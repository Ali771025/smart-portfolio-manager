"""Broker-aware parser strategies for Agah, Mofid, and Boursiran imports."""

from __future__ import annotations

from datetime import UTC
from decimal import Decimal
from typing import Any

from app.schemas.multi_portfolio_import import BrokerType, ImportRowStatus, ImportType
from app.services.multi_portfolio_import_models import (
    BrokerParser,
    ParseContext,
    ParseOutput,
    ParsedRow,
    RowSemanticType,
)
from app.services.multi_portfolio_import_utils import (
    normalize_string,
    parse_datetime_flexible,
    parse_decimal,
    parse_trade_details_from_description,
)

ZERO = Decimal("0")
MAX_LEDGER_AMOUNT_DIFF = Decimal("10")


class AgahLedgerParser(BrokerParser):
    broker = BrokerType.AGAH
    import_type = ImportType.LEDGER_TRANSACTIONS
    required_headers = {"ردیف", "نوع", "شرح", "زمان", "بدهکار(ریال)", "بستانکار(ریال)", "مانده(ریال)"}

    def can_handle(self, headers: list[str]) -> bool:
        return self.required_headers.issubset(set(headers))

    def parse(self, rows: list[dict[str, Any]], ctx: ParseContext) -> ParseOutput:
        parsed_rows: list[ParsedRow] = []
        for index, raw in enumerate(rows, start=1):
            description = normalize_string(raw.get("شرح"))
            trade_at = parse_datetime_flexible(raw.get("زمان"))
            debit = parse_decimal(raw.get("بدهکار(ریال)")) or ZERO
            credit = parse_decimal(raw.get("بستانکار(ریال)")) or ZERO
            running_balance = parse_decimal(raw.get("مانده(ریال)"))
            symbol, quantity, unit_price = parse_trade_details_from_description(description)
            side_sum = int(debit > ZERO) + int(credit > ZERO)

            messages: list[str] = []
            status = ImportRowStatus.VALID
            if not description:
                messages.append("شرح خالی است.")
            if trade_at is None:
                messages.append("زمان نامعتبر است.")
            if side_sum != 1:
                messages.append("دقیقا یکی از بدهکار/بستانکار باید مثبت باشد.")
            if not symbol:
                messages.append("نماد معامله از شرح قابل استخراج نیست.")
            if quantity is None or quantity <= ZERO:
                messages.append("تعداد معامله از شرح قابل استخراج نیست.")
            if unit_price is None or unit_price <= ZERO:
                messages.append("قیمت واحد معامله از شرح قابل استخراج نیست.")
            if quantity is not None and quantity > ZERO and unit_price is not None and unit_price > ZERO:
                expected_total = quantity * unit_price
                ledger_total = debit if debit > ZERO else credit
                if abs(expected_total - ledger_total) > MAX_LEDGER_AMOUNT_DIFF:
                    messages.append("عدم تطابق مبلغ شرح با بدهکار/بستانکار.")
            if messages:
                status = ImportRowStatus.INVALID

            normalized = {
                "trade_at": trade_at.isoformat() if trade_at else None,
                "symbol": symbol,
                "description": description,
                "quantity": str(quantity) if quantity is not None else None,
                "unit_price": str(unit_price) if unit_price is not None else None,
                "debit": str(debit),
                "credit": str(credit),
                "running_balance": str(running_balance) if running_balance is not None else None,
                "broker": self.broker.value,
                "import_type": self.import_type.value,
            }

            fingerprint = None
            if status == ImportRowStatus.VALID and trade_at is not None:
                fingerprint = "|".join(
                    [
                        str(ctx.portfolio_id),
                        self.broker.value,
                        trade_at.astimezone(UTC).isoformat(),
                        normalize_string(symbol),
                        str(quantity),
                        str(unit_price),
                        normalize_string(description),
                        str(debit),
                        str(credit),
                        str(running_balance or ZERO),
                    ]
                )

            parsed_rows.append(
                ParsedRow(
                    row_no=index,
                    raw=raw,
                    normalized=normalized,
                    semantic_type=RowSemanticType.TRADE_ROW,
                    status=status,
                    messages=messages,
                    duplicate_fingerprint=fingerprint,
                )
            )

        return ParseOutput(
            broker=self.broker,
            import_type=self.import_type,
            rows=parsed_rows,
            warnings=[],
        )


class MofidLedgerParser(BrokerParser):
    broker = BrokerType.MOFID
    import_type = ImportType.LEDGER_TRANSACTIONS
    required_headers = {"تاریخ", "شرح", "نماد دارایی", "بدهکار", "بستانکار", "مانده"}

    def can_handle(self, headers: list[str]) -> bool:
        return self.required_headers.issubset(set(headers))

    def parse(self, rows: list[dict[str, Any]], ctx: ParseContext) -> ParseOutput:
        parsed_rows: list[ParsedRow] = []
        for index, raw in enumerate(rows, start=1):
            description = normalize_string(raw.get("شرح"))
            symbol = normalize_string(raw.get("نماد دارایی")) or None
            trade_at = parse_datetime_flexible(raw.get("تاریخ"))
            debit = parse_decimal(raw.get("بدهکار")) or ZERO
            credit = parse_decimal(raw.get("بستانکار")) or ZERO
            running_balance = parse_decimal(raw.get("مانده"))
            parsed_symbol, quantity, unit_price = parse_trade_details_from_description(description)
            if symbol is None:
                symbol = parsed_symbol
            side_sum = int(debit > ZERO) + int(credit > ZERO)

            messages: list[str] = []
            status = ImportRowStatus.VALID
            if not description:
                messages.append("شرح خالی است.")
            if trade_at is None:
                messages.append("تاریخ نامعتبر است.")
            if side_sum != 1:
                messages.append("دقیقا یکی از بدهکار/بستانکار باید مثبت باشد.")
            if not symbol:
                messages.append("نماد معامله مشخص نیست.")
            if quantity is None or quantity <= ZERO:
                messages.append("تعداد معامله از شرح قابل استخراج نیست.")
            if unit_price is None or unit_price <= ZERO:
                messages.append("قیمت واحد معامله از شرح قابل استخراج نیست.")
            if quantity is not None and quantity > ZERO and unit_price is not None and unit_price > ZERO:
                expected_total = quantity * unit_price
                ledger_total = debit if debit > ZERO else credit
                if abs(expected_total - ledger_total) > MAX_LEDGER_AMOUNT_DIFF:
                    messages.append("عدم تطابق مبلغ شرح با بدهکار/بستانکار.")
            if messages:
                status = ImportRowStatus.INVALID

            normalized = {
                "trade_at": trade_at.isoformat() if trade_at else None,
                "symbol": symbol,
                "description": description,
                "quantity": str(quantity) if quantity is not None else None,
                "unit_price": str(unit_price) if unit_price is not None else None,
                "debit": str(debit),
                "credit": str(credit),
                "running_balance": str(running_balance) if running_balance is not None else None,
                "broker": self.broker.value,
                "import_type": self.import_type.value,
            }

            fingerprint = None
            if status == ImportRowStatus.VALID and trade_at is not None:
                fingerprint = "|".join(
                    [
                        str(ctx.portfolio_id),
                        self.broker.value,
                        trade_at.astimezone(UTC).isoformat(),
                        normalize_string(symbol),
                        str(quantity),
                        str(unit_price),
                        normalize_string(description),
                        str(debit),
                        str(credit),
                        str(running_balance or ZERO),
                    ]
                )

            parsed_rows.append(
                ParsedRow(
                    row_no=index,
                    raw=raw,
                    normalized=normalized,
                    semantic_type=RowSemanticType.TRADE_ROW,
                    status=status,
                    messages=messages,
                    duplicate_fingerprint=fingerprint,
                )
            )

        return ParseOutput(
            broker=self.broker,
            import_type=self.import_type,
            rows=parsed_rows,
            warnings=[],
        )


class BoursiranSnapshotParser(BrokerParser):
    broker = BrokerType.BOURSIRAN
    import_type = ImportType.HOLDINGS_SNAPSHOT
    required_headers = {
        "نماد",
        "تعداد",
        "ق آخرین معامله",
        "ارزش دیروز",
        "ارزش امروز",
        "میانگین خرید",
        "بهای تمام شده خرید",
        "سود و زیان مانده",
        "٪ سود و زیان مانده",
        "ق سر به سر فروش",
        "ارزش خالص فروش",
        "سود و زیان فروش",
        "سود و زیان امروز",
        "٪ از پورتفو",
    }

    def can_handle(self, headers: list[str]) -> bool:
        return self.required_headers.issubset(set(headers))

    def parse(self, rows: list[dict[str, Any]], ctx: ParseContext) -> ParseOutput:
        parsed_rows: list[ParsedRow] = []
        for index, raw in enumerate(rows, start=1):
            symbol = normalize_string(raw.get("نماد"))
            quantity = parse_decimal(raw.get("تعداد"))
            market_value_today = parse_decimal(raw.get("ارزش امروز"))
            cost_basis = parse_decimal(raw.get("بهای تمام شده خرید"))
            weight_pct = parse_decimal(raw.get("٪ از پورتفو"))

            messages: list[str] = []
            status = ImportRowStatus.VALID
            if not symbol:
                messages.append("نماد خالی است.")
            if quantity is None or quantity <= ZERO:
                messages.append("تعداد باید بزرگ‌تر از صفر باشد.")
            if market_value_today is None or market_value_today < ZERO:
                messages.append("ارزش امروز نامعتبر است.")
            if cost_basis is None or cost_basis < ZERO:
                messages.append("بهای تمام شده خرید نامعتبر است.")
            if messages:
                status = ImportRowStatus.INVALID

            normalized = {
                "snapshot_at": ctx.now_utc.isoformat(),
                "symbol": symbol,
                "quantity": str(quantity) if quantity is not None else None,
                "market_value_today": str(market_value_today) if market_value_today is not None else None,
                "cost_basis": str(cost_basis) if cost_basis is not None else None,
                "weight_pct": str(weight_pct) if weight_pct is not None else None,
                "broker": self.broker.value,
                "import_type": self.import_type.value,
            }

            fingerprint = None
            if status == ImportRowStatus.VALID:
                fingerprint = "|".join(
                    [
                        str(ctx.portfolio_id),
                        self.broker.value,
                        ctx.now_utc.date().isoformat(),
                        symbol,
                        str(quantity),
                        str(market_value_today),
                    ]
                )

            parsed_rows.append(
                ParsedRow(
                    row_no=index,
                    raw=raw,
                    normalized=normalized,
                    semantic_type=RowSemanticType.HOLDING_SNAPSHOT_ROW,
                    status=status,
                    messages=messages,
                    duplicate_fingerprint=fingerprint,
                )
            )

        return ParseOutput(
            broker=self.broker,
            import_type=self.import_type,
            rows=parsed_rows,
            warnings=["فایل بورسیران به صورت Snapshot پردازش شد و هرگز Ledger محسوب نمی‌شود."],
        )


ALL_PARSERS: tuple[BrokerParser, ...] = (
    AgahLedgerParser(),
    MofidLedgerParser(),
    BoursiranSnapshotParser(),
)
