"""Repository helpers for portfolio PnL and performance analytics."""

from __future__ import annotations

import uuid
from datetime import date, datetime
from decimal import Decimal

from sqlalchemy import func, inspect, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.asset import Asset
from app.models.asset_position import AssetPosition
from app.models.corporate_action import DividendTransaction
from app.models.enums import BenchmarkType, TransactionType
from app.models.market_data import BenchmarkHistory
from app.models.portfolio import Portfolio
from app.models.cash_transaction import PortfolioCashTransaction
from app.models.transaction import Transaction
from app.repositories.trade_reconciliation import TradeReconciliationRepository
from app.services.reconciliation_accounting import ConfirmedReconciliationTransfer


class PnLRepository:
    """Data access abstraction for advanced PnL computations."""

    def __init__(self, db: AsyncSession) -> None:
        self.db = db
        self._existing_tables: set[str] | None = None

    async def _table_exists(self, table_name: str) -> bool:
        if self._existing_tables is None:
            self._existing_tables = await self.db.run_sync(
                lambda sync_session: set(inspect(sync_session.bind).get_table_names())
            )
        return table_name in self._existing_tables

    async def get_portfolio_for_user(
        self,
        *,
        portfolio_id: uuid.UUID,
        user_id: uuid.UUID,
    ) -> Portfolio | None:
        result = await self.db.execute(
            select(Portfolio).where(
                Portfolio.id == portfolio_id,
                Portfolio.user_id == user_id,
                Portfolio.is_active.is_(True),
            )
        )
        return result.scalar_one_or_none()

    async def fetch_live_positions(self, portfolio_id: uuid.UUID) -> list[tuple[AssetPosition, Asset]]:
        result = await self.db.execute(
            select(AssetPosition, Asset)
            .join(Asset, Asset.id == AssetPosition.asset_id)
            .where(
                AssetPosition.portfolio_id == portfolio_id,
                AssetPosition.total_quantity > Decimal("0.0000"),
            )
            .order_by(AssetPosition.total_cost_basis.desc())
        )
        return list(result.all())

    async def fetch_all_positions(self, portfolio_id: uuid.UUID) -> list[tuple[AssetPosition, Asset]]:
        result = await self.db.execute(
            select(AssetPosition, Asset)
            .join(Asset, Asset.id == AssetPosition.asset_id)
            .where(AssetPosition.portfolio_id == portfolio_id)
            .order_by(Asset.ticker_symbol.asc())
        )
        return list(result.all())

    async def fetch_trade_ledger_with_assets(self, portfolio_id: uuid.UUID) -> list[tuple[Transaction, Asset]]:
        result = await self.db.execute(
            select(Transaction, Asset)
            .join(Asset, Asset.id == Transaction.asset_id)
            .where(Transaction.portfolio_id == portfolio_id)
            .order_by(
                Transaction.executed_at.asc(),
                Transaction.source_row_number.asc(),
                Transaction.created_at.asc(),
                Transaction.id.asc(),
            )
        )
        return list(result.all())

    async def fetch_confirmed_reconciliation_transfers(
        self,
        portfolio_id: uuid.UUID,
    ) -> list[ConfirmedReconciliationTransfer]:
        return await TradeReconciliationRepository(self.db).confirmed_transfers_for_portfolio(
            portfolio_id=portfolio_id
        )

    async def sum_realized_sell_pnl(self, portfolio_id: uuid.UUID) -> Decimal:
        result = await self.db.execute(
            select(func.coalesce(func.sum(Transaction.realized_pnl), Decimal("0.0000"))).where(
                Transaction.portfolio_id == portfolio_id,
                Transaction.transaction_type == TransactionType.SELL,
            )
        )
        return Decimal(result.scalar_one() or Decimal("0.0000"))

    async def sum_dividend_pnl(self, portfolio_id: uuid.UUID) -> Decimal:
        result = await self.db.execute(
            select(func.coalesce(func.sum(DividendTransaction.total_dividend_profit), Decimal("0.0000"))).where(
                DividendTransaction.portfolio_id == portfolio_id,
            )
        )
        return Decimal(result.scalar_one() or Decimal("0.0000"))

    async def sum_cash_event_pnl(self, portfolio_id: uuid.UUID) -> Decimal:
        if not await self._table_exists("portfolio_cash_transactions"):
            return Decimal("0.0000")

        result = await self.db.execute(
            select(func.coalesce(func.sum(PortfolioCashTransaction.amount), Decimal("0.0000"))).where(
                PortfolioCashTransaction.portfolio_id == portfolio_id,
            )
        )
        return Decimal(result.scalar_one() or Decimal("0.0000"))

    async def sum_cash_balance(self, portfolio_id: uuid.UUID) -> Decimal:
        if not await self._table_exists("portfolio_cash_transactions"):
            return Decimal("0.0000")

        result = await self.db.execute(
            select(func.coalesce(func.sum(PortfolioCashTransaction.amount), Decimal("0.0000"))).where(
                PortfolioCashTransaction.portfolio_id == portfolio_id,
            )
        )
        return Decimal(result.scalar_one() or Decimal("0.0000"))

    async def sum_income_cash_flows(self, portfolio_id: uuid.UUID) -> Decimal:
        if not await self._table_exists("portfolio_cash_transactions"):
            return Decimal("0.0000")

        result = await self.db.execute(
            select(func.coalesce(func.sum(PortfolioCashTransaction.amount), Decimal("0.0000"))).where(
                PortfolioCashTransaction.portfolio_id == portfolio_id,
                PortfolioCashTransaction.normalized_type.in_(["DIVIDEND", "FEE", "TAX"]),
            )
        )
        return Decimal(result.scalar_one() or Decimal("0.0000"))

    async def sum_net_cash_contributions(self, portfolio_id: uuid.UUID) -> Decimal:
        if not await self._table_exists("portfolio_cash_transactions"):
            return Decimal("0.0000")

        result = await self.db.execute(
            select(func.coalesce(func.sum(PortfolioCashTransaction.amount), Decimal("0.0000"))).where(
                PortfolioCashTransaction.portfolio_id == portfolio_id,
                PortfolioCashTransaction.normalized_type.in_(
                    ["DEPOSIT", "WITHDRAWAL", "OPENING_CASH_BALANCE"]
                ),
            )
        )
        return Decimal(result.scalar_one() or Decimal("0.0000"))

    async def fetch_transactions_until(
        self,
        *,
        portfolio_id: uuid.UUID,
        end_dt: datetime,
    ) -> list[Transaction]:
        result = await self.db.execute(
            select(Transaction)
            .where(
                Transaction.portfolio_id == portfolio_id,
                Transaction.executed_at <= end_dt,
            )
            .order_by(Transaction.executed_at.asc(), Transaction.created_at.asc())
        )
        return list(result.scalars().all())

    async def fetch_benchmark_history(
        self,
        *,
        benchmark_types: list[BenchmarkType],
        start_date: date,
        end_date: date,
    ) -> list[BenchmarkHistory]:
        result = await self.db.execute(
            select(BenchmarkHistory)
            .where(
                BenchmarkHistory.benchmark_type.in_(benchmark_types),
                BenchmarkHistory.date >= start_date,
                BenchmarkHistory.date <= end_date,
            )
            .order_by(BenchmarkHistory.benchmark_type.asc(), BenchmarkHistory.date.asc())
        )
        return list(result.scalars().all())
