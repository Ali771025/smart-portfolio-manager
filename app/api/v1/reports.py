"""FastAPI router for portfolio report endpoints."""

from __future__ import annotations

import uuid
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Query
from fastapi.responses import JSONResponse
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.deps import CurrentUser
from app.schemas.reports import (
    MonthlyReportResponse,
    YearlyReportResponse,
)
from app.services.report_service import ReportService

router = APIRouter(prefix="/reports", tags=["Reports"])


async def _get_report_service(
    db: AsyncSession = Depends(get_db),
) -> ReportService:
    """Dependency injector for report service."""
    return ReportService(db)


@router.get(
    "/monthly",
    response_model=MonthlyReportResponse,
    summary="Get monthly portfolio report",
    description="Returns comprehensive monthly portfolio performance report.",
)
async def get_monthly_report(
    current_user: CurrentUser,
    service: Annotated[ReportService, Depends(_get_report_service)],
    portfolio_id: uuid.UUID = Query(
        description="Portfolio identifier",
    ),
    year: int = Query(
        description="Report year",
    ),
    month: int = Query(
        ge=1,
        le=12,
        description="Report month (1-12)",
    ),
) -> MonthlyReportResponse | JSONResponse:
    """Get monthly portfolio report."""
    try:
        return await service.get_monthly_report(
            portfolio_id=portfolio_id,
            user_id=current_user.id,
            year=year,
            month=month,
        )
    except ValueError as exc:
        return JSONResponse(
            status_code=404,
            content={"error": str(exc)},
        )


@router.get(
    "/yearly",
    response_model=YearlyReportResponse,
    summary="Get yearly portfolio report",
    description="Returns comprehensive yearly portfolio performance report with monthly breakdown.",
)
async def get_yearly_report(
    current_user: CurrentUser,
    service: Annotated[ReportService, Depends(_get_report_service)],
    portfolio_id: uuid.UUID = Query(
        description="Portfolio identifier",
    ),
    year: int = Query(
        description="Report year",
    ),
) -> YearlyReportResponse | JSONResponse:
    """Get yearly portfolio report."""
    try:
        return await service.get_yearly_report(
            portfolio_id=portfolio_id,
            user_id=current_user.id,
            year=year,
        )
    except ValueError as exc:
        return JSONResponse(
            status_code=404,
            content={"error": str(exc)},
        )
