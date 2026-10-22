"""FastAPI router for benchmark comparison endpoints.

Provides:
  - GET /benchmarks/compare/{asset_id} - Compare against multiple benchmarks
  - GET /benchmarks/compare/{asset_id}/single - Compare against single benchmark
  - GET /benchmarks/compare/{asset_id}/series - Get comparison time series
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
from app.schemas.benchmark_comparison import (
    BenchmarkComparisonResultDTO,
    BenchmarkComparisonSummaryDTO,
    BenchmarkIdentifier,
    ComparisonPeriod,
    ComparisonSeriesResponseDTO,
)
from app.services.benchmark_comparison_service import BenchmarkComparisonService
from sqlalchemy.ext.asyncio import AsyncSession

router = APIRouter(prefix="/benchmarks", tags=["Benchmark Comparison"])


def _get_comparison_service(
    db: AsyncSession = Depends(get_db),
) -> BenchmarkComparisonService:
    """Dependency injector for benchmark comparison service."""
    repository = ReturnsReadRepository(db)
    return BenchmarkComparisonService(repository)


@router.get(
    "/compare/{asset_id}",
    response_model=BenchmarkComparisonSummaryDTO,
    summary="Compare asset against multiple benchmarks",
    description="Returns comparison results for multiple benchmarks.",
)
async def compare_asset_benchmarks(
    asset_id: uuid.UUID,
    _: CurrentUser,
    service: BenchmarkComparisonService = Depends(_get_comparison_service),
    benchmark_ids: str = Query(
        default="TEDPIX",
        description="Comma-separated benchmark IDs",
    ),
    period: ComparisonPeriod = Query(
        default=ComparisonPeriod.ONE_YEAR,
        description="Comparison period",
    ),
    as_of_date: date | None = Query(
        default=None,
        description="Reference date (default: today)",
    ),
) -> BenchmarkComparisonSummaryDTO:
    """Compare asset against multiple benchmarks.

    Returns:
      - Comparison results for each benchmark
      - Best/worst benchmark identification
      - Alignment metadata
    """
    # Parse benchmark IDs
    try:
        benchmarks = [
            BenchmarkIdentifier(b.strip())
            for b in benchmark_ids.split(",")
            if b.strip()
        ]
    except ValueError as e:
        return JSONResponse(
            status_code=400,
            content={
                "error": "Invalid benchmark ID",
                "detail": str(e),
                "status_code": 400,
            },
        )

    if not benchmarks:
        benchmarks = [BenchmarkIdentifier.TEDPIX]

    return await service.compare_multiple_benchmarks(
        asset_id=asset_id,
        benchmark_ids=benchmarks,
        period=period,
        as_of_date=as_of_date,
    )


@router.get(
    "/compare/{asset_id}/single",
    response_model=BenchmarkComparisonResultDTO,
    summary="Compare asset against single benchmark",
    description="Returns detailed comparison against one benchmark.",
)
async def compare_asset_single_benchmark(
    asset_id: uuid.UUID,
    _: CurrentUser,
    service: BenchmarkComparisonService = Depends(_get_comparison_service),
    benchmark_id: BenchmarkIdentifier = Query(
        default=BenchmarkIdentifier.TEDPIX,
        description="Benchmark to compare against",
    ),
    period: ComparisonPeriod = Query(
        default=ComparisonPeriod.ONE_YEAR,
        description="Comparison period",
    ),
    as_of_date: date | None = Query(
        default=None,
        description="Reference date (default: today)",
    ),
) -> BenchmarkComparisonResultDTO:
    """Compare asset against a single benchmark.

    Returns detailed metrics:
      - Return comparison (absolute, excess)
      - Risk metrics (beta, alpha, tracking error, correlation)
      - Alignment metadata
    """
    return await service.compare_single_benchmark(
        asset_id=asset_id,
        benchmark_id=benchmark_id,
        period=period,
        as_of_date=as_of_date,
    )


@router.get(
    "/compare/{asset_id}/series",
    response_model=ComparisonSeriesResponseDTO,
    summary="Get comparison time series",
    description="Returns aligned return series for charting.",
)
async def get_comparison_series(
    asset_id: uuid.UUID,
    _: CurrentUser,
    service: BenchmarkComparisonService = Depends(_get_comparison_service),
    benchmark_id: BenchmarkIdentifier = Query(
        default=BenchmarkIdentifier.TEDPIX,
        description="Benchmark to compare against",
    ),
    period: ComparisonPeriod = Query(
        default=ComparisonPeriod.ONE_YEAR,
        description="Comparison period",
    ),
    as_of_date: date | None = Query(
        default=None,
        description="Reference date (default: today)",
    ),
) -> ComparisonSeriesResponseDTO:
    """Get comparison time series for charting.

    Returns aligned daily data points with:
      - Target cumulative return
      - Benchmark cumulative return
      - Excess return series
    """
    return await service.get_comparison_series(
        asset_id=asset_id,
        benchmark_id=benchmark_id,
        period=period,
        as_of_date=as_of_date,
    )


@router.get(
    "/available",
    summary="List available benchmarks",
    description="Returns list of available benchmark identifiers.",
)
async def list_available_benchmarks(
    _: CurrentUser,
) -> dict:
    """List available benchmark identifiers."""
    benchmarks = [
        {
            "id": b.value,
            "name": {
                "TEDPIX": "شاخص کل",
                "GOLD_18K": "طلای ۱۸ عیار",
                "USD_IRR": "دلار آمریکا",
                "EQUAL_WEIGHT": "شاخص هم وزن",
                "MARKET_CAP": "شاخص شرکت‌های بزرگ",
                "RISK_FREE": "نرخ سود بانکی",
            }.get(b.value, b.value),
            "description": {
                "TEDPIX": "شاخص کل بورس اوراق بهادار تهران",
                "GOLD_18K": "طلای ۱۸ عیار",
                "USD_IRR": "نرخ ارز دلار آمریکا به ریال",
                "EQUAL_WEIGHT": "شاخص هم وزن بورس",
                "MARKET_CAP": "شاخص شرکت‌های بزرگ بورس",
                "RISK_FREE": "نرخ سود بدون ریسک (قابل پیکربندی)",
            }.get(b.value, ""),
        }
        for b in BenchmarkIdentifier
    ]
    return {"benchmarks": benchmarks}


@router.get(
    "/ticker/{ticker}/compare",
    response_model=BenchmarkComparisonSummaryDTO,
    summary="Compare ticker against multiple benchmarks",
    description="Returns comparison results for a ticker symbol.",
)
async def compare_ticker_benchmarks(
    ticker: str,
    _: CurrentUser,
    service: BenchmarkComparisonService = Depends(_get_comparison_service),
    benchmark_ids: str = Query(
        default="TEDPIX",
        description="Comma-separated benchmark IDs",
    ),
    period: ComparisonPeriod = Query(
        default=ComparisonPeriod.ONE_YEAR,
        description="Comparison period",
    ),
    as_of_date: date | None = Query(
        default=None,
        description="Reference date (default: today)",
    ),
) -> BenchmarkComparisonSummaryDTO | JSONResponse:
    """Compare ticker against multiple benchmarks.

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

    # Parse benchmark IDs
    try:
        benchmarks = [
            BenchmarkIdentifier(b.strip())
            for b in benchmark_ids.split(",")
            if b.strip()
        ]
    except ValueError as e:
        return JSONResponse(
            status_code=400,
            content={
                "error": "Invalid benchmark ID",
                "detail": str(e),
                "status_code": 400,
            },
        )

    if not benchmarks:
        benchmarks = [BenchmarkIdentifier.TEDPIX]

    return await service.compare_multiple_benchmarks(
        asset_id=asset.id,
        benchmark_ids=benchmarks,
        period=period,
        as_of_date=as_of_date,
    )


@router.get(
    "/ticker/{ticker}/single",
    response_model=BenchmarkComparisonResultDTO,
    summary="Compare ticker against single benchmark",
    description="Returns detailed comparison for a ticker symbol.",
)
async def compare_ticker_single_benchmark(
    ticker: str,
    _: CurrentUser,
    service: BenchmarkComparisonService = Depends(_get_comparison_service),
    benchmark_id: BenchmarkIdentifier = Query(
        default=BenchmarkIdentifier.TEDPIX,
        description="Benchmark to compare against",
    ),
    period: ComparisonPeriod = Query(
        default=ComparisonPeriod.ONE_YEAR,
        description="Comparison period",
    ),
    as_of_date: date | None = Query(
        default=None,
        description="Reference date (default: today)",
    ),
) -> BenchmarkComparisonResultDTO | JSONResponse:
    """Compare ticker against a single benchmark.

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

    return await service.compare_single_benchmark(
        asset_id=asset.id,
        benchmark_id=benchmark_id,
        period=period,
        as_of_date=as_of_date,
    )


@router.get(
    "/ticker/{ticker}/series",
    response_model=ComparisonSeriesResponseDTO,
    summary="Get comparison series for ticker",
    description="Returns aligned return series for a ticker symbol.",
)
async def get_ticker_comparison_series(
    ticker: str,
    _: CurrentUser,
    service: BenchmarkComparisonService = Depends(_get_comparison_service),
    benchmark_id: BenchmarkIdentifier = Query(
        default=BenchmarkIdentifier.TEDPIX,
        description="Benchmark to compare against",
    ),
    period: ComparisonPeriod = Query(
        default=ComparisonPeriod.ONE_YEAR,
        description="Comparison period",
    ),
    as_of_date: date | None = Query(
        default=None,
        description="Reference date (default: today)",
    ),
) -> ComparisonSeriesResponseDTO | JSONResponse:
    """Get comparison time series for a ticker symbol.

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

    return await service.get_comparison_series(
        asset_id=asset.id,
        benchmark_id=benchmark_id,
        period=period,
        as_of_date=as_of_date,
    )
