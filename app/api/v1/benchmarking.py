"""FastAPI router for ultra-low-latency benchmark attribution."""

from __future__ import annotations

from dataclasses import asdict
import logging
import uuid
from datetime import UTC, date, datetime, time
from typing import Annotated, Literal

from fastapi import APIRouter, Depends, Query
from fastapi.responses import JSONResponse

from app.api.responses import ArrowIPCResponse, MessagePackResponse
from app.api.responses.columnar import is_msgpack_available
from app.core.monitoring import record_msgpack_json_fallback
from app.core.deps import CurrentUser, get_advanced_benchmark_service
from app.schemas.benchmarking import (
    BENCHMARK_ALIGNMENT_ARROW_SCHEMA,
    BenchmarkAttributionResponse,
    BenchmarkWindow,
    ProblemDetails,
)
from app.services.advanced_benchmark_service import AdvancedBenchmarkService, BenchmarkingProblem

router = APIRouter(prefix="/benchmarking", tags=["Benchmark Attribution"])
logger = logging.getLogger(__name__)


def _problem_response(problem: BenchmarkingProblem) -> JSONResponse:
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
    "/portfolios/{portfolio_id}/twr-attribution",
    response_model=BenchmarkAttributionResponse,
    responses={
        401: {"model": ProblemDetails, "content": {"application/problem+json": {}}},
        404: {"model": ProblemDetails, "content": {"application/problem+json": {}}},
        422: {"model": ProblemDetails, "content": {"application/problem+json": {}}},
        500: {"model": ProblemDetails, "content": {"application/problem+json": {}}},
    },
)
async def get_portfolio_twr_attribution(
    portfolio_id: uuid.UUID,
    current_user: CurrentUser,
    service: Annotated[AdvancedBenchmarkService, Depends(get_advanced_benchmark_service)],
    window: BenchmarkWindow = Query(default=BenchmarkWindow.ONE_MONTH),
    window_start: date | None = Query(default=None),
    window_end: date | None = Query(default=None),
    response_format: Literal["json", "arrow", "msgpack"] = Query(default="json"),
) -> BenchmarkAttributionResponse | JSONResponse | ArrowIPCResponse | MessagePackResponse:
    """Return aligned true-TWR portfolio attribution versus four market benchmarks."""

    instance = f"/benchmarking/portfolios/{portfolio_id}/twr-attribution"
    try:
        response, frame = await service.get_benchmark_attribution(
            portfolio_id=portfolio_id,
            user_id=current_user.id,
            window=window,
            window_start=window_start,
            window_end=window_end,
            instance=instance,
        )
    except BenchmarkingProblem as exc:
        return _problem_response(exc)

    if response_format == "arrow":
        rows = [
            {
                **row,
                "as_of": datetime.combine(row["as_of"], time.min, tzinfo=UTC),
            }
            for row in frame.to_dicts()
        ]
        return ArrowIPCResponse(
            content={
                "schema": BENCHMARK_ALIGNMENT_ARROW_SCHEMA,
                "rows": rows,
            }
        )

    if response_format == "msgpack":
        if is_msgpack_available():
            return MessagePackResponse(content=response.model_dump(mode="json"))
        record_msgpack_json_fallback(route_key="benchmarking.twr_attribution")
        logger.warning(
            "MessagePack unavailable; falling back to JSON response",
            extra={
                "route": "benchmarking.twr_attribution",
                "portfolio_id": str(portfolio_id),
                "window": window.value,
                "instance": instance,
            },
        )
        return JSONResponse(
            status_code=200,
            content=response.model_dump(mode="json"),
            media_type="application/json",
            headers={"X-Response-Format-Fallback": "json"},
        )

    return response
