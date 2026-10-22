"""Market API endpoints for Flutter frontend consumption.

Provides stable, well-typed APIs for:
  - Live market snapshots (single and batch)
  - Historical price data
  - Market status and freshness metadata
  - Index snapshots
  - Sync triggers (admin)

Design Principles:
  - All responses use snake_case with camelCase aliases for Flutter
  - Decimal values returned as strings for precision
  - Freshness metadata included where useful
  - Proper HTTP status codes for all error cases
  - No raw provider payload leakage
"""

from __future__ import annotations

from datetime import UTC, date, datetime
import logging
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Query, status

from app.core import market_cache
from app.core.config import settings
from app.core.deps import CurrentUser, get_market_integration_service, get_market_read_service
from app.repositories.market_data import MarketDataRepository
from app.schemas.market_api import (
    IndexSnapshotResponse,
    LiveMarketBatchResponse,
    LiveMarketSnapshotResponse,
    MarketOverviewResponse,
    MarketIndicesResponse,
    MarketStatusResponse,
    MarketWatchResponse,
    PriceBarResponse,
    SyncTriggerResponse,
    SymbolHistoryResponse,
)
from app.services.market_integration import MarketIntegrationService
from app.services.market_overview_service import (
    as_datetime as _as_datetime,
    build_market_overview_response as _overview_response,
    calculate_freshness as _calculate_freshness,
    market_metadata as _market_metadata,
    overview_field as _overview_field,
)
from app.services.market_provider import MarketOverview
from app.services.market_read_service import MarketReadService
from app.services.tehran_market_calendar import TEHRAN_TZ, get_market_session
from app.core.database import async_session_factory

router = APIRouter()
logger = logging.getLogger("market_api")


# ═══════════════════════════════════════════════════════════════
# Helper Functions
# ═══════════════════════════════════════════════════════════════

def _is_market_session() -> bool:
    return get_market_session().is_market_open


def _empty_index_response(index_code: str, name: str | None = None) -> IndexSnapshotResponse:
    return IndexSnapshotResponse(
        index_code=index_code,
        name=name or index_code,
        last_value="0",
        change_value="0",
        change_percent="0",
        open_value="0",
        high_value="0",
        low_value="0",
        volume=0,
        fetched_at=None,
        source="UNKNOWN",
    )


def _index_response_from_cache(
    *,
    index_code: str,
    cached: dict | None,
    fallback_name: str | None = None,
) -> IndexSnapshotResponse:
    if cached is None:
        return _empty_index_response(index_code, fallback_name)

    return IndexSnapshotResponse(
        index_code=cached.get("index_code", index_code),
        name=cached.get("name", fallback_name or index_code),
        last_value=str(cached.get("last_value", "0")),
        change_value=str(cached.get("change_value", "0")),
        change_percent=str(cached.get("change_percent", "0")),
        open_value=str(cached.get("open_value", "0")),
        high_value=str(cached.get("high_value", "0")),
        low_value=str(cached.get("low_value", "0")),
        volume=int(cached.get("volume", 0)),
        fetched_at=cached.get("fetched_at").isoformat() if cached.get("fetched_at") else None,
        source=cached.get("source", "UNKNOWN"),
    )


def _index_response_from_snapshot(snapshot, fallback_name: str | None = None) -> IndexSnapshotResponse:
    return IndexSnapshotResponse(
        index_code=snapshot.index_code,
        name=snapshot.name or fallback_name or snapshot.index_code,
        last_value=str(snapshot.last_value),
        change_value=str(snapshot.change_value),
        change_percent=str(snapshot.change_percent),
        open_value=str(snapshot.open_value),
        high_value=str(snapshot.high_value),
        low_value=str(snapshot.low_value),
        volume=int(snapshot.volume or 0),
        fetched_at=snapshot.fetched_at.isoformat() if snapshot.fetched_at else None,
        source=getattr(snapshot, "source", "TSETMC"),
    )


def _index_response_from_normalized(index, fallback_name: str | None = None) -> IndexSnapshotResponse:
    value = getattr(index, "value", None)
    change = getattr(index, "change", None)
    change_percent = getattr(index, "change_percent", None)
    event_time = getattr(index, "event_time", None)
    return IndexSnapshotResponse(
        index_code=getattr(index, "index_code", ""),
        name=getattr(index, "name", None) or fallback_name or getattr(index, "index_code", ""),
        last_value=str(value if value is not None else "0"),
        change_value=str(change if change is not None else "0"),
        change_percent=str(change_percent if change_percent is not None else "0"),
        open_value=str(value if value is not None else "0"),
        high_value=str(value if value is not None else "0"),
        low_value=str(value if value is not None else "0"),
        volume=0,
        fetched_at=event_time.isoformat() if event_time else None,
        source=getattr(index, "source", "UNKNOWN"),
    )


async def _load_latest_overview() -> MarketOverview | dict | None:
    cached = await market_cache.get_normalized_market_overview()
    if cached is not None:
        return cached
    async with async_session_factory() as db:
        repo = MarketDataRepository(db)
        item = await repo.get_latest_market_overview()
    if item is not None:
        await market_cache.cache_normalized_market_overview(item)
        return item

    # Keep the API usable when Celery/beat has not run yet (fresh installs,
    # worker restarts). The successful result is persisted, so this is only a
    # cold-start request and not a provider call on every dashboard refresh.
    async with async_session_factory() as db:
        service = MarketIntegrationService(repository=MarketDataRepository(db))
        try:
            return await service.sync_market_summary()
        except Exception as exc:
            logger.warning("market.overview.cold_start_sync_failed error=%s", exc)
            return None


def _live_response_from_quote(quote) -> LiveMarketSnapshotResponse:
    event_time = getattr(quote, "event_time", None) or getattr(quote, "received_at", None)
    status_value = getattr(quote, "status", "UNKNOWN")
    if hasattr(status_value, "value"):
        status_value = status_value.value
    closing_price = getattr(quote, "closing_price", None)
    last_price = getattr(quote, "last_price", None)
    return LiveMarketSnapshotResponse(
        ins_code=getattr(quote, "instrument_id", ""),
        ticker=getattr(quote, "symbol", ""),
        close_price=str(closing_price if closing_price is not None else last_price or "0"),
        last_trade_price=str(last_price if last_price is not None else closing_price or "0"),
        last_price=str(last_price if last_price is not None else closing_price or "0"),
        closing_price=str(closing_price if closing_price is not None else last_price or "0"),
        price_change=None,
        price_change_percent=None,
        last_updated_at=event_time.isoformat() if event_time else None,
        open_price=str(getattr(quote, "first_price", None) or "0"),
        high_price=str(getattr(quote, "high_price", None) or "0"),
        low_price=str(getattr(quote, "low_price", None) or "0"),
        volume=int(getattr(quote, "volume", 0) or 0),
        state=str(status_value),
        has_corporate_action=False,
        fetched_at=event_time.isoformat() if event_time else None,
    )


# ═══════════════════════════════════════════════════════════════
# Live Market Endpoints
# ═══════════════════════════════════════════════════════════════

@router.get(
    "/live",
    response_model=LiveMarketSnapshotResponse,
    summary="Get live market snapshot for a symbol",
    description="Returns the latest market data for a single instrument from Redis cache.",
)
async def get_live_market(
    _: CurrentUser,
    ins_code: str = Query(..., alias="insCode", description="TSETMC instrument code"),
) -> LiveMarketSnapshotResponse:
    """Get live market snapshot for a single instrument.

    Returns cached data from Redis (TTL: 60s). If cache miss, returns 404.
    """
    quote_cached = await market_cache.get_market_quote(ins_code)
    if quote_cached is not None:
        response = _live_response_from_quote(type("CachedQuote", (), quote_cached))
        fetched_at = quote_cached.get("event_time") or quote_cached.get("received_at")
        if isinstance(fetched_at, datetime):
            seconds, is_stale = _calculate_freshness(fetched_at)
            response.is_fresh = not is_stale
        return response

    cached = await market_cache.get_live_snapshot(ins_code)
    if cached is None:
        async with async_session_factory() as db:
            repo = MarketDataRepository(db)
            quote = await repo.get_latest_quote(ins_code)
        if quote is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"No live data available for instrument {ins_code}",
            )
        return _live_response_from_quote(quote)

    response = LiveMarketSnapshotResponse.from_dict(cached)

    # Calculate freshness
    fetched_at = cached.get("fetched_at")
    if isinstance(fetched_at, datetime):
        seconds, is_stale = _calculate_freshness(fetched_at)
        response.is_fresh = not is_stale

    return response


@router.get(
    "/live/batch",
    response_model=LiveMarketBatchResponse,
    summary="Get live market snapshots for multiple symbols",
    description="Returns latest market data for multiple instruments.",
)
async def get_live_market_batch(
    _: CurrentUser,
    ins_codes: str = Query(..., alias="insCodes", description="Comma-separated instrument codes"),
) -> LiveMarketBatchResponse:
    """Get live market snapshots for multiple instruments.

    Accepts comma-separated ins_codes. Returns cached data from Redis.
    """
    codes = [c.strip() for c in ins_codes.split(",") if c.strip()]
    if not codes:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="No valid instrument codes provided",
        )

    if len(codes) > 50:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Maximum 50 instruments per request",
        )

    snapshots = []
    for code in codes:
        quote_cached = await market_cache.get_market_quote(code)
        if quote_cached is not None:
            snapshots.append(_live_response_from_quote(type("CachedQuote", (), quote_cached)))
            continue
        cached = await market_cache.get_live_snapshot(code)
        if cached is not None:
            snapshots.append(LiveMarketSnapshotResponse.from_dict(cached))
            continue
        async with async_session_factory() as db:
            repo = MarketDataRepository(db)
            quote = await repo.get_latest_quote(code)
        if quote is not None:
            snapshots.append(_live_response_from_quote(quote))

    return LiveMarketBatchResponse(
        snapshots=snapshots,
        count=len(snapshots),
        fetched_at=datetime.now(UTC).isoformat(),
    )


@router.get(
    "/watch",
    response_model=MarketWatchResponse,
    summary="Get latest market-watch snapshot",
    description="Returns paginated normalized latest quotes for market-watch UI.",
)
async def get_market_watch(
    _: CurrentUser,
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=100, ge=1, le=500),
    compact: bool = Query(default=False),
    service: MarketReadService = Depends(get_market_read_service),
) -> MarketWatchResponse:
    return await service.market_watch(page=page, page_size=page_size, compact=compact)


# ═══════════════════════════════════════════════════════════════
# Symbol History Endpoints
# ═══════════════════════════════════════════════════════════════

@router.get(
    "/symbol/{symbol}/history",
    response_model=SymbolHistoryResponse,
    summary="Get historical price data for a symbol",
    description="Returns OHLCV price history from database.",
)
async def get_symbol_history(
    _: CurrentUser,
    symbol: str,
    start_date: date = Query(..., alias="startDate", description="Start date (YYYY-MM-DD)"),
    end_date: date = Query(..., alias="endDate", description="End date (YYYY-MM-DD)"),
) -> SymbolHistoryResponse:
    """Get historical price data for a symbol.

    Returns price bars from database. Maximum 365 days range.
    """
    # Validate date range
    if start_date > end_date:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="startDate must be before endDate",
        )

    max_days = 365
    if (end_date - start_date).days > max_days:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Maximum date range is {max_days} days",
        )

    # Look up asset by ticker symbol and prefer persisted history. Do not call
    # TSETMC with a blank instrument code; it redirects to an invalid payload.
    async with async_session_factory() as db:
        repo = MarketDataRepository(db)
        from sqlalchemy import select
        from app.models.asset import Asset

        result = await db.execute(
            select(Asset).where(Asset.ticker_symbol == symbol).limit(1)
        )
        asset = result.scalar_one_or_none()

        if asset is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Asset with ticker {symbol} not found",
            )

        bars = await repo.get_symbol_history(
            asset_id=asset.id,
            start_date=start_date,
            end_date=end_date,
        )

    # Convert to response schema
    bar_responses = [
        PriceBarResponse(
            date=bar.date.isoformat(),
            open_price=str(bar.open_price),
            high_price=str(bar.high_price),
            low_price=str(bar.low_price),
            close_price=str(bar.close_price),
            adjusted_close=str(bar.adjusted_close),
            volume=bar.volume,
        )
        for bar in bars
    ]

    return SymbolHistoryResponse(
        asset_id=str(asset.id),
        ticker=symbol,
        bars=bar_responses,
        count=len(bar_responses),
        start_date=start_date.isoformat(),
        end_date=end_date.isoformat(),
    )


# ═══════════════════════════════════════════════════════════════
# Market Status Endpoints
# ═══════════════════════════════════════════════════════════════

@router.get(
    "/status",
    response_model=MarketStatusResponse,
    summary="Get market status and freshness metadata",
    description="Returns provider health, sync status, and data freshness information.",
)
async def get_market_status(
    _: CurrentUser,
) -> MarketStatusResponse:
    """Get market status and freshness metadata.

    Returns:
        - Provider health status
        - Last sync timestamp
        - Sync success/failure counts
        - Market session status
        - Data freshness metrics
    """
    # Get sync status from Redis
    sync_status = await market_cache.get_sync_status()

    # Calculate freshness
    last_sync_at = None
    data_freshness_seconds = None
    is_stale = True

    if sync_status and sync_status.get("last_sync_at"):
        try:
            last_sync_at = sync_status["last_sync_at"]
            last_sync_dt = datetime.fromisoformat(last_sync_at)
            data_freshness_seconds, is_stale = _calculate_freshness(last_sync_dt)
        except (ValueError, TypeError):
            pass

    now = datetime.now(UTC)
    session = get_market_session(now)
    overview = await _load_latest_overview()
    metadata = _market_metadata(overview, now=now) if overview is not None else {
        "is_current_session": False,
        "data_quality_status": "unavailable",
        "price_info_timestamp": None,
        "server_received_at": None,
    }

    if overview is not None:
        data_freshness_seconds, _ = _calculate_freshness(metadata["price_info_timestamp"])
        is_stale = metadata["data_quality_status"] != "current"

    return MarketStatusResponse(
        provider_status=sync_status.get("provider_status", "unknown") if sync_status else "unknown",
        last_sync_at=last_sync_at,
        synced_assets=sync_status.get("synced_assets", 0) if sync_status else 0,
        failed_assets=sync_status.get("failed_assets", 0) if sync_status else 0,
        is_market_open=session.is_market_open,
        is_trading_day=session.is_trading_day,
        data_freshness_seconds=data_freshness_seconds,
        is_stale=is_stale,
        checked_at=now.isoformat(),
        market_status=session.market_status,
        is_current_session=metadata["is_current_session"],
        price_info_timestamp=(
            metadata["price_info_timestamp"].isoformat()
            if metadata["price_info_timestamp"]
            else None
        ),
        server_received_at=(
            metadata["server_received_at"].isoformat()
            if metadata["server_received_at"]
            else None
        ),
        source=str(_overview_field(overview, "source", "UNKNOWN")) if overview else "UNKNOWN",
        data_quality_status=metadata["data_quality_status"],
    )


# ═══════════════════════════════════════════════════════════════
# Index Snapshot Endpoints
# ═══════════════════════════════════════════════════════════════

@router.get(
    "/overview",
    response_model=MarketOverviewResponse,
    summary="Get market overview",
    description="Returns dashboard-ready TSETMC overview indexes: شاخص کل and شاخص هم‌وزن.",
)
async def get_market_overview(
    _: CurrentUser,
) -> MarketOverviewResponse:
    overview = await _load_latest_overview()
    if overview is None:
        raise HTTPException(status_code=503, detail="Market overview is not available")
    return _overview_response(overview)


@router.get(
    "/indices",
    response_model=MarketIndicesResponse,
    summary="Get latest market indices",
)
async def get_market_indices(
    _: CurrentUser,
) -> MarketIndicesResponse:
    indices = await market_cache.get_market_indices()
    if indices is None:
        async with async_session_factory() as db:
            repo = MarketDataRepository(db)
            db_indices = await repo.get_indices_latest()
        indices = db_indices
        if db_indices:
            await market_cache.cache_market_indices(db_indices)

    session = get_market_session()
    rows = [
        _index_response_from_normalized(
            type("CachedIndex", (), item) if isinstance(item, dict) else item,
        )
        for item in (indices or [])
    ]
    response_times = [
        parsed
        for row in rows
        if row.fetched_at and (parsed := _as_datetime(row.fetched_at)) is not None
    ]
    latest = max(response_times, default=None)
    is_current = bool(
        session.is_market_open
        and latest is not None
        and latest.astimezone(TEHRAN_TZ).date() == session.session_date
    )
    _, stale = _calculate_freshness(latest)
    quality = "unavailable" if latest is None else ("current" if is_current and not stale else "stale")
    return MarketIndicesResponse(
        indices=rows,
        price_info_timestamp=latest.isoformat() if latest else None,
        server_received_at=datetime.now(UTC).isoformat(),
        market_status=session.market_status,
        is_current_session=is_current,
        source=rows[0].source if rows else "UNKNOWN",
        data_quality_status=quality,
    )


@router.get(
    "/index/{index_code}",
    response_model=IndexSnapshotResponse,
    summary="Get market index snapshot",
    description="Returns latest index data from Redis cache.",
)
async def get_index_snapshot(
    _: CurrentUser,
    index_code: str,
) -> IndexSnapshotResponse:
    """Get market index snapshot (e.g., TEDPIX, TEP10).

    Returns cached data from Redis (TTL: 60s).
    """
    cached = await market_cache.get_index_snapshot(index_code)
    if cached is not None:
        return _index_response_from_cache(index_code=index_code, cached=cached)
    normalized_cached = await market_cache.get_market_indices()
    if normalized_cached:
        for item in normalized_cached:
            if item["index_code"] == index_code:
                return _index_response_from_normalized(type("CachedIndex", (), item))
    async with async_session_factory() as db:
        repo = MarketDataRepository(db)
        db_indices = await repo.get_indices_latest()
    for item in db_indices:
        if item.index_code == index_code:
            await market_cache.cache_market_indices(db_indices)
            return _index_response_from_normalized(item)
    return _index_response_from_cache(index_code=index_code, cached=None)


# ═══════════════════════════════════════════════════════════════
# Admin/Sync Trigger Endpoints
# ═══════════════════════════════════════════════════════════════

@router.post(
    "/sync/live",
    response_model=SyncTriggerResponse,
    status_code=status.HTTP_202_ACCEPTED,
    summary="Trigger live market sync (admin)",
    description="Enqueues a Celery task to sync live market prices.",
)
async def trigger_live_sync(
    _: CurrentUser,
) -> SyncTriggerResponse:
    """Trigger live market sync (admin only).

    Enqueues a Celery task that syncs all active TSETMC assets.
    """
    from app.tasks.market_tasks import sync_tsetmc_live_prices

    task = sync_tsetmc_live_prices.delay()
    return SyncTriggerResponse(
        task_id=task.id,
        status="queued",
        message="Live market sync task queued",
    )


@router.post(
    "/sync/benchmarks",
    response_model=SyncTriggerResponse,
    status_code=status.HTTP_202_ACCEPTED,
    summary="Trigger benchmark sync (admin)",
    description="Enqueues a Celery task to sync daily benchmarks.",
)
async def trigger_benchmark_sync(
    _: CurrentUser,
) -> SyncTriggerResponse:
    """Trigger benchmark sync (admin only).

    Enqueues a Celery task that syncs Gold, USD, and TEDPIX benchmarks.
    """
    from app.tasks.market_tasks import sync_daily_benchmarks

    task = sync_daily_benchmarks.delay()
    return SyncTriggerResponse(
        task_id=task.id,
        status="queued",
        message="Benchmark sync task queued",
    )


@router.post(
    "/sync/health",
    response_model=SyncTriggerResponse,
    status_code=status.HTTP_202_ACCEPTED,
    summary="Trigger provider health check (admin)",
    description="Enqueues a Celery task to check provider health.",
)
async def trigger_health_check(
    _: CurrentUser,
) -> SyncTriggerResponse:
    """Trigger provider health check (admin only).

    Enqueues a Celery task that checks TSETMC provider connectivity.
    """
    from app.tasks.market_tasks import check_provider_health

    task = check_provider_health.delay()
    return SyncTriggerResponse(
        task_id=task.id,
        status="queued",
        message="Health check task queued",
    )
