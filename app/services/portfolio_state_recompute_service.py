"""Post-import portfolio recomputation and cache invalidation orchestration."""

from __future__ import annotations

import uuid
from dataclasses import dataclass
from datetime import UTC, date, datetime
from decimal import Decimal, ROUND_HALF_EVEN
import logging

from sqlalchemy import delete, func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.redis import get_redis
from app.models.asset import Asset
from app.models.asset_position import AssetPosition
from app.models.cash_transaction import PortfolioCashTransaction
from app.models.enums import TransactionType
from app.models.holding_snapshot import HoldingSnapshot
from app.models.market_data import PortfolioSnapshot
from app.models.transaction import Transaction
from app.services.advanced_benchmark_service import invalidate_portfolio_benchmark_cache
from app.services.analytics_service import invalidate_portfolio_analytics_cache
from app.services.market_price_service import MarketPriceService
from app.services.portfolio_calculation_engine import LedgerHolding, PortfolioCalculationEngine
from app.repositories.trade_reconciliation import TradeReconciliationRepository
from app.services.reconciliation_accounting import ConfirmedReconciliationTransfer

Q8 = Decimal("0.00000001")
ZERO = Decimal("0.00000000")
HUNDRED = Decimal("100")
logger = logging.getLogger(__name__)

POSITION_AFFECTING_TRANSACTION_TYPES = {
    TransactionType.BUY,
    TransactionType.SELL,
    TransactionType.CAPITAL_INCREASE_BONUS,
    TransactionType.STOCK_SPLIT,
    TransactionType.PRE_EMPTIVE_RIGHTS,
}


def q8(value: Decimal | int | float) -> Decimal:
    return Decimal(str(value)).quantize(Q8, rounding=ROUND_HALF_EVEN)


@dataclass(slots=True)
class _RunningPosition:
    quantity: Decimal = ZERO
    weighted_avg_cost: Decimal = ZERO
    total_cost_basis: Decimal = ZERO
    cumulative_realized_pnl: Decimal = ZERO
    trade_count: int = 0
    warnings: list[str] | None = None


@dataclass(slots=True, frozen=True)
class PortfolioRecomputeResult:
    portfolio_id: uuid.UUID
    positions_rebuilt: int
    transactions_repriced: int
    snapshot_date: date
    completed_at: datetime


class PortfolioStateRecomputeService:
    """Rebuild mutable portfolio state from immutable ledgers."""

    def __init__(self, db: AsyncSession) -> None:
        self.db = db

    async def recompute_portfolio_state(
        self,
        *,
        portfolio_id: uuid.UUID,
        rebuild_positions: bool = True,
        commit: bool = True,
    ) -> PortfolioRecomputeResult:
        started_at = datetime.now(UTC)
        logger.info(
            "portfolio_recompute_started",
            extra={
                "portfolio_id": str(portfolio_id),
                "rebuild_positions": rebuild_positions,
                "started_at": started_at.isoformat(),
            },
        )
        transactions = await self._load_transactions(portfolio_id=portfolio_id)
        transfers = await TradeReconciliationRepository(
            self.db
        ).confirmed_transfers_for_portfolio(portfolio_id=portfolio_id)
        has_position_events = rebuild_positions and any(
            transaction.transaction_type in POSITION_AFFECTING_TRANSACTION_TYPES
            for transaction in transactions
        )
        if has_position_events:
            positions_by_asset, transactions_repriced = self._replay_positions(
                transactions=transactions,
                portfolio_id=portfolio_id,
                transfers=transfers,
            )
            active_positions = {
                asset_id: position
                for asset_id, position in positions_by_asset.items()
                if position.quantity > ZERO
            }
            persisted_positions = {
                asset_id: position
                for asset_id, position in positions_by_asset.items()
                if position.quantity > ZERO or position.cumulative_realized_pnl != ZERO
            }
            await self._replace_positions(
                portfolio_id=portfolio_id,
                active_positions=persisted_positions,
            )
        else:
            active_positions = await self._load_existing_positions(portfolio_id=portfolio_id)
            transactions_repriced = 0

        snapshot_day = datetime.now(UTC).date()
        await self._upsert_snapshots(
            portfolio_id=portfolio_id,
            positions_by_asset=active_positions,
            snapshot_day=snapshot_day,
        )
        if commit:
            await self.db.commit()
        else:
            await self.db.flush()

        # Versioned cache invalidation keeps read-side APIs coherent post-import.
        await invalidate_portfolio_analytics_cache(portfolio_id=portfolio_id)
        await invalidate_portfolio_benchmark_cache(
            portfolio_id=portfolio_id,
            redis_client=get_redis(),
        )
        completed_at = datetime.now(UTC)
        logger.info(
            "portfolio_recompute_completed",
            extra={
                "portfolio_id": str(portfolio_id),
                "positions_rebuilt": len(active_positions),
                "transactions_repriced": transactions_repriced,
                "snapshot_date": snapshot_day.isoformat(),
                "completed_at": completed_at.isoformat(),
            },
        )
        return PortfolioRecomputeResult(
            portfolio_id=portfolio_id,
            positions_rebuilt=len(active_positions),
            transactions_repriced=transactions_repriced,
            snapshot_date=snapshot_day,
            completed_at=completed_at,
        )

    async def _load_transactions(self, *, portfolio_id: uuid.UUID) -> list[Transaction]:
        result = await self.db.execute(
            select(Transaction)
            .where(Transaction.portfolio_id == portfolio_id)
            .order_by(
                Transaction.executed_at.asc(),
                Transaction.source_row_number.asc(),
                Transaction.created_at.asc(),
                Transaction.id.asc(),
            )
        )
        return list(result.scalars().all())

    async def _load_existing_positions(self, *, portfolio_id: uuid.UUID) -> dict[uuid.UUID, _RunningPosition]:
        result = await self.db.execute(
            select(AssetPosition).where(
                AssetPosition.portfolio_id == portfolio_id,
                AssetPosition.total_quantity > ZERO,
            )
        )
        rows = list(result.scalars().all())
        existing: dict[uuid.UUID, _RunningPosition] = {}
        for row in rows:
            existing[row.asset_id] = _RunningPosition(
                quantity=q8(row.total_quantity),
                weighted_avg_cost=q8(row.weighted_avg_cost),
                total_cost_basis=q8(row.total_cost_basis),
                cumulative_realized_pnl=q8(row.cumulative_realized_pnl),
                trade_count=int(row.trade_count),
            )
        return existing

    def _replay_positions(
        self,
        *,
        transactions: list[Transaction],
        portfolio_id: uuid.UUID | None = None,
        transfers: list[ConfirmedReconciliationTransfer] | None = None,
    ) -> tuple[dict[uuid.UUID, _RunningPosition], int]:
        confirmed_transfers = transfers or []
        ledger_positions = PortfolioCalculationEngine().replay_transactions(
            transactions,
            # Transactions are immutable source events. Recompute only replaces
            # derived position/snapshot projections.
            update_transactions=False,
            incoming_transfers=[
                item
                for item in confirmed_transfers
                if portfolio_id is not None and item.destination_portfolio_id == portfolio_id
            ],
            outgoing_transfers=[
                item
                for item in confirmed_transfers
                if portfolio_id is not None and item.source_portfolio_id == portfolio_id
            ],
        )
        positions = {
            asset_id: _RunningPosition(
                quantity=holding.quantity,
                weighted_avg_cost=holding.average_cost,
                total_cost_basis=holding.cost_basis,
                cumulative_realized_pnl=holding.realized_pnl,
                trade_count=holding.trade_count,
                warnings=holding.warnings,
            )
            for asset_id, holding in ledger_positions.items()
        }
        transactions_repriced = 0
        return positions, transactions_repriced

    async def _replace_positions(
        self,
        *,
        portfolio_id: uuid.UUID,
        active_positions: dict[uuid.UUID, _RunningPosition],
    ) -> None:
        await self.db.execute(
            delete(AssetPosition).where(AssetPosition.portfolio_id == portfolio_id)
        )

        now = datetime.now(UTC).replace(tzinfo=None)
        for asset_id, position in active_positions.items():
            self.db.add(
                AssetPosition(
                    portfolio_id=portfolio_id,
                    asset_id=asset_id,
                    total_quantity=position.quantity,
                    weighted_avg_cost=position.weighted_avg_cost,
                    total_cost_basis=position.total_cost_basis,
                    cumulative_realized_pnl=position.cumulative_realized_pnl,
                    trade_count=position.trade_count,
                    last_updated=now,
                )
            )

    async def _upsert_snapshots(
        self,
        *,
        portfolio_id: uuid.UUID,
        positions_by_asset: dict[uuid.UUID, _RunningPosition],
        snapshot_day: date,
    ) -> None:
        asset_ids = list(positions_by_asset.keys())
        assets_by_id: dict[uuid.UUID, Asset] = {}
        if asset_ids:
            assets_result = await self.db.execute(
                select(Asset).where(Asset.id.in_(asset_ids))
            )
            assets_by_id = {asset.id: asset for asset in assets_result.scalars().all()}

        total_market_value = ZERO
        total_cost_basis = ZERO
        total_known_gain_loss = ZERO
        breakdown_rows: list[dict[str, str | float]] = []
        price_service = MarketPriceService()
        engine = PortfolioCalculationEngine()

        await self.db.execute(
            delete(HoldingSnapshot).where(
                HoldingSnapshot.portfolio_id == portfolio_id,
                HoldingSnapshot.snapshot_date == snapshot_day,
            )
        )

        for asset_id, position in positions_by_asset.items():
            asset = assets_by_id.get(asset_id)
            if asset is None:
                continue
            selected = price_service.select_from_asset(asset, use_case="eod")
            valued = engine.value_holding(
                holding=LedgerHolding(
                    asset_id=asset_id,
                    quantity=position.quantity,
                    average_cost=position.weighted_avg_cost,
                    cost_basis=position.total_cost_basis,
                    realized_pnl=position.cumulative_realized_pnl,
                    warnings=position.warnings or [],
                ),
                asset=asset,
                selected_price=selected,
            )
            market_price = valued.current_price
            market_value = valued.market_value
            unrealized_pnl = valued.unrealized_pnl
            weight_pct = ZERO
            if market_value is not None:
                total_market_value = q8(total_market_value + market_value)
            if unrealized_pnl is not None:
                total_known_gain_loss = q8(total_known_gain_loss + unrealized_pnl)
            total_cost_basis = q8(total_cost_basis + position.total_cost_basis)

            self.db.add(
                HoldingSnapshot(
                    portfolio_id=portfolio_id,
                    asset_id=asset_id,
                    snapshot_date=snapshot_day,
                    quantity=position.quantity,
                    average_cost=position.weighted_avg_cost,
                    cost_basis=position.total_cost_basis,
                    market_price=market_price,
                    market_value=market_value,
                    unrealized_pnl=unrealized_pnl,
                    weight_pct=weight_pct,
                    source_metadata={
                        "recomputed": True,
                        "selected_price_source": selected.selected_price_source,
                        "current_price_type": valued.current_price_type,
                        "data_status": valued.data_status,
                        "warnings": valued.warnings,
                        "status": selected.status,
                        "price_as_of": selected.price_as_of.isoformat() if selected.price_as_of else None,
                    },
                )
            )

            breakdown_rows.append(
                {
                    "asset_id": str(asset_id),
                    "ticker": asset.ticker_symbol,
                    "quantity": float(position.quantity),
                    "avg_cost": float(position.weighted_avg_cost),
                    "market_price": float(market_price) if market_price is not None else None,
                    "market_value": float(market_value) if market_value is not None else None,
                    "gain_loss": float(unrealized_pnl) if unrealized_pnl is not None else None,
                    "weight_pct": 0.0,
                    "selected_price_source": selected.selected_price_source,
                    "current_price_type": valued.current_price_type,
                    "data_status": valued.data_status,
                    "warnings": valued.warnings,
                    "status": selected.status,
                }
            )

        if total_market_value > ZERO:
            for row in breakdown_rows:
                if row["market_value"] is None:
                    continue
                market_value = q8(Decimal(str(row["market_value"])))
                row["weight_pct"] = float(q8((market_value / total_market_value) * HUNDRED))

        gain_loss = total_known_gain_loss
        gain_loss_pct = ZERO if total_cost_basis == ZERO else q8((gain_loss / total_cost_basis) * HUNDRED)

        cash_result = await self.db.execute(
            select(func.coalesce(func.sum(PortfolioCashTransaction.amount), ZERO)).where(
                PortfolioCashTransaction.portfolio_id == portfolio_id
            )
        )
        cash_balance = q8(cash_result.scalar_one() or ZERO)

        snapshot_result = await self.db.execute(
            select(PortfolioSnapshot).where(
                PortfolioSnapshot.portfolio_id == portfolio_id,
                PortfolioSnapshot.snapshot_date == snapshot_day,
            )
        )
        snapshot = snapshot_result.scalar_one_or_none()
        holdings_breakdown: dict[str, list[dict[str, str | float]]] = {"rows": breakdown_rows}
        if snapshot is None:
            self.db.add(
                PortfolioSnapshot(
                    portfolio_id=portfolio_id,
                    snapshot_date=snapshot_day,
                    total_market_value=total_market_value,
                    total_cost_basis=total_cost_basis,
                    total_gain_loss=gain_loss,
                    total_gain_loss_pct=gain_loss_pct,
                    cash_balance=cash_balance,
                    holdings_breakdown=holdings_breakdown,
                )
            )
            return

        snapshot.total_market_value = total_market_value
        snapshot.total_cost_basis = total_cost_basis
        snapshot.total_gain_loss = gain_loss
        snapshot.total_gain_loss_pct = gain_loss_pct
        snapshot.cash_balance = cash_balance
        snapshot.holdings_breakdown = holdings_breakdown
