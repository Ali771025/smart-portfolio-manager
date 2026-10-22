"""Cross-portfolio reconciliation lifecycle, validation, and suggestions."""

from __future__ import annotations

import uuid
from dataclasses import dataclass
from datetime import UTC, datetime
from decimal import Decimal, ROUND_HALF_UP

from sqlalchemy.ext.asyncio import AsyncSession

from app.models.enums import (
    ReconciliationAuditAction,
    ReconciliationMatchingMethod,
    ReconciliationStatus,
    TransactionType,
)
from app.models.trade_reconciliation import (
    TradeReconciliation,
    TradeReconciliationAllocation,
    TradeReconciliationAuditEvent,
)
from app.models.transaction import Transaction
from app.repositories.trade_reconciliation import TradeContext, TradeReconciliationRepository

Q8 = Decimal("0.00000001")
ZERO = Decimal("0.00000000")
MIN_SUGGESTION_CONFIDENCE = Decimal("0.6500")
MAX_SUGGESTION_CONFIDENCE = Decimal("0.9900")


def q8(value: Decimal | int | str) -> Decimal:
    return Decimal(str(value)).quantize(Q8, rounding=ROUND_HALF_UP)


@dataclass(slots=True, frozen=True)
class AllocationRequest:
    buy_transaction_id: uuid.UUID
    quantity: Decimal


@dataclass(slots=True, frozen=True)
class AllocationImpactPreview:
    allocation_id: uuid.UUID
    buy_transaction_id: uuid.UUID
    matched_quantity: Decimal
    allocated_buy_cost: Decimal
    allocated_sell_proceeds: Decimal
    realized_pnl: Decimal


@dataclass(slots=True, frozen=True)
class ReconciliationImpact:
    reconciliation: TradeReconciliation
    allocations: list[AllocationImpactPreview]
    matched_quantity: Decimal
    remaining_sell_quantity: Decimal
    realized_pnl: Decimal


class TradeReconciliationError(Exception):
    def __init__(self, *, code: str, detail: str, status_code: int = 409) -> None:
        super().__init__(detail)
        self.code = code
        self.detail = detail
        self.status_code = status_code


class TradeReconciliationService:
    def __init__(
        self,
        db: AsyncSession,
        *,
        repository: TradeReconciliationRepository | None = None,
        recompute_on_transition: bool = True,
    ) -> None:
        self.db = db
        self.repository = repository or TradeReconciliationRepository(db)
        self.recompute_on_transition = recompute_on_transition

    async def create_manual_reconciliation(
        self,
        *,
        user_id: uuid.UUID,
        sell_transaction_id: uuid.UUID,
        allocations: list[AllocationRequest],
        notes: str | None = None,
    ) -> TradeReconciliation:
        return await self._create_case(
            user_id=user_id,
            sell_transaction_id=sell_transaction_id,
            allocations=allocations,
            matching_method=ReconciliationMatchingMethod.MANUAL,
            confidence_score=None,
            rationale={"reason": "manual_cross_portfolio_allocation"},
            notes=notes,
        )

    async def create_suggestion(
        self,
        *,
        user_id: uuid.UUID,
        sell_transaction_id: uuid.UUID,
        allocations: list[AllocationRequest],
        confidence_score: Decimal,
        rationale: dict,
    ) -> TradeReconciliation:
        if confidence_score < ZERO or confidence_score > Decimal("1"):
            self._raise("invalid-confidence", "Confidence score must be between zero and one.", 422)
        return await self._create_case(
            user_id=user_id,
            sell_transaction_id=sell_transaction_id,
            allocations=allocations,
            matching_method=ReconciliationMatchingMethod.AUTO,
            confidence_score=q8(confidence_score).quantize(Decimal("0.0001")),
            rationale=rationale,
            notes=None,
        )

    async def _create_case(
        self,
        *,
        user_id: uuid.UUID,
        sell_transaction_id: uuid.UUID,
        allocations: list[AllocationRequest],
        matching_method: ReconciliationMatchingMethod,
        confidence_score: Decimal | None,
        rationale: dict,
        notes: str | None,
    ) -> TradeReconciliation:
        if not allocations:
            self._raise("empty-allocation", "At least one buy allocation is required.", 422)
        buy_ids = [item.buy_transaction_id for item in allocations]
        if len(buy_ids) != len(set(buy_ids)):
            self._raise("duplicate-allocation", "A buy transaction may appear only once per case.")
        if await self.repository.has_active_case_for_sell(
            user_id=user_id,
            sell_transaction_id=sell_transaction_id,
        ):
            self._raise("active-case-exists", "An active reconciliation already exists for this sell.")

        sell = await self._required_trade_context(sell_transaction_id)
        self._validate_sell(sell=sell, user_id=user_id)
        unmatched_sell = await self.repository.unmatched_sell_quantity(sell_transaction_id)
        requested_total = q8(sum((q8(item.quantity) for item in allocations), ZERO))
        if requested_total > unmatched_sell:
            self._raise(
                "sell-allocation-overflow",
                f"Requested quantity {requested_total} exceeds unmatched sell quantity {unmatched_sell}.",
            )

        source_open = await self._source_open_quantities(sell=sell, user_id=user_id)
        entities: list[TradeReconciliationAllocation] = []
        for requested in allocations:
            quantity = q8(requested.quantity)
            if quantity <= ZERO:
                self._raise("invalid-quantity", "Allocation quantity must be greater than zero.", 422)
            buy = await self._required_trade_context(requested.buy_transaction_id)
            self._validate_buy(sell=sell, buy=buy, user_id=user_id)
            available = await self.repository.available_buy_quantity(requested.buy_transaction_id)
            if quantity > available:
                self._raise(
                    "buy-allocation-overflow",
                    f"Requested quantity {quantity} exceeds available buy quantity {available}.",
                )
            portfolio_available = source_open.get(buy.transaction.portfolio_id, ZERO)
            if quantity > portfolio_available:
                self._raise(
                    "source-inventory-overflow",
                    f"Source portfolio has only {portfolio_available} open units at the sell time.",
                )
            source_open[buy.transaction.portfolio_id] = q8(portfolio_available - quantity)
            entities.append(
                TradeReconciliationAllocation(
                    buy_transaction_id=requested.buy_transaction_id,
                    source_portfolio_id=buy.transaction.portfolio_id,
                    matched_quantity=quantity,
                )
            )

        reconciliation = TradeReconciliation(
            user_id=user_id,
            asset_id=sell.transaction.asset_id,
            sell_transaction_id=sell_transaction_id,
            destination_portfolio_id=sell.transaction.portfolio_id,
            status=ReconciliationStatus.SUGGESTED,
            matching_method=matching_method,
            confidence_score=confidence_score,
            notes=notes,
            rationale=rationale,
            created_by_user_id=user_id,
            updated_by_user_id=user_id,
            allocations=entities,
        )
        await self.repository.add(reconciliation)
        await self._audit(
            reconciliation=reconciliation,
            actor_user_id=user_id,
            action=ReconciliationAuditAction.CREATED,
            reason=notes,
            metadata={
                "matching_method": matching_method.value,
                "matched_quantity": str(requested_total),
                "rationale": rationale,
            },
        )
        await self.db.commit()
        return reconciliation

    async def confirm(
        self,
        *,
        user_id: uuid.UUID,
        reconciliation_id: uuid.UUID,
        notes: str | None = None,
    ) -> TradeReconciliation:
        impact = await self._calculate_confirmation_impact(
            user_id=user_id,
            reconciliation_id=reconciliation_id,
            for_update=True,
        )
        reconciliation = impact.reconciliation
        for allocation, allocation_impact in zip(
            reconciliation.allocations,
            impact.allocations,
            strict=True,
        ):
            allocation.allocated_buy_cost = allocation_impact.allocated_buy_cost
            allocation.allocated_sell_proceeds = allocation_impact.allocated_sell_proceeds
            allocation.realized_pnl = allocation_impact.realized_pnl

        now = datetime.now(UTC)
        reconciliation.status = ReconciliationStatus.CONFIRMED
        reconciliation.updated_by_user_id = user_id
        reconciliation.confirmed_by_user_id = user_id
        reconciliation.confirmed_at = now
        if notes:
            reconciliation.notes = notes
        await self._audit(
            reconciliation=reconciliation,
            actor_user_id=user_id,
            action=ReconciliationAuditAction.CONFIRMED,
            reason=notes,
            metadata={
                "matched_quantity": str(impact.matched_quantity),
                "realized_pnl": str(impact.realized_pnl),
            },
        )
        await self._recompute_affected_portfolios(reconciliation)
        await self.db.commit()
        return reconciliation

    async def preview_confirmation(
        self,
        *,
        user_id: uuid.UUID,
        reconciliation_id: uuid.UUID,
    ) -> ReconciliationImpact:
        """Validate current inventory and calculate confirmation impact without mutation."""

        return await self._calculate_confirmation_impact(
            user_id=user_id,
            reconciliation_id=reconciliation_id,
            for_update=False,
        )

    async def _calculate_confirmation_impact(
        self,
        *,
        user_id: uuid.UUID,
        reconciliation_id: uuid.UUID,
        for_update: bool,
    ) -> ReconciliationImpact:
        reconciliation = await self._required_case(
            reconciliation_id=reconciliation_id,
            user_id=user_id,
            for_update=for_update,
        )
        self._require_status(reconciliation, {ReconciliationStatus.SUGGESTED}, "confirm")
        sell = await self._required_trade_context(
            reconciliation.sell_transaction_id,
            for_update=for_update,
        )
        self._validate_sell(sell=sell, user_id=user_id)

        unmatched_sell = q8(
            await self.repository.unmatched_sell_quantity(
                reconciliation.sell_transaction_id,
                exclude_reconciliation_id=reconciliation.id,
            )
        )
        total = q8(
            sum((allocation.matched_quantity for allocation in reconciliation.allocations), ZERO)
        )
        if total > unmatched_sell:
            self._raise("sell-allocation-overflow", "The sell no longer has enough unmatched quantity.")

        sell_proceeds_total = self._sell_proceeds(sell.transaction)
        source_open = await self._source_open_quantities(sell=sell, user_id=user_id)
        impacts: list[AllocationImpactPreview] = []
        for allocation in reconciliation.allocations:
            buy = await self._required_trade_context(
                allocation.buy_transaction_id,
                for_update=for_update,
            )
            self._validate_buy(sell=sell, buy=buy, user_id=user_id)
            available = await self.repository.available_buy_quantity(
                allocation.buy_transaction_id,
                exclude_reconciliation_id=reconciliation.id,
            )
            quantity = q8(allocation.matched_quantity)
            if quantity > available:
                self._raise("buy-allocation-overflow", "A buy allocation is no longer available.")
            portfolio_available = source_open.get(buy.transaction.portfolio_id, ZERO)
            if quantity > portfolio_available:
                self._raise(
                    "source-inventory-overflow",
                    "The source portfolio no longer has enough inventory at the sell time.",
                )
            source_open[buy.transaction.portfolio_id] = q8(portfolio_available - quantity)

            buy_cost = q8(self._buy_cost(buy.transaction) * quantity / q8(buy.transaction.quantity))
            sell_proceeds = q8(
                sell_proceeds_total * quantity / q8(sell.transaction.quantity)
            )
            impacts.append(
                AllocationImpactPreview(
                    allocation_id=allocation.id,
                    buy_transaction_id=allocation.buy_transaction_id,
                    matched_quantity=quantity,
                    allocated_buy_cost=buy_cost,
                    allocated_sell_proceeds=sell_proceeds,
                    realized_pnl=q8(sell_proceeds - buy_cost),
                )
            )

        return ReconciliationImpact(
            reconciliation=reconciliation,
            allocations=impacts,
            matched_quantity=total,
            remaining_sell_quantity=q8(unmatched_sell - total),
            realized_pnl=q8(sum((item.realized_pnl for item in impacts), ZERO)),
        )

    async def reject(
        self,
        *,
        user_id: uuid.UUID,
        reconciliation_id: uuid.UUID,
        reason: str | None = None,
    ) -> TradeReconciliation:
        reconciliation = await self._required_case(reconciliation_id, user_id=user_id, for_update=True)
        self._require_status(reconciliation, {ReconciliationStatus.SUGGESTED}, "reject")
        reconciliation.status = ReconciliationStatus.REJECTED
        reconciliation.updated_by_user_id = user_id
        reconciliation.rejected_by_user_id = user_id
        reconciliation.rejected_at = datetime.now(UTC)
        await self._audit(
            reconciliation=reconciliation,
            actor_user_id=user_id,
            action=ReconciliationAuditAction.REJECTED,
            reason=reason,
        )
        await self.db.commit()
        return reconciliation

    async def cancel(
        self,
        *,
        user_id: uuid.UUID,
        reconciliation_id: uuid.UUID,
        reason: str | None = None,
    ) -> TradeReconciliation:
        reconciliation = await self._required_case(reconciliation_id, user_id=user_id, for_update=True)
        self._require_status(reconciliation, {ReconciliationStatus.CONFIRMED}, "cancel")
        reconciliation.status = ReconciliationStatus.CANCELED
        reconciliation.updated_by_user_id = user_id
        reconciliation.canceled_by_user_id = user_id
        reconciliation.canceled_at = datetime.now(UTC)
        await self._audit(
            reconciliation=reconciliation,
            actor_user_id=user_id,
            action=ReconciliationAuditAction.CANCELED,
            reason=reason,
        )
        await self._recompute_affected_portfolios(reconciliation)
        await self.db.commit()
        return reconciliation

    async def detect_candidate_for_sell(
        self,
        *,
        user_id: uuid.UUID,
        sell_transaction_id: uuid.UUID,
    ) -> TradeReconciliation | None:
        if await self.repository.has_active_case_for_sell(
            user_id=user_id,
            sell_transaction_id=sell_transaction_id,
        ):
            return None
        sell = await self._required_trade_context(sell_transaction_id)
        self._validate_sell(sell=sell, user_id=user_id)
        if not sell.portfolio_is_active:
            return None

        contexts = await self.repository.list_user_asset_transactions(
            user_id=user_id,
            asset_id=sell.transaction.asset_id,
            executed_at_lte=sell.transaction.executed_at,
            active_portfolios_only=True,
        )
        if any(
            item.transaction.transaction_type
            not in {TransactionType.BUY, TransactionType.SELL}
            for item in contexts
        ):
            return None
        open_by_portfolio: dict[uuid.UUID, Decimal] = {}
        for context in contexts:
            transaction = context.transaction
            if transaction.id == sell.transaction.id:
                continue
            current = open_by_portfolio.get(transaction.portfolio_id, ZERO)
            if transaction.transaction_type == TransactionType.BUY:
                current = q8(current + transaction.quantity)
            elif transaction.transaction_type == TransactionType.SELL:
                current = q8(max(ZERO, current - transaction.quantity))
            open_by_portfolio[transaction.portfolio_id] = current

        local_quantity = open_by_portfolio.get(sell.transaction.portfolio_id, ZERO)
        deficit = q8(max(ZERO, q8(sell.transaction.quantity) - local_quantity))
        if deficit <= ZERO:
            return None

        candidate_buys = [
            context
            for context in contexts
            if context.transaction.transaction_type == TransactionType.BUY
            and context.transaction.portfolio_id != sell.transaction.portfolio_id
        ]
        candidate_buys.sort(
            key=lambda context: abs(
                (sell.transaction.executed_at - context.transaction.executed_at).total_seconds()
            )
        )

        remaining = deficit
        allocations: list[AllocationRequest] = []
        source_portfolios: list[dict[str, str]] = []
        for candidate in candidate_buys:
            source_open = open_by_portfolio.get(candidate.transaction.portfolio_id, ZERO)
            if source_open <= ZERO or remaining <= ZERO:
                continue
            available = await self.repository.available_buy_quantity(candidate.transaction.id)
            quantity = q8(min(remaining, source_open, available))
            if quantity <= ZERO:
                continue
            allocations.append(
                AllocationRequest(
                    buy_transaction_id=candidate.transaction.id,
                    quantity=quantity,
                )
            )
            open_by_portfolio[candidate.transaction.portfolio_id] = q8(source_open - quantity)
            remaining = q8(remaining - quantity)
            source_portfolios.append(
                {
                    "portfolio_id": str(candidate.transaction.portfolio_id),
                    "portfolio_name": candidate.portfolio_name,
                    "manager_type": candidate.manager_type,
                    "quantity": str(quantity),
                    "date_proximity_days": str(
                        abs((sell.transaction.executed_at - candidate.transaction.executed_at).days)
                    ),
                }
            )

        if not allocations:
            return None
        matched = q8(deficit - remaining)
        coverage = matched / deficit if deficit > ZERO else ZERO
        nearest_days = min(int(item["date_proximity_days"]) for item in source_portfolios)
        proximity = max(Decimal("0"), Decimal("1") - (Decimal(nearest_days) / Decimal("365")))
        exact_fit = Decimal("1") if remaining == ZERO else ZERO
        confidence = min(
            MAX_SUGGESTION_CONFIDENCE,
            Decimal("0.5000")
            + (Decimal("0.3000") * coverage)
            + (Decimal("0.1500") * proximity)
            + (Decimal("0.0400") * exact_fit),
        )
        if confidence < MIN_SUGGESTION_CONFIDENCE:
            return None
        rationale = {
            "reason": "sell_exceeds_local_inventory",
            "canonical_asset_id": str(sell.transaction.asset_id),
            "sell_quantity": str(q8(sell.transaction.quantity)),
            "local_quantity_before_sell": str(local_quantity),
            "quantity_deficit": str(deficit),
            "matched_quantity": str(matched),
            "uncovered_quantity": str(remaining),
            "coverage_ratio": str(q8(coverage)),
            "quantity_fit": "exact" if exact_fit else "partial",
            "nearest_date_distance_days": nearest_days,
            "scoring": {
                "base": "0.5000",
                "coverage_weight": "0.3000",
                "date_proximity_weight": "0.1500",
                "exact_quantity_bonus": "0.0400",
                "minimum_confidence": str(MIN_SUGGESTION_CONFIDENCE),
            },
            "destination_portfolio_id": str(sell.transaction.portfolio_id),
            "destination_portfolio_name": sell.portfolio_name,
            "destination_manager_type": sell.manager_type,
            "sources": source_portfolios,
        }
        return await self.create_suggestion(
            user_id=user_id,
            sell_transaction_id=sell_transaction_id,
            allocations=allocations,
            confidence_score=confidence,
            rationale=rationale,
        )

    async def detect_candidates_for_transactions(
        self,
        *,
        user_id: uuid.UUID,
        transaction_ids: list[uuid.UUID],
    ) -> list[TradeReconciliation]:
        """Idempotently detect suggestions for newly persisted sell transactions."""

        suggestions: list[TradeReconciliation] = []
        for transaction_id in dict.fromkeys(transaction_ids):
            context = await self.repository.get_trade_context(transaction_id)
            if context is None or context.transaction.transaction_type != TransactionType.SELL:
                continue
            suggestion = await self.detect_candidate_for_sell(
                user_id=user_id,
                sell_transaction_id=transaction_id,
            )
            if suggestion is not None:
                suggestions.append(suggestion)
        return suggestions

    async def _required_trade_context(
        self,
        transaction_id: uuid.UUID,
        *,
        for_update: bool = False,
    ) -> TradeContext:
        context = await self.repository.get_trade_context(transaction_id, for_update=for_update)
        if context is None:
            self._raise("transaction-not-found", "Transaction not found.", 404)
        return context

    async def _source_open_quantities(
        self,
        *,
        sell: TradeContext,
        user_id: uuid.UUID,
    ) -> dict[uuid.UUID, Decimal]:
        contexts = await self.repository.list_user_asset_transactions(
            user_id=user_id,
            asset_id=sell.transaction.asset_id,
            executed_at_lte=sell.transaction.executed_at,
            active_portfolios_only=False,
        )
        if any(
            item.transaction.transaction_type
            not in {TransactionType.BUY, TransactionType.SELL}
            for item in contexts
        ):
            self._raise(
                "corporate-action-review-required",
                "Automatic quantity availability is unsafe when corporate actions are present.",
                409,
            )
        open_by_portfolio: dict[uuid.UUID, Decimal] = {}
        for context in contexts:
            transaction = context.transaction
            if transaction.id == sell.transaction.id:
                continue
            current = open_by_portfolio.get(transaction.portfolio_id, ZERO)
            if transaction.transaction_type == TransactionType.BUY:
                current = q8(current + transaction.quantity)
            else:
                current = q8(max(ZERO, current - transaction.quantity))
            open_by_portfolio[transaction.portfolio_id] = current

        confirmed = await self.repository.active_confirmed_links(
            user_id=user_id,
            asset_id=sell.transaction.asset_id,
        )
        for reconciliation in confirmed:
            for allocation in reconciliation.allocations:
                current = open_by_portfolio.get(allocation.source_portfolio_id, ZERO)
                open_by_portfolio[allocation.source_portfolio_id] = q8(
                    max(ZERO, current - allocation.matched_quantity)
                )
        return open_by_portfolio

    async def _required_case(
        self,
        reconciliation_id: uuid.UUID,
        *,
        user_id: uuid.UUID,
        for_update: bool,
    ) -> TradeReconciliation:
        reconciliation = await self.repository.get_case(
            reconciliation_id,
            user_id=user_id,
            for_update=for_update,
        )
        if reconciliation is None:
            self._raise("reconciliation-not-found", "Reconciliation not found.", 404)
        return reconciliation

    def _validate_sell(self, *, sell: TradeContext, user_id: uuid.UUID) -> None:
        if sell.user_id != user_id:
            self._raise("user-mismatch", "Transaction belongs to another user.", 403)
        if sell.transaction.transaction_type != TransactionType.SELL:
            self._raise("invalid-sell", "Destination transaction must be a SELL.", 422)

    def _validate_buy(self, *, sell: TradeContext, buy: TradeContext, user_id: uuid.UUID) -> None:
        if buy.user_id != user_id:
            self._raise("user-mismatch", "Buy and sell must belong to the same user.", 403)
        if buy.transaction.transaction_type != TransactionType.BUY:
            self._raise("invalid-buy", "Source transaction must be a BUY.", 422)
        if buy.transaction.asset_id != sell.transaction.asset_id:
            self._raise("asset-mismatch", "Buy and sell must reference the same canonical asset.", 422)
        if buy.transaction.portfolio_id == sell.transaction.portfolio_id:
            self._raise("same-portfolio", "Reconciliation requires different portfolios.", 422)
        if buy.transaction.executed_at > sell.transaction.executed_at:
            self._raise("buy-after-sell", "Buy transaction cannot occur after the sell.", 422)

    @staticmethod
    def _require_status(
        reconciliation: TradeReconciliation,
        allowed: set[ReconciliationStatus],
        action: str,
    ) -> None:
        if reconciliation.status not in allowed:
            raise TradeReconciliationError(
                code="invalid-status-transition",
                detail=f"Cannot {action} reconciliation in status {reconciliation.status.value}.",
            )

    async def _audit(
        self,
        *,
        reconciliation: TradeReconciliation,
        actor_user_id: uuid.UUID,
        action: ReconciliationAuditAction,
        reason: str | None = None,
        metadata: dict | None = None,
    ) -> None:
        await self.repository.add_audit_event(
            TradeReconciliationAuditEvent(
                reconciliation_id=reconciliation.id,
                actor_user_id=actor_user_id,
                action=action,
                reason=reason,
                event_metadata=metadata,
                created_at=datetime.now(UTC),
            )
        )

    async def _recompute_affected_portfolios(
        self,
        reconciliation: TradeReconciliation,
    ) -> None:
        if not self.recompute_on_transition:
            return
        await self.db.flush()
        from app.services.portfolio_state_recompute_service import PortfolioStateRecomputeService

        portfolio_ids = {reconciliation.destination_portfolio_id}
        portfolio_ids.update(item.source_portfolio_id for item in reconciliation.allocations)
        recompute = PortfolioStateRecomputeService(self.db)
        for portfolio_id in sorted(portfolio_ids, key=str):
            await recompute.recompute_portfolio_state(
                portfolio_id=portfolio_id,
                rebuild_positions=True,
                commit=False,
            )

    @staticmethod
    def _buy_cost(transaction: Transaction) -> Decimal:
        net_amount = q8(transaction.net_amount or ZERO)
        if net_amount > ZERO:
            return net_amount
        total_amount = q8(transaction.total_amount or ZERO)
        if total_amount > ZERO:
            return total_amount
        return q8((transaction.quantity * transaction.price_per_unit) + (transaction.fees or ZERO))

    @staticmethod
    def _sell_proceeds(transaction: Transaction) -> Decimal:
        net_amount = q8(transaction.net_amount or ZERO)
        if net_amount > ZERO:
            return net_amount
        total_amount = q8(transaction.total_amount or ZERO)
        if total_amount > ZERO:
            return total_amount
        return q8((transaction.quantity * transaction.price_per_unit) - (transaction.fees or ZERO))

    @staticmethod
    def _raise(code: str, detail: str, status_code: int = 409) -> None:
        raise TradeReconciliationError(code=code, detail=detail, status_code=status_code)
