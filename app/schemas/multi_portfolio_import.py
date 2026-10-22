"""Schemas for multi-portfolio broker-aware import flow (preview -> confirm)."""

from __future__ import annotations

import uuid
from datetime import datetime
from decimal import Decimal
from enum import StrEnum
from typing import Any

from pydantic import BaseModel, ConfigDict, Field


class BrokerType(StrEnum):
    AGAH = "AGAH"
    MOFID = "MOFID"
    BOURSIRAN = "BOURSIRAN"
    UNKNOWN = "UNKNOWN"


class ImportType(StrEnum):
    LEDGER_TRANSACTIONS = "LEDGER_TRANSACTIONS"
    HOLDINGS_SNAPSHOT = "HOLDINGS_SNAPSHOT"


class ImportRowStatus(StrEnum):
    VALID = "VALID"
    INVALID = "INVALID"
    DUPLICATE = "DUPLICATE"


class ImportPreviewSummary(BaseModel):
    total_rows: int = Field(ge=0)
    valid_rows: int = Field(ge=0)
    invalid_rows: int = Field(ge=0)
    duplicate_rows: int = Field(ge=0)
    warnings: list[str] = Field(default_factory=list)


class ImportPreviewRow(BaseModel):
    model_config = ConfigDict(extra="forbid")

    row_no: int = Field(ge=1)
    status: ImportRowStatus
    raw: dict[str, Any]
    normalized: dict[str, Any]
    messages: list[str] = Field(default_factory=list)


class ImportPreviewResponse(BaseModel):
    preview_id: uuid.UUID
    portfolio_id: uuid.UUID
    detected_broker: BrokerType
    detected_import_type: ImportType
    generated_at: datetime
    summary: ImportPreviewSummary
    rows: list[ImportPreviewRow]


class ConfirmImportRequest(BaseModel):
    preview_id: uuid.UUID


class ImportResultResponse(BaseModel):
    job_id: uuid.UUID | None = None
    portfolio_id: uuid.UUID
    broker: BrokerType
    import_type: ImportType
    status: str
    imported_rows: int = Field(ge=0)
    duplicate_rows: int = Field(ge=0)
    invalid_rows: int = Field(ge=0)
    errors: list[str] = Field(default_factory=list)


class PortfolioManagerAssignmentRequest(BaseModel):
    manager: BrokerType = Field(
        description="Use AGAH/MOFID/BOURSIRAN for broker portfolios, UNKNOWN for manual/custom.",
    )


class PortfolioPerformanceRead(BaseModel):
    portfolio_id: uuid.UUID
    portfolio_name: str
    manager: BrokerType
    total_invested: Decimal
    total_current_value: Decimal
    total_pnl: Decimal
    roi_percent: Decimal


class AggregatePerformanceRead(BaseModel):
    portfolio_count: int = Field(ge=0)
    total_invested: Decimal
    total_current_value: Decimal
    total_pnl: Decimal
    roi_percent: Decimal


class ManagerComparisonRow(BaseModel):
    manager: BrokerType
    portfolios: int = Field(ge=0)
    total_invested: Decimal
    total_current_value: Decimal
    total_pnl: Decimal
    roi_percent: Decimal


class ManualQuickTransactionRequest(BaseModel):
    portfolio_id: uuid.UUID
    symbol: str = Field(min_length=1, max_length=32)
    transaction_type: str = Field(
        description="BUY or SELL",
        pattern="^(BUY|SELL)$",
    )
    quantity: Decimal = Field(gt=Decimal("0"))
    price: Decimal = Field(gt=Decimal("0"))
    notes: str | None = Field(default=None, max_length=1000)
