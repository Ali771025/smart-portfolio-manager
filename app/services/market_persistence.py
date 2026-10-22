"""Market data persistence service.

Orchestrates dual-write to Redis (hot cache) and DB (source of truth).
Handles partial failures gracefully with appropriate logging.

Design:
  - Redis is write-through cache for fast reads
  - DB is source of truth for durability
  - Partial failures are logged but don't abort the operation
  - All writes are idempotent for repeated sync safety
"""

from __future__ import annotations

import logging
import uuid
from datetime import UTC, date, datetime
from decimal import Decimal

from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.redis import get_redis
from app.core import market_cache
from app.repositories.market_data import MarketDataRepository
from app.services.market_provider import (
    IndexSnapshot,
    InstrumentState,
    LiveMarketSnapshot,
    PriceBar,
)
from app.services.market_normalizers import TSETMCNormalizer

logger = logging.getLogger("market_persistence")


class MarketPersistenceService:
    """Service for persisting market data to Redis and DB.

    Usage:
        async with async_session_factory() as db:
            service = MarketPersistenceService(db)
            await service.save_live_snapshot(snapshot)
    """

    def __init__(self, db: AsyncSession) -> None:
        self._repo = MarketDataRepository(db)

    @property
    def repo(self) -> MarketDataRepository:
        """Access the underlying repository."""
        return self._repo

    # ═══════════════════════════════════════════════════════════════
    # Live Market Snapshot
    # ═══════════════════════════════════════════════════════════════

    async def save_live_snapshot(
        self,
        snapshot: LiveMarketSnapshot,
        *,
        asset_id: uuid.UUID | None = None,
    ) -> bool:
        """Save live market snapshot to Redis and DB.

        Args:
            snapshot: LiveMarketSnapshot from provider.
            asset_id: Optional asset UUID for DB update. If None, only Redis is updated.

        Returns:
            True if at least one write succeeded.
        """
        redis_ok = False
        db_ok = False

        # Redis write (fast path)
        try:
            redis_ok = await market_cache.cache_live_snapshot(
                snapshot.ins_code,
                snapshot,
                ttl_seconds=settings.REDIS_LIVE_PRICE_TTL_SECONDS,
            )
            await market_cache.cache_market_quote(
                TSETMCNormalizer.quote_from_snapshot(snapshot),
                publish_stream=True,
            )
        except Exception as exc:
            logger.warning(
                "Redis write failed for snapshot %s: %s",
                snapshot.ins_code,
                exc,
            )

        # DB write (if asset_id provided)
        if asset_id is not None:
            try:
                is_tradeable = snapshot.state not in {
                    InstrumentState.HALT,
                    InstrumentState.SUSPENDED,
                    InstrumentState.CLOSED,
                    InstrumentState.STOPPED,
                }
                await self._repo.update_asset_live_price(
                    asset_id=asset_id,
                    price=snapshot.close_price,
                    last_price=snapshot.last_trade_price,
                    closing_price=snapshot.close_price,
                    tradeable=is_tradeable,
                    updated_at=snapshot.fetched_at or datetime.now(UTC),
                )
                db_ok = True
            except Exception as exc:
                logger.warning(
                    "DB write failed for snapshot %s asset=%s: %s",
                    snapshot.ins_code,
                    asset_id,
                    exc,
                )

        return redis_ok or db_ok

    async def get_live_snapshot(
        self,
        ins_code: str,
        *,
        asset_id: uuid.UUID | None = None,
    ) -> LiveMarketSnapshot | None:
        """Get live market snapshot, checking Redis first then DB.

        Args:
            ins_code: TSETMC instrument code.
            asset_id: Optional asset UUID for DB fallback.

        Returns:
            LiveMarketSnapshot if found, None otherwise.
        """
        # Try Redis first
        cached = await market_cache.get_live_snapshot(ins_code)
        if cached is not None:
            try:
                from app.services.market_provider import InstrumentState as IS
                state_str = cached.get("state", "UNKNOWN")
                state = IS(state_str) if state_str in [s.value for s in IS] else IS.UNKNOWN
                return LiveMarketSnapshot(
                    ins_code=cached["ins_code"],
                    ticker=cached["ticker"],
                    close_price=cached["close_price"],
                    last_trade_price=cached["last_trade_price"],
                    open_price=cached["open_price"],
                    high_price=cached["high_price"],
                    low_price=cached["low_price"],
                    volume=cached["volume"],
                    state=state,
                    has_corporate_action=cached["has_corporate_action"],
                    fetched_at=cached.get("fetched_at"),
                    price_change=cached.get("price_change"),
                    price_change_percent=cached.get("price_change_percent"),
                )
            except Exception as exc:
                logger.warning("Failed to reconstruct snapshot from cache: %s", exc)

        # Fallback to DB
        if asset_id is not None:
            try:
                asset = await self._repo.get_asset_by_id(asset_id)
                selected = None
                if asset is not None:
                    selected = asset.last_trade_price if asset.last_trade_price > 0 else asset.closing_price
                if asset is not None and selected is not None and selected > 0:
                    return LiveMarketSnapshot(
                        ins_code=ins_code,
                        ticker=asset.ticker_symbol,
                        close_price=asset.closing_price or selected,
                        last_trade_price=selected,
                        open_price=asset.closing_price,
                        high_price=asset.closing_price,
                        low_price=asset.closing_price,
                        volume=0,
                        state=InstrumentState.TRADEABLE if asset.is_tradeable else InstrumentState.HALT,
                        has_corporate_action=False,
                        fetched_at=asset.price_updated_at or datetime.now(UTC),
                        price_change=asset.price_change,
                        price_change_percent=asset.price_change_percent,
                    )
            except Exception as exc:
                logger.warning("DB fallback failed for %s: %s", ins_code, exc)

        return None

    async def bulk_save_live_snapshots(
        self,
        snapshots: list[LiveMarketSnapshot],
        asset_map: dict[str, uuid.UUID] | None = None,
    ) -> dict[str, bool]:
        """Batch save multiple live snapshots.

        Args:
            snapshots: List of LiveMarketSnapshot.
            asset_map: Optional mapping of ins_code → asset_id for DB updates.

        Returns:
            Dict mapping ins_code to success status.
        """
        results: dict[str, bool] = {}

        # Bulk Redis write
        redis_cached = 0
        try:
            redis_cached = await market_cache.bulk_cache_live_snapshots(
                snapshots,
                ttl_seconds=settings.REDIS_LIVE_PRICE_TTL_SECONDS,
            )
        except Exception as exc:
            logger.warning("Bulk Redis write failed: %s", exc)

        # Individual DB writes
        for snapshot in snapshots:
            asset_id = asset_map.get(snapshot.ins_code) if asset_map else None
            success = await self.save_live_snapshot(snapshot, asset_id=asset_id)
            results[snapshot.ins_code] = success

        return results

    # ═══════════════════════════════════════════════════════════════
    # Symbol History
    # ═══════════════════════════════════════════════════════════════

    async def save_symbol_history(
        self,
        *,
        asset_id: uuid.UUID,
        bars: list[PriceBar],
    ) -> int:
        """Save historical price bars to DB.

        Args:
            asset_id: Asset UUID.
            bars: List of PriceBar from provider.

        Returns:
            Number of bars saved.
        """
        if not bars:
            return 0

        records = []
        for bar in bars:
            records.append({
                "asset_id": asset_id,
                "price_date": bar.date,
                "open_price": bar.open_price,
                "high_price": bar.high_price,
                "low_price": bar.low_price,
                "close_price": bar.close_price,
                "adjusted_close": bar.adjusted_close,
                "adjustment_factor": bar.adjustment_factor,
                "volume": bar.volume,
            })

        try:
            count = await self._repo.bulk_upsert_price_history(records)
            logger.debug("Saved %d price bars for asset %s", count, asset_id)
            return count
        except Exception as exc:
            logger.warning("Failed to save symbol history for %s: %s", asset_id, exc)
            return 0

    async def get_symbol_history(
        self,
        *,
        asset_id: uuid.UUID,
        start_date: date,
        end_date: date,
    ) -> list[PriceBar]:
        """Get price history from DB.

        Returns:
            List of PriceBar sorted by date ascending.
        """
        try:
            rows = await self._repo.get_symbol_history(
                asset_id=asset_id,
                start_date=start_date,
                end_date=end_date,
            )
            return [
                PriceBar(
                    date=row.date,
                    open_price=row.open_price,
                    high_price=row.high_price,
                    low_price=row.low_price,
                    close_price=row.close_price,
                    adjusted_close=row.adjusted_close,
                    adjustment_factor=row.adjustment_factor,
                    volume=row.volume,
                )
                for row in rows
            ]
        except Exception as exc:
            logger.warning("Failed to get symbol history for %s: %s", asset_id, exc)
            return []

    # ═══════════════════════════════════════════════════════════════
    # Index Snapshot
    # ═══════════════════════════════════════════════════════════════

    async def save_index_snapshot(
        self,
        snapshot: IndexSnapshot,
        *,
        benchmark_type: BenchmarkType | None = None,
    ) -> bool:
        """Save index snapshot to Redis and optionally to DB.

        Args:
            snapshot: IndexSnapshot from provider.
            benchmark_type: If provided, also save to benchmark_history table.

        Returns:
            True if at least one write succeeded.
        """
        from app.models.enums import BenchmarkType

        redis_ok = False
        db_ok = False

        # Redis write
        try:
            redis_ok = await market_cache.cache_index_snapshot(
                snapshot.index_code,
                snapshot,
                ttl_seconds=settings.REDIS_LIVE_PRICE_TTL_SECONDS,
            )
        except Exception as exc:
            logger.warning(
                "Redis write failed for index %s: %s",
                snapshot.index_code,
                exc,
            )

        # DB write (if benchmark_type provided)
        if benchmark_type is not None:
            try:
                await self._repo.upsert_benchmark_history(
                    benchmark_type=benchmark_type,
                    price_date=snapshot.fetched_at.date() if snapshot.fetched_at else date.today(),
                    open_price=snapshot.open_value,
                    high_price=snapshot.high_value,
                    low_price=snapshot.low_value,
                    close_price=snapshot.last_value,
                    adjusted_close=snapshot.last_value,
                    adjustment_factor=Decimal("1.0000"),
                    volume=snapshot.volume,
                    source="TSETMC",
                )
                db_ok = True
            except Exception as exc:
                logger.warning(
                    "DB write failed for index %s: %s",
                    snapshot.index_code,
                    exc,
                )

        return redis_ok or db_ok

    async def get_index_snapshot(
        self,
        index_code: str,
    ) -> IndexSnapshot | None:
        """Get index snapshot from Redis cache."""
        cached = await market_cache.get_index_snapshot(index_code)
        if cached is None:
            return None

        try:
            return IndexSnapshot(
                index_code=cached["index_code"],
                name=cached["name"],
                last_value=cached["last_value"],
                change_value=cached["change_value"],
                change_percent=cached["change_percent"],
                open_value=cached["open_value"],
                high_value=cached["high_value"],
                low_value=cached["low_value"],
                volume=cached["volume"],
                fetched_at=cached.get("fetched_at"),
            )
        except Exception as exc:
            logger.warning("Failed to reconstruct index snapshot from cache: %s", exc)
            return None

    # ═══════════════════════════════════════════════════════════════
    # Sync Metadata
    # ═══════════════════════════════════════════════════════════════

    async def save_sync_status(
        self,
        *,
        last_sync_at: datetime,
        synced_assets: int,
        failed_assets: int,
        provider_status: str = "healthy",
    ) -> bool:
        """Save sync status to Redis for monitoring."""
        try:
            return await market_cache.cache_sync_status(
                last_sync_at=last_sync_at,
                synced_assets=synced_assets,
                failed_assets=failed_assets,
                provider_status=provider_status,
            )
        except Exception as exc:
            logger.warning("Failed to save sync status: %s", exc)
            return False

    async def get_sync_status(self) -> dict | None:
        """Get sync status from Redis."""
        try:
            return await market_cache.get_sync_status()
        except Exception as exc:
            logger.warning("Failed to get sync status: %s", exc)
            return None

    # ═══════════════════════════════════════════════════════════════
    # Price Resolution (for Analytics/PnL consumers)
    # ═══════════════════════════════════════════════════════════════

    async def get_latest_price(
        self,
        asset_id: uuid.UUID,
        *,
        ins_code: str | None = None,
    ) -> tuple[Decimal, bool, datetime | None]:
        """Get latest price for an asset with freshness metadata.

        Checks Redis cache first, falls back to DB.
        Returns tuple of (price, is_fresh, last_updated_at).

        Args:
            asset_id: Asset UUID.
            ins_code: Optional TSETMC instrument code for Redis lookup.

        Returns:
            Tuple of (price, is_fresh, last_updated_at).
            price=0 if unavailable.
        """
        # Try Redis cache first
        if ins_code:
            cached_quote = await market_cache.get_market_quote(ins_code)
            if cached_quote is not None:
                price = cached_quote.get("last_price") or cached_quote.get("closing_price")
                fetched_at = cached_quote.get("event_time") or cached_quote.get("received_at")
                is_fresh = False
                if isinstance(fetched_at, datetime):
                    now = datetime.now(UTC)
                    if fetched_at.tzinfo is None:
                        fetched_at = fetched_at.replace(tzinfo=UTC)
                    age_seconds = (now - fetched_at).total_seconds()
                    is_fresh = age_seconds < (settings.TSETMC_SYNC_INTERVAL_MINUTES * 60 * 2)
                if price is not None and Decimal(str(price)) > 0:
                    return (Decimal(str(price)), is_fresh, fetched_at)

            cached = await market_cache.get_live_snapshot(ins_code)
            if cached is not None:
                price = cached.get("last_trade_price") or cached.get("close_price", Decimal("0"))
                fetched_at = cached.get("fetched_at")

                # Check freshness
                is_fresh = False
                if isinstance(fetched_at, datetime):
                    now = datetime.now(UTC)
                    if fetched_at.tzinfo is None:
                        fetched_at = fetched_at.replace(tzinfo=UTC)
                    age_seconds = (now - fetched_at).total_seconds()
                    # Fresh if within 2x sync interval
                    is_fresh = age_seconds < (settings.TSETMC_SYNC_INTERVAL_MINUTES * 60 * 2)

                return (Decimal(str(price)), is_fresh, fetched_at)

        # Fallback to DB
        try:
            asset = await self._repo.get_asset_by_id(asset_id)
            if asset is not None:
                selected = asset.last_trade_price if asset.last_trade_price > 0 else asset.closing_price
                if selected <= 0:
                    return (Decimal("0"), False, asset.price_updated_at)
                # Check freshness from price_updated_at
                is_fresh = False
                last_updated = asset.price_updated_at
                if last_updated is not None:
                    now = datetime.now(UTC)
                    if last_updated.tzinfo is None:
                        last_updated = last_updated.replace(tzinfo=UTC)
                    age_seconds = (now - last_updated).total_seconds()
                    is_fresh = age_seconds < (settings.TSETMC_SYNC_INTERVAL_MINUTES * 60 * 2)

                return (selected, is_fresh, asset.price_updated_at)
        except Exception as exc:
            logger.warning("DB price fallback failed for %s: %s", asset_id, exc)

        return (Decimal("0"), False, None)

    async def get_latest_prices_batch(
        self,
        asset_ids: list[uuid.UUID],
        *,
        ins_code_map: dict[uuid.UUID, str] | None = None,
    ) -> dict[uuid.UUID, tuple[Decimal, bool, datetime | None]]:
        """Get latest prices for multiple assets with freshness metadata.

        Args:
            asset_ids: List of asset UUIDs.
            ins_code_map: Optional mapping of asset_id → ins_code for Redis lookup.

        Returns:
            Dict mapping asset_id to (price, is_fresh, last_updated_at).
        """
        results: dict[uuid.UUID, tuple[Decimal, bool, datetime | None]] = {}

        for asset_id in asset_ids:
            ins_code = ins_code_map.get(asset_id) if ins_code_map else None
            results[asset_id] = await self.get_latest_price(asset_id, ins_code=ins_code)

        return results

    async def get_price_freshness_info(self) -> dict[str, Any]:
        """Get overall price freshness information for monitoring.

        Returns:
            Dict with freshness metrics.
        """
        from datetime import timedelta

        sync_status = await market_cache.get_sync_status()
        last_sync_at = None
        freshness_seconds = None
        is_stale = True

        if sync_status and sync_status.get("last_sync_at"):
            try:
                last_sync_str = sync_status["last_sync_at"]
                last_sync_dt = datetime.fromisoformat(last_sync_str)
                now = datetime.now(UTC)
                if last_sync_dt.tzinfo is None:
                    last_sync_dt = last_sync_dt.replace(tzinfo=UTC)
                freshness_seconds = int((now - last_sync_dt).total_seconds())
                is_stale = freshness_seconds > (settings.TSETMC_SYNC_INTERVAL_MINUTES * 60 * 2)
                last_sync_at = last_sync_str
            except (ValueError, TypeError):
                pass

        return {
            "last_sync_at": last_sync_at,
            "freshness_seconds": freshness_seconds,
            "is_stale": is_stale,
            "sync_interval_seconds": settings.TSETMC_SYNC_INTERVAL_MINUTES * 60,
            "stale_threshold_seconds": settings.TSETMC_SYNC_INTERVAL_MINUTES * 60 * 2,
        }

    # ═══════════════════════════════════════════════════════════════
    # Transaction Support
    # ═══════════════════════════════════════════════════════════════

    async def commit(self) -> None:
        """Commit the current transaction."""
        await self._repo.commit()

    async def rollback(self) -> None:
        """Rollback the current transaction."""
        await self._repo.rollback()
