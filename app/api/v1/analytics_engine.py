"""CQRS read-side analytics router with Redis-backed caching and SSE streams."""

from __future__ import annotations

from dataclasses import asdict
import json
import logging
import time
import uuid
from datetime import UTC, datetime, timedelta
from typing import Annotated, Any

from fastapi import APIRouter, Depends, Query, Request
from fastapi.responses import JSONResponse, StreamingResponse

from app.core.monitoring import record_degraded_sse
from app.core.deps import CurrentUser, get_read_handler_bundle
from app.cqrs.read_handlers import (
    AnalyticsReportQuery,
    OhlcvQuery,
    ReadHandlerBundle,
    ReadModelProblem,
)
from app.models.enums import InventoryAccountingMethod
from app.schemas.analytics_engine import AnalyticsResponse, OHLCVResponse, ProblemDetails

router = APIRouter(prefix="/analytics-engine", tags=["Analytics Engine"])
logger = logging.getLogger(__name__)

HEARTBEAT_INTERVAL_SECONDS = 15
SSE_HEADERS = {
    "Cache-Control": "no-cache",
    "Connection": "keep-alive",
    "X-Accel-Buffering": "no",
}


def _problem_response(problem: ReadModelProblem) -> JSONResponse:
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


def _default_window_start(days: int = 30) -> datetime:
    return datetime.now(UTC) - timedelta(days=days)


def _ensure_timezone(value: datetime, *, field_name: str, instance: str) -> datetime:
    if value.tzinfo is None or value.utcoffset() is None:
        raise ReadModelProblem(
            status_code=422,
            title="Invalid Datetime",
            detail=f"{field_name} must be timezone-aware (ISO-8601 with offset).",
            instance=instance,
            type_slug="invalid-datetime",
        )
    return value


def _format_sse_event(*, event: str, data: dict[str, Any]) -> str:
    return f"event: {event}\ndata: {json.dumps(data, default=str)}\n\n"


def _validate_window(*, window_start: datetime, window_end: datetime, instance: str) -> None:
    if window_end < window_start:
        raise ReadModelProblem(
            status_code=422,
            title="Invalid Date Window",
            detail="window_end must be greater than or equal to window_start.",
            instance=instance,
            type_slug="invalid-date-window",
        )


async def _stream_from_pubsub(
    *,
    request: Request,
    handlers: ReadHandlerBundle,
    channel: str,
    event_name: str,
    static_payload: dict[str, Any],
) -> Any:
    if handlers.redis_client is None:
        record_degraded_sse(channel=channel)
        logger.warning(
            "Degraded SSE mode activated: redis pub/sub unavailable",
            extra={
                "channel": channel,
                "path": str(request.url.path),
                "event_name": event_name,
            },
        )

        async def degraded_event_generator() -> Any:
            yield _format_sse_event(
                event="ready",
                data={
                    "channel": channel,
                    "connected_at": datetime.now(UTC).isoformat(),
                    "degraded": True,
                    "reason": "redis_pubsub_unavailable",
                    **static_payload,
                },
            )
            while True:
                if await request.is_disconnected():
                    break
                await _sleep_for_heartbeat()
                yield ": keep-alive\n\n"

        return degraded_event_generator()

    pubsub = handlers.redis_client.pubsub()
    await pubsub.subscribe(channel)

    async def event_generator() -> Any:
        last_heartbeat = time.monotonic()
        try:
            yield _format_sse_event(
                event="ready",
                data={
                    "channel": channel,
                    "connected_at": datetime.now(UTC).isoformat(),
                    **static_payload,
                },
            )

            while True:
                if await request.is_disconnected():
                    break

                message = await pubsub.get_message(ignore_subscribe_messages=True, timeout=1.0)
                if message and message.get("type") == "message":
                    payload = message.get("data")
                    if isinstance(payload, bytes):
                        payload = payload.decode("utf-8")

                    if isinstance(payload, str):
                        try:
                            payload = json.loads(payload)
                        except json.JSONDecodeError:
                            payload = {"raw": payload}

                    if not isinstance(payload, dict):
                        payload = {"value": payload}

                    yield _format_sse_event(
                        event=event_name,
                        data={
                            "received_at": datetime.now(UTC).isoformat(),
                            **static_payload,
                            **payload,
                        },
                    )
                    continue

                now = time.monotonic()
                if now - last_heartbeat >= HEARTBEAT_INTERVAL_SECONDS:
                    yield ": keep-alive\n\n"
                    last_heartbeat = now
        finally:
            await pubsub.unsubscribe(channel)
            await pubsub.close()

    return event_generator()


async def _sleep_for_heartbeat() -> None:
    import asyncio
    await asyncio.sleep(HEARTBEAT_INTERVAL_SECONDS)


@router.get(
    "/portfolios/{portfolio_id}/report",
    response_model=AnalyticsResponse,
    responses={
        401: {"model": ProblemDetails, "content": {"application/problem+json": {}}},
        404: {"model": ProblemDetails, "content": {"application/problem+json": {}}},
        422: {"model": ProblemDetails, "content": {"application/problem+json": {}}},
        500: {"model": ProblemDetails, "content": {"application/problem+json": {}}},
    },
)
async def get_portfolio_analytics_report(
    portfolio_id: uuid.UUID,
    current_user: CurrentUser,
    handlers: Annotated[ReadHandlerBundle, Depends(get_read_handler_bundle)],
    window_start: datetime | None = Query(default=None),
    window_end: datetime | None = Query(default=None),
    inventory_method: InventoryAccountingMethod = Query(default=InventoryAccountingMethod.WAC),
    limit: int = Query(default=1000, ge=1, le=10000),
) -> AnalyticsResponse | JSONResponse:
    try:
        resolved_start = _ensure_timezone(
            window_start or _default_window_start(30),
            field_name="window_start",
            instance=f"/analytics-engine/portfolios/{portfolio_id}/report",
        )
        resolved_end = _ensure_timezone(
            window_end or datetime.now(UTC),
            field_name="window_end",
            instance=f"/analytics-engine/portfolios/{portfolio_id}/report",
        )
        _validate_window(
            window_start=resolved_start,
            window_end=resolved_end,
            instance=f"/analytics-engine/portfolios/{portfolio_id}/report",
        )
        query = AnalyticsReportQuery(
            portfolio_id=portfolio_id,
            user_id=current_user.id,
            window_start=resolved_start,
            window_end=resolved_end,
            inventory_method=inventory_method,
            limit=limit,
        )
        return await handlers.analytics_report.handle(query)
    except ReadModelProblem as exc:
        return _problem_response(exc)


@router.get(
    "/assets/{asset_id}/ohlcv",
    response_model=OHLCVResponse,
    responses={
        404: {"model": ProblemDetails, "content": {"application/problem+json": {}}},
        422: {"model": ProblemDetails, "content": {"application/problem+json": {}}},
    },
)
async def get_asset_ohlcv(
    asset_id: uuid.UUID,
    handlers: Annotated[ReadHandlerBundle, Depends(get_read_handler_bundle)],
    window_start: datetime | None = Query(default=None),
    window_end: datetime | None = Query(default=None),
    limit: int = Query(default=5000, ge=1, le=50000),
) -> OHLCVResponse | JSONResponse:
    try:
        resolved_start = _ensure_timezone(
            window_start or _default_window_start(3),
            field_name="window_start",
            instance=f"/analytics-engine/assets/{asset_id}/ohlcv",
        )
        resolved_end = _ensure_timezone(
            window_end or datetime.now(UTC),
            field_name="window_end",
            instance=f"/analytics-engine/assets/{asset_id}/ohlcv",
        )
        _validate_window(
            window_start=resolved_start,
            window_end=resolved_end,
            instance=f"/analytics-engine/assets/{asset_id}/ohlcv",
        )
        return await handlers.asset_ohlcv.handle(
            OhlcvQuery(
                asset_id=asset_id,
                window_start=resolved_start,
                window_end=resolved_end,
                limit=limit,
            )
        )
    except ReadModelProblem as exc:
        return _problem_response(exc)


@router.get(
    "/assets/{asset_id}/ticks/stream",
    response_model=None,
    responses={
        401: {"model": ProblemDetails, "content": {"application/problem+json": {}}},
        404: {"model": ProblemDetails, "content": {"application/problem+json": {}}},
        503: {"model": ProblemDetails, "content": {"application/problem+json": {}}},
    },
)
async def stream_asset_ticks(
    asset_id: uuid.UUID,
    request: Request,
    current_user: CurrentUser,
    handlers: Annotated[ReadHandlerBundle, Depends(get_read_handler_bundle)],
) -> StreamingResponse | JSONResponse:
    try:
        metadata = await handlers.asset_ohlcv.get_asset_metadata(asset_id)
        if metadata is None:
            raise ReadModelProblem(
                status_code=404,
                title="Asset Not Found",
                detail="Asset does not exist or is inactive.",
                instance=str(request.url.path),
                type_slug="asset-not-found",
            )

        stream = await _stream_from_pubsub(
            request=request,
            handlers=handlers,
            channel=f"ticks:{asset_id}",
            event_name="tick",
            static_payload={
                "asset_id": str(asset_id),
                "ticker_symbol": metadata.ticker_symbol,
                "subscriber_user_id": str(current_user.id),
            },
        )
        return StreamingResponse(stream, media_type="text/event-stream", headers=SSE_HEADERS)
    except ReadModelProblem as exc:
        return _problem_response(exc)


@router.get(
    "/portfolios/{portfolio_id}/pnl/stream",
    response_model=None,
    responses={
        401: {"model": ProblemDetails, "content": {"application/problem+json": {}}},
        404: {"model": ProblemDetails, "content": {"application/problem+json": {}}},
        503: {"model": ProblemDetails, "content": {"application/problem+json": {}}},
    },
)
async def stream_portfolio_pnl(
    portfolio_id: uuid.UUID,
    request: Request,
    current_user: CurrentUser,
    handlers: Annotated[ReadHandlerBundle, Depends(get_read_handler_bundle)],
) -> StreamingResponse | JSONResponse:
    try:
        # Enforce ownership on stream subscriptions.
        await handlers.analytics_report.handle(
            AnalyticsReportQuery(
                portfolio_id=portfolio_id,
                user_id=current_user.id,
                window_start=_default_window_start(1),
                window_end=datetime.now(UTC),
                inventory_method=InventoryAccountingMethod.WAC,
                limit=1,
            )
        )

        stream = await _stream_from_pubsub(
            request=request,
            handlers=handlers,
            channel=f"pnl:{portfolio_id}",
            event_name="pnl",
            static_payload={
                "portfolio_id": str(portfolio_id),
                "subscriber_user_id": str(current_user.id),
            },
        )
        return StreamingResponse(stream, media_type="text/event-stream", headers=SSE_HEADERS)
    except ReadModelProblem as exc:
        return _problem_response(exc)
