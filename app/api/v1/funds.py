"""Read APIs for normalized fund, NAV, and risk-free benchmark data."""

from __future__ import annotations

from decimal import Decimal

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.database import get_db
from app.core.deps import CurrentUser
from app.repositories.market_data import MarketDataRepository
from app.schemas.funds import FundNavResponse, FundResponse, RiskFreeBenchmarkResponse
from app.services.fund_benchmark import is_fixed_income_fund_type

router = APIRouter(tags=["Funds"])


@router.get("/funds", response_model=list[FundResponse])
async def list_funds(
    _: CurrentUser,
    fund_type: str | None = Query(default=None, alias="type", max_length=128),
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=100, ge=1, le=500),
    db: AsyncSession = Depends(get_db),
) -> list[FundResponse]:
    rows = await MarketDataRepository(db).list_funds(
        fund_type=fund_type,
        limit=page_size,
        offset=(page - 1) * page_size,
    )
    return [FundResponse.model_validate(item) for item in rows]


@router.get("/funds/{fund_id}", response_model=FundResponse)
async def get_fund(
    fund_id: str,
    _: CurrentUser,
    db: AsyncSession = Depends(get_db),
) -> FundResponse:
    item = await MarketDataRepository(db).get_fund(fund_id.strip())
    if item is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Fund not found")
    return FundResponse.model_validate(item)


@router.get("/funds/{fund_id}/nav", response_model=FundNavResponse)
async def get_fund_nav(
    fund_id: str,
    _: CurrentUser,
    db: AsyncSession = Depends(get_db),
) -> FundNavResponse:
    item = await MarketDataRepository(db).get_latest_fund_nav(fund_id.strip())
    if item is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Fund NAV not found")
    return FundNavResponse.model_validate(item)


@router.get("/benchmarks/risk-free", response_model=RiskFreeBenchmarkResponse)
async def get_risk_free_benchmark(
    _: CurrentUser,
    db: AsyncSession = Depends(get_db),
) -> RiskFreeBenchmarkResponse:
    mode = settings.RISK_FREE_BENCHMARK_MODE.strip().lower()
    if mode in {"fund", "fixed_income_fund"} and settings.RISK_FREE_FUND_ID.strip():
        fund = await MarketDataRepository(db).get_fund(settings.RISK_FREE_FUND_ID.strip())
        if fund is not None and is_fixed_income_fund_type(fund.type) and fund.return_1y is not None:
            return RiskFreeBenchmarkResponse(
                name=fund.name,
                annual_return_percent=fund.return_1y,
                source=fund.source,
                fund_id=fund.fund_id,
                nav=fund.nav,
                nav_date=fund.nav_date,
            )
        if not settings.RISK_FREE_ALLOW_CONFIGURED_FALLBACK:
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="Configured fixed-income benchmark is unavailable or invalid",
            )

    configured_rate = Decimal(str(settings.RISK_FREE_ANNUAL_RATE))
    if configured_rate < 0 or configured_rate > 100:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Configured risk-free rate is invalid",
        )
    return RiskFreeBenchmarkResponse(
        name=settings.RISK_FREE_BENCHMARK_NAME,
        annual_return_percent=configured_rate,
        source="CONFIGURATION",
        fallback_used=mode in {"fund", "fixed_income_fund"},
    )
