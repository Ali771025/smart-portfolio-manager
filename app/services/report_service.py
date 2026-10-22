"""Portfolio report service for monthly and yearly analytics.

Computes:
  - Monthly portfolio summary (starting/ending value, PnL, returns)
  - Yearly portfolio summary with monthly breakdown
  - Best/worst performing symbols
  - Data completeness and freshness flags

Assumptions:
  - Uses PortfolioSnapshot for historical market values
  - Uses Transaction history for cash flows (deposits/withdrawals)
  - Cash flows are derived from transaction types: BUY adds to invested,
    SELL reduces holdings, DIVIDEND/DEPOSIT/WITHDRAWAL affect cash balance
  - Monthly values use last available snapshot in each month
  - Partial months/years are handled gracefully
"""

from __future__ import annotations

import logging
import uuid
from dataclasses import dataclass
from datetime import UTC, date, datetime, timedelta
from typing import Any

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.enums import TransactionType
from app.models.market_data import PortfolioSnapshot, DailyPrice
from app.models.portfolio import Portfolio
from app.models.transaction import Transaction

from app.schemas.reports import (
    DataCompleteness,
    MonthlyReportResponse,
    MonthlyReturnPoint,
    PeriodPerformanceDTO,
    ReportPeriod,
    SymbolPerformanceDTO,
    YearlyReportResponse,
    YearlyReturnPoint,
)

logger = logging.getLogger("report_service")

TRADING_DAYS_PER_YEAR = 252


class ReportService:
    """Service for computing portfolio reports."""

    def __init__(self, db: AsyncSession) -> None:
        self.db = db

    async def get_monthly_report(
        self,
        *,
        portfolio_id: uuid.UUID,
        user_id: uuid.UUID,
        year: int,
        month: int,
    ) -> MonthlyReportResponse:
        """Generate monthly portfolio report."""
        logger.info(
            "report.monthly.request portfolio=%s year=%d month=%d",
            portfolio_id, year, month,
        )

        portfolio = await self._get_portfolio(portfolio_id, user_id)
        if portfolio is None:
            raise ValueError(f"Portfolio {portfolio_id} not found")

        period_start = date(year, month, 1)
        if month == 12:
            period_end = date(year + 1, 1, 1) - timedelta(days=1)
        else:
            period_end = date(year, month + 1, 1) - timedelta(days=1)

        # Get snapshots for this month
        snapshots = await self._get_snapshots(
            portfolio_id=portfolio_id,
            start_date=period_start,
            end_date=period_end,
        )

        # Get transactions for cash flow calculation
        transactions = await self._get_transactions(
            portfolio_id=portfolio_id,
            start_date=period_start,
            end_date=period_end,
        )

        # Compute performance
        performance = self._compute_period_performance(
            snapshots=snapshots,
            transactions=transactions,
            period_start=period_start,
            period_end=period_end,
        )

        # Get monthly return series
        monthly_returns = await self._get_monthly_returns_for_period(
            portfolio_id=portfolio_id,
            year=year,
        )

        # Determine data completeness
        data_completeness = self._determine_completeness(
            snapshots=snapshots,
            period_start=period_start,
            period_end=period_end,
        )

        is_stale = self._is_stale(snapshots)

        return MonthlyReportResponse(
            portfolio_id=portfolio_id,
            base_currency=str(portfolio.base_currency.value),
            year=year,
            month=month,
            period_start=period_start,
            period_end=period_end,
            performance=performance,
            monthly_returns=monthly_returns,
            data_completeness=data_completeness,
            is_stale=is_stale,
            generated_at=datetime.now(UTC),
        )

    async def get_yearly_report(
        self,
        *,
        portfolio_id: uuid.UUID,
        user_id: uuid.UUID,
        year: int,
    ) -> YearlyReportResponse:
        """Generate yearly portfolio report."""
        logger.info(
            "report.yearly.request portfolio=%s year=%d",
            portfolio_id, year,
        )

        portfolio = await self._get_portfolio(portfolio_id, user_id)
        if portfolio is None:
            raise ValueError(f"Portfolio {portfolio_id} not found")

        period_start = date(year, 1, 1)
        period_end = date(year, 12, 31)

        # Get snapshots for this year
        snapshots = await self._get_snapshots(
            portfolio_id=portfolio_id,
            start_date=period_start,
            end_date=period_end,
        )

        # Get transactions for cash flow calculation
        transactions = await self._get_transactions(
            portfolio_id=portfolio_id,
            start_date=period_start,
            end_date=period_end,
        )

        # Compute performance
        performance = self._compute_period_performance(
            snapshots=snapshots,
            transactions=transactions,
            period_start=period_start,
            period_end=period_end,
        )

        # Get monthly breakdown
        monthly_breakdown = await self._get_monthly_returns_for_period(
            portfolio_id=portfolio_id,
            year=year,
        )

        # Get yearly returns for historical context
        yearly_returns = await self._get_yearly_returns(
            portfolio_id=portfolio_id,
            end_year=year,
            lookback_years=5,
        )

        # Determine data completeness
        data_completeness = self._determine_completeness(
            snapshots=snapshots,
            period_start=period_start,
            period_end=period_end,
        )

        is_stale = self._is_stale(snapshots)

        return YearlyReportResponse(
            portfolio_id=portfolio_id,
            base_currency=str(portfolio.base_currency.value),
            year=year,
            period_start=period_start,
            period_end=period_end,
            performance=performance,
            monthly_breakdown=monthly_breakdown,
            yearly_returns=yearly_returns,
            data_completeness=data_completeness,
            is_stale=is_stale,
            generated_at=datetime.now(UTC),
        )

    # ═══════════════════════════════════════════════════════════════
    # Data Fetching
    # ═══════════════════════════════════════════════════════════════

    async def _get_portfolio(
        self,
        portfolio_id: uuid.UUID,
        user_id: uuid.UUID,
    ) -> Portfolio | None:
        """Fetch portfolio for user."""
        result = await self.db.execute(
            select(Portfolio).where(
                Portfolio.id == portfolio_id,
                Portfolio.user_id == user_id,
                Portfolio.is_active.is_(True),
            )
        )
        return result.scalar_one_or_none()

    async def _get_snapshots(
        self,
        *,
        portfolio_id: uuid.UUID,
        start_date: date,
        end_date: date,
    ) -> list[PortfolioSnapshot]:
        """Fetch portfolio snapshots for date range."""
        result = await self.db.execute(
            select(PortfolioSnapshot)
            .where(
                PortfolioSnapshot.portfolio_id == portfolio_id,
                PortfolioSnapshot.snapshot_date >= start_date,
                PortfolioSnapshot.snapshot_date <= end_date,
            )
            .order_by(PortfolioSnapshot.snapshot_date.asc())
        )
        return list(result.scalars().all())

    async def _get_transactions(
        self,
        *,
        portfolio_id: uuid.UUID,
        start_date: date,
        end_date: date,
    ) -> list[Transaction]:
        """Fetch transactions for date range."""
        result = await self.db.execute(
            select(Transaction)
            .where(
                Transaction.portfolio_id == portfolio_id,
                Transaction.executed_at >= datetime.combine(start_date, datetime.min.time()),
                Transaction.executed_at <= datetime.combine(end_date, datetime.max.time()),
            )
            .order_by(Transaction.executed_at.asc())
        )
        return list(result.scalars().all())

    async def _get_latest_snapshot_before(
        self,
        *,
        portfolio_id: uuid.UUID,
        before_date: date,
    ) -> PortfolioSnapshot | None:
        """Get latest snapshot before a date."""
        result = await self.db.execute(
            select(PortfolioSnapshot)
            .where(
                PortfolioSnapshot.portfolio_id == portfolio_id,
                PortfolioSnapshot.snapshot_date < before_date,
            )
            .order_by(PortfolioSnapshot.snapshot_date.desc())
            .limit(1)
        )
        return result.scalar_one_or_none()

    # ═══════════════════════════════════════════════════════════════
    # Performance Calculation
    # ═══════════════════════════════════════════════════════════════

    def _compute_period_performance(
        self,
        *,
        snapshots: list[PortfolioSnapshot],
        transactions: list[Transaction],
        period_start: date,
        period_end: date,
    ) -> PeriodPerformanceDTO:
        """Compute performance metrics for a period."""
        
        # Get starting and ending values
        starting_value = self._get_period_start_value(snapshots, period_start)
        ending_value = self._get_period_end_value(snapshots, period_end)
        
        # Calculate net deposits/withdrawals
        net_deposits = self._calculate_net_cash_flows(transactions)
        
        # Calculate PnL
        realized_pnl = self._calculate_realized_pnl(transactions)
        
        # Get unrealized PnL from last snapshot
        unrealized_pnl = None
        if ending_value is not None and snapshots:
            last_snapshot = snapshots[-1]
            unrealized_pnl = float(last_snapshot.total_gain_loss) if last_snapshot.total_gain_loss else None
        
        # Calculate total PnL
        total_pnl = None
        if realized_pnl is not None and unrealized_pnl is not None:
            total_pnl = realized_pnl + unrealized_pnl
        
        # Calculate total return
        total_return_amount = None
        total_return_pct = None
        if starting_value is not None and ending_value is not None:
            total_return_amount = ending_value - starting_value - (net_deposits or 0)
            if starting_value != 0:
                total_return_pct = (total_return_amount / starting_value) * 100
        
        return PeriodPerformanceDTO(
            period_label=f"{period_start.year}-{period_start.month:02d}",
            period_start=period_start,
            period_end=period_end,
            starting_value=starting_value,
            ending_value=ending_value,
            net_deposits=net_deposits,
            realized_pnl=realized_pnl,
            unrealized_pnl=unrealized_pnl,
            total_pnl=total_pnl,
            total_return_amount=total_return_amount,
            total_return_pct=total_return_pct,
            best_performer_symbol=None,
            best_performer_return_pct=None,
            worst_performer_symbol=None,
            worst_performer_return_pct=None,
        )

    def _get_period_start_value(
        self,
        snapshots: list[PortfolioSnapshot],
        period_start: date,
    ) -> float | None:
        """Get portfolio value at period start."""
        if not snapshots:
            return None
        
        # Find first snapshot on or after period_start
        for snapshot in snapshots:
            if snapshot.snapshot_date >= period_start:
                return float(snapshot.total_market_value) if snapshot.total_market_value else None
        
        # If no snapshot on/after start, use first available
        if snapshots:
            return float(snapshots[0].total_market_value) if snapshots[0].total_market_value else None
        
        return None

    def _get_period_end_value(
        self,
        snapshots: list[PortfolioSnapshot],
        period_end: date,
    ) -> float | None:
        """Get portfolio value at period end."""
        if not snapshots:
            return None
        
        # Find last snapshot on or before period_end
        for snapshot in reversed(snapshots):
            if snapshot.snapshot_date <= period_end:
                return float(snapshot.total_market_value) if snapshot.total_market_value else None
        
        # If no snapshot on/before end, use last available
        if snapshots:
            return float(snapshots[-1].total_market_value) if snapshots[-1].total_market_value else None
        
        return None

    def _calculate_net_cash_flows(self, transactions: list[Transaction]) -> float:
        """Calculate net deposits/withdrawals from transactions."""
        net = 0.0
        
        for txn in transactions:
            if txn.transaction_type == TransactionType.BUY:
                # BUY increases invested capital
                net += float(txn.total_amount)
            elif txn.transaction_type == TransactionType.SELL:
                # SELL reduces invested capital
                net -= float(txn.total_amount)
        
        return net

    def _calculate_realized_pnl(self, transactions: list[Transaction]) -> float:
        """Calculate realized PnL from transactions."""
        total_realized = 0.0
        
        for txn in transactions:
            total_realized += float(txn.realized_pnl)
        
        return total_realized

    async def _get_performers(
        self,
        portfolio_id: uuid.UUID,
        start_date: date,
        end_date: date,
    ) -> tuple[tuple[str, float] | None, tuple[str, float] | None]:
        """Get best and worst performing symbols."""
        # Get asset positions with their price changes
        from app.models.asset_position import AssetPosition
        from app.models.asset import Asset
        from app.models.market_data import DailyPrice
        
        # Get positions
        positions_result = await self.db.execute(
            select(AssetPosition, Asset)
            .join(Asset, Asset.id == AssetPosition.asset_id)
            .where(AssetPosition.portfolio_id == portfolio_id)
        )
        positions = positions_result.all()
        
        best = None
        worst = None
        best_return = float('-inf')
        worst_return = float('inf')
        
        for position, asset in positions:
            if position.total_quantity <= 0:
                continue
            
            # Get start and end prices
            start_price = await self._get_price_at_date(
                asset.id, start_date
            )
            end_price = await self._get_price_at_date(
                asset.id, end_date
            )
            
            if start_price is None or end_price is None or start_price == 0:
                continue
            
            ret = ((end_price - start_price) / start_price) * 100
            
            if ret > best_return:
                best_return = ret
                best = (asset.ticker_symbol, round(ret, 2))
            
            if ret < worst_return:
                worst_return = ret
                worst = (asset.ticker_symbol, round(ret, 2))
        
        return best, worst

    async def _get_price_at_date(
        self,
        asset_id: uuid.UUID,
        target_date: date,
    ) -> float | None:
        """Get asset price at or before a specific date."""
        from app.models.market_data import DailyPrice
        
        result = await self.db.execute(
            select(DailyPrice.close_price)
            .where(
                DailyPrice.asset_id == asset_id,
                DailyPrice.date <= target_date,
            )
            .order_by(DailyPrice.date.desc())
            .limit(1)
        )
        row = result.scalar_one_or_none()
        return float(row) if row else None

    # ═══════════════════════════════════════════════════════════════
    # Return Series
    # ═══════════════════════════════════════════════════════════════

    async def _get_monthly_returns_for_period(
        self,
        *,
        portfolio_id: uuid.UUID,
        year: int,
    ) -> list[MonthlyReturnPoint]:
        """Get monthly returns for a year."""
        from app.schemas.reports import MonthlyReturnPoint
        
        points = []
        cumulative_return = 0.0
        
        for month in range(1, 13):
            period_start = date(year, month, 1)
            if month == 12:
                period_end = date(year + 1, 1, 1) - timedelta(days=1)
            else:
                period_end = date(year, month + 1, 1) - timedelta(days=1)
            
            # Get snapshots for this month
            snapshots = await self._get_snapshots(
                portfolio_id=portfolio_id,
                start_date=period_start,
                end_date=period_end,
            )
            
            if not snapshots:
                continue
            
            starting_value = float(snapshots[0].total_market_value) if snapshots[0].total_market_value else None
            ending_value = float(snapshots[-1].total_market_value) if snapshots[-1].total_market_value else None
            
            return_pct = None
            if starting_value and ending_value and starting_value != 0:
                return_pct = round(((ending_value - starting_value) / starting_value) * 100, 2)
                cumulative_return += return_pct
            
            points.append(MonthlyReturnPoint(
                period_date=period_end,
                label=f"{year}-{month:02d}",
                starting_value=starting_value,
                ending_value=ending_value,
                return_pct=return_pct,
                cumulative_return_pct=round(cumulative_return, 2),
            ))
        
        return points

    async def _get_yearly_returns(
        self,
        *,
        portfolio_id: uuid.UUID,
        end_year: int,
        lookback_years: int = 5,
    ) -> list[YearlyReturnPoint]:
        """Get yearly returns for historical context."""
        from app.schemas.reports import YearlyReturnPoint
        
        points = []
        cumulative_return = 0.0
        
        for year in range(end_year - lookback_years + 1, end_year + 1):
            period_start = date(year, 1, 1)
            period_end = date(year, 12, 31)
            
            snapshots = await self._get_snapshots(
                portfolio_id=portfolio_id,
                start_date=period_start,
                end_date=period_end,
            )
            
            if not snapshots:
                continue
            
            starting_value = float(snapshots[0].total_market_value) if snapshots[0].total_market_value else None
            ending_value = float(snapshots[-1].total_market_value) if snapshots[-1].total_market_value else None
            
            return_pct = None
            if starting_value and ending_value and starting_value != 0:
                return_pct = round(((ending_value - starting_value) / starting_value) * 100, 2)
                cumulative_return += return_pct
            
            points.append(YearlyReturnPoint(
                year=year,
                starting_value=starting_value,
                ending_value=ending_value,
                return_pct=return_pct,
                cumulative_return_pct=round(cumulative_return, 2),
            ))
        
        return points

    # ═══════════════════════════════════════════════════════════════
    # Data Quality
    # ═══════════════════════════════════════════════════════════════

    def _determine_completeness(
        self,
        *,
        snapshots: list[PortfolioSnapshot],
        period_start: date,
        period_end: date,
    ) -> DataCompleteness:
        """Determine data completeness for a period."""
        if not snapshots:
            return DataCompleteness.INSUFFICIENT
        
        # Check if we have data for start and end of period
        has_start = any(s.snapshot_date == period_start for s in snapshots)
        has_end = any(s.snapshot_date == period_end for s in snapshots)
        
        if has_start and has_end:
            return DataCompleteness.COMPLETE
        elif snapshots:
            return DataCompleteness.PARTIAL
        else:
            return DataCompleteness.INSUFFICIENT

    def _is_stale(self, snapshots: list[PortfolioSnapshot]) -> bool:
        """Check if data is stale (older than 2 days)."""
        if not snapshots:
            return True
        
        latest_date = max(s.snapshot_date for s in snapshots)
        age_days = (date.today() - latest_date).days
        return age_days > 2
