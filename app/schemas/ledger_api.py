"""API contracts for asset ledger, valuation series, positions, and TWR."""

from __future__ import annotations

import uuid
from datetime import date, datetime
from decimal import Decimal

from pydantic import BaseModel, ConfigDict, Field

from app.models.enums import TransactionType


class DecimalStringModel(BaseModel):
    model_config = ConfigDict(
        extra="forbid",
        json_encoders={Decimal: lambda value: format(value, "f")},
    )


class ProblemDetails(DecimalStringModel):
    type: str = "about:blank"
    title: str
    status: int
    detail: str
    instance: str
    errors: list[dict[str, str]] | None = None


class LedgerEntryRead(DecimalStringModel):
    id: uuid.UUID
    portfolio_id: uuid.UUID
    asset_id: uuid.UUID
    asset_symbol: str = ""
    asset_name: str | None = None
    asset_type: str | None = None
    transaction_type: TransactionType
    quantity: Decimal
    price_per_unit: Decimal
    commission: Decimal = Decimal("0")
    fees: Decimal
    tax: Decimal = Decimal("0")
    total_amount: Decimal
    net_amount: Decimal = Decimal("0")
    cash_flow: Decimal = Decimal("0")
    realized_pnl: Decimal
    wac_at_execution: Decimal
    currency: str = "USD"
    executed_at: datetime
    notes: str | None = None


class AssetLedgerResponse(DecimalStringModel):
    items: list[LedgerEntryRead]
    total: int
    limit: int
    offset: int


class AssetPositionResponse(DecimalStringModel):
    portfolio_id: uuid.UUID
    asset_id: uuid.UUID
    symbol: str = ""
    name: str | None = None
    asset_type: str | None = None
    quantity: Decimal
    weighted_avg_cost: Decimal
    total_cost_basis: Decimal
    manual_break_even_price: Decimal | None = None
    computed_break_even_price: Decimal
    break_even_price: Decimal
    latest_price: Decimal | None = None
    market_value: Decimal | None = None
    unrealized_pnl: Decimal | None = None
    unrealized_pnl_percent: Decimal | None = None
    realized_pnl: Decimal
    total_pnl: Decimal | None = None
    roi: Decimal | None = None
    currency: str = "USD"
    last_price_timestamp: datetime | None = None
    has_market_price: bool = False
    price_source: str = "missing"
    price_date: datetime | None = None
    data_status: str = "missing_market_price"
    warnings: list[str] = Field(default_factory=list)


class AssetValuationPoint(DecimalStringModel):
    timestamp: datetime
    date: date
    quantity: Decimal
    weighted_avg_cost: Decimal
    total_cost_basis: Decimal
    price: Decimal | None = None
    market_value: Decimal | None = None
    unrealized_pnl: Decimal | None = None
    realized_pnl: Decimal
    benchmark_value: Decimal | None = None
    has_market_price: bool = False
    price_source: str = "missing"
    price_date: date | None = None
    data_status: str = "missing_market_price"
    warnings: list[str] = Field(default_factory=list)


class AssetValuationSeriesResponse(DecimalStringModel):
    portfolio_id: uuid.UUID
    asset_id: uuid.UUID
    adjusted_prices: bool = True
    points: list[AssetValuationPoint]


class PortfolioPositionItem(DecimalStringModel):
    asset_id: uuid.UUID
    ticker_symbol: str
    symbol: str
    name: str | None = None
    asset_type: str | None = None
    quantity: Decimal
    weighted_avg_cost: Decimal
    total_cost_basis: Decimal
    manual_break_even_price: Decimal | None = None
    computed_break_even_price: Decimal
    break_even_price: Decimal
    latest_price: Decimal | None = None
    market_value: Decimal | None = None
    unrealized_pnl: Decimal | None = None
    unrealized_pnl_percent: Decimal | None = None
    realized_pnl: Decimal
    total_pnl: Decimal | None = None
    roi: Decimal | None = None
    currency: str = "USD"
    last_price_timestamp: datetime | None = None
    has_market_price: bool = False
    price_source: str = "missing"
    price_date: datetime | None = None
    data_status: str = "missing_market_price"
    warnings: list[str] = Field(default_factory=list)


class PortfolioPositionsResponse(DecimalStringModel):
    portfolio_id: uuid.UUID
    total_market_value: Decimal | None = None
    total_cost_basis: Decimal
    total_pnl: Decimal | None = None
    total_roi: Decimal | None = None
    asset_count: int
    total_unrealized_pnl: Decimal | None = None
    total_realized_pnl: Decimal
    missing_market_price_count: int = 0
    data_status: str = "ok"
    warnings: list[str] = Field(default_factory=list)
    items: list[PortfolioPositionItem]


class TWRPoint(DecimalStringModel):
    date: date
    portfolio_value: Decimal
    net_cash_flow: Decimal
    period_return: Decimal
    cumulative_twr: Decimal


class PortfolioTWRResponse(DecimalStringModel):
    portfolio_id: uuid.UUID
    start_date: date
    end_date: date
    points: list[TWRPoint]


class BreakEvenPriceUpdate(DecimalStringModel):
    manual_break_even_price: Decimal | None = Field(
        default=None,
        gt=Decimal("0"),
        description=(
            "User-entered break-even sell price. Null clears the manual value; "
            "the computed weighted-average cost remains available."
        ),
    )


class DateRangeQuery(DecimalStringModel):
    start_date: date
    end_date: date
    adjusted_prices: bool = True


class PaginationQuery(DecimalStringModel):
    limit: int = Field(default=50, ge=1, le=500)
    offset: int = Field(default=0, ge=0)
