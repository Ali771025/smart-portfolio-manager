"""User-scoped application facade and response projection for reconciliation APIs."""

from __future__ import annotations

import uuid
from collections import defaultdict
from decimal import Decimal

from sqlalchemy.ext.asyncio import AsyncSession

from app.models.asset import Asset
from app.models.enums import ReconciliationStatus
from app.models.trade_reconciliation import TradeReconciliation
from app.repositories.trade_reconciliation import TradeContext, TradeReconciliationRepository
from app.schemas.trade_reconciliation import (
    ReconciliationAllocationInput,
    ReconciliationAllocationRead,
    ReconciliationAuditEventRead,
    ReconciliationAuditMetadata,
    ReconciliationHoldingsImpact,
    ReconciliationImpactPreview,
    ReconciliationTradeInfo,
    TradeReconciliationRead,
)
from app.services.trade_reconciliation_service import (
    AllocationRequest,
    ReconciliationImpact,
    TradeReconciliationError,
    TradeReconciliationService,
    ZERO,
    q8,
)


class TradeReconciliationApiService:
    def __init__(self, db: AsyncSession) -> None:
        self.db = db
        self.repository = TradeReconciliationRepository(db)
        self.domain = TradeReconciliationService(db, repository=self.repository)

    async def list_suggestions(
        self,
        *,
        user_id: uuid.UUID,
        asset_id: uuid.UUID | None = None,
    ) -> list[TradeReconciliationRead]:
        cases = await self.repository.active_suggestions(user_id=user_id, asset_id=asset_id)
        return [await self._project(case) for case in cases]

    async def list_active(
        self,
        *,
        user_id: uuid.UUID,
        status: ReconciliationStatus | None = None,
    ) -> list[TradeReconciliationRead]:
        statuses = (
            {status}
            if status is not None
            else {ReconciliationStatus.SUGGESTED, ReconciliationStatus.CONFIRMED}
        )
        cases = await self.repository.links_by_user(user_id=user_id, statuses=statuses)
        return [await self._project(case) for case in cases]

    async def get_detail(
        self,
        *,
        user_id: uuid.UUID,
        reconciliation_id: uuid.UUID,
    ) -> TradeReconciliationRead:
        case = await self._required_case(user_id=user_id, reconciliation_id=reconciliation_id)
        return await self._project(case)

    async def preview(
        self,
        *,
        user_id: uuid.UUID,
        reconciliation_id: uuid.UUID,
    ) -> ReconciliationImpactPreview:
        impact = await self.domain.preview_confirmation(
            user_id=user_id,
            reconciliation_id=reconciliation_id,
        )
        projected = await self._project(impact.reconciliation, impact=impact)
        return ReconciliationImpactPreview(
            reconciliation_id=projected.reconciliation_id,
            status=projected.status,
            asset_id=projected.asset_id,
            symbol=projected.symbol,
            matched_quantity=projected.matched_quantity,
            remaining_sell_quantity=impact.remaining_sell_quantity,
            estimated_realized_pnl_impact=impact.realized_pnl,
            estimated_holdings_impact=projected.estimated_or_actual_holdings_impact,
            allocations=projected.source_allocations,
        )

    async def create_manual(
        self,
        *,
        user_id: uuid.UUID,
        sell_transaction_id: uuid.UUID,
        allocations: list[ReconciliationAllocationInput],
        notes: str | None,
    ) -> TradeReconciliationRead:
        case = await self.domain.create_manual_reconciliation(
            user_id=user_id,
            sell_transaction_id=sell_transaction_id,
            allocations=[
                AllocationRequest(item.buy_transaction_id, item.quantity) for item in allocations
            ],
            notes=notes,
        )
        return await self._project(case)

    async def confirm(self, *, user_id: uuid.UUID, reconciliation_id: uuid.UUID, notes: str | None) -> TradeReconciliationRead:
        case = await self.domain.confirm(
            user_id=user_id,
            reconciliation_id=reconciliation_id,
            notes=notes,
        )
        return await self._project(case)

    async def reject(self, *, user_id: uuid.UUID, reconciliation_id: uuid.UUID, reason: str | None) -> TradeReconciliationRead:
        case = await self.domain.reject(
            user_id=user_id,
            reconciliation_id=reconciliation_id,
            reason=reason,
        )
        return await self._project(case)

    async def cancel(self, *, user_id: uuid.UUID, reconciliation_id: uuid.UUID, reason: str | None) -> TradeReconciliationRead:
        case = await self.domain.cancel(
            user_id=user_id,
            reconciliation_id=reconciliation_id,
            reason=reason,
        )
        return await self._project(case)

    async def _required_case(
        self,
        *,
        user_id: uuid.UUID,
        reconciliation_id: uuid.UUID,
    ) -> TradeReconciliation:
        case = await self.repository.get_case(reconciliation_id, user_id=user_id)
        if case is None:
            raise TradeReconciliationError(
                code="reconciliation-not-found",
                detail="Reconciliation not found.",
                status_code=404,
            )
        return case

    async def _project(
        self,
        case: TradeReconciliation,
        *,
        impact: ReconciliationImpact | None = None,
    ) -> TradeReconciliationRead:
        sell = await self.repository.get_trade_context(case.sell_transaction_id)
        if sell is None:
            raise TradeReconciliationError(
                code="transaction-not-found",
                detail="Reconciliation sell transaction no longer exists.",
                status_code=404,
            )
        asset = await self.db.get(Asset, case.asset_id)
        symbol = asset.ticker_symbol if asset is not None else str(case.asset_id)
        events = await self.repository.audit_events(reconciliation_id=case.id)

        impact_by_allocation = {
            item.allocation_id: item for item in impact.allocations
        } if impact is not None else {}
        source_impacts: dict[uuid.UUID, Decimal] = defaultdict(lambda: ZERO)
        source_labels: dict[uuid.UUID, str] = {}
        allocation_reads: list[ReconciliationAllocationRead] = []
        total_matched = ZERO
        total_pnl = ZERO
        for allocation in case.allocations:
            buy = await self.repository.get_trade_context(allocation.buy_transaction_id)
            if buy is None:
                raise TradeReconciliationError(
                    code="transaction-not-found",
                    detail="A reconciliation buy transaction no longer exists.",
                    status_code=404,
                )
            quantity = q8(allocation.matched_quantity)
            total_matched = q8(total_matched + quantity)
            available = q8(await self.repository.available_buy_quantity(allocation.buy_transaction_id))
            buy_remaining = available
            if case.status == ReconciliationStatus.SUGGESTED:
                buy_remaining = q8(max(ZERO, available - quantity))

            calculated = impact_by_allocation.get(allocation.id)
            buy_cost = (
                calculated.allocated_buy_cost
                if calculated is not None
                else q8(allocation.allocated_buy_cost or self.domain._buy_cost(buy.transaction) * quantity / q8(buy.transaction.quantity))
            )
            sell_proceeds = (
                calculated.allocated_sell_proceeds
                if calculated is not None
                else q8(allocation.allocated_sell_proceeds or self.domain._sell_proceeds(sell.transaction) * quantity / q8(sell.transaction.quantity))
            )
            pnl = (
                calculated.realized_pnl
                if calculated is not None
                else q8(allocation.realized_pnl if allocation.realized_pnl is not None else sell_proceeds - buy_cost)
            )
            total_pnl = q8(total_pnl + pnl)
            source_impacts[buy.transaction.portfolio_id] = q8(
                source_impacts[buy.transaction.portfolio_id] - quantity
            )
            source_labels[buy.transaction.portfolio_id] = buy.portfolio_name
            allocation_reads.append(
                ReconciliationAllocationRead(
                    allocation_id=allocation.id,
                    buy_transaction=self._trade_info(buy, remaining_quantity=buy_remaining),
                    matched_quantity=quantity,
                    estimated_or_actual_buy_cost=buy_cost,
                    estimated_or_actual_sell_proceeds=sell_proceeds,
                    estimated_or_actual_realized_pnl=pnl,
                )
            )

        unmatched_sell = q8(await self.repository.unmatched_sell_quantity(case.sell_transaction_id))
        remaining_sell = unmatched_sell
        if case.status == ReconciliationStatus.SUGGESTED:
            remaining_sell = q8(max(ZERO, unmatched_sell - total_matched))

        holdings = [
            ReconciliationHoldingsImpact(
                portfolio_id=portfolio_id,
                portfolio_label=source_labels[portfolio_id],
                role="SOURCE",
                quantity_delta=quantity_delta,
            )
            for portfolio_id, quantity_delta in source_impacts.items()
        ]
        holdings.append(
            ReconciliationHoldingsImpact(
                portfolio_id=sell.transaction.portfolio_id,
                portfolio_label=sell.portfolio_name,
                role="DESTINATION",
                quantity_delta=ZERO,
                reconciled_sell_quantity=total_matched,
            )
        )

        return TradeReconciliationRead(
            reconciliation_id=case.id,
            status=case.status,
            matching_method=case.matching_method,
            asset_id=case.asset_id,
            symbol=symbol,
            sell_transaction=self._trade_info(sell, remaining_quantity=remaining_sell),
            source_allocations=allocation_reads,
            matched_quantity=total_matched,
            remaining_sell_quantity=remaining_sell,
            confidence_score=case.confidence_score,
            rationale=case.rationale,
            notes=case.notes,
            estimated_or_actual_realized_pnl_impact=total_pnl,
            estimated_or_actual_holdings_impact=holdings,
            audit=ReconciliationAuditMetadata(
                created_by_user_id=case.created_by_user_id,
                updated_by_user_id=case.updated_by_user_id,
                confirmed_by_user_id=case.confirmed_by_user_id,
                rejected_by_user_id=case.rejected_by_user_id,
                canceled_by_user_id=case.canceled_by_user_id,
                created_at=case.created_at,
                updated_at=case.updated_at,
                confirmed_at=case.confirmed_at,
                rejected_at=case.rejected_at,
                canceled_at=case.canceled_at,
                events=[
                    ReconciliationAuditEventRead(
                        event_id=event.id,
                        action=event.action,
                        actor_user_id=event.actor_user_id,
                        reason=event.reason,
                        metadata=event.event_metadata,
                        created_at=event.created_at,
                    )
                    for event in events
                ],
            ),
        )

    @staticmethod
    def _trade_info(context: TradeContext, *, remaining_quantity: Decimal) -> ReconciliationTradeInfo:
        transaction = context.transaction
        broker_label = getattr(transaction, "source_broker", None)
        if not broker_label and context.broker_metadata:
            broker_label = next(
                (
                    str(context.broker_metadata[key])
                    for key in ("label", "broker_label", "broker_name", "name")
                    if context.broker_metadata.get(key)
                ),
                None,
            )
        if not broker_label and context.manager_type != "UNKNOWN":
            broker_label = context.manager_type
        return ReconciliationTradeInfo(
            transaction_id=transaction.id,
            transaction_type=transaction.transaction_type,
            portfolio_id=transaction.portfolio_id,
            portfolio_label=context.portfolio_name,
            broker_label=broker_label,
            executed_at=transaction.executed_at,
            quantity=q8(transaction.quantity),
            price_per_unit=q8(transaction.price_per_unit),
            fees=q8(transaction.fees or ZERO),
            remaining_quantity=remaining_quantity,
        )
