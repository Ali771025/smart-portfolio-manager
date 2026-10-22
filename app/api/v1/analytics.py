"""FastAPI router for analytics and performance endpoints."""

from __future__ import annotations

from dataclasses import asdict
import uuid
from typing import Annotated

from fastapi import APIRouter, Depends, Query
from fastapi.responses import JSONResponse

from app.core.deps import CurrentUser, get_analytics_service
from app.schemas.analytics import (
    AnalyticsTimeframe,
    MetricsResponseDTO,
    PerformanceResponseDTO,
    ProblemDetails,
)
from app.services.analytics_service import AnalyticsProblem, AnalyticsService

router = APIRouter(prefix="/analytics", tags=["Analytics"])


def _problem_response(problem: AnalyticsProblem) -> JSONResponse:
    payload = (
        problem.problem.model_dump()
        if hasattr(problem.problem, "model_dump")
        else asdict(problem.problem)
    )
    return JSONResponse(
        status_code=problem.status_code,
        content=payload,
        media_type="application/problem+json",
    )


@router.get(
    "/performance",
    response_model=PerformanceResponseDTO,
    responses={
        401: {"model": ProblemDetails, "content": {"application/problem+json": {}}},
        404: {"model": ProblemDetails, "content": {"application/problem+json": {}}},
        422: {"model": ProblemDetails, "content": {"application/problem+json": {}}},
        500: {"model": ProblemDetails, "content": {"application/problem+json": {}}},
    },
)
async def get_portfolio_performance(
    current_user: CurrentUser,
    service: Annotated[AnalyticsService, Depends(get_analytics_service)],
    portfolio_id: uuid.UUID | None = Query(
        default=None,
        description="Portfolio identifier. If omitted, the user's default active portfolio is used.",
    ),
    timeframe: AnalyticsTimeframe = Query(
        default=AnalyticsTimeframe.ALL,
        description="Analytics timeframe window",
    ),
) -> PerformanceResponseDTO | JSONResponse:
    """Return aggregated portfolio performance time-series for the requested timeframe."""

    try:
        payload = await service.get_performance_timeseries(
            portfolio_id=portfolio_id,
            user_id=current_user.id,
            timeframe=timeframe.value,
        )
    except AnalyticsProblem as exc:
        return _problem_response(exc)

    return PerformanceResponseDTO.model_validate(payload)


@router.get(
    "/metrics",
    response_model=MetricsResponseDTO,
    responses={
        401: {"model": ProblemDetails, "content": {"application/problem+json": {}}},
        404: {"model": ProblemDetails, "content": {"application/problem+json": {}}},
        422: {"model": ProblemDetails, "content": {"application/problem+json": {}}},
        500: {"model": ProblemDetails, "content": {"application/problem+json": {}}},
    },
)
async def get_portfolio_metrics(
    current_user: CurrentUser,
    service: Annotated[AnalyticsService, Depends(get_analytics_service)],
    portfolio_id: uuid.UUID | None = Query(
        default=None,
        description="Portfolio identifier. If omitted, the user's default active portfolio is used.",
    ),
    timeframe: AnalyticsTimeframe = Query(
        default=AnalyticsTimeframe.ALL,
        description="Analytics timeframe window",
    ),
) -> MetricsResponseDTO | JSONResponse:
    """Return portfolio KPIs plus advanced quant risk assessment for the timeframe."""

    try:
        payload = await service.get_performance_metrics(
            portfolio_id=portfolio_id,
            user_id=current_user.id,
            timeframe=timeframe.value,
        )
    except AnalyticsProblem as exc:
        return _problem_response(exc)

    return MetricsResponseDTO.model_validate(payload)
