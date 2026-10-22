"""Pydantic v2 DTOs for historical returns and period summary.

Response contracts for:
  - Period returns (1M, 3M, 6M, 1Y, YTD, Inception)
  - Return series (daily/monthly)
  - Risk-adjusted returns (Sharpe, Sortino)
  - Benchmark-relative returns

All fields use float with strict sanitization for frontend safety.
"""

from __future__ import annotations

import math
import uuid
from datetime import date, datetime
from enum import Enum
from typing import Any, Literal

from pydantic import BaseModel, ConfigDict, Field, field_validator


# ═══════════════════════════════════════════════════════════════
# Base Classes
# ═══════════════════════════════════════════════════════════════

class ReturnsBaseModel(BaseModel):
    """Base DTO for returns schemas with strict validation."""

    model_config = ConfigDict(extra="forbid", ser_json_inf_nan="null")


def _sanitize_return(value: Any) -> float | None:
    """Sanitize return percentage value (finite, 2 decimal places)."""
    if value is None:
        return None
    parsed = float(value)
    if not math.isfinite(parsed):
        return None
    return round(parsed, 2)


def _sanitize_metric(value: Any) -> float | None:
    """Sanitize metric value (finite, 4 decimal places)."""
    if value is None:
        return None
    parsed = float(value)
    if not math.isfinite(parsed):
        return None
    return round(parsed, 4)


def _sanitize_amount(value: Any) -> float | None:
    """Sanitize monetary amount (finite, 2 decimal places)."""
    if value is None:
        return None
    parsed = float(value)
    if not math.isfinite(parsed):
        return None
    return round(parsed, 2)


# ═══════════════════════════════════════════════════════════════
# Enums
# ═══════════════════════════════════════════════════════════════

class ReturnPeriod(str, Enum):
    """Standard return calculation periods."""
    ONE_MONTH = "1M"
    THREE_MONTHS = "3M"
    SIX_MONTHS = "6M"
    ONE_YEAR = "1Y"
    YEAR_TO_DATE = "YTD"
    INCEPTION = "INCEPTION"


class ReturnFrequency(str, Enum):
    """Frequency of return series data points."""
    DAILY = "daily"
    WEEKLY = "weekly"
    MONTHLY = "monthly"


class DataQuality(str, Enum):
    """Indicates data completeness for the requested period."""
    COMPLETE = "complete"
    PARTIAL = "partial"
    INSUFFICIENT = "insufficient"
    UNAVAILABLE = "unavailable"


# ═══════════════════════════════════════════════════════════════
# Period Returns
# ═══════════════════════════════════════════════════════════════

class PeriodReturnDTO(ReturnsBaseModel):
    """Return for a single period."""
    period: ReturnPeriod
    return_pct: float | None = Field(
        default=None,
        description="Total return percentage for the period",
    )
    annualized_return_pct: float | None = Field(
        default=None,
        description="Annualized return percentage",
    )
    start_value: float | None = Field(
        default=None,
        description="Portfolio value at period start",
    )
    end_value: float | None = Field(
        default=None,
        description="Portfolio value at period end",
    )
    start_date: date = Field(
        description="Period start date",
    )
    end_date: date = Field(
        description="Period end date",
    )
    trading_days: int = Field(
        default=0,
        description="Number of trading days in period",
    )
    data_quality: DataQuality = Field(
        default=DataQuality.COMPLETE,
        description="Data completeness indicator",
    )

    @field_validator(
        "return_pct", "annualized_return_pct",
        "start_value", "end_value",
        mode="before",
    )
    @classmethod
    def round_return_fields(cls, value: Any) -> float | None:
        return _sanitize_return(value)


class BenchmarkComparisonDTO(ReturnsBaseModel):
    """Portfolio return compared to a benchmark."""
    benchmark_code: str = Field(
        description="Benchmark identifier (e.g., TEDPIX, GOLD_18K)",
    )
    benchmark_name: str = Field(
        description="Human-readable benchmark name",
    )
    benchmark_return_pct: float | None = Field(
        default=None,
        description="Benchmark return percentage",
    )
    portfolio_return_pct: float | None = Field(
        default=None,
        description="Portfolio return percentage (same period)",
    )
    excess_return_pct: float | None = Field(
        default=None,
        description="Portfolio return minus benchmark return",
    )
    tracking_error: float | None = Field(
        default=None,
        description="Standard deviation of excess returns",
    )
    information_ratio: float | None = Field(
        default=None,
        description="Excess return / tracking error",
    )
    beta: float | None = Field(
        default=None,
        description="Portfolio beta relative to benchmark",
    )
    alpha: float | None = Field(
        default=None,
        description="Jensen's alpha relative to benchmark",
    )
    correlation: float | None = Field(
        default=None,
        description="Correlation coefficient with benchmark",
    )

    @field_validator(
        "benchmark_return_pct", "portfolio_return_pct", "excess_return_pct",
        "tracking_error", "information_ratio", "beta", "alpha", "correlation",
        mode="before",
    )
    @classmethod
    def round_comparison_fields(cls, value: Any) -> float | None:
        return _sanitize_metric(value)


# ═══════════════════════════════════════════════════════════════
# Return Series
# ═══════════════════════════════════════════════════════════════

class ReturnSeriesPointDTO(ReturnsBaseModel):
    """Single point in a return time series."""
    point_date: date = Field(description="Data point date")
    value: float | None = Field(
        default=None,
        description="Cumulative return value (1.0 = 0%)",
    )
    daily_return_pct: float | None = Field(
        default=None,
        description="Daily return percentage",
    )
    cumulative_return_pct: float | None = Field(
        default=None,
        description="Cumulative return from period start",
    )
    benchmark_value: float | None = Field(
        default=None,
        description="Benchmark cumulative value (if comparing)",
    )

    @field_validator(
        "value", "daily_return_pct", "cumulative_return_pct", "benchmark_value",
        mode="before",
    )
    @classmethod
    def round_series_fields(cls, value: Any) -> float | None:
        return _sanitize_metric(value)


class ReturnSeriesResponseDTO(ReturnsBaseModel):
    """Response containing a return time series."""
    portfolio_id: uuid.UUID = Field(description="Portfolio identifier")
    period: ReturnPeriod = Field(description="Requested return period")
    frequency: ReturnFrequency = Field(
        default=ReturnFrequency.DAILY,
        description="Data point frequency",
    )
    base_currency: str = Field(
        default="IRR",
        description="Currency for values",
    )
    start_date: date = Field(description="Series start date")
    end_date: date = Field(description="Series end date")
    points: list[ReturnSeriesPointDTO] = Field(
        default_factory=list,
        description="Return data points",
    )
    total_return_pct: float | None = Field(
        default=None,
        description="Total return for the period",
    )
    annualized_return_pct: float | None = Field(
        default=None,
        description="Annualized return",
    )
    data_quality: DataQuality = Field(
        default=DataQuality.COMPLETE,
        description="Data completeness indicator",
    )

    @field_validator("total_return_pct", "annualized_return_pct", mode="before")
    @classmethod
    def round_total_fields(cls, value: Any) -> float | None:
        return _sanitize_return(value)


# ═══════════════════════════════════════════════════════════════
# Summary Response
# ═══════════════════════════════════════════════════════════════

class ReturnsSummaryResponseDTO(ReturnsBaseModel):
    """Comprehensive returns summary for all standard periods."""
    portfolio_id: uuid.UUID = Field(description="Portfolio identifier")
    base_currency: str = Field(default="IRR", description="Currency")
    as_of_date: date = Field(description="Data as-of date")
    inception_date: date | None = Field(
        default=None,
        description="Portfolio inception date",
    )

    # Period returns
    period_1m: PeriodReturnDTO | None = Field(
        default=None,
        description="1-month return",
    )
    period_3m: PeriodReturnDTO | None = Field(
        default=None,
        description="3-month return",
    )
    period_6m: PeriodReturnDTO | None = Field(
        default=None,
        description="6-month return",
    )
    period_1y: PeriodReturnDTO | None = Field(
        default=None,
        description="1-year return",
    )
    period_ytd: PeriodReturnDTO | None = Field(
        default=None,
        description="Year-to-date return",
    )
    period_inception: PeriodReturnDTO | None = Field(
        default=None,
        description="Since inception return",
    )

    # Risk metrics
    volatility_annual_pct: float | None = Field(
        default=None,
        description="Annualized volatility",
    )
    sharpe_ratio: float | None = Field(
        default=None,
        description="Sharpe ratio (risk-adjusted return)",
    )
    sortino_ratio: float | None = Field(
        default=None,
        description="Sortino ratio (downside risk-adjusted)",
    )
    max_drawdown_pct: float | None = Field(
        default=None,
        description="Maximum drawdown percentage",
    )

    # Benchmark comparisons
    benchmark_comparisons: list[BenchmarkComparisonDTO] = Field(
        default_factory=list,
        description="Comparisons against benchmarks",
    )

    # Metadata
    data_quality: DataQuality = Field(
        default=DataQuality.COMPLETE,
        description="Overall data completeness",
    )
    is_stale: bool = Field(
        default=False,
        description="True if data may be outdated",
    )
    last_computed_at: datetime | None = Field(
        default=None,
        description="When this summary was last computed",
    )

    @field_validator(
        "volatility_annual_pct", "sharpe_ratio", "sortino_ratio", "max_drawdown_pct",
        mode="before",
    )
    @classmethod
    def round_risk_fields(cls, value: Any) -> float | None:
        return _sanitize_metric(value)
