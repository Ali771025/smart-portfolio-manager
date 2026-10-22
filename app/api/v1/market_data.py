"""Legacy market data endpoint kept for backward compatibility."""

from fastapi import APIRouter, Depends, status
from pydantic import BaseModel

from app.core.deps import CurrentUser
from app.tasks.market_tasks import sync_tsetmc_live_prices

router = APIRouter()


class MarketSyncResponse(BaseModel):
    task_id: str
    state: str
    message: str


@router.post(
    "/sync",
    response_model=MarketSyncResponse,
    status_code=status.HTTP_202_ACCEPTED,
)
async def trigger_market_sync(_: CurrentUser) -> MarketSyncResponse:
    report = sync_tsetmc_live_prices.delay()
    return MarketSyncResponse(
        task_id=report.id,
        state=report.state,
        message="Live market sync task queued",
    )
