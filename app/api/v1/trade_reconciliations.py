"""Authenticated reconciliation lifecycle API."""

from __future__ import annotations

import uuid
from typing import Annotated

from fastapi import APIRouter, Depends, Query, Request, status
from fastapi.responses import JSONResponse
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.deps import CurrentUser
from app.models.enums import ReconciliationStatus
from app.schemas.trade_reconciliation import (
    ManualReconciliationCreate,
    ReconciliationImpactPreview,
    ReconciliationProblem,
    ReconciliationTransitionRequest,
    TradeReconciliationRead,
)
from app.services.trade_reconciliation_api_service import TradeReconciliationApiService
from app.services.trade_reconciliation_service import TradeReconciliationError

router = APIRouter(prefix="/trade-reconciliations", tags=["Trade Reconciliation"])


def get_trade_reconciliation_api_service(
    db: Annotated[AsyncSession, Depends(get_db)],
) -> TradeReconciliationApiService:
    return TradeReconciliationApiService(db)


ReconciliationApi = Annotated[
    TradeReconciliationApiService,
    Depends(get_trade_reconciliation_api_service),
]


def _problem(request: Request, exc: TradeReconciliationError) -> JSONResponse:
    problem = ReconciliationProblem(
        title="Trade reconciliation failed",
        status=exc.status_code,
        detail=exc.detail,
        instance=request.url.path,
        code=exc.code,
    )
    return JSONResponse(
        status_code=exc.status_code,
        content=problem.model_dump(mode="json"),
        media_type="application/problem+json",
    )


ERROR_RESPONSES = {
    403: {"model": ReconciliationProblem},
    404: {"model": ReconciliationProblem},
    409: {"model": ReconciliationProblem},
    422: {"model": ReconciliationProblem},
}


@router.get("/suggestions", response_model=list[TradeReconciliationRead])
async def list_reconciliation_suggestions(
    current_user: CurrentUser,
    service: ReconciliationApi,
    asset_id: Annotated[uuid.UUID | None, Query()] = None,
) -> list[TradeReconciliationRead]:
    return await service.list_suggestions(user_id=current_user.id, asset_id=asset_id)


@router.get("", response_model=list[TradeReconciliationRead])
async def list_active_reconciliations(
    current_user: CurrentUser,
    service: ReconciliationApi,
    reconciliation_status: Annotated[
        ReconciliationStatus | None,
        Query(alias="status"),
    ] = None,
) -> list[TradeReconciliationRead]:
    return await service.list_active(user_id=current_user.id, status=reconciliation_status)


@router.get(
    "/{reconciliation_id}",
    response_model=TradeReconciliationRead,
    responses=ERROR_RESPONSES,
)
async def get_reconciliation_detail(
    reconciliation_id: uuid.UUID,
    request: Request,
    current_user: CurrentUser,
    service: ReconciliationApi,
) -> TradeReconciliationRead | JSONResponse:
    try:
        return await service.get_detail(
            user_id=current_user.id,
            reconciliation_id=reconciliation_id,
        )
    except TradeReconciliationError as exc:
        return _problem(request, exc)


@router.get(
    "/{reconciliation_id}/preview",
    response_model=ReconciliationImpactPreview,
    responses=ERROR_RESPONSES,
)
async def preview_reconciliation_impact(
    reconciliation_id: uuid.UUID,
    request: Request,
    current_user: CurrentUser,
    service: ReconciliationApi,
) -> ReconciliationImpactPreview | JSONResponse:
    try:
        return await service.preview(
            user_id=current_user.id,
            reconciliation_id=reconciliation_id,
        )
    except TradeReconciliationError as exc:
        return _problem(request, exc)


@router.post(
    "/manual",
    response_model=TradeReconciliationRead,
    status_code=status.HTTP_201_CREATED,
    responses=ERROR_RESPONSES,
)
async def create_manual_reconciliation(
    payload: ManualReconciliationCreate,
    request: Request,
    current_user: CurrentUser,
    service: ReconciliationApi,
) -> TradeReconciliationRead | JSONResponse:
    try:
        return await service.create_manual(
            user_id=current_user.id,
            sell_transaction_id=payload.sell_transaction_id,
            allocations=payload.allocations,
            notes=payload.notes,
        )
    except TradeReconciliationError as exc:
        return _problem(request, exc)


@router.post(
    "/{reconciliation_id}/confirm",
    response_model=TradeReconciliationRead,
    responses=ERROR_RESPONSES,
)
async def confirm_reconciliation(
    reconciliation_id: uuid.UUID,
    payload: ReconciliationTransitionRequest,
    request: Request,
    current_user: CurrentUser,
    service: ReconciliationApi,
) -> TradeReconciliationRead | JSONResponse:
    try:
        return await service.confirm(
            user_id=current_user.id,
            reconciliation_id=reconciliation_id,
            notes=payload.notes,
        )
    except TradeReconciliationError as exc:
        return _problem(request, exc)


@router.post(
    "/{reconciliation_id}/reject",
    response_model=TradeReconciliationRead,
    responses=ERROR_RESPONSES,
)
async def reject_reconciliation(
    reconciliation_id: uuid.UUID,
    payload: ReconciliationTransitionRequest,
    request: Request,
    current_user: CurrentUser,
    service: ReconciliationApi,
) -> TradeReconciliationRead | JSONResponse:
    try:
        return await service.reject(
            user_id=current_user.id,
            reconciliation_id=reconciliation_id,
            reason=payload.notes,
        )
    except TradeReconciliationError as exc:
        return _problem(request, exc)


@router.post(
    "/{reconciliation_id}/cancel",
    response_model=TradeReconciliationRead,
    responses=ERROR_RESPONSES,
)
async def cancel_reconciliation(
    reconciliation_id: uuid.UUID,
    payload: ReconciliationTransitionRequest,
    request: Request,
    current_user: CurrentUser,
    service: ReconciliationApi,
) -> TradeReconciliationRead | JSONResponse:
    try:
        return await service.cancel(
            user_id=current_user.id,
            reconciliation_id=reconciliation_id,
            reason=payload.notes,
        )
    except TradeReconciliationError as exc:
        return _problem(request, exc)
