"""Excel parsing and Persian normalization utilities for broker trade imports."""

from __future__ import annotations

import io
import logging
import math
import re
from zipfile import BadZipFile
from dataclasses import dataclass
from datetime import UTC, datetime
from decimal import Decimal, InvalidOperation, ROUND_HALF_UP
from enum import Enum
from typing import Any
from zoneinfo import ZoneInfo

import jdatetime
import pandas as pd
from openpyxl.utils.exceptions import InvalidFileException

from app.models.enums import TransactionType

EIGHT_PLACES = Decimal("0.00000001")
ZERO = Decimal("0.00000000")
TEHRAN_TZ = ZoneInfo("Asia/Tehran")
MAX_EXCEL_ROWS = 50_000
logger = logging.getLogger(__name__)


class ImportFileKind(str, Enum):
    TRADE_LEDGER = "TRADE_LEDGER"
    PORTFOLIO_SNAPSHOT = "PORTFOLIO_SNAPSHOT"


class BrokerFormat(str, Enum):
    # Backward-compatible aliases expected by older tests/callers.
    MOFID = "MOFID_LEDGER"
    AGAH = "AGAH_LEDGER"
    MOFID_LEDGER = "MOFID_LEDGER"
    AGAH_LEDGER = "AGAH_LEDGER"
    MOFID_PORTFOLIO = "MOFID_PORTFOLIO"
    BOURSIRAN_PORTFOLIO = "BOURSIRAN_PORTFOLIO"


MOFID_LEDGER_HEADERS = {"تاریخ", "شرح", "نماد دارایی", "بدهکار", "بستانکار"}
AGAH_LEDGER_HEADERS = {"زمان", "شرح", "بدهکار(ریال)", "بستانکار(ریال)"}
MOFID_PORTFOLIO_HEADERS = {"نماد دارایی", "مانده", "بهای تمام شده"}
BOURSIRAN_PORTFOLIO_HEADERS = {"نماد", "تعداد", "بهای تمام شده خرید"}

ARABIC_TO_PERSIAN_MAP = str.maketrans(
    {
        "ي": "ی",
        "ى": "ی",
        "ك": "ک",
        "ة": "ه",
        "ؤ": "و",
        "أ": "ا",
        "إ": "ا",
        "ئ": "ی",
        "٠": "0",
        "١": "1",
        "٢": "2",
        "٣": "3",
        "٤": "4",
        "٥": "5",
        "٦": "6",
        "٧": "7",
        "٨": "8",
        "٩": "9",
        "۰": "0",
        "۱": "1",
        "۲": "2",
        "۳": "3",
        "۴": "4",
        "۵": "5",
        "۶": "6",
        "۷": "7",
        "۸": "8",
        "۹": "9",
        "٬": ",",
        "،": ",",
        "٫": ".",
    }
)

ZWNJ_AND_MARKS_RE = re.compile(r"[\u200c\u200d\u200e\u200f\ufeff\u202a-\u202e]")
MULTISPACE_RE = re.compile(r"\s+")

QTY_RE = re.compile(
    r"(?:"
    r"(?:تعداد|تتداد|حجم)\s*[:\-]?\s*(?P<qty_a>[0-9,\.]+)"
    r"|"
    r"(?:خرید|فروش)\s*(?P<qty_b>[0-9,\.]+)\s*س(?:ه|ح)م"
    r")"
)
SYMBOL_RE = re.compile(
    r"(?:"
    r"(?:نماد(?:\s*دارایی)?)\s*[:\-]?\s*(?P<sym_a>[A-Za-z0-9\u0600-\u06FF]+)"
    r"|"
    r"س(?:ه|ح)م\s+(?P<sym_b>[A-Za-z0-9\u0600-\u06FF]+)"
    r")"
)
PRICE_RE = re.compile(r"(?:قیمت(?:\s*هر\s*سهم)?|بهای\s*واحد)\s*[:\-]?\s*(?P<price>[0-9,\.]+)")

AGAH_QTY_SYMBOL_PRICE_RE = re.compile(
    r"(?:تعداد|حجم)\s*(?P<quantity>[0-9۰-۹,\.]+)\s*(?:سهم)?\s*(?P<symbol>[A-Za-z0-9\u0600-\u06FF\s\u200c]+?)"
    r"\s*(?:با\s*)?قیمت\s*(?:میانگین|متوسط|هر\s*سهم)?\s*(?P<price>[0-9۰-۹,\.]+)",
    re.IGNORECASE,
)
AGAH_SYMBOL_FALLBACK_RE = re.compile(r"سهم\s+(?P<symbol>[A-Za-z0-9\u0600-\u06FF\s\u200c]+)")


@dataclass(frozen=True, slots=True)
class ParsedBrokerTransaction:
    row_number: int
    broker_format: BrokerFormat
    executed_at: datetime
    symbol: str
    description: str
    transaction_type: TransactionType
    quantity: Decimal
    unit_price: Decimal
    fees: Decimal
    total_amount: Decimal
    debit: Decimal
    credit: Decimal


@dataclass(frozen=True, slots=True)
class ParsedPortfolioPosition:
    row_number: int
    broker_format: BrokerFormat
    symbol: str
    quantity: Decimal
    total_cost_basis: Decimal
    unit_cost: Decimal
    description: str


@dataclass(frozen=True, slots=True)
class ParseWorkbookResult:
    broker_format: BrokerFormat
    file_kind: ImportFileKind
    total_rows: int
    parsed_rows: list[ParsedBrokerTransaction]
    parsed_positions: list[ParsedPortfolioPosition]
    errors: list[dict[str, Any]]


class ExcelFormatDetectionError(ValueError):
    pass


def q8(value: Decimal) -> Decimal:
    return value.quantize(EIGHT_PLACES, rounding=ROUND_HALF_UP)


def normalize_persian_text(value: str) -> str:
    """Normalize Arabic variants, Persian digits, ZWNJ and punctuation into ASCII-friendly text."""

    normalized = value.translate(ARABIC_TO_PERSIAN_MAP)
    normalized = ZWNJ_AND_MARKS_RE.sub(" ", normalized)
    normalized = MULTISPACE_RE.sub(" ", normalized)
    return normalized.strip()


def normalize_symbol(value: str) -> str:
    cleaned = normalize_persian_text(value)
    cleaned = cleaned.replace(" ", "")
    latin = "".join(char.upper() if "a" <= char <= "z" or "A" <= char <= "Z" else char for char in cleaned)
    latin = re.sub(r"(?<=[A-Za-z\u0600-\u06FF])[0-9]+$", "", latin)
    return latin


def _normalize_header(value: Any) -> str:
    normalized = normalize_persian_text(str(value)).lower()
    normalized = normalized.replace("(", "").replace(")", "")
    normalized = normalized.replace("_", " ")
    return MULTISPACE_RE.sub("", normalized)


def _signature(headers: set[str]) -> set[str]:
    return {_normalize_header(header) for header in headers if str(header).strip()}


def detect_broker_format(headers: Any) -> BrokerFormat:
    normalized_headers = {normalize_persian_text(str(item)) for item in headers}
    header_signature = _signature(normalized_headers)

    logger.info(
        "Attempting broker format detection",
        extra={
            "normalized_headers": sorted(normalized_headers),
            "header_signature": sorted(header_signature),
            "header_count": len(header_signature),
        },
    )

    checks: list[tuple[BrokerFormat, set[str]]] = [
        (BrokerFormat.MOFID_PORTFOLIO, _signature(MOFID_PORTFOLIO_HEADERS)),
        (BrokerFormat.BOURSIRAN_PORTFOLIO, _signature(BOURSIRAN_PORTFOLIO_HEADERS)),
        (BrokerFormat.AGAH_LEDGER, _signature(AGAH_LEDGER_HEADERS)),
        (BrokerFormat.MOFID_LEDGER, _signature(MOFID_LEDGER_HEADERS)),
    ]

    for broker_format, expected_signature in checks:
        if expected_signature.issubset(header_signature):
            return broker_format

    missing = {
        broker_format.value: sorted(expected_signature - header_signature)
        for broker_format, expected_signature in checks
    }
    raise ExcelFormatDetectionError(
        "Unsupported broker format. Missing headers by format: "
        + "; ".join(f"{name}={parts}" for name, parts in missing.items())
    )


def infer_file_kind(broker_format: BrokerFormat) -> ImportFileKind:
    if broker_format in {BrokerFormat.MOFID_PORTFOLIO, BrokerFormat.BOURSIRAN_PORTFOLIO}:
        return ImportFileKind.PORTFOLIO_SNAPSHOT
    return ImportFileKind.TRADE_LEDGER


def parse_excel_transactions(file_bytes: bytes, *, instance_base: str) -> ParseWorkbookResult:
    raw_df = _read_candidate_sheet(file_bytes=file_bytes)
    if raw_df.empty:
        raise ExcelFormatDetectionError("Excel file is empty and contains no import rows.")
    if len(raw_df.index) > MAX_EXCEL_ROWS:
        raise ExcelFormatDetectionError(
            f"Excel file contains {len(raw_df.index)} rows, exceeding the {MAX_EXCEL_ROWS:,} row limit."
        )

    df = raw_df.copy()
    df.columns = [normalize_persian_text(str(col)) for col in df.columns]
    broker_format = detect_broker_format(df.columns)
    file_kind = infer_file_kind(broker_format)

    errors: list[dict[str, Any]] = []
    if file_kind == ImportFileKind.TRADE_LEDGER:
        standardized = _standardize_trade_dataframe(df, broker_format)
        parsed_rows: list[ParsedBrokerTransaction] = []
        for row in standardized.to_dict(orient="records"):
            problem = _parse_standardized_trade_row(
                row,
                broker_format=broker_format,
                instance_base=instance_base,
            )
            if problem is None:
                continue
            if isinstance(problem, dict):
                errors.append(problem)
            else:
                parsed_rows.append(problem)

        return ParseWorkbookResult(
            broker_format=broker_format,
            file_kind=file_kind,
            total_rows=len(standardized.index),
            parsed_rows=parsed_rows,
            parsed_positions=[],
            errors=errors,
        )

    standardized_positions = _standardize_snapshot_dataframe(df, broker_format)
    parsed_positions: list[ParsedPortfolioPosition] = []
    for row in standardized_positions.to_dict(orient="records"):
        parsed = _parse_snapshot_row(row, broker_format=broker_format, instance_base=instance_base)
        if isinstance(parsed, dict):
            errors.append(parsed)
        else:
            parsed_positions.append(parsed)

    return ParseWorkbookResult(
        broker_format=broker_format,
        file_kind=file_kind,
        total_rows=len(standardized_positions.index),
        parsed_rows=[],
        parsed_positions=parsed_positions,
        errors=errors,
    )


def _read_candidate_sheet(*, file_bytes: bytes) -> pd.DataFrame:
    try:
        workbook = pd.ExcelFile(io.BytesIO(file_bytes))
        logger.info("Workbook loaded for broker detection", extra={"file_size_bytes": len(file_bytes)})
    except (InvalidFileException, BadZipFile) as ex:
        logger.warning(
            "Invalid or corrupt Excel workbook",
            extra={
                "file_size_bytes": len(file_bytes),
                "exception_type": type(ex).__name__,
                "exception_message": str(ex),
            },
        )
        raise ExcelFormatDetectionError("File is corrupt or not a valid Excel workbook.") from ex
    except Exception as ex:  # noqa: BLE001
        logger.exception(
            "Unexpected workbook load failure",
            extra={
                "file_size_bytes": len(file_bytes),
                "exception_type": type(ex).__name__,
            },
        )
        raise ExcelFormatDetectionError("File is corrupt or not a valid Excel workbook.") from ex

    if not workbook.sheet_names:
        raise ExcelFormatDetectionError("Excel workbook has no worksheets.")

    selected_sheet: str | None = None
    detection_failures: list[str] = []
    for sheet_name in workbook.sheet_names:
        try:
            header_frame = workbook.parse(sheet_name=sheet_name, nrows=0, dtype=str)
        except Exception as ex:  # noqa: BLE001
            detection_failures.append(f"{sheet_name}: failed to read headers ({type(ex).__name__}: {ex})")
            continue
        normalized_headers = [normalize_persian_text(str(col)) for col in header_frame.columns]
        try:
            detect_broker_format(normalized_headers)
        except ExcelFormatDetectionError as ex:
            detection_failures.append(f"{sheet_name}: {ex}")
            continue
        selected_sheet = sheet_name
        break

    if selected_sheet is None:
        failures_preview = "; ".join(detection_failures[:3])
        if len(detection_failures) > 3:
            failures_preview = f"{failures_preview}; ... (+{len(detection_failures) - 3} more)"
        detail = "Unsupported broker format."
        if failures_preview:
            detail = f"{detail} Detection details: {failures_preview}"
        raise ExcelFormatDetectionError(detail)

    try:
        return workbook.parse(sheet_name=selected_sheet, dtype=str)
    except Exception as ex:  # noqa: BLE001
        raise ExcelFormatDetectionError(
            f"Failed to read worksheet '{selected_sheet}'. Ensure the workbook is not corrupted."
        ) from ex


def parse_jalali_datetime_to_utc(value: str) -> datetime:
    """Convert Jalali date/time strings to timezone-aware UTC datetime."""

    normalized = normalize_persian_text(value).replace("-", "/")
    normalized = normalized.replace("T", " ")

    date_time_match = re.search(
        r"(?P<year>\d{4})/(?P<month>\d{1,2})/(?P<day>\d{1,2})"
        r"(?:\s+(?P<hour>\d{1,2})(?::(?P<minute>\d{1,2}))?(?::(?P<second>\d{1,2}))?)?",
        normalized,
    )
    if not date_time_match:
        raise ValueError(f"Cannot parse Jalali datetime from '{value}'.")

    parts = date_time_match.groupdict()
    year = int(parts["year"])
    month = int(parts["month"])
    day = int(parts["day"])
    hour = int(parts["hour"] or 0)
    minute = int(parts["minute"] or 0)
    second = int(parts["second"] or 0)

    jalali_dt = jdatetime.datetime(year, month, day, hour, minute, second)
    gregorian_dt = jalali_dt.togregorian().replace(tzinfo=TEHRAN_TZ)
    return gregorian_dt.astimezone(UTC)


def parse_decimal(value: Any, *, default: Decimal | None = None) -> Decimal | None:
    if value is None:
        return default

    normalized = normalize_persian_text(str(value))
    if not normalized:
        return default

    negative = False
    if normalized.startswith("(") and normalized.endswith(")"):
        negative = True
        normalized = normalized[1:-1]

    normalized = normalized.replace(",", "").replace(" ", "")
    if normalized in {"", "-", "--", "—"}:
        return default

    try:
        parsed = Decimal(normalized)
    except InvalidOperation:
        return default

    if negative:
        parsed *= Decimal("-1")

    return q8(parsed)


def _standardize_trade_dataframe(df: pd.DataFrame, broker_format: BrokerFormat) -> pd.DataFrame:
    if broker_format == BrokerFormat.MOFID_LEDGER:
        work = pd.DataFrame(
            {
                "row_number": df.index + 2,
                "date_time": df["تاریخ"].map(lambda x: normalize_persian_text(str(x)) if pd.notna(x) else ""),
                "description": df["شرح"].map(lambda x: normalize_persian_text(str(x)) if pd.notna(x) else ""),
                "symbol_col": df["نماد دارایی"].map(lambda x: normalize_persian_text(str(x)) if pd.notna(x) else ""),
                "debit_raw": df["بدهکار"],
                "credit_raw": df["بستانکار"],
            }
        )
    elif broker_format == BrokerFormat.AGAH_LEDGER:
        work = pd.DataFrame(
            {
                "row_number": df.index + 2,
                "date_time": df["زمان"].map(lambda x: normalize_persian_text(str(x)) if pd.notna(x) else ""),
                "description": df["شرح"].map(lambda x: normalize_persian_text(str(x)) if pd.notna(x) else ""),
                "symbol_col": "",
                "debit_raw": df["بدهکار(ریال)"],
                "credit_raw": df["بستانکار(ریال)"],
            }
        )
    else:
        raise ExcelFormatDetectionError("Trade standardization requested for non-ledger format.")

    work["debit"] = work["debit_raw"].map(lambda x: parse_decimal(x, default=ZERO) or ZERO)
    work["credit"] = work["credit_raw"].map(lambda x: parse_decimal(x, default=ZERO) or ZERO)
    work["clean_description"] = work["description"].map(lambda x: MULTISPACE_RE.sub(" ", x).strip())

    qty_extract = work["clean_description"].str.extract(QTY_RE, expand=True)
    work["qty_from_desc"] = qty_extract.apply(
        lambda extracted: next((value for value in extracted if pd.notna(value)), None),
        axis=1,
    )

    symbol_extract = work["clean_description"].str.extract(SYMBOL_RE, expand=True)
    work["symbol_from_desc"] = symbol_extract.apply(
        lambda extracted: next((value for value in extracted if pd.notna(value)), None),
        axis=1,
    )

    price_extract = work["clean_description"].str.extract(PRICE_RE, expand=True)
    work["price_from_desc"] = price_extract

    if broker_format == BrokerFormat.AGAH_LEDGER:
        agah_extract = work["clean_description"].map(_extract_agah_trade_parts)
        work["agah_qty"] = agah_extract.map(lambda x: x["quantity"])
        work["agah_symbol"] = agah_extract.map(lambda x: x["symbol"])
        work["agah_price"] = agah_extract.map(lambda x: x["price"])

    return work


def _standardize_snapshot_dataframe(df: pd.DataFrame, broker_format: BrokerFormat) -> pd.DataFrame:
    if broker_format == BrokerFormat.MOFID_PORTFOLIO:
        return pd.DataFrame(
            {
                "row_number": df.index + 2,
                "symbol_col": df["نماد دارایی"].map(lambda x: normalize_persian_text(str(x)) if pd.notna(x) else ""),
                "quantity_raw": df["مانده"],
                "cost_basis_raw": df["بهای تمام شده"],
                "description": "",
            }
        )

    if broker_format == BrokerFormat.BOURSIRAN_PORTFOLIO:
        return pd.DataFrame(
            {
                "row_number": df.index + 2,
                "symbol_col": df["نماد"].map(lambda x: normalize_persian_text(str(x)) if pd.notna(x) else ""),
                "quantity_raw": df["تعداد"],
                "cost_basis_raw": df["بهای تمام شده خرید"],
                "description": "",
            }
        )

    raise ExcelFormatDetectionError("Snapshot standardization requested for non-portfolio format.")


def _extract_agah_trade_parts(description: str) -> dict[str, str | None]:
    text = normalize_persian_text(description)
    match = AGAH_QTY_SYMBOL_PRICE_RE.search(text)
    if match:
        symbol = normalize_symbol(match.group("symbol"))
        return {
            "quantity": match.group("quantity"),
            "symbol": symbol,
            "price": match.group("price"),
        }

    fallback_symbol = None
    fallback_match = AGAH_SYMBOL_FALLBACK_RE.search(text)
    if fallback_match:
        fallback_symbol = normalize_symbol(fallback_match.group("symbol"))

    return {
        "quantity": None,
        "symbol": fallback_symbol,
        "price": None,
    }


def _parse_standardized_trade_row(
    row: dict[str, Any],
    *,
    broker_format: BrokerFormat,
    instance_base: str,
) -> ParsedBrokerTransaction | dict[str, Any] | None:
    row_number = int(row["row_number"])

    executed_at_raw = str(row.get("date_time", "") or "").strip()
    description = str(row.get("clean_description", "") or "").strip()

    debit = parse_decimal(row.get("debit"), default=ZERO) or ZERO
    credit = parse_decimal(row.get("credit"), default=ZERO) or ZERO

    if debit > ZERO and credit == ZERO:
        tx_type = TransactionType.BUY
        total_amount = debit
    elif credit > ZERO and debit == ZERO:
        tx_type = TransactionType.SELL
        total_amount = credit
    elif debit == ZERO and credit == ZERO:
        # Non-trade rows (headers/subtotals/cash movements) are ignored.
        return None
    elif debit > ZERO and credit > ZERO:
        inferred = _infer_tx_type_from_description(description)
        if inferred is None:
            return _problem(
                row_number=row_number,
                title="Invalid Debit/Credit Mapping",
                detail="Both debit and credit are positive and trade side could not be inferred.",
                instance_base=instance_base,
                row_payload=row,
            )
        tx_type = inferred
        total_amount = debit if tx_type == TransactionType.BUY else credit
    else:
        return _problem(
            row_number=row_number,
            title="Invalid Debit/Credit Mapping",
            detail="Exactly one of debit or credit must be positive to infer BUY/SELL.",
            instance_base=instance_base,
            row_payload=row,
        )

    if broker_format == BrokerFormat.AGAH_LEDGER:
        symbol_candidate = str(row.get("agah_symbol") or "").strip() or str(row.get("symbol_from_desc") or "").strip()
        qty_raw = row.get("agah_qty") or row.get("qty_from_desc")
        price_raw = row.get("agah_price") or row.get("price_from_desc")
    else:
        symbol_candidate = str(row.get("symbol_col") or "").strip() or str(row.get("symbol_from_desc") or "").strip()
        qty_raw = row.get("qty_from_desc")
        price_raw = row.get("price_from_desc")

    symbol = normalize_symbol(symbol_candidate)
    if not symbol:
        return _problem(
            row_number=row_number,
            title="Symbol Extraction Failed",
            detail="Could not parse ticker symbol from broker row.",
            instance_base=instance_base,
            row_payload=row,
        )

    quantity = parse_decimal(qty_raw, default=None)
    try:
        if quantity is None or quantity <= ZERO:
            return _problem(
                row_number=row_number,
                title="Quantity Extraction Failed",
                detail="Could not parse a positive share quantity from شرح.",
                instance_base=instance_base,
                row_payload=row,
                problem_type="parse_failure",
            )
    except (InvalidOperation, TypeError, ValueError):
        return _problem(
            row_number=row_number,
            title="Quantity Extraction Failed",
            detail=f"Invalid quantity value: {qty_raw}",
            instance_base=instance_base,
            row_payload=row,
            problem_type="parse_failure",
        )

    try:
        executed_at = parse_jalali_datetime_to_utc(executed_at_raw)
    except Exception as ex:  # noqa: BLE001
        logger.warning(
            "Jalali date conversion failed for import row",
            extra={
                "row_number": row_number,
                "date_value": executed_at_raw,
                "broker_format": broker_format.value,
                "exception_type": type(ex).__name__,
                "exception_message": str(ex),
            },
        )
        return _problem(
            row_number=row_number,
            title="Date Conversion Failed",
            detail="Could not convert Jalali date/time to UTC Gregorian datetime.",
            instance_base=instance_base,
            row_payload=row,
        )

    if total_amount <= ZERO:
        return _problem(
            row_number=row_number,
            title="Invalid Amount",
            detail="Debit/Credit amount must be positive.",
            instance_base=instance_base,
            row_payload=row,
        )

    explicit_price = parse_decimal(price_raw, default=None)
    if explicit_price is None or explicit_price <= ZERO:
        unit_price = q8(total_amount / quantity)
        fees = ZERO
    else:
        unit_price = explicit_price
        gross = q8(quantity * unit_price)
        if tx_type == TransactionType.BUY:
            implied_fees = q8(total_amount - gross)
        else:
            implied_fees = q8(gross - total_amount)

        if implied_fees < ZERO:
            unit_price = q8(total_amount / quantity)
            fees = ZERO
        else:
            fees = implied_fees

    return ParsedBrokerTransaction(
        row_number=row_number,
        broker_format=broker_format,
        executed_at=executed_at,
        symbol=symbol,
        description=description,
        transaction_type=tx_type,
        quantity=quantity,
        unit_price=unit_price,
        fees=fees,
        total_amount=total_amount,
        debit=debit,
        credit=credit,
    )


def _parse_snapshot_row(
    row: dict[str, Any],
    *,
    broker_format: BrokerFormat,
    instance_base: str,
) -> ParsedPortfolioPosition | dict[str, Any]:
    row_number = int(row["row_number"])
    symbol = normalize_symbol(str(row.get("symbol_col") or ""))
    quantity = parse_decimal(row.get("quantity_raw"), default=None)
    total_cost_basis = parse_decimal(row.get("cost_basis_raw"), default=None)

    if not symbol:
        return _problem(
            row_number=row_number,
            title="Symbol Extraction Failed",
            detail="Could not parse portfolio symbol.",
            instance_base=instance_base,
            row_payload=row,
        )

    if quantity is None or quantity <= ZERO:
        return _problem(
            row_number=row_number,
            title="Quantity Extraction Failed",
            detail="Could not parse a positive quantity from portfolio snapshot.",
            instance_base=instance_base,
            row_payload=row,
        )

    if total_cost_basis is None or total_cost_basis < ZERO:
        return _problem(
            row_number=row_number,
            title="Cost Basis Extraction Failed",
            detail="Could not parse total cost basis from portfolio snapshot.",
            instance_base=instance_base,
            row_payload=row,
        )

    unit_cost = ZERO
    if quantity > ZERO:
        unit_cost = q8(total_cost_basis / quantity)

    return ParsedPortfolioPosition(
        row_number=row_number,
        broker_format=broker_format,
        symbol=symbol,
        quantity=quantity,
        total_cost_basis=q8(total_cost_basis),
        unit_cost=unit_cost,
        description=str(row.get("description") or "").strip(),
    )


def _problem(
    *,
    row_number: int,
    title: str,
    detail: str,
    instance_base: str,
    row_payload: dict[str, Any],
    problem_type: str = "parse_failure",
) -> dict[str, Any]:
    cleaned_payload = _sanitize_json_value(row_payload)
    return {
        "type": problem_type,
        "problem_type": problem_type,
        "title": title,
        "status": 422,
        "detail": detail,
        "instance": f"{instance_base}/rows/{row_number}",
        "row_number": row_number,
        "row_payload": cleaned_payload if isinstance(cleaned_payload, dict) else {"value": cleaned_payload},
    }


def _infer_tx_type_from_description(description: str) -> TransactionType | None:
    text = normalize_persian_text(description).lower()
    buy_tokens = ("خرید", "خري", "buy")
    sell_tokens = ("فروش", "sell")
    if any(token in text for token in buy_tokens):
        return TransactionType.BUY
    if any(token in text for token in sell_tokens):
        return TransactionType.SELL
    return None


def _sanitize_json_value(value: Any) -> Any:
    if value is None:
        return None
    if isinstance(value, dict):
        return {str(key): _sanitize_json_value(item) for key, item in value.items()}
    if isinstance(value, (list, tuple, set)):
        return [_sanitize_json_value(item) for item in value]
    if isinstance(value, Decimal):
        return str(value)
    if isinstance(value, float):
        if math.isnan(value) or math.isinf(value):
            return None
        return value
    try:
        if pd.isna(value):
            return None
    except Exception:  # noqa: BLE001
        pass
    if hasattr(value, "item"):
        try:
            return _sanitize_json_value(value.item())
        except Exception:  # noqa: BLE001
            return str(value)
    return value
