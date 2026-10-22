"""Schemas for advanced PnL metrics and time-series analytics."""

from __future__ import annotations

import uuid
from datetime import UTC, date, datetime
from decimal import Decimal

from pydantic import BaseModel, Field, model_validator

from app.models.enums import BenchmarkType, PortfolioCurrency


class AssetPnLBreakdown(BaseModel):
    """Per-asset valuation statistics used for allocation and PnL dashboards."""

    asset_id: uuid.UUID
    ticker_symbol: str
    name: str | None = None
    quantity: Decimal
    weighted_avg_cost: Decimal
    total_cost: Decimal
    live_price: Decimal
    last_price: Decimal | None = None
    closing_price: Decimal | None = None
    selected_valuation_price: Decimal | None = None
    selected_price_source: str = "missing"
    current_value: Decimal
    market_value: Decimal | None = None
    unrealized_pnl: Decimal
    realized_pnl: Decimal
    weight: Decimal = Field(description="Asset allocation weight in [0,1]")

    # PnL percents
    unrealized_pnl_percent: Decimal = Field(
        default=Decimal("0.0000"),
        description="Unrealized PnL as percent of cost basis",
    )

    # Daily change (if previous price available)
    daily_change: Decimal | None = Field(
        default=None,
        description="Price change from previous close (None if unavailable)",
    )
    daily_change_percent: Decimal | None = Field(
        default=None,
        description="Price change percent from previous close",
    )

    # Freshness metadata
    is_price_fresh: bool = Field(default=True, description="True if price data is fresh")
    price_timestamp: datetime | None = Field(default=None, description="When price was last updated")
    price_as_of: datetime | None = Field(default=None, description="Timestamp of selected valuation price")
    is_stale: bool = True
    is_current_session: bool = False
    status: str = "missing_price"
    data_freshness_seconds: int | None = Field(default=None, description="Seconds since price update")
    is_tradeable: bool = Field(default=True, description="False if instrument is halted/suspended")

    # Status field for frontend display
    price_status: str = Field(
        default="ok",
        description="ok | missing_price | stale_price | insufficient_data",
    )

    # Canonical backend calculation fields for import-ledger holdings.
    symbol: str | None = None
    average_cost: Decimal | None = None
    remaining_cost_basis: Decimal | None = None
    current_price: Decimal | None = None
    current_price_type: str = "MISSING"
    current_price_source: str = "MISSING"
    current_price_date: datetime | None = None
    total_pnl: Decimal = Decimal("0")
    total_pnl_percent: Decimal = Decimal("0")
    data_status: str = "ok"
    warnings: list[str] = Field(default_factory=list)


class PortfolioPnLSummaryResponse(BaseModel):
    """
    Real-time portfolio metrics based on weighted-average-cost accounting.

    Formulas:
      Unrealized PnL = (Live Price × Current Quantity) - Total Cost
      Realized PnL   = Σ((Sell Price - WAC) × Sold Quantity) + Σ(Dividend Profit)
      ROI (%)        = ((Total Current Value - Total Invested) / Total Invested) × 100
      Weight         = Asset Value / Total Portfolio Value
    """

    portfolio_id: uuid.UUID
    portfolio_name: str | None = None
    base_currency: PortfolioCurrency
    total_current_value: Decimal
    total_market_value: Decimal | None = None
    total_invested: Decimal
    total_cost_basis: Decimal | None = None
    total_cash_balance: Decimal = Decimal("0")
    total_portfolio_value: Decimal = Decimal("0")
    total_unrealized_pnl: Decimal
    total_realized_pnl: Decimal
    total_pnl: Decimal = Field(default=Decimal("0"))
    cash_flow_pnl: Decimal = Field(default=Decimal("0"))
    net_invested_capital: Decimal = Field(default=Decimal("0"))
    roi_percent: Decimal
    roi_definition: str = Field(
        default="ROI% = (total_pnl / net_invested_capital) * 100; net_invested_capital defaults to cost_basis when cash ledger is unavailable."
    )
    valuation_is_partial: bool = False
    missing_price_assets: list[str] = Field(default_factory=list)
    sanity_flags: list[str] = Field(default_factory=list)
    assets: list[AssetPnLBreakdown]

    # Enhanced fields
    unrealized_pnl_percent: Decimal = Field(
        default=Decimal("0.0000"),
        description="Total unrealized PnL as percent of cost basis",
    )
    as_of_timestamp: datetime = Field(
        default_factory=lambda: datetime.now(UTC),
        description="Timestamp of when this valuation was computed",
    )
    stale_price_assets: list[str] = Field(
        default_factory=list,
        description="Assets with stale price data",
    )
    holdings_count: int = 0
    missing_price_count: int = 0
    missing_market_price_count: int = 0
    stale_price_count: int = 0
    as_of: datetime | None = None
    market_status: str = "unknown"
    data_quality_status: str = Field(
        default="ok",
        description="ok | partial | stale | insufficient_data",
    )


class PortfolioPerformanceTimeseriesQuery(BaseModel):
    """Query model for sparkline/candlestick-oriented historical responses."""

    start_date: date
    end_date: date
    adjusted_prices: bool = True
    benchmarks: list[BenchmarkType] = Field(
        default_factory=lambda: [BenchmarkType.GOLD_18K, BenchmarkType.USD_IRR, BenchmarkType.TEDPIX],
    )

    @model_validator(mode="after")
    def validate_dates(self) -> "PortfolioPerformanceTimeseriesQuery":
        if self.end_date < self.start_date:
            raise ValueError("end_date must be greater than or equal to start_date")
        if (self.end_date - self.start_date).days > 730:
            raise ValueError("Date range cannot exceed 730 days for this endpoint")
        return self


class PortfolioTimeseriesPoint(BaseModel):
    date: date
    portfolio_value: Decimal
    portfolio_return_pct: Decimal
    benchmark_values: dict[BenchmarkType, Decimal]
    benchmark_return_pct: dict[BenchmarkType, Decimal]


class PortfolioPerformanceTimeseriesResponse(BaseModel):
    portfolio_id: uuid.UUID
    adjusted_prices: bool
    points: list[PortfolioTimeseriesPoint]
