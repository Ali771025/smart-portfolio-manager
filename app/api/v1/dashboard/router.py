"""Dashboard BFF API router."""

from __future__ import annotations

import uuid
from typing import Annotated

from fastapi import APIRouter, Depends, Query, Response
from fastapi.exceptions import HTTPException
from fastapi.responses import JSONResponse
from fastapi.security import OAuth2PasswordBearer
from pydantic import ValidationError
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.redis import get_redis
from app.core.security import TokenError, decode_access_token

from .schemas import (
    DashboardSummaryResponse,
    DashboardOverviewResponse,
    GrowthChartPoint,
    MockActiveUser,
    PortfolioSummaryPage,
    ProblemDetails,
)
from .services import DashboardService

router = APIRouter()

dashboard_oauth2_scheme = OAuth2PasswordBearer(
    tokenUrl="/api/v1/auth/login",
    auto_error=False,
)


async def current_active_user(
    token: Annotated[str | None, Depends(dashboard_oauth2_scheme)],
) -> MockActiveUser | None:
    """
    Mock auth dependency for BFF.

    It validates bearer presence and extracts user UUID from:
      1) our access JWT `sub` claim, or
      2) a raw UUID token in development mode.
    """

    if not token:
        return None

    user_id: uuid.UUID | None = None
    try:
        payload = decode_access_token(token)
        subject = payload.get("sub")
        if subject:
            user_id = uuid.UUID(subject)
    except (TokenError, ValueError):
        # Fallback for non-JWT local mocks (Bearer <uuid>).
        try:
            user_id = uuid.UUID(token)
        except ValueError:
            user_id = None

    if user_id is None:
        return None

    return MockActiveUser(id=user_id, is_active=True)


def get_dashboard_service(
    db: Annotated[AsyncSession, Depends(get_db)],
) -> DashboardService:
    """Dependency injector for DashboardService."""

    return DashboardService(db=db, redis_client=get_redis())


def _problem_response(exc: HTTPException, instance: str) -> JSONResponse:
    """Ensure HTTP exceptions follow RFC 7807 format."""

    detail = exc.detail
    if isinstance(detail, dict):
        required_keys = {"type", "title", "status", "detail", "instance"}
        if required_keys.issubset(set(detail.keys())):
            try:
                problem = ProblemDetails.model_validate(detail).model_dump()
            except ValidationError:
                problem = ProblemDetails(
                    type="about:blank",
                    title="HTTP Error",
                    status=exc.status_code,
                    detail=str(detail),
                    instance=instance,
                ).model_dump()
        else:
            problem = ProblemDetails(
                type="about:blank",
                title="HTTP Error",
                status=exc.status_code,
                detail=str(detail),
                instance=instance,
            ).model_dump()
    else:
        problem = ProblemDetails(
            type="about:blank",
            title="HTTP Error",
            status=exc.status_code,
            detail=str(detail),
            instance=instance,
        ).model_dump()

    return JSONResponse(
        status_code=exc.status_code,
        content=problem,
        media_type="application/problem+json",
    )


def _unauthorized_response(instance: str) -> JSONResponse:
    """Standardized 401 response."""

    problem = ProblemDetails(
        type="https://smartportfolio.local/problems/unauthorized",
        title="Unauthorized",
        status=401,
        detail="Missing or invalid bearer token.",
        instance=instance,
    )
    return JSONResponse(
        status_code=401,
        content=problem.model_dump(),
        media_type="application/problem+json",
    )


def _bad_request_response(
    *,
    detail: str,
    instance: str,
    type_slug: str,
) -> JSONResponse:
    """Standardized 400 response."""

    problem = ProblemDetails(
        type=f"https://smartportfolio.local/problems/{type_slug}",
        title="Bad Request",
        status=400,
        detail=detail,
        instance=instance,
    )
    return JSONResponse(
        status_code=400,
        content=problem.model_dump(),
        media_type="application/problem+json",
    )


def _parse_positive_int(
    *,
    raw_value: str,
    field_name: str,
    instance: str,
    max_value: int | None = None,
) -> int | JSONResponse:
    """Parse query parameter into a positive integer."""

    try:
        parsed = int(raw_value)
    except ValueError:
        return _bad_request_response(
            detail=f"Query parameter '{field_name}' must be an integer.",
            instance=instance,
            type_slug="invalid-query-parameter",
        )

    if parsed <= 0:
        return _bad_request_response(
            detail=f"Query parameter '{field_name}' must be greater than zero.",
            instance=instance,
            type_slug="invalid-query-parameter",
        )

    if max_value is not None and parsed > max_value:
        return _bad_request_response(
            detail=(
                f"Query parameter '{field_name}' must be less than or equal to "
                f"{max_value}."
            ),
            instance=instance,
            type_slug="invalid-query-parameter",
        )

    return parsed


@router.get(
    "/dashboard/summary",
    response_model=DashboardSummaryResponse,
    responses={
        401: {"model": ProblemDetails, "content": {"application/problem+json": {}}},
        500: {"model": ProblemDetails, "content": {"application/problem+json": {}}},
    },
)
async def get_dashboard_summary(
    current_user: Annotated[MockActiveUser | None, Depends(current_active_user)],
    service: Annotated[DashboardService, Depends(get_dashboard_service)],
    portfolio_id: uuid.UUID | None = Query(
        default=None,
        description="Optional portfolio scope. If omitted, data is aggregated across active portfolios.",
    ),
) -> DashboardSummaryResponse | JSONResponse:
    """
    Return consolidated dashboard contract for frontend rendering.

    Data is fully computed from persisted portfolios, positions,
    snapshots, and live/DB prices.
    """

    if current_user is None:
        return _unauthorized_response(instance="/api/v1/dashboard/summary")

    try:
        if portfolio_id is None:
            return await service.get_summary(
                user_id=current_user.id,
                history_days=30,
            )
        return await service.get_summary(
            user_id=current_user.id,
            history_days=30,
            portfolio_id=portfolio_id,
        )
    except HTTPException as exc:
        return _problem_response(exc, instance="/api/v1/dashboard/summary")


@router.get(
    "/dashboard/overview",
    response_model=DashboardOverviewResponse,
    responses={
        401: {"model": ProblemDetails, "content": {"application/problem+json": {}}},
        500: {"model": ProblemDetails, "content": {"application/problem+json": {}}},
    },
)
async def get_dashboard_overview(
    current_user: Annotated[MockActiveUser | None, Depends(current_active_user)],
    service: Annotated[DashboardService, Depends(get_dashboard_service)],
    portfolio_id: uuid.UUID | None = Query(
        default=None,
        description="Optional portfolio scope. If omitted, data is aggregated across active portfolios.",
    ),
) -> DashboardOverviewResponse | JSONResponse:
    """Return top-level dashboard KPIs and asset allocation."""

    if current_user is None:
        return _unauthorized_response(instance="/api/v1/dashboard/overview")

    try:
        if portfolio_id is None:
            return await service.get_overview(user_id=current_user.id)
        return await service.get_overview(
            user_id=current_user.id,
            portfolio_id=portfolio_id,
        )
    except HTTPException as exc:
        return _problem_response(exc, instance="/api/v1/dashboard/overview")


@router.get(
    "/dashboard/growth-chart",
    response_model=list[GrowthChartPoint],
    responses={
        400: {"model": ProblemDetails, "content": {"application/problem+json": {}}},
        401: {"model": ProblemDetails, "content": {"application/problem+json": {}}},
        500: {"model": ProblemDetails, "content": {"application/problem+json": {}}},
    },
)
async def get_dashboard_growth_chart(
    response: Response,
    current_user: Annotated[MockActiveUser | None, Depends(current_active_user)],
    service: Annotated[DashboardService, Depends(get_dashboard_service)],
) -> list[GrowthChartPoint] | JSONResponse:
    """
    Return 30-day historical portfolio value with Jalali dates.

    Response may be cached briefly by clients and edge caches.
    """

    response.headers["Cache-Control"] = "public, max-age=3600"
    if current_user is None:
        return _unauthorized_response(instance="/api/v1/dashboard/growth-chart")

    try:
        return await service.get_growth_chart(user_id=current_user.id, days=30)
    except HTTPException as exc:
        return _problem_response(exc, instance="/api/v1/dashboard/growth-chart")


@router.get(
    "/portfolios/summary",
    response_model=PortfolioSummaryPage,
    responses={
        400: {"model": ProblemDetails, "content": {"application/problem+json": {}}},
        401: {"model": ProblemDetails, "content": {"application/problem+json": {}}},
        500: {"model": ProblemDetails, "content": {"application/problem+json": {}}},
    },
)
async def get_portfolios_summary(
    current_user: Annotated[MockActiveUser | None, Depends(current_active_user)],
    service: Annotated[DashboardService, Depends(get_dashboard_service)],
    page: str = Query(default="1"),
    page_size: str = Query(default="20"),
) -> PortfolioSummaryPage | JSONResponse:
    """Return paginated portfolio value and ROI summary for dashboard table."""

    if current_user is None:
        return _unauthorized_response(instance="/api/v1/portfolios/summary")

    parsed_page = _parse_positive_int(
        raw_value=page,
        field_name="page",
        instance="/api/v1/portfolios/summary",
    )
    if isinstance(parsed_page, JSONResponse):
        return parsed_page

    parsed_page_size = _parse_positive_int(
        raw_value=page_size,
        field_name="page_size",
        instance="/api/v1/portfolios/summary",
        max_value=100,
    )
    if isinstance(parsed_page_size, JSONResponse):
        return parsed_page_size

    try:
        return await service.get_portfolios_summary(
            user_id=current_user.id,
            page=parsed_page,
            page_size=parsed_page_size,
        )
    except HTTPException as exc:
        return _problem_response(exc, instance="/api/v1/portfolios/summary")
