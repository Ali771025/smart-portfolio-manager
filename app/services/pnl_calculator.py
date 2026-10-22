"""Advanced PnL and portfolio quant analytics service.

Integrates with MarketPersistenceService for:
  - Latest price resolution with Redis-first fallback
  - Freshness-aware valuation
  - Graceful degradation when live data is unavailable
"""

from __future__ import annotations

import logging
import uuid
from collections import defaultdict
from datetime import UTC, date, datetime, time
from decimal import Decimal, ROUND_HALF_UP

from fastapi import HTTPException, status

from app.models.enums import BenchmarkType, TransactionType
from app.repositories.market_data import MarketDataRepository
from app.repositories.pnl import PnLRepository
from app.schemas.pnl import (
    AssetPnLBreakdown,
    PortfolioPerformanceTimeseriesQuery,
    PortfolioPerformanceTimeseriesResponse,
    PortfolioPnLSummaryResponse,
    PortfolioTimeseriesPoint,
)
from app.services.market_price_service import MarketPriceService, SelectedMarketPrice
from app.services.portfolio_calculation_engine import PortfolioCalculationEngine

logger = logging.getLogger("pnl_calculator")

FOUR_PLACES = Decimal("0.0001")
ZERO = Decimal("0.0000")
HUNDRED = Decimal("100")


def q4(value: Decimal) -> Decimal:
    return value.quantize(FOUR_PLACES, rounding=ROUND_HALF_UP)


def safe_pct(numerator: Decimal, denominator: Decimal) -> Decimal:
    if denominator == ZERO:
        return ZERO
    return q4((numerator / denominator) * HUNDRED)


def safe_weight(value: Decimal, total: Decimal) -> Decimal:
    if total == ZERO:
        return ZERO
    return q4(value / total)


class PnLCalculatorService:
    """
    Quant engine for real-time and historical portfolio analytics.

    Integrates with MarketPersistenceService for price resolution:
      - Redis-first price lookups for fast reads
      - DB fallback when cache is unavailable
      - Freshness awareness for staleness detection

    Implemented formulas:
      market_value      = Σ(open_position_quantity × latest_price_if_available)
      cost_basis        = Σ(open_position_remaining_cost_basis)
      unrealized_pnl    = market_value - cost_basis
      realized_pnl      = Σ(realized_pnl from trade ledger sell accounting)
      cash_flow_pnl     = Σ(cash dividend/fee/tax events from cash ledger)
      total_pnl         = realized_pnl + unrealized_pnl + cash_flow_pnl
      ROI (%)           = (total_pnl / net_invested_capital) × 100
      net_invested_capital = max(net_cash_contributions, cost_basis)
      Weight            = Asset Value / Total Portfolio Value
    """

    def __init__(
        self,
        pnl_repo: PnLRepository,
        market_repo: MarketDataRepository,
        market_persistence: "MarketPersistenceService | None" = None,
    ) -> None:
        self.pnl_repo = pnl_repo
        self.market_repo = market_repo
        self._market_persistence = market_persistence

    def _get_market_persistence(self) -> "MarketPersistenceService":
        """Lazy-load market persistence service."""
        if self._market_persistence is None:
            if not hasattr(self.market_repo, "db"):
                raise AttributeError("market_repo does not expose a db session")
            from app.services.market_persistence import MarketPersistenceService
            # Note: This is a fallback; ideally injected via DI
            # For now, we'll use the market_repo's session
            self._market_persistence = MarketPersistenceService(self.market_repo.db)
        return self._market_persistence

    async def _resolve_latest_price_for_asset(self, asset: object) -> tuple[Decimal, bool, datetime | None]:
        """Resolve latest price from injected persistence or test/local asset fields."""
        selected = await self._resolve_latest_price_snapshot_for_asset(asset)
        return (
            selected.selected_valuation_price or ZERO,
            not selected.is_stale and selected.selected_valuation_price is not None,
            selected.price_as_of,
        )

    async def _resolve_latest_price_snapshot_for_asset(self, asset: object) -> SelectedMarketPrice:
        """Resolve latest price and selection metadata for one asset."""
        selector = MarketPriceService()
        if hasattr(asset, "last_trade_price") or hasattr(asset, "closing_price"):
            return selector.select_from_asset(asset, use_case="live")
        if self._market_persistence is not None or hasattr(self.market_repo, "db"):
            market_persistence = self._get_market_persistence()
            ins_code = getattr(asset, "tsetmc_id", None)
            price, is_fresh, last_updated = await market_persistence.get_latest_price(
                asset.id,
                ins_code=ins_code,
            )
            return selector.select(
                asset_id=getattr(asset, "id", None),
                symbol=str(getattr(asset, "ticker_symbol", "")),
                instrument_id=ins_code,
                last_price=price if price and price > ZERO else getattr(asset, "last_trade_price", None),
                closing_price=getattr(asset, "closing_price", None),
                yesterday_price=getattr(asset, "previous_close_price", None),
                price_as_of=last_updated,
                is_tradeable=bool(getattr(asset, "is_tradeable", True)),
                source="MARKET_PERSISTENCE",
                use_case="live",
            )

        return selector.select(
            asset_id=getattr(asset, "id", None),
            symbol=str(getattr(asset, "ticker_symbol", "")),
            instrument_id=getattr(asset, "tsetmc_id", None),
            last_price=getattr(asset, "current_price", None),
            closing_price=None,
            yesterday_price=getattr(asset, "previous_close_price", None),
            price_as_of=getattr(asset, "price_updated_at", None),
            is_tradeable=bool(getattr(asset, "is_tradeable", True)),
            source="LEGACY_ASSET_CURRENT_PRICE",
            use_case="live",
        )

    async def calculate_realtime_summary(
        self,
        *,
        portfolio_id: uuid.UUID,
        user_id: uuid.UUID,
    ) -> PortfolioPnLSummaryResponse:
        """Calculate real-time PnL summary with freshness-aware pricing.

        Uses MarketPersistenceService for price resolution:
          - Redis cache for fast reads
          - DB fallback when cache unavailable
          - Freshness metadata for staleness detection
        """
        portfolio = await self.pnl_repo.get_portfolio_for_user(portfolio_id=portfolio_id, user_id=user_id)
        if portfolio is None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Portfolio not found")

        if hasattr(self.pnl_repo, "fetch_trade_ledger_with_assets"):
            ledger_rows = await self.pnl_repo.fetch_trade_ledger_with_assets(portfolio_id)  # type: ignore[attr-defined]
            if ledger_rows:
                return await self._calculate_realtime_summary_from_ledger(
                    portfolio=portfolio,
                    portfolio_id=portfolio_id,
                    ledger_rows=ledger_rows,
                )

        rows = await self.pnl_repo.fetch_live_positions(portfolio_id)
        all_positions = await self.pnl_repo.fetch_all_positions(portfolio_id)

        total_current = ZERO
        total_cost_basis = ZERO
        total_unrealized_known = ZERO
        per_asset: list[AssetPnLBreakdown] = []
        missing_price_assets: list[str] = []
        stale_price_assets: list[str] = []
        sanity_flags: list[str] = []
        market_status = "unknown"

        for position, asset in rows:
            quantity = q4(position.total_quantity)
            if quantity <= ZERO:
                continue
            total_cost = q4(position.total_cost_basis)

            # Resolve price with Redis-first fallback, or local asset fields in
            # unit tests where no DB-backed market repository is injected.
            selected = await self._resolve_latest_price_snapshot_for_asset(asset)
            market_status = selected.market_status
            live_price = q4(selected.selected_valuation_price) if selected.selected_valuation_price is not None else ZERO

            # Determine price status
            if selected.selected_valuation_price is None:
                price_status = "missing_price"
                missing_price_assets.append(asset.ticker_symbol)
            elif selected.is_stale:
                price_status = "stale_price"
                stale_price_assets.append(asset.ticker_symbol)
            else:
                price_status = selected.status if selected.status != "halted" else "ok"

            current_value = q4(quantity * live_price) if selected.selected_valuation_price is not None else ZERO
            unrealized = q4(current_value - total_cost) if selected.selected_valuation_price is not None else ZERO

            # Calculate unrealized PnL percent
            unrealized_pnl_percent = safe_pct(unrealized, total_cost)

            # Calculate daily change if previous_close_price is available
            daily_change = None
            daily_change_percent = None
            previous_close = getattr(asset, "previous_close_price", None)
            if live_price > ZERO and previous_close is not None and previous_close > ZERO:
                daily_change = q4(live_price - previous_close)
                daily_change_percent = safe_pct(daily_change, previous_close)

            total_current = q4(total_current + current_value)
            total_cost_basis = q4(total_cost + total_cost_basis)
            total_unrealized_known = q4(total_unrealized_known + unrealized)

            if position.weighted_avg_cost < ZERO:
                sanity_flags.append(f"NEGATIVE_WAC:{asset.ticker_symbol}")
            if quantity > ZERO and live_price > ZERO:
                price_ratio = q4(live_price / q4(position.weighted_avg_cost)) if position.weighted_avg_cost > ZERO else ZERO
                if position.weighted_avg_cost > ZERO and (price_ratio > Decimal("100.0000") or price_ratio < Decimal("0.0100")):
                    sanity_flags.append(f"PRICE_ANOMALY:{asset.ticker_symbol}")

            # Calculate freshness seconds
            data_freshness_seconds = None
            if selected.price_as_of is not None:
                now_utc = datetime.now(UTC)
                last_updated = selected.price_as_of
                if last_updated.tzinfo is None:
                    last_updated = last_updated.replace(tzinfo=UTC)
                data_freshness_seconds = int((now_utc - last_updated).total_seconds())

            per_asset.append(
                AssetPnLBreakdown(
                    asset_id=asset.id,
                    ticker_symbol=asset.ticker_symbol,
                    name=getattr(asset, "name_fa", None) or getattr(asset, "name_en", None),
                    quantity=quantity,
                    weighted_avg_cost=q4(position.weighted_avg_cost),
                    total_cost=total_cost,
                    live_price=live_price,
                    last_price=selected.last_price,
                    closing_price=selected.closing_price,
                    selected_valuation_price=selected.selected_valuation_price,
                    selected_price_source=selected.selected_price_source,
                    current_value=current_value,
                    market_value=current_value if selected.selected_valuation_price is not None else None,
                    unrealized_pnl=unrealized,
                    realized_pnl=q4(position.cumulative_realized_pnl),
                    symbol=asset.ticker_symbol,
                    average_cost=q4(position.weighted_avg_cost),
                    remaining_cost_basis=total_cost,
                    current_price=live_price if selected.selected_valuation_price is not None else None,
                    current_price_type="TSETMC" if selected.selected_valuation_price is not None else "MISSING",
                    current_price_source=(
                        f"TSETMC:{selected.selected_price_source}"
                        if selected.selected_valuation_price is not None
                        else "MISSING"
                    ),
                    current_price_date=selected.price_as_of,
                    total_pnl=q4(position.cumulative_realized_pnl + unrealized),
                    total_pnl_percent=safe_pct(q4(position.cumulative_realized_pnl + unrealized), total_cost),
                    data_status="missing_market_price" if selected.selected_valuation_price is None else (
                        "stale_market_price" if selected.is_stale else "ok"
                    ),
                    weight=ZERO,
                    unrealized_pnl_percent=unrealized_pnl_percent,
                    daily_change=daily_change,
                    daily_change_percent=daily_change_percent,
                    is_price_fresh=not selected.is_stale and selected.selected_valuation_price is not None,
                    price_timestamp=selected.price_as_of,
                    price_as_of=selected.price_as_of,
                    is_stale=selected.is_stale,
                    is_current_session=selected.is_current_session,
                    status=selected.status,
                    data_freshness_seconds=data_freshness_seconds,
                    is_tradeable=getattr(asset, "is_tradeable", True),
                    price_status=price_status,
                )
            )

        for position, asset in all_positions:
            if q4(position.total_quantity) < ZERO:
                sanity_flags.append(f"NEGATIVE_QUANTITY:{asset.ticker_symbol}")

        total_unrealized = total_unrealized_known
        total_realized = q4(await self.pnl_repo.sum_realized_sell_pnl(portfolio_id))
        income_cash_flows = q4(await self.pnl_repo.sum_income_cash_flows(portfolio_id))
        total_pnl = q4(total_realized + total_unrealized + income_cash_flows)

        net_contributions = q4(await self.pnl_repo.sum_net_cash_contributions(portfolio_id))
        if net_contributions <= ZERO:
            net_invested_capital = total_cost_basis
        else:
            net_invested_capital = net_contributions
        roi_percent = safe_pct(total_pnl, net_invested_capital)

        if total_cost_basis > ZERO and total_current > ZERO:
            ratio = q4(total_cost_basis / total_current)
            if ratio > Decimal("100.0000") or ratio < Decimal("0.0100"):
                sanity_flags.append("ABSURD_COST_BASIS_TO_MARKET_VALUE_RATIO")
        elif total_cost_basis > ZERO and total_current == ZERO:
            sanity_flags.append("OPEN_POSITIONS_WITH_ZERO_MARKET_VALUE")

        # Add staleness warning if many prices are stale
        if len(stale_price_assets) > len(rows) * 0.5:
            sanity_flags.append("MAJORITY_OF_PRICES_STALE")

        weighted_assets: list[AssetPnLBreakdown] = []
        for item in per_asset:
            weighted_assets.append(item.model_copy(update={"weight": safe_weight(item.current_value, total_current)}))

        # Calculate portfolio-level unrealized PnL percent
        unrealized_pnl_percent = safe_pct(total_unrealized, total_cost_basis)

        # Determine data quality status
        if len(missing_price_assets) == len(rows) and len(rows) > 0:
            data_quality_status = "insufficient_data"
        elif len(missing_price_assets) > 0:
            data_quality_status = "partial"
        elif len(stale_price_assets) > 0:
            data_quality_status = "stale"
        else:
            data_quality_status = "ok"

        return PortfolioPnLSummaryResponse(
            portfolio_id=portfolio.id,
            portfolio_name=getattr(portfolio, "name", None),
            base_currency=portfolio.base_currency,
            total_current_value=total_current,
            total_invested=total_cost_basis,
            total_unrealized_pnl=total_unrealized,
            total_realized_pnl=total_realized,
            total_pnl=total_pnl,
            cash_flow_pnl=income_cash_flows,
            net_invested_capital=net_invested_capital,
            roi_percent=roi_percent,
            valuation_is_partial=bool(missing_price_assets),
            missing_price_assets=sorted(set(missing_price_assets)),
            sanity_flags=sorted(set(sanity_flags)),
            assets=weighted_assets,
            # Enhanced fields
            unrealized_pnl_percent=unrealized_pnl_percent,
            as_of_timestamp=datetime.now(UTC),
            stale_price_assets=sorted(set(stale_price_assets)),
            holdings_count=len(weighted_assets),
            missing_price_count=len(set(missing_price_assets)),
            stale_price_count=len(set(stale_price_assets)),
            total_market_value=total_current,
            total_cost_basis=total_cost_basis,
            total_cash_balance=net_contributions,
            total_portfolio_value=q4(total_current + net_contributions),
            missing_market_price_count=len(set(missing_price_assets)),
            as_of=datetime.now(UTC),
            market_status=market_status,
            data_quality_status=data_quality_status,
        )

    async def _calculate_realtime_summary_from_ledger(
        self,
        *,
        portfolio: object,
        portfolio_id: uuid.UUID,
        ledger_rows: list[tuple[object, object]],
    ) -> PortfolioPnLSummaryResponse:
        engine = PortfolioCalculationEngine()
        transactions = [transaction for transaction, _asset in ledger_rows]
        assets_by_id = {asset.id: asset for _transaction, asset in ledger_rows}
        transfers = []
        if hasattr(self.pnl_repo, "fetch_confirmed_reconciliation_transfers"):
            transfers = await self.pnl_repo.fetch_confirmed_reconciliation_transfers(  # type: ignore[attr-defined]
                portfolio_id
            )
        ledger_holdings = engine.replay_transactions(
            transactions,
            update_transactions=False,
            incoming_transfers=[
                item for item in transfers if item.destination_portfolio_id == portfolio_id
            ],
            outgoing_transfers=[
                item for item in transfers if item.source_portfolio_id == portfolio_id
            ],
        )

        per_asset: list[AssetPnLBreakdown] = []
        valued_holdings = []
        missing_price_assets: list[str] = []
        stale_price_assets: list[str] = []
        sanity_flags: list[str] = []
        market_status = "unknown"

        for asset_id, holding in ledger_holdings.items():
            if holding.quantity <= ZERO:
                continue
            asset = assets_by_id.get(asset_id)
            if asset is None:
                continue

            selected = MarketPriceService().select_from_asset(asset, use_case="live")
            market_status = selected.market_status
            valued = engine.value_holding(
                holding=holding,
                asset=asset,
                selected_price=selected,
            )
            valued_holdings.append(valued)

            if valued.data_status == "missing_market_price":
                missing_price_assets.append(valued.symbol)
                price_status = "missing_price"
            elif valued.data_status == "stale_market_price":
                stale_price_assets.append(valued.symbol)
                price_status = "stale_price"
            else:
                price_status = selected.status if selected.status != "halted" else "ok"

            data_freshness_seconds = None
            if selected.price_as_of is not None:
                now_utc = datetime.now(UTC)
                last_updated = selected.price_as_of
                if last_updated.tzinfo is None:
                    last_updated = last_updated.replace(tzinfo=UTC)
                data_freshness_seconds = int((now_utc - last_updated).total_seconds())

            previous_close = getattr(asset, "previous_close_price", None)
            daily_change = None
            daily_change_percent = None
            if valued.current_price is not None and previous_close is not None and previous_close > ZERO:
                daily_change = q4(valued.current_price - previous_close)
                daily_change_percent = safe_pct(daily_change, q4(previous_close))

            current_value = q4(valued.market_value or ZERO)
            total_cost = q4(valued.remaining_cost_basis)
            total_pnl = q4(valued.total_pnl)
            per_asset.append(
                AssetPnLBreakdown(
                    asset_id=asset.id,
                    ticker_symbol=asset.ticker_symbol,
                    name=getattr(asset, "name_fa", None) or getattr(asset, "name_en", None),
                    symbol=valued.symbol,
                    quantity=q4(valued.quantity),
                    weighted_avg_cost=q4(valued.average_cost),
                    average_cost=q4(valued.average_cost),
                    total_cost=total_cost,
                    remaining_cost_basis=total_cost,
                    live_price=q4(valued.current_price or ZERO),
                    current_price=q4(valued.current_price) if valued.current_price is not None else None,
                    current_price_type=valued.current_price_type,
                    current_price_source=valued.current_price_source,
                    current_price_date=valued.current_price_date,
                    last_price=selected.last_price,
                    closing_price=selected.closing_price,
                    selected_valuation_price=selected.selected_valuation_price,
                    selected_price_source=selected.selected_price_source,
                    current_value=current_value,
                    market_value=current_value if valued.market_value is not None else None,
                    unrealized_pnl=q4(valued.unrealized_pnl or ZERO),
                    realized_pnl=q4(valued.realized_pnl),
                    total_pnl=total_pnl,
                    total_pnl_percent=q4(valued.total_pnl_percent),
                    data_status=valued.data_status,
                    warnings=valued.warnings,
                    weight=ZERO,
                    unrealized_pnl_percent=q4(valued.unrealized_pnl_percent),
                    daily_change=daily_change,
                    daily_change_percent=daily_change_percent,
                    is_price_fresh=not selected.is_stale and selected.selected_valuation_price is not None,
                    price_timestamp=selected.price_as_of,
                    price_as_of=selected.price_as_of,
                    is_stale=selected.is_stale,
                    is_current_session=selected.is_current_session,
                    status=selected.status,
                    data_freshness_seconds=data_freshness_seconds,
                    is_tradeable=getattr(asset, "is_tradeable", True),
                    price_status=price_status,
                )
            )

            if holding.warnings:
                sanity_flags.extend(f"LEDGER_WARNING:{valued.symbol}:{warning}" for warning in holding.warnings)
            if holding.average_cost < ZERO:
                sanity_flags.append(f"NEGATIVE_WAC:{valued.symbol}")

        if hasattr(self.pnl_repo, "sum_cash_balance"):
            cash_balance = q4(await self.pnl_repo.sum_cash_balance(portfolio_id))  # type: ignore[attr-defined]
        else:
            cash_balance = q4(await self.pnl_repo.sum_net_cash_contributions(portfolio_id))
        summary = engine.summarize(holdings=valued_holdings, cash_balance=cash_balance)

        weighted_assets = [
            item.model_copy(update={"weight": safe_weight(item.current_value, q4(summary.total_market_value))})
            for item in per_asset
        ]

        income_cash_flows = q4(await self.pnl_repo.sum_income_cash_flows(portfolio_id))
        # Realized PnL belongs to the full transaction ledger, not only to
        # holdings that remain open. `valued_holdings` intentionally excludes
        # zero-quantity symbols, so summing it would lose fully closed trades.
        total_realized = q4(
            sum((holding.realized_pnl for holding in ledger_holdings.values()), ZERO)
        )
        total_unrealized = q4(summary.total_unrealized_pnl)
        total_pnl = q4(total_realized + total_unrealized + income_cash_flows)
        net_contributions = q4(await self.pnl_repo.sum_net_cash_contributions(portfolio_id))
        net_invested_capital = net_contributions if net_contributions > ZERO else q4(summary.total_cost_basis)
        roi_percent = safe_pct(total_pnl, net_invested_capital)

        if len(missing_price_assets) == len(weighted_assets) and weighted_assets:
            data_quality_status = "insufficient_data"
        elif missing_price_assets:
            data_quality_status = "partial"
        elif stale_price_assets:
            data_quality_status = "stale"
        else:
            data_quality_status = "ok"

        return PortfolioPnLSummaryResponse(
            portfolio_id=portfolio.id,
            portfolio_name=getattr(portfolio, "name", None),
            base_currency=portfolio.base_currency,
            total_current_value=q4(summary.total_market_value),
            total_market_value=q4(summary.total_market_value),
            total_invested=q4(summary.total_cost_basis),
            total_cost_basis=q4(summary.total_cost_basis),
            total_cash_balance=cash_balance,
            total_portfolio_value=q4(summary.total_portfolio_value),
            total_unrealized_pnl=total_unrealized,
            total_realized_pnl=total_realized,
            total_pnl=total_pnl,
            cash_flow_pnl=income_cash_flows,
            net_invested_capital=net_invested_capital,
            roi_percent=roi_percent,
            valuation_is_partial=bool(missing_price_assets),
            missing_price_assets=sorted(set(missing_price_assets)),
            sanity_flags=sorted(set(sanity_flags)),
            assets=weighted_assets,
            unrealized_pnl_percent=q4(summary.total_unrealized_pnl_percent),
            as_of_timestamp=datetime.now(UTC),
            stale_price_assets=sorted(set(stale_price_assets)),
            holdings_count=summary.holdings_count,
            missing_price_count=summary.missing_market_price_count,
            missing_market_price_count=summary.missing_market_price_count,
            stale_price_count=len(set(stale_price_assets)),
            as_of=datetime.now(UTC),
            market_status=market_status,
            data_quality_status=data_quality_status,
        )

    async def calculate_performance_timeseries(
        self,
        *,
        portfolio_id: uuid.UUID,
        user_id: uuid.UUID,
        query: PortfolioPerformanceTimeseriesQuery,
    ) -> PortfolioPerformanceTimeseriesResponse:
        portfolio = await self.pnl_repo.get_portfolio_for_user(portfolio_id=portfolio_id, user_id=user_id)
        if portfolio is None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Portfolio not found")

        end_dt = datetime.combine(query.end_date, time.max)
        transactions = await self.pnl_repo.fetch_transactions_until(portfolio_id=portfolio_id, end_dt=end_dt)

        events_by_date: dict[date, list] = defaultdict(list)
        holdings: dict[uuid.UUID, Decimal] = defaultdict(lambda: ZERO)

        for txn in transactions:
            txn_day = txn.executed_at.date()
            if txn_day < query.start_date:
                if txn.transaction_type == TransactionType.BUY:
                    holdings[txn.asset_id] = q4(holdings[txn.asset_id] + txn.quantity)
                else:
                    holdings[txn.asset_id] = q4(max(ZERO, holdings[txn.asset_id] - txn.quantity))
                continue
            events_by_date[txn_day].append(txn)

        asset_ids = list({txn.asset_id for txn in transactions} | set(holdings.keys()))
        asset_price_rows = await self.market_repo.fetch_asset_price_rows(asset_ids=asset_ids, end_date=query.end_date)

        prices_by_asset: dict[uuid.UUID, list] = defaultdict(list)
        for row in asset_price_rows:
            prices_by_asset[row.asset_id].append(row)

        benchmark_rows = await self.pnl_repo.fetch_benchmark_history(
            benchmark_types=query.benchmarks,
            start_date=query.start_date,
            end_date=query.end_date,
        )
        benchmark_series: dict[BenchmarkType, list] = defaultdict(list)
        for row in benchmark_rows:
            benchmark_series[row.benchmark_type].append(row)

        points: list[PortfolioTimeseriesPoint] = []
        price_index: dict[uuid.UUID, int] = defaultdict(int)
        last_asset_price: dict[uuid.UUID, Decimal] = {}
        benchmark_index: dict[BenchmarkType, int] = defaultdict(int)
        last_benchmark_price: dict[BenchmarkType, Decimal] = {}

        day = query.start_date
        base_portfolio_value: Decimal | None = None
        base_benchmark_values: dict[BenchmarkType, Decimal] = {}

        while day <= query.end_date:
            for txn in events_by_date.get(day, []):
                if txn.transaction_type == TransactionType.BUY:
                    holdings[txn.asset_id] = q4(holdings[txn.asset_id] + txn.quantity)
                else:
                    holdings[txn.asset_id] = q4(max(ZERO, holdings[txn.asset_id] - txn.quantity))

            portfolio_value = ZERO

            for asset_id, quantity in holdings.items():
                if quantity <= ZERO:
                    continue
                rows = prices_by_asset.get(asset_id, [])
                idx = price_index[asset_id]
                while idx < len(rows) and rows[idx].date <= day:
                    price = rows[idx].adjusted_close if query.adjusted_prices else rows[idx].close_price
                    last_asset_price[asset_id] = q4(price)
                    idx += 1
                price_index[asset_id] = idx

                market_price = last_asset_price.get(asset_id)
                if market_price is None:
                    continue
                portfolio_value = q4(portfolio_value + q4(quantity * market_price))

            if base_portfolio_value is None and portfolio_value > ZERO:
                base_portfolio_value = portfolio_value

            benchmark_values: dict[BenchmarkType, Decimal] = {}
            benchmark_returns: dict[BenchmarkType, Decimal] = {}

            for benchmark_type in query.benchmarks:
                series = benchmark_series.get(benchmark_type, [])
                b_idx = benchmark_index[benchmark_type]
                while b_idx < len(series) and series[b_idx].date <= day:
                    b_price = series[b_idx].adjusted_close if query.adjusted_prices else series[b_idx].close_price
                    last_benchmark_price[benchmark_type] = q4(b_price)
                    b_idx += 1
                benchmark_index[benchmark_type] = b_idx

                benchmark_price = last_benchmark_price.get(benchmark_type, ZERO)
                benchmark_values[benchmark_type] = benchmark_price

                if benchmark_type not in base_benchmark_values and benchmark_price > ZERO:
                    base_benchmark_values[benchmark_type] = benchmark_price

                benchmark_returns[benchmark_type] = safe_pct(
                    benchmark_price - base_benchmark_values.get(benchmark_type, ZERO),
                    base_benchmark_values.get(benchmark_type, ZERO),
                )

            portfolio_return = safe_pct(
                portfolio_value - (base_portfolio_value or ZERO),
                (base_portfolio_value or ZERO),
            )

            points.append(
                PortfolioTimeseriesPoint(
                    date=day,
                    portfolio_value=portfolio_value,
                    portfolio_return_pct=portfolio_return,
                    benchmark_values=benchmark_values,
                    benchmark_return_pct=benchmark_returns,
                )
            )

            day += timedelta(days=1)

        return PortfolioPerformanceTimeseriesResponse(
            portfolio_id=portfolio.id,
            adjusted_prices=query.adjusted_prices,
            points=points,
        )
