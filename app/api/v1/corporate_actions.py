"""API router for dividend and capital increase accounting operations."""

from __future__ import annotations

import uuid
from typing import Annotated

from fastapi import APIRouter, Depends, Header, status

from app.core.deps import CurrentUser, get_corporate_actions_service
from app.schemas.corporate_actions import (
    CapitalIncreaseRequest,
    CapitalIncreaseResponse,
    CashDividendRequest,
    CashDividendResponse,
)
from app.services.corporate_actions import CorporateActionsService

router = APIRouter()


@router.post(
    "/portfolios/{portfolio_id}/corporate-actions/dividends",
    response_model=CashDividendResponse,
    status_code=status.HTTP_201_CREATED,
)
async def register_cash_dividend(
    portfolio_id: uuid.UUID,
    payload: CashDividendRequest,
    current_user: CurrentUser,
    service: Annotated[CorporateActionsService, Depends(get_corporate_actions_service)],
    idempotency_key: Annotated[str, Header(alias="Idempotency-Key")],
) -> CashDividendResponse:
    """Register a DPS event without mutating quantity or WAC."""

    dividend = await service.register_cash_dividend(
        portfolio_id=portfolio_id,
        user_id=current_user.id,
        payload=payload,
        idempotency_key=idempotency_key,
    )
    return CashDividendResponse.model_validate(dividend)


@router.post(
    "/portfolios/{portfolio_id}/corporate-actions/capital-increase",
    response_model=CapitalIncreaseResponse,
    status_code=status.HTTP_201_CREATED,
)
async def apply_capital_increase(
    portfolio_id: uuid.UUID,
    payload: CapitalIncreaseRequest,
    current_user: CurrentUser,
    service: Annotated[CorporateActionsService, Depends(get_corporate_actions_service)],
    idempotency_key: Annotated[str, Header(alias="Idempotency-Key")],
) -> CapitalIncreaseResponse:
    """Apply rights/bonus shares with pessimistic row locking."""

    execution = await service.apply_capital_increase(
        portfolio_id=portfolio_id,
        user_id=current_user.id,
        payload=payload,
        idempotency_key=idempotency_key,
    )
    return CapitalIncreaseResponse.model_validate(execution)
