"""Pydantic v2 DTOs for benchmark comparison analytics.

Response contracts for:
  - Single benchmark comparison (target vs benchmark)
  - Multi-benchmark comparison
  - Comparison time series
  - Alignment metadata

All fields use float with strict sanitization for frontend safety.
"""

from __future__ import annotations

import math
import uuid
from datetime import date, datetime
from enum import Enum
from typing import Any

from pydantic import BaseModel, ConfigDict, Field, field_validator


# ═══════════════════════════════════════════════════════════════
# Base Classes
# ═══════════════════════════════════════════════════════════════

class ComparisonBaseModel(BaseModel):
    """Base DTO for comparison schemas with strict validation."""

    model_config = ConfigDict(extra="forbid", ser_json_inf_nan="null")


def _sanitize_pct(value: Any) -> float | None:
    """Sanitize percentage value (finite, 2 decimal places)."""
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


def _sanitize_ratio(value: Any) -> float | None:
    """Sanitize ratio value (finite, 4 decimal places)."""
    if value is None:
        return None
    parsed = float(value)
    if not math.isfinite(parsed):
        return None
    return round(parsed, 4)


# ═══════════════════════════════════════════════════════════════
# Enums
# ═══════════════════════════════════════════════════════════════

class BenchmarkIdentifier(str, Enum):
    """Stable benchmark identifiers from internal backend sources."""
    TEDPIX = "TEDPIX"
    GOLD_18K = "GOLD_18K"
    USD_IRR = "USD_IRR"
    EQUAL_WEIGHT = "EQUAL_WEIGHT"
    MARKET_CAP = "MARKET_CAP"
    RISK_FREE = "RISK_FREE"  # Configurable risk-free rate benchmark


class ComparisonPeriod(str, Enum):
    """Standard comparison periods."""
    ONE_MONTH = "1M"
    THREE_MONTHS = "3M"
    SIX_MONTHS = "6M"
    ONE_YEAR = "1Y"
    YEAR_TO_DATE = "YTD"
    INCEPTION = "INCEPTION"
    CUSTOM = "CUSTOM"


class AlignmentQuality(str, Enum):
    """Quality of date alignment between target and benchmark."""
    FULL = "full"  # 100% overlap
    HIGH = "high"  # >80% overlap
    PARTIAL = "partial"  # 50-80% overlap
    LOW = "low"  # <50% overlap
    INSUFFICIENT = "insufficient"  # <10 data points


# ═══════════════════════════════════════════════════════════════
# Alignment Metadata
# ═══════════════════════════════════════════════════════════════

class AlignmentMetadataDTO(ComparisonBaseModel):
    """Metadata about date alignment between target and benchmark."""
    target_data_points: int = Field(
        default=0,
        description="Number of target data points",
    )
    benchmark_data_points: int = Field(
        default=0,
        description="Number of benchmark data points",
    )
    aligned_data_points: int = Field(
        default=0,
        description="Number of aligned (overlapping) data points",
    )
    alignment_quality: AlignmentQuality = Field(
        default=AlignmentQuality.INSUFFICIENT,
        description="Quality of date alignment",
    )
    overlap_start_date: date | None = Field(
        default=None,
        description="First date with data for both series",
    )
    overlap_end_date: date | None = Field(
        default=None,
        description="Last date with data for both series",
    )
    target_only_dates: int = Field(
        default=0,
        description="Dates with target data but no benchmark data",
    )
    benchmark_only_dates: int = Field(
        default=0,
        description="Dates with benchmark data but no target data",
    )


# ═══════════════════════════════════════════════════════════════
# Single Benchmark Comparison
# ═══════════════════════════════════════════════════════════════

class BenchmarkComparisonResultDTO(ComparisonBaseModel):
    """Result of comparing target against a single benchmark."""
    benchmark_id: BenchmarkIdentifier = Field(
        description="Benchmark identifier",
    )
    benchmark_name: str = Field(
        description="Human-readable benchmark name",
    )

    # Period information
    period: ComparisonPeriod = Field(description="Comparison period")
    start_date: date = Field(description="Comparison start date")
    end_date: date = Field(description="Comparison end date")
    as_of_date: date = Field(description="Data as-of date")

    # Return comparison
    target_return_pct: float | None = Field(
        default=None,
        description="Target return percentage",
    )
    benchmark_return_pct: float | None = Field(
        default=None,
        description="Benchmark return percentage",
    )
    excess_return_pct: float | None = Field(
        default=None,
        description="Target return minus benchmark return",
    )

    # Annualized comparison
    target_annualized_pct: float | None = Field(
        default=None,
        description="Target annualized return",
    )
    benchmark_annualized_pct: float | None = Field(
        default=None,
        description="Benchmark annualized return",
    )
    excess_annualized_pct: float | None = Field(
        default=None,
        description="Annualized excess return",
    )

    # Risk metrics
    tracking_error_pct: float | None = Field(
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
    alpha_pct: float | None = Field(
        default=None,
        description="Jensen's alpha (risk-adjusted excess return)",
    )
    correlation: float | None = Field(
        default=None,
        description="Correlation coefficient with benchmark",
    )
    r_squared: float | None = Field(
        default=None,
        description="Proportion of variance explained by benchmark",
    )

    # Alignment
    alignment: AlignmentMetadataDTO = Field(
        default_factory=AlignmentMetadataDTO,
        description="Date alignment metadata",
    )

    # Data quality
    is_fresh: bool = Field(
        default=True,
        description="True if comparison used fresh data",
    )
    is_stale: bool = Field(
        default=False,
        description="True if data may be outdated",
    )
    last_computed_at: datetime | None = Field(
        default=None,
        description="When this comparison was computed",
    )

    @field_validator(
        "target_return_pct", "benchmark_return_pct", "excess_return_pct",
        "target_annualized_pct", "benchmark_annualized_pct", "excess_annualized_pct",
        "tracking_error_pct", "information_ratio", "beta", "alpha_pct",
        "correlation", "r_squared",
        mode="before",
    )
    @classmethod
    def round_comparison_fields(cls, value: Any) -> float | None:
        return _sanitize_metric(value)


# ═══════════════════════════════════════════════════════════════
# Multi-Benchmark Comparison
# ═══════════════════════════════════════════════════════════════

class BenchmarkComparisonSummaryDTO(ComparisonBaseModel):
    """Summary of target performance vs multiple benchmarks."""
    target_id: str = Field(description="Target identifier (asset_id or portfolio_id)")
    target_name: str | None = Field(default=None, description="Target name")
    as_of_date: date = Field(description="Data as-of date")
    period: ComparisonPeriod = Field(description="Comparison period")

    # Comparisons
    comparisons: list[BenchmarkComparisonResultDTO] = Field(
        default_factory=list,
        description="Comparison results for each benchmark",
    )

    # Best/worst
    best_benchmark: str | None = Field(
        default=None,
        description="Benchmark with highest excess return",
    )
    worst_benchmark: str | None = Field(
        default=None,
        description="Benchmark with lowest excess return",
    )

    # Metadata
    is_fresh: bool = Field(default=True)
    is_stale: bool = Field(default=False)
    last_computed_at: datetime | None = Field(default=None)


# ═══════════════════════════════════════════════════════════════
# Comparison Time Series
# ═══════════════════════════════════════════════════════════════

class ComparisonSeriesPointDTO(ComparisonBaseModel):
    """Single point in a comparison time series."""
    point_date: date = Field(description="Data point date")
    target_cumulative_pct: float | None = Field(
        default=None,
        description="Target cumulative return percentage",
    )
    benchmark_cumulative_pct: float | None = Field(
        default=None,
        description="Benchmark cumulative return percentage",
    )
    excess_cumulative_pct: float | None = Field(
        default=None,
        description="Cumulative excess return percentage",
    )
    target_value: float | None = Field(
        default=None,
        description="Normalized target value (1.0 = 0%)",
    )
    benchmark_value: float | None = Field(
        default=None,
        description="Normalized benchmark value (1.0 = 0%)",
    )

    @field_validator(
        "target_cumulative_pct", "benchmark_cumulative_pct", "excess_cumulative_pct",
        "target_value", "benchmark_value",
        mode="before",
    )
    @classmethod
    def round_series_fields(cls, value: Any) -> float | None:
        return _sanitize_metric(value)


class ComparisonSeriesResponseDTO(ComparisonBaseModel):
    """Response containing comparison time series for charting."""
    target_id: str = Field(description="Target identifier")
    benchmark_id: BenchmarkIdentifier = Field(description="Benchmark identifier")
    period: ComparisonPeriod = Field(description="Comparison period")
    start_date: date = Field(description="Series start date")
    end_date: date = Field(description="Series end date")

    points: list[ComparisonSeriesPointDTO] = Field(
        default_factory=list,
        description="Comparison data points",
    )

    # Summary
    final_target_return_pct: float | None = Field(
        default=None,
        description="Final target return",
    )
    final_benchmark_return_pct: float | None = Field(
        default=None,
        description="Final benchmark return",
    )
    final_excess_return_pct: float | None = Field(
        default=None,
        description="Final excess return",
    )

    # Alignment
    alignment: AlignmentMetadataDTO = Field(
        default_factory=AlignmentMetadataDTO,
    )

    @field_validator(
        "final_target_return_pct", "final_benchmark_return_pct", "final_excess_return_pct",
        mode="before",
    )
    @classmethod
    def round_final_fields(cls, value: Any) -> float | None:
        return _sanitize_pct(value)


# ═══════════════════════════════════════════════════════════════
# Request Models
# ═══════════════════════════════════════════════════════════════

class ComparisonRequestDTO(ComparisonBaseModel):
    """Request for benchmark comparison."""
    target_id: str = Field(description="Target identifier (asset_id)")
    benchmark_ids: list[BenchmarkIdentifier] = Field(
        default_factory=lambda: [BenchmarkIdentifier.TEDPIX],
        description="Benchmarks to compare against",
    )
    period: ComparisonPeriod = Field(
        default=ComparisonPeriod.ONE_YEAR,
        description="Comparison period",
    )
    custom_start_date: date | None = Field(
        default=None,
        description="Custom start date (if period=CUSTOM)",
    )
    custom_end_date: date | None = Field(
        default=None,
        description="Custom end date (if period=CUSTOM)",
    )
