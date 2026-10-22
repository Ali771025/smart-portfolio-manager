"""Public contracts for cross-portfolio trade reconciliation."""

from __future__ import annotations

import uuid
from datetime import datetime
from decimal import Decimal
from typing import Any, Literal

from pydantic import BaseModel, ConfigDict, Field

from app.models.enums import (
    ReconciliationAuditAction,
    ReconciliationMatchingMethod,
    ReconciliationStatus,
    TransactionType,
)


class ReconciliationAllocationInput(BaseModel):
    buy_transaction_id: uuid.UUID
    quantity: Decimal = Field(gt=0, max_digits=24, decimal_places=8)


class ManualReconciliationCreate(BaseModel):
    sell_transaction_id: uuid.UUID
    allocations: list[ReconciliationAllocationInput] = Field(min_length=1)
    notes: str | None = Field(default=None, max_length=2000)


class ReconciliationTransitionRequest(BaseModel):
    notes: str | None = Field(default=None, max_length=2000)


class ReconciliationProblem(BaseModel):
    type: str = "https://smartportfolio.dev/problems/trade-reconciliation"
    title: str
    status: int
    detail: str
    instance: str
    code: str


class ReconciliationTradeInfo(BaseModel):
    transaction_id: uuid.UUID
    transaction_type: TransactionType
    portfolio_id: uuid.UUID
    portfolio_label: str
    broker_label: str | None = None
    executed_at: datetime
    quantity: Decimal
    price_per_unit: Decimal
    fees: Decimal
    remaining_quantity: Decimal


class ReconciliationAllocationRead(BaseModel):
    allocation_id: uuid.UUID
    buy_transaction: ReconciliationTradeInfo
    matched_quantity: Decimal
    estimated_or_actual_buy_cost: Decimal
    estimated_or_actual_sell_proceeds: Decimal
    estimated_or_actual_realized_pnl: Decimal


class ReconciliationHoldingsImpact(BaseModel):
    portfolio_id: uuid.UUID
    portfolio_label: str
    role: Literal["SOURCE", "DESTINATION"]
    quantity_delta: Decimal
    reconciled_sell_quantity: Decimal = Decimal("0")


class ReconciliationAuditEventRead(BaseModel):
    event_id: uuid.UUID
    action: ReconciliationAuditAction
    actor_user_id: uuid.UUID
    reason: str | None = None
    metadata: dict[str, Any] | None = None
    created_at: datetime


class ReconciliationAuditMetadata(BaseModel):
    created_by_user_id: uuid.UUID
    updated_by_user_id: uuid.UUID
    confirmed_by_user_id: uuid.UUID | None = None
    rejected_by_user_id: uuid.UUID | None = None
    canceled_by_user_id: uuid.UUID | None = None
    created_at: datetime
    updated_at: datetime
    confirmed_at: datetime | None = None
    rejected_at: datetime | None = None
    canceled_at: datetime | None = None
    events: list[ReconciliationAuditEventRead] = Field(default_factory=list)


class TradeReconciliationRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    reconciliation_id: uuid.UUID
    status: ReconciliationStatus
    matching_method: ReconciliationMatchingMethod
    asset_id: uuid.UUID
    symbol: str
    sell_transaction: ReconciliationTradeInfo
    source_allocations: list[ReconciliationAllocationRead]
    matched_quantity: Decimal
    remaining_sell_quantity: Decimal
    confidence_score: Decimal | None = None
    rationale: dict[str, Any] | None = None
    notes: str | None = None
    estimated_or_actual_realized_pnl_impact: Decimal
    estimated_or_actual_holdings_impact: list[ReconciliationHoldingsImpact]
    audit: ReconciliationAuditMetadata


class ReconciliationImpactPreview(BaseModel):
    reconciliation_id: uuid.UUID
    status: ReconciliationStatus
    asset_id: uuid.UUID
    symbol: str
    matched_quantity: Decimal
    remaining_sell_quantity: Decimal
    estimated_realized_pnl_impact: Decimal
    estimated_holdings_impact: list[ReconciliationHoldingsImpact]
    allocations: list[ReconciliationAllocationRead]
    is_confirmable: bool = True

