"""FastAPI router for historical returns endpoints.

Provides:
  - GET /returns/asset/{asset_id}/summary - Returns summary for all periods
  - GET /returns/asset/{asset_id}/series - Return series for charting
"""

from __future__ import annotations

import uuid
from datetime import date
from typing import Annotated

from fastapi import APIRouter, Depends, Query
from fastapi.responses import JSONResponse

from app.core.database import get_db
from app.core.deps import CurrentUser
from app.repositories.returns_read import ReturnsReadRepository
from app.schemas.returns import (
    DataQuality,
    ReturnPeriod,
    ReturnSeriesResponseDTO,
    ReturnsSummaryResponseDTO,
)
from app.services.returns_service import ReturnsService
from sqlalchemy.ext.asyncio import AsyncSession

router = APIRouter(prefix="/returns", tags=["Historical Returns"])


def _get_returns_service(
    db: AsyncSession = Depends(get_db),
) -> ReturnsService:
    """Dependency injector for returns service."""
    repository = ReturnsReadRepository(db)
    return ReturnsService(repository)


@router.get(
    "/asset/{asset_id}/summary",
    response_model=ReturnsSummaryResponseDTO,
    summary="Get returns summary for an asset",
    description="Returns period returns (1M, 3M, 6M, 1Y, YTD, Inception) for an asset.",
)
async def get_asset_returns_summary(
    asset_id: uuid.UUID,
    _: CurrentUser,
    service: ReturnsService = Depends(_get_returns_service),
    as_of_date: date | None = Query(
        default=None,
        description="Reference date (default: today)",
    ),
) -> ReturnsSummaryResponseDTO:
    """Get returns summary for a single asset.

    Returns period returns for all standard windows:
    - 1M, 3M, 6M, 1Y, YTD, Inception

    Also includes benchmark comparisons where available.
    """
    return await service.get_asset_returns_summary(
        asset_id=asset_id,
        as_of_date=as_of_date,
    )


@router.get(
    "/asset/{asset_id}/series",
    response_model=ReturnSeriesResponseDTO,
    summary="Get return series for charting",
    description="Returns daily return time series for the specified period.",
)
async def get_asset_return_series(
    asset_id: uuid.UUID,
    _: CurrentUser,
    service: ReturnsService = Depends(_get_returns_service),
    period: ReturnPeriod = Query(
        default=ReturnPeriod.ONE_YEAR,
        description="Return period",
    ),
    as_of_date: date | None = Query(
        default=None,
        description="Reference date (default: today)",
    ),
) -> ReturnSeriesResponseDTO:
    """Get return time series for charting.

    Returns daily return data points for the specified period.
    Each point includes:
    - Cumulative return from period start
    - Daily return percentage
    - Normalized value (1.0 = 0%)
    """
    return await service.get_asset_return_series(
        asset_id=asset_id,
        period=period,
        as_of_date=as_of_date,
    )


@router.get(
    "/ticker/{ticker}/summary",
    response_model=ReturnsSummaryResponseDTO,
    summary="Get returns summary by ticker symbol",
    description="Returns period returns for an asset identified by ticker symbol.",
)
async def get_ticker_returns_summary(
    ticker: str,
    _: CurrentUser,
    service: ReturnsService = Depends(_get_returns_service),
    as_of_date: date | None = Query(
        default=None,
        description="Reference date (default: today)",
    ),
) -> ReturnsSummaryResponseDTO | JSONResponse:
    """Get returns summary by ticker symbol.

    Convenience endpoint that resolves ticker to asset_id.
    """
    from app.repositories.returns_read import ReturnsReadRepository
    from app.core.database import async_session_factory

    async with async_session_factory() as db:
        repo = ReturnsReadRepository(db)
        asset = await repo.get_asset_by_ticker(ticker)

    if asset is None:
        return JSONResponse(
            status_code=404,
            content={
                "error": "Asset Not Found",
                "detail": f"No asset found with ticker {ticker}",
                "status_code": 404,
            },
        )

    return await service.get_asset_returns_summary(
        asset_id=asset.id,
        as_of_date=as_of_date,
    )
