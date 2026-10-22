"""FastAPI router for factor summary endpoints.

Provides:
  - GET /factors/asset/{asset_id} - Get factor summary for an asset
  - GET /factors/ticker/{ticker} - Get factor summary by ticker symbol
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
from app.schemas.factors import (
    FactorSummaryResponseDTO,
)
from app.services.factor_service import FactorService
from sqlalchemy.ext.asyncio import AsyncSession

router = APIRouter(prefix="/factors", tags=["Factor Analysis"])


def _get_factor_service(
    db: AsyncSession = Depends(get_db),
) -> FactorService:
    """Dependency injector for factor service."""
    repository = ReturnsReadRepository(db)
    return FactorService(repository)


@router.get(
    "/asset/{asset_id}",
    response_model=FactorSummaryResponseDTO,
    summary="Get factor summary for an asset",
    description="Returns factor exposures and interpretations for an asset.",
)
async def get_asset_factor_summary(
    asset_id: uuid.UUID,
    _: CurrentUser,
    service: FactorService = Depends(_get_factor_service),
    period: str = Query(
        default="1Y",
        description="Analysis period (1M, 3M, 6M, 1Y)",
    ),
    as_of_date: date | None = Query(
        default=None,
        description="Reference date (default: today)",
    ),
) -> FactorSummaryResponseDTO:
    """Get factor summary for a single asset.

    Returns:
      - Momentum factors (1M, 3M, 6M, 1Y)
      - Volatility factor
      - Drawdown factors (max drawdown, current drawdown)
      - Relative strength vs benchmark
      - Trend indicator

    Each factor includes:
      - value: Numeric value
      - interpretation: Human-readable interpretation
      - status: ok / insufficient_data
    """
    return await service.get_asset_factor_summary(
        asset_id=asset_id,
        period=period,
        as_of_date=as_of_date,
    )


@router.get(
    "/ticker/{ticker}",
    response_model=FactorSummaryResponseDTO,
    summary="Get factor summary by ticker symbol",
    description="Returns factor analysis for an asset identified by ticker.",
)
async def get_ticker_factor_summary(
    ticker: str,
    _: CurrentUser,
    service: FactorService = Depends(_get_factor_service),
    period: str = Query(
        default="1Y",
        description="Analysis period",
    ),
    as_of_date: date | None = Query(
        default=None,
        description="Reference date (default: today)",
    ),
) -> FactorSummaryResponseDTO | JSONResponse:
    """Get factor summary by ticker symbol.

    Convenience endpoint that resolves ticker to asset_id.
    """
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

    return await service.get_asset_factor_summary(
        asset_id=asset.id,
        period=period,
        as_of_date=as_of_date,
    )


@router.get(
    "/batch",
    response_model=list[FactorSummaryResponseDTO],
    summary="Get factor summaries for multiple assets",
    description="Returns factor analysis for multiple assets at once.",
)
async def batch_factor_summaries(
    asset_ids: str,
    _: CurrentUser,
    service: FactorService = Depends(_get_factor_service),
    period: str = Query(
        default="1Y",
        description="Analysis period",
    ),
    as_of_date: date | None = Query(
        default=None,
        description="Reference date (default: today)",
    ),
) -> list[FactorSummaryResponseDTO]:
    """Get factor summaries for multiple assets.

    Accepts comma-separated asset_ids.
    """
    # Parse asset IDs
    try:
        ids = [uuid.UUID(a.strip()) for a in asset_ids.split(",") if a.strip()]
    except ValueError:
        return []

    if not ids or len(ids) > 20:
        return []

    results = []
    for asset_id in ids[:20]:
        try:
            result = await service.get_asset_factor_summary(
                asset_id=asset_id,
                period=period,
                as_of_date=as_of_date,
            )
            results.append(result)
        except Exception:
            pass

    return results
