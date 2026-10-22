"""Normalization and utility helpers for broker-aware import pipeline."""

from __future__ import annotations

import hashlib
import re
from datetime import UTC, datetime
from decimal import Decimal, InvalidOperation
from typing import Any

_PERSIAN_ARABIC_DIGITS_MAP = str.maketrans(
    "۰۱۲۳۴۵۶۷۸۹٠١٢٣٤٥٦٧٨٩٬٫",
    "01234567890123456789,.",
)

_SPACE_RE = re.compile(r"\s+")
_TRADE_DETAILS_PATTERN = re.compile(
    r"(?:تعداد)\s*(?P<qty>[0-9۰-۹٠-٩,٬\.]+)\s*(?:سهم)?\s*"
    r"(?P<symbol>[\u0600-\u06FFA-Za-z0-9_]+)?"
    r".*?(?:قیمت(?:\s*میانگین)?|@)\s*(?P<price>[0-9۰-۹٠-٩,٬\.]+)",
)


def normalize_header(value: str) -> str:
    compact = _SPACE_RE.sub(" ", value.strip())
    return compact.translate(_PERSIAN_ARABIC_DIGITS_MAP)


def normalize_string(value: Any) -> str:
    if value is None:
        return ""
    text = str(value).strip()
    text = _SPACE_RE.sub(" ", text)
    return text.translate(_PERSIAN_ARABIC_DIGITS_MAP)


def parse_decimal(value: Any) -> Decimal | None:
    text = normalize_string(value)
    if not text:
        return None
    normalized = text.replace(",", "")
    try:
        return Decimal(normalized)
    except (InvalidOperation, ValueError):
        return None


def parse_datetime_flexible(value: Any) -> datetime | None:
    text = normalize_string(value)
    if not text:
        return None

    for fmt in (
        "%Y-%m-%d %H:%M:%S",
        "%Y/%m/%d %H:%M:%S",
        "%Y-%m-%d %H:%M",
        "%Y/%m/%d %H:%M",
        "%Y-%m-%d",
        "%Y/%m/%d",
    ):
        try:
            parsed = datetime.strptime(text, fmt)
            if parsed.tzinfo is None:
                return parsed.replace(tzinfo=UTC)
            return parsed.astimezone(UTC)
        except ValueError:
            continue
    return None


def sha256_hex(value: str) -> str:
    return hashlib.sha256(value.encode("utf-8")).hexdigest()


def parse_trade_details_from_description(description: str) -> tuple[str | None, Decimal | None, Decimal | None]:
    text = normalize_string(description)
    if not text:
        return None, None, None

    match = _TRADE_DETAILS_PATTERN.search(text)
    if match is None:
        return None, None, None

    raw_symbol = normalize_string(match.group("symbol"))
    symbol = raw_symbol if raw_symbol else None
    quantity = parse_decimal(match.group("qty"))
    price = parse_decimal(match.group("price"))
    return symbol, quantity, price
