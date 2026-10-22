"""Service for selected-symbol portfolio analytics.

Composes existing PnL, Returns, and BenchmarkComparison services
to provide per-symbol analytics without duplicating logic.
"""

from __future__ import annotations

import logging
import uuid
from datetime import UTC, date, datetime, time, timedelta
from decimal import Decimal

from fastapi import HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from starlette.concurrency import run_in_threadpool

from app.models.enums import TransactionType
from app.repositories.market_data import MarketDataRepository
from app.repositories.pnl import PnLRepository
from app.schemas.charts import (
    ChartPeriod,
    ChartPoint,
    ChartValueType,
    MonthlyReturnPoint,
)
from app.schemas.returns import (
    DataQuality,
    ReturnPeriod,
    ReturnSeriesPointDTO,
)
from app.schemas.symbol_analytics import (
    PortfolioHoldingItem,
    PortfolioHoldingsListResponse,
    SymbolAnalyticsResponse,
    SymbolChartResponse,
    SymbolMonthlyReturns,
    SymbolPositionInfo,
    SymbolReturnSeries,
)
from app.services.returns_service import ReturnsService
from app.services.benchmark_comparison_service import BenchmarkComparisonService
from app.repositories.returns_read import ReturnsReadRepository

logger = logging.getLogger(__name__)

ZERO = Decimal("0.0000")


def _q4(v: Decimal) -> Decimal:
    return v.quantize(Decimal("0.0001"))


class SymbolAnalyticsService:
    """Provides per-symbol analytics for portfolio holdings."""

    def __init__(self, db: AsyncSession) -> None:
        self.db = db
        self.pnl_repo = PnLRepository(db)
        self.market_repo = MarketDataRepository(db)
        repo = ReturnsReadRepository(db)
        self.returns_service = ReturnsService(repo)
        self.benchmark_service = BenchmarkComparisonService(repo)

    async def list_portfolio_holdings(
        self,
        *,
        portfolio_id: uuid.UUID,
        user_id: uuid.UUID,
    ) -> PortfolioHoldingsListResponse:
        """List all current holdings with live market data."""
        portfolio = await self.pnl_repo.get_portfolio_for_user(
            portfolio_id=portfolio_id, user_id=user_id,
        )
        if portfolio is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Portfolio not found",
            )

        from app.services.market_persistence import MarketPersistenceService

        market_persistence = MarketPersistenceService(self.db)
        rows = await self.pnl_repo.fetch_live_positions(portfolio_id)

        holdings: list[PortfolioHoldingItem] = []
        total_value = ZERO
        missing: list[str] = []
        stale: list[str] = []

        for position, asset in rows:
            quantity = _q4(position.total_quantity)
            wac = _q4(position.weighted_avg_cost)
            total_cost = _q4(position.total_cost_basis)

            ins_code = getattr(asset, "tsetmc_id", None)
            price, is_fresh, last_updated = await market_persistence.get_latest_price(
                asset.id, ins_code=ins_code,
            )
            live_price = _q4(price)
            last_price = _q4(getattr(asset, "last_trade_price", live_price) or live_price)
            previous_close = _q4(getattr(asset, "previous_close_price", ZERO) or ZERO)
            price_change = _q4(live_price - previous_close) if live_price > ZERO and previous_close > ZERO else None
            price_change_percent = (
                _q4(price_change / previous_close * Decimal("100"))
                if price_change is not None and previous_close > ZERO
                else None
            )
            daily_pnl = _q4(price_change * quantity) if price_change is not None else None

            if live_price <= ZERO:
                price_status = "missing_price"
                missing.append(asset.ticker_symbol)
            elif not is_fresh:
                price_status = "stale_price"
                stale.append(asset.ticker_symbol)
            else:
                price_status = "ok"

            current_value = _q4(quantity * live_price) if live_price > ZERO else ZERO
            unrealized = _q4(current_value - total_cost)
            unrealized_pct = (
                _q4(unrealized / total_cost * Decimal("100"))
                if total_cost > ZERO else ZERO
            )

            total_value = _q4(total_value + current_value)

            holdings.append(PortfolioHoldingItem(
                asset_id=asset.id,
                ticker_symbol=asset.ticker_symbol,
                asset_name=getattr(asset, "asset_name", ""),
                quantity=quantity,
                weighted_avg_cost=wac,
                current_price=live_price if live_price > ZERO else None,
                last_price=last_price if last_price > ZERO else None,
                closing_price=live_price if live_price > ZERO else None,
                price_change=price_change,
                price_change_percent=price_change_percent,
                daily_pnl=daily_pnl,
                last_updated_at=last_updated,
                current_value=current_value if current_value > ZERO else None,
                unrealized_pnl=unrealized if total_cost > ZERO else None,
                unrealized_pnl_pct=unrealized_pct if total_cost > ZERO else None,
                weight_pct=ZERO,
                is_price_fresh=is_fresh,
                is_tradeable=getattr(asset, "is_tradeable", True),
                price_status=price_status,
            ))

        for h in holdings:
            if total_value > ZERO and h.current_value:
                h.weight_pct = _q4(h.current_value / total_value * Decimal("100"))

        return PortfolioHoldingsListResponse(
            portfolio_id=portfolio_id,
            total_current_value=total_value,
            holdings=holdings,
            as_of_timestamp=datetime.now(UTC),
        )

    async def get_symbol_analytics(
        self,
        *,
        portfolio_id: uuid.UUID,
        user_id: uuid.UUID,
        symbol: str,
        period: ReturnPeriod = ReturnPeriod.ONE_YEAR,
        include_monthly: bool = False,
        monthly_year: int | None = None,
        include_benchmark: bool = False,
        benchmark_id: str | None = None,
    ) -> SymbolAnalyticsResponse:
        """Comprehensive analytics for a single portfolio symbol."""
        portfolio = await self.pnl_repo.get_portfolio_for_user(
            portfolio_id=portfolio_id, user_id=user_id,
        )
        if portfolio is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Portfolio not found",
            )

        position, asset = await self._resolve_position(portfolio_id, symbol)

        from app.services.market_persistence import MarketPersistenceService

        market_persistence = MarketPersistenceService(self.db)
        ins_code = getattr(asset, "tsetmc_id", None)
        price, is_fresh, last_updated = await market_persistence.get_latest_price(
            asset.id, ins_code=ins_code,
        )
        live_price = _q4(price)
        last_price = _q4(getattr(asset, "last_trade_price", live_price) or live_price)
        previous_close = _q4(getattr(asset, "previous_close_price", ZERO) or ZERO)
        price_change = _q4(live_price - previous_close) if live_price > ZERO and previous_close > ZERO else None
        price_change_percent = (
            _q4(price_change / previous_close * Decimal("100"))
            if price_change is not None and previous_close > ZERO
            else None
        )

        quantity = _q4(position.total_quantity)
        wac = _q4(position.weighted_avg_cost)
        total_cost = _q4(position.total_cost_basis)
        daily_pnl = _q4(price_change * quantity) if price_change is not None else None
        current_value = _q4(quantity * live_price) if live_price > ZERO else ZERO
        unrealized = _q4(current_value - total_cost) if total_cost > ZERO else None
        unrealized_pct = (
            _q4(unrealized / total_cost * Decimal("100"))
            if unrealized is not None and total_cost > ZERO else None
        )

        if live_price <= ZERO:
            price_status = "missing_price"
        elif not is_fresh:
            price_status = "stale_price"
        else:
            price_status = "ok"

        data_freshness_seconds = None
        if last_updated is not None:
            now_utc = datetime.now(UTC)
            if last_updated.tzinfo is None:
                last_updated = last_updated.replace(tzinfo=UTC)
            data_freshness_seconds = int((now_utc - last_updated).total_seconds())

        position_info = SymbolPositionInfo(
            asset_id=asset.id,
            ticker_symbol=asset.ticker_symbol,
            asset_name=getattr(asset, "asset_name", ""),
            quantity=quantity,
            weighted_avg_cost=wac,
            total_cost_basis=total_cost,
            current_price=live_price if live_price > ZERO else None,
            last_price=last_price if last_price > ZERO else None,
            closing_price=live_price if live_price > ZERO else None,
            price_change=price_change,
            price_change_percent=price_change_percent,
            daily_pnl=daily_pnl,
            last_updated_at=last_updated,
            current_value=current_value if current_value > ZERO else None,
            unrealized_pnl=unrealized,
            unrealized_pnl_pct=unrealized_pct,
            realized_pnl=_q4(position.cumulative_realized_pnl),
            is_price_fresh=is_fresh,
            is_tradeable=getattr(asset, "is_tradeable", True),
            price_status=price_status,
            price_timestamp=last_updated,
            data_freshness_seconds=data_freshness_seconds,
        )

        return_series = None
        try:
            series_response = await self.returns_service.get_asset_return_series(
                asset_id=asset.id,
                period=period,
            )
            return_series = SymbolReturnSeries(
                period=series_response.period,
                start_date=series_response.start_date,
                end_date=series_response.end_date,
                total_return_pct=series_response.total_return_pct,
                annualized_return_pct=series_response.annualized_return_pct,
                data_quality=series_response.data_quality,
                points=series_response.points,
            )
        except Exception as exc:
            logger.warning("symbol_analytics.return_series_failed symbol=%s err=%s", symbol, exc)

        monthly_returns = None
        if include_monthly:
            now = datetime.now(UTC)
            eff_year = monthly_year or now.year
            try:
                monthly_chart = await self._get_monthly_for_symbol(
                    portfolio_id=portfolio_id,
                    user_id=user_id,
                    symbol=symbol,
                    year=eff_year,
                )
                monthly_returns = monthly_chart
            except Exception as exc:
                logger.warning("symbol_analytics.monthly_failed symbol=%s err=%s", symbol, exc)

        benchmark_comparison = None
        if include_benchmark and benchmark_id:
            try:
                from app.schemas.benchmark_comparison import BenchmarkIdentifier, ComparisonPeriod
                benchmark_identifier = BenchmarkIdentifier(benchmark_id)
                period_map = {
                    ReturnPeriod.ONE_MONTH: ComparisonPeriod.ONE_MONTH,
                    ReturnPeriod.THREE_MONTHS: ComparisonPeriod.THREE_MONTHS,
                    ReturnPeriod.SIX_MONTHS: ComparisonPeriod.SIX_MONTHS,
                    ReturnPeriod.ONE_YEAR: ComparisonPeriod.ONE_YEAR,
                    ReturnPeriod.YEAR_TO_DATE: ComparisonPeriod.YEAR_TO_DATE,
                }
                comp_period = period_map.get(period, ComparisonPeriod.ONE_YEAR)
                comp_result = await self.benchmark_service.compare_single_benchmark(
                    asset_id=asset.id,
                    benchmark_id=benchmark_identifier,
                    period=comp_period,
                )
                benchmark_comparison = BenchmarkComparisonDTO(
                    benchmark_code=benchmark_id,
                    benchmark_name=comp_result.benchmark_name,
                    benchmark_return_pct=comp_result.benchmark_return_pct,
                    portfolio_return_pct=comp_result.target_return_pct,
                    excess_return_pct=comp_result.excess_return_pct,
                    tracking_error=comp_result.tracking_error_pct,
                    information_ratio=comp_result.information_ratio,
                    beta=comp_result.beta,
                    alpha=comp_result.alpha_pct,
                    correlation=comp_result.correlation,
                )
            except Exception as exc:
                logger.warning("symbol_analytics.benchmark_failed symbol=%s err=%s", symbol, exc)

        sanity_flags: list[str] = []
        if live_price <= ZERO:
            sanity_flags.append(f"MISSING_PRICE:{symbol}")
        if not is_fresh:
            sanity_flags.append(f"STALE_PRICE:{symbol}")
        if position.weighted_avg_cost < ZERO:
            sanity_flags.append(f"NEGATIVE_WAC:{symbol}")

        data_quality = DataQuality.COMPLETE
        if live_price <= ZERO:
            data_quality = DataQuality.INSUFFICIENT
        elif not is_fresh:
            data_quality = DataQuality.PARTIAL

        is_stale = price_status == "stale_price" or (
            data_freshness_seconds is not None and data_freshness_seconds > 3600
        )

        return SymbolAnalyticsResponse(
            portfolio_id=portfolio_id,
            as_of_timestamp=datetime.now(UTC),
            total_unrealized_pnl=unrealized,
            last_market_update=last_updated,
            position=position_info,
            return_series=return_series,
            monthly_returns=monthly_returns,
            benchmark_comparison=benchmark_comparison,
            data_quality=data_quality,
            is_stale=is_stale,
            sanity_flags=sanity_flags,
        )

    async def get_symbol_chart(
        self,
        *,
        portfolio_id: uuid.UUID,
        user_id: uuid.UUID,
        symbol: str,
        chart_type: str = "performance",
        period: ChartPeriod = ChartPeriod.ONE_YEAR,
        start_date: date | None = None,
        end_date: date | None = None,
    ) -> SymbolChartResponse:
        """Chart-ready data for a single symbol."""
        portfolio = await self.pnl_repo.get_portfolio_for_user(
            portfolio_id=portfolio_id, user_id=user_id,
        )
        if portfolio is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Portfolio not found",
            )

        position, asset = await self._resolve_position(portfolio_id, symbol)

        now = datetime.now(UTC).date()
        eff_end = end_date or now
        eff_start = start_date or (eff_end - timedelta(days=_period_to_days(period)))
        if period == ChartPeriod.YTD:
            eff_start = date(eff_end.year, 1, 1)

        price_rows = await self.market_repo.fetch_asset_price_rows(
            asset_ids=[asset.id], end_date=eff_end,
        )

        asset_prices_by_date: dict[date, Decimal] = {}
        for row in price_rows:
            if row.date >= eff_start:
                asset_prices_by_date[row.date] = Decimal(str(row.adjusted_close))

        data_points: list[dict] = []
        if chart_type == "performance" and asset_prices_by_date:
            base_price = None
            sorted_dates = sorted(asset_prices_by_date.keys())
            for d in sorted_dates:
                p = asset_prices_by_date[d]
                if base_price is None and p > ZERO:
                    base_price = p
                if base_price and base_price > ZERO:
                    rebased = float(_q4(p / base_price * Decimal("100")))
                else:
                    rebased = None
                data_points.append({"date": d.isoformat(), "value": rebased})
            value_type = "index"
            total_return = None
            if base_price and base_price > ZERO and sorted_dates:
                last_p = asset_prices_by_date[sorted_dates[-1]]
                total_return = float(_q4((last_p - base_price) / base_price * Decimal("100")))
        elif chart_type == "price" and asset_prices_by_date:
            for d in sorted(asset_prices_by_date.keys()):
                data_points.append({
                    "date": d.isoformat(),
                    "value": float(asset_prices_by_date[d]),
                })
            value_type = "currency"
            total_return = None
            sorted_d = sorted(asset_prices_by_date.keys())
            if len(sorted_d) >= 2:
                first_p = asset_prices_by_date[sorted_d[0]]
                last_p = asset_prices_by_date[sorted_d[-1]]
                if first_p > ZERO:
                    total_return = float(_q4((last_p - first_p) / first_p * Decimal("100")))
        else:
            value_type = "currency"
            total_return = None

        has_data = len(data_points) > 0
        data_quality = DataQuality.COMPLETE if has_data else DataQuality.INSUFFICIENT

        from app.services.chart_service import _determine_completeness

        completeness = _determine_completeness(len(data_points), (eff_end - eff_start).days + 1)

        return SymbolChartResponse(
            portfolio_id=portfolio_id,
            symbol=symbol,
            chart_type=chart_type,
            period=period,
            start_date=eff_start,
            end_date=eff_end,
            as_of_timestamp=datetime.now(UTC),
            series_key=symbol,
            series_name=symbol,
            value_type=value_type,
            data_points=data_points,
            total_return_pct=total_return,
            data_quality=data_quality if has_data else DataQuality.INSUFFICIENT,
            is_stale=False,
        )

    # ── Private helpers ──

    async def _resolve_position(self, portfolio_id: uuid.UUID, symbol: str):
        """Find position and asset for a symbol in the portfolio."""
        from sqlalchemy import select
        from app.models.asset_position import AssetPosition
        from app.models.asset import Asset

        result = await self.db.execute(
            select(AssetPosition, Asset)
            .join(Asset, Asset.id == AssetPosition.asset_id)
            .where(
                AssetPosition.portfolio_id == portfolio_id,
                Asset.ticker_symbol == symbol,
            )
        )
        row = result.first()
        if row is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Symbol '{symbol}' not found in portfolio",
            )
        return row[0], row[1]

    async def _get_monthly_for_symbol(
        self,
        *,
        portfolio_id: uuid.UUID,
        user_id: uuid.UUID,
        symbol: str,
        year: int,
    ) -> SymbolMonthlyReturns:
        """Get monthly returns for a single symbol using existing chart service logic."""
        from collections import defaultdict

        end_date = date(year, 12, 31)
        end_dt = datetime.combine(end_date, time.max)
        transactions = await self.pnl_repo.fetch_transactions_until(
            portfolio_id=portfolio_id, end_dt=end_dt,
        )

        target_asset_id = None
        asset_tickers: dict[uuid.UUID, str] = {}
        from sqlalchemy import select as sa_select
        from app.models.asset import Asset as AssetModel

        asset_ids = list({txn.asset_id for txn in transactions})
        if asset_ids:
            result = await self.db.execute(
                sa_select(AssetModel.id, AssetModel.ticker_symbol)
                .where(AssetModel.id.in_(asset_ids))
            )
            for row in result.all():
                asset_tickers[row[0]] = row[1]
                if row[1] == symbol:
                    target_asset_id = row[0]

        if target_asset_id is None:
            return SymbolMonthlyReturns(year=year, monthly_returns=[])

        price_rows = await self.market_repo.fetch_asset_price_rows(
            asset_ids=[target_asset_id], end_date=end_date,
        )

        events_by_date: dict[date, list] = defaultdict(list)
        holdings: dict[uuid.UUID, Decimal] = defaultdict(lambda: ZERO)
        start_date = date(year, 1, 1)

        for txn in transactions:
            txn_day = txn.executed_at.date()
            if txn_day < start_date:
                if txn.transaction_type == TransactionType.BUY:
                    holdings[txn.asset_id] = _q4(holdings[txn.asset_id] + txn.quantity)
                else:
                    holdings[txn.asset_id] = _q4(max(ZERO, holdings[txn.asset_id] - txn.quantity))
                continue
            events_by_date[txn_day].append(txn)

        prices_by_date: dict[date, Decimal] = {}
        for row in price_rows:
            if row.date >= start_date:
                prices_by_date[row.date] = Decimal(str(row.adjusted_close))

        monthly_values: dict[int, Decimal] = {}
        last_price: Decimal | None = None
        day = start_date
        eff_end = min(end_date, datetime.now(UTC).date())

        while day <= eff_end:
            for txn in events_by_date.get(day, []):
                if txn.transaction_type == TransactionType.BUY:
                    holdings[txn.asset_id] = _q4(holdings[txn.asset_id] + txn.quantity)
                else:
                    holdings[txn.asset_id] = _q4(max(ZERO, holdings[txn.asset_id] - txn.quantity))

            mp = prices_by_date.get(day)
            if mp is not None:
                last_price = mp

            if last_price is not None:
                quantity = holdings.get(target_asset_id, ZERO)
                monthly_values[day.month] = _q4(quantity * last_price)

            day += timedelta(days=1)

        monthly_pts: list[MonthlyReturnPoint] = []
        prev_value = None
        for m in range(1, 13):
            if eff_end < date(year, m, 1):
                break
            cur_value = monthly_values.get(m)
            ret = None
            cum = None
            if prev_value and prev_value > ZERO and cur_value is not None:
                ret = float(_q4((cur_value - prev_value) / prev_value * Decimal("100")))
            jan_val = monthly_values.get(1)
            if cur_value is not None and jan_val and jan_val > ZERO:
                cum = float(_q4((cur_value - jan_val) / jan_val * Decimal("100")))

            monthly_pts.append(MonthlyReturnPoint(
                year=year,
                month=m,
                month_label=f"{_month_name(m)} {year}",
                return_pct=ret,
                cumulative_pct=cum,
            ))
            if cur_value is not None:
                prev_value = cur_value

        return SymbolMonthlyReturns(year=year, monthly_returns=monthly_pts)


def _period_to_days(period: ChartPeriod) -> int:
    mapping = {
        ChartPeriod.ONE_MONTH: 30,
        ChartPeriod.THREE_MONTHS: 90,
        ChartPeriod.SIX_MONTHS: 180,
        ChartPeriod.ONE_YEAR: 365,
    }
    return mapping.get(period, 365 * 3)


def _month_name(m: int) -> str:
    names = {
        1: "January", 2: "February", 3: "March", 4: "April",
        5: "May", 6: "June", 7: "July", 8: "August",
        9: "September", 10: "October", 11: "November", 12: "December",
    }
    return names.get(m, f"M{m}")
