"""Repository layer for market prices, benchmark series, and live snapshots.

Extends the base market data repository with methods for:
  - Live market snapshot persistence (DB)
  - Historical price bar persistence (DB)
  - Index snapshot persistence (DB)
  - Sync metadata tracking
  - Idempotent upsert operations

Design:
  - All writes are idempotent (upsert with conflict handling)
  - Partial failures are logged but don't abort the batch
  - Redis is used for hot data (see market_cache.py)
  - DB is source of truth for historical/durable data
"""

from __future__ import annotations

import json
import logging
import uuid
from datetime import UTC, date, datetime, time, timedelta
from decimal import Decimal
from typing import Any

from sqlalchemy import bindparam, desc, or_, select, text as sql_text, update
from sqlalchemy.dialects.postgresql import insert as pg_insert
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.asset import Asset
from app.models.market_data import (
    BenchmarkHistory,
    ClientType,
    DailyPrice,
    Disclosure,
    Fund,
    FundNavHistory,
    Instrument,
    MarketIndex,
    MarketOverview,
    MarketQuote,
    OrderBook,
    IngestionRun,
)
from app.models.enums import BenchmarkType
from app.services import market_provider as dto
from app.services.market_normalizers import normalize_market_symbol

logger = logging.getLogger("market_repository")


class MarketDataRepository:
    """Persistence operations for TSETMC market data and benchmark histories."""

    def __init__(self, db: AsyncSession) -> None:
        self.db = db

    # ═══════════════════════════════════════════════════════════════
    # Normalized Provider Data (Idempotent Upserts)
    # ═══════════════════════════════════════════════════════════════

    async def upsert_instruments(self, items: list[dto.MarketInstrument]) -> int:
        if not items:
            return 0
        rows = [
            {
                "instrument_id": item.instrument_id,
                "ins_code": item.ins_code,
                "isin": item.isin,
                "symbol": item.symbol,
                "company_name": item.company_name,
                "market": item.market,
                "board": item.board,
                "sector_code": item.sector_code,
                "sector_name": item.sector_name,
                "instrument_type": item.instrument_type,
                "is_active": item.is_active,
            }
            for item in items
        ]
        # A full market-watch snapshot can contain thousands of instruments.
        # Each instrument insert binds 12+ parameters, so one giant statement
        # can exceed asyncpg/PostgreSQL's bind-parameter limit. Keep batches
        # comfortably below that ceiling.
        batch_size = 500
        for offset in range(0, len(rows), batch_size):
            statement = pg_insert(Instrument).values(rows[offset : offset + batch_size])
            excluded = statement.excluded
            statement = statement.on_conflict_do_update(
                index_elements=["instrument_id"],
                set_={
                    "ins_code": excluded.ins_code,
                    "isin": excluded.isin,
                    "symbol": excluded.symbol,
                    "company_name": excluded.company_name,
                    "market": excluded.market,
                    "board": excluded.board,
                    "sector_code": excluded.sector_code,
                    "sector_name": excluded.sector_name,
                    "instrument_type": excluded.instrument_type,
                    "is_active": excluded.is_active,
                    "updated_at": datetime.now(UTC),
                },
            )
            await self.db.execute(statement)
        return len(rows)

    async def upsert_market_quotes(self, items: list[dto.MarketQuote]) -> int:
        if not items:
            return 0
        now = datetime.now(UTC)
        rows = [
            {
                "instrument_id": item.instrument_id,
                "symbol": item.symbol,
                "trade_date": item.trade_date,
                "event_time": item.event_time or item.received_at or now,
                "first_price": item.first_price,
                "last_price": item.last_price,
                "closing_price": item.closing_price,
                "yesterday_price": item.yesterday_price,
                "high_price": item.high_price,
                "low_price": item.low_price,
                "trade_count": item.trade_count,
                "volume": item.volume,
                "value": item.value,
                "buy_count": item.buy_count,
                "sell_count": item.sell_count,
                "status": item.status.value if hasattr(item.status, "value") else str(item.status),
                "received_at": item.received_at or now,
                "source": item.source,
            }
            for item in items
        ]
        # A full TSETMC snapshot contains thousands of rows. Inserting the
        # whole payload in one statement exceeds PostgreSQL/asyncpg's bind
        # parameter limit (roughly 20 columns x 2,500+ rows). Keep each
        # statement comfortably below that limit.
        batch_size = 500
        for offset in range(0, len(rows), batch_size):
            statement = pg_insert(MarketQuote).values(rows[offset : offset + batch_size])
            excluded = statement.excluded
            statement = statement.on_conflict_do_update(
                index_elements=["instrument_id", "event_time"],
                set_={
                    "symbol": excluded.symbol,
                    "trade_date": excluded.trade_date,
                    "first_price": excluded.first_price,
                    "last_price": excluded.last_price,
                    "closing_price": excluded.closing_price,
                    "yesterday_price": excluded.yesterday_price,
                    "high_price": excluded.high_price,
                    "low_price": excluded.low_price,
                    "trade_count": excluded.trade_count,
                    "volume": excluded.volume,
                    "value": excluded.value,
                    "buy_count": excluded.buy_count,
                    "sell_count": excluded.sell_count,
                    "status": excluded.status,
                    "received_at": excluded.received_at,
                    "source": excluded.source,
                    "updated_at": now,
                },
            )
            await self.db.execute(statement)
        return len(rows)

    async def update_assets_from_market_quotes(self, items: list[dto.MarketQuote]) -> int:
        if not items:
            return 0
        updated = 0
        by_instrument = {item.instrument_id: item for item in items}
        symbol_candidates: dict[str, list[dto.MarketQuote]] = {}
        for item in items:
            symbol_candidates.setdefault(normalize_market_symbol(item.symbol), []).append(item)
        by_symbol = {
            symbol: self._select_preferred_quote(candidates)
            for symbol, candidates in symbol_candidates.items()
            if symbol
        }
        result = await self.db.execute(
            select(Asset).where(
                Asset.is_active.is_(True),
                Asset.exchange == "TSETMC",
            )
        )
        assets = list(result.scalars().all())
        for asset in assets:
            quote = by_instrument.get(str(asset.tsetmc_id or ""))
            if quote is None:
                quote = next(
                    (
                        by_symbol[key]
                        for key in self._asset_symbol_keys(asset)
                        if key in by_symbol
                    ),
                    None,
                )
            if quote is None or quote.closing_price is None:
                continue
            effective_last = quote.last_price or quote.closing_price
            await self.db.execute(
                update(Asset)
                .where(Asset.id == asset.id)
                .values(
                    previous_close_price=quote.yesterday_price or Asset.closing_price,
                    tsetmc_id=quote.instrument_id,
                    current_price=effective_last,
                    closing_price=quote.closing_price,
                    last_trade_price=effective_last,
                    is_tradeable=str(quote.status).upper() not in {"HALT", "SUSPENDED", "STOPPED", "CLOSED"},
                    price_updated_at=quote.received_at or quote.event_time or datetime.now(UTC),
                )
            )
            updated += 1
        return updated

    @staticmethod
    def _select_preferred_quote(candidates: list[dto.MarketQuote]) -> dto.MarketQuote:
        return max(
            candidates,
            key=lambda item: (
                item.last_price is not None and item.last_price > 0,
                item.closing_price is not None and item.closing_price > 0,
                item.trade_count,
                item.volume,
                item.value or Decimal("0"),
                item.event_time or item.received_at or datetime.min.replace(tzinfo=UTC),
            ),
        )

    @staticmethod
    def _asset_symbol_keys(asset: Asset) -> list[str]:
        raw_values: list[Any] = [
            asset.normalized_symbol,
            asset.ticker_symbol,
        ]
        metadata = asset.display_metadata if isinstance(asset.display_metadata, dict) else {}
        for key in (
            "symbol",
            "ticker",
            "ticker_symbol",
            "tsetmc_symbol",
            "normalized_symbol",
        ):
            raw_values.append(metadata.get(key))
        aliases = metadata.get("aliases")
        if isinstance(aliases, list):
            raw_values.extend(aliases)
        keys: list[str] = []
        for value in raw_values:
            normalized = normalize_market_symbol(value)
            if normalized and normalized not in keys:
                keys.append(normalized)
        return keys

    async def upsert_daily_prices(self, items: list[dto.DailyPrice]) -> int:
        if not items:
            return 0
        now = datetime.now(UTC)
        rows = [
            {
                "instrument_id": item.instrument_id,
                "price_time": item.updated_at or datetime.combine(item.trade_date, time.min, tzinfo=UTC),
                "date": item.trade_date,
                "open_price": item.open_price,
                "high_price": item.high_price,
                "low_price": item.low_price,
                "close_price": item.closing_price,
                "last_trade_price": item.last_price,
                "yesterday_price": item.yesterday_price,
                "adjusted_close": item.adjusted_close,
                "adjustment_factor": Decimal("1.00000000"),
                "volume": item.volume,
                "value": item.value,
                "trade_count": item.trade_count,
                "source": item.source,
            }
            for item in items
        ]
        statement = pg_insert(DailyPrice).values(rows)
        excluded = statement.excluded
        statement = statement.on_conflict_do_update(
            index_elements=["instrument_id", "date"],
            set_={
                "price_time": excluded.price_time,
                "open_price": excluded.open_price,
                "high_price": excluded.high_price,
                "low_price": excluded.low_price,
                "close_price": excluded.close_price,
                "last_trade_price": excluded.last_trade_price,
                "yesterday_price": excluded.yesterday_price,
                "adjusted_close": excluded.adjusted_close,
                "volume": excluded.volume,
                "value": excluded.value,
                "trade_count": excluded.trade_count,
                "source": excluded.source,
                "updated_at": now,
            },
        )
        await self.db.execute(statement)
        return len(rows)

    async def upsert_client_types(self, items: list[dto.ClientTypeBreakdown]) -> int:
        if not items:
            return 0
        rows = [
            {
                "instrument_id": item.instrument_id,
                "trade_date": item.trade_date,
                "individual_buy_count": item.individual_buy_count,
                "individual_buy_volume": item.individual_buy_volume,
                "individual_sell_count": item.individual_sell_count,
                "individual_sell_volume": item.individual_sell_volume,
                "legal_buy_count": item.legal_buy_count,
                "legal_buy_volume": item.legal_buy_volume,
                "legal_sell_count": item.legal_sell_count,
                "legal_sell_volume": item.legal_sell_volume,
            }
            for item in items
        ]
        statement = pg_insert(ClientType).values(rows)
        excluded = statement.excluded
        statement = statement.on_conflict_do_update(
            index_elements=["instrument_id", "trade_date"],
            set_={
                "individual_buy_count": excluded.individual_buy_count,
                "individual_buy_volume": excluded.individual_buy_volume,
                "individual_sell_count": excluded.individual_sell_count,
                "individual_sell_volume": excluded.individual_sell_volume,
                "legal_buy_count": excluded.legal_buy_count,
                "legal_buy_volume": excluded.legal_buy_volume,
                "legal_sell_count": excluded.legal_sell_count,
                "legal_sell_volume": excluded.legal_sell_volume,
                "updated_at": datetime.now(UTC),
            },
        )
        await self.db.execute(statement)
        return len(rows)

    async def upsert_order_book_snapshot(self, items: list[dto.OrderBookLevel]) -> int:
        if not items:
            return 0
        rows = [
            {
                "instrument_id": item.instrument_id,
                "event_time": item.event_time,
                "level": item.level,
                "buy_price": item.buy_price,
                "buy_volume": item.buy_volume,
                "buy_count": item.buy_count,
                "sell_price": item.sell_price,
                "sell_volume": item.sell_volume,
                "sell_count": item.sell_count,
            }
            for item in items
        ]
        statement = pg_insert(OrderBook).values(rows)
        excluded = statement.excluded
        statement = statement.on_conflict_do_update(
            index_elements=["instrument_id", "event_time", "level"],
            set_={
                "buy_price": excluded.buy_price,
                "buy_volume": excluded.buy_volume,
                "buy_count": excluded.buy_count,
                "sell_price": excluded.sell_price,
                "sell_volume": excluded.sell_volume,
                "sell_count": excluded.sell_count,
                "updated_at": datetime.now(UTC),
            },
        )
        await self.db.execute(statement)
        return len(rows)

    async def upsert_indices(self, items: list[dto.MarketIndex]) -> int:
        if not items:
            return 0
        rows = [
            {
                "index_code": item.index_code,
                "name": item.name,
                "value": item.value,
                "change": item.change,
                "change_percent": item.change_percent,
                "event_time": item.event_time,
                "source": item.source,
            }
            for item in items
        ]
        statement = pg_insert(MarketIndex).values(rows)
        excluded = statement.excluded
        statement = statement.on_conflict_do_update(
            index_elements=["index_code", "event_time"],
            set_={
                "name": excluded.name,
                "value": excluded.value,
                "change": excluded.change,
                "change_percent": excluded.change_percent,
                "source": excluded.source,
                "updated_at": datetime.now(UTC),
            },
        )
        await self.db.execute(statement)
        return len(rows)

    async def upsert_market_overview(self, item: dto.MarketOverview) -> int:
        statement = pg_insert(MarketOverview).values(
            total_index_value=item.total_index_value,
            total_index_change=item.total_index_change,
            equal_weight_index_value=item.equal_weight_index_value,
            equal_weight_index_change=item.equal_weight_index_change,
            market_value=item.market_value,
            trades_count=item.trades_count,
            trades_value=item.trades_value,
            trades_volume=item.trades_volume,
            price_info_timestamp=item.price_info_timestamp,
            server_received_at=item.server_received_at,
            source=item.source,
        )
        excluded = statement.excluded
        statement = statement.on_conflict_do_update(
            index_elements=["source", "price_info_timestamp"],
            set_={
                "total_index_value": excluded.total_index_value,
                "total_index_change": excluded.total_index_change,
                "equal_weight_index_value": excluded.equal_weight_index_value,
                "equal_weight_index_change": excluded.equal_weight_index_change,
                "market_value": excluded.market_value,
                "trades_count": excluded.trades_count,
                "trades_value": excluded.trades_value,
                "trades_volume": excluded.trades_volume,
                "server_received_at": excluded.server_received_at,
                "updated_at": datetime.now(UTC),
            },
        )
        await self.db.execute(statement)
        return 1

    async def upsert_disclosures(self, items: list[dto.CodalDisclosure]) -> int:
        if not items:
            return 0
        rows = [
            {
                "tracking_number": item.tracking_number,
                "symbol": item.symbol,
                "company_name": item.company_name,
                "title": item.title,
                "letter_code": item.letter_code,
                "sent_at": item.sent_at,
                "published_at": item.published_at,
                "category": item.category,
                "url": item.url,
                "has_attachment": item.has_attachment,
                "source": item.source,
            }
            for item in items
        ]
        statement = pg_insert(Disclosure).values(rows)
        excluded = statement.excluded
        statement = statement.on_conflict_do_update(
            index_elements=["tracking_number"],
            set_={
                "symbol": excluded.symbol,
                "company_name": excluded.company_name,
                "title": excluded.title,
                "letter_code": excluded.letter_code,
                "sent_at": excluded.sent_at,
                "published_at": excluded.published_at,
                "category": excluded.category,
                "url": excluded.url,
                "has_attachment": excluded.has_attachment,
                "source": excluded.source,
                "updated_at": datetime.now(UTC),
            },
        )
        await self.db.execute(statement)
        return len(rows)

    async def upsert_funds(self, items: list[dto.Fund]) -> int:
        if not items:
            return 0
        rows = [
            {
                "fund_id": item.fund_id,
                "name": item.name,
                "type": item.type,
                "nav": item.nav,
                "nav_date": item.nav_date,
                "return_1m": item.return_1m,
                "return_3m": item.return_3m,
                "return_6m": item.return_6m,
                "return_1y": item.return_1y,
                "source": item.source,
            }
            for item in items
        ]
        statement = pg_insert(Fund).values(rows)
        excluded = statement.excluded
        statement = statement.on_conflict_do_update(
            index_elements=["fund_id"],
            set_={
                "name": excluded.name,
                "type": excluded.type,
                "nav": excluded.nav,
                "nav_date": excluded.nav_date,
                "return_1m": excluded.return_1m,
                "return_3m": excluded.return_3m,
                "return_6m": excluded.return_6m,
                "return_1y": excluded.return_1y,
                "source": excluded.source,
                "updated_at": datetime.now(UTC),
            },
        )
        await self.db.execute(statement)
        return len(rows)

    async def upsert_fund_navs(self, items: list[dto.FundNav]) -> int:
        if not items:
            return 0
        rows = [
            {
                "fund_id": item.fund_id,
                "nav_date": item.nav_date,
                "subscription_nav": item.subscription_nav,
                "redemption_nav": item.redemption_nav,
                "statistical_nav": item.statistical_nav,
                "source": item.source,
            }
            for item in items
        ]
        statement = pg_insert(FundNavHistory).values(rows)
        excluded = statement.excluded
        statement = statement.on_conflict_do_update(
            index_elements=["fund_id", "nav_date", "source"],
            set_={
                "subscription_nav": excluded.subscription_nav,
                "redemption_nav": excluded.redemption_nav,
                "statistical_nav": excluded.statistical_nav,
                "updated_at": datetime.now(UTC),
            },
        )
        await self.db.execute(statement)
        return len(rows)

    async def upsert_benchmark_tick(
        self,
        *,
        benchmark_code: str,
        tick_time: datetime,
        value_type: str,
        price_level: Decimal | None,
        annual_rate: Decimal | None,
        source: str,
        idempotency_key: str,
    ) -> int:
        await self.db.execute(
            sql_text(
                """
                INSERT INTO benchmark_ticks (
                    benchmark_code, tick_time, sequence_no, value_type,
                    price_level, annual_rate, source, ingest_idempotency_key
                ) VALUES (
                    :benchmark_code, :tick_time, 0,
                    CAST(:value_type AS benchmark_value_type_enum),
                    :price_level, :annual_rate, :source, :idempotency_key
                )
                ON CONFLICT (benchmark_code, tick_time, sequence_no)
                DO UPDATE SET
                    value_type = EXCLUDED.value_type,
                    price_level = EXCLUDED.price_level,
                    annual_rate = EXCLUDED.annual_rate,
                    source = EXCLUDED.source,
                    ingest_idempotency_key = EXCLUDED.ingest_idempotency_key
                """
            ),
            {
                "benchmark_code": benchmark_code,
                "tick_time": tick_time,
                "value_type": value_type,
                "price_level": price_level,
                "annual_rate": annual_rate,
                "source": source,
                "idempotency_key": idempotency_key,
            },
        )
        return 1

    async def record_ingestion_run(
        self,
        *,
        source: str,
        provider: str | None,
        run_type: str,
        started_at: datetime,
        finished_at: datetime,
        status: str,
        records_received: int,
        records_valid: int,
        records_inserted: int = 0,
        records_updated: int = 0,
        errors_count: int = 0,
        last_success_at: datetime | None = None,
        metadata_json: dict[str, Any] | None = None,
        error_message: str | None = None,
    ) -> IngestionRun:
        run = IngestionRun(
            source=source,
            provider=provider,
            run_type=run_type,
            started_at=started_at,
            finished_at=finished_at,
            status=status,
            records_received=records_received,
            records_valid=records_valid,
            records_inserted=records_inserted,
            records_updated=records_updated,
            errors_count=errors_count,
            last_success_at=last_success_at,
            records_seen=records_received,
            records_upserted=records_inserted + records_updated,
            records_failed=errors_count,
            error_message=error_message,
            metadata_json=metadata_json,
        )
        self.db.add(run)
        return run

    async def get_latest_quote(self, symbol_or_instrument_id: str) -> MarketQuote | None:
        result = await self.db.execute(
            select(MarketQuote)
            .where(
                or_(
                    MarketQuote.instrument_id == symbol_or_instrument_id,
                    MarketQuote.symbol == symbol_or_instrument_id,
                )
            )
            .order_by(desc(MarketQuote.event_time))
            .limit(1)
        )
        return result.scalar_one_or_none()

    async def list_symbols(
        self,
        *,
        query: str | None = None,
        active_only: bool = True,
        limit: int = 100,
        offset: int = 0,
    ) -> list[Instrument]:
        statement = select(Instrument)
        if active_only:
            statement = statement.where(Instrument.is_active.is_(True))
        if query:
            normalized = f"%{query.strip()}%"
            statement = statement.where(
                or_(
                    Instrument.symbol.ilike(normalized),
                    Instrument.company_name.ilike(normalized),
                    Instrument.instrument_id == query.strip(),
                    Instrument.ins_code == query.strip(),
                    Instrument.isin == query.strip(),
                )
            )
        result = await self.db.execute(
            statement.order_by(Instrument.symbol.asc()).limit(min(max(limit, 1), 500)).offset(max(offset, 0))
        )
        return list(result.scalars().all())

    async def get_symbol(self, symbol_or_instrument_id: str) -> Instrument | None:
        key = symbol_or_instrument_id.strip()
        result = await self.db.execute(
            select(Instrument)
            .where(
                or_(
                    Instrument.symbol == key,
                    Instrument.instrument_id == key,
                    Instrument.ins_code == key,
                    Instrument.isin == key,
                )
            )
            .limit(1)
        )
        return result.scalar_one_or_none()

    async def get_market_watch_snapshot(self) -> list[MarketQuote]:
        result = await self.db.execute(
            select(MarketQuote).order_by(MarketQuote.instrument_id.asc(), MarketQuote.event_time.desc())
        )
        latest: dict[str, MarketQuote] = {}
        for quote in result.scalars().all():
            latest.setdefault(quote.instrument_id, quote)
        return list(latest.values())

    async def get_latest_client_types(self, symbol_or_instrument_id: str) -> ClientType | None:
        instrument = await self.get_symbol(symbol_or_instrument_id)
        instrument_id = instrument.instrument_id if instrument is not None else symbol_or_instrument_id
        result = await self.db.execute(
            select(ClientType)
            .where(ClientType.instrument_id == instrument_id)
            .order_by(desc(ClientType.trade_date))
            .limit(1)
        )
        return result.scalar_one_or_none()

    async def get_latest_order_book(self, symbol_or_instrument_id: str) -> list[OrderBook]:
        instrument = await self.get_symbol(symbol_or_instrument_id)
        instrument_id = instrument.instrument_id if instrument is not None else symbol_or_instrument_id
        latest_time = await self.db.execute(
            select(OrderBook.event_time)
            .where(OrderBook.instrument_id == instrument_id)
            .order_by(desc(OrderBook.event_time))
            .limit(1)
        )
        event_time = latest_time.scalar_one_or_none()
        if event_time is None:
            return []
        result = await self.db.execute(
            select(OrderBook)
            .where(
                OrderBook.instrument_id == instrument_id,
                OrderBook.event_time == event_time,
            )
            .order_by(OrderBook.level.asc())
        )
        return list(result.scalars().all())

    async def get_indices_latest(self) -> list[MarketIndex]:
        result = await self.db.execute(
            select(MarketIndex).order_by(MarketIndex.index_code.asc(), MarketIndex.event_time.desc())
        )
        latest: dict[str, MarketIndex] = {}
        for index in result.scalars().all():
            latest.setdefault(index.index_code, index)
        return list(latest.values())

    async def get_latest_market_overview(self) -> MarketOverview | None:
        result = await self.db.execute(
            select(MarketOverview)
            .order_by(desc(MarketOverview.price_info_timestamp))
            .limit(1)
        )
        return result.scalar_one_or_none()

    async def list_disclosures(
        self,
        *,
        symbol: str | None = None,
        category: str | None = None,
        from_date: date | None = None,
        to_date: date | None = None,
        has_attachment: bool | None = None,
        limit: int = 50,
        offset: int = 0,
    ) -> list[Disclosure]:
        statement = select(Disclosure)
        if symbol:
            statement = statement.where(Disclosure.symbol == symbol.strip())
        if category:
            statement = statement.where(Disclosure.category == category.strip())
        if from_date:
            statement = statement.where(
                Disclosure.published_at >= datetime.combine(from_date, time.min, tzinfo=UTC)
            )
        if to_date:
            statement = statement.where(
                Disclosure.published_at
                < datetime.combine(to_date + timedelta(days=1), time.min, tzinfo=UTC)
            )
        if has_attachment is not None:
            statement = statement.where(Disclosure.has_attachment.is_(has_attachment))
        result = await self.db.execute(
            statement
            .order_by(desc(Disclosure.published_at).nullslast(), desc(Disclosure.created_at))
            .limit(min(max(limit, 1), 200))
            .offset(max(offset, 0))
        )
        return list(result.scalars().all())

    async def get_disclosure(self, tracking_number: str) -> Disclosure | None:
        result = await self.db.execute(
            select(Disclosure).where(Disclosure.tracking_number == tracking_number)
        )
        return result.scalar_one_or_none()

    async def list_funds(
        self,
        *,
        fund_type: str | None = None,
        limit: int = 100,
        offset: int = 0,
    ) -> list[Fund]:
        statement = select(Fund)
        if fund_type:
            statement = statement.where(Fund.type.ilike(f"%{fund_type.strip()}%"))
        result = await self.db.execute(
            statement.order_by(Fund.name.asc()).limit(min(max(limit, 1), 500)).offset(max(offset, 0))
        )
        return list(result.scalars().all())

    async def get_fund(self, fund_id: str) -> Fund | None:
        result = await self.db.execute(select(Fund).where(Fund.fund_id == fund_id))
        return result.scalar_one_or_none()

    async def get_latest_fund_nav(self, fund_id: str) -> FundNavHistory | None:
        result = await self.db.execute(
            select(FundNavHistory)
            .where(FundNavHistory.fund_id == fund_id)
            .order_by(desc(FundNavHistory.nav_date))
            .limit(1)
        )
        return result.scalar_one_or_none()

    # ═══════════════════════════════════════════════════════════════
    # Asset Queries
    # ═══════════════════════════════════════════════════════════════

    async def list_active_tsetmc_assets(self) -> list[Asset]:
        """List all active assets with TSETMC IDs for sync."""
        result = await self.db.execute(
            select(Asset).where(
                Asset.is_active.is_(True),
                Asset.tsetmc_id.isnot(None),
            )
        )
        return list(result.scalars().all())

    async def list_unlinked_active_tsetmc_assets(self) -> list[Asset]:
        """List active TSETMC assets that still need an instrument ID."""
        result = await self.db.execute(
            select(Asset).where(
                Asset.is_active.is_(True),
                Asset.exchange == "TSETMC",
                Asset.tsetmc_id.is_(None),
            )
        )
        return list(result.scalars().all())

    async def get_asset_by_tsetmc_id(self, tsetmc_id: str) -> Asset | None:
        """Get asset by TSETMC instrument code."""
        result = await self.db.execute(
            select(Asset).where(Asset.tsetmc_id == tsetmc_id)
        )
        return result.scalar_one_or_none()

    async def get_asset_by_id(self, asset_id: uuid.UUID) -> Asset | None:
        """Get asset by UUID."""
        result = await self.db.execute(
            select(Asset).where(Asset.id == asset_id)
        )
        return result.scalar_one_or_none()

    # ═══════════════════════════════════════════════════════════════
    # Live Price Updates (Asset Table)
    # ═══════════════════════════════════════════════════════════════

    async def update_asset_live_price(
        self,
        *,
        asset_id: uuid.UUID,
        price: Decimal,
        tradeable: bool,
        updated_at: datetime,
        last_price: Decimal | None = None,
        closing_price: Decimal | None = None,
    ) -> None:
        """Update asset's live price in the assets table."""
        effective_closing_price = closing_price or price
        effective_last_price = last_price or price
        await self.db.execute(
            update(Asset)
            .where(Asset.id == asset_id)
            .values(
                previous_close_price=Asset.closing_price,
                current_price=effective_closing_price,
                closing_price=effective_closing_price,
                last_trade_price=effective_last_price,
                is_tradeable=tradeable,
                price_updated_at=updated_at,
            )
        )

    async def bulk_update_asset_prices(
        self,
        updates: list[dict],
    ) -> int:
        """Batch update multiple asset prices.

        Args:
            updates: List of dicts with keys: asset_id, closing_price,
                last_price, tradeable, updated_at.

        Returns:
            Number of assets updated.
        """
        if not updates:
            return 0

        payload = [
            {
                "b_asset_id": item["asset_id"],
                "b_current_price": item.get("closing_price", item.get("price")),
                "b_closing_price": item.get("closing_price", item.get("price")),
                "b_last_trade_price": item.get("last_price", item.get("price")),
                "b_tradeable": item["tradeable"],
                "b_updated_at": item["updated_at"],
            }
            for item in updates
        ]
        statement = (
            update(Asset.__table__)
            .where(Asset.__table__.c.id == bindparam("b_asset_id"))
            .values(
                previous_close_price=Asset.__table__.c.closing_price,
                current_price=bindparam("b_current_price"),
                closing_price=bindparam("b_closing_price"),
                last_trade_price=bindparam("b_last_trade_price"),
                is_tradeable=bindparam("b_tradeable"),
                price_updated_at=bindparam("b_updated_at"),
            )
        )
        await self.db.execute(statement, payload)
        return len(payload)

    # ═══════════════════════════════════════════════════════════════
    # Daily Price History (Idempotent Upsert)
    # ═══════════════════════════════════════════════════════════════

    async def upsert_asset_price_history(
        self,
        *,
        asset_id: uuid.UUID,
        price_date: date,
        open_price: Decimal,
        high_price: Decimal,
        low_price: Decimal,
        close_price: Decimal,
        adjusted_close: Decimal,
        adjustment_factor: Decimal,
        volume: int,
        last_trade_price: Decimal | None = None,
    ) -> None:
        """Upsert a single daily price record (idempotent).

        Uses PostgreSQL ON CONFLICT to handle duplicate (asset_id, date) pairs.
        """
        statement = pg_insert(DailyPrice).values(
            asset_id=asset_id,
            price_time=datetime.combine(price_date, time.min, tzinfo=UTC),
            date=price_date,
            open_price=open_price,
            high_price=high_price,
            low_price=low_price,
            close_price=close_price,
            last_trade_price=last_trade_price or close_price,
            adjusted_close=adjusted_close,
            adjustment_factor=adjustment_factor,
            volume=volume,
        )
        statement = statement.on_conflict_do_update(
            index_elements=["asset_id", "date"],
            set_={
                "open_price": open_price,
                "high_price": high_price,
                "low_price": low_price,
                "close_price": close_price,
                "last_trade_price": last_trade_price or close_price,
                "adjusted_close": adjusted_close,
                "adjustment_factor": adjustment_factor,
                "volume": volume,
                "price_time": datetime.combine(price_date, time.min, tzinfo=UTC),
            },
        )
        await self.db.execute(statement)

    async def bulk_upsert_price_history(
        self,
        records: list[dict],
    ) -> int:
        """Batch upsert multiple daily price records.

        Args:
            records: List of dicts with price history fields.

        Returns:
            Number of records successfully upserted.
        """
        if not records:
            return 0

        count = 0
        for record in records:
            try:
                await self.upsert_asset_price_history(**record)
                count += 1
            except Exception as exc:
                logger.warning(
                    "bulk_upsert_price_history failed for asset=%s date=%s: %s",
                    record.get("asset_id"),
                    record.get("price_date"),
                    exc,
                )

        return count

    async def save_symbol_history(
        self,
        *,
        asset_id: uuid.UUID,
        bars: list[dict],
    ) -> int:
        """Save historical price bars for a symbol.

        Args:
            asset_id: Asset UUID.
            bars: List of dicts with OHLCV fields.

        Returns:
            Number of bars saved.
        """
        if not bars:
            return 0

        records = []
        for bar in bars:
            records.append({
                "asset_id": asset_id,
                "price_date": bar["date"],
                "open_price": bar["open_price"],
                "high_price": bar["high_price"],
                "low_price": bar["low_price"],
                "close_price": bar["close_price"],
                "last_trade_price": bar.get("last_trade_price", bar["close_price"]),
                "adjusted_close": bar.get("adjusted_close", bar["close_price"]),
                "adjustment_factor": bar.get("adjustment_factor", Decimal("1.0000")),
                "volume": bar.get("volume", 0),
            })

        return await self.bulk_upsert_price_history(records)

    # ═══════════════════════════════════════════════════════════════
    # Price History Queries
    # ═══════════════════════════════════════════════════════════════

    async def fetch_asset_price_rows(
        self,
        *,
        asset_ids: list[uuid.UUID],
        end_date: date,
    ) -> list[DailyPrice]:
        """Fetch price history for multiple assets up to end_date."""
        if not asset_ids:
            return []

        result = await self.db.execute(
            select(DailyPrice)
            .where(
                DailyPrice.asset_id.in_(asset_ids),
                DailyPrice.date <= end_date,
            )
            .order_by(DailyPrice.asset_id.asc(), DailyPrice.date.asc())
        )
        return list(result.scalars().all())

    async def fetch_latest_asset_price(
        self,
        *,
        asset_id: uuid.UUID,
        price_date: date,
    ) -> DailyPrice | None:
        """Fetch the latest price record for an asset up to price_date."""
        result = await self.db.execute(
            select(DailyPrice)
            .where(
                DailyPrice.asset_id == asset_id,
                DailyPrice.date <= price_date,
            )
            .order_by(DailyPrice.date.desc())
            .limit(1)
        )
        return result.scalar_one_or_none()

    async def get_symbol_history(
        self,
        symbol: str | None = None,
        from_date: date | None = None,
        to_date: date | None = None,
        *,
        asset_id: uuid.UUID | None = None,
        start_date: date | None = None,
        end_date: date | None = None,
    ) -> list[DailyPrice]:
        """Get price history by legacy asset id or normalized symbol/instrument id.

        Returns:
            List of DailyPrice sorted by date ascending.
        """
        start = start_date or from_date
        end = end_date or to_date
        if start is None or end is None:
            raise ValueError("start_date/from_date and end_date/to_date are required")

        if asset_id is None and symbol is not None:
            instrument_result = await self.db.execute(
                select(Instrument.instrument_id).where(
                    or_(
                        Instrument.symbol == symbol,
                        Instrument.instrument_id == symbol,
                        Instrument.ins_code == symbol,
                    )
                )
            )
            instrument_id = instrument_result.scalar_one_or_none() or symbol
            result = await self.db.execute(
                select(DailyPrice)
                .where(
                    DailyPrice.instrument_id == instrument_id,
                    DailyPrice.date >= start,
                    DailyPrice.date <= end,
                )
                .order_by(DailyPrice.date.asc())
            )
            return list(result.scalars().all())

        if asset_id is None:
            raise ValueError("asset_id or symbol is required")

        result = await self.db.execute(
            select(DailyPrice)
            .where(
                DailyPrice.asset_id == asset_id,
                DailyPrice.date >= start,
                DailyPrice.date <= end,
            )
            .order_by(DailyPrice.date.asc())
        )
        return list(result.scalars().all())

    async def get_latest_price_for_assets(
        self,
        asset_ids: list[uuid.UUID],
    ) -> dict[uuid.UUID, DailyPrice]:
        """Get the latest price for each asset.

        Returns:
            Dict mapping asset_id to its latest DailyPrice.
        """
        if not asset_ids:
            return {}

        result: dict[uuid.UUID, DailyPrice] = {}
        for asset_id in asset_ids:
            price = await self.fetch_latest_asset_price(
                asset_id=asset_id,
                price_date=date.today(),
            )
            if price is not None:
                result[asset_id] = price

        return result

    # ═══════════════════════════════════════════════════════════════
    # Benchmark History
    # ═══════════════════════════════════════════════════════════════

    async def upsert_benchmark_history(
        self,
        *,
        benchmark_type: BenchmarkType,
        price_date: date,
        open_price: Decimal,
        high_price: Decimal,
        low_price: Decimal,
        close_price: Decimal,
        adjusted_close: Decimal,
        adjustment_factor: Decimal,
        volume: int | None,
        source: str,
    ) -> None:
        """Upsert a benchmark history record (idempotent)."""
        statement = pg_insert(BenchmarkHistory).values(
            benchmark_type=benchmark_type,
            date=price_date,
            open_price=open_price,
            high_price=high_price,
            low_price=low_price,
            close_price=close_price,
            adjusted_close=adjusted_close,
            adjustment_factor=adjustment_factor,
            volume=volume,
            source=source,
        )
        statement = statement.on_conflict_do_update(
            index_elements=["benchmark_type", "date"],
            set_={
                "open_price": open_price,
                "high_price": high_price,
                "low_price": low_price,
                "close_price": close_price,
                "adjusted_close": adjusted_close,
                "adjustment_factor": adjustment_factor,
                "volume": volume,
                "source": source,
            },
        )
        await self.db.execute(statement)

    async def fetch_benchmark_rows(
        self,
        *,
        benchmark_types: list[BenchmarkType],
        start_date: date,
        end_date: date,
    ) -> list[BenchmarkHistory]:
        """Fetch benchmark history for given types and date range."""
        result = await self.db.execute(
            select(BenchmarkHistory)
            .where(
                BenchmarkHistory.benchmark_type.in_(benchmark_types),
                BenchmarkHistory.date >= start_date,
                BenchmarkHistory.date <= end_date,
            )
            .order_by(BenchmarkHistory.benchmark_type.asc(), BenchmarkHistory.date.asc())
        )
        return list(result.scalars().all())

    async def get_benchmark_history(
        self,
        *,
        benchmark_type: BenchmarkType,
        start_date: date,
        end_date: date,
    ) -> list[BenchmarkHistory]:
        """Get benchmark history for a single type within date range."""
        return await self.fetch_benchmark_rows(
            benchmark_types=[benchmark_type],
            start_date=start_date,
            end_date=end_date,
        )

    # ═══════════════════════════════════════════════════════════════
    # Sync Metadata (via Asset table)
    # ═══════════════════════════════════════════════════════════════

    async def update_sync_metadata(
        self,
        *,
        asset_id: uuid.UUID,
        last_synced_at: datetime,
        sync_status: str = "success",
    ) -> None:
        """Update sync metadata for an asset.

        This stores sync status in the asset's display_metadata JSONB field
        to avoid creating a separate table.
        """
        asset = await self.get_asset_by_id(asset_id)
        if asset is None:
            return

        metadata = asset.display_metadata or {}
        metadata["last_synced_at"] = last_synced_at.isoformat()
        metadata["sync_status"] = sync_status

        await self.db.execute(
            update(Asset)
            .where(Asset.id == asset_id)
            .values(display_metadata=metadata)
        )

    async def get_sync_metadata(
        self,
        asset_id: uuid.UUID,
    ) -> dict[str, Any] | None:
        """Get sync metadata for an asset."""
        asset = await self.get_asset_by_id(asset_id)
        if asset is None:
            return None

        metadata = asset.display_metadata or {}
        return {
            "last_synced_at": metadata.get("last_synced_at"),
            "sync_status": metadata.get("sync_status"),
        }

    # ═══════════════════════════════════════════════════════════════
    # Transaction Support
    # ═══════════════════════════════════════════════════════════════

    async def commit(self) -> None:
        """Commit the current transaction."""
        await self.db.commit()

    async def rollback(self) -> None:
        """Rollback the current transaction."""
        await self.db.rollback()
