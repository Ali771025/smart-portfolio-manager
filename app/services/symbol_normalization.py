"""Canonical symbol normalization shared by import, asset, and market data code."""

from __future__ import annotations

from typing import Any

_SYMBOL_TRANSLATION = str.maketrans(
    {
        "ي": "ی",
        "ى": "ی",
        "ك": "ک",
        **dict(zip("۰۱۲۳۴۵۶۷۸۹٠١٢٣٤٥٦٧٨٩", "01234567890123456789")),
    }
)
_INVISIBLE_MARKS = frozenset(
    {"\u200b", "\u200c", "\u200d", "\u200e", "\u200f", "\ufeff", "\u2060"}
)


def normalize_symbol_key(value: Any) -> str:
    """Return one stable lookup key for Persian/Arabic symbol variants."""

    normalized = str(value or "").translate(_SYMBOL_TRANSLATION)
    normalized = "".join(char for char in normalized if char not in _INVISIBLE_MARKS)
    normalized = " ".join(normalized.strip().split())
    if normalized.startswith("(") and normalized.endswith(")"):
        normalized = normalized[1:-1].strip()
    if normalized.startswith("（") and normalized.endswith("）"):
        normalized = normalized[1:-1].strip()
    return normalized.replace(" ", "").upper()
