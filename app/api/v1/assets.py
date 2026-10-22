"""Asset catalog and detail endpoints used by the frontend asset screen."""

import uuid
from decimal import Decimal
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Query, status
from pydantic import BaseModel, Field
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.deps import CurrentUser
from app.models.asset import Asset
from app.models.asset_position import AssetPosition
from app.models.portfolio import Portfolio
from app.services.market_price_service import MarketPriceService
from app.services.symbol_normalization import normalize_symbol_key
from app.schemas.asset_resolve import (
    AssetResolveRequest,
    AssetResolveResponse,
    BulkAssetResolveItemResponse,
    BulkAssetResolveRequest,
    BulkAssetResolveResponse,
)
from app.services.asset_resolver_service import AssetResolveInput, AssetResolverService

router = APIRouter()


class AssetDetailsResponse(BaseModel):
    symbol: str
    portfolio_id: uuid.UUID | None = None
    quantity: Decimal = Field(default=Decimal("0"))
    current_price: Decimal | None = None
    current_value: Decimal | None = None
    unrealized_pnl: Decimal | None = None
    realized_pnl: Decimal = Field(default=Decimal("0"))


@router.post("/assets/resolve", response_model=AssetResolveResponse, status_code=status.HTTP_200_OK)
async def resolve_asset(
    payload: AssetResolveRequest,
    _current_user: CurrentUser,
    db: Annotated[AsyncSession, Depends(get_db)],
) -> AssetResolveResponse:
    resolver = AssetResolverService(db)
    try:
        resolved = await resolver.resolve_one(
            AssetResolveInput(
                symbol=payload.symbol,
                market=payload.market,
                display_name=payload.display_name,
            )
        )
    except ValueError as ex:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=str(ex),
        ) from ex

    await db.commit()
    return AssetResolveResponse(
        asset_id=resolved.asset.id,
        symbol=resolved.asset.ticker_symbol,
        created=resolved.created,
    )


@router.post("/assets/resolve/bulk", response_model=BulkAssetResolveResponse, status_code=status.HTTP_200_OK)
async def resolve_assets_bulk(
    payload: BulkAssetResolveRequest,
    _current_user: CurrentUser,
    db: Annotated[AsyncSession, Depends(get_db)],
) -> BulkAssetResolveResponse:
    resolver = AssetResolverService(db)
    try:
        resolved = await resolver.resolve_bulk(
            [
                AssetResolveInput(
                    symbol=item.symbol,
                    market=item.market,
                    display_name=item.display_name,
                )
                for item in payload.assets
            ]
        )
    except ValueError as ex:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=str(ex),
        ) from ex

    await db.commit()
    ordered_results = [
        BulkAssetResolveItemResponse(
            asset_id=match.asset.id,
            symbol=match.asset.ticker_symbol,
            market=match.asset.exchange,
            created=match.created,
        )
        for (_symbol, _market), match in sorted(resolved.items(), key=lambda item: item[0])
    ]
    return BulkAssetResolveResponse(results=ordered_results)


@router.get("/assets/{symbol}", response_model=AssetDetailsResponse)
async def get_asset_details(
    symbol: str,
    current_user: CurrentUser,
    db: Annotated[AsyncSession, Depends(get_db)],
    portfolio_id: uuid.UUID | None = Query(default=None),
) -> AssetDetailsResponse:
    normalized_symbol = normalize_symbol_key(symbol)
    if not normalized_symbol:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Asset symbol is required",
        )

    if portfolio_id is not None:
        portfolio_result = await db.execute(
            select(Portfolio).where(
                Portfolio.id == portfolio_id,
                Portfolio.user_id == current_user.id,
                Portfolio.is_active.is_(True),
            )
        )
        if portfolio_result.scalar_one_or_none() is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Portfolio not found",
            )

    asset_result = await db.execute(
        select(Asset).where(
            Asset.normalized_symbol == normalized_symbol,
            Asset.is_active.is_(True),
        )
    )
    asset = asset_result.scalar_one_or_none()

    if asset is None:
        return AssetDetailsResponse(
            symbol=normalized_symbol,
            portfolio_id=portfolio_id,
        )

    position_stmt = (
        select(
            func.coalesce(func.sum(AssetPosition.total_quantity), 0),
            func.coalesce(func.sum(AssetPosition.total_cost_basis), 0),
            func.coalesce(func.sum(AssetPosition.cumulative_realized_pnl), 0),
        )
        .select_from(AssetPosition)
        .join(Portfolio, Portfolio.id == AssetPosition.portfolio_id)
        .where(
            AssetPosition.asset_id == asset.id,
            Portfolio.user_id == current_user.id,
            Portfolio.is_active.is_(True),
        )
    )
    if portfolio_id is not None:
        position_stmt = position_stmt.where(AssetPosition.portfolio_id == portfolio_id)

    aggregate_result = await db.execute(position_stmt)
    quantity, total_cost_basis, realized_pnl = aggregate_result.one()

    selected_price = MarketPriceService().select_from_asset(asset, use_case="live")
    current_price = selected_price.selected_valuation_price
    current_value = quantity * current_price if current_price is not None else None
    unrealized_pnl = current_value - total_cost_basis if current_value is not None else None

    return AssetDetailsResponse(
        symbol=normalized_symbol,
        portfolio_id=portfolio_id,
        quantity=quantity,
        current_price=current_price,
        current_value=current_value,
        unrealized_pnl=unrealized_pnl,
        realized_pnl=realized_pnl,
    )
