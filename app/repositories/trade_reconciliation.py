"""Persistence queries for cross-portfolio trade reconciliation."""

from __future__ import annotations

import uuid
from dataclasses import dataclass
from datetime import datetime
from decimal import Decimal

from sqlalchemy import and_, func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models.enums import ReconciliationStatus, TransactionType
from app.models.portfolio import Portfolio
from app.models.trade_reconciliation import (
    TradeReconciliation,
    TradeReconciliationAllocation,
    TradeReconciliationAuditEvent,
)
from app.models.transaction import Transaction
from app.services.reconciliation_accounting import ConfirmedReconciliationTransfer

ZERO = Decimal("0.00000000")


@dataclass(slots=True, frozen=True)
class TradeContext:
    transaction: Transaction
    user_id: uuid.UUID
    portfolio_name: str
    portfolio_is_active: bool
    manager_type: str
    broker_metadata: dict | None


class TradeReconciliationRepository:
    def __init__(self, db: AsyncSession) -> None:
        self.db = db

    async def add(self, reconciliation: TradeReconciliation) -> TradeReconciliation:
        self.db.add(reconciliation)
        await self.db.flush()
        return reconciliation

    async def add_audit_event(self, event: TradeReconciliationAuditEvent) -> None:
        self.db.add(event)
        await self.db.flush()

    async def audit_events(
        self,
        *,
        reconciliation_id: uuid.UUID,
    ) -> list[TradeReconciliationAuditEvent]:
        stmt = (
            select(TradeReconciliationAuditEvent)
            .where(TradeReconciliationAuditEvent.reconciliation_id == reconciliation_id)
            .order_by(TradeReconciliationAuditEvent.created_at.asc())
        )
        result = await self.db.execute(stmt)
        return list(result.scalars().all())

    async def get_case(
        self,
        reconciliation_id: uuid.UUID,
        *,
        user_id: uuid.UUID | None = None,
        for_update: bool = False,
    ) -> TradeReconciliation | None:
        stmt = (
            select(TradeReconciliation)
            .options(selectinload(TradeReconciliation.allocations))
            .where(TradeReconciliation.id == reconciliation_id)
        )
        if user_id is not None:
            stmt = stmt.where(TradeReconciliation.user_id == user_id)
        if for_update:
            stmt = stmt.with_for_update()
        result = await self.db.execute(stmt)
        return result.scalar_one_or_none()

    async def get_trade_context(
        self,
        transaction_id: uuid.UUID,
        *,
        for_update: bool = False,
    ) -> TradeContext | None:
        stmt = (
            select(Transaction, Portfolio)
            .join(Portfolio, Portfolio.id == Transaction.portfolio_id)
            .where(Transaction.id == transaction_id)
        )
        if for_update:
            stmt = stmt.with_for_update()
        result = await self.db.execute(stmt)
        row = result.one_or_none()
        if row is None:
            return None
        transaction, portfolio = row
        manager_type = getattr(portfolio.manager_type, "value", portfolio.manager_type)
        return TradeContext(
            transaction=transaction,
            user_id=portfolio.user_id,
            portfolio_name=portfolio.name,
            portfolio_is_active=portfolio.is_active,
            manager_type=str(manager_type),
            broker_metadata=portfolio.broker_metadata,
        )

    async def available_buy_quantity(
        self,
        buy_transaction_id: uuid.UUID,
        *,
        exclude_reconciliation_id: uuid.UUID | None = None,
    ) -> Decimal:
        transaction = await self.db.get(Transaction, buy_transaction_id)
        if transaction is None or transaction.transaction_type != TransactionType.BUY:
            return ZERO
        allocated = await self._confirmed_allocation_sum(
            buy_transaction_id=buy_transaction_id,
            exclude_reconciliation_id=exclude_reconciliation_id,
        )
        return max(ZERO, Decimal(transaction.quantity) - allocated)

    async def unmatched_sell_quantity(
        self,
        sell_transaction_id: uuid.UUID,
        *,
        exclude_reconciliation_id: uuid.UUID | None = None,
    ) -> Decimal:
        transaction = await self.db.get(Transaction, sell_transaction_id)
        if transaction is None or transaction.transaction_type != TransactionType.SELL:
            return ZERO
        stmt = (
            select(func.coalesce(func.sum(TradeReconciliationAllocation.matched_quantity), ZERO))
            .join(
                TradeReconciliation,
                TradeReconciliation.id == TradeReconciliationAllocation.reconciliation_id,
            )
            .where(
                TradeReconciliation.sell_transaction_id == sell_transaction_id,
                TradeReconciliation.status == ReconciliationStatus.CONFIRMED,
            )
        )
        if exclude_reconciliation_id is not None:
            stmt = stmt.where(TradeReconciliation.id != exclude_reconciliation_id)
        result = await self.db.execute(stmt)
        allocated = Decimal(result.scalar_one() or ZERO)
        return max(ZERO, Decimal(transaction.quantity) - allocated)

    async def _confirmed_allocation_sum(
        self,
        *,
        buy_transaction_id: uuid.UUID,
        exclude_reconciliation_id: uuid.UUID | None = None,
    ) -> Decimal:
        stmt = (
            select(func.coalesce(func.sum(TradeReconciliationAllocation.matched_quantity), ZERO))
            .join(
                TradeReconciliation,
                TradeReconciliation.id == TradeReconciliationAllocation.reconciliation_id,
            )
            .where(
                TradeReconciliationAllocation.buy_transaction_id == buy_transaction_id,
                TradeReconciliation.status == ReconciliationStatus.CONFIRMED,
            )
        )
        if exclude_reconciliation_id is not None:
            stmt = stmt.where(TradeReconciliation.id != exclude_reconciliation_id)
        result = await self.db.execute(stmt)
        return Decimal(result.scalar_one() or ZERO)

    async def links_by_transaction(
        self,
        *,
        transaction_id: uuid.UUID,
        user_id: uuid.UUID,
    ) -> list[TradeReconciliation]:
        allocation_cases = select(TradeReconciliationAllocation.reconciliation_id).where(
            TradeReconciliationAllocation.buy_transaction_id == transaction_id
        )
        stmt = (
            select(TradeReconciliation)
            .options(selectinload(TradeReconciliation.allocations))
            .where(
                TradeReconciliation.user_id == user_id,
                or_(
                    TradeReconciliation.sell_transaction_id == transaction_id,
                    TradeReconciliation.id.in_(allocation_cases),
                ),
            )
            .order_by(TradeReconciliation.created_at.desc())
        )
        result = await self.db.execute(stmt)
        return list(result.scalars().unique().all())

    async def links_by_user(
        self,
        *,
        user_id: uuid.UUID,
        statuses: set[ReconciliationStatus] | None = None,
    ) -> list[TradeReconciliation]:
        stmt = (
            select(TradeReconciliation)
            .options(selectinload(TradeReconciliation.allocations))
            .where(TradeReconciliation.user_id == user_id)
        )
        if statuses:
            stmt = stmt.where(TradeReconciliation.status.in_(statuses))
        result = await self.db.execute(stmt.order_by(TradeReconciliation.created_at.desc()))
        return list(result.scalars().unique().all())

    async def links_by_asset(
        self,
        *,
        user_id: uuid.UUID,
        asset_id: uuid.UUID,
        statuses: set[ReconciliationStatus] | None = None,
    ) -> list[TradeReconciliation]:
        stmt = (
            select(TradeReconciliation)
            .options(selectinload(TradeReconciliation.allocations))
            .where(
                TradeReconciliation.user_id == user_id,
                TradeReconciliation.asset_id == asset_id,
            )
        )
        if statuses:
            stmt = stmt.where(TradeReconciliation.status.in_(statuses))
        result = await self.db.execute(stmt.order_by(TradeReconciliation.created_at.desc()))
        return list(result.scalars().unique().all())

    async def active_confirmed_links(
        self,
        *,
        user_id: uuid.UUID | None = None,
        portfolio_id: uuid.UUID | None = None,
        asset_id: uuid.UUID | None = None,
    ) -> list[TradeReconciliation]:
        stmt = (
            select(TradeReconciliation)
            .options(selectinload(TradeReconciliation.allocations))
            .where(TradeReconciliation.status == ReconciliationStatus.CONFIRMED)
        )
        if user_id is not None:
            stmt = stmt.where(TradeReconciliation.user_id == user_id)
        if asset_id is not None:
            stmt = stmt.where(TradeReconciliation.asset_id == asset_id)
        if portfolio_id is not None:
            allocation_cases = select(TradeReconciliationAllocation.reconciliation_id).where(
                TradeReconciliationAllocation.source_portfolio_id == portfolio_id
            )
            stmt = stmt.where(
                or_(
                    TradeReconciliation.destination_portfolio_id == portfolio_id,
                    TradeReconciliation.id.in_(allocation_cases),
                )
            )
        result = await self.db.execute(stmt.order_by(TradeReconciliation.confirmed_at.asc()))
        return list(result.scalars().unique().all())

    async def active_suggestions(
        self,
        *,
        user_id: uuid.UUID,
        asset_id: uuid.UUID | None = None,
    ) -> list[TradeReconciliation]:
        stmt = (
            select(TradeReconciliation)
            .options(selectinload(TradeReconciliation.allocations))
            .where(
                TradeReconciliation.user_id == user_id,
                TradeReconciliation.status == ReconciliationStatus.SUGGESTED,
            )
        )
        if asset_id is not None:
            stmt = stmt.where(TradeReconciliation.asset_id == asset_id)
        result = await self.db.execute(stmt.order_by(TradeReconciliation.created_at.desc()))
        return list(result.scalars().unique().all())

    async def list_user_asset_transactions(
        self,
        *,
        user_id: uuid.UUID,
        asset_id: uuid.UUID,
        executed_at_lte: datetime | None = None,
        active_portfolios_only: bool = True,
    ) -> list[TradeContext]:
        stmt = (
            select(Transaction, Portfolio)
            .join(Portfolio, Portfolio.id == Transaction.portfolio_id)
            .where(
                Portfolio.user_id == user_id,
                Transaction.asset_id == asset_id,
            )
        )
        if executed_at_lte is not None:
            stmt = stmt.where(Transaction.executed_at <= executed_at_lte)
        if active_portfolios_only:
            stmt = stmt.where(Portfolio.is_active.is_(True))
        result = await self.db.execute(
            stmt.order_by(
                Transaction.executed_at.asc(),
                Transaction.source_row_number.asc(),
                Transaction.created_at.asc(),
            )
        )
        contexts: list[TradeContext] = []
        for transaction, portfolio in result.all():
            manager_type = getattr(portfolio.manager_type, "value", portfolio.manager_type)
            contexts.append(
                TradeContext(
                    transaction=transaction,
                    user_id=portfolio.user_id,
                    portfolio_name=portfolio.name,
                    portfolio_is_active=portfolio.is_active,
                    manager_type=str(manager_type),
                    broker_metadata=portfolio.broker_metadata,
                )
            )
        return contexts

    async def has_active_case_for_sell(
        self,
        *,
        user_id: uuid.UUID,
        sell_transaction_id: uuid.UUID,
    ) -> bool:
        stmt = select(func.count(TradeReconciliation.id)).where(
            TradeReconciliation.user_id == user_id,
            TradeReconciliation.sell_transaction_id == sell_transaction_id,
            TradeReconciliation.status.in_(
                {ReconciliationStatus.SUGGESTED, ReconciliationStatus.CONFIRMED}
            ),
        )
        result = await self.db.execute(stmt)
        return int(result.scalar_one() or 0) > 0

    async def confirmed_transfers_for_portfolio(
        self,
        *,
        portfolio_id: uuid.UUID,
    ) -> list[ConfirmedReconciliationTransfer]:
        cases = await self.active_confirmed_links(portfolio_id=portfolio_id)
        transfers: list[ConfirmedReconciliationTransfer] = []
        for reconciliation in cases:
            sell = await self.db.get(Transaction, reconciliation.sell_transaction_id)
            if sell is None:
                continue
            for allocation in reconciliation.allocations:
                if allocation.allocated_buy_cost is None or allocation.allocated_sell_proceeds is None:
                    continue
                transfers.append(
                    ConfirmedReconciliationTransfer(
                        allocation_id=allocation.id,
                        reconciliation_id=reconciliation.id,
                        asset_id=reconciliation.asset_id,
                        buy_transaction_id=allocation.buy_transaction_id,
                        sell_transaction_id=reconciliation.sell_transaction_id,
                        source_portfolio_id=allocation.source_portfolio_id,
                        destination_portfolio_id=reconciliation.destination_portfolio_id,
                        effective_at=sell.executed_at,
                        quantity=Decimal(allocation.matched_quantity),
                        buy_cost=Decimal(allocation.allocated_buy_cost),
                        sell_proceeds=Decimal(allocation.allocated_sell_proceeds),
                    )
                )
        return transfers
