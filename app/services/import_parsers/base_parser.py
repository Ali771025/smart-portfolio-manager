"""Base types and helpers for broker-specific Excel parsers."""

from __future__ import annotations

import re
from dataclasses import dataclass
from datetime import UTC, datetime, timedelta
from decimal import Decimal, InvalidOperation, ROUND_HALF_UP
from enum import StrEnum
from typing import Any

import jdatetime

EIGHT_PLACES = Decimal("0.00000001")
ZERO = Decimal("0.00000000")
PERSIAN_DIGITS_MAP = str.maketrans("۰۱۲۳۴۵۶۷۸۹", "0123456789")
ARABIC_DIGITS_MAP = str.maketrans("٠١٢٣٤٥٦٧٨٩", "0123456789")
ARABIC_TO_PERSIAN_MAP = str.maketrans({"ي": "ی", "ى": "ی", "ك": "ک"})

BUY_KEYWORDS = ("خرید", "buy")
SELL_KEYWORDS = ("فروش", "sell")
DEPOSIT_KEYWORDS = ("واریز", "واريز", "شارژ", "deposit")
DIVIDEND_KEYWORDS = ("سود", "dividend")
FEE_KEYWORDS = ("کارمزد", "هزینه", "fee", "commission")
WITHDRAWAL_KEYWORDS = ("برداشت", "withdrawal", "پرداخت")
TAX_KEYWORDS = ("مالیات", "tax")
BONUS_KEYWORDS = ("سهام جایزه", "افزایش سرمایه")
SPLIT_KEYWORDS = ("تجزیه", "تجمیع", "split")
IGNORE_KEYWORDS = ("ابطال", "لغو", "cancelled")
OPENING_BALANCE_KEYWORDS = ("مانده نقل از قبل", "مانده ابتدا دوره", "opening balance")

SYMBOL_INLINE_RE = re.compile(r"(?:سهم|نماد)\s*[:\-]?\s*([A-Za-z0-9\u0600-\u06FF]+)")
BUY_SELL_QTY_SYMBOL_RE = re.compile(
    r"(?:خرید|فروش)\s*([0-9۰-۹٠-٩,./]+)\s*(?:سهم)?\s*([A-Za-z0-9\u0600-\u06FF]+)"
)
QTY_RE = re.compile(r"(?:تعداد|حجم)\s*[:\-]?\s*([0-9۰-۹٠-٩,./]+)")
PRICE_RE = re.compile(r"(?:قیمت|بهای)\s*(?:هر\s*سهم)?\s*[:\-]?\s*([0-9۰-۹٠-٩,./]+)")


class BrokerType(StrEnum):
    MOFID = "MOFID"
    AGAH = "AGAH"
    BOURSIRAN = "BOURSIRAN"
    GANDAM = "GANDAM"


class NormalizedTransactionType(StrEnum):
    BUY = "BUY"
    SELL = "SELL"
    DIVIDEND = "DIVIDEND"
    DEPOSIT = "DEPOSIT"
    WITHDRAWAL = "WITHDRAWAL"
    FEE = "FEE"
    TAX = "TAX"
    OPENING_CASH_BALANCE = "OPENING_CASH_BALANCE"
    BONUS = "BONUS"
    SPLIT = "SPLIT"
    UNKNOWN = "UNKNOWN"
    IGNORE = "IGNORE"


@dataclass(slots=True, frozen=True)
class NormalizedImportTransaction:
    row_number: int
    date: datetime
    symbol: str
    transaction_type: NormalizedTransactionType
    quantity: Decimal
    price_per_unit: Decimal
    total_amount: Decimal
    broker: BrokerType
    source_file: str
    raw_text: str
    normalized_description: str = ""
    confidence_source: str = "heuristic"
    warning: str | None = None
    fees: Decimal = ZERO
    tax: Decimal = ZERO
    net_amount: Decimal = ZERO
    diagnostics: dict[str, Any] | None = None


@dataclass(slots=True, frozen=True)
class ImportParseError:
    row_number: int
    raw_text: str
    error_reason: str


class BaseBrokerParser:
    """Base parser contract for normalizing broker-specific rows."""

    broker: BrokerType

    def parse(
        self,
        *,
        rows: list[dict[str, Any]],
        source_file: str,
    ) -> tuple[list[NormalizedImportTransaction], list[ImportParseError]]:
        normalized_rows: list[NormalizedImportTransaction] = []
        errors: list[ImportParseError] = []
        for row in rows:
            parsed, err = self._parse_single_row(row=row, source_file=source_file)
            if parsed is not None:
                normalized_rows.append(parsed)
            elif err is not None:
                errors.append(err)
        return normalized_rows, errors

    def _parse_single_row(
        self,
        *,
        row: dict[str, Any],
        source_file: str,
    ) -> tuple[NormalizedImportTransaction | None, ImportParseError | None]:
        raise NotImplementedError

    @staticmethod
    def is_missing(value: Any) -> bool:
        if value is None:
            return True
        if type(value).__name__ in {"NAType", "NaTType"}:
            return True
        if isinstance(value, float) and value != value:
            return True
        return False

    @staticmethod
    def pick_first(row: dict[str, Any], keys: list[str]) -> Any:
        for key in keys:
            if key not in row:
                continue
            value = row[key]
            if BaseBrokerParser.is_missing(value) or value == "":
                continue
            return value
        return None

    @staticmethod
    def normalize_text(value: Any) -> str:
        if BaseBrokerParser.is_missing(value):
            return ""
        text = str(value or "").strip()
        text = text.translate(ARABIC_TO_PERSIAN_MAP)
        text = text.translate(PERSIAN_DIGITS_MAP).translate(ARABIC_DIGITS_MAP)
        text = text.replace("\u200c", " ").replace("\u200f", " ").replace("\ufeff", " ")
        text = re.sub(r"\s+", " ", text)
        return text.strip()

    @staticmethod
    def to_decimal(value: Any) -> Decimal:
        text = BaseBrokerParser.normalize_text(value)
        if not text:
            return ZERO
        cleaned = text.replace(",", "").replace("٬", "").replace("،", "")
        cleaned = cleaned.replace("ریال", "").replace("تومان", "").strip()
        if cleaned in {"-", "--"}:
            return ZERO
        try:
            return Decimal(cleaned).quantize(EIGHT_PLACES, rounding=ROUND_HALF_UP)
        except InvalidOperation:
            return ZERO

    @staticmethod
    def normalize_symbol(value: str) -> str:
        cleaned = BaseBrokerParser.normalize_text(value)
        cleaned = cleaned.replace("(", "").replace(")", "")
        cleaned = cleaned.replace("/", "").replace("\\", "")
        cleaned = cleaned.replace(" ", "")
        if not cleaned:
            return ""
        return "".join(ch.upper() if "a" <= ch.lower() <= "z" else ch for ch in cleaned)

    @staticmethod
    def parse_jalali_or_gregorian(value: Any) -> datetime:
        text = BaseBrokerParser.normalize_text(value)
        if not text:
            return datetime.now(UTC)

        if isinstance(value, datetime):
            return value.astimezone(UTC) if value.tzinfo else value.replace(tzinfo=UTC)

        if isinstance(value, (int, float)):
            # Excel serial date fallback
            base = datetime(1899, 12, 30, tzinfo=UTC)
            return base + timedelta(days=float(value))

        match = re.search(
            r"(\d{4})[/-](\d{1,2})[/-](\d{1,2})(?:[ T](\d{1,2}):(\d{1,2})(?::(\d{1,2}))?)?",
            text,
        )
        if not match:
            return datetime.now(UTC)
        year, month, day = (int(match.group(1)), int(match.group(2)), int(match.group(3)))
        hour = int(match.group(4) or 0)
        minute = int(match.group(5) or 0)
        second = int(match.group(6) or 0)

        # Treat years >= 1300 and < 1600 as Jalali.
        if 1300 <= year < 1600:
            try:
                g = jdatetime.date(year, month, day).togregorian()
                return datetime(g.year, g.month, g.day, hour, minute, second, tzinfo=UTC)
            except ValueError:
                return datetime.now(UTC)

        try:
            return datetime(year, month, day, hour, minute, second, tzinfo=UTC)
        except ValueError:
            return datetime.now(UTC)

    @staticmethod
    def infer_transaction_type(*, description: str, raw_type: str) -> NormalizedTransactionType | None:
        probe = f"{description} {raw_type}".lower()
        if any(token in probe for token in BUY_KEYWORDS):
            return NormalizedTransactionType.BUY
        if any(token in probe for token in SELL_KEYWORDS):
            return NormalizedTransactionType.SELL
        if any(token in probe for token in DEPOSIT_KEYWORDS):
            return NormalizedTransactionType.DEPOSIT
        if any(token in probe for token in WITHDRAWAL_KEYWORDS):
            return NormalizedTransactionType.WITHDRAWAL
        if any(token in probe for token in DIVIDEND_KEYWORDS):
            return NormalizedTransactionType.DIVIDEND
        if any(token in probe for token in TAX_KEYWORDS):
            return NormalizedTransactionType.TAX
        if any(token in probe for token in FEE_KEYWORDS):
            return NormalizedTransactionType.FEE
        if any(token in probe for token in OPENING_BALANCE_KEYWORDS):
            return NormalizedTransactionType.OPENING_CASH_BALANCE
        if any(token in probe for token in BONUS_KEYWORDS):
            return NormalizedTransactionType.BONUS
        if any(token in probe for token in SPLIT_KEYWORDS):
            return NormalizedTransactionType.SPLIT
        if any(token in probe for token in IGNORE_KEYWORDS):
            return NormalizedTransactionType.IGNORE
        return None

    @staticmethod
    def extract_symbol_and_quantity(*, description: str) -> tuple[str, Decimal]:
        normalized = BaseBrokerParser.normalize_text(description)
        match = BUY_SELL_QTY_SYMBOL_RE.search(normalized)
        if match:
            quantity = BaseBrokerParser.to_decimal(match.group(1))
            symbol = BaseBrokerParser.normalize_symbol(match.group(2))
            return symbol, quantity

        symbol_match = SYMBOL_INLINE_RE.search(normalized)
        qty_match = QTY_RE.search(normalized)
        symbol = BaseBrokerParser.normalize_symbol(symbol_match.group(1)) if symbol_match else ""
        quantity = BaseBrokerParser.to_decimal(qty_match.group(1)) if qty_match else ZERO
        return symbol, quantity

    @staticmethod
    def extract_price(description: str) -> Decimal:
        normalized = BaseBrokerParser.normalize_text(description)
        match = PRICE_RE.search(normalized)
        if not match:
            return ZERO
        return BaseBrokerParser.to_decimal(match.group(1))
