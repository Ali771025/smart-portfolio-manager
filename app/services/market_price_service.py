"""Canonical market price selection for valuation, PnL, reports, and charts."""

from __future__ import annotations

import uuid
from dataclasses import dataclass
from datetime import UTC, date, datetime
from decimal import Decimal, InvalidOperation
from typing import Any, Literal

from app.core.config import settings
from app.services.money_normalization import MoneyUnit, normalize_market_price
from app.services.symbol_normalization import normalize_symbol_key
from app.services.tehran_market_calendar import TEHRAN_TZ, get_market_session

PriceUseCase = Literal["live", "eod", "history", "history_adjusted"]


def _decimal(value: Any) -> Decimal | None:
    if value is None:
        return None
    if isinstance(value, Decimal):
        parsed = value
    else:
        try:
            parsed = Decimal(str(value))
        except (InvalidOperation, ValueError):
            return None
    return parsed if parsed > 0 else None


def _aware(value: datetime | None) -> datetime | None:
    if value is None:
        return None
    return value if value.tzinfo is not None else value.replace(tzinfo=UTC)


@dataclass(slots=True, frozen=True)
class SelectedMarketPrice:
    asset_id: uuid.UUID | None
    symbol: str
    instrument_id: str | None
    last_price: Decimal | None
    closing_price: Decimal | None
    yesterday_price: Decimal | None
    selected_valuation_price: Decimal | None
    selected_price_source: str
    price_as_of: datetime | None
    is_stale: bool
    is_current_session: bool
    market_status: str
    data_quality_status: str
    status: str
    source: str
    normalized_symbol: str = ""
    price_age_seconds: int | None = None
    warnings: tuple[str, ...] = ()

    @property
    def has_price(self) -> bool:
        return self.selected_valuation_price is not None

    @property
    def fallback_used(self) -> bool:
        return self.selected_price_source == "fallback"


class MarketPriceService:
    """Single selector for market prices used by portfolio calculations."""

    def __init__(self, *, stale_after_seconds: int | None = None) -> None:
        self.stale_after_seconds = (
            stale_after_seconds
            if stale_after_seconds is not None
            else settings.TSETMC_SYNC_INTERVAL_MINUTES * 60 * 2
        )

    def select_from_asset(
        self,
        asset: Any,
        *,
        use_case: PriceUseCase = "live",
        now: datetime | None = None,
        source_unit: MoneyUnit | str = MoneyUnit.IRR,
        target_unit: MoneyUnit | str = MoneyUnit.IRR,
    ) -> SelectedMarketPrice:
        return self.select(
            asset_id=getattr(asset, "id", None),
            symbol=str(getattr(asset, "ticker_symbol", getattr(asset, "symbol", ""))),
            instrument_id=getattr(asset, "tsetmc_id", None),
            last_price=getattr(asset, "last_trade_price", getattr(asset, "last_price", None)),
            closing_price=getattr(asset, "closing_price", None),
            final_price=getattr(asset, "final_price", getattr(asset, "current_price", None)),
            adjusted_close=getattr(asset, "adjusted_close", None),
            yesterday_price=getattr(asset, "previous_close_price", getattr(asset, "yesterday_price", None)),
            price_as_of=getattr(asset, "price_updated_at", getattr(asset, "updated_at", None)),
            is_tradeable=bool(getattr(asset, "is_tradeable", True)),
            source=str(getattr(asset, "source", "ASSET")),
            use_case=use_case,
            now=now,
            source_unit=source_unit,
            target_unit=target_unit,
        )

    def select_from_daily_bar(
        self,
        row: Any,
        *,
        symbol: str = "",
        adjusted: bool = False,
        now: datetime | None = None,
    ) -> SelectedMarketPrice:
        row_date = getattr(row, "date", None)
        as_of = getattr(row, "price_time", None)
        if as_of is None and isinstance(row_date, date):
            as_of = datetime.combine(row_date, datetime.min.time(), tzinfo=UTC)
        return self.select(
            asset_id=getattr(row, "asset_id", None),
            symbol=symbol,
            instrument_id=getattr(row, "instrument_id", None),
            last_price=getattr(row, "last_trade_price", None),
            closing_price=getattr(row, "close_price", None),
            final_price=getattr(row, "final_price", None),
            adjusted_close=getattr(row, "adjusted_close", None),
            yesterday_price=getattr(row, "yesterday_price", None),
            price_as_of=as_of,
            source=str(getattr(row, "source", "DAILY_PRICE")),
            use_case="history_adjusted" if adjusted else "history",
            now=now,
        )

    def select(
        self,
        *,
        asset_id: uuid.UUID | None,
        symbol: str,
        instrument_id: str | None,
        last_price: Any = None,
        closing_price: Any = None,
        final_price: Any = None,
        adjusted_close: Any = None,
        yesterday_price: Any = None,
        price_as_of: datetime | None = None,
        is_tradeable: bool = True,
        source: str = "UNKNOWN",
        use_case: PriceUseCase = "live",
        now: datetime | None = None,
        source_unit: MoneyUnit | str = MoneyUnit.IRR,
        target_unit: MoneyUnit | str = MoneyUnit.IRR,
    ) -> SelectedMarketPrice:
        checked_at = _aware(now) or datetime.now(UTC)
        as_of = _aware(price_as_of)
        session = get_market_session(checked_at)
        normalized_symbol = normalize_symbol_key(symbol)
        last = normalize_market_price(last_price, source_unit=source_unit, target_unit=target_unit)
        close = normalize_market_price(closing_price, source_unit=source_unit, target_unit=target_unit)
        final = normalize_market_price(final_price, source_unit=source_unit, target_unit=target_unit)
        adjusted = normalize_market_price(adjusted_close, source_unit=source_unit, target_unit=target_unit)
        previous = _decimal(yesterday_price)

        selected: Decimal | None = None
        selected_source = "missing"
        status = "missing_price"

        if use_case == "live":
            if last is not None:
                selected = last
                selected_source = "last_price"
                status = "ok"
            elif close is not None:
                selected = close
                selected_source = "fallback"
                status = "closing_price_fallback"
        elif use_case == "eod":
            if close is not None:
                selected = close
                selected_source = "closing_price"
                status = "ok"
            elif final is not None:
                selected = final
                selected_source = "final_price"
                status = "final_price_fallback"
        elif use_case == "history_adjusted":
            if adjusted is not None:
                selected = adjusted
                selected_source = "adjusted_close"
                status = "ok"
            elif close is not None:
                selected = close
                selected_source = "fallback"
                status = "closing_price_fallback"
        else:
            if close is not None:
                selected = close
                selected_source = "closing_price"
                status = "ok"

        if not is_tradeable and status == "ok":
            status = "halted"

        age_seconds = None if as_of is None else int((checked_at - as_of).total_seconds())
        is_stale = selected is None or as_of is None or (
            age_seconds is not None and age_seconds > self.stale_after_seconds
        )
        warnings: list[str] = []
        if selected is None:
            warnings.append("missing_market_price")
        elif is_stale:
            warnings.append("outdated_market_price")
        is_current_session = bool(
            selected is not None
            and as_of is not None
            and session.is_market_open
            and as_of.astimezone(TEHRAN_TZ).date() == session.session_date
            and not is_stale
        )
        if selected is None:
            quality = "missing"
        elif is_stale:
            quality = "stale"
        elif selected_source == "fallback":
            quality = "fallback"
        else:
            quality = "current"

        return SelectedMarketPrice(
            asset_id=asset_id,
            symbol=symbol,
            instrument_id=instrument_id,
            last_price=last,
            closing_price=close,
            yesterday_price=previous,
            selected_valuation_price=selected,
            selected_price_source=selected_source,
            price_as_of=as_of,
            normalized_symbol=normalized_symbol,
            price_age_seconds=age_seconds,
            warnings=tuple(warnings),
            is_stale=is_stale,
            is_current_session=is_current_session,
            market_status=session.market_status,
            data_quality_status=quality,
            status=status,
            source=source,
        )
