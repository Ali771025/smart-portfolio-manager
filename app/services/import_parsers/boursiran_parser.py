"""BOURSIRAN-specific Excel parser."""

from __future__ import annotations

from decimal import Decimal
from typing import Any

from .base_parser import (
    BaseBrokerParser,
    BrokerType,
    ImportParseError,
    NormalizedImportTransaction,
    NormalizedTransactionType,
    ZERO,
)


class BoursiranParser(BaseBrokerParser):
    broker = BrokerType.BOURSIRAN

    def _parse_single_row(
        self,
        *,
        row: dict[str, Any],
        source_file: str,
    ) -> tuple[NormalizedImportTransaction | None, ImportParseError | None]:
        row_number = int(row.get("__row_number__", 0) or 0)
        symbol = self.normalize_symbol(
            self.pick_first(row, ["نماد", "نماد دارایی", "نام نماد"]) or ""
        )
        quantity = self.to_decimal(self.pick_first(row, ["تعداد", "حجم", "مانده"]))
        total_amount = self.to_decimal(
            self.pick_first(row, ["بهای تمام شده خرید", "بهای تمام شده", "ارزش خرید", "بدهکار"])
        )
        unit_price = self.to_decimal(self.pick_first(row, ["میانگین خرید", "بهای متوسط خرید", "قیمت"]))
        description = self.normalize_text(self.pick_first(row, ["شرح", "description", "توضیحات"]) or "")
        raw_type = self.normalize_text(self.pick_first(row, ["نوع", "عملیات"]) or "")
        transaction_type = self.infer_transaction_type(description=description, raw_type=raw_type)
        if transaction_type is None:
            transaction_type = NormalizedTransactionType.BUY

        if not symbol:
            return None, ImportParseError(
                row_number=row_number,
                raw_text=description or str(row),
                error_reason="Symbol is missing.",
            )
        if quantity <= ZERO:
            return None, ImportParseError(
                row_number=row_number,
                raw_text=description or str(row),
                error_reason="Quantity is missing or invalid.",
            )

        if unit_price <= ZERO and total_amount > ZERO:
            unit_price = (total_amount / quantity).quantize(Decimal("0.00000001"))
        if total_amount <= ZERO and unit_price > ZERO:
            total_amount = (unit_price * quantity).quantize(Decimal("0.00000001"))
        if total_amount <= ZERO:
            return None, ImportParseError(
                row_number=row_number,
                raw_text=description or str(row),
                error_reason="Total amount is missing or invalid.",
            )

        return (
            NormalizedImportTransaction(
                row_number=row_number,
                date=self.parse_jalali_or_gregorian(self.pick_first(row, ["تاریخ", "زمان", "date"])),
                symbol=symbol,
                transaction_type=transaction_type,
                quantity=quantity,
                price_per_unit=unit_price if unit_price > ZERO else total_amount,
                total_amount=total_amount,
                broker=self.broker,
                source_file=source_file,
                raw_text=description or str(row),
            ),
            None,
        )
