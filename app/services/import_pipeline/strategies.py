"""Strategy implementations for broker-specific parsing and semantics."""

from __future__ import annotations

import re
from abc import ABC, abstractmethod
from datetime import UTC, datetime
from decimal import Decimal, InvalidOperation
from typing import Final

import pandas as pd

from app.services.import_pipeline.models import (
    ImportMode,
    ImportParseResult,
    ParsedHoldingRow,
    ParsedTradeRow,
    TradeAction,
)
from app.services.import_pipeline.normalization import normalize_symbol, parse_decimal

ZERO: Final[Decimal] = Decimal("0")


class BaseImportStrategy(ABC):
    format_name: str
    import_mode: ImportMode  # TRADES or SNAPSHOT

    @abstractmethod
    def can_handle(self, columns: set[str], sample_rows: list[dict[str, object]]) -> bool:
        """Return True if this strategy recognizes the workbook signature."""

    @abstractmethod
    def parse(self, df: pd.DataFrame) -> ImportParseResult:
        """Parse broker rows into normalized intermediate DTOs."""


class _HeaderMatchMixin:
    required_headers: set[str]

    def _has_signature(self, columns: set[str]) -> bool:
        return self.required_headers.issubset(columns)


class AghahLedgerStrategy(BaseImportStrategy, _HeaderMatchMixin):
    format_name = "AGHAH"
    import_mode = ImportMode.TRADES
    required_headers = {
        "ردیف",
        "نوع",
        "شرح",
        "زمان",
        "بدهکار(ریال)",
        "بستانکار(ریال)",
        "مانده(ریال)",
    }
    _desc_pattern = re.compile(
        r"تعداد\s+(?P<qty>[0-9۰-۹٠-٩,٬.]+)\s+سهم\s+(?P<symbol>.+?)\s+با\s+قیمت\s+میانگین\s+(?P<price>[0-9۰-۹٠-٩,٬.]+)"
    )

    def can_handle(self, columns: set[str], sample_rows: list[dict[str, object]]) -> bool:
        if not self._has_signature(columns):
            return False
        return True

    def parse(self, df: pd.DataFrame) -> ImportParseResult:
        parsed: list[ParsedTradeRow] = []
        warnings: list[str] = []
        skipped_rows = 0

        for row_no, row in enumerate(df.to_dict(orient="records"), start=1):
            description = str(row.get("شرح") or "").strip()
            if _looks_like_non_trade_cash_row(description):
                skipped_rows += 1
                warnings.append(f"row {row_no}: non-trade cash movement row ignored")
                continue

            type_text = str(row.get("نوع") or "").strip()
            debit = parse_decimal(row.get("بدهکار(ریال)")) or ZERO
            credit = parse_decimal(row.get("بستانکار(ریال)")) or ZERO

            match = self._desc_pattern.search(description)
            symbol_raw = match.group("symbol") if match else ""
            quantity = parse_decimal(match.group("qty") if match else None)
            description_price = parse_decimal(match.group("price") if match else None)
            gross_from_ledger = debit if debit > ZERO else credit

            if quantity is None or quantity <= ZERO:
                skipped_rows += 1
                warnings.append(f"row {row_no}: quantity parse failure")
                continue

            unit_price = description_price
            if unit_price is None and gross_from_ledger > ZERO:
                unit_price = gross_from_ledger / quantity

            if unit_price is None or unit_price <= ZERO:
                skipped_rows += 1
                warnings.append(f"row {row_no}: unit price parse failure")
                continue

            trade_date = _parse_datetime(row.get("زمان"))
            if trade_date is None:
                skipped_rows += 1
                warnings.append(f"row {row_no}: trade_date parse failure")
                continue

            normalized = normalize_symbol(symbol_raw)
            if not normalized:
                skipped_rows += 1
                warnings.append(f"row {row_no}: symbol parse failure")
                continue

            side = _resolve_trade_side(
                explicit_type=type_text,
                description=description,
                debit=debit,
                credit=credit,
            )
            if side is None:
                skipped_rows += 1
                warnings.append(f"row {row_no}: side resolution failed")
                continue

            gross_amount = quantity * unit_price
            parsed.append(
                ParsedTradeRow(
                    row_number=row_no,
                    symbol_raw=symbol_raw,
                    symbol_normalized=normalized,
                    side=side,
                    trade_date=trade_date,
                    quantity=quantity,
                    unit_price=unit_price,
                    gross_amount=gross_amount,
                    raw_description=description,
                    source_broker=self.format_name,
                )
            )

        return ImportParseResult(
            format_name=self.format_name,
            import_mode=self.import_mode,
            parsed_trades=parsed,
            parsed_holdings=[],
            skipped_rows=skipped_rows,
            warnings=warnings,
        )


class MofidLedgerStrategy(BaseImportStrategy, _HeaderMatchMixin):
    format_name = "MOFID"
    import_mode = ImportMode.TRADES
    required_headers = {
        "تاریخ",
        "شرح",
        "نماد دارایی",
        "بدهکار",
        "بستانکار",
        "مانده",
    }
    _qty_pattern = re.compile(r"(?P<qty>[0-9۰-۹٠-٩,٬.]+)\s*سهم")
    _price_pattern = re.compile(r"(?:به\s*نرخ|قیمت|میانگین)\s*(?P<price>[0-9۰-۹٠-٩,٬.]+)")
    _trade_pattern = re.compile(
        r"(?:خرید|فروش)\s*[0-9۰-۹٠-٩,٬.]+\s*سهم\s*"
        r"(?:سهامی\s+عا\s*\()?\s*(?P<symbol>[A-Za-z0-9\u0600-\u06FF]+)\)?"
    )

    def can_handle(self, columns: set[str], sample_rows: list[dict[str, object]]) -> bool:
        return self._has_signature(columns)

    def parse(self, df: pd.DataFrame) -> ImportParseResult:
        parsed: list[ParsedTradeRow] = []
        warnings: list[str] = []
        skipped_rows = 0

        for row_no, row in enumerate(df.to_dict(orient="records"), start=1):
            description_value = row.get("شرح")
            description = "" if pd.isna(description_value) else str(description_value or "").strip()
            symbol_value = row.get("نماد دارایی")
            symbol_raw = "" if pd.isna(symbol_value) else str(symbol_value or "").strip()
            debit = parse_decimal(row.get("بدهکار")) or ZERO
            credit = parse_decimal(row.get("بستانکار")) or ZERO
            if _looks_like_non_trade_cash_row(description):
                skipped_rows += 1
                warnings.append(f"row {row_no}: non-trade cash movement row ignored")
                continue

            qty_match = self._qty_pattern.search(description)
            price_match = self._price_pattern.search(description)
            trade_match = self._trade_pattern.search(description)
            if not symbol_raw and trade_match:
                symbol_raw = trade_match.group("symbol")
            quantity = parse_decimal(qty_match.group("qty") if qty_match else None)
            unit_price = parse_decimal(price_match.group("price") if price_match else None)

            gross_from_ledger = debit if debit > ZERO else credit
            if quantity is None and unit_price is not None and unit_price > ZERO and gross_from_ledger > ZERO:
                quantity = gross_from_ledger / unit_price
            if unit_price is None and quantity is not None and quantity > ZERO and gross_from_ledger > ZERO:
                unit_price = gross_from_ledger / quantity

            if quantity is None or quantity <= ZERO or unit_price is None or unit_price <= ZERO:
                skipped_rows += 1
                warnings.append(f"row {row_no}: quantity/unit price parse failure")
                continue

            trade_date = _parse_datetime(row.get("تاریخ"))
            if trade_date is None:
                skipped_rows += 1
                warnings.append(f"row {row_no}: trade_date parse failure")
                continue

            normalized = normalize_symbol(symbol_raw)
            if not normalized:
                skipped_rows += 1
                warnings.append(f"row {row_no}: symbol parse failure")
                continue

            side = _resolve_trade_side(
                explicit_type="",
                description=description,
                debit=debit,
                credit=credit,
            )
            if side is None:
                skipped_rows += 1
                warnings.append(f"row {row_no}: side resolution failed")
                continue

            parsed.append(
                ParsedTradeRow(
                    row_number=row_no,
                    symbol_raw=symbol_raw,
                    symbol_normalized=normalized,
                    side=side,
                    trade_date=trade_date,
                    quantity=quantity,
                    unit_price=unit_price,
                    gross_amount=quantity * unit_price,
                    raw_description=description,
                    source_broker=self.format_name,
                )
            )

        return ImportParseResult(
            format_name=self.format_name,
            import_mode=self.import_mode,
            parsed_trades=parsed,
            parsed_holdings=[],
            skipped_rows=skipped_rows,
            warnings=warnings,
        )


class BoursiranSnapshotStrategy(BaseImportStrategy, _HeaderMatchMixin):
    format_name = "BOURSIRAN"
    import_mode = ImportMode.SNAPSHOT
    required_headers = {
        "نماد",
        "تعداد",
        "میانگین خرید",
        "بهای تمام شده خرید",
    }

    def can_handle(self, columns: set[str], sample_rows: list[dict[str, object]]) -> bool:
        return self._has_signature(columns)

    def parse(self, df: pd.DataFrame) -> ImportParseResult:
        parsed: list[ParsedHoldingRow] = []
        warnings: list[str] = []
        skipped_rows = 0

        for row_no, row in enumerate(df.to_dict(orient="records"), start=1):
            symbol_raw = str(row.get("نماد") or "").strip()
            quantity = parse_decimal(row.get("تعداد"))
            average_cost = parse_decimal(row.get("میانگین خرید"))
            cost_basis = parse_decimal(row.get("بهای تمام شده خرید"))

            if quantity is None or quantity <= ZERO:
                skipped_rows += 1
                warnings.append(f"row {row_no}: quantity parse failure")
                continue
            if average_cost is None and cost_basis is not None and quantity > ZERO:
                average_cost = cost_basis / quantity
            if cost_basis is None and average_cost is not None:
                cost_basis = average_cost * quantity
            if average_cost is None or average_cost < ZERO or cost_basis is None or cost_basis < ZERO:
                skipped_rows += 1
                warnings.append(f"row {row_no}: average_cost/cost_basis parse failure")
                continue

            normalized = normalize_symbol(symbol_raw)
            if not normalized:
                skipped_rows += 1
                warnings.append(f"row {row_no}: symbol parse failure")
                continue

            market_price = _first_decimal(
                row,
                (
                    "ق آخرین معامله",
                    "قیمت آخرین معامله",
                    "قیمت پایانی",
                    "قیمت روز",
                ),
            )
            market_value = _first_decimal(
                row,
                (
                    "ارزش روز",
                    "ارزش جاری",
                    "ارزش بازار",
                    "ارزش",
                ),
            )
            unrealized_pnl = None
            if market_value is not None:
                unrealized_pnl = market_value - cost_basis
            weight_percent = _first_decimal(
                row,
                (
                    "درصد وزن",
                    "درصد",
                    "وزن",
                ),
            )
            parsed.append(
                ParsedHoldingRow(
                    row_number=row_no,
                    symbol_raw=symbol_raw,
                    symbol_normalized=normalized,
                    quantity=quantity,
                    average_cost=average_cost,
                    cost_basis=cost_basis,
                    market_price=market_price,
                    market_value=market_value,
                    unrealized_pnl=unrealized_pnl,
                    weight_percent=weight_percent,
                    source_broker=self.format_name,
                )
            )

        return ImportParseResult(
            format_name=self.format_name,
            import_mode=self.import_mode,
            parsed_trades=[],
            parsed_holdings=parsed,
            skipped_rows=skipped_rows,
            warnings=warnings,
        )


def _parse_datetime(value: object) -> datetime | None:
    if value is None:
        return None
    text = str(value).strip()
    if not text:
        return None
    normalized = text.replace("/", "-")
    # Allow YYYY-MM-DD and YYYY-MM-DD HH:MM[:SS]
    try:
        dt = datetime.fromisoformat(normalized)
    except ValueError:
        for fmt in ("%Y-%m-%d", "%Y-%m-%d %H:%M", "%Y-%m-%d %H:%M:%S"):
            try:
                dt = datetime.strptime(normalized, fmt)
                break
            except ValueError:
                dt = None
        if dt is None:
            return None
    if dt.tzinfo is None:
        return dt.replace(tzinfo=UTC)
    return dt.astimezone(UTC)


def _first_decimal(row: dict[str, object], keys: tuple[str, ...]) -> Decimal | None:
    for key in keys:
        if key not in row:
            continue
        parsed = parse_decimal(row.get(key))
        if parsed is not None:
            return parsed
    return None


def _resolve_trade_side(
    *,
    explicit_type: str,
    description: str,
    debit: Decimal,
    credit: Decimal,
) -> TradeAction | None:
    type_text = explicit_type.strip().lower()
    if "خرید" in type_text or "buy" in type_text:
        return TradeAction.BUY
    if "فروش" in type_text or "sell" in type_text:
        return TradeAction.SELL

    desc_text = description.strip().lower()
    if "خرید" in desc_text or "buy" in desc_text:
        return TradeAction.BUY
    if "فروش" in desc_text or "sell" in desc_text:
        return TradeAction.SELL

    if debit > ZERO and credit <= ZERO:
        return TradeAction.BUY
    if credit > ZERO and debit <= ZERO:
        return TradeAction.SELL
    return None


def _looks_like_non_trade_cash_row(description: str) -> bool:
    lowered = description.strip().lower()
    if not lowered:
        return True

    # Trade rows should mention share quantity context; cash-only rows should be skipped.
    if "سهم" in lowered:
        return False

    cash_tokens = (
        "واریز",
        "برداشت",
        "انتقال وجه",
        "کارمزد",
        "مانده",
        "سود",
        "cash",
        "deposit",
        "withdraw",
        "balance",
    )
    return any(token in lowered for token in cash_tokens)


# Backward compatibility with previous strategy names.
AgahStrategy = AghahLedgerStrategy
MofidStrategy = MofidLedgerStrategy
BoursiranStrategy = BoursiranSnapshotStrategy
BrokerParserStrategy = BaseImportStrategy
