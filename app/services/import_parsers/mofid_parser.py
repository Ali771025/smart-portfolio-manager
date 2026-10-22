"""MOFID-specific Excel parser."""

from __future__ import annotations

import re
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

_MOFID_TRADE_RE = re.compile(
    r"(?P<side>خرید|فروش)\s*"
    r"(?P<quantity>[0-9۰-۹٠-٩,٬،.]+)\s*سهم\s*"
    r"(?:سهامی\s+عا\s*\()?\s*(?P<symbol>[A-Za-z0-9\u0600-\u06FF]+)\)?"
    r"(?:.*?به\s*نرخ\s*(?P<price>[0-9۰-۹٠-٩,٬،.]+))?"
)


class MofidParser(BaseBrokerParser):
    broker = BrokerType.MOFID

    _OPENING_BALANCE_PATTERNS = ("مانده نقل از قبل", "مانده ابتدا دوره")

    def _parse_trade_description(
        self, description: str
    ) -> tuple[NormalizedTransactionType | None, str, Decimal, Decimal]:
        match = _MOFID_TRADE_RE.search(description)
        if match is None:
            return None, "", ZERO, ZERO
        side = (
            NormalizedTransactionType.BUY
            if match.group("side") == "خرید"
            else NormalizedTransactionType.SELL
        )
        return (
            side,
            self.normalize_symbol(match.group("symbol")),
            self.to_decimal(match.group("quantity")),
            self.to_decimal(match.group("price")),
        )

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
        if any(pattern in description for pattern in self._OPENING_BALANCE_PATTERNS):
            return (
                NormalizedImportTransaction(
                    row_number=row_number,
                    date=self.parse_jalali_or_gregorian(
                        self.pick_first(row, ["تاریخ", "زمان", "date"])
                    ),
                    symbol="CASH",
                    transaction_type=NormalizedTransactionType.IGNORE,
                    quantity=ZERO,
                    price_per_unit=ZERO,
                    total_amount=ZERO,
                    broker=self.broker,
                    source_file=source_file,
                    raw_text=description,
                    normalized_description=description,
                    confidence_source="mofid_opening_balance",
                    warning="ردیف مانده نقل از قبل، معامله نیست و از تراکنش‌های پرتفوی رد شد.",
                ),
                None,
            )

        raw_symbol = self.normalize_text(
            self.pick_first(row, ["نماد دارایی", "نماددارایی", "نماد", "نام نماد"]) or ""
        )
        parsed_type, symbol_from_text, quantity_from_text, price_from_text = (
            self._parse_trade_description(description)
        )
        symbol = self.normalize_symbol(raw_symbol) or symbol_from_text

        raw_type = self.normalize_text(self.pick_first(row, ["نوع", "عملیات"]) or "")
        transaction_type = parsed_type or self.infer_transaction_type(
            description=description, raw_type=raw_type
        )
        if transaction_type is None:
            debit = self.to_decimal(self.pick_first(row, ["بدهکار", "بدهکار(ریال)", "بدهکار ریال"]))
            credit = self.to_decimal(self.pick_first(row, ["بستانکار", "بستانکار(ریال)", "بستانکار ریال"]))
            if debit > ZERO and credit == ZERO:
                transaction_type = NormalizedTransactionType.BUY
            elif credit > ZERO and debit == ZERO:
                transaction_type = NormalizedTransactionType.SELL

        if transaction_type is None:
            return None, ImportParseError(
                row_number=row_number,
                raw_text=description,
                error_reason="نوع تراکنش این ردیف قابل تشخیص نیست.",
            )

        quantity = quantity_from_text
        if quantity <= ZERO:
            quantity = self.to_decimal(self.pick_first(row, ["تعداد", "حجم", "مانده"]))

        debit = self.to_decimal(self.pick_first(row, ["بدهکار", "بدهکار(ریال)", "بدهکار ریال"]))
        credit = self.to_decimal(self.pick_first(row, ["بستانکار", "بستانکار(ریال)", "بستانکار ریال"]))
        total_amount = debit if transaction_type == NormalizedTransactionType.BUY else credit
        if total_amount <= ZERO:
            total_amount = self.to_decimal(self.pick_first(row, ["مبلغ", "ارزش", "جمع"]))

        price_per_unit = price_from_text or self.extract_price(description)
        if price_per_unit <= ZERO and quantity > ZERO and total_amount > ZERO:
            price_per_unit = (total_amount / quantity).quantize(Decimal("0.00000001"))

        if transaction_type in {NormalizedTransactionType.BUY, NormalizedTransactionType.SELL}:
            if not symbol:
                return None, ImportParseError(
                    row_number=row_number,
                    raw_text=description,
                    error_reason="نماد معامله در ستون نماد یا شرح پیدا نشد.",
                )
            if quantity <= ZERO:
                return None, ImportParseError(
                    row_number=row_number,
                    raw_text=description,
                    error_reason="تعداد معامله در شرح پیدا نشد یا نامعتبر است.",
                )

        gross_amount = (
            (quantity * price_per_unit).quantize(Decimal("0.00000001"))
            if quantity > ZERO and price_per_unit > ZERO
            else ZERO
        )
        inferred_fee = ZERO
        if transaction_type == NormalizedTransactionType.SELL and gross_amount > total_amount > ZERO:
            inferred_fee = (gross_amount - total_amount).quantize(Decimal("0.00000001"))
        elif transaction_type == NormalizedTransactionType.BUY and total_amount > gross_amount > ZERO:
            inferred_fee = (total_amount - gross_amount).quantize(Decimal("0.00000001"))

        if total_amount <= ZERO:
            return None, ImportParseError(
                row_number=row_number,
                raw_text=description,
                error_reason="مبلغ بدهکار یا بستانکار این ردیف نامعتبر است.",
            )

        if price_per_unit <= ZERO:
            price_per_unit = total_amount

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
                raw_text=description,
                normalized_description=description,
                confidence_source="mofid_trade_description" if parsed_type else "mofid_columns",
                fees=inferred_fee,
                net_amount=total_amount,
                diagnostics={
                    "broker_symbol": raw_symbol or None,
                    "extracted_symbol": symbol_from_text or None,
                    "extracted_quantity": format(quantity, "f"),
                    "extracted_unit_price": format(price_per_unit, "f"),
                    "extracted_gross_amount": format(gross_amount, "f"),
                    "net_amount": format(total_amount, "f"),
                    "inferred_fee": format(inferred_fee, "f"),
                    "debit": format(debit, "f"),
                    "credit": format(credit, "f"),
                },
            ),
            None,
        )
