"""DataFrame normalization helpers for resilient broker file detection."""

from __future__ import annotations

from decimal import Decimal, InvalidOperation
from typing import Iterable

import pandas as pd

from app.services.symbol_normalization import normalize_symbol_key

PERSIAN_ZWNJ = "\u200c"
_ARABIC_TO_PERSIAN = str.maketrans({"ي": "ی", "ى": "ی", "ك": "ک"})
_PERSIAN_DIGITS_TO_ASCII = str.maketrans("۰۱۲۳۴۵۶۷۸۹", "0123456789")
_ARABIC_DIGITS_TO_ASCII = str.maketrans("٠١٢٣٤٥٦٧٨٩", "0123456789")
_INVISIBLE_MARKS = {
    "\u200b",  # zero-width space
    "\u200c",  # ZWNJ
    "\u200d",  # ZWJ
    "\u200e",  # LRM
    "\u200f",  # RLM
    "\ufeff",  # BOM
    "\u2060",  # word joiner
}


def normalize_symbol(symbol: str) -> str:
    """Canonicalize broker symbols so Persian/Arabic variants map to one key."""
    return normalize_symbol_key(symbol)


def normalize_column_name(value: object) -> str:
    """Normalize a header by trimming, lower-casing, and removing ZWNJ markers."""

    text = str(value).translate(_ARABIC_TO_PERSIAN)
    # ZWNJ can make visually equal headers fail exact matching.
    text = text.replace(PERSIAN_ZWNJ, "")
    text = text.strip().lower()
    return " ".join(text.split())


def normalize_dataframe_headers(df: pd.DataFrame) -> pd.DataFrame:
    """Return a copy of df with normalized headers only."""

    normalized = df.copy()
    normalized.columns = [normalize_column_name(col) for col in normalized.columns]
    return normalized


def normalize_headers(headers: Iterable[object]) -> set[str]:
    """Normalize an iterable of headers into a comparable set."""

    return {normalize_column_name(header) for header in headers}


def has_required_subset(df: pd.DataFrame, required_columns: set[str]) -> bool:
    """Detect broker signature via subset matching while ignoring extra columns."""

    normalized_required = normalize_headers(required_columns)
    return normalized_required.issubset(set(df.columns))


def parse_decimal(value: object) -> Decimal | None:
    """Parse localized numeric strings into Decimal values."""

    if value is None:
        return None

    text = str(value).translate(_ARABIC_TO_PERSIAN).strip()
    if not text:
        return None

    text = text.replace(PERSIAN_ZWNJ, "")
    text = text.translate(_PERSIAN_DIGITS_TO_ASCII).translate(_ARABIC_DIGITS_TO_ASCII)
    text = text.replace(",", "")
    text = text.replace("٬", "")
    text = text.replace("−", "-")
    if text.startswith("(") and text.endswith(")"):
        text = f"-{text[1:-1].strip()}"

    try:
        parsed = Decimal(text)
        if not parsed.is_finite():
            return None
        return parsed
    except InvalidOperation:
        return None
