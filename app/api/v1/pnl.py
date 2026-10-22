"""API router for advanced portfolio PnL analytics."""

from __future__ import annotations

import uuid
from datetime import UTC, date, datetime, timedelta
from typing import Annotated

from fastapi import APIRouter, Depends, Query

from app.core.deps import CurrentUser, get_pnl_calculator_service
from app.models.enums import BenchmarkType
from app.schemas.pnl import (
    PortfolioPerformanceTimeseriesQuery,
    PortfolioPerformanceTimeseriesResponse,
    PortfolioPnLSummaryResponse,
)
from app.services.pnl_calculator import PnLCalculatorService

router = APIRouter()


@router.get(
    "/portfolios/{portfolio_id}/performance/summary",
    response_model=PortfolioPnLSummaryResponse,
)
async def get_portfolio_pnl_summary(
    portfolio_id: uuid.UUID,
    current_user: CurrentUser,
    service: Annotated[PnLCalculatorService, Depends(get_pnl_calculator_service)],
) -> PortfolioPnLSummaryResponse:
    """Compute real-time portfolio PnL using live market prices."""

    return await service.calculate_realtime_summary(
        portfolio_id=portfolio_id,
        user_id=current_user.id,
    )


@router.get(
    "/portfolios/{portfolio_id}/performance/timeseries",
    response_model=PortfolioPerformanceTimeseriesResponse,
)
async def get_portfolio_performance_timeseries(
    portfolio_id: uuid.UUID,
    current_user: CurrentUser,
    service: Annotated[PnLCalculatorService, Depends(get_pnl_calculator_service)],
    start_date: date | None = Query(default=None),
    end_date: date | None = Query(default=None),
    adjusted_prices: bool = Query(True),
    benchmarks: list[BenchmarkType] | None = Query(default=None),
) -> PortfolioPerformanceTimeseriesResponse:
    """Return daily portfolio valuation versus selected benchmarks."""

    now_date = datetime.now(UTC).date()
    query = PortfolioPerformanceTimeseriesQuery(
        start_date=start_date or (now_date - timedelta(days=90)),
        end_date=end_date or now_date,
        adjusted_prices=adjusted_prices,
        benchmarks=benchmarks
        or [BenchmarkType.GOLD_18K, BenchmarkType.USD_IRR, BenchmarkType.TEDPIX],
    )

    return await service.calculate_performance_timeseries(
        portfolio_id=portfolio_id,
        user_id=current_user.id,
        query=query,
    )
