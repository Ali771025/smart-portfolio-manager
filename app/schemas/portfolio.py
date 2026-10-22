"""Portfolio schemas - Phase 2: includes Unrealized PnL and ROI%."""

import uuid
from datetime import datetime
from decimal import Decimal
from typing import Annotated

from pydantic import BaseModel, ConfigDict, Field

from app.models.enums import PortfolioCurrency, PortfolioManagerType, TransactionType

Decimal4 = Annotated[Decimal, Field(max_digits=18, decimal_places=4)]


class PortfolioCreate(BaseModel):
    name: str = Field(min_length=1, max_length=255)
    description: str | None = None
    base_currency: PortfolioCurrency = PortfolioCurrency.IRR
    manager_type: PortfolioManagerType = PortfolioManagerType.UNKNOWN


class PortfolioRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    user_id: uuid.UUID
    name: str
    description: str | None
    base_currency: PortfolioCurrency
    manager_type: PortfolioManagerType
    is_active: bool
    created_at: datetime
    updated_at: datetime


class ProblemDetails(BaseModel):
    """RFC 7807 problem details payload."""

    type: str = "about:blank"
    title: str
    status: int
    detail: str
    instance: str


class PortfolioSummary(BaseModel):
    """Per-portfolio summary used by `GET /api/v1/portfolios`."""

    model_config = ConfigDict(extra="forbid")

    id: uuid.UUID
    name: str
    portfolio_id: uuid.UUID
    portfolio_name: str
    base_currency: PortfolioCurrency
    total_invested_capital: Decimal4
    total_current_value: Decimal4
    current_price: Decimal4 | None = None
    closing_price: Decimal4 | None = None
    daily_pnl: Decimal4 | None = None
    total_unrealized_pnl: Decimal4
    last_market_update: datetime | None = None
    roi_percent: Decimal4
    missing_price_count: int = 0
    stale_price_count: int = 0
    market_status: str = "unknown"
    data_quality_status: str = "unknown"


class AssetPositionSummary(BaseModel):
    """Current position header for one ticker in one portfolio."""

    model_config = ConfigDict(extra="forbid")

    portfolio_id: uuid.UUID
    ticker: str
    current_quantity: Decimal4
    average_buy_price: Decimal4
    current_live_price: Decimal4
    asset_pnl: Decimal4


class TradeHistoryItem(BaseModel):
    """Single trade entry in Jalali-date ledger."""

    model_config = ConfigDict(extra="forbid")

    date_jalali: str = Field(pattern=r"^\d{4}/\d{2}/\d{2}$")
    trade_type: TransactionType
    quantity: Decimal4
    unit_price: Decimal4
    total_trade_value: Decimal4


class TradeHistoryPaginated(BaseModel):
    """Asset header + paginated trade history for one ticker."""

    model_config = ConfigDict(extra="forbid")

    asset_summary: AssetPositionSummary
    transactions: list[TradeHistoryItem] = Field(default_factory=list)
    total: int = Field(ge=0)
    limit: int = Field(ge=1, le=200)
    offset: int = Field(ge=0)


class AssetPositionRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    asset_id: uuid.UUID
    portfolio_id: uuid.UUID
    total_quantity: Decimal
    weighted_avg_cost: Decimal
    total_cost_basis: Decimal
    cumulative_realized_pnl: Decimal
    trade_count: int
    last_updated: datetime


class PositionWithMarketData(AssetPositionRead):
    """
    Single position enriched with live market data for the dashboard.
    Extends the base position with current valuation fields and freshness metadata.
    """

    ticker_symbol: str
    asset_name: str
    current_price: Decimal
    quantity: Decimal | None = Field(default=None, description="Holding quantity")
    average_cost: Decimal | None = Field(default=None, description="Weighted average cost")
    total_cost: Decimal | None = Field(default=None, description="Total open-position cost basis")
    last_price: Decimal | None = Field(
        default=None,
        description="Latest last-trade price from Market Engine",
    )
    closing_price: Decimal | None = Field(
        default=None,
        description="Latest closing price from Market Engine",
    )
    price_change: Decimal | None = Field(
        default=None,
        description="Absolute change versus previous close",
    )
    price_change_percent: Decimal | None = Field(
        default=None,
        description="Percent change versus previous close",
    )
    last_updated_at: datetime | None = Field(
        default=None,
        description="Market Engine price timestamp",
    )
    current_market_value: Decimal = Field(
        description="Quantity x Current Price",
    )
    selected_valuation_price: Decimal | None = Field(
        default=None,
        description="Price selected by backend valuation rules",
    )
    selected_price_source: str = Field(
        default="missing",
        description="last_price | closing_price | adjusted_close | fallback | missing",
    )
    market_value: Decimal | None = Field(
        default=None,
        description="Quantity x selected_valuation_price, null when price is missing",
    )
    daily_pnl: Decimal = Field(
        description="(Current Last Price - Previous Close) x Quantity",
    )
    unrealized_pnl: Decimal = Field(
        description="Current Market Value - Cost Basis",
    )
    unrealized_pnl_pct: Decimal = Field(
        description="(Unrealized PnL / Cost Basis) x 100",
    )
    weight_pct: Decimal = Field(
        description="Position weight as % of total portfolio value",
    )

    # Freshness metadata for staleness detection
    price_timestamp: datetime | None = Field(
        default=None,
        description="ISO timestamp of the latest price data used for valuation",
    )
    is_price_fresh: bool = Field(
        default=True,
        description="True if price data is within acceptable freshness window",
    )
    data_freshness_seconds: int | None = Field(
        default=None,
        description="Seconds since price was last updated",
    )
    is_tradeable: bool = Field(
        default=True,
        description="False if instrument is halted/suspended/closed",
    )
    price_as_of: datetime | None = Field(
        default=None,
        description="Timestamp of selected valuation price",
    )
    is_stale: bool = Field(
        default=True,
        description="True when selected price is stale or missing",
    )
    is_current_session: bool = Field(
        default=False,
        description="True when selected price belongs to current open market session",
    )
    status: str = Field(
        default="missing_price",
        description="ok | closing_price_fallback | halted | stale_price | missing_price",
    )


class PortfolioSummaryResponse(BaseModel):
    """
    Macro-level portfolio statistics for the frontend dashboard.

    Financial Formulas:
      Current Value      = Sum(Quantity x Current Price)
      Total Invested     = Sum(Quantity x WAC)  [= Sum(total_cost_basis)]
      Unrealized PnL     = Current Value - Total Invested
      Unrealized PnL %   = (Unrealized PnL / Total Invested) x 100
      Total PnL          = Realized PnL + Unrealized PnL
      ROI %              = (Total PnL / Total Invested) x 100
    """

    portfolio_id: uuid.UUID
    portfolio_name: str
    base_currency: PortfolioCurrency

    # Core financial metrics
    total_current_value: Decimal = Field(
        description="Sum(Qty x Current Price) for all active positions",
    )
    total_market_value: Decimal | None = Field(
        default=None,
        description="Alias for total_current_value using selected valuation prices",
    )
    total_invested_value: Decimal = Field(
        description="Sum(Qty x WAC) for all active positions",
    )
    total_cost_basis: Decimal | None = Field(
        default=None,
        description="Alias for total_invested_value",
    )

    # PnL breakdown
    total_unrealized_pnl: Decimal = Field(
        description="Current Value - Invested Value",
    )
    daily_pnl: Decimal = Field(
        description="Sum of daily PnL across active positions",
    )
    total_unrealized_pnl_pct: Decimal = Field(
        description="(Unrealized PnL / Invested) x 100",
    )
    total_realized_pnl: Decimal = Field(
        description="Sum of realized PnL from all SELL transactions",
    )
    total_pnl: Decimal = Field(
        description="Realized + Unrealized PnL",
    )
    roi_pct: Decimal = Field(
        description="(Total PnL / Total Invested) x 100",
    )

    # Counts
    active_positions_count: int = Field(
        description="Number of assets with quantity > 0",
    )
    holdings_count: int | None = Field(
        default=None,
        description="Alias for active_positions_count",
    )
    missing_price_count: int = Field(default=0)
    stale_price_count: int = Field(default=0)
    total_trades_count: int = Field(
        description="Total number of trades in this portfolio",
    )

    # Per-position breakdown
    positions: list[PositionWithMarketData] = Field(
        default_factory=list,
        description="Active positions enriched with market data",
    )

    # Portfolio-level freshness metadata
    is_valuation_partial: bool = Field(
        default=False,
        description="True if any position has missing or stale price data",
    )
    missing_price_assets: list[str] = Field(
        default_factory=list,
        description="Tickers with unavailable prices",
    )
    stale_price_assets: list[str] = Field(
        default_factory=list,
        description="Tickers with stale price data",
    )
    suspended_assets: list[str] = Field(
        default_factory=list,
        description="Tickers with halted/suspended status",
    )
    data_freshness_seconds: int | None = Field(
        default=None,
        description="Seconds since oldest price data was updated across portfolio",
    )
    last_price_update_at: datetime | None = Field(
        default=None,
        description="ISO timestamp of the most recent price update in portfolio",
    )
    last_market_update: datetime | None = Field(
        default=None,
        description="ISO timestamp of the latest market price update used in valuation",
    )
    valuation_as_of: datetime = Field(
        description="ISO timestamp of when this valuation was computed",
    )
    as_of: datetime | None = Field(
        default=None,
        description="Alias for valuation_as_of",
    )
    market_status: str = Field(default="unknown")
    data_quality_status: str = Field(default="unknown")
