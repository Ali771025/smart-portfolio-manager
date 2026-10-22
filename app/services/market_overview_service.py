"""Pure market overview response and freshness helpers."""

from __future__ import annotations

from datetime import UTC, datetime
from decimal import Decimal
from typing import Any

from app.core.config import settings
from app.schemas.market_api import MarketOverviewResponse
from app.services.tehran_market_calendar import TEHRAN_TZ, get_market_session


def as_datetime(value: Any) -> datetime | None:
    if isinstance(value, datetime):
        return value if value.tzinfo else value.replace(tzinfo=UTC)
    if isinstance(value, str):
        try:
            parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
            return parsed if parsed.tzinfo else parsed.replace(tzinfo=UTC)
        except ValueError:
            return None
    return None


def overview_field(item: Any, name: str, default: Any = None) -> Any:
    if isinstance(item, dict):
        return item.get(name, default)
    return getattr(item, name, default)


def calculate_freshness(
    fetched_at: datetime | None,
    *,
    now: datetime | None = None,
) -> tuple[int | None, bool]:
    if fetched_at is None:
        return None, True
    checked_at = now or datetime.now(UTC)
    if fetched_at.tzinfo is None:
        fetched_at = fetched_at.replace(tzinfo=UTC)
    seconds = int((checked_at - fetched_at).total_seconds())
    threshold = settings.TSETMC_SYNC_INTERVAL_MINUTES * 60 * 2
    return seconds, seconds > threshold


def market_metadata(item: Any, *, now: datetime | None = None) -> dict[str, Any]:
    checked_at = now or datetime.now(UTC)
    session = get_market_session(checked_at)
    price_time = as_datetime(overview_field(item, "price_info_timestamp"))
    received_at = as_datetime(overview_field(item, "server_received_at"))
    same_session_date = (
        price_time is not None
        and price_time.astimezone(TEHRAN_TZ).date() == session.session_date
    )
    is_current_session = bool(session.is_market_open and same_session_date)
    _, stale_by_age = calculate_freshness(price_time, now=checked_at)
    if price_time is None:
        quality = "unavailable"
    elif is_current_session and not stale_by_age:
        quality = "current"
    else:
        quality = "stale"
    return {
        "market_status": session.market_status,
        "is_current_session": is_current_session,
        "data_quality_status": quality,
        "price_info_timestamp": price_time,
        "server_received_at": received_at or checked_at,
    }


def build_market_overview_response(
    item: Any,
    *,
    now: datetime | None = None,
) -> MarketOverviewResponse:
    metadata = market_metadata(item, now=now)
    return MarketOverviewResponse(
        total_index_value=str(overview_field(item, "total_index_value", Decimal("0"))),
        total_index_change=(
            str(overview_field(item, "total_index_change"))
            if overview_field(item, "total_index_change") is not None
            else None
        ),
        equal_weight_index_value=str(
            overview_field(item, "equal_weight_index_value", Decimal("0")),
        ),
        equal_weight_index_change=(
            str(overview_field(item, "equal_weight_index_change"))
            if overview_field(item, "equal_weight_index_change") is not None
            else None
        ),
        market_value=(
            str(overview_field(item, "market_value"))
            if overview_field(item, "market_value") is not None
            else None
        ),
        trades_count=int(overview_field(item, "trades_count", 0) or 0),
        trades_value=(
            str(overview_field(item, "trades_value"))
            if overview_field(item, "trades_value") is not None
            else None
        ),
        trades_volume=int(overview_field(item, "trades_volume", 0) or 0),
        price_info_timestamp=metadata["price_info_timestamp"].isoformat(),
        server_received_at=metadata["server_received_at"].isoformat(),
        market_status=metadata["market_status"],
        is_current_session=metadata["is_current_session"],
        source=str(overview_field(item, "source", "UNKNOWN")),
        data_quality_status=metadata["data_quality_status"],
    )
