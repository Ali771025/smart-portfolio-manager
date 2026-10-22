"""Factor summary computation service for analytics enrichment.

Computes practical, explainable factors based on historical price data:
  - Momentum: Price momentum over multiple lookback periods
  - Volatility: Annualized price volatility
  - Drawdown: Maximum drawdown and current drawdown
  - Relative Strength: Performance vs benchmark (TEDPIX)
  - Trend: Price position relative to moving averages

Design:
  - All factors are explainable and testable
  - Uses existing repository layer for data access
  - Handles missing data gracefully with status indicators
  - No black-box calculations
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
from app.schemas.factors import (
    FactorExposureDTO,
    FactorSummaryResponseDTO,
    FactorType,
    RegressionDiagnosticsDTO,
    RegressionStatus,
)

logger = logging.getLogger("factor_service")

TRADING_DAYS_PER_YEAR = 252


@dataclass(slots=True, frozen=True)
class FactorResult:
    """Internal result of a single factor computation."""
    factor_type: FactorType
    factor_name: str
    value: float | None
    interpretation: str | None
    status: str  # ok, insufficient_data, stale


class FactorService:
    """Service for computing factor summaries."""

    def __init__(self, repository: ReturnsReadRepository) -> None:
        self._repo = repository

    # ═══════════════════════════════════════════════════════════════
    # Public API
    # ═══════════════════════════════════════════════════════════════

    async def get_asset_factor_summary(
        self,
        *,
        asset_id: uuid.UUID,
        period: str = "1Y",
        as_of_date: date | None = None,
    ) -> FactorSummaryResponseDTO:
        """Compute factor summary for a single asset.

        Args:
            asset_id: Asset UUID.
            period: Analysis period (1M, 3M, 6M, 1Y).
            as_of_date: Reference date (default: today).

        Returns:
            FactorSummaryResponseDTO with factor exposures.
        """
        logger.info(
            "factor.summary.request asset_id=%s period=%s",
            asset_id,
            period,
        )

        target_date = as_of_date or date.today()
        start_date = self._resolve_period_start(target_date, period)

        # Get asset info
        asset = await self._repo.get_asset_info(asset_id)
        if asset is None:
            logger.warning("factor.summary.asset_not_found asset_id=%s", asset_id)
            return self._build_empty_summary(
                asset_id=asset_id,
                period=period,
                start_date=start_date,
                end_date=target_date,
            )

        # Fetch price history
        prices = await self._repo.get_price_history(
            asset_id=asset_id,
            start_date=start_date,
            end_date=target_date,
        )

        # Fetch benchmark for relative strength
        benchmark_prices = await self._repo.get_benchmark_history(
            benchmark_type=BenchmarkType.TEDPIX,
            start_date=start_date,
            end_date=target_date,
        )

        # Compute factors
        factors = await run_in_threadpool(
            self._compute_all_factors,
            prices,
            benchmark_prices,
        )

        # Determine overall status
        is_fresh = self._is_data_fresh(prices, target_date)
        is_stale = not is_fresh

        logger.info(
            "factor.summary.complete asset_id=%s factors=%d",
            asset_id,
            len(factors),
        )

        return FactorSummaryResponseDTO(
            portfolio_id=asset_id,
            base_currency="IRR",
            as_of_date=target_date,
            period=period,
            start_date=start_date,
            end_date=target_date,
            factors=[
                FactorExposureDTO(
                    factor_type=f.factor_type,
                    factor_name=f.factor_name,
                    exposure=f.value,
                    t_statistic=None,
                    p_value=None,
                    is_significant=f.value is not None and abs(f.value) > 0,
                    contribution_return_pct=f.value if f.factor_type == FactorType.MOMENTUM else None,
                    contribution_risk_pct=f.value if f.factor_type == FactorType.VOLATILITY else None,
                )
                for f in factors
            ],
            regression=RegressionDiagnosticsDTO(
                status=RegressionStatus.SUCCESS if prices else RegressionStatus.INSUFFICIENT_DATA,
                observations_count=len(prices),
            ),
            is_fresh=is_fresh,
            is_stale=is_stale,
            last_computed_at=datetime.now(UTC) if prices else None,
        )

    # ═══════════════════════════════════════════════════════════════
    # Factor Computation
    # ═══════════════════════════════════════════════════════════════

    def _compute_all_factors(
        self,
        prices: list[PriceRow],
        benchmark_prices: list[BenchmarkPriceRow],
    ) -> list[FactorResult]:
        """Compute all factors from price history."""
        if len(prices) < 5:
            return [
                FactorResult(
                    factor_type=FactorType.CUSTOM,
                    factor_name="داده ناکافی",
                    value=None,
                    interpretation="داده کافی برای محاسبه عوامل وجود ندارد",
                    status="insufficient_data",
                ),
            ]

        factors: list[FactorResult] = []

        # 1. Momentum factors
        factors.extend(self._compute_momentum_factors(prices))

        # 2. Volatility factor
        factors.append(self._compute_volatility_factor(prices))

        # 3. Drawdown factors
        factors.extend(self._compute_drawdown_factors(prices))

        # 4. Relative strength vs benchmark
        if benchmark_prices:
            factors.append(self._compute_relative_strength(prices, benchmark_prices))

        # 5. Trend factors
        factors.extend(self._compute_trend_factors(prices))

        return factors

    # ── Momentum ─────────────────────────────────────────────

    def _compute_momentum_factors(self, prices: list[PriceRow]) -> list[FactorResult]:
        """Compute momentum factors for multiple lookback periods."""
        factors: list[FactorResult] = []

        lookbacks = [
            ("1M", 21),
            ("3M", 63),
            ("6M", 126),
            ("1Y", 252),
        ]

        for label, days in lookbacks:
            if len(prices) < days:
                factors.append(
                    FactorResult(
                        factor_type=FactorType.MOMENTUM,
                        factor_name=f"مومنتوم {label}",
                        value=None,
                        interpretation=f"داده کافی برای {label} موجود نیست",
                        status="insufficient_data",
                    )
                )
                continue

            start_price = float(prices[-days].adjusted_close)
            end_price = float(prices[-1].adjusted_close)

            if start_price <= 0:
                continue

            momentum_pct = ((end_price / start_price) - 1) * 100

            # Interpret momentum
            if momentum_pct > 10:
                interpretation = "روند صعودی قوی"
            elif momentum_pct > 0:
                interpretation = "روند صعودی"
            elif momentum_pct > -10:
                interpretation = "روند نزولی"
            else:
                interpretation = "روند نزولی قوی"

            factors.append(
                FactorResult(
                    factor_type=FactorType.MOMENTUM,
                    factor_name=f"مومنتوم {label}",
                    value=round(momentum_pct, 2),
                    interpretation=interpretation,
                    status="ok",
                )
            )

        return factors

    # ── Volatility ───────────────────────────────────────────

    def _compute_volatility_factor(self, prices: list[PriceRow]) -> FactorResult:
        """Compute annualized volatility."""
        if len(prices) < 30:
            return FactorResult(
                factor_type=FactorType.VOLATILITY,
                factor_name="نوسانات",
                value=None,
                interpretation="داده کافی برای محاسبه نوسانات موجود نیست",
                status="insufficient_data",
            )

        # Compute daily returns
        returns = []
        for i in range(1, len(prices)):
            prev = float(prices[i - 1].adjusted_close)
            curr = float(prices[i].adjusted_close)
            if prev > 0:
                returns.append((curr / prev) - 1)

        if len(returns) < 20:
            return FactorResult(
                factor_type=FactorType.VOLATILITY,
                factor_name="نوسانات",
                value=None,
                interpretation="داده کافی برای محاسبه نوسانات موجود نیست",
                status="insufficient_data",
            )

        # Annualized volatility
        mean_return = sum(returns) / len(returns)
        variance = sum((r - mean_return) ** 2 for r in returns) / (len(returns) - 1)
        daily_vol = math.sqrt(variance)
        annualized_vol = daily_vol * math.sqrt(TRADING_DAYS_PER_YEAR) * 100

        # Interpret volatility
        if annualized_vol < 15:
            interpretation = "نوسانات پایین"
        elif annualized_vol < 30:
            interpretation = "نوسانات متوسط"
        elif annualized_vol < 50:
            interpretation = "نوسانات بالا"
        else:
            interpretation = "نوسانات بسیار بالا"

        return FactorResult(
            factor_type=FactorType.VOLATILITY,
            factor_name="نوسانات",
            value=round(annualized_vol, 2),
            interpretation=interpretation,
            status="ok",
        )

    # ── Drawdown ─────────────────────────────────────────────

    def _compute_drawdown_factors(self, prices: list[PriceRow]) -> list[FactorResult]:
        """Compute drawdown factors."""
        factors: list[FactorResult] = []

        if len(prices) < 10:
            return [
                FactorResult(
                    factor_type=FactorType.CUSTOM,
                    factor_name="حداکثر افت",
                    value=None,
                    interpretation="داده کافی موجود نیست",
                    status="insufficient_data",
                ),
            ]

        # Compute running peak and drawdowns
        values = [float(p.adjusted_close) for p in prices]
        peak = values[0]
        max_drawdown = 0.0
        current_drawdown = 0.0
        peak_date = prices[0].date
        trough_date = prices[0].date

        for i, v in enumerate(values):
            if v > peak:
                peak = v
                peak_date = prices[i].date

            drawdown = ((v - peak) / peak) * 100 if peak > 0 else 0
            if drawdown < max_drawdown:
                max_drawdown = drawdown
                trough_date = prices[i].date

            current_drawdown = drawdown

        # Max drawdown
        factors.append(
            FactorResult(
                factor_type=FactorType.CUSTOM,
                factor_name="حداکثر افت",
                value=round(abs(max_drawdown), 2),
                interpretation=self._interpret_drawdown(abs(max_drawdown)),
                status="ok",
            )
        )

        # Current drawdown
        factors.append(
            FactorResult(
                factor_type=FactorType.CUSTOM,
                factor_name="افت فعلی",
                value=round(abs(current_drawdown), 2),
                interpretation=self._interpret_current_drawdown(abs(current_drawdown)),
                status="ok",
            )
        )

        return factors

    def _interpret_drawdown(self, drawdown_pct: float) -> str:
        """Interpret maximum drawdown."""
        if drawdown_pct < 5:
            return "حداکثر افت کمتر از ۵٪ - عملکرد پایدار"
        elif drawdown_pct < 15:
            return "حداکثر افت متوسط - ریسک متوسط"
        elif drawdown_pct < 30:
            return "حداکثر افت بالا - ریسک بالا"
        else:
            return "حداکثر افت بسیار بالا - ریسک بسیار بالا"

    def _interpret_current_drawdown(self, drawdown_pct: float) -> str:
        """Interpret current drawdown."""
        if drawdown_pct < 1:
            return "نزدیک به اوج"
        elif drawdown_pct < 5:
            return "افت جزئی از اوج"
        elif drawdown_pct < 15:
            return "افت قابل توجه از اوج"
        else:
            return "افت عمیق از اوج"

    # ── Relative Strength ────────────────────────────────────

    def _compute_relative_strength(
        self,
        target_prices: list[PriceRow],
        benchmark_prices: list[BenchmarkPriceRow],
    ) -> FactorResult:
        """Compute relative strength vs benchmark."""
        if len(target_prices) < 30 or len(benchmark_prices) < 30:
            return FactorResult(
                factor_type=FactorType.CUSTOM,
                factor_name="قدرت نسبی",
                value=None,
                interpretation="داده کافی برای مقایسه موجود نیست",
                status="insufficient_data",
            )

        # Align by date
        benchmark_by_date = {bp.date: bp for bp in benchmark_prices}

        target_returns = []
        benchmark_returns = []

        for i in range(1, len(target_prices)):
            curr = target_prices[i]
            prev = target_prices[i - 1]

            if curr.date not in benchmark_by_date or prev.date not in benchmark_by_date:
                continue

            curr_bench = benchmark_by_date[curr.date]
            prev_bench = benchmark_by_date[prev.date]

            if prev.adjusted_close <= 0 or prev_bench.adjusted_close <= 0:
                continue

            target_ret = (float(curr.adjusted_close) / float(prev.adjusted_close)) - 1
            bench_ret = (float(curr_bench.adjusted_close) / float(prev_bench.adjusted_close)) - 1

            target_returns.append(target_ret)
            benchmark_returns.append(bench_ret)

        if len(target_returns) < 20:
            return FactorResult(
                factor_type=FactorType.CUSTOM,
                factor_name="قدرت نسبی",
                value=None,
                interpretation="همپوشانی کافی با شاخص وجود ندارد",
                status="insufficient_data",
            )

        # Compute relative strength (excess return)
        total_target = 1.0
        total_benchmark = 1.0
        for t, b in zip(target_returns, benchmark_returns):
            total_target *= (1 + t)
            total_benchmark *= (1 + b)

        relative_strength = ((total_target / total_benchmark) - 1) * 100 if total_benchmark > 0 else 0

        # Interpret
        if relative_strength > 10:
            interpretation = "عملکرد بهتر از شاخص - قدرت نسبی بالا"
        elif relative_strength > 0:
            interpretation = "عملکرد بهتر از شاخص"
        elif relative_strength > -10:
            interpretation = "عملکرد بدتر از شاخص"
        else:
            interpretation = "عملکرد بدتر از شاخص - ضعف نسبی"

        return FactorResult(
            factor_type=FactorType.CUSTOM,
            factor_name="قدرت نسبی",
            value=round(relative_strength, 2),
            interpretation=interpretation,
            status="ok",
        )

    # ── Trend ────────────────────────────────────────────────

    def _compute_trend_factors(self, prices: list[PriceRow]) -> list[FactorResult]:
        """Compute trend factors based on moving averages."""
        factors: list[FactorResult] = []

        if len(prices) < 50:
            return [
                FactorResult(
                    factor_type=FactorType.CUSTOM,
                    factor_name="روند",
                    value=None,
                    interpretation="داده کافی برای تحلیل روند موجود نیست",
                    status="insufficient_data",
                ),
            ]

        values = [float(p.adjusted_close) for p in prices]
        current_price = values[-1]

        # SMA 20
        sma_20 = sum(values[-20:]) / 20 if len(values) >= 20 else None

        # SMA 50
        sma_50 = sum(values[-50:]) / 50 if len(values) >= 50 else None

        # Compute trend signal
        trend_signals = []

        if sma_20 is not None:
            if current_price > sma_20:
                trend_signals.append(1)  # Bullish
            else:
                trend_signals.append(-1)  # Bearish

        if sma_50 is not None:
            if current_price > sma_50:
                trend_signals.append(1)
            else:
                trend_signals.append(-1)

        if not trend_signals:
            return factors

        avg_signal = sum(trend_signals) / len(trend_signals)

        # Trend strength (normalized -1 to 1)
        trend_strength = round(avg_signal * 100, 2)

        # Interpret
        if trend_strength > 50:
            interpretation = "روند صعودی قوی - قیمت بالاتر از میانگین‌ها"
        elif trend_strength > 0:
            interpretation = "روند صعودی - قیمت بالاتر از برخی میانگین‌ها"
        elif trend_strength > -50:
            interpretation = "روند نزولی - قیمت پایین‌تر از برخی میانگین‌ها"
        else:
            interpretation = "روند نزولی قوی - قیمت پایین‌تر از میانگین‌ها"

        factors.append(
            FactorResult(
                factor_type=FactorType.CUSTOM,
                factor_name="روند",
                value=trend_strength,
                interpretation=interpretation,
                status="ok",
            )
        )

        return factors

    # ═══════════════════════════════════════════════════════════════
    # Helpers
    # ═══════════════════════════════════════════════════════════════

    def _resolve_period_start(self, target_date: date, period: str) -> date:
        """Resolve period string to start date."""
        period_days = {
            "1M": 30,
            "3M": 90,
            "6M": 180,
            "1Y": 365,
        }
        days = period_days.get(period, 365)
        return target_date - timedelta(days=days)

    def _is_data_fresh(self, prices: list[PriceRow], target_date: date) -> bool:
        """Check if data is fresh (within 2 days)."""
        if not prices:
            return False
        age_days = (target_date - prices[-1].date).days
        return age_days <= 2

    def _build_empty_summary(
        self,
        asset_id: uuid.UUID,
        period: str,
        start_date: date,
        end_date: date,
    ) -> FactorSummaryResponseDTO:
        """Build empty summary for no-data case."""
        return FactorSummaryResponseDTO(
            portfolio_id=asset_id,
            base_currency="IRR",
            as_of_date=end_date,
            period=period,
            start_date=start_date,
            end_date=end_date,
            factors=[],
            regression=RegressionDiagnosticsDTO(
                status=RegressionStatus.INSUFFICIENT_DATA,
                observations_count=0,
            ),
            is_fresh=False,
            is_stale=True,
        )
