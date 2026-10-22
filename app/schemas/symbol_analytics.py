"""Schemas for selected-symbol analytics.

Provides a unified response for per-symbol portfolio analytics:
  - Holdings info (quantity, avg cost, current price, PnL)
  - Return series over selected window
  - Monthly returns
  - Benchmark comparison
  - Data freshness/quality flags
"""

from __future__ import annotations

import uuid
from datetime import date, datetime
from decimal import Decimal
from enum import Enum
from typing import Any

from pydantic import BaseModel, ConfigDict, Field, field_validator

from app.schemas.charts import ChartPeriod, MonthlyReturnPoint
from app.schemas.returns import (
    BenchmarkComparisonDTO,
    DataQuality,
    ReturnPeriod,
    ReturnSeriesPointDTO,
)


class SymbolBaseModel(BaseModel):
    model_config = ConfigDict(extra="forbid", ser_json_inf_nan="null")


# ═══════════════════════════════════════════════════════════════
# Portfolio Holdings List
# ═══════════════════════════════════════════════════════════════


class PortfolioHoldingItem(SymbolBaseModel):
    """One selectable holding in a portfolio."""
    asset_id: uuid.UUID
    ticker_symbol: str
    asset_name: str = Field(default="")
    quantity: Decimal = Field(description="Current held quantity")
    weighted_avg_cost: Decimal = Field(description="Weighted average cost per unit")
    current_price: Decimal | None = Field(default=None, description="Latest market price")
    last_price: Decimal | None = Field(default=None, description="Latest last-trade price from Market Engine")
    closing_price: Decimal | None = Field(default=None, description="Latest closing price from Market Engine")
    price_change: Decimal | None = Field(default=None, description="Absolute change versus previous close")
    price_change_percent: Decimal | None = Field(default=None, description="Percent change versus previous close")
    daily_pnl: Decimal | None = Field(default=None, description="Daily PnL using current price versus previous close")
    last_updated_at: datetime | None = Field(default=None, description="Market Engine price timestamp")
    current_value: Decimal | None = Field(default=None, description="Quantity x Current Price")
    unrealized_pnl: Decimal | None = Field(default=None, description="Market value - Cost basis")
    unrealized_pnl_pct: Decimal | None = Field(default=None, description="PnL as % of cost")
    weight_pct: Decimal = Field(default=Decimal("0"), description="Allocation weight")
    is_price_fresh: bool = Field(default=True)
    is_tradeable: bool = Field(default=True)
    price_status: str = Field(default="ok", description="ok | missing_price | stale_price")


class PortfolioHoldingsListResponse(SymbolBaseModel):
    """List of selectable portfolio holdings."""
    portfolio_id: uuid.UUID
    total_current_value: Decimal
    holdings: list[PortfolioHoldingItem] = Field(default_factory=list)
    as_of_timestamp: datetime


# ═══════════════════════════════════════════════════════════════
# Symbol Analytics
# ═══════════════════════════════════════════════════════════════


class SymbolPositionInfo(SymbolBaseModel):
    """Current position for the selected symbol."""
    asset_id: uuid.UUID
    ticker_symbol: str
    asset_name: str = Field(default="")
    quantity: Decimal
    weighted_avg_cost: Decimal
    total_cost_basis: Decimal
    current_price: Decimal | None = None
    last_price: Decimal | None = None
    closing_price: Decimal | None = None
    price_change: Decimal | None = None
    price_change_percent: Decimal | None = None
    daily_pnl: Decimal | None = None
    last_updated_at: datetime | None = None
    current_value: Decimal | None = None
    unrealized_pnl: Decimal | None = None
    unrealized_pnl_pct: Decimal | None = None
    realized_pnl: Decimal = Field(default=Decimal("0"))
    is_price_fresh: bool = True
    is_tradeable: bool = True
    price_status: str = "ok"
    price_timestamp: datetime | None = None
    data_freshness_seconds: int | None = None


class SymbolReturnSeries(SymbolBaseModel):
    """Return series for charting."""
    period: ReturnPeriod
    start_date: date
    end_date: date
    total_return_pct: float | None = None
    annualized_return_pct: float | None = None
    data_quality: DataQuality = DataQuality.COMPLETE
    points: list[ReturnSeriesPointDTO] = Field(default_factory=list)


class SymbolMonthlyReturns(SymbolBaseModel):
    """Monthly returns for the symbol."""
    year: int
    monthly_returns: list[MonthlyReturnPoint] = Field(default_factory=list)


class SymbolAnalyticsResponse(SymbolBaseModel):
    """Comprehensive analytics for a selected portfolio symbol."""
    portfolio_id: uuid.UUID
    as_of_timestamp: datetime
    total_unrealized_pnl: Decimal | None = None
    last_market_update: datetime | None = None

    position: SymbolPositionInfo

    return_series: SymbolReturnSeries | None = None
    monthly_returns: SymbolMonthlyReturns | None = None
    benchmark_comparison: BenchmarkComparisonDTO | None = None

    data_quality: DataQuality = DataQuality.COMPLETE
    is_stale: bool = False
    sanity_flags: list[str] = Field(default_factory=list)


# ═══════════════════════════════════════════════════════════════
# Symbol Chart Data (uses existing chart schemas)
# ═══════════════════════════════════════════════════════════════


class SymbolChartResponse(SymbolBaseModel):
    """Chart-ready data for a single symbol."""
    portfolio_id: uuid.UUID
    symbol: str
    chart_type: str
    period: ChartPeriod
    start_date: date
    end_date: date
    as_of_timestamp: datetime

    series_key: str = Field(description="Series identifier (ticker)")
    series_name: str = Field(description="Display name")
    value_type: str = Field(default="currency", description="currency | percent | index")
    data_points: list[dict] = Field(default_factory=list, description="Chart points [{date, value}]")

    total_return_pct: float | None = None
    data_quality: DataQuality = DataQuality.COMPLETE
    is_stale: bool = False


# Force Pydantic to resolve all forward references from `from __future__ import annotations`
SymbolMonthlyReturns.model_rebuild()
SymbolAnalyticsResponse.model_rebuild()
SymbolChartResponse.model_rebuild()
