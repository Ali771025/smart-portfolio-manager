"""Broker format detection based on normalized Excel headers."""

from __future__ import annotations

from collections.abc import Iterable

from .base_parser import BrokerType


def _normalize_header(header: str) -> str:
    return (
        str(header)
        .strip()
        .lower()
        .replace(" ", "")
        .replace("_", "")
        .replace("(", "")
        .replace(")", "")
    )


def _has_any(signature: set[str], aliases: set[str]) -> bool:
    return any(item in signature for item in aliases)


def detect_broker_format(headers: Iterable[str]) -> BrokerType:
    """Detect broker by known header signatures with alias support."""

    signature = {_normalize_header(h) for h in headers if str(h).strip()}

    has_symbol = _has_any(signature, {"نماددارایی", "نماد", "نامنماد"})
    has_debit = _has_any(signature, {"بدهکار", "بدهکارریال", "بدهکار(ریال)"})
    has_credit = _has_any(signature, {"بستانکار", "بستانکارریال", "بستانکار(ریال)"})
    has_description = _has_any(signature, {"شرح"})
    has_time = _has_any(signature, {"زمان", "تاریخ"})
    has_irr_debit = _has_any(signature, {"بدهکارریال", "بدهکار(ریال)"})
    has_irr_credit = _has_any(signature, {"بستانکارریال", "بستانکار(ریال)"})

    if has_symbol and has_debit and has_credit:
        return BrokerType.MOFID

    # AGAH exports commonly use explicit IRR debit/credit headers and may or may not
    # provide a dedicated type column.
    if has_description and has_time and has_irr_debit and has_irr_credit:
        return BrokerType.AGAH
    if _has_any(signature, {"نوع", "عملیات"}) and has_debit and has_credit:
        return BrokerType.AGAH

    if _has_any(signature, {"میانگینخرید", "بهایمتوسطخرید"}) and _has_any(
        signature,
        {"تعداد", "حجم", "مانده"},
    ):
        return BrokerType.BOURSIRAN

    if has_description and has_time and has_debit and has_credit:
        return BrokerType.GANDAM

    raise ValueError(
        "Unsupported broker format. Missing recognizable broker-specific headers."
    )
