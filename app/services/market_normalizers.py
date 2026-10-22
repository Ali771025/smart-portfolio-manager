"""Normalizers for external market-data providers.

Provider implementations should hide external payload quirks here and expose
only the normalized DTOs from ``market_provider`` to services/repositories.
"""

from __future__ import annotations

import re
from datetime import UTC, date, datetime, timedelta, timezone
from decimal import Decimal, InvalidOperation
from typing import Any, Mapping

from app.services.market_provider import (
    CodalDisclosure,
    CodalDisclosureDetail,
    Fund,
    FundNav,
    FundReturn,
    LiveMarketSnapshot,
    MarketIndex,
    MarketOverview,
    MarketQuote,
)
from app.services.symbol_normalization import normalize_symbol_key


ZERO = Decimal("0.0000")
_IRANIAN_DIGIT_TRANSLATION = str.maketrans(
    "۰۱۲۳۴۵۶۷۸۹٠١٢٣٤٥٦٧٨٩",
    "01234567890123456789",
)
_BILLION_SUFFIXES = {"B", "BN", "BILLION", "میلیارد", "ميليارد"}
_MILLION_SUFFIXES = {"M", "MN", "MILLION", "میلیون", "ميليون"}
_THOUSAND_SUFFIXES = {"K", "هزار"}
IRAN_TZ = timezone(timedelta(hours=3, minutes=30))


def normalize_market_symbol(value: Any) -> str:
    """Return one stable key for Persian/Arabic TSETMC symbol variants."""
    return normalize_symbol_key(value)


def _jalali_to_gregorian(year: int, month: int, day: int) -> tuple[int, int, int]:
    """Convert a Jalali date without adding a provider-only dependency."""
    year += 1595
    days = (
        -355668
        + (365 * year)
        + ((year // 33) * 8)
        + (((year % 33) + 3) // 4)
        + day
        + ((month - 1) * 31 if month < 7 else ((month - 7) * 30) + 186)
    )
    gregorian_year = 400 * (days // 146097)
    days %= 146097
    if days > 36524:
        days -= 1
        gregorian_year += 100 * (days // 36524)
        days %= 36524
        if days >= 365:
            days += 1
    gregorian_year += 4 * (days // 1461)
    days %= 1461
    if days > 365:
        gregorian_year += (days - 1) // 365
        days = (days - 1) % 365
    month_days = [31, 29 if gregorian_year % 4 == 0 and (gregorian_year % 100 != 0 or gregorian_year % 400 == 0) else 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
    gregorian_month = 1
    for month_length in month_days:
        if days < month_length:
            break
        days -= month_length
        gregorian_month += 1
    return gregorian_year, gregorian_month, days + 1


def normalize_iranian_digits(value: Any) -> str:
    """Normalize Persian/Arabic digits and separators to ASCII text."""
    return str(value).translate(_IRANIAN_DIGIT_TRANSLATION)


def parse_iranian_decimal(value: Any) -> Decimal | None:
    """Parse Iranian market numeric text without coercing missing values to zero."""
    if value is None:
        return None
    text = normalize_iranian_digits(value).strip()
    if not text or text in {"-", "--", "null", "None"}:
        return None

    multiplier = Decimal("1")
    parts = text.split()
    if len(parts) > 1 and parts[-1].upper() in _BILLION_SUFFIXES | _MILLION_SUFFIXES | _THOUSAND_SUFFIXES:
        suffix = parts[-1].upper()
        text = " ".join(parts[:-1])
    else:
        suffix = text[-1:].upper()
        if suffix in _BILLION_SUFFIXES | _MILLION_SUFFIXES | _THOUSAND_SUFFIXES:
            text = text[:-1]

    if suffix in _BILLION_SUFFIXES:
        multiplier = Decimal("1000000000")
    elif suffix in _MILLION_SUFFIXES:
        multiplier = Decimal("1000000")
    elif suffix in _THOUSAND_SUFFIXES:
        multiplier = Decimal("1000")

    normalized = (
        text.replace(",", "")
        .replace("٬", "")
        .replace("_", "")
        .replace("−", "-")
        .strip()
    )
    if not normalized:
        return None
    try:
        result = Decimal(normalized) * multiplier
        return result if result.is_finite() else None
    except (InvalidOperation, ValueError, TypeError):
        return None


def parse_iranian_int(value: Any) -> int | None:
    parsed = parse_iranian_decimal(value)
    if parsed is None:
        return None
    return int(parsed)


def decimal_or_none(value: Any) -> Decimal | None:
    return parse_iranian_decimal(value)


def _first_value(mapping: Mapping[str, Any], *keys: str) -> Any:
    for key in keys:
        value = mapping.get(key)
        if value is not None and value != "":
            return value
    return None


def _parse_market_timestamp(row: Mapping[str, Any], received_at: datetime) -> datetime:
    direct = _first_value(
        row,
        "price_info_timestamp",
        "priceInfoTimestamp",
        "priceInfoDateTime",
        "event_time",
        "eventTime",
    )
    if isinstance(direct, datetime):
        return direct if direct.tzinfo else direct.replace(tzinfo=IRAN_TZ)
    if direct:
        normalized_direct = normalize_iranian_digits(direct).strip()
        if normalized_direct.isdigit() and len(normalized_direct) == 14:
            try:
                return datetime.strptime(
                    normalized_direct,
                    "%Y%m%d%H%M%S",
                ).replace(tzinfo=IRAN_TZ)
            except ValueError:
                pass
        try:
            parsed = datetime.fromisoformat(normalized_direct.replace("Z", "+00:00"))
            return parsed if parsed.tzinfo else parsed.replace(tzinfo=IRAN_TZ)
        except ValueError:
            pass

    date_value = _first_value(row, "marketActivityDEven", "dEven", "date")
    time_value = _first_value(row, "marketActivityHEven", "hEven", "time")
    if date_value is not None:
        try:
            date_text = str(int(date_value)).zfill(8)
            time_text = str(int(time_value or 0)).zfill(6)
            return datetime.strptime(date_text + time_text, "%Y%m%d%H%M%S").replace(
                tzinfo=IRAN_TZ,
            )
        except (TypeError, ValueError):
            pass
    return received_at


def normalize_tsetmc_indices(
    payload: Mapping[str, Any],
    *,
    received_at: datetime | None = None,
) -> list[MarketIndex]:
    """Normalize TSETMC index-list payloads while rejecting incomplete rows."""
    received = received_at or datetime.now(UTC)
    rows = payload.get("indexB1") or payload.get("indices") or payload.get("data") or []
    if isinstance(rows, Mapping):
        rows = [rows]
    result: list[MarketIndex] = []
    for row in rows:
        if not isinstance(row, Mapping):
            continue
        code = str(_first_value(row, "insCode", "indexCode", "index_code") or "").strip()
        value = parse_iranian_decimal(
            _first_value(row, "xDrNivJIdx004", "lastValue", "value"),
        )
        if not code or value is None or value < 0:
            continue
        result.append(
            MarketIndex(
                index_code=code,
                name=str(
                    _first_value(row, "lVal30", "lVal18AFC", "name") or code,
                ).strip(),
                value=value,
                change=parse_iranian_decimal(
                    _first_value(row, "indexChange", "change", "changeValue"),
                ),
                change_percent=parse_iranian_decimal(
                    _first_value(row, "indexPercent", "changePercent", "change_percent"),
                ),
                event_time=_parse_market_timestamp(row, received),
                source="TSETMC",
            )
        )
    return result


def normalize_tsetmc_market_overview(
    payload: Mapping[str, Any],
    *,
    total_index: MarketIndex,
    equal_weight_index: MarketIndex,
    received_at: datetime | None = None,
) -> MarketOverview | None:
    """Normalize TSETMC overview payload plus its two canonical index rows."""
    received = received_at or datetime.now(UTC)
    row = payload.get("marketOverview") or payload.get("overview") or payload
    if isinstance(row, list):
        row = row[0] if row else {}
    if not isinstance(row, Mapping):
        return None

    trades_count = parse_iranian_int(
        _first_value(row, "marketActivityZTotTran", "trades_count", "tradesCount"),
    )
    trades_volume = parse_iranian_int(
        _first_value(row, "marketActivityQTotTran", "trades_volume", "tradesVolume"),
    )
    return MarketOverview(
        total_index_value=total_index.value,
        total_index_change=total_index.change,
        equal_weight_index_value=equal_weight_index.value,
        equal_weight_index_change=equal_weight_index.change,
        market_value=parse_iranian_decimal(
            _first_value(row, "marketValue", "market_value", "marketCapitalization"),
        ),
        trades_count=max(trades_count or 0, 0),
        trades_value=parse_iranian_decimal(
            _first_value(row, "tradesValue", "trades_value", "marketActivityQTotCap"),
        ),
        trades_volume=max(trades_volume or 0, 0),
        price_info_timestamp=_parse_market_timestamp(row, received),
        server_received_at=received,
        source=str(_first_value(row, "source") or "TSETMC"),
    )


class TSETMCNormalizer:
    """Convert TSETMC provider objects into stable internal DTOs."""

    @staticmethod
    def quote_from_snapshot(snapshot: LiveMarketSnapshot) -> MarketQuote:
        return MarketQuote(
            instrument_id=snapshot.ins_code,
            symbol=snapshot.ticker,
            trade_date=snapshot.fetched_at.date(),
            event_time=snapshot.fetched_at,
            first_price=snapshot.open_price,
            last_price=snapshot.last_trade_price,
            closing_price=snapshot.close_price,
            high_price=snapshot.high_price,
            low_price=snapshot.low_price,
            volume=snapshot.volume,
            status=snapshot.state,
            received_at=snapshot.fetched_at,
            source="TSETMC",
        )


class CodalNormalizer:
    """Convert Codal response fragments into normalized disclosure DTOs."""

    @staticmethod
    def _datetime(value: Any) -> datetime | None:
        if isinstance(value, datetime):
            return value if value.tzinfo is not None else value.replace(tzinfo=IRAN_TZ).astimezone(UTC)
        if not value:
            return None
        text = normalize_iranian_digits(value).strip().replace("/Date(", "").replace(")/", "")
        if text.isdigit() and len(text) >= 10:
            timestamp = int(text[:13]) / (1000 if len(text) >= 13 else 1)
            return datetime.fromtimestamp(timestamp, tz=UTC)
        date_match = re.match(
            r"^(?P<year>\d{4})[/-](?P<month>\d{1,2})[/-](?P<day>\d{1,2})"
            r"(?:[T ](?P<hour>\d{1,2})(?::(?P<minute>\d{1,2}))?(?::(?P<second>\d{1,2}))?)?",
            text,
        )
        if date_match and int(date_match.group("year")) < 1700:
            parts = date_match.groupdict()
            try:
                gregorian = _jalali_to_gregorian(
                    int(parts["year"]), int(parts["month"]), int(parts["day"])
                )
                parsed = datetime(
                    *gregorian,
                    int(parts["hour"] or 0),
                    int(parts["minute"] or 0),
                    int(parts["second"] or 0),
                )
                return parsed.replace(tzinfo=IRAN_TZ).astimezone(UTC)
            except ValueError:
                return None
        normalized = text.replace("Z", "+00:00")
        for candidate in (normalized, normalized.replace("/", "-")):
            try:
                parsed = datetime.fromisoformat(candidate)
                return (
                    parsed
                    if parsed.tzinfo is not None
                    else parsed.replace(tzinfo=IRAN_TZ).astimezone(UTC)
                )
            except ValueError:
                continue
        return None

    @staticmethod
    def _text(row: Mapping[str, Any], *keys: str) -> str | None:
        for key in keys:
            value = row.get(key)
            if value is not None and str(value).strip():
                return str(value).strip()
        return None

    @staticmethod
    def _boolean(row: Mapping[str, Any], *keys: str) -> bool:
        for key in keys:
            value = row.get(key)
            if isinstance(value, bool):
                return value
            if isinstance(value, (int, float)) and value != 0:
                return True
            if str(value or "").strip().lower() in {"true", "1", "yes"}:
                return True
        return False

    @staticmethod
    def disclosure_from_mapping(row: Mapping[str, Any]) -> CodalDisclosure | None:
        tracking_number = CodalNormalizer._text(
            row, "tracking_number", "TracingNo", "TrackingNumber", "trackingNumber"
        ) or ""
        symbol = CodalNormalizer._text(row, "symbol", "Symbol") or ""
        title = CodalNormalizer._text(row, "title", "Title") or ""
        if not tracking_number or not symbol or not title:
            return None
        sent_at = CodalNormalizer._datetime(
            row.get("sent_at") or row.get("SentDateTime") or row.get("SentDate")
        )
        published_at = CodalNormalizer._datetime(
            row.get("published_at")
            or row.get("PublishDateTime")
            or row.get("PublishedDateTime")
        )
        url = CodalNormalizer._text(row, "url", "Url", "LetterUrl")
        if url and url.startswith("/"):
            url = f"https://codal.ir{url}"
        has_attachment = CodalNormalizer._boolean(
            row,
            "has_attachment",
            "HasAttachment",
            "HasPdf",
            "HasExcel",
            "HasXbrl",
        ) or bool(CodalNormalizer._text(row, "AttachmentUrl", "PdfUrl", "ExcelUrl"))
        return CodalDisclosure(
            tracking_number=tracking_number,
            symbol=symbol,
            title=title,
            company_name=CodalNormalizer._text(row, "company_name", "CompanyName"),
            letter_code=CodalNormalizer._text(row, "letter_code", "LetterCode"),
            sent_at=sent_at,
            published_at=published_at,
            category=CodalNormalizer._text(
                row, "category", "Category", "LetterType", "LetterCode"
            ),
            url=url,
            has_attachment=has_attachment,
            source=CodalNormalizer._text(row, "source", "Source") or "CODAL",
        )

    @staticmethod
    def detail_from_mapping(row: Mapping[str, Any]) -> CodalDisclosureDetail | None:
        disclosure = CodalNormalizer.disclosure_from_mapping(row)
        if disclosure is None:
            return None
        attachments = row.get("attachments") or row.get("Attachments") or []
        if not isinstance(attachments, list):
            attachments = []
        return CodalDisclosureDetail(
            tracking_number=disclosure.tracking_number,
            symbol=disclosure.symbol,
            title=disclosure.title,
            published_at=disclosure.published_at,
            body=str(row.get("body") or row.get("Body") or "") or None,
            attachments=[str(item) for item in attachments],
        )


class FipiranNormalizer:
    """Convert Fipiran response fragments into normalized fund DTOs."""

    @staticmethod
    def _value(row: Mapping[str, Any], *keys: str) -> Any:
        for key in keys:
            if key in row and row[key] is not None and str(row[key]).strip() != "":
                return row[key]
        return None

    @staticmethod
    def _date(value: Any) -> date | None:
        if isinstance(value, datetime):
            return value.date()
        if isinstance(value, date):
            return value
        text = normalize_iranian_digits(value).strip() if value is not None else ""
        if re.fullmatch(r"\d{4}-\d{1,2}-\d{1,2}", text):
            try:
                return date.fromisoformat(text)
            except ValueError:
                return None
        parsed = CodalNormalizer._datetime(value)
        return parsed.astimezone(IRAN_TZ).date() if parsed else None

    @staticmethod
    def fund_from_mapping(row: Mapping[str, Any]) -> Fund | None:
        fund_id = str(FipiranNormalizer._value(
            row, "fund_id", "FundId", "fundId", "reg_no", "RegNo", "id"
        ) or "").strip()
        name = str(FipiranNormalizer._value(
            row, "name", "Name", "fund_name", "FundName", "title"
        ) or "").strip()
        if not fund_id or not name:
            return None
        return Fund(
            fund_id=fund_id,
            name=name,
            symbol=str(FipiranNormalizer._value(row, "symbol", "Symbol") or "") or None,
            type=str(FipiranNormalizer._value(
                row, "type", "fund_type", "FundType", "fundType", "FundTypeName"
            ) or "") or None,
            nav=decimal_or_none(FipiranNormalizer._value(
                row, "nav", "Nav", "statistical_nav", "StatisticalNav", "NetAssetValue"
            )),
            nav_date=FipiranNormalizer._date(FipiranNormalizer._value(
                row, "nav_date", "NavDate", "navDate", "Date"
            )),
            return_1m=decimal_or_none(FipiranNormalizer._value(
                row, "return_1m", "Return1M", "MonthlyReturn"
            )),
            return_3m=decimal_or_none(FipiranNormalizer._value(
                row, "return_3m", "Return3M", "QuarterlyReturn"
            )),
            return_6m=decimal_or_none(FipiranNormalizer._value(
                row, "return_6m", "Return6M", "SemiAnnualReturn"
            )),
            return_1y=decimal_or_none(FipiranNormalizer._value(
                row, "return_1y", "Return1Y", "AnnualReturn"
            )),
            manager=str(FipiranNormalizer._value(row, "manager", "Manager") or "") or None,
            source=str(FipiranNormalizer._value(row, "source", "Source") or "FIPIRAN"),
        )

    @staticmethod
    def nav_from_mapping(row: Mapping[str, Any], fund_id: str | None = None) -> FundNav | None:
        normalized_id = str(fund_id or FipiranNormalizer._value(
            row, "fund_id", "FundId", "fundId", "reg_no", "RegNo", "id"
        ) or "").strip()
        nav_date = FipiranNormalizer._date(FipiranNormalizer._value(
            row, "nav_date", "NavDate", "navDate", "Date"
        ))
        if not normalized_id or nav_date is None:
            return None
        return FundNav(
            fund_id=normalized_id,
            nav_date=nav_date,
            subscription_nav=decimal_or_none(FipiranNormalizer._value(
                row, "subscription_nav", "SubscriptionNav", "PurchaseNav"
            )),
            redemption_nav=decimal_or_none(FipiranNormalizer._value(
                row, "redemption_nav", "RedemptionNav", "SellNav"
            )),
            statistical_nav=decimal_or_none(FipiranNormalizer._value(
                row, "statistical_nav", "StatisticalNav", "nav", "Nav", "NetAssetValue"
            )),
            source=str(FipiranNormalizer._value(row, "source", "Source") or "FIPIRAN"),
        )

    @staticmethod
    def return_from_mapping(row: Mapping[str, Any], fund_id: str, window: str) -> FundReturn:
        return FundReturn(
            fund_id=fund_id,
            window=window,
            return_percent=decimal_or_none(FipiranNormalizer._value(
                row, "return_percent", "ReturnPercent", "value", "Value"
            )),
            as_of_date=FipiranNormalizer._date(FipiranNormalizer._value(
                row, "as_of_date", "AsOfDate", "Date"
            )),
        )
