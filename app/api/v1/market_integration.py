"""API router for Celery-powered market integration operations."""

from __future__ import annotations

from datetime import date
from typing import Annotated

from fastapi import APIRouter, Depends, Query, status

from app.core.deps import CurrentUser, get_market_integration_service
from app.models.enums import BenchmarkType
from app.schemas.market_integration import (
    BenchmarkCandleIn,
    BenchmarkSeriesPoint,
    BenchmarkSeriesResponse,
    MarketSyncTaskResponse,
    ProviderHealthResponse,
)
from app.services.market_integration import BenchmarkPayload, MarketIntegrationService
from app.tasks.market_tasks import sync_daily_benchmarks, sync_tsetmc_live_prices

router = APIRouter()


@router.post(
    "/sync/live",
    response_model=MarketSyncTaskResponse,
    status_code=status.HTTP_202_ACCEPTED,
)
def dispatch_live_market_sync(_: CurrentUser) -> MarketSyncTaskResponse:
    """Enqueue live market synchronization task on Celery workers."""

    task = sync_tsetmc_live_prices.delay()
    return MarketSyncTaskResponse(
        task_id=task.id,
        state=task.state,
        message="Live market sync task queued",
    )


@router.post(
    "/sync/benchmarks",
    response_model=MarketSyncTaskResponse,
    status_code=status.HTTP_202_ACCEPTED,
)
def dispatch_benchmark_sync(_: CurrentUser) -> MarketSyncTaskResponse:
    """Enqueue benchmark synchronization task on Celery workers."""

    task = sync_daily_benchmarks.delay()
    return MarketSyncTaskResponse(
        task_id=task.id,
        state=task.state,
        message="Benchmark sync task queued",
    )


@router.post(
    "/benchmarks",
    status_code=status.HTTP_201_CREATED,
)
async def upsert_benchmark_candle(
    payload: BenchmarkCandleIn,
    _: CurrentUser,
    service: Annotated[MarketIntegrationService, Depends(get_market_integration_service)],
) -> dict[str, str]:
    """Manual benchmark backfill endpoint for administrative reconciliation."""

    benchmark_payload = BenchmarkPayload(
        benchmark_type=payload.benchmark_type,
        price_date=payload.date,
        open_price=payload.open_price,
        high_price=payload.high_price,
        low_price=payload.low_price,
        close_price=payload.close_price,
        adjusted_close=payload.adjusted_close,
        adjustment_factor=payload.adjustment_factor,
        volume=payload.volume,
        source=payload.source,
    )
    await service.upsert_benchmark(benchmark_payload)
    return {"status": "ok"}


@router.get(
    "/benchmarks/{benchmark_type}",
    response_model=BenchmarkSeriesResponse,
)
async def get_benchmark_series(
    benchmark_type: BenchmarkType,
    _: CurrentUser,
    service: Annotated[MarketIntegrationService, Depends(get_market_integration_service)],
    start_date: date = Query(...),
    end_date: date = Query(...),
    adjusted: bool = Query(True),
) -> BenchmarkSeriesResponse:
    """Return daily benchmark time-series for chart widgets."""

    rows = await service.get_benchmark_series(
        benchmark_type=benchmark_type,
        start_date=start_date,
        end_date=end_date,
        adjusted=adjusted,
    )

    return BenchmarkSeriesResponse(
        benchmark_type=benchmark_type,
        adjusted=adjusted,
        series=[
            BenchmarkSeriesPoint(date=item[0], value=item[1])
            for item in rows
        ],
    )


@router.get(
    "/health",
    response_model=ProviderHealthResponse,
)
async def check_provider_health(
    _: CurrentUser,
    service: Annotated[MarketIntegrationService, Depends(get_market_integration_service)],
) -> ProviderHealthResponse:
    """Check health status of the market data provider.

    Returns provider connectivity status, latency, and circuit breaker state.
    Useful for monitoring and debugging sync issues.
    """
    health = await service.check_provider_health()
    return ProviderHealthResponse(
        provider_name=health.provider_name,
        status=health.status.value,
        latency_ms=health.latency_ms,
        last_success_at=health.last_success_at.isoformat() if health.last_success_at else None,
        error_message=health.error_message,
        details=health.details,
    )
