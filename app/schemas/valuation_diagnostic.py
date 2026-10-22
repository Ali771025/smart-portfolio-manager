"""Development-only valuation diagnostic response contracts."""

from __future__ import annotations

import uuid
from datetime import date, datetime
from decimal import Decimal

from pydantic import BaseModel, ConfigDict, Field


class DiagnosticModel(BaseModel):
    model_config = ConfigDict(
        extra="forbid",
        json_encoders={Decimal: lambda value: format(value, "f")},
    )


class ValuationDiagnosticMetadata(DiagnosticModel):
    portfolio_id: uuid.UUID
    symbol_input: str
    normalized_symbol: str
    asset_id: uuid.UUID
    asset_symbol: str
    currency: str


class ValuationDiagnosticPosition(DiagnosticModel):
    total_quantity: Decimal
    weighted_avg_cost: Decimal
    total_cost_basis: Decimal
    cumulative_realized_pnl: Decimal
    last_recomputed_at: datetime | None = None


class ValuationDiagnosticMarketPrice(DiagnosticModel):
    daily_price_found: bool
    daily_price_date: date | None = None
    daily_price_close_price: Decimal | None = None
    asset_last_trade_price: Decimal | None = None
    asset_closing_price: Decimal | None = None
    selected_price: Decimal | None = None
    selected_price_source: str
    has_market_price: bool
    warnings: list[str] = Field(default_factory=list)


class ValuationDiagnosticTransaction(DiagnosticModel):
    id: uuid.UUID
    date: datetime
    type: str
    quantity: Decimal
    unit_price: Decimal
    gross_amount: Decimal
    net_amount: Decimal | None = None
    fees: Decimal
    taxes: Decimal
    total_amount: Decimal
    realized_pnl: Decimal
    wac_at_execution: Decimal | None = None
    source: str | None = None
    import_id: uuid.UUID | None = None
    created_at: datetime


class ValuationDiagnosticReplayStep(DiagnosticModel):
    transaction_id: uuid.UUID
    date: datetime
    before_quantity: Decimal
    before_wac: Decimal
    before_cost_basis: Decimal
    action: str
    quantity: Decimal
    price: Decimal
    net_amount: Decimal | None = None
    after_quantity: Decimal
    after_wac: Decimal
    after_cost_basis: Decimal
    realized_pnl_delta: Decimal


class ValuationDiagnosticFinalCalculation(DiagnosticModel):
    remaining_quantity: Decimal
    average_cost: Decimal
    cost_basis: Decimal
    current_price: Decimal | None = None
    market_value: Decimal | None = None
    unrealized_pnl: Decimal | None = None
    realized_pnl: Decimal
    total_pnl: Decimal | None = None
    calculation_status: str


class ValuationDiagnosticAnomalies(DiagnosticModel):
    current_price_equals_wac: bool
    price_source_is_fallback: bool
    missing_market_price: bool
    realized_pnl_without_sell: bool
    suspicious_realized_pnl_abs_gt_cost_basis: bool
    net_amount_missing: bool
    unit_mismatch_suspected: bool


class ValuationDiagnosticResponse(DiagnosticModel):
    metadata: ValuationDiagnosticMetadata
    position: ValuationDiagnosticPosition
    market_price_resolution: ValuationDiagnosticMarketPrice
    transactions: list[ValuationDiagnosticTransaction]
    recomputed_ledger_simulation: list[ValuationDiagnosticReplayStep]
    final_calculation: ValuationDiagnosticFinalCalculation
    anomaly_flags: ValuationDiagnosticAnomalies
