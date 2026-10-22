"""Tehran exchange session calendar and freshness classification."""

from __future__ import annotations

from dataclasses import dataclass
from datetime import date, datetime, time
from zoneinfo import ZoneInfo

from app.core.config import settings


TEHRAN_TZ = ZoneInfo("Asia/Tehran")
TRADING_WEEKDAYS = {5, 6, 0, 1, 2}


@dataclass(slots=True, frozen=True)
class MarketSession:
    market_status: str
    is_market_open: bool
    is_trading_day: bool
    session_date: date


def _parse_time(value: str) -> time:
    hour, minute = value.split(":", maxsplit=1)
    return time(hour=int(hour), minute=int(minute))


def configured_holidays() -> set[date]:
    result: set[date] = set()
    for value in settings.TEHRAN_MARKET_HOLIDAYS.split(","):
        value = value.strip()
        if not value:
            continue
        try:
            result.add(date.fromisoformat(value))
        except ValueError:
            continue
    return result


def get_market_session(
    now: datetime | None = None,
    *,
    holidays: set[date] | None = None,
) -> MarketSession:
    current = now or datetime.now(TEHRAN_TZ)
    if current.tzinfo is None:
        current = current.replace(tzinfo=TEHRAN_TZ)
    tehran_now = current.astimezone(TEHRAN_TZ)
    holiday_dates = configured_holidays() if holidays is None else holidays
    is_trading_day = (
        tehran_now.weekday() in TRADING_WEEKDAYS
        and tehran_now.date() not in holiday_dates
    )
    opens_at = _parse_time(settings.TEHRAN_MARKET_OPEN_TIME)
    closes_at = _parse_time(settings.TEHRAN_MARKET_CLOSE_TIME)
    is_open = is_trading_day and opens_at <= tehran_now.time().replace(tzinfo=None) <= closes_at
    return MarketSession(
        market_status="open" if is_open else "closed",
        is_market_open=is_open,
        is_trading_day=is_trading_day,
        session_date=tehran_now.date(),
    )
