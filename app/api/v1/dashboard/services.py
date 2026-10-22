"""Business logic for Dashboard BFF endpoints."""

from __future__ import annotations

import json
import logging
import uuid
from dataclasses import dataclass
from datetime import date, timedelta
from decimal import Decimal, InvalidOperation, ROUND_HALF_UP

import jdatetime
import redis.asyncio as aioredis
from fastapi import HTTPException, status
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.models.asset import Asset
from app.models.asset_position import AssetPosition
from app.models.market_data import PortfolioSnapshot
from app.models.portfolio import Portfolio
from app.models.enums import ReconciliationStatus
from app.models.trade_reconciliation import (
    TradeReconciliation,
    TradeReconciliationAllocation,
)

from .schemas import (
    AssetAllocationItem,
    DashboardSummaryAsset,
    DashboardSummaryData,
    DashboardSummaryHistoryPoint,
    DashboardSummaryPortfolioPnl,
    DashboardSummaryResponse,
    DashboardSummaryTopMover,
    DashboardOverviewMetrics,
    DashboardOverviewResponse,
    GrowthChartPoint,
    PortfolioSummaryItem,
    PortfolioSummaryPage,
    ProblemDetails,
)

logger = logging.getLogger(__name__)

ZERO = Decimal("0.0000")
HUNDRED = Decimal("100")
FOUR_PLACES = Decimal("0.0001")
PROBLEM_BASE_URL = "https://smartportfolio.local/problems"


def quantize4(value: Decimal) -> Decimal:
    """Round monetary and percentage values to 4 decimal places."""

    return value.quantize(FOUR_PLACES, rounding=ROUND_HALF_UP)


def safe_percent(numerator: Decimal, denominator: Decimal) -> Decimal:
    """Calculate percentages without raising ZeroDivisionError."""

    try:
        if denominator == 0:
            return ZERO
        return quantize4((numerator / denominator) * HUNDRED)
    except (ZeroDivisionError, InvalidOperation):
        return ZERO


def raise_problem(
    *,
    status_code: int,
    title: str,
    detail: str,
    instance: str,
    type_slug: str,
) -> None:
    """Raise HTTPException with RFC 7807 problem details."""

    problem = ProblemDetails(
        type=f"{PROBLEM_BASE_URL}/{type_slug}",
        title=title,
        status=status_code,
        detail=detail,
        instance=instance,
    )
    raise HTTPException(status_code=status_code, detail=problem.model_dump())


@dataclass(slots=True, frozen=True)
class AggregatedAssetPosition:
    asset_id: uuid.UUID
    ticker: str
    name: str
    quantity: Decimal
    total_cost_basis: Decimal
    db_price: Decimal


@dataclass(slots=True, frozen=True)
class PortfolioAssetPosition:
    portfolio_id: uuid.UUID
    asset_id: uuid.UUID
    quantity: Decimal
    total_cost_basis: Decimal
    db_price: Decimal


@dataclass(slots=True, frozen=True)
class ActivePortfolioRow:
    portfolio_id: uuid.UUID
    name: str


class DashboardService:
    """Service layer for dashboard read models."""

    def __init__(
        self,
        db: AsyncSession,
        redis_client: aioredis.Redis | None,
    ) -> None:
        self.db = db
        self.redis = redis_client

    async def get_overview(
        self,
        *,
        user_id: uuid.UUID,
        portfolio_id: uuid.UUID | None = None,
    ) -> DashboardOverviewResponse:
        """Return portfolio-wide metrics and allocation for dashboard cards."""

        # One AsyncSession cannot execute concurrent queries safely.
        active_portfolios = await self._fetch_active_portfolios(user_id)
        if portfolio_id is not None:
            if portfolio_id not in active_portfolios:
                raise_problem(
                    status_code=status.HTTP_404_NOT_FOUND,
                    title="Portfolio Not Found",
                    detail="The requested portfolio does not exist or is not accessible.",
                    instance="/api/v1/dashboard/overview",
                    type_slug="portfolio-not-found",
                )
            scoped_portfolio_ids = [portfolio_id]
        else:
            scoped_portfolio_ids = active_portfolios

        if portfolio_id is None:
            # Backward-compatible call shape (tests monkeypatch this method with
            # a single-argument coroutine).
            aggregated_assets = await self._fetch_aggregated_assets(user_id)
        else:
            aggregated_assets = await self._fetch_aggregated_assets(
                user_id=user_id,
                portfolio_ids=scoped_portfolio_ids,
            )

        if not active_portfolios:
            return DashboardOverviewResponse(
                metrics=DashboardOverviewMetrics(
                    total_current_value=ZERO,
                    total_unrealized_pnl=ZERO,
                    total_realized_pnl=ZERO,
                    overall_roi_percent=ZERO,
                ),
                asset_allocation=[],
            )

        live_prices = await self._fetch_prices_from_redis(
            [row.asset_id for row in aggregated_assets]
        )

        total_current_value = ZERO
        total_cost_basis = ZERO
        allocation_buffer: list[tuple[str, Decimal]] = []

        for row in aggregated_assets:
            live_price = live_prices.get(row.asset_id, row.db_price)
            asset_live_value = quantize4(row.quantity * live_price)
            total_current_value = quantize4(total_current_value + asset_live_value)
            total_cost_basis = quantize4(total_cost_basis + row.total_cost_basis)
            allocation_buffer.append((row.ticker, asset_live_value))

        total_unrealized_pnl = quantize4(total_current_value - total_cost_basis)
        realized_by_portfolio = await self._fetch_reconciliation_realized_pnl(
            user_id=user_id,
            portfolio_ids=scoped_portfolio_ids,
        )
        total_realized_pnl = quantize4(sum(realized_by_portfolio.values(), ZERO))
        overall_roi_percent = safe_percent(
            quantize4(total_unrealized_pnl + total_realized_pnl),
            total_cost_basis,
        )

        allocation = [
            AssetAllocationItem(
                ticker=ticker,
                value=value,
                percentage=self._allocation_percentage(
                    asset_live_value=value,
                    total_portfolio_value=total_current_value,
                ),
            )
            for ticker, value in allocation_buffer
        ]
        allocation.sort(key=lambda item: item.value, reverse=True)

        return DashboardOverviewResponse(
            metrics=DashboardOverviewMetrics(
                total_current_value=total_current_value,
                total_unrealized_pnl=total_unrealized_pnl,
                total_realized_pnl=total_realized_pnl,
                overall_roi_percent=overall_roi_percent,
            ),
            asset_allocation=allocation,
        )

    async def get_summary(
        self,
        *,
        user_id: uuid.UUID,
        history_days: int = 30,
        portfolio_id: uuid.UUID | None = None,
    ) -> DashboardSummaryResponse:
        """Return consolidated summary payload for dashboard rendering."""

        active_portfolios = await self._fetch_active_portfolios(user_id)
        if not active_portfolios:
            return DashboardSummaryResponse(
                status="success",
                data=DashboardSummaryData(
                    portfolio_count=0,
                    total_balance=ZERO,
                    total_cost_basis=ZERO,
                    total_profit_loss=ZERO,
                    total_unrealized_pnl=ZERO,
                    total_realized_pnl=ZERO,
                    profit_loss_percent=ZERO,
                    currency="IRR",
                    assets=[],
                    top_movers=[],
                    history=[],
                ),
            )

        if portfolio_id is not None:
            if portfolio_id not in active_portfolios:
                raise_problem(
                    status_code=status.HTTP_404_NOT_FOUND,
                    title="Portfolio Not Found",
                    detail="The requested portfolio does not exist or is not accessible.",
                    instance="/api/v1/dashboard/summary",
                    type_slug="portfolio-not-found",
                )
            scoped_portfolio_ids = [portfolio_id]
        else:
            scoped_portfolio_ids = active_portfolios

        if portfolio_id is None:
            aggregated_assets = await self._fetch_aggregated_assets(user_id)
        else:
            aggregated_assets = await self._fetch_aggregated_assets(
                user_id,
                portfolio_ids=scoped_portfolio_ids,
            )
        live_prices = await self._fetch_prices_from_redis(
            [row.asset_id for row in aggregated_assets],
        )

        total_balance = ZERO
        total_cost_basis = ZERO
        assets: list[DashboardSummaryAsset] = []

        for index, row in enumerate(aggregated_assets):
            current_price = quantize4(live_prices.get(row.asset_id, row.db_price))
            market_value = quantize4(row.quantity * current_price)
            avg_buy_price = quantize4(row.total_cost_basis / row.quantity) if row.quantity > 0 else ZERO
            profit_loss = quantize4(market_value - row.total_cost_basis)

            total_balance = quantize4(total_balance + market_value)
            total_cost_basis = quantize4(total_cost_basis + row.total_cost_basis)

            assets.append(
                DashboardSummaryAsset(
                    symbol=row.ticker,
                    name=row.name,
                    quantity=quantize4(row.quantity),
                    avg_buy_price=avg_buy_price,
                    current_price=current_price,
                    market_value=market_value,
                    allocation_percent=ZERO,
                    profit_loss=profit_loss,
                    color_hint=self._color_hint(index),
                )
            )

        total_unrealized_pnl = quantize4(total_balance - total_cost_basis)
        realized_by_portfolio = await self._fetch_reconciliation_realized_pnl(
            user_id=user_id,
            portfolio_ids=scoped_portfolio_ids,
        )
        total_realized_pnl = quantize4(sum(realized_by_portfolio.values(), ZERO))
        total_profit_loss = quantize4(total_unrealized_pnl + total_realized_pnl)
        profit_loss_percent = safe_percent(total_profit_loss, total_cost_basis)

        normalized_assets = [
            asset.model_copy(
                update={
                    "allocation_percent": self._allocation_percentage(
                        asset_live_value=asset.market_value,
                        total_portfolio_value=total_balance,
                    )
                }
            )
            for asset in assets
        ]
        normalized_assets.sort(key=lambda item: item.market_value, reverse=True)
        top_assets = normalized_assets[:10]

        if portfolio_id is None:
            history = await self._fetch_summary_history(
                user_id=user_id,
                days=history_days,
            )
        else:
            history = await self._fetch_summary_history(
                user_id=user_id,
                days=history_days,
                portfolio_ids=scoped_portfolio_ids,
            )
        top_movers = await self._fetch_top_movers(
            aggregated_assets=aggregated_assets,
            live_prices=live_prices,
        )
        top_portfolios = await self._fetch_top_portfolios_by_pnl(
            user_id=user_id,
            portfolio_ids=scoped_portfolio_ids,
            limit=5,
        )

        return DashboardSummaryResponse(
            status="success",
            data=DashboardSummaryData(
                portfolio_count=len(scoped_portfolio_ids),
                total_balance=total_balance,
                total_cost_basis=total_cost_basis,
                total_profit_loss=total_profit_loss,
                total_unrealized_pnl=total_unrealized_pnl,
                total_realized_pnl=total_realized_pnl,
                profit_loss_percent=profit_loss_percent,
                currency=await self._resolve_base_currency(user_id=user_id)
                if portfolio_id is None
                else await self._resolve_base_currency(
                    user_id=user_id,
                    portfolio_id=portfolio_id,
                ),
                assets=normalized_assets,
                top_assets=top_assets,
                top_movers=top_movers,
                top_portfolios_by_pnl=top_portfolios,
                history=history,
            ),
        )

    async def get_growth_chart(
        self,
        *,
        user_id: uuid.UUID,
        days: int = 30,
    ) -> list[GrowthChartPoint]:
        """Return 30-day historical valuation (Jalali dates)."""

        if days <= 0:
            raise_problem(
                status_code=status.HTTP_400_BAD_REQUEST,
                title="Invalid date range",
                detail="Parameter 'days' must be greater than zero.",
                instance="/api/v1/dashboard/growth-chart",
                type_slug="invalid-date-range",
            )

        # Include today so post-import views reflect fresh valuations immediately.
        end_date = date.today()
        start_date = end_date - timedelta(days=days - 1)

        stmt = (
            select(
                PortfolioSnapshot.snapshot_date.label("snapshot_date"),
                func.coalesce(
                    func.sum(PortfolioSnapshot.total_market_value),
                    ZERO,
                ).label("total_value"),
            )
            .join(
                Portfolio,
                Portfolio.id == PortfolioSnapshot.portfolio_id,
            )
            .where(
                Portfolio.user_id == user_id,
                Portfolio.is_active.is_(True),
                PortfolioSnapshot.snapshot_date >= start_date,
                PortfolioSnapshot.snapshot_date <= end_date,
            )
            .group_by(PortfolioSnapshot.snapshot_date)
            .order_by(PortfolioSnapshot.snapshot_date.asc())
        )
        result = await self.db.execute(stmt)

        value_by_date: dict[date, Decimal] = {
            row.snapshot_date: quantize4(row.total_value or ZERO)
            for row in result.all()
        }

        points: list[GrowthChartPoint] = []
        for offset in range(days):
            snapshot_day = start_date + timedelta(days=offset)
            jalali_date = jdatetime.date.fromgregorian(date=snapshot_day).strftime(
                "%Y/%m/%d"
            )
            points.append(
                GrowthChartPoint(
                    date=jalali_date,
                    total_value=value_by_date.get(snapshot_day, ZERO),
                )
            )

        return points

    async def get_portfolios_summary(
        self,
        *,
        user_id: uuid.UUID,
        page: int,
        page_size: int,
    ) -> PortfolioSummaryPage:
        """Return paginated per-portfolio value and ROI metrics."""

        if page <= 0 or page_size <= 0:
            raise_problem(
                status_code=status.HTTP_400_BAD_REQUEST,
                title="Invalid pagination",
                detail="Parameters 'page' and 'page_size' must be positive integers.",
                instance="/api/v1/portfolios/summary",
                type_slug="invalid-pagination",
            )

        offset = (page - 1) * page_size
        total_stmt = select(func.count(Portfolio.id)).where(
            Portfolio.user_id == user_id,
            Portfolio.is_active.is_(True),
        )
        page_stmt = (
            select(Portfolio.id, Portfolio.name)
            .where(
                Portfolio.user_id == user_id,
                Portfolio.is_active.is_(True),
            )
            .order_by(Portfolio.created_at.desc())
            .offset(offset)
            .limit(page_size)
        )

        # Execute sequentially on the same session to avoid concurrent
        # connection provisioning errors.
        total_result = await self.db.execute(total_stmt)
        page_result = await self.db.execute(page_stmt)
        total_items = int(total_result.scalar_one() or 0)
        total_pages = (
            (total_items + page_size - 1) // page_size
            if total_items > 0
            else 0
        )

        portfolio_rows = page_result.all()
        if not portfolio_rows:
            return PortfolioSummaryPage(
                page=page,
                page_size=page_size,
                total_items=total_items,
                total_pages=total_pages,
                items=[],
            )

        portfolio_ids = [row.id for row in portfolio_rows]
        portfolio_positions = await self._fetch_portfolio_positions(portfolio_ids)
        live_prices = await self._fetch_prices_from_redis(
            [row.asset_id for row in portfolio_positions]
        )

        portfolio_value_map: dict[uuid.UUID, Decimal] = {
            portfolio_id: ZERO for portfolio_id in portfolio_ids
        }
        portfolio_cost_map: dict[uuid.UUID, Decimal] = {
            portfolio_id: ZERO for portfolio_id in portfolio_ids
        }

        for row in portfolio_positions:
            live_price = live_prices.get(row.asset_id, row.db_price)
            live_value = quantize4(row.quantity * live_price)
            portfolio_value_map[row.portfolio_id] = quantize4(
                portfolio_value_map[row.portfolio_id] + live_value
            )
            portfolio_cost_map[row.portfolio_id] = quantize4(
                portfolio_cost_map[row.portfolio_id] + row.total_cost_basis
            )

        items = []
        for row in portfolio_rows:
            total_value = portfolio_value_map.get(row.id, ZERO)
            total_cost_basis = portfolio_cost_map.get(row.id, ZERO)
            unrealized_pnl = quantize4(total_value - total_cost_basis)
            roi_percent = safe_percent(unrealized_pnl, total_cost_basis)

            items.append(
                PortfolioSummaryItem(
                    portfolio_id=row.id,
                    portfolio_name=row.name,
                    total_value=total_value,
                    roi_percent=roi_percent,
                )
            )

        return PortfolioSummaryPage(
            page=page,
            page_size=page_size,
            total_items=total_items,
            total_pages=total_pages,
            items=items,
        )

    async def _fetch_active_portfolios(self, user_id: uuid.UUID) -> list[uuid.UUID]:
        """Load active portfolio IDs for the user."""

        stmt = select(Portfolio.id).where(
            Portfolio.user_id == user_id,
            Portfolio.is_active.is_(True),
        )
        result = await self.db.execute(stmt)
        return list(result.scalars().all())

    async def _fetch_reconciliation_realized_pnl(
        self,
        *,
        user_id: uuid.UUID,
        portfolio_ids: list[uuid.UUID],
    ) -> dict[uuid.UUID, Decimal]:
        """Return confirmed reconciliation PnL only; no links means exact legacy totals."""
        if self.db is None or not portfolio_ids:
            return {}
        stmt = (
            select(
                TradeReconciliation.destination_portfolio_id,
                func.coalesce(func.sum(TradeReconciliationAllocation.realized_pnl), ZERO),
            )
            .join(
                TradeReconciliationAllocation,
                TradeReconciliationAllocation.reconciliation_id == TradeReconciliation.id,
            )
            .where(
                TradeReconciliation.user_id == user_id,
                TradeReconciliation.status == ReconciliationStatus.CONFIRMED,
                TradeReconciliation.destination_portfolio_id.in_(portfolio_ids),
            )
            .group_by(TradeReconciliation.destination_portfolio_id)
        )
        result = await self.db.execute(stmt)
        return {
            row[0]: quantize4(Decimal(row[1] or ZERO))
            for row in result.all()
        }

    async def _fetch_active_portfolio_rows(
        self,
        *,
        user_id: uuid.UUID,
        portfolio_ids: list[uuid.UUID] | None = None,
    ) -> list[ActivePortfolioRow]:
        """Load active portfolio IDs and names for dashboard ranking."""

        stmt = (
            select(Portfolio.id, Portfolio.name)
            .where(
                Portfolio.user_id == user_id,
                Portfolio.is_active.is_(True),
            )
            .order_by(Portfolio.created_at.desc())
        )
        if portfolio_ids is not None:
            if not portfolio_ids:
                return []
            stmt = stmt.where(Portfolio.id.in_(portfolio_ids))
        result = await self.db.execute(stmt)
        return [
            ActivePortfolioRow(
                portfolio_id=row.id,
                name=row.name,
            )
            for row in result.all()
        ]

    async def _fetch_aggregated_assets(
        self,
        user_id: uuid.UUID,
        portfolio_ids: list[uuid.UUID] | None = None,
    ) -> list[AggregatedAssetPosition]:
        """Aggregate positions by asset across all active user portfolios."""

        stmt = (
            select(
                Asset.id.label("asset_id"),
                Asset.ticker_symbol.label("ticker"),
                func.coalesce(Asset.name_fa, Asset.ticker_symbol).label("name"),
                func.coalesce(func.sum(AssetPosition.total_quantity), ZERO).label(
                    "quantity"
                ),
                func.coalesce(func.sum(AssetPosition.total_cost_basis), ZERO).label(
                    "total_cost_basis"
                ),
                func.coalesce(
                    func.nullif(Asset.last_trade_price, 0),
                    func.nullif(Asset.closing_price, 0),
                    0,
                ).label("db_price"),
            )
            .join(Asset, Asset.id == AssetPosition.asset_id)
            .join(Portfolio, Portfolio.id == AssetPosition.portfolio_id)
            .where(
                Portfolio.user_id == user_id,
                Portfolio.is_active.is_(True),
                AssetPosition.total_quantity > 0,
            )
            .group_by(
                Asset.id,
                Asset.ticker_symbol,
                Asset.name_fa,
                Asset.last_trade_price,
                Asset.closing_price,
            )
            .order_by(Asset.ticker_symbol.asc())
        )
        if portfolio_ids is not None:
            if not portfolio_ids:
                return []
            stmt = stmt.where(AssetPosition.portfolio_id.in_(portfolio_ids))
        result = await self.db.execute(stmt)

        return [
            AggregatedAssetPosition(
                asset_id=row.asset_id,
                ticker=row.ticker,
                name=row.name,
                quantity=quantize4(row.quantity or ZERO),
                total_cost_basis=quantize4(row.total_cost_basis or ZERO),
                db_price=quantize4(row.db_price or ZERO),
            )
            for row in result.all()
        ]

    async def _fetch_portfolio_positions(
        self,
        portfolio_ids: list[uuid.UUID],
    ) -> list[PortfolioAssetPosition]:
        """Aggregate positions per portfolio + asset for summary pagination."""

        if not portfolio_ids:
            return []

        stmt = (
            select(
                AssetPosition.portfolio_id.label("portfolio_id"),
                Asset.id.label("asset_id"),
                func.coalesce(func.sum(AssetPosition.total_quantity), ZERO).label(
                    "quantity"
                ),
                func.coalesce(func.sum(AssetPosition.total_cost_basis), ZERO).label(
                    "total_cost_basis"
                ),
                func.coalesce(
                    func.nullif(Asset.last_trade_price, 0),
                    func.nullif(Asset.closing_price, 0),
                    0,
                ).label("db_price"),
            )
            .join(Asset, Asset.id == AssetPosition.asset_id)
            .where(
                AssetPosition.portfolio_id.in_(portfolio_ids),
                AssetPosition.total_quantity > 0,
            )
            .group_by(
                AssetPosition.portfolio_id,
                Asset.id,
                Asset.last_trade_price,
                Asset.closing_price,
            )
        )
        result = await self.db.execute(stmt)

        return [
            PortfolioAssetPosition(
                portfolio_id=row.portfolio_id,
                asset_id=row.asset_id,
                quantity=quantize4(row.quantity or ZERO),
                total_cost_basis=quantize4(row.total_cost_basis or ZERO),
                db_price=quantize4(row.db_price or ZERO),
            )
            for row in result.all()
        ]

    async def _fetch_prices_from_redis(
        self,
        asset_ids: list[uuid.UUID],
    ) -> dict[uuid.UUID, Decimal]:
        """
        Fetch live prices via Redis pipeline + MGET.

        Fallback is handled by callers using selected last/closing price from DB.
        """

        if not asset_ids or self.redis is None:
            return {}

        keys = [f"{settings.REDIS_PRICE_PREFIX}{asset_id}" for asset_id in asset_ids]
        try:
            async with self.redis.pipeline(transaction=False) as pipe:
                pipe.mget(keys)
                response = await pipe.execute()
            raw_values = response[0] if response else []
        except Exception as exc:  # noqa: BLE001 - Redis errors must never break BFF
            logger.warning("Redis pipeline mget failed: %s", exc)
            return {}

        prices: dict[uuid.UUID, Decimal] = {}
        for asset_id, raw in zip(asset_ids, raw_values):
            if not raw:
                continue
            try:
                payload = json.loads(raw)
                price_value = payload.get("price")
                if price_value is None:
                    continue
                prices[asset_id] = quantize4(Decimal(str(price_value)))
            except (
                json.JSONDecodeError,
                InvalidOperation,
                TypeError,
                ValueError,
            ) as exc:
                logger.warning(
                    "Invalid cached price payload for asset %s: %s",
                    asset_id,
                    exc,
                )
                continue

        return prices

    @staticmethod
    def _allocation_percentage(
        *,
        asset_live_value: Decimal,
        total_portfolio_value: Decimal,
    ) -> Decimal:
        """
        Allocation formula:
          percentage = (asset_live_value / total_portfolio_value) * 100
        """

        try:
            if total_portfolio_value == 0:
                return ZERO
            return quantize4((asset_live_value / total_portfolio_value) * HUNDRED)
        except (ZeroDivisionError, InvalidOperation):
            return ZERO

    async def _resolve_base_currency(
        self,
        *,
        user_id: uuid.UUID,
        portfolio_id: uuid.UUID | None = None,
    ) -> str:
        stmt = (
            select(Portfolio.base_currency)
            .where(
                Portfolio.user_id == user_id,
                Portfolio.is_active.is_(True),
            )
            .order_by(Portfolio.created_at.desc())
            .limit(1)
        )
        if portfolio_id is not None:
            stmt = stmt.where(Portfolio.id == portfolio_id)
        result = await self.db.execute(stmt)
        value = result.scalar_one_or_none()
        if value is None:
            return "IRR"
        return str(getattr(value, "value", value))

    async def _fetch_summary_history(
        self,
        *,
        user_id: uuid.UUID,
        days: int,
        portfolio_ids: list[uuid.UUID] | None = None,
    ) -> list[DashboardSummaryHistoryPoint]:
        if days <= 0:
            return []

        end_date = date.today()
        start_date = end_date - timedelta(days=days - 1)

        stmt = (
            select(
                PortfolioSnapshot.snapshot_date.label("snapshot_date"),
                func.coalesce(func.sum(PortfolioSnapshot.total_market_value), ZERO).label(
                    "total_value"
                ),
            )
            .join(Portfolio, Portfolio.id == PortfolioSnapshot.portfolio_id)
            .where(
                Portfolio.user_id == user_id,
                Portfolio.is_active.is_(True),
                PortfolioSnapshot.snapshot_date >= start_date,
                PortfolioSnapshot.snapshot_date <= end_date,
            )
            .group_by(PortfolioSnapshot.snapshot_date)
            .order_by(PortfolioSnapshot.snapshot_date.asc())
        )
        if portfolio_ids is not None:
            if not portfolio_ids:
                return []
            stmt = stmt.where(PortfolioSnapshot.portfolio_id.in_(portfolio_ids))
        result = await self.db.execute(stmt)
        rows = result.all()
        if not rows:
            return []

        value_by_date = {
            row.snapshot_date: quantize4(row.total_value or ZERO)
            for row in rows
        }
        history: list[DashboardSummaryHistoryPoint] = []
        for offset in range(days):
            snapshot_day = start_date + timedelta(days=offset)
            if snapshot_day not in value_by_date:
                continue
            jalali = jdatetime.date.fromgregorian(date=snapshot_day).strftime("%Y/%m/%d")
            history.append(
                DashboardSummaryHistoryPoint(
                    date=jalali,
                    total_value=value_by_date[snapshot_day],
                )
            )
        return history

    async def _fetch_top_movers(
        self,
        *,
        aggregated_assets: list[AggregatedAssetPosition],
        live_prices: dict[uuid.UUID, Decimal],
    ) -> list[DashboardSummaryTopMover]:
        if not aggregated_assets:
            return []

        movers: list[DashboardSummaryTopMover] = []
        for row in aggregated_assets:
            current_price = quantize4(live_prices.get(row.asset_id, row.db_price))
            market_value = quantize4(row.quantity * current_price)
            profit_loss = quantize4(market_value - row.total_cost_basis)
            pnl_pct = safe_percent(profit_loss, row.total_cost_basis)
            movers.append(
                DashboardSummaryTopMover(
                    symbol=row.ticker,
                    name=row.name,
                    profit_loss=profit_loss,
                    profit_loss_percent=pnl_pct,
                )
            )

        movers.sort(key=lambda item: abs(item.profit_loss_percent), reverse=True)
        return movers[:5]

    async def _fetch_top_portfolios_by_pnl(
        self,
        *,
        user_id: uuid.UUID,
        portfolio_ids: list[uuid.UUID],
        limit: int,
    ) -> list[DashboardSummaryPortfolioPnl]:
        """Rank active portfolios by absolute profit/loss using DB positions."""

        if limit <= 0 or not portfolio_ids:
            return []

        portfolio_rows = await self._fetch_active_portfolio_rows(
            user_id=user_id,
            portfolio_ids=portfolio_ids,
        )
        if not portfolio_rows:
            return []

        positions = await self._fetch_portfolio_positions(
            [row.portfolio_id for row in portfolio_rows],
        )
        live_prices = await self._fetch_prices_from_redis(
            [row.asset_id for row in positions],
        )
        realized_by_portfolio = await self._fetch_reconciliation_realized_pnl(
            user_id=user_id,
            portfolio_ids=[row.portfolio_id for row in portfolio_rows],
        )

        value_by_portfolio: dict[uuid.UUID, Decimal] = {
            row.portfolio_id: ZERO for row in portfolio_rows
        }
        cost_by_portfolio: dict[uuid.UUID, Decimal] = {
            row.portfolio_id: ZERO for row in portfolio_rows
        }

        for row in positions:
            current_price = quantize4(live_prices.get(row.asset_id, row.db_price))
            market_value = quantize4(row.quantity * current_price)
            value_by_portfolio[row.portfolio_id] = quantize4(
                value_by_portfolio[row.portfolio_id] + market_value
            )
            cost_by_portfolio[row.portfolio_id] = quantize4(
                cost_by_portfolio[row.portfolio_id] + row.total_cost_basis
            )

        ranked: list[DashboardSummaryPortfolioPnl] = []
        for row in portfolio_rows:
            total_value = value_by_portfolio.get(row.portfolio_id, ZERO)
            total_cost_basis = cost_by_portfolio.get(row.portfolio_id, ZERO)
            profit_loss = quantize4(
                total_value
                - total_cost_basis
                + realized_by_portfolio.get(row.portfolio_id, ZERO)
            )
            ranked.append(
                DashboardSummaryPortfolioPnl(
                    portfolio_id=row.portfolio_id,
                    portfolio_name=row.name,
                    total_value=total_value,
                    total_cost_basis=total_cost_basis,
                    profit_loss=profit_loss,
                    profit_loss_percent=safe_percent(profit_loss, total_cost_basis),
                )
            )

        ranked.sort(key=lambda item: item.profit_loss, reverse=True)
        return ranked[:limit]

    @staticmethod
    def _color_hint(index: int) -> str:
        palette = (
            "#4F8CFF",
            "#22C55E",
            "#F59E0B",
            "#A855F7",
            "#06B6D4",
            "#EF4444",
            "#14B8A6",
            "#F97316",
        )
        return palette[index % len(palette)]
