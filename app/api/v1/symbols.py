"""Read-only symbol market endpoints consumed by Flutter."""

from __future__ import annotations

from datetime import date

from fastapi import APIRouter, Depends, HTTPException, Query, status

from app.core.deps import CurrentUser, get_market_read_service
from app.schemas.market_api import (
    ClientTypesResponse,
    OrderBookResponse,
    QuoteResponse,
    SymbolHistoryNormalizedResponse,
    SymbolListResponse,
    SymbolResponse,
)
from app.services.market_read_service import MarketReadService

router = APIRouter(prefix="/symbols", tags=["Symbols"])


@router.get("", response_model=SymbolListResponse)
async def list_symbols(
    _: CurrentUser,
    q: str | None = Query(default=None, max_length=128),
    active_only: bool = Query(default=True),
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=100, ge=1, le=500),
    service: MarketReadService = Depends(get_market_read_service),
) -> SymbolListResponse:
    return await service.list_symbols(
        query=q,
        active_only=active_only,
        page=page,
        page_size=page_size,
    )


@router.get("/{symbol}", response_model=SymbolResponse)
async def get_symbol(
    symbol: str,
    _: CurrentUser,
    service: MarketReadService = Depends(get_market_read_service),
) -> SymbolResponse:
    item = await service.get_symbol(symbol.strip())
    if item is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Symbol not found")
    return item


@router.get("/{symbol}/quote", response_model=QuoteResponse)
async def get_symbol_quote(
    symbol: str,
    _: CurrentUser,
    service: MarketReadService = Depends(get_market_read_service),
) -> QuoteResponse:
    item = await service.latest_quote(symbol.strip())
    if item is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Quote not found")
    return item


@router.get("/{symbol}/history", response_model=SymbolHistoryNormalizedResponse)
async def get_symbol_history(
    symbol: str,
    _: CurrentUser,
    from_date: date = Query(...),
    to_date: date = Query(...),
    service: MarketReadService = Depends(get_market_read_service),
) -> SymbolHistoryNormalizedResponse:
    if from_date > to_date:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="from_date must be on or before to_date",
        )
    if (to_date - from_date).days > 730:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Maximum history range is 730 days",
        )
    return await service.history(
        symbol=symbol.strip(),
        start_date=from_date,
        end_date=to_date,
    )


@router.get("/{symbol}/client-types", response_model=ClientTypesResponse)
async def get_symbol_client_types(
    symbol: str,
    _: CurrentUser,
    service: MarketReadService = Depends(get_market_read_service),
) -> ClientTypesResponse:
    item = await service.latest_client_types(symbol.strip())
    if item is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Client types not found")
    return item


@router.get("/{symbol}/order-book", response_model=OrderBookResponse)
async def get_symbol_order_book(
    symbol: str,
    _: CurrentUser,
    service: MarketReadService = Depends(get_market_read_service),
) -> OrderBookResponse:
    item = await service.latest_order_book(symbol.strip())
    if item is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Order book not found")
    return item


@router.get("/{symbol}/shareholders", include_in_schema=False)
async def get_symbol_shareholders(symbol: str, _: CurrentUser) -> None:
    _ = symbol
    raise HTTPException(
        status_code=status.HTTP_501_NOT_IMPLEMENTED,
        detail="Shareholder endpoint is not supported until normalized shareholder storage is available",
    )
