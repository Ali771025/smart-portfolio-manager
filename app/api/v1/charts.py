"""API router for portfolio chart data endpoints.

Provides frontend-ready time series data for:
  - Capital growth
  - Asset value over time
  - Per-stock performance
  - Monthly returns per stock
"""

from __future__ import annotations

import uuid
from typing import Annotated

from fastapi import APIRouter, Depends, Query

from app.core.deps import CurrentUser, get_db
from app.schemas.charts import (
    CapitalGrowthResponse,
    ChartPeriod,
    ChartResponse,
    MonthlyReturnsResponse,
)
from app.services.chart_service import ChartService
from sqlalchemy.ext.asyncio import AsyncSession

router = APIRouter(prefix="/portfolios/{portfolio_id}/charts", tags=["Charts"])


def _get_chart_service(
    db: Annotated[AsyncSession, Depends(get_db)],
) -> ChartService:
    return ChartService(db)


@router.get(
    "/capital-growth",
    response_model=CapitalGrowthResponse,
    summary="Capital growth chart data",
    description="Portfolio value, cost basis, and ROI over time.",
)
async def get_capital_growth(
    portfolio_id: uuid.UUID,
    current_user: CurrentUser,
    service: Annotated[ChartService, Depends(_get_chart_service)],
    period: ChartPeriod = Query(default=ChartPeriod.ONE_YEAR),
    start_date: str | None = Query(default=None, description="YYYY-MM-DD"),
    end_date: str | None = Query(default=None, description="YYYY-MM-DD"),
) -> CapitalGrowthResponse:
    from datetime import date as _date

    sd = _date.fromisoformat(start_date) if start_date else None
    ed = _date.fromisoformat(end_date) if end_date else None

    return await service.get_capital_growth_chart(
        portfolio_id=portfolio_id,
        user_id=current_user.id,
        period=period,
        start_date=sd,
        end_date=ed,
    )


@router.get(
    "/asset-value",
    response_model=ChartResponse,
    summary="Asset value over time chart data",
    description="Per-asset market value contribution over time (stacked area).",
)
async def get_asset_value(
    portfolio_id: uuid.UUID,
    current_user: CurrentUser,
    service: Annotated[ChartService, Depends(_get_chart_service)],
    period: ChartPeriod = Query(default=ChartPeriod.ONE_YEAR),
    start_date: str | None = Query(default=None, description="YYYY-MM-DD"),
    end_date: str | None = Query(default=None, description="YYYY-MM-DD"),
    symbols: list[str] | None = Query(default=None, description="Filter by ticker symbols"),
) -> ChartResponse:
    from datetime import date as _date

    sd = _date.fromisoformat(start_date) if start_date else None
    ed = _date.fromisoformat(end_date) if end_date else None

    return await service.get_asset_value_chart(
        portfolio_id=portfolio_id,
        user_id=current_user.id,
        period=period,
        start_date=sd,
        end_date=ed,
        symbols=symbols,
    )


@router.get(
    "/symbol-performance",
    response_model=ChartResponse,
    summary="Per-stock performance chart data",
    description="Normalized performance overlay for each stock (rebased to 100 at period start).",
)
async def get_symbol_performance(
    portfolio_id: uuid.UUID,
    current_user: CurrentUser,
    service: Annotated[ChartService, Depends(_get_chart_service)],
    period: ChartPeriod = Query(default=ChartPeriod.ONE_YEAR),
    start_date: str | None = Query(default=None, description="YYYY-MM-DD"),
    end_date: str | None = Query(default=None, description="YYYY-MM-DD"),
    symbols: list[str] | None = Query(default=None, description="Filter by ticker symbols"),
) -> ChartResponse:
    from datetime import date as _date

    sd = _date.fromisoformat(start_date) if start_date else None
    ed = _date.fromisoformat(end_date) if end_date else None

    return await service.get_symbol_performance_chart(
        portfolio_id=portfolio_id,
        user_id=current_user.id,
        period=period,
        start_date=sd,
        end_date=ed,
        symbols=symbols,
    )


@router.get(
    "/monthly-returns",
    response_model=MonthlyReturnsResponse,
    summary="Monthly returns per stock",
    description="Monthly return bars for each stock in the portfolio plus aggregate.",
)
async def get_monthly_returns(
    portfolio_id: uuid.UUID,
    current_user: CurrentUser,
    service: Annotated[ChartService, Depends(_get_chart_service)],
    year: int | None = Query(default=None, description="Calendar year (default: current)"),
    symbols: list[str] | None = Query(default=None, description="Filter by ticker symbols"),
) -> MonthlyReturnsResponse:
    return await service.get_monthly_returns_chart(
        portfolio_id=portfolio_id,
        user_id=current_user.id,
        year=year,
        symbols=symbols,
    )
