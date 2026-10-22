"""Chart data service for portfolio analytics.

Generates frontend-ready time series data for:
  - Capital growth (portfolio value + cost basis over time)
  - Asset value over time (per-asset market value contribution)
  - Symbol performance (per-stock return overlay)
  - Monthly returns per stock

All chart calculations run in the backend. Date alignment and
sparse data handling are built in. No raw DB rows are returned.
"""

from __future__ import annotations

import logging
import math
import uuid
from collections import defaultdict
from datetime import UTC, date, datetime, time, timedelta
from decimal import Decimal
from types import SimpleNamespace
from typing import Protocol

from sqlalchemy.ext.asyncio import AsyncSession
from starlette.concurrency import run_in_threadpool

from app.models.enums import TransactionType
from app.repositories.market_data import MarketDataRepository
from app.repositories.pnl import PnLRepository
from app.schemas.charts import (
    CapitalGrowthPoint,
    CapitalGrowthResponse,
    ChartMetadata,
    ChartPeriod,
    ChartPoint,
    ChartResponse,
    ChartSeries,
    ChartValueType,
    DataCompleteness,
    MonthlyReturnPoint,
    MonthlyReturnsResponse,
)

logger = logging.getLogger(__name__)

ZERO = Decimal("0.0000")
TRADING_DAYS_PER_YEAR = 252

_MONTH_NAMES_FA = {
    1: "ژانویه", 2: "فوریه", 3: "مارس", 4: "آوریل",
    5: "مه", 6: "ژوئن", 7: "ژوئیه", 8: "اوت",
    9: "سپتامبر", 10: "اکتبر", 11: "نوامبر", 12: "دسامبر",
}

MONTH_NAMES_EN = {
    1: "January", 2: "February", 3: "March", 4: "April",
    5: "May", 6: "June", 7: "July", 8: "August",
    9: "September", 10: "October", 11: "November", 12: "December",
}


def _period_to_days(period: ChartPeriod) -> int:
    mapping = {
        ChartPeriod.ONE_MONTH: 30,
        ChartPeriod.THREE_MONTHS: 90,
        ChartPeriod.SIX_MONTHS: 180,
        ChartPeriod.ONE_YEAR: 365,
    }
    return mapping.get(period, 365 * 3)


def _q4(v: Decimal) -> Decimal:
    from decimal import ROUND_HALF_UP
    return v.quantize(Decimal("0.0001"), rounding=ROUND_HALF_UP)


class ChartService:
    """Generates chart-ready time series data for portfolio analytics."""

    def __init__(self, db: AsyncSession) -> None:
        self.db = db
        self.pnl_repo = PnLRepository(db)
        self.market_repo = MarketDataRepository(db)

    async def get_capital_growth_chart(
        self,
        *,
        portfolio_id: uuid.UUID,
        user_id: uuid.UUID,
        period: ChartPeriod = ChartPeriod.ONE_YEAR,
        start_date: date | None = None,
        end_date: date | None = None,
    ) -> CapitalGrowthResponse:
        """Capital growth chart: portfolio value + cost basis + PnL over time."""
        portfolio = await self.pnl_repo.get_portfolio_for_user(
            portfolio_id=portfolio_id, user_id=user_id,
        )
        if portfolio is None:
            from fastapi import HTTPException, status
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Portfolio not found")

        now = datetime.now(UTC).date()
        eff_end = end_date or now
        eff_start = start_date or (eff_end - timedelta(days=_period_to_days(period)))
        if period == ChartPeriod.YTD:
            eff_start = date(eff_end.year, 1, 1)

        end_dt = datetime.combine(eff_end, time.max)
        transactions = await self.pnl_repo.fetch_transactions_until(
            portfolio_id=portfolio_id, end_dt=end_dt,
        )
        transactions = await self._augment_transactions_with_positions(
            portfolio_id=portfolio_id,
            transactions=transactions,
            synthetic_at=datetime.combine(eff_start, time.min, tzinfo=UTC),
        )

        asset_ids = list({txn.asset_id for txn in transactions})
        price_rows = await self.market_repo.fetch_asset_price_rows(
            asset_ids=asset_ids, end_date=eff_end,
        )

        points = await run_in_threadpool(
            self._compute_capital_growth,
            transactions, price_rows, eff_start, eff_end,
        )

        non_null = sum(1 for p in points if p.portfolio_value and p.portfolio_value > 0)
        completeness = _determine_completeness(non_null, (eff_end - eff_start).days + 1)

        metadata = ChartMetadata(
            chart_type="capital_growth",
            title="رشد سرمایه",
            period=period,
            start_date=eff_start,
            end_date=eff_end,
            as_of_timestamp=datetime.now(UTC),
            base_currency="IRR",
            total_data_points=(eff_end - eff_start).days + 1,
            available_data_points=non_null,
            completeness=completeness,
        )

        return CapitalGrowthResponse(
            portfolio_id=portfolio_id,
            metadata=metadata,
            points=points,
        )

    async def get_asset_value_chart(
        self,
        *,
        portfolio_id: uuid.UUID,
        user_id: uuid.UUID,
        period: ChartPeriod = ChartPeriod.ONE_YEAR,
        start_date: date | None = None,
        end_date: date | None = None,
        symbols: list[str] | None = None,
    ) -> ChartResponse:
        """Per-asset value contribution over time (stacked area chart data)."""
        portfolio = await self.pnl_repo.get_portfolio_for_user(
            portfolio_id=portfolio_id, user_id=user_id,
        )
        if portfolio is None:
            from fastapi import HTTPException, status
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Portfolio not found")

        now = datetime.now(UTC).date()
        eff_end = end_date or now
        eff_start = start_date or (eff_end - timedelta(days=_period_to_days(period)))
        if period == ChartPeriod.YTD:
            eff_start = date(eff_end.year, 1, 1)

        end_dt = datetime.combine(eff_end, time.max)
        transactions = await self.pnl_repo.fetch_transactions_until(
            portfolio_id=portfolio_id, end_dt=end_dt,
        )
        transactions = await self._augment_transactions_with_positions(
            portfolio_id=portfolio_id,
            transactions=transactions,
            synthetic_at=datetime.combine(eff_start, time.min, tzinfo=UTC),
        )

        asset_ids = list({txn.asset_id for txn in transactions})
        price_rows = await self.market_repo.fetch_asset_price_rows(
            asset_ids=asset_ids, end_date=eff_end,
        )

        asset_tickers = await self._resolve_asset_tickers(asset_ids)

        all_series = await run_in_threadpool(
            self._compute_asset_value_series,
            transactions, price_rows, asset_tickers, eff_start, eff_end, symbols,
        )

        total_days = (eff_end - eff_start).days + 1
        max_non_null = max((s.non_null_count for s in all_series), default=0)
        completeness = _determine_completeness(max_non_null, total_days)

        metadata = ChartMetadata(
            chart_type="asset_value",
            title="ارزش دارایی‌ها در طول زمان",
            period=period,
            start_date=eff_start,
            end_date=eff_end,
            as_of_timestamp=datetime.now(UTC),
            base_currency="IRR",
            total_data_points=total_days,
            available_data_points=max_non_null,
            completeness=completeness,
        )

        return ChartResponse(
            portfolio_id=portfolio_id,
            metadata=metadata,
            series=all_series,
        )

    async def get_symbol_performance_chart(
        self,
        *,
        portfolio_id: uuid.UUID,
        user_id: uuid.UUID,
        period: ChartPeriod = ChartPeriod.ONE_YEAR,
        start_date: date | None = None,
        end_date: date | None = None,
        symbols: list[str] | None = None,
    ) -> ChartResponse:
        """Per-stock normalized performance overlay (rebased to 100)."""
        portfolio = await self.pnl_repo.get_portfolio_for_user(
            portfolio_id=portfolio_id, user_id=user_id,
        )
        if portfolio is None:
            from fastapi import HTTPException, status
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Portfolio not found")

        now = datetime.now(UTC).date()
        eff_end = end_date or now
        eff_start = start_date or (eff_end - timedelta(days=_period_to_days(period)))
        if period == ChartPeriod.YTD:
            eff_start = date(eff_end.year, 1, 1)

        end_dt = datetime.combine(eff_end, time.max)
        transactions = await self.pnl_repo.fetch_transactions_until(
            portfolio_id=portfolio_id, end_dt=end_dt,
        )
        transactions = await self._augment_transactions_with_positions(
            portfolio_id=portfolio_id,
            transactions=transactions,
            synthetic_at=datetime.combine(eff_start, time.min, tzinfo=UTC),
        )

        asset_ids = list({txn.asset_id for txn in transactions})
        price_rows = await self.market_repo.fetch_asset_price_rows(
            asset_ids=asset_ids, end_date=eff_end,
        )

        asset_tickers = await self._resolve_asset_tickers(asset_ids)

        all_series, missing_syms = await run_in_threadpool(
            self._compute_symbol_performance_series,
            transactions, price_rows, asset_tickers, eff_start, eff_end, symbols,
        )

        total_days = (eff_end - eff_start).days + 1
        max_non_null = max((s.non_null_count for s in all_series), default=0)
        completeness = _determine_completeness(max_non_null, total_days)

        metadata = ChartMetadata(
            chart_type="symbol_performance",
            title="عملکرد سهام",
            period=period,
            start_date=eff_start,
            end_date=eff_end,
            as_of_timestamp=datetime.now(UTC),
            base_currency="IRR",
            total_data_points=total_days,
            available_data_points=max_non_null,
            completeness=completeness,
            missing_symbols=missing_syms,
        )

        return ChartResponse(
            portfolio_id=portfolio_id,
            metadata=metadata,
            series=all_series,
        )

    async def get_monthly_returns_chart(
        self,
        *,
        portfolio_id: uuid.UUID,
        user_id: uuid.UUID,
        year: int | None = None,
        symbols: list[str] | None = None,
    ) -> MonthlyReturnsResponse:
        """Monthly return bars per stock + portfolio aggregate."""
        portfolio = await self.pnl_repo.get_portfolio_for_user(
            portfolio_id=portfolio_id, user_id=user_id,
        )
        if portfolio is None:
            from fastapi import HTTPException, status
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Portfolio not found")

        now = datetime.now(UTC)
        eff_year = year or now.year
        eff_start = date(eff_year, 1, 1)
        eff_end = date(eff_year, 12, 31) if eff_year < now.year else now.date()

        end_dt = datetime.combine(eff_end, time.max)
        transactions = await self.pnl_repo.fetch_transactions_until(
            portfolio_id=portfolio_id, end_dt=end_dt,
        )
        transactions = await self._augment_transactions_with_positions(
            portfolio_id=portfolio_id,
            transactions=transactions,
            synthetic_at=datetime.combine(eff_start, time.min, tzinfo=UTC),
        )

        asset_ids = list({txn.asset_id for txn in transactions})
        price_rows = await self.market_repo.fetch_asset_price_rows(
            asset_ids=asset_ids, end_date=eff_end,
        )

        asset_tickers = await self._resolve_asset_tickers(asset_ids)

        symbol_monthly, portfolio_monthly, resolved_symbols = await run_in_threadpool(
            self._compute_monthly_returns,
            transactions, price_rows, asset_tickers, eff_year, eff_start, eff_end, symbols,
        )

        non_null = sum(1 for p in portfolio_monthly if p.return_pct is not None)
        completeness = _determine_completeness(non_null, 12)

        metadata = ChartMetadata(
            chart_type="monthly_returns",
            title=f"بازدهی ماهانه {eff_year}",
            period=ChartPeriod.CUSTOM,
            start_date=eff_start,
            end_date=eff_end,
            as_of_timestamp=datetime.now(UTC),
            base_currency="IRR",
            total_data_points=12,
            available_data_points=non_null,
            completeness=completeness,
        )

        return MonthlyReturnsResponse(
            portfolio_id=portfolio_id,
            metadata=metadata,
            symbols=resolved_symbols,
            monthly_returns=symbol_monthly,
            portfolio_monthly_returns=portfolio_monthly,
        )

    # ── Private computation methods (CPU-bound, run in threadpool) ──

    async def _augment_transactions_with_positions(
        self,
        *,
        portfolio_id: uuid.UUID,
        transactions: list,
        synthetic_at: datetime,
    ) -> list:
        """Add synthetic opening buys for position-only assets.

        Some imported portfolios have current positions before their full
        transaction ledger is loaded. Without this, chart series are blank even
        though the portfolio has holdings. Synthetic rows are only added for
        assets missing from the transaction set.
        """
        seen_asset_ids = {txn.asset_id for txn in transactions}
        positions = await self.pnl_repo.fetch_all_positions(portfolio_id)
        synthetic_rows = []
        for position, _asset in positions:
            if position.asset_id in seen_asset_ids:
                continue
            if position.total_quantity <= ZERO:
                continue
            synthetic_rows.append(
                SimpleNamespace(
                    asset_id=position.asset_id,
                    executed_at=synthetic_at,
                    transaction_type=TransactionType.BUY,
                    quantity=position.total_quantity,
                    total_amount=position.total_cost_basis,
                    realized_pnl=ZERO,
                )
            )
        if not synthetic_rows:
            return transactions
        return [*transactions, *synthetic_rows]

    def _compute_capital_growth(
        self,
        transactions: list,
        price_rows: list,
        start_date: date,
        end_date: date,
    ) -> list[CapitalGrowthPoint]:
        from collections import defaultdict

        events_by_date: dict[date, list] = defaultdict(list)
        holdings: dict[uuid.UUID, Decimal] = defaultdict(lambda: ZERO)
        cost_basis_by_asset: dict[uuid.UUID, Decimal] = defaultdict(lambda: ZERO)

        for txn in transactions:
            txn_day = txn.executed_at.date()
            if txn_day < start_date:
                if txn.transaction_type == TransactionType.BUY:
                    holdings[txn.asset_id] = _q4(holdings[txn.asset_id] + txn.quantity)
                    cost_basis_by_asset[txn.asset_id] = _q4(
                        cost_basis_by_asset[txn.asset_id] + txn.total_amount
                    )
                else:
                    if holdings[txn.asset_id] > ZERO:
                        cost_per_share = (
                            cost_basis_by_asset[txn.asset_id] / holdings[txn.asset_id]
                            if holdings[txn.asset_id] > ZERO else ZERO
                        )
                        cost_basis_by_asset[txn.asset_id] = _q4(
                            cost_per_share * max(ZERO, holdings[txn.asset_id] - txn.quantity)
                        )
                    holdings[txn.asset_id] = _q4(max(ZERO, holdings[txn.asset_id] - txn.quantity))
                continue
            events_by_date[txn_day].append(txn)

        prices_by_asset: dict[uuid.UUID, list] = defaultdict(list)
        for row in price_rows:
            prices_by_asset[row.asset_id].append(row)

        points: list[CapitalGrowthPoint] = []
        price_index: dict[uuid.UUID, int] = defaultdict(int)
        last_price: dict[uuid.UUID, Decimal] = {}

        day = start_date
        while day <= end_date:
            for txn in events_by_date.get(day, []):
                if txn.transaction_type == TransactionType.BUY:
                    holdings[txn.asset_id] = _q4(holdings[txn.asset_id] + txn.quantity)
                    cost_basis_by_asset[txn.asset_id] = _q4(
                        cost_basis_by_asset[txn.asset_id] + txn.total_amount
                    )
                else:
                    if holdings[txn.asset_id] > ZERO:
                        cost_per_share = (
                            cost_basis_by_asset[txn.asset_id] / holdings[txn.asset_id]
                            if holdings[txn.asset_id] > ZERO else ZERO
                        )
                        cost_basis_by_asset[txn.asset_id] = _q4(
                            cost_per_share * max(ZERO, holdings[txn.asset_id] - txn.quantity)
                        )
                    holdings[txn.asset_id] = _q4(max(ZERO, holdings[txn.asset_id] - txn.quantity))

            total_value = ZERO
            total_cost = ZERO

            for asset_id, quantity in holdings.items():
                if quantity <= ZERO:
                    continue
                rows = prices_by_asset.get(asset_id, [])
                idx = price_index[asset_id]
                while idx < len(rows) and rows[idx].date <= day:
                    last_price[asset_id] = Decimal(str(rows[idx].close_price))
                    idx += 1
                price_index[asset_id] = idx

                mp = last_price.get(asset_id)
                if mp is not None:
                    total_value = _q4(total_value + _q4(quantity * mp))
                total_cost = _q4(total_cost + cost_basis_by_asset.get(asset_id, ZERO))

            pnl = _q4(total_value - total_cost) if total_cost > ZERO else None
            roi = None
            if total_cost > ZERO and total_value > ZERO:
                roi = float(_q4((total_value - total_cost) / total_cost * Decimal("100")))

            points.append(CapitalGrowthPoint(
                point_date=day,
                portfolio_value=float(total_value) if total_value > ZERO else None,
                cost_basis=float(total_cost) if total_cost > ZERO else None,
                total_pnl=float(pnl) if pnl is not None else None,
                roi_pct=roi,
            ))

            day += timedelta(days=1)

        return points

    def _compute_asset_value_series(
        self,
        transactions: list,
        price_rows: list,
        asset_tickers: dict[uuid.UUID, str],
        start_date: date,
        end_date: date,
        filter_symbols: list[str] | None,
    ) -> list[ChartSeries]:
        from collections import defaultdict

        events_by_date: dict[date, list] = defaultdict(list)
        holdings: dict[uuid.UUID, Decimal] = defaultdict(lambda: ZERO)

        for txn in transactions:
            txn_day = txn.executed_at.date()
            if txn_day < start_date:
                if txn.transaction_type == TransactionType.BUY:
                    holdings[txn.asset_id] = _q4(holdings[txn.asset_id] + txn.quantity)
                else:
                    holdings[txn.asset_id] = _q4(max(ZERO, holdings[txn.asset_id] - txn.quantity))
                continue
            events_by_date[txn_day].append(txn)

        prices_by_asset: dict[uuid.UUID, list] = defaultdict(list)
        for row in price_rows:
            prices_by_asset[row.asset_id].append(row)

        active_asset_ids = {aid for aid, q in holdings.items() if q > ZERO}
        active_asset_ids.update({txn.asset_id for rows in events_by_date.values() for txn in rows})

        if filter_symbols:
            active_asset_ids = {
                aid for aid in active_asset_ids
                if asset_tickers.get(aid) in filter_symbols
            }

        all_series_map: dict[uuid.UUID, list[ChartPoint]] = {
            aid: [] for aid in active_asset_ids
        }

        price_index: dict[uuid.UUID, int] = defaultdict(int)
        last_price: dict[uuid.UUID, Decimal] = {}

        day = start_date
        while day <= end_date:
            for txn in events_by_date.get(day, []):
                if txn.transaction_type == TransactionType.BUY:
                    holdings[txn.asset_id] = _q4(holdings[txn.asset_id] + txn.quantity)
                    active_asset_ids.add(txn.asset_id)
                else:
                    holdings[txn.asset_id] = _q4(max(ZERO, holdings[txn.asset_id] - txn.quantity))

            for asset_id in active_asset_ids:
                quantity = holdings.get(asset_id, ZERO)
                if quantity <= ZERO:
                    all_series_map[asset_id].append(
                        ChartPoint(point_date=day, value=0.0)
                    )
                    continue

                rows = prices_by_asset.get(asset_id, [])
                idx = price_index[asset_id]
                while idx < len(rows) and rows[idx].date <= day:
                    last_price[asset_id] = Decimal(str(rows[idx].close_price))
                    idx += 1
                price_index[asset_id] = idx

                mp = last_price.get(asset_id)
                mv = float(_q4(quantity * mp)) if mp is not None else None
                all_series_map[asset_id].append(
                    ChartPoint(point_date=day, value=mv)
                )

            day += timedelta(days=1)

        result = []
        for asset_id in active_asset_ids:
            ticker = asset_tickers.get(asset_id, str(asset_id)[:8])
            result.append(ChartSeries(
                key=ticker,
                name=ticker,
                value_type=ChartValueType.CURRENCY,
                data_points=all_series_map.get(asset_id, []),
            ))

        result.sort(key=lambda s: -(s.non_null_count or 0))
        return result

    def _compute_symbol_performance_series(
        self,
        transactions: list,
        price_rows: list,
        asset_tickers: dict[uuid.UUID, str],
        start_date: date,
        end_date: date,
        filter_symbols: list[str] | None,
    ) -> tuple[list[ChartSeries], list[str]]:
        from collections import defaultdict

        events_by_date: dict[date, list] = defaultdict(list)
        holdings: dict[uuid.UUID, Decimal] = defaultdict(lambda: ZERO)

        for txn in transactions:
            txn_day = txn.executed_at.date()
            if txn_day < start_date:
                if txn.transaction_type == TransactionType.BUY:
                    holdings[txn.asset_id] = _q4(holdings[txn.asset_id] + txn.quantity)
                else:
                    holdings[txn.asset_id] = _q4(max(ZERO, holdings[txn.asset_id] - txn.quantity))
                continue
            events_by_date[txn_day].append(txn)

        prices_by_asset: dict[uuid.UUID, list] = defaultdict(list)
        for row in price_rows:
            prices_by_asset[row.asset_id].append(row)

        active_asset_ids = {aid for aid, q in holdings.items() if q > ZERO}
        active_asset_ids.update({txn.asset_id for rows in events_by_date.values() for txn in rows})
        if filter_symbols:
            active_asset_ids = {
                aid for aid in active_asset_ids
                if asset_tickers.get(aid) in filter_symbols
            }

        all_prices: dict[uuid.UUID, list[ChartPoint]] = {aid: [] for aid in active_asset_ids}
        price_index: dict[uuid.UUID, int] = defaultdict(int)
        last_price: dict[uuid.UUID, Decimal] = {}
        base_price: dict[uuid.UUID, Decimal | None] = {}

        day = start_date
        while day <= end_date:
            for txn in events_by_date.get(day, []):
                if txn.transaction_type == TransactionType.BUY:
                    holdings[txn.asset_id] = _q4(holdings[txn.asset_id] + txn.quantity)
                    active_asset_ids.add(txn.asset_id)
                else:
                    holdings[txn.asset_id] = _q4(max(ZERO, holdings[txn.asset_id] - txn.quantity))

            for asset_id in active_asset_ids:
                rows = prices_by_asset.get(asset_id, [])
                idx = price_index[asset_id]
                while idx < len(rows) and rows[idx].date <= day:
                    last_price[asset_id] = Decimal(str(rows[idx].close_price))
                    idx += 1
                price_index[asset_id] = idx

                mp = last_price.get(asset_id)
                if mp is not None:
                    if base_price.get(asset_id) is None:
                        base_price[asset_id] = mp
                    bp = base_price[asset_id]
                    if bp and bp > ZERO:
                        rebased = float(_q4(mp / bp * Decimal("100")))
                    else:
                        rebased = None
                else:
                    rebased = None

                all_prices[asset_id].append(
                    ChartPoint(point_date=day, value=rebased)
                )

            day += timedelta(days=1)

        result = []
        missing_syms = []
        for asset_id in active_asset_ids:
            ticker = asset_tickers.get(asset_id, str(asset_id)[:8])
            pts = all_prices.get(asset_id, [])
            has_data = any(p.value is not None for p in pts)
            if not has_data:
                missing_syms.append(ticker)
                continue
            result.append(ChartSeries(
                key=ticker,
                name=ticker,
                value_type=ChartValueType.INDEX,
                data_points=pts,
            ))

        result.sort(key=lambda s: -(s.non_null_count or 0))
        return result, missing_syms

    def _compute_monthly_returns(
        self,
        transactions: list,
        price_rows: list,
        asset_tickers: dict[uuid.UUID, str],
        year: int,
        start_date: date,
        end_date: date,
        filter_symbols: list[str] | None,
    ) -> tuple[dict[str, list[MonthlyReturnPoint]], list[MonthlyReturnPoint], list[str]]:
        from collections import defaultdict

        events_by_date: dict[date, list] = defaultdict(list)
        holdings: dict[uuid.UUID, Decimal] = defaultdict(lambda: ZERO)

        for txn in transactions:
            txn_day = txn.executed_at.date()
            if txn_day < start_date:
                if txn.transaction_type == TransactionType.BUY:
                    holdings[txn.asset_id] = _q4(holdings[txn.asset_id] + txn.quantity)
                else:
                    holdings[txn.asset_id] = _q4(max(ZERO, holdings[txn.asset_id] - txn.quantity))
                continue
            events_by_date[txn_day].append(txn)

        prices_by_asset: dict[uuid.UUID, list] = defaultdict(list)
        for row in price_rows:
            prices_by_asset[row.asset_id].append(row)

        active_asset_ids = {aid for aid, q in holdings.items() if q > ZERO}
        active_asset_ids.update({txn.asset_id for rows in events_by_date.values() for txn in rows})
        if filter_symbols:
            active_asset_ids = {
                aid for aid in active_asset_ids
                if asset_tickers.get(aid) in filter_symbols
            }

        monthly_values: dict[uuid.UUID, dict[int, Decimal]] = defaultdict(lambda: defaultdict(lambda: ZERO))
        portfolio_monthly_values: dict[int, Decimal] = defaultdict(lambda: ZERO)
        price_index: dict[uuid.UUID, int] = defaultdict(int)
        last_price: dict[uuid.UUID, Decimal] = {}

        day = start_date
        while day <= end_date:
            for txn in events_by_date.get(day, []):
                if txn.transaction_type == TransactionType.BUY:
                    holdings[txn.asset_id] = _q4(holdings[txn.asset_id] + txn.quantity)
                    active_asset_ids.add(txn.asset_id)
                else:
                    holdings[txn.asset_id] = _q4(max(ZERO, holdings[txn.asset_id] - txn.quantity))

            month = day.month
            for asset_id in active_asset_ids:
                quantity = holdings.get(asset_id, ZERO)
                if quantity <= ZERO:
                    continue
                rows = prices_by_asset.get(asset_id, [])
                idx = price_index[asset_id]
                while idx < len(rows) and rows[idx].date <= day:
                    last_price[asset_id] = Decimal(str(rows[idx].close_price))
                    idx += 1
                price_index[asset_id] = idx

                mp = last_price.get(asset_id)
                if mp is not None:
                    mv = _q4(quantity * mp)
                    monthly_values[asset_id][month] = mv
                    portfolio_monthly_values[month] = _q4(
                        portfolio_monthly_values[month] + mv
                    )

            day += timedelta(days=1)

        resolved_symbols = []
        symbol_monthly: dict[str, list[MonthlyReturnPoint]] = {}

        for asset_id in sorted(active_asset_ids):
            ticker = asset_tickers.get(asset_id, str(asset_id)[:8])
            resolved_symbols.append(ticker)

            monthly_pts = []
            prev_value = None
            for m in range(1, 13):
                if day < date(year, m, 1):
                    break
                cur_value = monthly_values.get(asset_id, {}).get(m)
                ret = None
                cum = None
                if prev_value and prev_value > ZERO and cur_value is not None:
                    ret = float(_q4((cur_value - prev_value) / prev_value * Decimal("100")))
                if cur_value is not None and monthly_values.get(asset_id, {}).get(1) is not None:
                    jan_val = monthly_values[asset_id][1]
                    if jan_val > ZERO:
                        cum = float(_q4((cur_value - jan_val) / jan_val * Decimal("100")))

                monthly_pts.append(MonthlyReturnPoint(
                    year=year,
                    month=m,
                    month_label=f"{MONTH_NAMES_EN[m]} {year}",
                    return_pct=ret,
                    cumulative_pct=cum,
                ))
                if cur_value is not None:
                    prev_value = cur_value

            symbol_monthly[ticker] = monthly_pts

        portfolio_monthly_pts = []
        prev_pval = None
        for m in range(1, 13):
            if day < date(year, m, 1):
                break
            cur_pval = portfolio_monthly_values.get(m)
            pret = None
            pcum = None
            if prev_pval and prev_pval > ZERO and cur_pval is not None:
                pret = float(_q4((cur_pval - prev_pval) / prev_pval * Decimal("100")))
            jan_pval = portfolio_monthly_values.get(1)
            if cur_pval is not None and jan_pval and jan_pval > ZERO:
                pcum = float(_q4((cur_pval - jan_pval) / jan_pval * Decimal("100")))

            portfolio_monthly_pts.append(MonthlyReturnPoint(
                year=year,
                month=m,
                month_label=f"{MONTH_NAMES_EN[m]} {year}",
                return_pct=pret,
                cumulative_pct=pcum,
            ))
            if cur_pval is not None:
                prev_pval = cur_pval

        return symbol_monthly, portfolio_monthly_pts, resolved_symbols

    async def _resolve_asset_tickers(
        self, asset_ids: list[uuid.UUID]
    ) -> dict[uuid.UUID, str]:
        from sqlalchemy import select
        from app.models.asset import Asset

        if not asset_ids:
            return {}
        result = await self.db.execute(
            select(Asset.id, Asset.ticker_symbol).where(Asset.id.in_(asset_ids))
        )
        return {row[0]: row[1] for row in result.all()}


def _determine_completeness(have: int, total: int) -> DataCompleteness:
    if total <= 0:
        return DataCompleteness.INSUFFICIENT
    ratio = have / total
    if ratio >= 0.9:
        return DataCompleteness.COMPLETE
    elif ratio >= 0.5:
        return DataCompleteness.PARTIAL
    return DataCompleteness.INSUFFICIENT
