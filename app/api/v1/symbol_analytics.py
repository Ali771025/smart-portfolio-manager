"""API router for selected-symbol analytics.

Endpoints:
  - GET  /portfolios/{portfolio_id}/symbols
  - GET  /portfolios/{portfolio_id}/symbols/{symbol}/analytics
  - GET  /portfolios/{portfolio_id}/symbols/{symbol}/charts
"""

from __future__ import annotations

import uuid
from typing import Annotated

from fastapi import APIRouter, Depends, Query

from app.core.deps import CurrentUser, get_db
from app.schemas.charts import ChartPeriod
from app.schemas.returns import ReturnPeriod
from app.schemas.symbol_analytics import (
    PortfolioHoldingsListResponse,
    SymbolAnalyticsResponse,
    SymbolChartResponse,
)
from app.services.symbol_analytics_service import SymbolAnalyticsService
from sqlalchemy.ext.asyncio import AsyncSession

router = APIRouter(
    prefix="/portfolios/{portfolio_id}/symbols",
    tags=["Symbol Analytics"],
)


def _get_service(
    db: Annotated[AsyncSession, Depends(get_db)],
) -> SymbolAnalyticsService:
    return SymbolAnalyticsService(db)


@router.get(
    "",
    response_model=PortfolioHoldingsListResponse,
    summary="List selectable portfolio symbols",
    description="Returns all current holdings with live market data for symbol selection.",
)
async def list_portfolio_symbols(
    portfolio_id: uuid.UUID,
    current_user: CurrentUser,
    service: Annotated[SymbolAnalyticsService, Depends(_get_service)],
) -> PortfolioHoldingsListResponse:
    return await service.list_portfolio_holdings(
        portfolio_id=portfolio_id,
        user_id=current_user.id,
    )


@router.get(
    "/{symbol}/analytics",
    response_model=SymbolAnalyticsResponse,
    summary="Get analytics for a selected symbol",
    description="Returns comprehensive analytics: position info, return series, monthly returns, and benchmark comparison.",
)
async def get_symbol_analytics(
    portfolio_id: uuid.UUID,
    symbol: str,
    current_user: CurrentUser,
    service: Annotated[SymbolAnalyticsService, Depends(_get_service)],
    period: ReturnPeriod = Query(default=ReturnPeriod.ONE_YEAR),
    include_monthly: bool = Query(default=False),
    monthly_year: int | None = Query(default=None),
    include_benchmark: bool = Query(default=False),
    benchmark_id: str | None = Query(default=None, description="e.g. TEDPIX, GOLD_18K, USD_IRR, RISK_FREE"),
) -> SymbolAnalyticsResponse:
    return await service.get_symbol_analytics(
        portfolio_id=portfolio_id,
        user_id=current_user.id,
        symbol=symbol,
        period=period,
        include_monthly=include_monthly,
        monthly_year=monthly_year,
        include_benchmark=include_benchmark,
        benchmark_id=benchmark_id,
    )


@router.get(
    "/{symbol}/charts",
    response_model=SymbolChartResponse,
    summary="Get chart data for a selected symbol",
    description="Returns chart-ready time series data for a single portfolio symbol.",
)
async def get_symbol_charts(
    portfolio_id: uuid.UUID,
    symbol: str,
    current_user: CurrentUser,
    service: Annotated[SymbolAnalyticsService, Depends(_get_service)],
    chart_type: str = Query(default="performance", description="performance | price"),
    period: ChartPeriod = Query(default=ChartPeriod.ONE_YEAR),
    start_date: str | None = Query(default=None, description="YYYY-MM-DD"),
    end_date: str | None = Query(default=None, description="YYYY-MM-DD"),
) -> SymbolChartResponse:
    from datetime import date as _date

    sd = _date.fromisoformat(start_date) if start_date else None
    ed = _date.fromisoformat(end_date) if end_date else None

    return await service.get_symbol_chart(
        portfolio_id=portfolio_id,
        user_id=current_user.id,
        symbol=symbol,
        chart_type=chart_type,
        period=period,
        start_date=sd,
        end_date=ed,
    )
