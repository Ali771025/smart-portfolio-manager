"""Development-only authenticated diagnostic endpoints."""

from __future__ import annotations

import uuid
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.database import get_db
from app.core.deps import CurrentUser
from app.schemas.valuation_diagnostic import ValuationDiagnosticResponse
from app.services.valuation_diagnostic_service import ValuationDiagnosticService

router = APIRouter(prefix="/debug", tags=["Development Diagnostics"])
DEVELOPMENT_ENVIRONMENTS = frozenset({"development", "dev", "local"})


def valuation_diagnostic_enabled(environment: str | None = None) -> bool:
    value = settings.ENVIRONMENT if environment is None else environment
    return value.strip().lower() in DEVELOPMENT_ENVIRONMENTS


def require_development_environment() -> None:
    if not valuation_diagnostic_enabled():
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Not found")


@router.get(
    "/portfolios/{portfolio_id}/symbols/{symbol}/valuation-diagnostic",
    response_model=ValuationDiagnosticResponse,
    dependencies=[Depends(require_development_environment)],
)
async def valuation_diagnostic(
    portfolio_id: uuid.UUID,
    symbol: str,
    current_user: CurrentUser,
    db: Annotated[AsyncSession, Depends(get_db)],
) -> ValuationDiagnosticResponse:
    return await ValuationDiagnosticService(db).build(
        portfolio_id=portfolio_id,
        user_id=current_user.id,
        symbol_input=symbol,
    )
