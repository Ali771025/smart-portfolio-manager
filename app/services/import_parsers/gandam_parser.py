"""GANDAM-specific Excel parser."""

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


class GandamParser(BaseBrokerParser):
    broker = BrokerType.GANDAM

    def _parse_single_row(
        self,
        *,
        row: dict[str, Any],
        source_file: str,
    ) -> tuple[NormalizedImportTransaction | None, ImportParseError | None]:
        row_number = int(row.get("__row_number__", 0) or 0)
        description = self.normalize_text(
            self.pick_first(row, ["شرح", "description", "توضیحات"]) or ""
        )
        raw_type = self.normalize_text(self.pick_first(row, ["نوع", "عملیات"]) or "")
        symbol_from_text, quantity_from_text = self.extract_symbol_and_quantity(description=description)
        symbol = self.normalize_symbol(
            self.pick_first(row, ["نماد", "نماد دارایی", "نام نماد"]) or ""
        ) or symbol_from_text

        transaction_type = self.infer_transaction_type(description=description, raw_type=raw_type)
        debit = self.to_decimal(self.pick_first(row, ["بدهکار", "بدهکار(ریال)", "بدهکار ریال"]))
        credit = self.to_decimal(self.pick_first(row, ["بستانکار", "بستانکار(ریال)", "بستانکار ریال"]))
        if transaction_type is None:
            if debit > ZERO and credit == ZERO:
                transaction_type = NormalizedTransactionType.BUY
            elif credit > ZERO and debit == ZERO:
                transaction_type = NormalizedTransactionType.SELL

        if transaction_type is None:
            return None, ImportParseError(
                row_number=row_number,
                raw_text=description or str(row),
                error_reason="Could not detect transaction type.",
            )

        quantity = quantity_from_text
        if quantity <= ZERO:
            quantity = self.to_decimal(self.pick_first(row, ["تعداد", "حجم", "مانده"]))
        total_amount = debit if transaction_type == NormalizedTransactionType.BUY else credit
        if total_amount <= ZERO:
            total_amount = self.to_decimal(self.pick_first(row, ["مبلغ", "ارزش", "جمع"]))

        price_per_unit = self.extract_price(description)
        if price_per_unit <= ZERO and quantity > ZERO and total_amount > ZERO:
            price_per_unit = (total_amount / quantity).quantize(Decimal("0.00000001"))
        if price_per_unit <= ZERO:
            price_per_unit = total_amount

        if transaction_type in {NormalizedTransactionType.BUY, NormalizedTransactionType.SELL}:
            if not symbol:
                return None, ImportParseError(
                    row_number=row_number,
                    raw_text=description or str(row),
                    error_reason="Symbol is missing for trade transaction.",
                )
            if quantity <= ZERO:
                return None, ImportParseError(
                    row_number=row_number,
                    raw_text=description or str(row),
                    error_reason="Quantity is missing or invalid.",
                )

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
                symbol=symbol or "CASH",
                transaction_type=transaction_type,
                quantity=quantity if quantity > ZERO else Decimal("1.00000000"),
                price_per_unit=price_per_unit,
                total_amount=total_amount,
                broker=self.broker,
                source_file=source_file,
                raw_text=description or str(row),
            ),
            None,
        )
