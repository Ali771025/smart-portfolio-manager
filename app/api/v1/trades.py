"""Frontend-compatible trade endpoints."""

import uuid
from datetime import datetime
from decimal import Decimal
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Query, status
from pydantic import BaseModel, Field, field_validator
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.deps import CurrentUser
from app.models.asset import Asset
from app.models.enums import AssetType, TransactionType
from app.models.portfolio import Portfolio
from app.models.transaction import Transaction
from app.schemas.transaction import BuyTransactionCreate, SellTransactionCreate
from app.services.ledger_domain import LedgerDomainError
from app.services.ledger_valuation_service import LedgerValuationService
from app.services.symbol_normalization import normalize_symbol_key

router = APIRouter()


class TradeWriteRequest(BaseModel):
    portfolio_id: uuid.UUID
    symbol: str = Field(min_length=1, max_length=50)
    quantity: Decimal = Field(gt=0)
    price: Decimal = Field(gt=0)
    fees: Decimal = Field(default=Decimal("0.0000"), ge=0)
    executed_at: datetime
    notes: str | None = None
    idempotency_key: str = Field(min_length=4, max_length=255)
    asset_name: str | None = Field(default=None, max_length=255)
    external_order_id: str | None = Field(default=None, max_length=255)

    @field_validator("symbol")
    @classmethod
    def normalize_symbol(cls, value: str) -> str:
        symbol = normalize_symbol_key(value)
        if not symbol:
            raise ValueError("symbol cannot be blank")
        return symbol

    @field_validator("idempotency_key")
    @classmethod
    def normalize_idempotency_key(cls, value: str) -> str:
        return value.strip()


class TradeReadResponse(BaseModel):
    id: uuid.UUID
    portfolio_id: uuid.UUID
    symbol: str
    side: TransactionType
    quantity: Decimal
    price: Decimal
    fees: Decimal
    executed_at: datetime
    notes: str | None = None


class TradeListResponse(BaseModel):
    items: list[TradeReadResponse]
    total: int
    limit: int
    offset: int


async def _get_owned_portfolio_or_404(
    *,
    db: AsyncSession,
    portfolio_id: uuid.UUID,
    user_id: uuid.UUID,
) -> Portfolio:
    result = await db.execute(
        select(Portfolio).where(
            Portfolio.id == portfolio_id,
            Portfolio.user_id == user_id,
            Portfolio.is_active.is_(True),
        )
    )
    portfolio = result.scalar_one_or_none()
    if portfolio is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Portfolio not found",
        )
    return portfolio


async def _get_or_create_asset(
    *,
    db: AsyncSession,
    symbol: str,
    price: Decimal,
    asset_name: str | None,
) -> Asset:
    result = await db.execute(
        select(Asset).where(
            Asset.normalized_symbol == symbol,
            Asset.is_active.is_(True),
        )
    )
    asset = result.scalar_one_or_none()
    if asset is not None:
        return asset

    asset = Asset(
        ticker_symbol=symbol,
        normalized_symbol=symbol.strip().upper(),
        name_fa=(asset_name or symbol).strip() or symbol,
        name_en=asset_name.strip() if asset_name else None,
        asset_type=AssetType.STOCK,
        exchange="TSETMC",
        display_metadata=None,
        current_price=Decimal("0"),
        last_trade_price=Decimal("0"),
        closing_price=Decimal("0"),
        previous_close_price=Decimal("0"),
        is_active=True,
        is_tradeable=True,
    )
    db.add(asset)
    await db.flush()
    return asset


def _to_trade_read(transaction: Transaction, symbol: str) -> TradeReadResponse:
    return TradeReadResponse(
        id=transaction.id,
        portfolio_id=transaction.portfolio_id,
        symbol=symbol,
        side=transaction.transaction_type,
        quantity=transaction.quantity,
        price=transaction.price_per_unit,
        fees=transaction.fees,
        executed_at=transaction.executed_at,
        notes=transaction.notes,
    )


async def _create_trade(
    *,
    payload: TradeWriteRequest,
    transaction_type: TransactionType,
    current_user_id: uuid.UUID,
    db: AsyncSession,
) -> TradeReadResponse:
    await _get_owned_portfolio_or_404(
        db=db,
        portfolio_id=payload.portfolio_id,
        user_id=current_user_id,
    )
    asset = await _get_or_create_asset(
        db=db,
        symbol=payload.symbol,
        price=payload.price,
        asset_name=payload.asset_name,
    )

    if transaction_type == TransactionType.BUY:
        command = BuyTransactionCreate(
            asset_id=asset.id,
            transaction_type=TransactionType.BUY,
            quantity=payload.quantity,
            price_per_unit=payload.price,
            fees=payload.fees,
            executed_at=payload.executed_at,
            notes=payload.notes,
        )
    else:
        command = SellTransactionCreate(
            asset_id=asset.id,
            transaction_type=TransactionType.SELL,
            quantity=payload.quantity,
            price_per_unit=payload.price,
            fees=payload.fees,
            executed_at=payload.executed_at,
            notes=payload.notes,
        )

    service = LedgerValuationService(db)
    try:
        transaction = await service.apply_transaction(
            portfolio_id=payload.portfolio_id,
            payload=command,
            idempotency_key=payload.idempotency_key,
        )
    except LedgerDomainError as exc:
        raise HTTPException(
            status_code=exc.status,
            detail=exc.detail,
        ) from exc
    return _to_trade_read(transaction, payload.symbol)


@router.post("/trades/buy", response_model=TradeReadResponse, status_code=status.HTTP_201_CREATED)
async def create_buy_trade(
    payload: TradeWriteRequest,
    current_user: CurrentUser,
    db: Annotated[AsyncSession, Depends(get_db)],
) -> TradeReadResponse:
    return await _create_trade(
        payload=payload,
        transaction_type=TransactionType.BUY,
        current_user_id=current_user.id,
        db=db,
    )


@router.post("/trades/sell", response_model=TradeReadResponse, status_code=status.HTTP_201_CREATED)
async def create_sell_trade(
    payload: TradeWriteRequest,
    current_user: CurrentUser,
    db: Annotated[AsyncSession, Depends(get_db)],
) -> TradeReadResponse:
    return await _create_trade(
        payload=payload,
        transaction_type=TransactionType.SELL,
        current_user_id=current_user.id,
        db=db,
    )


@router.get("/trades", response_model=TradeListResponse)
async def list_trades(
    current_user: CurrentUser,
    db: Annotated[AsyncSession, Depends(get_db)],
    portfolio_id: uuid.UUID | None = Query(default=None),
    limit: int = Query(default=50, ge=1, le=200),
    offset: int = Query(default=0, ge=0),
) -> TradeListResponse:
    if portfolio_id is not None:
        await _get_owned_portfolio_or_404(
            db=db,
            portfolio_id=portfolio_id,
            user_id=current_user.id,
        )

    base_stmt = (
        select(Transaction, Asset.ticker_symbol)
        .join(Asset, Asset.id == Transaction.asset_id)
        .join(Portfolio, Portfolio.id == Transaction.portfolio_id)
        .where(
            Portfolio.user_id == current_user.id,
            Portfolio.is_active.is_(True),
        )
    )
    if portfolio_id is not None:
        base_stmt = base_stmt.where(Transaction.portfolio_id == portfolio_id)

    total_stmt = select(func.count()).select_from(base_stmt.subquery())
    total_result = await db.execute(total_stmt)
    total = total_result.scalar_one()

    page_stmt = (
        base_stmt
        .order_by(Transaction.executed_at.desc())
        .limit(limit)
        .offset(offset)
    )
    page_result = await db.execute(page_stmt)
    rows = page_result.all()

    return TradeListResponse(
        items=[_to_trade_read(transaction, symbol) for transaction, symbol in rows],
        total=total,
        limit=limit,
        offset=offset,
    )
