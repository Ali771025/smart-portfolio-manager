"""Ledger write/valuation service with Decimal-only accounting semantics."""

from __future__ import annotations

import hashlib
import uuid
from dataclasses import dataclass
from datetime import UTC, date, datetime
from decimal import Decimal, ROUND_HALF_EVEN

from sqlalchemy import select
from sqlalchemy.exc import IntegrityError, ProgrammingError
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.asset import Asset
from app.models.asset_position import AssetPosition
from app.models.market_data import DailyPrice
from app.models.transaction import Transaction
from app.schemas.transaction import (
    BuyTransactionCreate,
    CapitalIncreaseBonusTransactionCreate,
    CashDividendTransactionCreate,
    LedgerTransactionPayload,
    PreEmptiveRightsTransactionCreate,
    SellTransactionCreate,
    StockSplitTransactionCreate,
)
from app.services.ledger_domain import LedgerDomainError, problem_type
from app.services.market_price_service import MarketPriceService

Q8 = Decimal("0.00000001")
ZERO = Decimal("0.00000000")


@dataclass(slots=True)
class PositionValuation:
    quantity: Decimal
    weighted_avg_cost: Decimal
    total_cost_basis: Decimal
    latest_price: Decimal | None
    market_value: Decimal | None
    unrealized_pnl: Decimal | None
    unrealized_pnl_percent: Decimal | None
    realized_pnl: Decimal
    has_market_price: bool
    price_source: str
    price_date: datetime | None
    data_status: str
    warnings: list[str]


@dataclass(slots=True, frozen=True)
class ResolvedPositionPrice:
    price: Decimal | None
    source: str
    price_date: datetime | None
    has_market_price: bool
    warnings: tuple[str, ...] = ()


@dataclass(slots=True)
class LedgerComputationResult:
    recorded_quantity: Decimal
    price_per_unit: Decimal
    fees: Decimal
    total_amount: Decimal
    realized_pnl: Decimal
    new_quantity: Decimal
    new_total_cost_basis: Decimal
    new_weighted_avg_cost: Decimal


def q8(value: Decimal) -> Decimal:
    return value.quantize(Q8, rounding=ROUND_HALF_EVEN)


def apply_financial_rule(
    *,
    quantity_before: Decimal,
    wac_before: Decimal,
    cost_before: Decimal,
    payload: LedgerTransactionPayload,
) -> LedgerComputationResult:
    recorded_quantity = q8(payload.quantity)
    realized_pnl = ZERO
    price_per_unit = ZERO
    fees = ZERO
    total_amount = ZERO

    if isinstance(payload, BuyTransactionCreate):
        price_per_unit = q8(payload.price_per_unit)
        fees = q8(payload.fees)
        trade_cost = q8((recorded_quantity * price_per_unit) + fees)
        new_qty = q8(quantity_before + recorded_quantity)
        new_cost = q8(cost_before + trade_cost)
        new_wac = ZERO if new_qty == ZERO else q8(new_cost / new_qty)
        total_amount = trade_cost
        return LedgerComputationResult(
            recorded_quantity=recorded_quantity,
            price_per_unit=price_per_unit,
            fees=fees,
            total_amount=total_amount,
            realized_pnl=realized_pnl,
            new_quantity=new_qty,
            new_total_cost_basis=new_cost,
            new_weighted_avg_cost=new_wac,
        )

    if isinstance(payload, SellTransactionCreate):
        sell_qty = recorded_quantity
        if sell_qty > quantity_before:
            raise LedgerDomainError(
                type=problem_type("insufficient-quantity"),
                title="Insufficient quantity",
                status=409,
                detail=(
                    f"Cannot sell {sell_qty} units; only {quantity_before} are available "
                    "for this portfolio/asset pair."
                ),
            )

        price_per_unit = q8(payload.price_per_unit)
        fees = q8(payload.fees)
        proceeds = q8((sell_qty * price_per_unit) - fees)
        cost_of_sold = q8(sell_qty * wac_before)
        realized_pnl = q8(proceeds - cost_of_sold)

        new_qty = q8(quantity_before - sell_qty)
        new_cost = q8(cost_before - cost_of_sold)
        if new_qty == ZERO:
            new_wac = ZERO
            new_cost = ZERO
        else:
            new_wac = wac_before

        return LedgerComputationResult(
            recorded_quantity=recorded_quantity,
            price_per_unit=price_per_unit,
            fees=fees,
            total_amount=proceeds,
            realized_pnl=realized_pnl,
            new_quantity=new_qty,
            new_total_cost_basis=new_cost,
            new_weighted_avg_cost=new_wac,
        )

    if isinstance(payload, CashDividendTransactionCreate):
        if quantity_before <= ZERO:
            raise LedgerDomainError(
                type=problem_type("empty-position"),
                title="Empty position",
                status=409,
                detail="Cannot book dividend for an empty position.",
            )
        if recorded_quantity > quantity_before:
            raise LedgerDomainError(
                type=problem_type("invalid-dividend-quantity"),
                title="Invalid dividend quantity",
                status=422,
                detail=(
                    f"Dividend quantity {recorded_quantity} cannot exceed held "
                    f"quantity {quantity_before}."
                ),
            )
        price_per_unit = q8(payload.dividend_per_unit)
        dividend_profit = q8(recorded_quantity * price_per_unit)
        return LedgerComputationResult(
            recorded_quantity=recorded_quantity,
            price_per_unit=price_per_unit,
            fees=ZERO,
            total_amount=dividend_profit,
            realized_pnl=dividend_profit,
            new_quantity=quantity_before,
            new_total_cost_basis=cost_before,
            new_weighted_avg_cost=wac_before,
        )

    if isinstance(payload, CapitalIncreaseBonusTransactionCreate):
        if quantity_before <= ZERO:
            raise LedgerDomainError(
                type=problem_type("empty-position"),
                title="Empty position",
                status=409,
                detail="Cannot apply bonus shares to an empty position.",
            )
        bonus_qty = recorded_quantity
        new_qty = q8(quantity_before + bonus_qty)
        new_wac = ZERO if new_qty == ZERO else q8(cost_before / new_qty)
        return LedgerComputationResult(
            recorded_quantity=recorded_quantity,
            price_per_unit=ZERO,
            fees=ZERO,
            total_amount=ZERO,
            realized_pnl=ZERO,
            new_quantity=new_qty,
            new_total_cost_basis=cost_before,
            new_weighted_avg_cost=new_wac,
        )

    if isinstance(payload, StockSplitTransactionCreate):
        if quantity_before <= ZERO:
            raise LedgerDomainError(
                type=problem_type("empty-position"),
                title="Empty position",
                status=409,
                detail="Cannot apply stock split to an empty position.",
            )
        ratio = q8(Decimal(payload.split_to) / Decimal(payload.split_from))
        new_qty = q8(quantity_before * ratio)
        delta_qty = q8(new_qty - quantity_before)
        if delta_qty <= ZERO:
            raise LedgerDomainError(
                type=problem_type("invalid-split-ratio"),
                title="Invalid split ratio",
                status=422,
                detail="Stock split ratio must increase total quantity.",
            )
        new_wac = ZERO if new_qty == ZERO else q8(cost_before / new_qty)
        return LedgerComputationResult(
            recorded_quantity=delta_qty,
            price_per_unit=ZERO,
            fees=ZERO,
            total_amount=ZERO,
            realized_pnl=ZERO,
            new_quantity=new_qty,
            new_total_cost_basis=cost_before,
            new_weighted_avg_cost=new_wac,
        )

    if isinstance(payload, PreEmptiveRightsTransactionCreate):
        if quantity_before <= ZERO:
            raise LedgerDomainError(
                type=problem_type("empty-position"),
                title="Empty position",
                status=409,
                detail="Cannot apply rights issue to an empty position.",
            )
        rights_qty = recorded_quantity
        price_per_unit = q8(payload.subscription_price)
        fees = q8(payload.fees)
        rights_cost = q8((rights_qty * price_per_unit) + fees)

        new_qty = q8(quantity_before + rights_qty)
        new_cost = q8(cost_before + rights_cost)
        new_wac = ZERO if new_qty == ZERO else q8(new_cost / new_qty)
        return LedgerComputationResult(
            recorded_quantity=recorded_quantity,
            price_per_unit=price_per_unit,
            fees=fees,
            total_amount=rights_cost,
            realized_pnl=ZERO,
            new_quantity=new_qty,
            new_total_cost_basis=new_cost,
            new_weighted_avg_cost=new_wac,
        )

    raise LedgerDomainError(
        type=problem_type("unsupported-transaction-type"),
        title="Unsupported transaction",
        status=422,
        detail=f"Unsupported transaction_type={payload.transaction_type.value}",
    )


class LedgerValuationService:
    def __init__(self, db: AsyncSession) -> None:
        self.db = db

    async def apply_transaction(
        self,
        *,
        portfolio_id: uuid.UUID,
        payload: LedgerTransactionPayload,
        idempotency_key: str,
    ) -> Transaction:
        existing = await self._find_existing_transaction(
            portfolio_id=portfolio_id,
            idempotency_key=idempotency_key,
        )
        if existing is not None:
            return existing

        position = await self._lock_or_create_position(
            portfolio_id=portfolio_id,
            asset_id=payload.asset_id,
        )

        quantity_before = q8(position.total_quantity)
        wac_before = q8(position.weighted_avg_cost)
        cost_before = q8(position.total_cost_basis)
        computed = apply_financial_rule(
            quantity_before=quantity_before,
            wac_before=wac_before,
            cost_before=cost_before,
            payload=payload,
        )
        position.total_quantity = computed.new_quantity
        position.total_cost_basis = computed.new_total_cost_basis
        position.weighted_avg_cost = computed.new_weighted_avg_cost
        if computed.realized_pnl != ZERO:
            position.cumulative_realized_pnl = q8(
                position.cumulative_realized_pnl + computed.realized_pnl
            )

        position.trade_count += 1
        position.last_updated = datetime.now(UTC)

        transaction = Transaction(
            portfolio_id=portfolio_id,
            asset_id=payload.asset_id,
            transaction_type=payload.transaction_type,
            quantity=computed.recorded_quantity,
            price_per_unit=computed.price_per_unit,
            fees=computed.fees,
            total_amount=computed.total_amount,
            currency="IRR",  # Tehran Stock Exchange uses Iranian Rial
            realized_pnl=computed.realized_pnl,
            wac_at_execution=wac_before,
            executed_at=payload.executed_at,
            notes=payload.notes,
            reference_hash=self._reference_hash(
                portfolio_id=portfolio_id,
                idempotency_key=idempotency_key,
                payload=payload,
            ),
            idempotency_key=idempotency_key,
        )
        self.db.add(transaction)

        try:
            await self.db.commit()
        except IntegrityError:
            await self.db.rollback()
            winner = await self._find_existing_transaction(
                portfolio_id=portfolio_id,
                idempotency_key=idempotency_key,
            )
            if winner is not None:
                return winner
            raise LedgerDomainError(
                type=problem_type("idempotency-conflict"),
                title="Idempotency conflict",
                status=409,
                detail="A concurrent request used the same idempotency key.",
            )

        await self.db.refresh(transaction)
        return transaction

    async def compute_position_valuation(
        self,
        *,
        portfolio_id: uuid.UUID,
        asset_id: uuid.UUID,
        as_of_date: date | None = None,
    ) -> PositionValuation:
        position_result = await self.db.execute(
            select(AssetPosition).where(
                AssetPosition.portfolio_id == portfolio_id,
                AssetPosition.asset_id == asset_id,
            )
        )
        position = position_result.scalar_one_or_none()
        if position is None:
            raise LedgerDomainError(
                type=problem_type("position-not-found"),
                title="Position not found",
                status=404,
                detail="No position exists for this asset in the selected portfolio.",
            )

        resolved_price = await self.resolve_position_price(
            asset_id=asset_id,
            as_of_date=as_of_date,
        )

        quantity = q8(position.total_quantity)
        total_cost_basis = q8(position.total_cost_basis)
        if resolved_price.price is None:
            market_value = None
            unrealized_pnl = None
            unrealized_pnl_percent = None
        else:
            market_value = q8(quantity * resolved_price.price)
            unrealized_pnl = q8(market_value - total_cost_basis)
            unrealized_pnl_percent = (
                ZERO
                if total_cost_basis == ZERO
                else q8((unrealized_pnl / total_cost_basis) * Decimal("100"))
            )

        return PositionValuation(
            quantity=quantity,
            weighted_avg_cost=q8(position.weighted_avg_cost),
            total_cost_basis=total_cost_basis,
            latest_price=resolved_price.price,
            market_value=market_value,
            unrealized_pnl=unrealized_pnl,
            unrealized_pnl_percent=unrealized_pnl_percent,
            realized_pnl=q8(position.cumulative_realized_pnl),
            has_market_price=resolved_price.has_market_price,
            price_source=resolved_price.source,
            price_date=resolved_price.price_date,
            data_status="ok" if resolved_price.has_market_price else "missing_market_price",
            warnings=list(resolved_price.warnings),
        )

    async def latest_price_for_asset(
        self,
        *,
        asset_id: uuid.UUID,
        as_of_date: date | None = None,
    ) -> ResolvedPositionPrice:
        query_date = as_of_date or datetime.now(UTC).date()

        try:
            price_result = await self.db.execute(
                select(DailyPrice)
                .where(
                    DailyPrice.asset_id == asset_id,
                    DailyPrice.date <= query_date,
                )
                .order_by(DailyPrice.date.desc())
                .limit(1)
            )
            price_row = price_result.scalar_one_or_none()
            if price_row is not None and price_row.close_price is not None and price_row.close_price > ZERO:
                return ResolvedPositionPrice(
                    price=q8(price_row.close_price),
                    source="daily_price.close_price",
                    price_date=datetime.combine(price_row.date, datetime.min.time(), tzinfo=UTC),
                    has_market_price=True,
                )
        except ProgrammingError:
            # Deployments that skipped market-data migrations may not have
            # the daily_prices table yet; gracefully fall back to asset spot price.
            await self.db.rollback()

        asset_result = await self.db.execute(select(Asset).where(Asset.id == asset_id))
        asset = asset_result.scalar_one_or_none()
        if asset is None:
            raise LedgerDomainError(
                type=problem_type("asset-not-found"),
                title="Asset not found",
                status=404,
                detail="Asset does not exist.",
            )

        selected = MarketPriceService().select_from_asset(asset, use_case="live")
        if selected.selected_valuation_price is None:
            return ResolvedPositionPrice(
                price=None,
                source="missing",
                price_date=None,
                has_market_price=False,
                warnings=("missing_market_price",),
            )

        source = (
            "asset.last_trade_price"
            if selected.selected_price_source == "last_price"
            else "asset.closing_price"
        )
        return ResolvedPositionPrice(
            price=q8(selected.selected_valuation_price),
            source=source,
            price_date=selected.price_as_of,
            has_market_price=True,
            warnings=selected.warnings,
        )

    async def resolve_position_price(
        self,
        *,
        asset_id: uuid.UUID,
        as_of_date: date | None = None,
    ) -> ResolvedPositionPrice:
        """Resolve a real market price without substituting position cost."""
        return await self.latest_price_for_asset(
            asset_id=asset_id,
            as_of_date=as_of_date,
        )

    async def latest_price_timestamp_for_asset(
        self,
        *,
        asset_id: uuid.UUID,
        as_of_date: date | None = None,
    ) -> datetime | None:
        query_date = as_of_date or datetime.now(UTC).date()
        try:
            price_result = await self.db.execute(
                select(DailyPrice)
                .where(
                    DailyPrice.asset_id == asset_id,
                    DailyPrice.date <= query_date,
                )
                .order_by(DailyPrice.date.desc())
                .limit(1)
            )
            price_row = price_result.scalar_one_or_none()
            if price_row is not None:
                return datetime.combine(price_row.date, datetime.min.time(), tzinfo=UTC)
        except ProgrammingError:
            await self.db.rollback()

        asset_result = await self.db.execute(
            select(Asset.price_updated_at).where(Asset.id == asset_id)
        )
        return asset_result.scalar_one_or_none()

    async def _lock_or_create_position(
        self,
        *,
        portfolio_id: uuid.UUID,
        asset_id: uuid.UUID,
    ) -> AssetPosition:
        result = await self.db.execute(
            select(AssetPosition)
            .where(
                AssetPosition.portfolio_id == portfolio_id,
                AssetPosition.asset_id == asset_id,
            )
            .with_for_update()
        )
        position = result.scalar_one_or_none()
        if position is not None:
            return position

        position = AssetPosition(
            portfolio_id=portfolio_id,
            asset_id=asset_id,
            total_quantity=ZERO,
            weighted_avg_cost=ZERO,
            total_cost_basis=ZERO,
            cumulative_realized_pnl=ZERO,
            trade_count=0,
            last_updated=datetime.now(UTC),
        )
        self.db.add(position)
        await self.db.flush()
        return position

    async def _find_existing_transaction(
        self,
        *,
        portfolio_id: uuid.UUID,
        idempotency_key: str,
    ) -> Transaction | None:
        existing = await self.db.execute(
            select(Transaction).where(
                Transaction.portfolio_id == portfolio_id,
                Transaction.idempotency_key == idempotency_key,
            )
        )
        return existing.scalar_one_or_none()

    def _reference_hash(
        self,
        *,
        portfolio_id: uuid.UUID,
        idempotency_key: str,
        payload: LedgerTransactionPayload,
    ) -> str:
        fingerprint = (
            f"{portfolio_id}|{payload.asset_id}|{payload.transaction_type.value}|"
            f"{payload.executed_at.isoformat()}|{q8(payload.quantity)}|{idempotency_key}"
        )
        return hashlib.sha256(fingerprint.encode("utf-8")).hexdigest()
