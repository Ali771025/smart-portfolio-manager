"""Normalized DTOs shared across all broker import strategies."""

from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime
from decimal import Decimal
from enum import StrEnum


class ImportType(StrEnum):
    """Legacy file-type contract exposed by parse API responses."""

    TRADE_LEDGER = "TRADE_LEDGER"
    PORTFOLIO_SNAPSHOT = "PORTFOLIO_SNAPSHOT"


class ImportMode(StrEnum):
    """Strategy output mode before API-specific mapping."""

    TRADES = "TRADES"
    SNAPSHOT = "SNAPSHOT"


class TradeAction(StrEnum):
    BUY = "BUY"
    SELL = "SELL"


@dataclass(frozen=True, slots=True)
class ParsedTradeRow:
    row_number: int
    symbol_raw: str
    symbol_normalized: str
    side: TradeAction
    trade_date: datetime
    quantity: Decimal
    unit_price: Decimal
    gross_amount: Decimal
    raw_description: str
    source_broker: str


@dataclass(frozen=True, slots=True)
class ParsedHoldingRow:
    row_number: int
    symbol_raw: str
    symbol_normalized: str
    quantity: Decimal
    average_cost: Decimal
    cost_basis: Decimal
    market_price: Decimal | None
    market_value: Decimal | None
    unrealized_pnl: Decimal | None
    weight_percent: Decimal | None
    source_broker: str


@dataclass(frozen=True, slots=True)
class ImportParseResult:
    format_name: str
    import_mode: ImportMode
    parsed_trades: list[ParsedTradeRow] = field(default_factory=list)
    parsed_holdings: list[ParsedHoldingRow] = field(default_factory=list)
    skipped_rows: int = 0
    warnings: list[str] = field(default_factory=list)

