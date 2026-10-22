"""Canonical portfolio ledger replay and valuation formulas."""

from __future__ import annotations

import uuid
from dataclasses import dataclass, field
from datetime import datetime
from decimal import Decimal, ROUND_HALF_UP
from typing import Any

from app.models.enums import TransactionType
from app.services.market_price_service import SelectedMarketPrice
from app.services.money_normalization import MoneyUnit, normalize_market_price
from app.services.reconciliation_accounting import ConfirmedReconciliationTransfer


Q8 = Decimal("0.00000001")
HUNDRED = Decimal("100")
ZERO = Decimal("0.00000000")


def q8(value: Decimal | int | float | str) -> Decimal:
    return Decimal(str(value)).quantize(Q8, rounding=ROUND_HALF_UP)


def safe_pct(numerator: Decimal, denominator: Decimal) -> Decimal:
    if denominator <= ZERO:
        return ZERO
    return q8((numerator / denominator) * HUNDRED)


@dataclass(slots=True)
class LedgerHolding:
    asset_id: uuid.UUID
    quantity: Decimal = ZERO
    average_cost: Decimal = ZERO
    cost_basis: Decimal = ZERO
    realized_pnl: Decimal = ZERO
    trade_count: int = 0
    warnings: list[str] = field(default_factory=list)


@dataclass(slots=True, frozen=True)
class ValuedHolding:
    asset_id: uuid.UUID
    symbol: str
    quantity: Decimal
    average_cost: Decimal
    remaining_cost_basis: Decimal
    current_price: Decimal | None
    current_price_type: str
    current_price_source: str
    current_price_date: datetime | None
    market_value: Decimal | None
    unrealized_pnl: Decimal | None
    unrealized_pnl_percent: Decimal
    realized_pnl: Decimal
    total_pnl: Decimal
    total_pnl_percent: Decimal
    data_status: str
    warnings: list[str]
    selected_price: SelectedMarketPrice


@dataclass(slots=True, frozen=True)
class PortfolioCalculationSummary:
    holdings: list[ValuedHolding]
    total_cost_basis: Decimal
    total_market_value: Decimal
    total_unrealized_pnl: Decimal
    total_unrealized_pnl_percent: Decimal
    total_realized_pnl: Decimal
    total_cash_balance: Decimal
    total_portfolio_value: Decimal
    holdings_count: int
    missing_market_price_count: int
    warnings: list[str]


class PortfolioCalculationEngine:
    """Weighted-average-cost portfolio calculation engine."""

    def __init__(self, *, money_unit: MoneyUnit = MoneyUnit.IRR, market_price_unit: MoneyUnit = MoneyUnit.IRR) -> None:
        self.money_unit = money_unit
        self.market_price_unit = market_price_unit

    def replay_transactions(
        self,
        transactions: list[Any],
        *,
        update_transactions: bool = False,
        incoming_transfers: list[ConfirmedReconciliationTransfer] | None = None,
        outgoing_transfers: list[ConfirmedReconciliationTransfer] | None = None,
    ) -> dict[uuid.UUID, LedgerHolding]:
        holdings: dict[uuid.UUID, LedgerHolding] = {}

        incoming_by_sell: dict[uuid.UUID, list[ConfirmedReconciliationTransfer]] = {}
        for transfer in incoming_transfers or []:
            incoming_by_sell.setdefault(transfer.sell_transaction_id, []).append(transfer)

        events: list[tuple[tuple[datetime, int, datetime, str], str, Any]] = [
            (self._sort_key(transaction), "transaction", transaction)
            for transaction in transactions
        ]
        for transfer in outgoing_transfers or []:
            events.append(
                (
                    (transfer.effective_at, -1, transfer.effective_at, str(transfer.allocation_id)),
                    "transfer_out",
                    transfer,
                )
            )

        for _event_key, event_type, event in sorted(events, key=lambda item: item[0]):
            if event_type == "transfer_out":
                self._apply_outgoing_transfer(holdings=holdings, transfer=event)
                continue

            transaction = event
            if transaction.transaction_type not in {
                TransactionType.BUY,
                TransactionType.SELL,
                TransactionType.PRE_EMPTIVE_RIGHTS,
                TransactionType.CAPITAL_INCREASE_BONUS,
                TransactionType.STOCK_SPLIT,
            }:
                continue

            asset_id = transaction.asset_id
            holding = holdings.setdefault(asset_id, LedgerHolding(asset_id=asset_id))
            old_average_cost = holding.average_cost
            realized_pnl = ZERO

            quantity = q8(transaction.quantity)
            unit_price = q8(transaction.price_per_unit)
            fees = q8(getattr(transaction, "fees", ZERO) or ZERO)

            if transaction.transaction_type in {TransactionType.BUY, TransactionType.PRE_EMPTIVE_RIGHTS}:
                trade_cost = self._buy_cost(transaction=transaction, quantity=quantity, unit_price=unit_price, fees=fees)
                new_quantity = q8(holding.quantity + quantity)
                holding.cost_basis = q8(holding.cost_basis + trade_cost)
                holding.quantity = new_quantity
                holding.average_cost = ZERO if new_quantity <= ZERO else q8(holding.cost_basis / new_quantity)
                holding.trade_count += 1
            elif transaction.transaction_type == TransactionType.SELL:
                transfers = incoming_by_sell.get(getattr(transaction, "id", None), [])
                if not transfers and quantity > holding.quantity:
                    message = (
                        f"SELL quantity {format(quantity, 'f')} exceeds available "
                        f"{format(holding.quantity, 'f')} for asset {asset_id}."
                    )
                    holding.warnings.append(message)
                    if update_transactions:
                        transaction.wac_at_execution = old_average_cost
                        transaction.realized_pnl = ZERO
                    continue
                external_quantity = q8(sum((item.quantity for item in transfers), ZERO))
                if external_quantity > quantity:
                    holding.warnings.append(
                        f"Confirmed reconciliation quantity {external_quantity} exceeds SELL quantity {quantity}."
                    )
                    external_quantity = quantity
                local_requested = q8(max(ZERO, quantity - external_quantity))
                local_executed = q8(min(local_requested, holding.quantity))
                matched_quantity = q8(external_quantity + local_executed)
                if matched_quantity <= ZERO:
                    message = (
                        f"SELL quantity {format(quantity, 'f')} exceeds available "
                        f"{format(holding.quantity, 'f')} for asset {asset_id}."
                    )
                    holding.warnings.append(message)
                    if update_transactions:
                        transaction.wac_at_execution = old_average_cost
                        transaction.realized_pnl = ZERO
                    continue

                full_proceeds = self._sell_proceeds(
                    transaction=transaction,
                    quantity=quantity,
                    unit_price=unit_price,
                    fees=fees,
                )
                external_proceeds = q8(sum((item.sell_proceeds for item in transfers), ZERO))
                external_cost = q8(sum((item.buy_cost for item in transfers), ZERO))
                local_proceeds = (
                    ZERO
                    if quantity <= ZERO
                    else q8(full_proceeds * local_executed / quantity)
                )
                proceeds = q8(external_proceeds + local_proceeds)
                local_cost = q8(old_average_cost * local_executed)
                cost_of_sold = q8(local_cost + external_cost)
                realized_pnl = q8(proceeds - cost_of_sold)
                holding.quantity = q8(holding.quantity - local_executed)
                holding.cost_basis = q8(holding.cost_basis - local_cost)
                if holding.quantity <= ZERO:
                    holding.quantity = ZERO
                    holding.cost_basis = ZERO
                    holding.average_cost = ZERO
                else:
                    holding.average_cost = old_average_cost
                holding.realized_pnl = q8(holding.realized_pnl + realized_pnl)
                holding.trade_count += 1
                unmatched = q8(quantity - matched_quantity)
                if unmatched > ZERO:
                    holding.warnings.append(
                        f"SELL has unmatched quantity {format(unmatched, 'f')} for asset {asset_id}."
                    )
            elif transaction.transaction_type == TransactionType.CAPITAL_INCREASE_BONUS:
                new_quantity = q8(holding.quantity + quantity)
                holding.quantity = new_quantity
                holding.average_cost = ZERO if new_quantity <= ZERO else q8(holding.cost_basis / new_quantity)
                holding.trade_count += 1
            elif transaction.transaction_type == TransactionType.STOCK_SPLIT:
                new_quantity = q8(holding.quantity + quantity)
                holding.quantity = new_quantity
                holding.average_cost = ZERO if new_quantity <= ZERO else q8(holding.cost_basis / new_quantity)
                holding.trade_count += 1

            if update_transactions:
                transaction.wac_at_execution = old_average_cost
                transaction.realized_pnl = realized_pnl

        return holdings

    @staticmethod
    def _apply_outgoing_transfer(
        *,
        holdings: dict[uuid.UUID, LedgerHolding],
        transfer: ConfirmedReconciliationTransfer,
    ) -> None:
        holding = holdings.setdefault(
            transfer.asset_id,
            LedgerHolding(asset_id=transfer.asset_id),
        )
        quantity = q8(transfer.quantity)
        if quantity > holding.quantity:
            holding.warnings.append(
                f"Reconciliation transfer {transfer.allocation_id} exceeds source quantity."
            )
            return
        removed_cost = q8(transfer.buy_cost)
        if removed_cost > holding.cost_basis:
            holding.warnings.append(
                f"Reconciliation transfer {transfer.allocation_id} cost exceeds source cost basis."
            )
            removed_cost = holding.cost_basis
        holding.quantity = q8(holding.quantity - quantity)
        holding.cost_basis = q8(holding.cost_basis - removed_cost)
        if holding.quantity <= ZERO:
            holding.quantity = ZERO
            holding.cost_basis = ZERO
            holding.average_cost = ZERO
        else:
            holding.average_cost = q8(holding.cost_basis / holding.quantity)

    def value_holding(
        self,
        *,
        holding: LedgerHolding,
        asset: Any,
        selected_price: SelectedMarketPrice,
    ) -> ValuedHolding:
        symbol = str(getattr(asset, "ticker_symbol", getattr(asset, "symbol", "")))
        warnings = list(holding.warnings)
        current_price = normalize_market_price(
            selected_price.selected_valuation_price,
            source_unit=self.market_price_unit,
            target_unit=self.money_unit,
        )

        if current_price is None:
            market_value = None
            unrealized_pnl = None
            unrealized_pct = ZERO
            data_status = "missing_market_price"
            warnings.append("missing_market_price")
        else:
            market_value = q8(holding.quantity * current_price)
            unrealized_pnl = q8(market_value - holding.cost_basis)
            unrealized_pct = safe_pct(unrealized_pnl, holding.cost_basis)
            data_status = "stale_market_price" if selected_price.is_stale else "ok"

        total_pnl = q8(holding.realized_pnl + (unrealized_pnl or ZERO))
        total_pnl_percent = safe_pct(total_pnl, holding.cost_basis)
        return ValuedHolding(
            asset_id=holding.asset_id,
            symbol=symbol,
            quantity=holding.quantity,
            average_cost=holding.average_cost,
            remaining_cost_basis=holding.cost_basis,
            current_price=current_price,
            current_price_type=self._price_type(selected_price),
            current_price_source=f"{self._price_type(selected_price)}:{selected_price.selected_price_source}",
            current_price_date=selected_price.price_as_of,
            market_value=market_value,
            unrealized_pnl=unrealized_pnl,
            unrealized_pnl_percent=unrealized_pct,
            realized_pnl=holding.realized_pnl,
            total_pnl=total_pnl,
            total_pnl_percent=total_pnl_percent,
            data_status=data_status,
            warnings=warnings,
            selected_price=selected_price,
        )

    def summarize(self, *, holdings: list[ValuedHolding], cash_balance: Decimal = ZERO) -> PortfolioCalculationSummary:
        total_cost_basis = q8(sum((item.remaining_cost_basis for item in holdings), ZERO))
        known_market_values = [item.market_value for item in holdings if item.market_value is not None]
        total_market_value = q8(sum((item or ZERO for item in known_market_values), ZERO))
        known_unrealized = [item.unrealized_pnl for item in holdings if item.unrealized_pnl is not None]
        total_unrealized_pnl = q8(sum((item or ZERO for item in known_unrealized), ZERO))
        total_realized_pnl = q8(sum((item.realized_pnl for item in holdings), ZERO))
        total_cash_balance = q8(cash_balance)
        missing_count = len([item for item in holdings if item.market_value is None])
        warnings = [warning for item in holdings for warning in item.warnings]
        return PortfolioCalculationSummary(
            holdings=holdings,
            total_cost_basis=total_cost_basis,
            total_market_value=total_market_value,
            total_unrealized_pnl=total_unrealized_pnl,
            total_unrealized_pnl_percent=safe_pct(total_unrealized_pnl, total_cost_basis),
            total_realized_pnl=total_realized_pnl,
            total_cash_balance=total_cash_balance,
            total_portfolio_value=q8(total_market_value + total_cash_balance),
            holdings_count=len(holdings),
            missing_market_price_count=missing_count,
            warnings=warnings,
        )

    @staticmethod
    def _sort_key(transaction: Any) -> tuple[datetime, int, datetime, str]:
        metadata = getattr(transaction, "source_metadata", None) or {}
        source_row_number = getattr(transaction, "source_row_number", None)
        if source_row_number is None:
            source_row_number = metadata.get("source_row_number") or 0
        executed_at = getattr(transaction, "executed_at", None) or datetime.min
        created_at = getattr(transaction, "created_at", None) or executed_at
        return (
            executed_at,
            int(source_row_number or 0),
            created_at,
            str(getattr(transaction, "id", "")),
        )

    @staticmethod
    def _buy_cost(*, transaction: Any, quantity: Decimal, unit_price: Decimal, fees: Decimal) -> Decimal:
        net_amount = q8(getattr(transaction, "net_amount", ZERO) or ZERO)
        if net_amount > ZERO:
            return net_amount
        total_amount = q8(getattr(transaction, "total_amount", ZERO) or ZERO)
        if total_amount > ZERO:
            return total_amount
        return q8((quantity * unit_price) + fees)

    @staticmethod
    def _sell_proceeds(*, transaction: Any, quantity: Decimal, unit_price: Decimal, fees: Decimal) -> Decimal:
        net_amount = q8(getattr(transaction, "net_amount", ZERO) or ZERO)
        if net_amount > ZERO:
            return net_amount
        total_amount = q8(getattr(transaction, "total_amount", ZERO) or ZERO)
        if total_amount > ZERO:
            return total_amount
        return q8((quantity * unit_price) - fees)

    @staticmethod
    def _price_type(selected_price: SelectedMarketPrice) -> str:
        if selected_price.selected_valuation_price is None:
            return "MISSING"
        if selected_price.source.upper().startswith("MANUAL"):
            return "MANUAL"
        if selected_price.source.upper().startswith("MOCK"):
            return "MOCK"
        return "TSETMC"
