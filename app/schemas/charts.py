"""Unified chart data schemas for portfolio analytics.

Provides a single response format for all chart types:
  - Capital growth (portfolio value over time)
  - Asset value (per-asset contribution over time)
  - Symbol performance (per-stock performance overlay)
  - Monthly returns (per-stock monthly return bars)
"""

from __future__ import annotations

import math
import uuid
from datetime import date, datetime
from enum import Enum
from typing import Any, Literal

from pydantic import BaseModel, ConfigDict, Field, field_validator


class ChartBaseModel(BaseModel):
    model_config = ConfigDict(extra="forbid", ser_json_inf_nan="null")


def _sanitize_float(value: Any) -> float | None:
    if value is None:
        return None
    parsed = float(value)
    if not math.isfinite(parsed):
        return None
    return round(parsed, 4)


def _sanitize_price(value: Any) -> float | None:
    if value is None:
        return None
    parsed = float(value)
    if not math.isfinite(parsed):
        return None
    return round(parsed, 2)


class ChartPeriod(str, Enum):
    ONE_MONTH = "1M"
    THREE_MONTHS = "3M"
    SIX_MONTHS = "6M"
    ONE_YEAR = "1Y"
    YTD = "YTD"
    ALL = "ALL"
    CUSTOM = "CUSTOM"


class ChartValueType(str, Enum):
    CURRENCY = "currency"
    PERCENT = "percent"
    INDEX = "index"
    COUNT = "count"


class DataCompleteness(str, Enum):
    COMPLETE = "complete"
    PARTIAL = "partial"
    INSUFFICIENT = "insufficient"


class ChartPoint(ChartBaseModel):
    """A single data point in a chart series."""
    point_date: date = Field(description="Data point date (Gregorian)")
    value: float | None = Field(default=None, description="Numeric value")
    secondary_value: float | None = Field(
        default=None,
        description="Optional secondary value (e.g. benchmark reference)",
    )

    @field_validator("value", "secondary_value", mode="before")
    @classmethod
    def sanitize(cls, v: Any) -> float | None:
        return _sanitize_float(v)


class ChartSeries(ChartBaseModel):
    """One named series in a chart response (one line / one bar group)."""
    key: str = Field(description="Unique series identifier (e.g. ticker symbol)")
    name: str = Field(description="Display name for the series")
    value_type: ChartValueType = Field(
        default=ChartValueType.CURRENCY,
        description="Unit of values in this series",
    )
    data_points: list[ChartPoint] = Field(default_factory=list)
    is_benchmark: bool = Field(
        default=False,
        description="True if this series is a benchmark reference line",
    )

    @property
    def data_point_count(self) -> int:
        return len(self.data_points)

    @property
    def non_null_count(self) -> int:
        return sum(1 for p in self.data_points if p.value is not None)


class ChartMetadata(ChartBaseModel):
    """Metadata describing the chart context and data quality."""
    chart_type: str = Field(description="Chart type identifier")
    title: str = Field(description="Human-readable chart title")
    period: ChartPeriod = Field(description="Selected time period")
    start_date: date = Field(description="Effective start date")
    end_date: date = Field(description="Effective end date")
    as_of_timestamp: datetime = Field(description="When chart data was computed")
    base_currency: str = Field(default="IRR", description="Currency for monetary values")
    total_data_points: int = Field(default=0, description="Total trading days in range")
    available_data_points: int = Field(default=0, description="Days with actual data")
    completeness: DataCompleteness = Field(
        default=DataCompleteness.COMPLETE,
        description="Data completeness assessment",
    )
    missing_symbols: list[str] = Field(
        default_factory=list,
        description="Symbols with no data in the range",
    )


class ChartResponse(ChartBaseModel):
    """Unified chart response wrapping multiple series and metadata."""
    portfolio_id: uuid.UUID
    metadata: ChartMetadata
    series: list[ChartSeries] = Field(default_factory=list)


class CapitalGrowthPoint(ChartBaseModel):
    """Single point in capital growth chart."""
    point_date: date
    portfolio_value: float | None = None
    cost_basis: float | None = None
    total_pnl: float | None = None
    roi_pct: float | None = None

    @field_validator(
        "portfolio_value", "cost_basis", "total_pnl", "roi_pct",
        mode="before",
    )
    @classmethod
    def sanitize(cls, v: Any) -> float | None:
        return _sanitize_price(v)


class CapitalGrowthResponse(ChartBaseModel):
    """Capital growth chart response."""
    portfolio_id: uuid.UUID
    metadata: ChartMetadata
    points: list[CapitalGrowthPoint] = Field(default_factory=list)


class MonthlyReturnPoint(ChartBaseModel):
    """Single monthly return data point."""
    year: int
    month: int
    month_label: str = Field(description="Localized month label (e.g. 'فروردین ۱۴۰۳')")
    return_pct: float | None = None
    cumulative_pct: float | None = None

    @field_validator("return_pct", "cumulative_pct", mode="before")
    @classmethod
    def sanitize(cls, v: Any) -> float | None:
        return _sanitize_float(v)


class MonthlyReturnsResponse(ChartBaseModel):
    """Monthly returns chart response - one series per symbol."""
    portfolio_id: uuid.UUID
    metadata: ChartMetadata
    symbols: list[str] = Field(default_factory=list)
    monthly_returns: dict[str, list[MonthlyReturnPoint]] = Field(
        default_factory=dict,
        description="Monthly returns keyed by ticker symbol",
    )
    portfolio_monthly_returns: list[MonthlyReturnPoint] = Field(
        default_factory=list,
        description="Aggregate portfolio monthly returns",
    )


# Resolve forward references from `from __future__ import annotations`
MonthlyReturnsResponse.model_rebuild()
ChartResponse.model_rebuild()
