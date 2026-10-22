"""FastAPI router for watchlist and alert endpoints.

Provides:
  - Watchlist CRUD operations
  - Alert rule CRUD operations
  - Alert event listing and acknowledgment
  - Alert summary statistics
"""

from __future__ import annotations

import uuid
from decimal import Decimal

from fastapi import APIRouter, Depends, HTTPException, Query, Response, status
from sqlalchemy import select

from app.core.database import get_db
from app.core.deps import CurrentUser
from app.models.asset import Asset
from app.models.market_data import DailyPrice
from app.models.watchlist import AlertEvent, AlertRule, Watchlist, WatchlistItem
from app.repositories.watchlist import WatchlistRepository
from app.schemas.watchlist import (
    AlertEventDTO,
    AlertEventListResponse,
    AlertRuleCreateRequest,
    AlertRuleDTO,
    AlertRuleListResponse,
    AlertRuleUpdateRequest,
    AlertSummaryDTO,
    AlertSummaryResponse,
    WatchlistCreateRequest,
    WatchlistDTO,
    WatchlistListResponse,
    WatchlistSymbolDTO,
    WatchlistSymbolsRequest,
    WatchlistUpdateRequest,
)
from app.services.alert_service import AlertEvaluationService
from sqlalchemy.ext.asyncio import AsyncSession

router = APIRouter(prefix="/watchlist", tags=["Watchlist & Alerts"])


async def _latest_price_row(
    repo: WatchlistRepository,
    asset_id: uuid.UUID,
) -> DailyPrice | None:
    result = await repo.db.execute(
        select(DailyPrice)
        .where(DailyPrice.asset_id == asset_id)
        .order_by(DailyPrice.date.desc())
        .limit(1)
    )
    return result.scalar_one_or_none()


def _decimal_to_float(value: Decimal | int | float | None) -> float | None:
    if value is None:
        return None
    parsed = float(value)
    return parsed if parsed > 0 else None


async def _watchlist_to_dto(
    repo: WatchlistRepository,
    watchlist: Watchlist,
    user_id: uuid.UUID,
) -> WatchlistDTO:
    item_rows = await repo.list_items_for_watchlist(
        watchlist_id=watchlist.id,
        user_id=user_id,
    )
    symbol_dtos = []
    for item, asset in item_rows:
        latest = await _latest_price_row(repo, asset.id)
        current_price = (
            _decimal_to_float(asset.current_price)
            if asset.price_updated_at is not None
            else None
        )
        if current_price is None and latest is not None:
            current_price = _decimal_to_float(latest.adjusted_close)

        previous_close = _decimal_to_float(asset.previous_close_price)
        price_change_pct = None
        if current_price is not None and previous_close is not None:
            price_change_pct = ((current_price - previous_close) / previous_close) * 100

        symbol_dtos.append(
            WatchlistSymbolDTO(
                symbol=asset.ticker_symbol,
                name_fa=asset.name_fa,
                name_en=asset.name_en,
                ins_code=asset.tsetmc_id,
                current_price=current_price,
                price_change_pct=price_change_pct,
                volume=latest.volume if latest is not None else None,
                is_tradeable=asset.is_tradeable,
                added_at=item.added_at,
            )
        )

    return WatchlistDTO(
        id=watchlist.id,
        name=watchlist.name,
        description=watchlist.description,
        symbols=symbol_dtos,
        symbol_count=len(symbol_dtos),
        alert_count=0,
        created_at=watchlist.created_at,
        updated_at=watchlist.updated_at,
    )


async def _alert_symbol(repo: WatchlistRepository, rule: AlertRule) -> str:
    result = await repo.db.execute(
        select(Asset.ticker_symbol)
        .join(WatchlistItem, WatchlistItem.asset_id == Asset.id)
        .where(WatchlistItem.id == rule.watchlist_item_id)
        .limit(1)
    )
    return result.scalar_one_or_none() or ""


async def _alert_rule_to_dto(
    repo: WatchlistRepository,
    rule: AlertRule,
) -> AlertRuleDTO:
    return AlertRuleDTO(
        id=rule.id,
        symbol=await _alert_symbol(repo, rule),
        alert_type=rule.alert_type,
        threshold=rule.threshold,
        threshold_pct=rule.threshold_pct,
        status=rule.status,
        frequency=rule.frequency,
        notification_channels=rule.notification_channels or [],
        message_template=rule.message_template,
        expires_at=rule.expires_at,
        created_at=rule.created_at,
        updated_at=rule.updated_at,
        last_triggered_at=rule.last_triggered_at,
        trigger_count=rule.trigger_count,
    )


async def _event_to_dto(
    repo: WatchlistRepository,
    event: AlertEvent,
) -> AlertEventDTO:
    result = await repo.db.execute(
        select(AlertRule, Asset.ticker_symbol)
        .join(WatchlistItem, WatchlistItem.id == AlertRule.watchlist_item_id)
        .join(Asset, Asset.id == WatchlistItem.asset_id)
        .where(AlertRule.id == event.alert_id)
        .limit(1)
    )
    row = result.first()
    rule = row[0] if row else None
    symbol = row[1] if row else ""

    return AlertEventDTO(
        id=event.id,
        alert_id=event.alert_id,
        symbol=symbol,
        alert_type=rule.alert_type if rule is not None else "PRICE_ABOVE",
        triggered_at=event.triggered_at,
        price_at_trigger=event.price_at_trigger,
        threshold_value=event.threshold_value,
        change_pct=event.change_pct,
        notification_sent=event.notification_sent,
        notification_channels=event.notification_channels or [],
        acknowledged_at=event.acknowledged_at,
    )


# ═══════════════════════════════════════════════════════════════
# Watchlist Endpoints
# ═══════════════════════════════════════════════════════════════

@router.get(
    "",
    response_model=WatchlistListResponse,
    summary="List user watchlists",
    description="Returns all watchlists for the current user.",
)
async def list_watchlists(
    current_user: CurrentUser,
    db: AsyncSession = Depends(get_db),
) -> WatchlistListResponse:
    """List all watchlists for the current user."""
    repo = WatchlistRepository(db)
    watchlists = await repo.list_watchlists(user_id=current_user.id)

    return WatchlistListResponse(
        watchlists=[
            await _watchlist_to_dto(repo, watchlist, current_user.id)
            for watchlist in watchlists
        ],
        total_count=len(watchlists),
    )


@router.post(
    "",
    response_model=WatchlistDTO,
    status_code=status.HTTP_201_CREATED,
    summary="Create a new watchlist",
    description="Creates a new watchlist with optional initial symbols.",
)
async def create_watchlist(
    request: WatchlistCreateRequest,
    current_user: CurrentUser,
    db: AsyncSession = Depends(get_db),
) -> WatchlistDTO:
    """Create a new watchlist."""
    repo = WatchlistRepository(db)

    try:
        watchlist = await repo.create_watchlist(
            user_id=current_user.id,
            name=request.name,
            description=request.description,
        )

        if request.symbols:
            await repo.sync_symbols(
                watchlist_id=watchlist.id,
                user_id=current_user.id,
                add_symbols=request.symbols,
                remove_symbols=[],
            )
    except RuntimeError as exc:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=str(exc),
        ) from exc

    await repo.commit()

    watchlist = await repo.get_watchlist(
        watchlist_id=watchlist.id,
        user_id=current_user.id,
    )
    return await _watchlist_to_dto(repo, watchlist, current_user.id)


@router.get(
    "/{watchlist_id:uuid}",
    response_model=WatchlistDTO,
    summary="Get watchlist details",
    description="Returns detailed information about a specific watchlist.",
)
async def get_watchlist(
    watchlist_id: uuid.UUID,
    current_user: CurrentUser,
    db: AsyncSession = Depends(get_db),
) -> WatchlistDTO:
    """Get a specific watchlist."""
    repo = WatchlistRepository(db)
    watchlist = await repo.get_watchlist(
        watchlist_id=watchlist_id,
        user_id=current_user.id,
    )

    if watchlist is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Watchlist not found",
        )

    return await _watchlist_to_dto(repo, watchlist, current_user.id)


@router.put(
    "/{watchlist_id:uuid}",
    response_model=WatchlistDTO,
    summary="Update watchlist",
    description="Updates watchlist name and description.",
)
async def update_watchlist(
    watchlist_id: uuid.UUID,
    request: WatchlistUpdateRequest,
    current_user: CurrentUser,
    db: AsyncSession = Depends(get_db),
) -> WatchlistDTO:
    """Update a watchlist."""
    repo = WatchlistRepository(db)
    watchlist = await repo.update_watchlist(
        watchlist_id=watchlist_id,
        user_id=current_user.id,
        name=request.name,
        description=request.description,
    )

    if watchlist is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Watchlist not found",
        )

    await repo.commit()

    return await _watchlist_to_dto(repo, watchlist, current_user.id)


@router.patch(
    "/{watchlist_id:uuid}/symbols",
    response_model=WatchlistDTO,
    summary="Update watchlist symbols",
    description="Adds and removes symbols in a watchlist.",
)
async def update_watchlist_symbols(
    watchlist_id: uuid.UUID,
    request: WatchlistSymbolsRequest,
    current_user: CurrentUser,
    db: AsyncSession = Depends(get_db),
) -> WatchlistDTO:
    """Add and remove symbols in a watchlist."""
    repo = WatchlistRepository(db)
    try:
        watchlist = await repo.sync_symbols(
            watchlist_id=watchlist_id,
            user_id=current_user.id,
            add_symbols=request.add_symbols,
            remove_symbols=request.remove_symbols,
        )
    except RuntimeError as exc:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=str(exc),
        ) from exc

    if watchlist is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Watchlist not found",
        )

    await repo.commit()
    return await _watchlist_to_dto(repo, watchlist, current_user.id)


@router.delete(
    "/{watchlist_id:uuid}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Delete watchlist",
    description="Deletes a watchlist and all its items/alerts.",
)
async def delete_watchlist(
    watchlist_id: uuid.UUID,
    current_user: CurrentUser,
    db: AsyncSession = Depends(get_db),
) -> Response:
    """Delete a watchlist."""
    repo = WatchlistRepository(db)
    deleted = await repo.delete_watchlist(
        watchlist_id=watchlist_id,
        user_id=current_user.id,
    )

    if not deleted:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Watchlist not found",
        )

    await repo.commit()
    return Response(status_code=status.HTTP_204_NO_CONTENT)


# ═══════════════════════════════════════════════════════════════
# Alert Rule Endpoints
# ═══════════════════════════════════════════════════════════════

@router.get(
    "/alerts",
    response_model=AlertRuleListResponse,
    summary="List alert rules",
    description="Returns all alert rules for the current user.",
)
async def list_alert_rules(
    current_user: CurrentUser,
    status_filter: str | None = Query(default=None, alias="status"),
    db: AsyncSession = Depends(get_db),
) -> AlertRuleListResponse:
    """List alert rules."""
    repo = WatchlistRepository(db)
    rules = await repo.list_alert_rules(
        user_id=current_user.id,
        status=status_filter,
    )

    active_count = sum(1 for r in rules if r.status == "ACTIVE")

    return AlertRuleListResponse(
        alerts=[
            await _alert_rule_to_dto(repo, rule)
            for rule in rules
        ],
        total_count=len(rules),
        active_count=active_count,
    )


@router.post(
    "/alerts",
    response_model=AlertRuleDTO,
    status_code=status.HTTP_201_CREATED,
    summary="Create alert rule",
    description="Creates a new alert rule for a watchlist item.",
)
async def create_alert_rule(
    request: AlertRuleCreateRequest,
    current_user: CurrentUser,
    db: AsyncSession = Depends(get_db),
) -> AlertRuleDTO:
    """Create an alert rule."""
    from app.repositories.returns_read import ReturnsReadRepository

    repo = WatchlistRepository(db)
    returns_repo = ReturnsReadRepository(db)

    # Resolve symbol to asset
    asset = await returns_repo.get_asset_by_ticker(request.symbol)
    if asset is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Asset with ticker {request.symbol} not found",
        )

    # Find or create watchlist item
    # For now, use the first watchlist or create a default one
    watchlists = await repo.list_watchlists(user_id=current_user.id)
    if not watchlists:
        # Create a default watchlist
        try:
            watchlist = await repo.create_watchlist(
                user_id=current_user.id,
                name="پیش‌فرض",
                description="لیست پیش‌فرض",
            )
        except RuntimeError as exc:
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail=str(exc),
            ) from exc
        await repo.commit()
        watchlists = [watchlist]

    watchlist_id = watchlists[0].id

    # Check if item already exists
    existing_item = await repo.get_item(
        watchlist_id=watchlist_id,
        asset_id=asset.id,
    )

    if existing_item is None:
        # Add item to watchlist
        try:
            item = await repo.add_item(
                watchlist_id=watchlist_id,
                asset_id=asset.id,
            )
        except RuntimeError as exc:
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail=str(exc),
            ) from exc
        watchlist_item_id = item.id
    else:
        watchlist_item_id = existing_item.id

    # Create alert rule
    try:
        rule = await repo.create_alert_rule(
            user_id=current_user.id,
            watchlist_item_id=watchlist_item_id,
            alert_type=request.alert_type.value,
            threshold=request.threshold,
            threshold_pct=request.threshold_pct,
            frequency=request.frequency.value,
            notification_channels=[ch.value for ch in request.notification_channels],
            message_template=request.message_template,
            expires_at=request.expires_at,
        )
    except RuntimeError as exc:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=str(exc),
        ) from exc

    await repo.commit()

    return await _alert_rule_to_dto(repo, rule)


@router.put(
    "/alerts/{rule_id}",
    response_model=AlertRuleDTO,
    summary="Update alert rule",
    description="Updates an alert rule's threshold, status, or settings.",
)
async def update_alert_rule(
    rule_id: uuid.UUID,
    request: AlertRuleUpdateRequest,
    current_user: CurrentUser,
    db: AsyncSession = Depends(get_db),
) -> AlertRuleDTO:
    """Update an alert rule."""
    repo = WatchlistRepository(db)

    rule = await repo.update_alert_rule(
        rule_id=rule_id,
        user_id=current_user.id,
        threshold=request.threshold,
        threshold_pct=request.threshold_pct,
        status=request.status.value if request.status else None,
        frequency=request.frequency.value if request.frequency else None,
        notification_channels=[ch.value for ch in request.notification_channels] if request.notification_channels else None,
        message_template=request.message_template,
        expires_at=request.expires_at,
    )

    if rule is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Alert rule not found",
        )

    await repo.commit()

    return await _alert_rule_to_dto(repo, rule)


@router.delete(
    "/alerts/{rule_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Delete alert rule",
    description="Deletes an alert rule.",
)
async def delete_alert_rule(
    rule_id: uuid.UUID,
    current_user: CurrentUser,
    db: AsyncSession = Depends(get_db),
) -> Response:
    """Delete an alert rule."""
    repo = WatchlistRepository(db)
    deleted = await repo.delete_alert_rule(
        rule_id=rule_id,
        user_id=current_user.id,
    )

    if not deleted:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Alert rule not found",
        )

    await repo.commit()
    return Response(status_code=status.HTTP_204_NO_CONTENT)


# ═══════════════════════════════════════════════════════════════
# Alert Event Endpoints
# ═══════════════════════════════════════════════════════════════

@router.get(
    "/events",
    response_model=AlertEventListResponse,
    summary="List alert events",
    description="Returns triggered alert events for the current user.",
)
async def list_alert_events(
    current_user: CurrentUser,
    alert_id: uuid.UUID | None = Query(default=None),
    limit: int = Query(default=50, le=100),
    db: AsyncSession = Depends(get_db),
) -> AlertEventListResponse:
    """List alert events."""
    repo = WatchlistRepository(db)
    events = await repo.list_alert_events(
        user_id=current_user.id,
        alert_id=alert_id,
        limit=limit,
    )

    unacknowledged = sum(1 for e in events if e.acknowledged_at is None)

    return AlertEventListResponse(
        events=[
            await _event_to_dto(repo, event)
            for event in events
        ],
        total_count=len(events),
        unacknowledged_count=unacknowledged,
    )


@router.post(
    "/events/{event_id}/acknowledge",
    status_code=status.HTTP_200_OK,
    summary="Acknowledge alert event",
    description="Marks an alert event as acknowledged.",
)
async def acknowledge_alert_event(
    event_id: uuid.UUID,
    current_user: CurrentUser,
    db: AsyncSession = Depends(get_db),
) -> dict:
    """Acknowledge an alert event."""
    repo = WatchlistRepository(db)
    acknowledged = await repo.acknowledge_alert_event(
        event_id=event_id,
        user_id=current_user.id,
    )

    if not acknowledged:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Alert event not found",
        )

    await repo.commit()

    return {"status": "acknowledged"}


# ═══════════════════════════════════════════════════════════════
# Alert Summary Endpoint
# ═══════════════════════════════════════════════════════════════

@router.get(
    "/summary",
    response_model=AlertSummaryResponse,
    summary="Get alert summary",
    description="Returns alert statistics and recent events.",
)
async def get_alert_summary(
    current_user: CurrentUser,
    db: AsyncSession = Depends(get_db),
) -> AlertSummaryResponse:
    """Get alert summary statistics."""
    repo = WatchlistRepository(db)
    summary_data = await repo.get_alert_summary(user_id=current_user.id)

    recent_events = await repo.list_alert_events(
        user_id=current_user.id,
        limit=10,
    )

    return AlertSummaryResponse(
        summary=AlertSummaryDTO(
            total_active_alerts=summary_data["total_active_alerts"],
            total_triggered_today=summary_data["total_triggered_today"],
            total_unacknowledged=summary_data["total_unacknowledged"],
        ),
        recent_events=[
            await _event_to_dto(repo, event)
            for event in recent_events
        ],
    )
