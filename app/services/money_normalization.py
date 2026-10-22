"""Central money/price normalization helpers.

Broker statement amounts and TSETMC equity prices are treated as IRR by
default. Any future toman feeds should convert through this module instead of
scattering unit conversions in UI or service code.
"""

from __future__ import annotations

from decimal import Decimal, ROUND_HALF_UP
from enum import StrEnum
from typing import Any


Q8 = Decimal("0.00000001")
ZERO = Decimal("0.00000000")


class MoneyUnit(StrEnum):
    IRR = "IRR"
    TOMAN = "TOMAN"


def money_decimal(value: Any) -> Decimal:
    if value in (None, ""):
        return ZERO
    return Decimal(str(value)).quantize(Q8, rounding=ROUND_HALF_UP)


def normalize_money_unit(
    value: Any,
    *,
    source_unit: MoneyUnit | str = MoneyUnit.IRR,
    target_unit: MoneyUnit | str = MoneyUnit.IRR,
) -> Decimal:
    amount = money_decimal(value)
    source = MoneyUnit(str(source_unit))
    target = MoneyUnit(str(target_unit))
    if source == target:
        return amount
    if source == MoneyUnit.TOMAN and target == MoneyUnit.IRR:
        return money_decimal(amount * Decimal("10"))
    if source == MoneyUnit.IRR and target == MoneyUnit.TOMAN:
        return money_decimal(amount / Decimal("10"))
    return amount


def normalize_market_price(
    value: Any,
    *,
    source_unit: MoneyUnit | str = MoneyUnit.IRR,
    target_unit: MoneyUnit | str = MoneyUnit.IRR,
) -> Decimal | None:
    if value in (None, ""):
        return None
    price = normalize_money_unit(value, source_unit=source_unit, target_unit=target_unit)
    return price if price > ZERO else None
