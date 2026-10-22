"""Benchmark comparison service for target vs benchmark analytics.

Provides:
  - Single benchmark comparison (target vs one benchmark)
  - Multi-benchmark comparison (target vs multiple benchmarks)
  - Comparison time series for charting
  - Proper date alignment and overlap handling
  - Alignment quality metrics

Design:
  - Uses existing ReturnsReadRepository for data access
  - Deterministic alignment logic (no hidden assumptions)
  - Returns explicit alignment metadata
  - Handles missing overlaps gracefully
"""

from __future__ import annotations

import logging
import math
import uuid
from dataclasses import dataclass
from datetime import date, timedelta
from decimal import Decimal
from typing import Any

from starlette.concurrency import run_in_threadpool

from app.models.enums import BenchmarkType
from app.repositories.returns_read import (
    BenchmarkPriceRow,
    PriceRow,
    ReturnsReadRepository,
)
from app.schemas.benchmark_comparison import (
    AlignmentMetadataDTO,
    AlignmentQuality,
    BenchmarkComparisonResultDTO,
    BenchmarkComparisonSummaryDTO,
    BenchmarkIdentifier,
    ComparisonPeriod,
    ComparisonSeriesPointDTO,
    ComparisonSeriesResponseDTO,
)

logger = logging.getLogger("benchmark_comparison")

TRADING_DAYS_PER_YEAR = 252


@dataclass(slots=True, frozen=True)
class AlignedSeries:
    """Aligned price series for target and benchmark."""
    dates: list[date]
    target_prices: list[float]
    benchmark_prices: list[float]
    target_only_count: int
    benchmark_only_count: int


class BenchmarkComparisonService:
    """Service for comparing target performance against benchmarks."""

    def __init__(self, repository: ReturnsReadRepository) -> None:
        self._repo = repository

    # ═══════════════════════════════════════════════════════════════
    # Public API
    # ═══════════════════════════════════════════════════════════════

    async def compare_single_benchmark(
        self,
        *,
        asset_id: uuid.UUID,
        benchmark_id: BenchmarkIdentifier,
        period: ComparisonPeriod = ComparisonPeriod.ONE_YEAR,
        as_of_date: date | None = None,
        custom_start_date: date | None = None,
        custom_end_date: date | None = None,
    ) -> BenchmarkComparisonResultDTO:
        """Compare target asset against a single benchmark.

        Args:
            asset_id: Target asset UUID.
            benchmark_id: Benchmark to compare against.
            period: Comparison period.
            as_of_date: Reference date (default: today).
            custom_start_date: Custom start date for CUSTOM period.
            custom_end_date: Custom end date for CUSTOM period.

        Returns:
            BenchmarkComparisonResultDTO with comparison metrics.
        """
        logger.info(
            "benchmark.comparison.request asset=%s benchmark=%s period=%s",
            asset_id,
            benchmark_id.value,
            period.value,
        )

        target_date = as_of_date or date.today()
        start_date, end_date = self._resolve_dates(
            target_date, period, custom_start_date, custom_end_date
        )

        # Get target info
        target_info = await self._repo.get_asset_info(asset_id)
        target_name = target_info.ticker_symbol if target_info else str(asset_id)

        # Get benchmark info
        benchmark_type = self._map_identifier_to_type(benchmark_id)
        benchmark_name = self._get_benchmark_name(benchmark_id)

        # Handle RISK_FREE benchmark specially (not stored in DB)
        if benchmark_id == BenchmarkIdentifier.RISK_FREE:
            return await self._compare_risk_free_benchmark(
                asset_id=asset_id,
                target_name=target_name,
                benchmark_name=benchmark_name,
                period=period,
                start_date=start_date,
                end_date=end_date,
                target_date=target_date,
            )

        # Fetch price histories
        target_prices = await self._repo.get_price_history(
            asset_id=asset_id,
            start_date=start_date,
            end_date=end_date,
        )

        benchmark_prices = await self._repo.get_benchmark_history(
            benchmark_type=benchmark_type,
            start_date=start_date,
            end_date=end_date,
        )

        # Align series
        aligned = await run_in_threadpool(
            self._align_series,
            target_prices,
            benchmark_prices,
        )

        # Compute alignment metadata
        alignment = self._compute_alignment_metadata(
            target_prices=target_prices,
            benchmark_prices=benchmark_prices,
            aligned=aligned,
        )

        # Check if we have enough data
        if alignment.aligned_data_points < 2:
            logger.info(
                "benchmark.comparison.insufficient_data asset=%s benchmark=%s aligned=%d",
                asset_id,
                benchmark_id.value,
                alignment.aligned_data_points,
            )
            return self._build_insufficient_result(
                benchmark_id=benchmark_id,
                benchmark_name=benchmark_name,
                period=period,
                start_date=start_date,
                end_date=end_date,
                target_date=target_date,
                alignment=alignment,
            )

        # Compute comparison metrics
        metrics = await run_in_threadpool(
            self._compute_comparison_metrics,
            aligned,
        )

        # Get latest computed timestamp
        last_computed_at = None
        if target_prices:
            last_price = target_prices[-1]
            last_computed_at = datetime.combine(
                last_price.date, datetime.min.time()
            )

        return BenchmarkComparisonResultDTO(
            benchmark_id=benchmark_id,
            benchmark_name=benchmark_name,
            period=period,
            start_date=start_date,
            end_date=end_date,
            as_of_date=target_date,
            target_return_pct=metrics.get("target_return"),
            benchmark_return_pct=metrics.get("benchmark_return"),
            excess_return_pct=metrics.get("excess_return"),
            target_annualized_pct=metrics.get("target_annualized"),
            benchmark_annualized_pct=metrics.get("benchmark_annualized"),
            excess_annualized_pct=metrics.get("excess_annualized"),
            tracking_error_pct=metrics.get("tracking_error"),
            information_ratio=metrics.get("information_ratio"),
            beta=metrics.get("beta"),
            alpha_pct=metrics.get("alpha"),
            correlation=metrics.get("correlation"),
            r_squared=metrics.get("r_squared"),
            alignment=alignment,
            is_fresh=self._is_data_fresh(target_prices, target_date),
            is_stale=self._is_data_stale(target_prices, target_date),
            last_computed_at=last_computed_at,
        )

    async def _compare_risk_free_benchmark(
        self,
        *,
        asset_id: uuid.UUID,
        target_name: str,
        benchmark_name: str,
        period: ComparisonPeriod,
        start_date: date,
        end_date: date,
        target_date: date,
    ) -> BenchmarkComparisonResultDTO:
        """Compare against configurable risk-free rate benchmark.

        The risk-free benchmark is not stored in the database - it's computed
        from the configured annual rate. This allows flexible configuration
        without requiring actual benchmark data ingestion.
        """
        from app.core.config import settings

        # Fetch target prices
        target_prices = await self._repo.get_price_history(
            asset_id=asset_id,
            start_date=start_date,
            end_date=end_date,
        )

        if len(target_prices) < 2:
            return self._build_insufficient_result(
                benchmark_id=BenchmarkIdentifier.RISK_FREE,
                benchmark_name=benchmark_name,
                period=period,
                start_date=start_date,
                end_date=end_date,
                target_date=target_date,
                alignment=AlignmentMetadataDTO(
                    target_data_points=len(target_prices),
                    benchmark_data_points=0,
                    aligned_data_points=0,
                    alignment_quality=AlignmentQuality.INSUFFICIENT,
                ),
            )

        # Compute target return
        target_prices_float = [float(p.adjusted_close) for p in target_prices]
        target_return = self._compute_total_return(target_prices_float)
        trading_days = len(target_prices)
        target_annualized = self._annualize_return(target_return, trading_days)

        # Risk-free return is simply the configured annual rate
        risk_free_annual = settings.RISK_FREE_ANNUAL_RATE

        # Compute excess return
        excess_return = (
            (target_return - risk_free_annual)
            if target_return is not None
            else None
        )
        excess_annualized = (
            (target_annualized - risk_free_annual)
            if target_annualized is not None
            else None
        )

        # Compute target daily returns for tracking error
        target_daily = self._compute_daily_returns(target_prices_float)

        # For risk-free, tracking error is just volatility (std of returns)
        tracking_error = None
        if len(target_daily) > 1:
            mean_return = sum(target_daily) / len(target_daily)
            variance = sum((r - mean_return) ** 2 for r in target_daily) / (len(target_daily) - 1)
            tracking_error = math.sqrt(variance) * math.sqrt(TRADING_DAYS_PER_YEAR) * 100

        # Alpha is the excess return over risk-free
        alpha = excess_annualized

        # Information ratio (excess / tracking_error)
        information_ratio = (
            (excess_annualized / tracking_error)
            if excess_annualized is not None and tracking_error and tracking_error > 0
            else None
        )

        # Build alignment metadata (risk-free has no date alignment needed)
        alignment = AlignmentMetadataDTO(
            target_data_points=len(target_prices),
            benchmark_data_points=trading_days,  # Risk-free has same trading days
            aligned_data_points=trading_days,
            alignment_quality=AlignmentQuality.FULL,
            overlap_start_date=start_date,
            overlap_end_date=end_date,
            target_only_dates=0,
            benchmark_only_dates=0,
        )

        # Get latest computed timestamp
        last_computed_at = None
        if target_prices:
            last_price = target_prices[-1]
            last_computed_at = datetime.combine(
                last_price.date, datetime.min.time()
            )

        return BenchmarkComparisonResultDTO(
            benchmark_id=BenchmarkIdentifier.RISK_FREE,
            benchmark_name=benchmark_name,
            period=period,
            start_date=start_date,
            end_date=end_date,
            as_of_date=target_date,
            target_return_pct=target_return,
            benchmark_return_pct=risk_free_annual,
            excess_return_pct=excess_return,
            target_annualized_pct=target_annualized,
            benchmark_annualized_pct=risk_free_annual,
            excess_annualized_pct=excess_annualized,
            tracking_error_pct=tracking_error,
            information_ratio=information_ratio,
            beta=None,  # N/A for risk-free comparison
            alpha_pct=alpha,
            correlation=None,  # N/A for risk-free comparison
            r_squared=None,  # N/A for risk-free comparison
            alignment=alignment,
            is_fresh=self._is_data_fresh(target_prices, target_date),
            is_stale=self._is_data_stale(target_prices, target_date),
            last_computed_at=last_computed_at,
        )

    async def compare_multiple_benchmarks(
        self,
        *,
        asset_id: uuid.UUID,
        benchmark_ids: list[BenchmarkIdentifier] | None = None,
        period: ComparisonPeriod = ComparisonPeriod.ONE_YEAR,
        as_of_date: date | None = None,
    ) -> BenchmarkComparisonSummaryDTO:
        """Compare target asset against multiple benchmarks.

        Args:
            asset_id: Target asset UUID.
            benchmark_ids: Benchmarks to compare against (default: TEDPIX).
            period: Comparison period.
            as_of_date: Reference date (default: today).

        Returns:
            BenchmarkComparisonSummaryDTO with all comparisons.
        """
        if benchmark_ids is None:
            benchmark_ids = [BenchmarkIdentifier.TEDPIX]

        target_date = as_of_date or date.today()
        target_info = await self._repo.get_asset_info(asset_id)
        target_name = target_info.ticker_symbol if target_info else str(asset_id)

        comparisons: list[BenchmarkComparisonResultDTO] = []
        for benchmark_id in benchmark_ids:
            try:
                comparison = await self.compare_single_benchmark(
                    asset_id=asset_id,
                    benchmark_id=benchmark_id,
                    period=period,
                    as_of_date=target_date,
                )
                comparisons.append(comparison)
            except Exception as exc:
                logger.warning(
                    "benchmark.comparison.failed asset=%s benchmark=%s error=%s",
                    asset_id,
                    benchmark_id.value,
                    exc,
                )

        # Find best/worst
        best_benchmark = None
        worst_benchmark = None
        best_excess = float("-inf")
        worst_excess = float("inf")

        for comp in comparisons:
            if comp.excess_return_pct is not None:
                if comp.excess_return_pct > best_excess:
                    best_excess = comp.excess_return_pct
                    best_benchmark = comp.benchmark_id.value
                if comp.excess_return_pct < worst_excess:
                    worst_excess = comp.excess_return_pct
                    worst_benchmark = comp.benchmark_id.value

        return BenchmarkComparisonSummaryDTO(
            target_id=str(asset_id),
            target_name=target_name,
            as_of_date=target_date,
            period=period,
            comparisons=comparisons,
            best_benchmark=best_benchmark,
            worst_benchmark=worst_benchmark,
            is_fresh=all(c.is_fresh for c in comparisons),
            is_stale=any(c.is_stale for c in comparisons),
            last_computed_at=max(
                (c.last_computed_at for c in comparisons if c.last_computed_at is not None),
                default=None,
            ),
        )

    async def get_comparison_series(
        self,
        *,
        asset_id: uuid.UUID,
        benchmark_id: BenchmarkIdentifier,
        period: ComparisonPeriod = ComparisonPeriod.ONE_YEAR,
        as_of_date: date | None = None,
    ) -> ComparisonSeriesResponseDTO:
        """Get comparison time series for charting.

        Args:
            asset_id: Target asset UUID.
            benchmark_id: Benchmark to compare against.
            period: Comparison period.
            as_of_date: Reference date (default: today).

        Returns:
            ComparisonSeriesResponseDTO with aligned series data.
        """
        target_date = as_of_date or date.today()
        start_date, end_date = self._resolve_dates(target_date, period)

        # Fetch price histories
        target_prices = await self._repo.get_price_history(
            asset_id=asset_id,
            start_date=start_date,
            end_date=end_date,
        )

        benchmark_type = self._map_identifier_to_type(benchmark_id)
        benchmark_prices = await self._repo.get_benchmark_history(
            benchmark_type=benchmark_type,
            start_date=start_date,
            end_date=end_date,
        )

        # Align series
        aligned = await run_in_threadpool(
            self._align_series,
            target_prices,
            benchmark_prices,
        )

        # Compute alignment metadata
        alignment = self._compute_alignment_metadata(
            target_prices=target_prices,
            benchmark_prices=benchmark_prices,
            aligned=aligned,
        )

        # Compute series points
        points = await run_in_threadpool(
            self._compute_comparison_series_points,
            aligned,
        )

        # Compute final values
        final_target = points[-1].target_cumulative_pct if points else None
        final_benchmark = points[-1].benchmark_cumulative_pct if points else None
        final_excess = points[-1].excess_cumulative_pct if points else None

        return ComparisonSeriesResponseDTO(
            target_id=str(asset_id),
            benchmark_id=benchmark_id,
            period=period,
            start_date=start_date,
            end_date=end_date,
            points=points,
            final_target_return_pct=final_target,
            final_benchmark_return_pct=final_benchmark,
            final_excess_return_pct=final_excess,
            alignment=alignment,
        )

    # ═══════════════════════════════════════════════════════════════
    # Series Alignment
    # ═══════════════════════════════════════════════════════════════

    def _align_series(
        self,
        target_prices: list[PriceRow],
        benchmark_prices: list[BenchmarkPriceRow],
    ) -> AlignedSeries:
        """Align target and benchmark series by date.

        Uses inner join (only dates present in both series).
        Also tracks dates present in only one series.
        """
        # Create date-indexed dicts
        target_by_date: dict[date, float] = {}
        for row in target_prices:
            target_by_date[row.date] = float(row.adjusted_close)

        benchmark_by_date: dict[date, float] = {}
        for row in benchmark_prices:
            benchmark_by_date[row.date] = float(row.adjusted_close)

        # Find overlapping dates
        target_dates = set(target_by_date.keys())
        benchmark_dates = set(benchmark_by_date.keys())
        overlap_dates = sorted(target_dates & benchmark_dates)

        target_only = len(target_dates - benchmark_dates)
        benchmark_only = len(benchmark_dates - target_dates)

        aligned_dates = []
        aligned_target = []
        aligned_benchmark = []

        for d in overlap_dates:
            aligned_dates.append(d)
            aligned_target.append(target_by_date[d])
            aligned_benchmark.append(benchmark_by_date[d])

        return AlignedSeries(
            dates=aligned_dates,
            target_prices=aligned_target,
            benchmark_prices=aligned_benchmark,
            target_only_count=target_only,
            benchmark_only_count=benchmark_only,
        )

    def _compute_alignment_metadata(
        self,
        target_prices: list[PriceRow],
        benchmark_prices: list[BenchmarkPriceRow],
        aligned: AlignedSeries,
    ) -> AlignmentMetadataDTO:
        """Compute alignment quality metadata."""
        target_count = len(target_prices)
        benchmark_count = len(benchmark_prices)
        aligned_count = len(aligned.dates)

        # Determine alignment quality
        if aligned_count < 10:
            quality = AlignmentQuality.INSUFFICIENT
        elif aligned_count == 0:
            quality = AlignmentQuality.INSUFFICIENT
        else:
            # Calculate overlap percentage relative to the smaller series
            min_count = min(target_count, benchmark_count) if min(target_count, benchmark_count) > 0 else 0
            if min_count == 0:
                quality = AlignmentQuality.INSUFFICIENT
            else:
                overlap_pct = aligned_count / min_count
                if overlap_pct >= 0.95:
                    quality = AlignmentQuality.FULL
                elif overlap_pct >= 0.80:
                    quality = AlignmentQuality.HIGH
                elif overlap_pct >= 0.50:
                    quality = AlignmentQuality.PARTIAL
                else:
                    quality = AlignmentQuality.LOW

        return AlignmentMetadataDTO(
            target_data_points=target_count,
            benchmark_data_points=benchmark_count,
            aligned_data_points=aligned_count,
            alignment_quality=quality,
            overlap_start_date=aligned.dates[0] if aligned.dates else None,
            overlap_end_date=aligned.dates[-1] if aligned.dates else None,
            target_only_dates=aligned.target_only_count,
            benchmark_only_dates=aligned.benchmark_only_count,
        )

    # ═══════════════════════════════════════════════════════════════
    # Metrics Computation
    # ═══════════════════════════════════════════════════════════════

    def _compute_comparison_metrics(
        self,
        aligned: AlignedSeries,
    ) -> dict[str, float | None]:
        """Compute comparison metrics from aligned series."""
        if len(aligned.dates) < 2:
            return {}

        target_prices = aligned.target_prices
        benchmark_prices = aligned.benchmark_prices

        # Compute returns
        target_return = self._compute_total_return(target_prices)
        benchmark_return = self._compute_total_return(benchmark_prices)
        excess_return = (
            (target_return - benchmark_return)
            if target_return is not None and benchmark_return is not None
            else None
        )

        # Compute annualized returns
        trading_days = len(aligned.dates)
        target_annualized = self._annualize_return(target_return, trading_days)
        benchmark_annualized = self._annualize_return(benchmark_return, trading_days)
        excess_annualized = (
            (target_annualized - benchmark_annualized)
            if target_annualized is not None and benchmark_annualized is not None
            else None
        )

        # Compute daily returns
        target_daily = self._compute_daily_returns(target_prices)
        benchmark_daily = self._compute_daily_returns(benchmark_prices)

        # Compute risk metrics
        tracking_error = self._compute_tracking_error(target_daily, benchmark_daily)
        information_ratio = (
            (excess_annualized / tracking_error)
            if excess_annualized is not None and tracking_error and tracking_error > 0
            else None
        )

        # Compute regression metrics
        beta, alpha, r_squared = self._compute_regression(
            target_daily, benchmark_daily
        )

        # Compute correlation
        correlation = self._compute_correlation(target_daily, benchmark_daily)

        return {
            "target_return": target_return,
            "benchmark_return": benchmark_return,
            "excess_return": excess_return,
            "target_annualized": target_annualized,
            "benchmark_annualized": benchmark_annualized,
            "excess_annualized": excess_annualized,
            "tracking_error": tracking_error,
            "information_ratio": information_ratio,
            "beta": beta,
            "alpha": alpha,
            "correlation": correlation,
            "r_squared": r_squared,
        }

    def _compute_total_return(self, prices: list[float]) -> float | None:
        """Compute total return from price series."""
        if len(prices) < 2 or prices[0] <= 0:
            return None
        return ((prices[-1] / prices[0]) - 1) * 100

    def _annualize_return(
        self, total_return_pct: float | None, trading_days: int
    ) -> float | None:
        """Annualize a total return."""
        if total_return_pct is None or trading_days <= 0:
            return None
        years = trading_days / TRADING_DAYS_PER_YEAR
        if years <= 0:
            return None
        total_return = total_return_pct / 100
        return ((1 + total_return) ** (1 / years) - 1) * 100

    def _compute_daily_returns(self, prices: list[float]) -> list[float]:
        """Compute daily returns from price series."""
        returns = []
        for i in range(1, len(prices)):
            if prices[i - 1] > 0:
                returns.append((prices[i] / prices[i - 1]) - 1)
        return returns

    def _compute_tracking_error(
        self, target_returns: list[float], benchmark_returns: list[float]
    ) -> float | None:
        """Compute tracking error (std dev of excess returns)."""
        if len(target_returns) != len(benchmark_returns) or len(target_returns) < 2:
            return None

        excess_returns = [t - b for t, b in zip(target_returns, benchmark_returns)]
        mean_excess = sum(excess_returns) / len(excess_returns)
        variance = sum((r - mean_excess) ** 2 for r in excess_returns) / (len(excess_returns) - 1)
        tracking_error = math.sqrt(variance) * math.sqrt(TRADING_DAYS_PER_YEAR) * 100
        return tracking_error

    def _compute_regression(
        self, target_returns: list[float], benchmark_returns: list[float]
    ) -> tuple[float | None, float | None, float | None]:
        """Compute beta, alpha, and R-squared via simple linear regression."""
        n = len(target_returns)
        if n < 10:
            return None, None, None

        mean_t = sum(target_returns) / n
        mean_b = sum(benchmark_returns) / n

        # Compute covariance and variance
        cov = sum((t - mean_t) * (b - mean_b) for t, b in zip(target_returns, benchmark_returns)) / n
        var_b = sum((b - mean_b) ** 2 for b in benchmark_returns) / n

        if var_b == 0:
            return None, None, None

        beta = cov / var_b
        alpha = (mean_t - beta * mean_b) * TRADING_DAYS_PER_YEAR * 100

        # Compute R-squared
        ss_res = sum((t - (mean_t + beta * (b - mean_b))) ** 2 for t, b in zip(target_returns, benchmark_returns))
        ss_tot = sum((t - mean_t) ** 2 for t in target_returns)
        r_squared = 1 - (ss_res / ss_tot) if ss_tot > 0 else 0

        return beta, alpha, r_squared

    def _compute_correlation(
        self, target_returns: list[float], benchmark_returns: list[float]
    ) -> float | None:
        """Compute Pearson correlation coefficient."""
        n = len(target_returns)
        if n < 10:
            return None

        mean_t = sum(target_returns) / n
        mean_b = sum(benchmark_returns) / n

        cov = sum((t - mean_t) * (b - mean_b) for t, b in zip(target_returns, benchmark_returns)) / n
        std_t = math.sqrt(sum((t - mean_t) ** 2 for t in target_returns) / n)
        std_b = math.sqrt(sum((b - mean_b) ** 2 for b in benchmark_returns) / n)

        if std_t == 0 or std_b == 0:
            return None

        return cov / (std_t * std_b)

    # ═══════════════════════════════════════════════════════════════
    # Series Points
    # ═══════════════════════════════════════════════════════════════

    def _compute_comparison_series_points(
        self,
        aligned: AlignedSeries,
    ) -> list[ComparisonSeriesPointDTO]:
        """Compute comparison series points for charting."""
        if not aligned.dates:
            return []

        points: list[ComparisonSeriesPointDTO] = []
        target_base = aligned.target_prices[0]
        benchmark_base = aligned.benchmark_prices[0]

        for i, d in enumerate(aligned.dates):
            target_price = aligned.target_prices[i]
            benchmark_price = aligned.benchmark_prices[i]

            target_cumulative = ((target_price / target_base) - 1) * 100 if target_base > 0 else 0
            benchmark_cumulative = ((benchmark_price / benchmark_base) - 1) * 100 if benchmark_base > 0 else 0
            excess_cumulative = target_cumulative - benchmark_cumulative

            points.append(
                ComparisonSeriesPointDTO(
                    point_date=d,
                    target_cumulative_pct=round(target_cumulative, 2),
                    benchmark_cumulative_pct=round(benchmark_cumulative, 2),
                    excess_cumulative_pct=round(excess_cumulative, 2),
                    target_value=round(target_price / target_base, 6) if target_base > 0 else 1.0,
                    benchmark_value=round(benchmark_price / benchmark_base, 6) if benchmark_base > 0 else 1.0,
                )
            )

        return points

    # ═══════════════════════════════════════════════════════════════
    # Helpers
    # ═══════════════════════════════════════════════════════════════

    def _resolve_dates(
        self,
        target_date: date,
        period: ComparisonPeriod,
        custom_start: date | None = None,
        custom_end: date | None = None,
    ) -> tuple[date, date]:
        """Resolve period to start and end dates."""
        if period == ComparisonPeriod.CUSTOM:
            start = custom_start or (target_date - timedelta(days=365))
            end = custom_end or target_date
            return start, end

        period_days = {
            ComparisonPeriod.ONE_MONTH: 30,
            ComparisonPeriod.THREE_MONTHS: 90,
            ComparisonPeriod.SIX_MONTHS: 180,
            ComparisonPeriod.ONE_YEAR: 365,
            ComparisonPeriod.YEAR_TO_DATE: (target_date - date(target_date.year, 1, 1)).days,
            ComparisonPeriod.INCEPTION: 365 * 5,  # 5 years for inception
        }

        days = period_days.get(period, 365)
        return target_date - timedelta(days=days), target_date

    def _map_identifier_to_type(self, identifier: BenchmarkIdentifier) -> BenchmarkType:
        """Map benchmark identifier to internal type."""
        mapping = {
            BenchmarkIdentifier.TEDPIX: BenchmarkType.TEDPIX,
            BenchmarkIdentifier.GOLD_18K: BenchmarkType.GOLD_18K,
            BenchmarkIdentifier.USD_IRR: BenchmarkType.USD_IRR,
            BenchmarkIdentifier.RISK_FREE: BenchmarkType.RISK_FREE,
        }
        return mapping.get(identifier, BenchmarkType.TEDPIX)

    def _get_benchmark_name(self, identifier: BenchmarkIdentifier) -> str:
        """Get human-readable benchmark name."""
        from app.core.config import settings

        names = {
            BenchmarkIdentifier.TEDPIX: "شاخص کل",
            BenchmarkIdentifier.GOLD_18K: "طلای ۱۸ عیار",
            BenchmarkIdentifier.USD_IRR: "دلار آمریکا",
            BenchmarkIdentifier.EQUAL_WEIGHT: "شاخص هم وزن",
            BenchmarkIdentifier.MARKET_CAP: "شاخص شرکت‌های بزرگ",
            BenchmarkIdentifier.RISK_FREE: settings.RISK_FREE_BENCHMARK_NAME,
        }
        return names.get(identifier, identifier.value)

    def _is_data_fresh(self, prices: list[PriceRow], target_date: date) -> bool:
        """Check if data is fresh (within 2 days)."""
        if not prices:
            return False
        age_days = (target_date - prices[-1].date).days
        return age_days <= 2

    def _is_data_stale(self, prices: list[PriceRow], target_date: date) -> bool:
        """Check if data is stale (>2 days old)."""
        return not self._is_data_fresh(prices, target_date)

    def _build_insufficient_result(
        self,
        benchmark_id: BenchmarkIdentifier,
        benchmark_name: str,
        period: ComparisonPeriod,
        start_date: date,
        end_date: date,
        target_date: date,
        alignment: AlignmentMetadataDTO,
    ) -> BenchmarkComparisonResultDTO:
        """Build result for insufficient data case."""
        return BenchmarkComparisonResultDTO(
            benchmark_id=benchmark_id,
            benchmark_name=benchmark_name,
            period=period,
            start_date=start_date,
            end_date=end_date,
            as_of_date=target_date,
            alignment=alignment,
            is_fresh=False,
            is_stale=True,
        )
