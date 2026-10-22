"""AGAH-specific parser that treats source rows as broker cash/account statements."""

from __future__ import annotations

import re
from dataclasses import dataclass
from decimal import Decimal
from typing import Any

from .base_parser import (
    EIGHT_PLACES,
    BaseBrokerParser,
    BrokerType,
    ImportParseError,
    NormalizedImportTransaction,
    NormalizedTransactionType,
    ZERO,
)

_TRADE_DESC_RE = re.compile(
    r"(?P<side>خرید|فروش)\s*(?P<qty>[0-9۰-۹٠-٩,٬./]+)\s*سهم\s*(?P<symbol>[A-Za-z0-9\u0600-\u06FF]+)"
    r"(?:\s*به\s*نرخ\s*(?P<price>[0-9۰-۹٠-٩,٬./]+))?"
)
_TRADE_DESC_FALLBACK_RE = re.compile(
    r"(?P<side>خرید|فروش).*?(?P<qty>[0-9۰-۹٠-٩,٬./]+)\s*سهم.*?(?P<symbol>[A-Za-z0-9\u0600-\u06FF]+)"
    r"(?:.*?نرخ\s*(?P<price>[0-9۰-۹٠-٩,٬./]+))?"
)
_AGAH_AVERAGE_PRICE_DESC_RE = re.compile(
    r"تعداد\s+(?P<qty>[0-9۰-۹٠-٩,٬./]+)\s+سهم\s+(?P<symbol>[^\s]+)\s+"
    r"با\s+قیمت\s+میانگین\s+(?P<price>[0-9۰-۹٠-٩,٬./]+)"
)
_SPLIT_RATIO_RE = re.compile(r"([0-9۰-۹٠-٩]+)\s*به\s*([0-9۰-۹٠-٩]+)")
_MONEY_IN_TEXT_RE = re.compile(r"(?:مبلغ|ارزش|کارمزد|مالیات)\s*[:\-]?\s*([0-9۰-۹٠-٩,./]+)")


@dataclass(slots=True, frozen=True)
class AgahRowClassification:
    normalized_type: NormalizedTransactionType
    parse_source: str
    warning: str | None = None
    symbol: str = ""
    quantity: Decimal = ZERO
    unit_price: Decimal = ZERO
    gross_amount: Decimal = ZERO
    diagnostics: dict[str, Any] | None = None


class AgahParser(BaseBrokerParser):
    broker = BrokerType.AGAH

    _OPENING_BALANCE_PATTERNS = ("مانده نقل از قبل", "مانده از قبل", "مانده ابتدا دوره")
    _SELL_PATTERNS = ("فروش",)
    _BUY_PATTERNS = ("خرید",)
    _DIVIDEND_PATTERNS = ("سود نقدی", "سود سهام", "بابت سود", "سود طرح سرمایه گذاری")
    _DEPOSIT_PATTERNS = ("واریز", "واریز وجه", "دریافت وجه", "افزایش مانده")
    _WITHDRAWAL_PATTERNS = ("برداشت", "برداشت وجه", "پرداخت وجه", "کاهش مانده")
    _FEE_PATTERNS = ("کارمزد", "هزینه", "هزینه خدمات", "حق نظارت")
    _TAX_PATTERNS = ("مالیات", "مالیات فروش")
    _BONUS_PATTERNS = ("افزایش سرمایه", "سهام جایزه", "حق تقدم")
    _SPLIT_PATTERNS = ("تجزیه", "تجمیع", "افزایش سرمایه از محل")
    _IGNORE_PATTERNS = ("لغو", "ابطال")

    _STRUCTURED_TYPE_RULES: list[tuple[str, NormalizedTransactionType]] = [
        ("مانده نقل از قبل", NormalizedTransactionType.OPENING_CASH_BALANCE),
        ("مانده از قبل", NormalizedTransactionType.OPENING_CASH_BALANCE),
        ("خرید", NormalizedTransactionType.BUY),
        ("فروش", NormalizedTransactionType.SELL),
        ("سود", NormalizedTransactionType.DIVIDEND),
        ("واریز", NormalizedTransactionType.DEPOSIT),
        ("برداشت", NormalizedTransactionType.WITHDRAWAL),
        ("کارمزد", NormalizedTransactionType.FEE),
        ("مالیات", NormalizedTransactionType.TAX),
        ("جایزه", NormalizedTransactionType.BONUS),
        ("افزایش سرمایه", NormalizedTransactionType.BONUS),
        ("تجزیه", NormalizedTransactionType.SPLIT),
        ("تجمیع", NormalizedTransactionType.SPLIT),
        ("لغو", NormalizedTransactionType.IGNORE),
        ("ابطال", NormalizedTransactionType.IGNORE),
    ]

    def parse_quantity(self, value: Any) -> Decimal:
        return self.to_decimal(value)

    def parse_unit_price(self, value: Any) -> Decimal:
        return self.to_decimal(value)

    def parse_currency_amount(self, value: Any) -> Decimal:
        return self.to_decimal(value)

    def compute_gross_trade_value(self, *, quantity: Decimal, unit_price: Decimal) -> Decimal:
        if quantity <= ZERO or unit_price <= ZERO:
            return ZERO
        return (quantity * unit_price).quantize(EIGHT_PLACES)

    @staticmethod
    def _pick_first_non_zero_decimal(row: dict[str, Any], keys: list[str], parser: "AgahParser") -> Decimal:
        for key in keys:
            if key in row and row[key] not in (None, ""):
                value = parser.parse_currency_amount(row[key])
                if value > ZERO:
                    return value
        return ZERO

    @staticmethod
    def _material_difference(left: Decimal, right: Decimal) -> bool:
        if left <= ZERO or right <= ZERO:
            return False
        diff = abs(left - right)
        baseline = max(left, right)
        # 5% or >= 1,000 IRR counts as a meaningful mismatch.
        return diff >= Decimal("1000") and (diff / baseline) >= Decimal("0.05")

    @staticmethod
    def _merge_warnings(warnings: list[str]) -> str | None:
        unique = [item for item in dict.fromkeys(warnings) if item]
        return " | ".join(unique) if unique else None

    @staticmethod
    def _sanitize_for_diagnostics(value: Any) -> Any:
        if BaseBrokerParser.is_missing(value):
            return ""
        if isinstance(value, dict):
            return {str(key): AgahParser._sanitize_for_diagnostics(item) for key, item in value.items()}
        if isinstance(value, (list, tuple)):
            return [AgahParser._sanitize_for_diagnostics(item) for item in value]
        return value

    def _parse_trade_from_description(self, normalized_description: str) -> dict[str, Any] | None:
        average_price_match = _AGAH_AVERAGE_PRICE_DESC_RE.search(normalized_description)
        if average_price_match:
            return {
                "side": None,
                "quantity": self.parse_quantity(average_price_match.group("qty")),
                "symbol": self.normalize_symbol(average_price_match.group("symbol")),
                "unit_price": self.parse_unit_price(average_price_match.group("price")),
                "parse_source": "agah_average_price_description",
            }

        match = _TRADE_DESC_RE.search(normalized_description) or _TRADE_DESC_FALLBACK_RE.search(normalized_description)
        if not match:
            return None
        return {
            "side": self.normalize_text(match.group("side")),
            "quantity": self.parse_quantity(match.group("qty")),
            "symbol": self.normalize_symbol(match.group("symbol")),
            "unit_price": self.parse_unit_price(match.group("price")),
            "parse_source": "pattern_trade_description",
        }

    def _classify_row(
        self,
        *,
        normalized_description: str,
        raw_type: str,
        debit: Decimal,
        credit: Decimal,
        row: dict[str, Any],
    ) -> AgahRowClassification:
        probe = f"{raw_type} {normalized_description}".strip()
        broker_symbol_raw = self.normalize_text(self.pick_first(row, ["نماد", "نماد دارایی", "نام نماد"]) or "")
        symbol_col = self.normalize_symbol(broker_symbol_raw)

        for token, normalized_type in self._STRUCTURED_TYPE_RULES:
            if token in raw_type:
                trade = (
                    self._parse_trade_from_description(normalized_description)
                    if normalized_type in {NormalizedTransactionType.BUY, NormalizedTransactionType.SELL}
                    else None
                )
                return AgahRowClassification(
                    normalized_type=normalized_type,
                    parse_source=str(trade["parse_source"]) if trade else "structured_type_column",
                    symbol=str(trade["symbol"]) if trade else symbol_col,
                    quantity=trade["quantity"] if trade else ZERO,
                    unit_price=trade["unit_price"] if trade else ZERO,
                    diagnostics={
                        "raw_type": raw_type,
                        "description": normalized_description,
                        "broker_symbol": broker_symbol_raw,
                        "normalized_symbol": (trade or {}).get("symbol") or symbol_col or None,
                    },
                )

        trade = self._parse_trade_from_description(normalized_description)
        if trade is not None:
            if trade["side"] == "خرید":
                normalized_type = NormalizedTransactionType.BUY
            elif trade["side"] == "فروش":
                normalized_type = NormalizedTransactionType.SELL
            elif "خرید" in raw_type:
                normalized_type = NormalizedTransactionType.BUY
            elif "فروش" in raw_type:
                normalized_type = NormalizedTransactionType.SELL
            elif (debit > ZERO) != (credit > ZERO):
                normalized_type = NormalizedTransactionType.BUY if debit > ZERO else NormalizedTransactionType.SELL
            else:
                normalized_type = NormalizedTransactionType.UNKNOWN
            return AgahRowClassification(
                normalized_type=normalized_type,
                parse_source=str(trade["parse_source"]),
                symbol=str(trade["symbol"]),
                quantity=trade["quantity"],
                unit_price=trade["unit_price"],
                diagnostics={
                    "raw_type": raw_type,
                    "description": normalized_description,
                    "broker_symbol": broker_symbol_raw,
                    "normalized_symbol": trade["symbol"] or symbol_col or None,
                },
            )

        if raw_type == "مانده" or any(token in probe for token in self._OPENING_BALANCE_PATTERNS):
            return AgahRowClassification(
                normalized_type=NormalizedTransactionType.OPENING_CASH_BALANCE,
                parse_source="pattern_opening_balance",
                symbol=symbol_col,
            )
        if any(token in probe for token in self._DIVIDEND_PATTERNS):
            return AgahRowClassification(
                normalized_type=NormalizedTransactionType.DIVIDEND,
                parse_source="pattern_dividend",
                symbol=symbol_col,
            )
        if any(token in probe for token in self._DEPOSIT_PATTERNS):
            return AgahRowClassification(
                normalized_type=NormalizedTransactionType.DEPOSIT,
                parse_source="pattern_deposit",
                symbol=symbol_col,
            )
        if any(token in probe for token in self._WITHDRAWAL_PATTERNS):
            return AgahRowClassification(
                normalized_type=NormalizedTransactionType.WITHDRAWAL,
                parse_source="pattern_withdrawal",
                symbol=symbol_col,
            )
        if any(token in probe for token in self._TAX_PATTERNS):
            return AgahRowClassification(
                normalized_type=NormalizedTransactionType.TAX,
                parse_source="pattern_tax",
                symbol=symbol_col,
            )
        if any(token in probe for token in self._FEE_PATTERNS):
            return AgahRowClassification(
                normalized_type=NormalizedTransactionType.FEE,
                parse_source="pattern_fee",
                symbol=symbol_col,
            )
        if any(token in probe for token in self._BONUS_PATTERNS):
            return AgahRowClassification(
                normalized_type=NormalizedTransactionType.BONUS,
                parse_source="pattern_bonus",
                symbol=symbol_col,
            )
        if any(token in probe for token in self._SPLIT_PATTERNS):
            split_diag: dict[str, Any] = {}
            split_match = _SPLIT_RATIO_RE.search(probe)
            if split_match:
                split_diag["split_from"] = format(self.parse_quantity(split_match.group(1)), "f")
                split_diag["split_to"] = format(self.parse_quantity(split_match.group(2)), "f")
            return AgahRowClassification(
                normalized_type=NormalizedTransactionType.SPLIT,
                parse_source="pattern_split",
                symbol=symbol_col,
                diagnostics=split_diag or None,
            )
        if any(token in probe for token in self._IGNORE_PATTERNS):
            return AgahRowClassification(
                normalized_type=NormalizedTransactionType.IGNORE,
                parse_source="pattern_ignore",
                symbol=symbol_col,
            )

        if symbol_col and (debit > ZERO) != (credit > ZERO):
            fallback_type = NormalizedTransactionType.BUY if debit > ZERO else NormalizedTransactionType.SELL
            return AgahRowClassification(
                normalized_type=fallback_type,
                parse_source="debit_credit_with_symbol",
                symbol=symbol_col,
                warning="Used debit/credit direction with symbol column as trade fallback.",
            )

        direction = "debit" if debit > credit else "credit" if credit > debit else "none"
        return AgahRowClassification(
            normalized_type=NormalizedTransactionType.UNKNOWN,
            parse_source="fallback_unknown",
            warning="Could not classify row from structured columns, Persian patterns, or debit/credit behavior.",
            diagnostics={
                "raw_type": raw_type,
                "description": normalized_description,
                "cash_direction": direction,
                "debit": format(debit, "f"),
                "credit": format(credit, "f"),
                "broker_symbol": broker_symbol_raw,
                "normalized_symbol": symbol_col or None,
            },
        )

    def _parse_single_row(
        self,
        *,
        row: dict[str, Any],
        source_file: str,
    ) -> tuple[NormalizedImportTransaction | None, ImportParseError | None]:
        row_number = int(row.get("__row_number__", 0) or 0)
        raw_description = self.normalize_text(self.pick_first(row, ["شرح", "description", "توضیحات"]) or "")
        normalized_description = self.normalize_text(raw_description)
        raw_type = self.normalize_text(self.pick_first(row, ["نوع", "عملیات"]) or "")
        raw_row = self._sanitize_for_diagnostics(row)

        debit = self.parse_currency_amount(
            self.pick_first(row, ["بدهکار(ریال)", "بدهکار (ریال)", "بدهکارریال", "بدهکار"])
        )
        credit = self.parse_currency_amount(
            self.pick_first(row, ["بستانکار(ریال)", "بستانکار (ریال)", "بستانکارریال", "بستانکار"])
        )
        balance_after = self.parse_currency_amount(
            self.pick_first(row, ["مانده(ریال)", "مانده (ریال)", "ماندهریال", "مانده"])
        )

        classification = self._classify_row(
            normalized_description=normalized_description,
            raw_type=raw_type,
            debit=debit,
            credit=credit,
            row=row,
        )

        parsed_trade = self._parse_trade_from_description(normalized_description) or {}
        symbol_col = self.normalize_symbol(self.pick_first(row, ["نماد", "نماد دارایی", "نام نماد"]) or "")
        symbol = classification.symbol or symbol_col or str(parsed_trade.get("symbol") or "")

        quantity = classification.quantity if classification.quantity > ZERO else self.parse_quantity(parsed_trade.get("quantity"))
        if quantity <= ZERO:
            quantity = self._pick_first_non_zero_decimal(row, ["تعداد", "حجم", "مقدار", "تعداد سهم"], self)

        unit_price = classification.unit_price if classification.unit_price > ZERO else self.parse_unit_price(parsed_trade.get("unit_price"))
        if unit_price <= ZERO:
            unit_price = self._pick_first_non_zero_decimal(
                row,
                ["نرخ", "قیمت", "قیمت هر سهم", "بهای واحد", "trade_price", "unit_price"],
                self,
            )

        gross_from_column = self._pick_first_non_zero_decimal(row, ["مبلغ ناخالص", "ناخالص", "gross", "ارزش ناخالص"], self)
        gross_amount = classification.gross_amount if classification.gross_amount > ZERO else gross_from_column
        if gross_amount <= ZERO:
            gross_amount = self.compute_gross_trade_value(quantity=quantity, unit_price=unit_price)

        if classification.normalized_type == NormalizedTransactionType.BUY:
            cash_reference = debit if debit > ZERO else credit
        elif classification.normalized_type == NormalizedTransactionType.SELL:
            cash_reference = credit if credit > ZERO else debit
        else:
            cash_reference = credit if credit > ZERO else debit

        fees = self.parse_currency_amount(self.pick_first(row, ["کارمزد", "هزینه", "fee", "commission"]))
        tax = self.parse_currency_amount(self.pick_first(row, ["مالیات", "tax"]))
        if fees <= ZERO and "کارمزد" in normalized_description:
            fee_match = _MONEY_IN_TEXT_RE.search(normalized_description)
            if fee_match:
                fees = self.parse_currency_amount(fee_match.group(1))
        if tax <= ZERO and "مالیات" in normalized_description:
            tax_match = _MONEY_IN_TEXT_RE.search(normalized_description)
            if tax_match:
                tax = self.parse_currency_amount(tax_match.group(1))

        warnings: list[str] = []
        if classification.warning:
            warnings.append(classification.warning)

        if classification.normalized_type in {NormalizedTransactionType.BUY, NormalizedTransactionType.SELL}:
            missing_trade_parts = []
            if not symbol:
                missing_trade_parts.append("نماد")
                warnings.append("اطلاعات تعداد، نماد یا قیمت از شرح تراکنش قابل تشخیص نیست.")
            if quantity <= ZERO:
                missing_trade_parts.append("تعداد")
                warnings.append("اطلاعات تعداد، نماد یا قیمت از شرح تراکنش قابل تشخیص نیست.")
            if unit_price <= ZERO:
                missing_trade_parts.append("قیمت واحد")
                if symbol and quantity > ZERO:
                    warnings.append("قیمت واحد (unit price) از شرح تراکنش قابل تشخیص نیست.")
                else:
                    warnings.append("اطلاعات تعداد، نماد یا قیمت از شرح تراکنش قابل تشخیص نیست.")

            if quantity > Decimal("1") and unit_price > ZERO and cash_reference > ZERO and unit_price == cash_reference:
                warnings.append(
                    "Parser bug guard: parsed unit price equals total debit/credit cash amount; probable gross-as-price mapping."
                )

            if gross_amount <= ZERO and quantity > ZERO and unit_price > ZERO:
                gross_amount = self.compute_gross_trade_value(quantity=quantity, unit_price=unit_price)

            if gross_amount > ZERO and cash_reference > ZERO and self._material_difference(gross_amount, cash_reference):
                warnings.append(
                    "Reconciliation warning: quantity*unit_price materially differs from debit/credit cash amount."
                )

            if not symbol or quantity <= ZERO or unit_price <= ZERO:
                classification = AgahRowClassification(
                    normalized_type=NormalizedTransactionType.UNKNOWN,
                    parse_source="trade_validation_failed",
                    warning=self._merge_warnings(warnings)
                    or "اطلاعات تعداد، نماد یا قیمت از شرح تراکنش قابل تشخیص نیست.",
                    diagnostics={
                        "raw_type": raw_type,
                        "normalized_description": normalized_description,
                        "missing_fields": missing_trade_parts,
                    },
                )

        if classification.normalized_type in {
            NormalizedTransactionType.FEE,
            NormalizedTransactionType.TAX,
            NormalizedTransactionType.WITHDRAWAL,
            NormalizedTransactionType.OPENING_CASH_BALANCE,
        }:
            total_amount = debit if debit > ZERO else credit
        elif classification.normalized_type in {
            NormalizedTransactionType.SELL,
            NormalizedTransactionType.DIVIDEND,
            NormalizedTransactionType.DEPOSIT,
        }:
            total_amount = credit if credit > ZERO else debit
        else:
            total_amount = debit if debit > ZERO else credit

        if total_amount <= ZERO:
            total_amount = self._pick_first_non_zero_decimal(row, ["مبلغ", "ارزش", "جمع"], self)

        if classification.normalized_type in {NormalizedTransactionType.BUY, NormalizedTransactionType.SELL} and gross_amount > ZERO:
            net_amount = total_amount if total_amount > ZERO else gross_amount
        else:
            net_amount = total_amount

        cash_effect = net_amount
        if classification.normalized_type == NormalizedTransactionType.BUY:
            cash_effect = -net_amount
            if fees <= ZERO and debit > gross_amount > ZERO:
                fees = (debit - gross_amount).quantize(EIGHT_PLACES)
            if debit > ZERO and debit < gross_amount:
                warnings.append("مبلغ بدهکار کمتر از حاصل‌ضرب تعداد در قیمت است؛ لطفاً بررسی شود.")
        elif classification.normalized_type == NormalizedTransactionType.SELL:
            if fees <= ZERO and gross_amount > credit > ZERO:
                fees = (gross_amount - credit).quantize(EIGHT_PLACES)
        elif classification.normalized_type in {
            NormalizedTransactionType.WITHDRAWAL,
            NormalizedTransactionType.FEE,
            NormalizedTransactionType.TAX,
        }:
            cash_effect = -net_amount

        inferred_fee_or_adjustment = ZERO
        if classification.normalized_type in {NormalizedTransactionType.BUY, NormalizedTransactionType.SELL}:
            inferred_fee_or_adjustment = abs(net_amount - gross_amount).quantize(EIGHT_PLACES)

        if classification.normalized_type == NormalizedTransactionType.IGNORE:
            return (
                NormalizedImportTransaction(
                    row_number=row_number,
                    date=self.parse_jalali_or_gregorian(self.pick_first(row, ["زمان", "تاریخ", "date"])),
                    symbol=symbol or "",
                    transaction_type=NormalizedTransactionType.IGNORE,
                    quantity=ZERO,
                    price_per_unit=ZERO,
                    total_amount=ZERO,
                    broker=self.broker,
                    source_file=source_file,
                    raw_text=raw_description,
                    normalized_description=normalized_description,
                    confidence_source=classification.parse_source,
                    warning=self._merge_warnings(warnings),
                    diagnostics={
                        **(classification.diagnostics or {}),
                        "normalized_type": classification.normalized_type.value,
                        "parse_source": classification.parse_source,
                        "raw_description": raw_description,
                        "raw_row": raw_row,
                        "normalized_description": normalized_description,
                        "transaction_datetime": self.parse_jalali_or_gregorian(
                            self.pick_first(row, ["زمان", "تاریخ", "date"])
                        ).isoformat(),
                        "source_row_number": row_number,
                        "debit_amount": format(debit, "f"),
                        "credit_amount": format(credit, "f"),
                        "balance_after": format(balance_after, "f") if balance_after > ZERO else None,
                        "debit": format(debit, "f"),
                        "credit": format(credit, "f"),
                        "extracted_quantity": format(quantity, "f"),
                        "extracted_symbol": symbol or None,
                        "extracted_unit_price": format(unit_price, "f"),
                        "extracted_gross_amount": format(gross_amount, "f"),
                        "row_number": row_number,
                    },
                ),
                None,
            )

        return (
            NormalizedImportTransaction(
                row_number=row_number,
                date=self.parse_jalali_or_gregorian(self.pick_first(row, ["زمان", "تاریخ", "date"])),
                symbol=symbol or "",
                transaction_type=classification.normalized_type,
                quantity=quantity if quantity > ZERO else ZERO,
                price_per_unit=unit_price if unit_price > ZERO else ZERO,
                total_amount=total_amount if total_amount > ZERO else ZERO,
                broker=self.broker,
                source_file=source_file,
                raw_text=raw_description,
                normalized_description=normalized_description,
                confidence_source=classification.parse_source,
                warning=classification.warning or self._merge_warnings(warnings),
                fees=fees if fees > ZERO else ZERO,
                tax=tax if tax > ZERO else ZERO,
                net_amount=net_amount if net_amount > ZERO else ZERO,
                diagnostics={
                    **(classification.diagnostics or {}),
                    "normalized_type": classification.normalized_type.value,
                    "parse_source": classification.parse_source,
                    "raw_description": raw_description,
                    "raw_row": raw_row,
                    "normalized_description": normalized_description,
                    "transaction_datetime": self.parse_jalali_or_gregorian(
                        self.pick_first(row, ["زمان", "تاریخ", "date"])
                    ).isoformat(),
                    "source_row_number": row_number,
                    "debit_amount": format(debit, "f"),
                    "credit_amount": format(credit, "f"),
                    "balance_after": format(balance_after, "f") if balance_after > ZERO else None,
                    "debit": format(debit, "f"),
                    "credit": format(credit, "f"),
                    "extracted_quantity": format(quantity, "f"),
                    "extracted_symbol": symbol or None,
                    "extracted_unit_price": format(unit_price, "f"),
                    "extracted_gross_amount": format(gross_amount, "f"),
                    "gross_amount": format(gross_amount, "f"),
                    "net_amount": format(net_amount, "f"),
                    "cash_effect": format(cash_effect, "f"),
                    "inferred_fee_or_adjustment": format(inferred_fee_or_adjustment, "f")
                    if inferred_fee_or_adjustment > ZERO
                    else None,
                    "inferred_fee": format(fees, "f") if fees > ZERO else None,
                    "row_number": row_number,
                    "warnings": warnings,
                },
            ),
            None,
        )
