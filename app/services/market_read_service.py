"""Read-side market service for Flutter-facing FastAPI contracts."""

from __future__ import annotations

from datetime import UTC, date, datetime, timedelta
from decimal import Decimal, InvalidOperation
from typing import TYPE_CHECKING, Any

from app.core import market_cache
from app.schemas.market_api import (
    ClientTypesResponse,
    MarketWatchResponse,
    NormalizedPriceBarResponse,
    OrderBookLevelResponse,
    OrderBookResponse,
    QuoteResponse,
    SymbolHistoryNormalizedResponse,
    SymbolListResponse,
    SymbolResponse,
)
from app.services.market_overview_service import as_datetime, calculate_freshness
from app.services.tehran_market_calendar import TEHRAN_TZ, TRADING_WEEKDAYS, configured_holidays, get_market_session

if TYPE_CHECKING:
    from app.repositories.market_data import MarketDataRepository


def _field(item: Any, name: str, default: Any = None) -> Any:
    if isinstance(item, dict):
        return item.get(name, default)
    return getattr(item, name, default)


def _decimal(value: Any) -> Decimal | None:
    if value is None:
        return None
    if isinstance(value, Decimal):
        return value
    try:
        return Decimal(str(value))
    except (InvalidOperation, ValueError):
        return None


def _decimal_string(value: Any) -> str | None:
    parsed = _decimal(value)
    return str(parsed) if parsed is not None else None


def _quote_time(item: Any) -> datetime | None:
    return as_datetime(_field(item, "event_time")) or as_datetime(_field(item, "received_at"))


def _quality_for_latest(latest: datetime | None, now: datetime) -> tuple[str, bool, bool, str]:
    session = get_market_session(now)
    if latest is None:
        return "unavailable", False, True, session.market_status
    _, stale_by_age = calculate_freshness(latest, now=now)
    same_session = latest.astimezone(TEHRAN_TZ).date() == session.session_date
    is_current = bool(session.is_market_open and same_session and not stale_by_age)
    is_stale = not is_current
    quality = "current" if is_current else "stale"
    return quality, is_current, is_stale, session.market_status


def build_quote_response(item: Any, *, now: datetime | None = None) -> QuoteResponse:
    checked_at = now or datetime.now(UTC)
    event_time = _quote_time(item)
    _, is_current, is_stale, market_status = _quality_for_latest(event_time, checked_at)
    last_price = _decimal(_field(item, "last_price"))
    closing_price = _decimal(_field(item, "closing_price"))
    yesterday_price = _decimal(_field(item, "yesterday_price"))
    effective_price = last_price if last_price is not None else closing_price
    price_change = (
        effective_price - yesterday_price
        if effective_price is not None and yesterday_price is not None
        else None
    )
    price_change_percent = (
        (price_change / yesterday_price) * Decimal("100")
        if price_change is not None and yesterday_price not in (None, Decimal("0"))
        else None
    )
    return QuoteResponse(
        symbol=str(_field(item, "symbol", "")),
        instrument_id=_field(item, "instrument_id"),
        last_price=_decimal_string(effective_price),
        closing_price=_decimal_string(closing_price if closing_price is not None else last_price),
        yesterday_price=_decimal_string(yesterday_price),
        price_change=_decimal_string(price_change),
        price_change_percent=_decimal_string(price_change_percent),
        volume=int(_field(item, "volume", 0) or 0),
        value=_decimal_string(_field(item, "value")),
        trade_count=int(_field(item, "trade_count", 0) or 0),
        trade_date=_field(item, "trade_date"),
        event_time=event_time,
        received_at=as_datetime(_field(item, "received_at")),
        market_status=market_status,
        is_current_session=is_current,
        is_stale=is_stale,
        source=str(_field(item, "source", "UNKNOWN")),
    )


def build_symbol_response(item: Any) -> SymbolResponse:
    return SymbolResponse(
        symbol=str(_field(item, "symbol", "")),
        instrument_id=_field(item, "instrument_id"),
        ins_code=_field(item, "ins_code"),
        isin=_field(item, "isin"),
        company_name=_field(item, "company_name"),
        market=_field(item, "market"),
        board=_field(item, "board"),
        sector_code=_field(item, "sector_code"),
        sector_name=_field(item, "sector_name"),
        instrument_type=_field(item, "instrument_type"),
        is_active=bool(_field(item, "is_active", True)),
    )


class MarketReadService:
    """Composes Redis latest snapshots and PostgreSQL history for API routes."""

    def __init__(self, repository: "MarketDataRepository") -> None:
        self.repository = repository

    async def latest_quote(self, symbol_or_instrument_id: str) -> QuoteResponse | None:
        cached = await market_cache.get_market_quote(symbol_or_instrument_id)
        item = cached or await self.repository.get_latest_quote(symbol_or_instrument_id)
        return build_quote_response(item) if item is not None else None

    async def market_watch(self, *, page: int, page_size: int, compact: bool) -> MarketWatchResponse:
        checked_at = datetime.now(UTC)
        cached = await market_cache.get_market_watch_snapshot()
        rows = cached if cached is not None else await self.repository.get_market_watch_snapshot()
        ordered = sorted(rows, key=lambda item: str(_field(item, "symbol", "")))
        start = (page - 1) * page_size
        selected = ordered[start:start + page_size]
        items = [build_quote_response(item, now=checked_at) for item in selected]
        latest = max((_quote_time(item) for item in rows), default=None)
        quality, is_current, is_stale, market_status = _quality_for_latest(latest, checked_at)
        source = next((item.source for item in items if item.source), "UNKNOWN")
        return MarketWatchResponse(
            items=items,
            page=page,
            page_size=page_size,
            count=len(ordered),
            compact=compact,
            server_time=checked_at,
            data_quality_status=quality,
            market_status=market_status,
            is_current_session=is_current,
            is_stale=is_stale,
            source=source,
        )

    async def list_symbols(
        self,
        *,
        query: str | None,
        active_only: bool,
        page: int,
        page_size: int,
    ) -> SymbolListResponse:
        rows = await self.repository.list_symbols(
            query=query,
            active_only=active_only,
            limit=page_size,
            offset=(page - 1) * page_size,
        )
        return SymbolListResponse(
            items=[build_symbol_response(item) for item in rows],
            page=page,
            page_size=page_size,
            count=len(rows),
        )

    async def get_symbol(self, symbol_or_instrument_id: str) -> SymbolResponse | None:
        item = await self.repository.get_symbol(symbol_or_instrument_id)
        return build_symbol_response(item) if item is not None else None

    async def history(
        self,
        *,
        symbol: str,
        start_date: date,
        end_date: date,
    ) -> SymbolHistoryNormalizedResponse:
        instrument = await self.repository.get_symbol(symbol)
        instrument_id = instrument.instrument_id if instrument is not None else symbol
        rows = await self.repository.get_symbol_history(
            symbol=instrument_id,
            start_date=start_date,
            end_date=end_date,
        )
        by_date = {_field(row, "date"): row for row in rows}
        holidays = configured_holidays()
        expected_dates: list[date] = []
        non_trading_dates: list[date] = []
        cursor = start_date
        while cursor <= end_date:
            if cursor.weekday() in TRADING_WEEKDAYS and cursor not in holidays:
                expected_dates.append(cursor)
            else:
                non_trading_dates.append(cursor)
            cursor += timedelta(days=1)
        missing_dates = [item for item in expected_dates if item not in by_date]
        bars = [
            NormalizedPriceBarResponse(
                trade_date=_field(row, "date"),
                open_price=_decimal_string(_field(row, "open_price")),
                high_price=_decimal_string(_field(row, "high_price")),
                low_price=_decimal_string(_field(row, "low_price")),
                closing_price=_decimal_string(_field(row, "close_price")),
                last_price=_decimal_string(_field(row, "last_trade_price")),
                yesterday_price=_decimal_string(_field(row, "yesterday_price")),
                adjusted_close=_decimal_string(_field(row, "adjusted_close")),
                volume=int(_field(row, "volume", 0) or 0),
                value=_decimal_string(_field(row, "value")),
                trade_count=int(_field(row, "trade_count", 0) or 0),
                source=str(_field(row, "source", "UNKNOWN")),
            )
            for row in rows
        ]
        quality = "current" if bars and not missing_dates else ("stale" if bars else "unavailable")
        return SymbolHistoryNormalizedResponse(
            symbol=instrument.symbol if instrument is not None else symbol,
            instrument_id=instrument_id,
            period={
                "from_date": start_date.isoformat(),
                "to_date": end_date.isoformat(),
                "requested_days": (end_date - start_date).days + 1,
                "trading_days_expected": len(expected_dates),
            },
            bars=bars,
            missing_dates=missing_dates,
            non_trading_dates=non_trading_dates,
            count=len(bars),
            data_quality_status=quality,
        )

    async def latest_client_types(self, symbol: str) -> ClientTypesResponse | None:
        instrument = await self.repository.get_symbol(symbol)
        item = await self.repository.get_latest_client_types(symbol)
        if item is None:
            return None
        return ClientTypesResponse(
            symbol=instrument.symbol if instrument is not None else symbol,
            instrument_id=_field(item, "instrument_id"),
            trade_date=_field(item, "trade_date"),
            individual_buy_count=int(_field(item, "individual_buy_count", 0) or 0),
            individual_buy_volume=int(_field(item, "individual_buy_volume", 0) or 0),
            individual_sell_count=int(_field(item, "individual_sell_count", 0) or 0),
            individual_sell_volume=int(_field(item, "individual_sell_volume", 0) or 0),
            legal_buy_count=int(_field(item, "legal_buy_count", 0) or 0),
            legal_buy_volume=int(_field(item, "legal_buy_volume", 0) or 0),
            legal_sell_count=int(_field(item, "legal_sell_count", 0) or 0),
            legal_sell_volume=int(_field(item, "legal_sell_volume", 0) or 0),
        )

    async def latest_order_book(self, symbol: str) -> OrderBookResponse | None:
        instrument = await self.repository.get_symbol(symbol)
        rows = await self.repository.get_latest_order_book(symbol)
        if not rows:
            return None
        return OrderBookResponse(
            symbol=instrument.symbol if instrument is not None else symbol,
            instrument_id=_field(rows[0], "instrument_id"),
            event_time=as_datetime(_field(rows[0], "event_time")),
            levels=[
                OrderBookLevelResponse(
                    level=int(_field(row, "level", 0) or 0),
                    buy_price=_decimal_string(_field(row, "buy_price")),
                    buy_volume=_field(row, "buy_volume"),
                    buy_count=_field(row, "buy_count"),
                    sell_price=_decimal_string(_field(row, "sell_price")),
                    sell_volume=_field(row, "sell_volume"),
                    sell_count=_field(row, "sell_count"),
                )
                for row in rows
            ],
        )
