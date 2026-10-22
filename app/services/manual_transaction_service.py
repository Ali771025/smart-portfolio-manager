"""Application service for manual transaction and corporate action entry."""

from __future__ import annotations

import hashlib
import uuid
from dataclasses import dataclass
from datetime import date
from decimal import Decimal, ROUND_HALF_EVEN
from typing import Any

from sqlalchemy import or_, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm.exc import StaleDataError

from app.core.redis import get_redis
from app.models.enums import TransactionType
from app.models.manual_transaction import ManualTransaction
from app.schemas.manual_transaction import (
    AssetTransferTransactionCreate,
    BuyTransactionCreate,
    CapitalIncreaseBonusTransactionCreate,
    CashDividendTransactionCreate,
    ManualTransactionPayload,
    PreEmptiveRightsTransactionCreate,
    SellTransactionCreate,
    StockSplitTransactionCreate,
)

EIGHT_PLACES = Decimal("0.00000001")
ZERO = Decimal("0.00000000")
IDEMPOTENCY_TTL_SECONDS = 60 * 60 * 24


def q8(value: Decimal) -> Decimal:
    """Normalize monetary and quantity values to NUMERIC(24, 8) scale."""

    return value.quantize(EIGHT_PLACES, rounding=ROUND_HALF_EVEN)


def build_idempotency_fingerprint(
    *,
    user_id: uuid.UUID,
    symbol: str,
    transaction_date: date,
    transaction_type: TransactionType,
    quantity: Decimal,
) -> str:
    payload = (
        f"{user_id}|{symbol}|{transaction_date.isoformat()}|"
        f"{transaction_type.value}|{q8(quantity)}"
    )
    return hashlib.sha256(payload.encode("utf-8")).hexdigest()


@dataclass(slots=True)
class ManualTransactionProblem(Exception):
    status_code: int
    title: str
    detail: str
    errors: list[dict[str, str]] | None = None


class ManualTransactionService:
    def __init__(self, db: AsyncSession) -> None:
        self.db = db

    async def process_transaction(
        self,
        *,
        payload: ManualTransactionPayload,
        user_id: uuid.UUID,
        idempotency_key: str,
    ) -> ManualTransaction:
        redis = get_redis()
        redis_key = f"manual_txn:idem:{user_id}:{idempotency_key}"

        if redis is not None:
            cached_id = await redis.get(redis_key)
            if cached_id:
                try:
                    cached_uuid = uuid.UUID(cached_id)
                except ValueError:
                    cached_uuid = None
                if cached_uuid is not None:
                    cached = await self.db.get(ManualTransaction, cached_uuid)
                    if cached is not None:
                        return cached

        existing = await self._find_existing(
            user_id=user_id,
            idempotency_key=idempotency_key,
            fingerprint=build_idempotency_fingerprint(
                user_id=user_id,
                symbol=payload.symbol,
                transaction_date=payload.transaction_date,
                transaction_type=payload.transaction_type,
                quantity=payload.quantity,
            ),
        )
        if existing is not None:
            return existing

        price, commission, total_value, metadata = calculate_financial_values(payload)
        fingerprint = build_idempotency_fingerprint(
            user_id=user_id,
            symbol=payload.symbol,
            transaction_date=payload.transaction_date,
            transaction_type=payload.transaction_type,
            quantity=payload.quantity,
        )

        entity = ManualTransaction(
            portfolio_id=payload.portfolio_id,
            created_by_user_id=user_id,
            symbol=payload.symbol,
            transaction_type=payload.transaction_type,
            transaction_date=payload.transaction_date,
            quantity=q8(payload.quantity),
            price=price,
            commission=commission,
            total_value=total_value,
            event_metadata=metadata,
            idempotency_key=idempotency_key,
            idempotency_fingerprint=fingerprint,
            notes=payload.notes,
        )
        self.db.add(entity)

        try:
            await self.db.commit()
        except IntegrityError:
            await self.db.rollback()
            winner = await self._find_existing(
                user_id=user_id,
                idempotency_key=idempotency_key,
                fingerprint=fingerprint,
            )
            if winner is not None:
                return winner
            raise ManualTransactionProblem(
                status_code=409,
                title="Transaction conflict",
                detail="Idempotency check failed due to a concurrent write.",
            )

        await self.db.refresh(entity)
        if redis is not None:
            await redis.set(redis_key, str(entity.id), ex=IDEMPOTENCY_TTL_SECONDS)
        return entity

    async def update_notes(
        self,
        *,
        transaction_id: uuid.UUID,
        user_id: uuid.UUID,
        notes: str | None,
        expected_version_id: int,
    ) -> ManualTransaction:
        entity = await self.db.get(ManualTransaction, transaction_id)
        if entity is None or entity.created_by_user_id != user_id:
            raise ManualTransactionProblem(
                status_code=404,
                title="Transaction not found",
                detail="No manual transaction exists for this id and user.",
            )

        if entity.version_id != expected_version_id:
            raise ManualTransactionProblem(
                status_code=409,
                title="Optimistic lock conflict",
                detail=(
                    "The transaction has been modified by another request. "
                    "Reload and retry with the latest version_id."
                ),
            )

        entity.notes = notes
        try:
            await self.db.commit()
        except StaleDataError as exc:
            await self.db.rollback()
            raise ManualTransactionProblem(
                status_code=409,
                title="Optimistic lock conflict",
                detail="Lost update prevented by version_id check.",
            ) from exc

        await self.db.refresh(entity)
        return entity

    async def _find_existing(
        self,
        *,
        user_id: uuid.UUID,
        idempotency_key: str,
        fingerprint: str,
    ) -> ManualTransaction | None:
        query = select(ManualTransaction).where(
            ManualTransaction.created_by_user_id == user_id,
            or_(
                ManualTransaction.idempotency_key == idempotency_key,
                ManualTransaction.idempotency_fingerprint == fingerprint,
            ),
        )
        result = await self.db.execute(query)
        return result.scalar_one_or_none()


def calculate_financial_values(
    payload: ManualTransactionPayload,
) -> tuple[Decimal | None, Decimal, Decimal, dict[str, Any]]:
    """
    Calculate canonical financial fields for every transaction variant.

    Returns:
        price, commission, total_value, metadata
    """

    if isinstance(payload, BuyTransactionCreate):
        price = q8(payload.price)
        commission = q8(payload.commission)
        total = q8((payload.quantity * payload.price) + payload.commission)
        return price, commission, total, {}

    if isinstance(payload, SellTransactionCreate):
        price = q8(payload.price)
        commission = q8(payload.commission)
        total = q8((payload.quantity * payload.price) - payload.commission)
        return price, commission, total, {}

    if isinstance(payload, CashDividendTransactionCreate):
        dps = q8(payload.dps)
        total = q8(payload.quantity * payload.dps)
        return ZERO, ZERO, total, {"dps": str(dps)}

    if isinstance(payload, CapitalIncreaseBonusTransactionCreate):
        return ZERO, ZERO, ZERO, {
            "bonus_ratio": str(q8(payload.bonus_ratio)),
            "cost_basis_dilution": True,
        }

    if isinstance(payload, StockSplitTransactionCreate):
        dilution_factor = Decimal(payload.split_from) / Decimal(payload.split_to)
        return ZERO, ZERO, ZERO, {
            "split_from": payload.split_from,
            "split_to": payload.split_to,
            "dilution_factor": str(q8(dilution_factor)),
            "cost_basis_dilution": True,
        }

    if isinstance(payload, PreEmptiveRightsTransactionCreate):
        price = q8(payload.price or payload.subscription_price)
        commission = q8(payload.commission)
        total = q8((payload.quantity * price) + commission)
        return price, commission, total, {
            "rights_ratio": str(q8(payload.rights_ratio)),
            "subscription_price": str(q8(payload.subscription_price)),
        }

    if isinstance(payload, AssetTransferTransactionCreate):
        price = q8(payload.price)
        commission = q8(payload.commission)
        total = q8(payload.quantity * price)
        return price, commission, total, {
            "target_symbol": payload.target_symbol,
        }

    raise ManualTransactionProblem(
        status_code=422,
        title="Unsupported transaction payload",
        detail=f"Unsupported transaction type: {payload.transaction_type.value}",
    )
