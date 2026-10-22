"""Read-only API for disclosures ingested from Codal."""

from __future__ import annotations

from datetime import date

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core import market_cache
from app.core.database import get_db
from app.core.deps import CurrentUser
from app.repositories.market_data import MarketDataRepository
from app.schemas.disclosures import DisclosureDetailResponse, DisclosureResponse

router = APIRouter(prefix="/disclosures", tags=["Disclosures"])


@router.get("", response_model=list[DisclosureResponse])
async def list_disclosures(
    _: CurrentUser,
    symbol: str | None = Query(default=None, max_length=64),
    category: str | None = Query(default=None, max_length=128),
    from_date: date | None = None,
    to_date: date | None = None,
    has_attachment: bool | None = None,
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=50, ge=1, le=200),
    db: AsyncSession = Depends(get_db),
) -> list[DisclosureResponse]:
    if from_date and to_date and from_date > to_date:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="from_date must be on or before to_date",
        )

    has_filters = any(
        value is not None
        for value in (symbol, category, from_date, to_date, has_attachment)
    )
    if not has_filters and page == 1:
        cached = await market_cache.get_cached_disclosures()
        if cached:
            return [DisclosureResponse.model_validate(item) for item in cached[:page_size]]

    rows = await MarketDataRepository(db).list_disclosures(
        symbol=symbol,
        category=category,
        from_date=from_date,
        to_date=to_date,
        has_attachment=has_attachment,
        limit=page_size,
        offset=(page - 1) * page_size,
    )
    return [DisclosureResponse.model_validate(item) for item in rows]


@router.get("/{tracking_number}", response_model=DisclosureDetailResponse)
async def get_disclosure(
    tracking_number: str,
    _: CurrentUser,
    db: AsyncSession = Depends(get_db),
) -> DisclosureDetailResponse:
    item = await MarketDataRepository(db).get_disclosure(tracking_number.strip())
    if item is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Disclosure not found")
    return DisclosureDetailResponse.model_validate(item)
