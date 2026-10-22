"""Domain models and parser contracts for broker-aware multi-portfolio import."""

from __future__ import annotations

import uuid
from dataclasses import dataclass, field
from datetime import datetime
from decimal import Decimal
from enum import StrEnum
from typing import Any, Protocol

from app.schemas.multi_portfolio_import import BrokerType, ImportRowStatus, ImportType


class RowSemanticType(StrEnum):
    TRADE_ROW = "TRADE_ROW"
    HOLDING_SNAPSHOT_ROW = "HOLDING_SNAPSHOT_ROW"


@dataclass(slots=True, frozen=True)
class ParseContext:
    portfolio_id: uuid.UUID
    source_filename: str
    now_utc: datetime


@dataclass(slots=True, frozen=True)
class ParsedRow:
    row_no: int
    raw: dict[str, Any]
    normalized: dict[str, Any]
    semantic_type: RowSemanticType
    status: ImportRowStatus
    messages: list[str] = field(default_factory=list)
    duplicate_fingerprint: str | None = None


@dataclass(slots=True, frozen=True)
class ParseOutput:
    broker: BrokerType
    import_type: ImportType
    rows: list[ParsedRow]
    warnings: list[str] = field(default_factory=list)


class BrokerParser(Protocol):
    broker: BrokerType
    import_type: ImportType
    required_headers: set[str]

    def can_handle(self, headers: list[str]) -> bool:
        """Return True when headers are compatible with this broker parser."""

    def parse(self, rows: list[dict[str, Any]], ctx: ParseContext) -> ParseOutput:
        """Parse raw rows into normalized domain rows."""


@dataclass(slots=True, frozen=True)
class NormalizedLedgerRow:
    trade_at: datetime
    symbol: str | None
    description: str
    debit: Decimal
    credit: Decimal
    running_balance: Decimal | None


@dataclass(slots=True, frozen=True)
class NormalizedSnapshotRow:
    snapshot_at: datetime
    symbol: str
    quantity: Decimal
    market_value_today: Decimal
    cost_basis: Decimal
    weight_pct: Decimal | None
