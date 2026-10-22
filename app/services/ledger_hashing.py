"""Deterministic hashing helpers for immutable ledger idempotency."""

from __future__ import annotations

import hashlib
import uuid
from datetime import datetime
from decimal import Decimal, ROUND_HALF_UP

from app.models.enums import TransactionType

EIGHT_PLACES = Decimal("0.00000001")


def q8(value: Decimal) -> Decimal:
    return value.quantize(EIGHT_PLACES, rounding=ROUND_HALF_UP)


def normalize_symbol_for_hash(symbol: str) -> str:
    cleaned = symbol.strip().replace(" ", "")
    return "".join(char.upper() if "a" <= char <= "z" or "A" <= char <= "Z" else char for char in cleaned)


def build_reference_hash(
    *,
    user_id: uuid.UUID,
    symbol: str,
    executed_at: datetime,
    quantity: Decimal,
    transaction_type: TransactionType,
) -> str:
    """Reference hash for strict ledger idempotency across broker imports."""

    payload = "|".join(
        [
            str(user_id),
            normalize_symbol_for_hash(symbol),
            executed_at.date().isoformat(),
            format(q8(quantity), "f"),
            transaction_type.value,
        ]
    )
    return hashlib.sha256(payload.encode("utf-8")).hexdigest()
