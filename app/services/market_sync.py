"""Background market sync for TSETMC with retry, sanity checks, and caching.

This module provides the standalone sync function that can be called
from both Celery tasks and APScheduler. It uses the MarketDataProvider
abstraction for fetching data.

Note: This is a simpler, standalone version of the sync logic that
doesn't require the full MarketIntegrationService dependency chain.
It's used by background workers that need minimal dependencies.
"""

from __future__ import annotations

import asyncio
import logging
import uuid
from dataclasses import dataclass
from datetime import UTC, date, datetime, timedelta
from decimal import Decimal, InvalidOperation, ROUND_HALF_UP

from sqlalchemy import select, update
from sqlalchemy.dialects.postgresql import insert as pg_insert
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.database import async_session_factory
from app.core.redis import bulk_cache_prices
from app.models.asset import Asset
from app.models.corporate_action import CorporateAction
from app.models.enums import SyncStatus
from app.models.market_data import DailyPrice
from app.services.market_provider import (
    InstrumentState,
    LiveMarketSnapshot,
    MarketProviderConfig,
    MarketDataProvider,
)

logger = logging.getLogger("market_sync")
FOUR_PLACES = Decimal("0.0001")


def quantize4(value: Decimal) -> Decimal:
    return value.quantize(FOUR_PLACES, rounding=ROUND_HALF_UP)


@dataclass(slots=True)
class MarketPayload:
    """Internal payload for sync operations."""
    close_price: Decimal
    last_trade_price: Decimal
    open_price: Decimal
    high_price: Decimal
    low_price: Decimal
    volume: int
    ticker_status: str
    has_corporate_action: bool

    @classmethod
    def from_snapshot(cls, snapshot: LiveMarketSnapshot) -> MarketPayload:
        """Create from provider's LiveMarketSnapshot."""
        return cls(
            close_price=snapshot.close_price,
            last_trade_price=snapshot.last_trade_price,
            open_price=snapshot.open_price,
            high_price=snapshot.high_price,
            low_price=snapshot.low_price,
            volume=snapshot.volume,
            ticker_status=snapshot.state.value,
            has_corporate_action=snapshot.has_corporate_action,
        )


@dataclass(slots=True)
class SyncResult:
    asset_id: uuid.UUID
    ticker: str
    status: SyncStatus
    price: Decimal | None = None
    error: str | None = None
    payload: MarketPayload | None = None


@dataclass(slots=True)
class SyncCycleReport:
    started_at: datetime
    finished_at: datetime | None
    total_tickers: int
    success_count: int
    skipped_sanity: int
    skipped_zero: int
    failed_count: int
    results: list[SyncResult]

    @classmethod
    def start(cls) -> SyncCycleReport:
        return cls(
            started_at=datetime.now(UTC),
            finished_at=None,
            total_tickers=0,
            success_count=0,
            skipped_sanity=0,
            skipped_zero=0,
            failed_count=0,
            results=[],
        )

    def finalize(self) -> None:
        self.finished_at = datetime.now(UTC)
        self.success_count = sum(1 for item in self.results if item.status == SyncStatus.SUCCESS)
        self.skipped_sanity = sum(1 for item in self.results if item.status == SyncStatus.SKIPPED_SANITY)
        self.skipped_zero = sum(1 for item in self.results if item.status == SyncStatus.SKIPPED_ZERO)
        self.failed_count = sum(
            1
            for item in self.results
            if item.status in (SyncStatus.FAILED_TIMEOUT, SyncStatus.FAILED_HTTP, SyncStatus.FAILED_PARSE)
        )


class PriceSanityValidator:
    """Validates price changes against sanity thresholds."""

    def __init__(
        self,
        max_drop_pct: float = settings.TSETMC_SANITY_MAX_DROP_PCT,
        max_rise_pct: float = settings.TSETMC_SANITY_MAX_RISE_PCT,
    ) -> None:
        self.max_drop_pct = Decimal(str(max_drop_pct))
        self.max_rise_pct = Decimal(str(max_rise_pct))

    def validate(
        self,
        new_price: Decimal,
        previous_close: Decimal,
        ticker: str,
        has_corporate_action: bool,
    ) -> tuple[bool, str | None]:
        if new_price <= 0:
            return False, f"{ticker}: current_price <= 0"

        if previous_close <= 0:
            return True, None

        change_pct = ((new_price - previous_close) / previous_close) * Decimal("100")

        if change_pct < -self.max_drop_pct and not has_corporate_action:
            return (
                False,
                f"{ticker}: drop {change_pct:.2f}% exceeds {-self.max_drop_pct}% without corporate action",
            )

        if change_pct > self.max_rise_pct:
            return (
                False,
                f"{ticker}: rise {change_pct:.2f}% exceeds {self.max_rise_pct}%",
            )

        return True, None


def _status_is_tradeable(status_text: str) -> bool:
    """Check if instrument status indicates tradeable."""
    halted = {"HALT", "SUSPENDED", "STOPPED", "CLOSED"}
    if not status_text:
        return True
    upper = status_text.upper()
    return all(term not in upper for term in halted)


async def _upsert_daily_history(
    db: AsyncSession,
    *,
    asset_id: uuid.UUID,
    trade_date: date,
    payload: MarketPayload,
) -> None:
    """Upsert daily price history row."""
    statement = pg_insert(DailyPrice).values(
        asset_id=asset_id,
        price_time=datetime.combine(trade_date, datetime.min.time(), tzinfo=UTC),
        date=trade_date,
        open_price=payload.open_price,
        high_price=payload.high_price,
        low_price=payload.low_price,
        close_price=payload.close_price,
        last_trade_price=payload.last_trade_price,
        adjusted_close=payload.close_price,
        adjustment_factor=Decimal("1.0000"),
        volume=payload.volume,
    )
    statement = statement.on_conflict_do_update(
        index_elements=["asset_id", "date"],
        set_={
            "open_price": payload.open_price,
            "high_price": payload.high_price,
            "low_price": payload.low_price,
            "close_price": payload.close_price,
            "last_trade_price": payload.last_trade_price,
            "adjusted_close": payload.close_price,
            "adjustment_factor": Decimal("1.0000"),
            "volume": payload.volume,
            "price_time": datetime.combine(trade_date, datetime.min.time(), tzinfo=UTC),
        },
    )
    await db.execute(statement)


async def _apply_asset_update(
    db: AsyncSession,
    *,
    asset: Asset,
    payload: MarketPayload,
    now: datetime,
) -> None:
    """Update asset's live price and tradeable status."""
    await db.execute(
        update(Asset)
        .where(Asset.id == asset.id)
        .values(
            previous_close_price=asset.closing_price,
            current_price=payload.close_price,
            closing_price=payload.close_price,
            last_trade_price=payload.last_trade_price,
            price_updated_at=now,
            is_tradeable=_status_is_tradeable(payload.ticker_status),
        )
    )


async def _sync_single_asset(
    *,
    provider: MarketDataProvider,
    validator: PriceSanityValidator,
    asset: Asset,
    has_corporate_action_flag: bool,
) -> SyncResult:
    """Sync a single asset using the provider abstraction."""
    ticker = asset.ticker_symbol
    asset_id = asset.id

    try:
        snapshot = await provider.fetch_live_market_snapshot(asset.tsetmc_id or "")
    except Exception as exc:
        return SyncResult(
            asset_id=asset_id,
            ticker=ticker,
            status=SyncStatus.FAILED_PARSE,
            error=str(exc),
        )

    if snapshot is None:
        return SyncResult(
            asset_id=asset_id,
            ticker=ticker,
            status=SyncStatus.FAILED_PARSE,
            error="Parse failed",
        )

    if snapshot.close_price <= 0:
        return SyncResult(
            asset_id=asset_id,
            ticker=ticker,
            status=SyncStatus.SKIPPED_ZERO,
            error="close_price <= 0",
        )

    payload = MarketPayload.from_snapshot(snapshot)

    is_valid, error = validator.validate(
        new_price=payload.close_price,
        previous_close=asset.previous_close_price or Decimal("0.0000"),
        ticker=ticker,
        has_corporate_action=(payload.has_corporate_action or has_corporate_action_flag),
    )
    if not is_valid:
        logger.warning("market_sync skip: %s", error)
        return SyncResult(
            asset_id=asset_id,
            ticker=ticker,
            status=SyncStatus.SKIPPED_SANITY,
            error=error,
        )

    return SyncResult(
        asset_id=asset_id,
        ticker=ticker,
        status=SyncStatus.SUCCESS,
        price=payload.close_price,
        payload=payload,
    )


def _get_provider() -> MarketDataProvider:
    """Get a fresh provider instance for sync operations."""
    from app.services.tsetmc_provider import TSETMCProvider

    config = MarketProviderConfig(
        base_url=settings.TSETMC_BASE_URL,
        request_timeout=settings.TSETMC_REQUEST_TIMEOUT,
        connect_timeout=settings.TSETMC_CONNECT_TIMEOUT,
        max_concurrent=settings.TSETMC_MAX_CONCURRENT,
        retry_attempts=settings.TSETMC_RETRY_ATTEMPTS,
        retry_base_delay=settings.TSETMC_RETRY_BASE_DELAY,
        retry_max_delay=settings.TSETMC_RETRY_MAX_DELAY,
        retry_backoff_multiplier=settings.TSETMC_RETRY_BACKOFF_MULTIPLIER,
        circuit_breaker_failure_threshold=settings.TSETMC_CIRCUIT_BREAKER_FAILURE_THRESHOLD,
        circuit_breaker_reset_seconds=settings.TSETMC_CIRCUIT_BREAKER_RESET_SECONDS,
    )
    return TSETMCProvider(config)


async def run_full_sync() -> SyncCycleReport:
    """Sync all active TSETMC assets, update DB, and push prices to Redis.

    This is the standalone sync function used by background workers.
    It uses the MarketDataProvider abstraction for fetching data.
    """
    report = SyncCycleReport.start()
    now = datetime.now(UTC)
    trade_date = now.date()
    validator = PriceSanityValidator()
    provider = _get_provider()

    async with async_session_factory() as db:
        asset_rows = await db.execute(
            select(Asset).where(
                Asset.is_active.is_(True),
                Asset.tsetmc_id.isnot(None),
            )
        )
        assets = asset_rows.scalars().all()
        asset_map = {item.id: item for item in assets}
        report.total_tickers = len(assets)
        if not assets:
            report.finalize()
            return report

        action_rows = await db.execute(
            select(CorporateAction.asset_id).where(
                CorporateAction.effective_date == trade_date,
                CorporateAction.is_active.is_(True),
            )
        )
        asset_action_flags = {row[0] for row in action_rows.all()}

        async with provider:
            tasks = [
                _sync_single_asset(
                    provider=provider,
                    validator=validator,
                    asset=asset,
                    has_corporate_action_flag=asset.id in asset_action_flags,
                )
                for asset in assets
            ]
            report.results = list(await asyncio.gather(*tasks))

        for result in report.results:
            if result.status != SyncStatus.SUCCESS or result.payload is None:
                continue
            asset = asset_map.get(result.asset_id)
            if asset is None:
                continue
            await _apply_asset_update(db, asset=asset, payload=result.payload, now=now)
            await _upsert_daily_history(
                db,
                asset_id=result.asset_id,
                trade_date=trade_date,
                payload=result.payload,
            )

        await db.commit()

    cache_batch = {
        str(item.asset_id): (item.price, now)
        for item in report.results
        if item.status == SyncStatus.SUCCESS and item.price is not None
    }
    await bulk_cache_prices(cache_batch)

    report.finalize()
    logger.info(
        "market_sync complete total=%s success=%s skipped_sanity=%s skipped_zero=%s failed=%s",
        report.total_tickers,
        report.success_count,
        report.skipped_sanity,
        report.skipped_zero,
        report.failed_count,
    )
    return report
