"""Dashboard BFF response schemas (Pydantic v2)."""

from __future__ import annotations

import uuid
from decimal import Decimal
from typing import Annotated

from pydantic import BaseModel, ConfigDict, Field

Decimal4 = Annotated[Decimal, Field(decimal_places=4)]


class ProblemDetails(BaseModel):
    """RFC 7807 error payload."""

    type: str
    title: str
    status: int
    detail: str
    instance: str


class MockActiveUser(BaseModel):
    """Minimal authenticated principal used by the dashboard BFF."""

    model_config = ConfigDict(frozen=True)

    id: uuid.UUID
    is_active: bool = True


class DashboardOverviewMetrics(BaseModel):
    total_current_value: Decimal4
    total_unrealized_pnl: Decimal4
    total_realized_pnl: Decimal4 = Decimal("0")
    overall_roi_percent: Decimal4


class AssetAllocationItem(BaseModel):
    ticker: str
    percentage: Decimal4
    value: Decimal4


class DashboardOverviewResponse(BaseModel):
    metrics: DashboardOverviewMetrics
    asset_allocation: list[AssetAllocationItem] = Field(default_factory=list)


class GrowthChartPoint(BaseModel):
    date: str = Field(pattern=r"^\d{4}/\d{2}/\d{2}$")
    total_value: Decimal4


class PortfolioSummaryItem(BaseModel):
    portfolio_id: uuid.UUID
    portfolio_name: str
    total_value: Decimal4
    roi_percent: Decimal4


class PortfolioSummaryPage(BaseModel):
    page: int = Field(ge=1)
    page_size: int = Field(ge=1, le=100)
    total_items: int = Field(ge=0)
    total_pages: int = Field(ge=0)
    items: list[PortfolioSummaryItem] = Field(default_factory=list)


class DashboardSummaryAsset(BaseModel):
    symbol: str
    name: str
    quantity: Decimal4
    avg_buy_price: Decimal4
    current_price: Decimal4
    market_value: Decimal4
    allocation_percent: Decimal4
    profit_loss: Decimal4
    color_hint: str = Field(pattern=r"^#[0-9A-Fa-f]{6}$")


class DashboardSummaryHistoryPoint(BaseModel):
    date: str = Field(pattern=r"^\d{4}/\d{2}/\d{2}$")
    total_value: Decimal4


class DashboardSummaryTopMover(BaseModel):
    symbol: str
    name: str
    profit_loss: Decimal4
    profit_loss_percent: Decimal4


class DashboardSummaryPortfolioPnl(BaseModel):
    portfolio_id: uuid.UUID
    portfolio_name: str
    total_value: Decimal4
    total_cost_basis: Decimal4
    profit_loss: Decimal4
    profit_loss_percent: Decimal4


class DashboardSummaryData(BaseModel):
    portfolio_count: int = Field(ge=0, default=0)
    total_balance: Decimal4
    total_cost_basis: Decimal4
    total_profit_loss: Decimal4
    total_unrealized_pnl: Decimal4 = Decimal("0")
    total_realized_pnl: Decimal4 = Decimal("0")
    profit_loss_percent: Decimal4
    currency: str = Field(min_length=3, max_length=3)
    assets: list[DashboardSummaryAsset] = Field(default_factory=list)
    top_assets: list[DashboardSummaryAsset] = Field(default_factory=list)
    top_movers: list[DashboardSummaryTopMover] = Field(default_factory=list)
    top_portfolios_by_pnl: list[DashboardSummaryPortfolioPnl] = Field(default_factory=list)
    history: list[DashboardSummaryHistoryPoint] = Field(default_factory=list)


class DashboardSummaryResponse(BaseModel):
    status: str = Field(pattern=r"^success$")
    data: DashboardSummaryData
