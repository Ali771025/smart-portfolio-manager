"""Development-only, ownership-scoped portfolio valuation diagnostics."""

from __future__ import annotations

import uuid
from decimal import Decimal
from typing import Any

from fastapi import HTTPException, status
from sqlalchemy import or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.asset import Asset
from app.models.asset_position import AssetPosition
from app.models.enums import TransactionType
from app.models.market_data import DailyPrice
from app.models.portfolio import Portfolio
from app.models.transaction import Transaction
from app.schemas.valuation_diagnostic import (
    ValuationDiagnosticAnomalies,
    ValuationDiagnosticFinalCalculation,
    ValuationDiagnosticMarketPrice,
    ValuationDiagnosticMetadata,
    ValuationDiagnosticPosition,
    ValuationDiagnosticReplayStep,
    ValuationDiagnosticResponse,
    ValuationDiagnosticTransaction,
)
from app.services.market_price_service import MarketPriceService
from app.services.portfolio_calculation_engine import PortfolioCalculationEngine, q8
from app.services.symbol_normalization import normalize_symbol_key

ZERO = Decimal("0.00000000")
POSITION_TYPES = {
    TransactionType.BUY,
    TransactionType.SELL,
    TransactionType.PRE_EMPTIVE_RIGHTS,
    TransactionType.CAPITAL_INCREASE_BONUS,
    TransactionType.STOCK_SPLIT,
}


def _decimal(value: Any, default: Decimal = ZERO) -> Decimal:
    if value is None:
        return default
    return q8(Decimal(str(value)))


def _taxes(transaction: Transaction) -> Decimal:
    explicit = getattr(transaction, "taxes", None) or getattr(transaction, "tax", None)
    if explicit is not None:
        return _decimal(explicit)
    metadata = transaction.source_metadata or {}
    return _decimal(metadata.get("taxes", metadata.get("tax", ZERO)))


def _transaction_source(transaction: Transaction) -> str | None:
    if transaction.source_broker:
        return transaction.source_broker
    metadata = transaction.source_metadata or {}
    value = metadata.get("source") or metadata.get("broker")
    return str(value) if value else "manual"


def _selected_asset_price_source(selected_source: str) -> str:
    if selected_source == "last_price":
        return "asset.last_trade_price"
    if selected_source in {"fallback", "closing_price"}:
        return "asset.closing_price"
    if selected_source == "final_price":
        return "asset.current_price"
    return selected_source or "missing"


def _is_cost_fallback(source: str) -> bool:
    normalized = source.lower().replace("-", "_")
    return normalized in {
        "wac",
        "weighted_avg_cost",
        "cost_basis",
        "position_cost",
        "average_cost",
    } or "cost_fallback" in normalized or "wac_fallback" in normalized


def build_ledger_simulation(
    transactions: list[Transaction],
) -> tuple[list[ValuationDiagnosticReplayStep], Decimal, Decimal, Decimal, Decimal]:
    """Replay one symbol with the same WAC rules as the canonical engine."""

    engine = PortfolioCalculationEngine()
    quantity = ZERO
    wac = ZERO
    cost_basis = ZERO
    realized_total = ZERO
    steps: list[ValuationDiagnosticReplayStep] = []

    for transaction in sorted(transactions, key=engine._sort_key):
        before_quantity = quantity
        before_wac = wac
        before_cost_basis = cost_basis
        transaction_quantity = _decimal(transaction.quantity)
        unit_price = _decimal(transaction.price_per_unit)
        fees = _decimal(transaction.fees)
        realized_delta = ZERO
        action = transaction.transaction_type.value

        if transaction.transaction_type in {TransactionType.BUY, TransactionType.PRE_EMPTIVE_RIGHTS}:
            trade_cost = engine._buy_cost(
                transaction=transaction,
                quantity=transaction_quantity,
                unit_price=unit_price,
                fees=fees,
            )
            quantity = q8(quantity + transaction_quantity)
            cost_basis = q8(cost_basis + trade_cost)
            wac = ZERO if quantity <= ZERO else q8(cost_basis / quantity)
        elif transaction.transaction_type == TransactionType.SELL:
            if transaction_quantity > quantity:
                action = "SELL_REJECTED_EXCEEDS_HOLDING"
            else:
                proceeds = engine._sell_proceeds(
                    transaction=transaction,
                    quantity=transaction_quantity,
                    unit_price=unit_price,
                    fees=fees,
                )
                removed_cost = q8(wac * transaction_quantity)
                realized_delta = q8(proceeds - removed_cost)
                realized_total = q8(realized_total + realized_delta)
                quantity = q8(quantity - transaction_quantity)
                cost_basis = q8(cost_basis - removed_cost)
                if quantity <= ZERO:
                    quantity = ZERO
                    cost_basis = ZERO
                    wac = ZERO
        elif transaction.transaction_type in {
            TransactionType.CAPITAL_INCREASE_BONUS,
            TransactionType.STOCK_SPLIT,
        }:
            quantity = q8(quantity + transaction_quantity)
            wac = ZERO if quantity <= ZERO else q8(cost_basis / quantity)
        elif transaction.transaction_type not in POSITION_TYPES:
            action = f"IGNORED_{transaction.transaction_type.value}"

        steps.append(
            ValuationDiagnosticReplayStep(
                transaction_id=transaction.id,
                date=transaction.executed_at,
                before_quantity=before_quantity,
                before_wac=before_wac,
                before_cost_basis=before_cost_basis,
                action=action,
                quantity=transaction_quantity,
                price=unit_price,
                net_amount=(
                    _decimal(transaction.net_amount)
                    if transaction.net_amount is not None
                    else None
                ),
                after_quantity=quantity,
                after_wac=wac,
                after_cost_basis=cost_basis,
                realized_pnl_delta=realized_delta,
            )
        )

    return steps, quantity, wac, cost_basis, realized_total


class ValuationDiagnosticService:
    def __init__(self, db: AsyncSession) -> None:
        self.db = db

    async def build(
        self,
        *,
        portfolio_id: uuid.UUID,
        user_id: uuid.UUID,
        symbol_input: str,
    ) -> ValuationDiagnosticResponse:
        normalized_symbol = normalize_symbol_key(symbol_input)
        if not normalized_symbol:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Symbol not found")

        portfolio_result = await self.db.execute(
            select(Portfolio).where(
                Portfolio.id == portfolio_id,
                Portfolio.user_id == user_id,
                Portfolio.is_active.is_(True),
            )
        )
        portfolio = portfolio_result.scalar_one_or_none()
        if portfolio is None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Portfolio not found")

        asset_result = await self.db.execute(
            select(Asset)
            .join(Transaction, Transaction.asset_id == Asset.id)
            .where(
                Transaction.portfolio_id == portfolio_id,
                or_(
                    Asset.normalized_symbol == normalized_symbol,
                    Asset.ticker_symbol == normalized_symbol,
                ),
            )
            .order_by(Transaction.executed_at.asc())
            .limit(1)
        )
        asset = asset_result.scalar_one_or_none()
        if asset is None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Symbol not found in portfolio")

        position_result = await self.db.execute(
            select(AssetPosition).where(
                AssetPosition.portfolio_id == portfolio_id,
                AssetPosition.asset_id == asset.id,
            )
        )
        position = position_result.scalar_one_or_none()

        daily_result = await self.db.execute(
            select(DailyPrice)
            .where(DailyPrice.asset_id == asset.id)
            .order_by(DailyPrice.date.desc(), DailyPrice.price_time.desc())
            .limit(1)
        )
        daily_price = daily_result.scalar_one_or_none()

        transaction_result = await self.db.execute(
            select(Transaction)
            .where(
                Transaction.portfolio_id == portfolio_id,
                Transaction.asset_id == asset.id,
            )
            .order_by(
                Transaction.executed_at.asc(),
                Transaction.source_row_number.asc(),
                Transaction.created_at.asc(),
                Transaction.id.asc(),
            )
        )
        transactions = list(transaction_result.scalars().all())
        steps, quantity, wac, cost_basis, realized_pnl = build_ledger_simulation(transactions)

        selected = MarketPriceService().select_from_asset(asset, use_case="live")
        selected_price = (
            q8(selected.selected_valuation_price)
            if selected.selected_valuation_price is not None
            else None
        )
        selected_source = _selected_asset_price_source(selected.selected_price_source)
        warnings = list(selected.warnings)
        has_market_price = selected_price is not None

        if has_market_price:
            market_value = q8(quantity * selected_price)
            unrealized_pnl = q8(market_value - cost_basis)
            total_pnl = q8(realized_pnl + unrealized_pnl)
            calculation_status = "complete"
        else:
            market_value = None
            unrealized_pnl = None
            total_pnl = None
            calculation_status = "missing_market_price"

        ratio_mismatch = False
        if selected_price is not None and wac > ZERO:
            ratio = selected_price / wac
            ratio_mismatch = ratio > Decimal("100") or ratio < Decimal("0.01")

        stored_realized = _decimal(
            position.cumulative_realized_pnl if position is not None else realized_pnl
        )
        has_sell = any(transaction.transaction_type == TransactionType.SELL for transaction in transactions)
        currency = getattr(portfolio.base_currency, "value", str(portfolio.base_currency))
        daily_close = (
            _decimal(daily_price.close_price)
            if daily_price is not None
            and daily_price.close_price is not None
            and daily_price.close_price > ZERO
            else None
        )

        return ValuationDiagnosticResponse(
            metadata=ValuationDiagnosticMetadata(
                portfolio_id=portfolio_id,
                symbol_input=symbol_input,
                normalized_symbol=normalized_symbol,
                asset_id=asset.id,
                asset_symbol=asset.ticker_symbol,
                currency=currency,
            ),
            position=ValuationDiagnosticPosition(
                total_quantity=_decimal(position.total_quantity if position is not None else quantity),
                weighted_avg_cost=_decimal(position.weighted_avg_cost if position is not None else wac),
                total_cost_basis=_decimal(position.total_cost_basis if position is not None else cost_basis),
                cumulative_realized_pnl=stored_realized,
                last_recomputed_at=(position.last_updated if position is not None else None),
            ),
            market_price_resolution=ValuationDiagnosticMarketPrice(
                daily_price_found=daily_close is not None,
                daily_price_date=daily_price.date if daily_close is not None else None,
                daily_price_close_price=daily_close,
                asset_last_trade_price=_decimal(asset.last_trade_price),
                asset_closing_price=_decimal(asset.closing_price),
                selected_price=selected_price,
                selected_price_source=selected_source,
                has_market_price=has_market_price,
                warnings=warnings,
            ),
            transactions=[
                ValuationDiagnosticTransaction(
                    id=transaction.id,
                    date=transaction.executed_at,
                    type=transaction.transaction_type.value,
                    quantity=_decimal(transaction.quantity),
                    unit_price=_decimal(transaction.price_per_unit),
                    gross_amount=q8(_decimal(transaction.quantity) * _decimal(transaction.price_per_unit)),
                    net_amount=(
                        _decimal(transaction.net_amount)
                        if transaction.net_amount is not None
                        else None
                    ),
                    fees=_decimal(transaction.fees),
                    taxes=_taxes(transaction),
                    total_amount=_decimal(transaction.total_amount),
                    realized_pnl=_decimal(transaction.realized_pnl),
                    wac_at_execution=(
                        _decimal(transaction.wac_at_execution)
                        if transaction.wac_at_execution is not None
                        else None
                    ),
                    source=_transaction_source(transaction),
                    import_id=transaction.import_batch_id,
                    created_at=transaction.created_at,
                )
                for transaction in transactions
            ],
            recomputed_ledger_simulation=steps,
            final_calculation=ValuationDiagnosticFinalCalculation(
                remaining_quantity=quantity,
                average_cost=wac,
                cost_basis=cost_basis,
                current_price=selected_price,
                market_value=market_value,
                unrealized_pnl=unrealized_pnl,
                realized_pnl=realized_pnl,
                total_pnl=total_pnl,
                calculation_status=calculation_status,
            ),
            anomaly_flags=ValuationDiagnosticAnomalies(
                current_price_equals_wac=selected_price is not None and wac > ZERO and selected_price == wac,
                price_source_is_fallback=_is_cost_fallback(selected_source),
                missing_market_price=not has_market_price,
                realized_pnl_without_sell=stored_realized != ZERO and not has_sell,
                suspicious_realized_pnl_abs_gt_cost_basis=abs(stored_realized) > abs(cost_basis),
                net_amount_missing=any(transaction.net_amount is None for transaction in transactions),
                unit_mismatch_suspected=ratio_mismatch,
            ),
        )
