"""Returns computation service for historical performance analytics.

Computes:
  - Period returns (1D, 1W, 1M, 3M, 6M, 1Y, YTD, Inception)
  - Return series for charting
  - Risk-adjusted metrics (annualized return, volatility)
  - Benchmark-relative returns

Design:
  - All calculations use adjusted prices by default (corporate-action safe)
  - Handles missing dates and non-trading days gracefully
  - Returns DataQuality indicator for insufficient data
  - Deterministic and testable calculations
  - Structured logging for observability
"""

from __future__ import annotations

import logging
import math
import uuid
from dataclasses import dataclass
from datetime import date, timedelta
from decimal import Decimal, ROUND_HALF_UP
from typing import Any

from starlette.concurrency import run_in_threadpool

from app.models.enums import BenchmarkType
from app.repositories.returns_read import (
    PriceRow,
    BenchmarkPriceRow,
    ReturnsReadRepository,
)
from app.schemas.returns import (
    BenchmarkComparisonDTO,
    DataQuality,
    PeriodReturnDTO,
    ReturnPeriod,
    ReturnSeriesPointDTO,
    ReturnSeriesResponseDTO,
    ReturnsSummaryResponseDTO,
)

logger = logging.getLogger("returns_service")

TRADING_DAYS_PER_YEAR = 252
ZERO = Decimal("0.0000")
HUNDRED = Decimal("100")


@dataclass(slots=True, frozen=True)
class ReturnCalculationInput:
    """Input for return calculation."""
    asset_id: uuid.UUID
    ticker_symbol: str
    asset_name: str | None
    prices: list[PriceRow]
    benchmark_prices: dict[BenchmarkType, list[BenchmarkPriceRow]]
    start_date: date
    end_date: date
    use_adjusted: bool = True


@dataclass(slots=True, frozen=True)
class ReturnResult:
    """Internal result of return calculation."""
    return_pct: float | None
    annualized_return_pct: float | None
    start_value: float | None
    end_value: float | None
    trading_days: int
    data_quality: DataQuality


class ReturnsService:
    """Service for computing historical returns."""

    def __init__(self, repository: ReturnsReadRepository) -> None:
        self._repo = repository

    # ═══════════════════════════════════════════════════════════════
    # Public API
    # ═══════════════════════════════════════════════════════════════

    async def get_asset_returns_summary(
        self,
        *,
        asset_id: uuid.UUID,
        as_of_date: date | None = None,
    ) -> ReturnsSummaryResponseDTO:
        """Compute returns summary for a single asset across all standard periods.

        Args:
            asset_id: Asset UUID.
            as_of_date: Reference date for calculations (default: today).

        Returns:
            ReturnsSummaryResponseDTO with all period returns.
        """
        logger.info(
            "returns.summary.request asset_id=%s as_of=%s",
            asset_id,
            as_of_date or "today",
        )

        target_date = as_of_date or date.today()
        asset = await self._repo.get_asset_info(asset_id)

        if asset is None:
            logger.warning("returns.summary.asset_not_found asset_id=%s", asset_id)
            return self._build_empty_summary(
                portfolio_id=asset_id,
                as_of_date=target_date,
            )

        # Get inception date
        inception_date = await self._repo.get_asset_inception_date(asset_id)
        if inception_date is None:
            logger.info("returns.summary.no_data asset_id=%s", asset_id)
            return self._build_empty_summary(
                portfolio_id=asset_id,
                as_of_date=target_date,
                inception_date=None,
            )

        # Compute returns for each period
        periods = await self._compute_all_periods(
            asset_id=asset_id,
            target_date=target_date,
            inception_date=inception_date,
        )

        # Compute benchmark comparisons
        benchmark_comparisons = await self._compute_benchmark_comparisons(
            asset_id=asset_id,
            target_date=target_date,
        )

        # Get latest computed timestamp
        latest_price = await self._repo.get_latest_price(asset_id, target_date)
        last_computed_at = None
        if latest_price is not None:
            last_computed_at = datetime.combine(
                latest_price.date, datetime.min.time()
            ).replace(tzinfo=UTC)

        logger.info(
            "returns.summary.complete asset_id=%s periods=%d",
            asset_id,
            len(periods),
        )

        return ReturnsSummaryResponseDTO(
            portfolio_id=asset_id,
            base_currency="IRR",
            as_of_date=target_date,
            inception_date=inception_date,
            period_1m=periods.get(ReturnPeriod.ONE_MONTH),
            period_3m=periods.get(ReturnPeriod.THREE_MONTHS),
            period_6m=periods.get(ReturnPeriod.SIX_MONTHS),
            period_1y=periods.get(ReturnPeriod.ONE_YEAR),
            period_ytd=periods.get(ReturnPeriod.YEAR_TO_DATE),
            period_inception=periods.get(ReturnPeriod.INCEPTION),
            benchmark_comparisons=benchmark_comparisons,
            data_quality=self._determine_overall_quality(periods),
            is_stale=self._is_data_stale(latest_price, target_date),
            last_computed_at=last_computed_at,
        )

    async def get_asset_return_series(
        self,
        *,
        asset_id: uuid.UUID,
        period: ReturnPeriod,
        as_of_date: date | None = None,
    ) -> ReturnSeriesResponseDTO:
        """Compute return time series for charting.

        Args:
            asset_id: Asset UUID.
            period: Return period (1M, 3M, 6M, 1Y, YTD).
            as_of_date: Reference date (default: today).

        Returns:
            ReturnSeriesResponseDTO with daily return points.
        """
        logger.info(
            "returns.series.request asset_id=%s period=%s",
            asset_id,
            period.value,
        )

        target_date = as_of_date or date.today()
        asset = await self._repo.get_asset_info(asset_id)

        if asset is None:
            return self._build_empty_series(
                portfolio_id=asset_id,
                period=period,
                start_date=target_date,
                end_date=target_date,
            )

        # Determine date range
        start_date = self._resolve_period_start(target_date, period)
        if start_date is None:
            return self._build_empty_series(
                portfolio_id=asset_id,
                period=period,
                start_date=target_date,
                end_date=target_date,
            )

        # Fetch price history
        prices = await self._repo.get_price_history(
            asset_id=asset_id,
            start_date=start_date,
            end_date=target_date,
        )

        if len(prices) < 2:
            logger.info(
                "returns.series.insufficient_data asset_id=%s count=%d",
                asset_id,
                len(prices),
            )
            return self._build_empty_series(
                portfolio_id=asset_id,
                period=period,
                start_date=start_date,
                end_date=target_date,
            )

        # Compute return series
        points = await run_in_threadpool(
            self._compute_return_series,
            prices,
        )

        # Compute summary metrics
        total_return = self._compute_total_return(prices)
        annualized = self._annualize_return(
            total_return,
            len(prices),
        )

        return ReturnSeriesResponseDTO(
            portfolio_id=asset_id,
            period=period,
            frequency="daily",
            base_currency="IRR",
            start_date=start_date,
            end_date=target_date,
            points=points,
            total_return_pct=total_return,
            annualized_return_pct=annualized,
            data_quality=DataQuality.COMPLETE if len(prices) > 10 else DataQuality.PARTIAL,
        )

    # ═══════════════════════════════════════════════════════════════
    # Period Computation
    # ═══════════════════════════════════════════════════════════════

    async def _compute_all_periods(
        self,
        asset_id: uuid.UUID,
        target_date: date,
        inception_date: date,
    ) -> dict[ReturnPeriod, PeriodReturnDTO]:
        """Compute returns for all standard periods."""
        periods: dict[ReturnPeriod, PeriodReturnDTO] = {}

        # Define period boundaries
        period_defs = [
            (ReturnPeriod.ONE_MONTH, target_date - timedelta(days=30)),
            (ReturnPeriod.THREE_MONTHS, target_date - timedelta(days=90)),
            (ReturnPeriod.SIX_MONTHS, target_date - timedelta(days=180)),
            (ReturnPeriod.ONE_YEAR, target_date - timedelta(days=365)),
            (ReturnPeriod.YEAR_TO_DATE, date(target_date.year, 1, 1)),
            (ReturnPeriod.INCEPTION, inception_date),
        ]

        for period, start_date in period_defs:
            if start_date < inception_date:
                start_date = inception_date

            if start_date >= target_date:
                continue

            prices = await self._repo.get_price_history(
                asset_id=asset_id,
                start_date=start_date,
                end_date=target_date,
            )

            if len(prices) < 2:
                data_quality = DataQuality.INSUFFICIENT
                if len(prices) == 1:
                    data_quality = DataQuality.PARTIAL
            else:
                data_quality = DataQuality.COMPLETE

            result = self._compute_period_return(prices)

            periods[period] = PeriodReturnDTO(
                period=period,
                return_pct=result.return_pct,
                annualized_return_pct=result.annualized_return_pct,
                start_value=result.start_value,
                end_value=result.end_value,
                start_date=start_date,
                end_date=target_date,
                trading_days=result.trading_days,
                data_quality=data_quality,
            )

        return periods

    def _compute_period_return(
        self,
        prices: list[PriceRow],
    ) -> ReturnResult:
        """Compute return for a single period."""
        if len(prices) < 2:
            return ReturnResult(
                return_pct=None,
                annualized_return_pct=None,
                start_value=None,
                end_value=None,
                trading_days=len(prices),
                data_quality=DataQuality.INSUFFICIENT,
            )

        start_price = float(prices[0].adjusted_close)
        end_price = float(prices[-1].adjusted_close)

        if start_price <= 0:
            return ReturnResult(
                return_pct=None,
                annualized_return_pct=None,
                start_value=start_price,
                end_value=end_price,
                trading_days=len(prices),
                data_quality=DataQuality.INSUFFICIENT,
            )

        total_return = ((end_price / start_price) - 1) * 100
        trading_days = len(prices)
        annualized = self._annualize_return(total_return, trading_days)

        return ReturnResult(
            return_pct=round(total_return, 2),
            annualized_return_pct=round(annualized, 2) if annualized is not None else None,
            start_value=round(start_price, 2),
            end_value=round(end_price, 2),
            trading_days=trading_days,
            data_quality=DataQuality.COMPLETE,
        )

    def _compute_total_return(self, prices: list[PriceRow]) -> float | None:
        """Compute total return from price series."""
        if len(prices) < 2:
            return None

        start_price = float(prices[0].adjusted_close)
        end_price = float(prices[-1].adjusted_close)

        if start_price <= 0:
            return None

        return round(((end_price / start_price) - 1) * 100, 2)

    def _annualize_return(
        self,
        total_return_pct: float | None,
        trading_days: int,
    ) -> float | None:
        """Annualize a total return."""
        if total_return_pct is None or trading_days <= 0:
            return None

        # Convert percentage to decimal
        total_return_decimal = total_return_pct / 100

        # Annualize
        years = trading_days / TRADING_DAYS_PER_YEAR
        if years <= 0:
            return None

        annualized = ((1 + total_return_decimal) ** (1 / years) - 1) * 100
        return round(annualized, 2)

    # ═══════════════════════════════════════════════════════════════
    # Return Series
    # ═══════════════════════════════════════════════════════════════

    def _compute_return_series(
        self,
        prices: list[PriceRow],
    ) -> list[ReturnSeriesPointDTO]:
        """Compute daily return series from price history."""
        if len(prices) < 2:
            return []

        points: list[ReturnSeriesPointDTO] = []
        base_price = float(prices[0].adjusted_close)

        for i, price_row in enumerate(prices):
            current_price = float(price_row.adjusted_close)
            cumulative_return = ((current_price / base_price) - 1) * 100 if base_price > 0 else 0

            daily_return = None
            if i > 0:
                prev_price = float(prices[i - 1].adjusted_close)
                if prev_price > 0:
                    daily_return = ((current_price / prev_price) - 1) * 100

            points.append(
                ReturnSeriesPointDTO(
                    point_date=price_row.date,
                    value=round(current_price / base_price, 6) if base_price > 0 else 1.0,
                    daily_return_pct=round(daily_return, 4) if daily_return is not None else None,
                    cumulative_return_pct=round(cumulative_return, 2),
                )
            )

        return points

    # ═══════════════════════════════════════════════════════════════
    # Benchmark Comparison
    # ═══════════════════════════════════════════════════════════════

    async def _compute_benchmark_comparisons(
        self,
        asset_id: uuid.UUID,
        target_date: date,
    ) -> list[BenchmarkComparisonDTO]:
        """Compute benchmark comparisons for standard benchmarks."""
        comparisons: list[BenchmarkComparisonDTO] = []

        # Compare against TEDPIX (main market index)
        try:
            comparison = await self._compute_single_benchmark_comparison(
                asset_id=asset_id,
                benchmark_type=BenchmarkType.TEDPIX,
                benchmark_name="شاخص کل",
                target_date=target_date,
                lookback_days=365,
            )
            if comparison is not None:
                comparisons.append(comparison)
        except Exception as exc:
            logger.warning(
                "returns.benchmark.comparison_failed asset=%s benchmark=TEDPIX error=%s",
                asset_id,
                exc,
            )

        return comparisons

    async def _compute_single_benchmark_comparison(
        self,
        asset_id: uuid.UUID,
        benchmark_type: BenchmarkType,
        benchmark_name: str,
        target_date: date,
        lookback_days: int,
    ) -> BenchmarkComparisonDTO | None:
        """Compute comparison with a single benchmark."""
        start_date = target_date - timedelta(days=lookback_days)

        # Fetch asset prices
        asset_prices = await self._repo.get_price_history(
            asset_id=asset_id,
            start_date=start_date,
            end_date=target_date,
        )

        # Fetch benchmark prices
        benchmark_prices = await self._repo.get_benchmark_history(
            benchmark_type=benchmark_type,
            start_date=start_date,
            end_date=target_date,
        )

        if len(asset_prices) < 2 or len(benchmark_prices) < 2:
            return None

        # Compute returns
        asset_return = self._compute_total_return(asset_prices)
        benchmark_return = self._compute_total_return_from_benchmark(benchmark_prices)

        if asset_return is None or benchmark_return is None:
            return None

        excess_return = asset_return - benchmark_return

        # Compute correlation (simplified)
        correlation = self._compute_correlation(asset_prices, benchmark_prices)

        return BenchmarkComparisonDTO(
            benchmark_code=benchmark_type.value,
            benchmark_name=benchmark_name,
            benchmark_return_pct=round(benchmark_return, 2),
            portfolio_return_pct=round(asset_return, 2),
            excess_return_pct=round(excess_return, 2),
            tracking_error=None,  # Requires more complex calculation
            information_ratio=None,
            beta=None,
            alpha=None,
            correlation=round(correlation, 4) if correlation is not None else None,
        )

    def _compute_total_return_from_benchmark(
        self,
        prices: list[BenchmarkPriceRow],
    ) -> float | None:
        """Compute total return from benchmark price series."""
        if len(prices) < 2:
            return None

        start_price = float(prices[0].adjusted_close)
        end_price = float(prices[-1].adjusted_close)

        if start_price <= 0:
            return None

        return round(((end_price / start_price) - 1) * 100, 2)

    def _compute_correlation(
        self,
        asset_prices: list[PriceRow],
        benchmark_prices: list[BenchmarkPriceRow],
    ) -> float | None:
        """Compute correlation between asset and benchmark returns."""
        # Align prices by date
        benchmark_by_date = {bp.date: bp for bp in benchmark_prices}

        asset_returns: list[float] = []
        benchmark_returns: list[float] = []

        for i in range(1, len(asset_prices)):
            current = asset_prices[i]
            prev = asset_prices[i - 1]

            if current.date not in benchmark_by_date:
                continue

            prev_benchmark = benchmark_by_date.get(prev.date)
            current_benchmark = benchmark_by_date.get(current.date)

            if prev_benchmark is None or current_benchmark is None:
                continue

            if prev.adjusted_close <= 0 or prev_benchmark.adjusted_close <= 0:
                continue

            asset_ret = float(current.adjusted_close / prev.adjusted_close) - 1
            bench_ret = float(current_benchmark.adjusted_close / prev_benchmark.adjusted_close) - 1

            asset_returns.append(asset_ret)
            benchmark_returns.append(bench_ret)

        if len(asset_returns) < 10:
            return None

        # Compute Pearson correlation
        n = len(asset_returns)
        mean_a = sum(asset_returns) / n
        mean_b = sum(benchmark_returns) / n

        cov = sum((a - mean_a) * (b - mean_b) for a, b in zip(asset_returns, benchmark_returns)) / n
        std_a = math.sqrt(sum((a - mean_a) ** 2 for a in asset_returns) / n)
        std_b = math.sqrt(sum((b - mean_b) ** 2 for b in benchmark_returns) / n)

        if std_a == 0 or std_b == 0:
            return None

        correlation = cov / (std_a * std_b)
        return correlation

    # ═══════════════════════════════════════════════════════════════
    # Date Resolution
    # ═══════════════════════════════════════════════════════════════

    def _resolve_period_start(
        self,
        target_date: date,
        period: ReturnPeriod,
    ) -> date | None:
        """Resolve period to start date."""
        if period == ReturnPeriod.ONE_MONTH:
            return target_date - timedelta(days=30)
        elif period == ReturnPeriod.THREE_MONTHS:
            return target_date - timedelta(days=90)
        elif period == ReturnPeriod.SIX_MONTHS:
            return target_date - timedelta(days=180)
        elif period == ReturnPeriod.ONE_YEAR:
            return target_date - timedelta(days=365)
        elif period == ReturnPeriod.YEAR_TO_DATE:
            return date(target_date.year, 1, 1)
        elif period == ReturnPeriod.INCEPTION:
            return None  # Must be resolved externally
        return None

    # ═══════════════════════════════════════════════════════════════
    # Helpers
    # ═══════════════════════════════════════════════════════════════

    def _determine_overall_quality(
        self,
        periods: dict[ReturnPeriod, PeriodReturnDTO],
    ) -> DataQuality:
        """Determine overall data quality from period results."""
        if not periods:
            return DataQuality.UNAVAILABLE

        qualities = [p.data_quality for p in periods.values()]

        if all(q == DataQuality.COMPLETE for q in qualities):
            return DataQuality.COMPLETE
        if any(q == DataQuality.INSUFFICIENT for q in qualities):
            return DataQuality.PARTIAL
        return DataQuality.COMPLETE

    def _is_data_stale(
        self,
        latest_price: PriceRow | None,
        target_date: date,
    ) -> bool:
        """Check if data is stale (>2 days old)."""
        if latest_price is None:
            return True
        age_days = (target_date - latest_price.date).days
        return age_days > 2

    def _build_empty_summary(
        self,
        portfolio_id: uuid.UUID,
        as_of_date: date,
        inception_date: date | None = None,
    ) -> ReturnsSummaryResponseDTO:
        """Build empty summary for no-data case."""
        return ReturnsSummaryResponseDTO(
            portfolio_id=portfolio_id,
            base_currency="IRR",
            as_of_date=as_of_date,
            inception_date=inception_date,
            data_quality=DataQuality.UNAVAILABLE,
            is_stale=True,
        )

    def _build_empty_series(
        self,
        portfolio_id: uuid.UUID,
        period: ReturnPeriod,
        start_date: date,
        end_date: date,
    ) -> ReturnSeriesResponseDTO:
        """Build empty series for no-data case."""
        return ReturnSeriesResponseDTO(
            portfolio_id=portfolio_id,
            period=period,
            frequency="daily",
            base_currency="IRR",
            start_date=start_date,
            end_date=end_date,
            points=[],
            data_quality=DataQuality.UNAVAILABLE,
        )
