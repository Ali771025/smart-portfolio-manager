"""Monthly and yearly portfolio report schemas."""

from __future__ import annotations

import math
import uuid
from datetime import UTC, date, datetime
from enum import Enum
from typing import Any

from pydantic import BaseModel, ConfigDict, Field, field_validator


class ReportPeriod(str, Enum):
    """Report period types."""
    MONTHLY = "monthly"
    YEARLY = "yearly"


class DataCompleteness(str, Enum):
    """Data completeness indicator."""
    COMPLETE = "complete"
    PARTIAL = "partial"
    INSUFFICIENT = "insufficient"


class _SanitizedBase(BaseModel):
    """Base model with strict float sanitization."""
    model_config = ConfigDict(extra="forbid", ser_json_inf_nan="null")


def _sanitize_float(value: Any) -> float | None:
    """Sanitize float value (finite, 2 decimal places)."""
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


class PeriodPerformanceDTO(_SanitizedBase):
    """Performance metrics for a single period (month or year)."""
    
    period_label: str = Field(
        description="Period label (e.g., '2024-01', '2024')",
    )
    period_start: date = Field(description="Period start date")
    period_end: date = Field(description="Period end date")
    
    # Value metrics
    starting_value: float | None = Field(
        default=None,
        description="Portfolio value at period start",
    )
    ending_value: float | None = Field(
        default=None,
        description="Portfolio value at period end",
    )
    
    # Cash flow
    net_deposits: float | None = Field(
        default=None,
        description="Net deposits/withdrawals (positive = deposits)",
    )
    
    # PnL
    realized_pnl: float | None = Field(
        default=None,
        description="Realized PnL during period",
    )
    unrealized_pnl: float | None = Field(
        default=None,
        description="Unrealized PnL at period end",
    )
    total_pnl: float | None = Field(
        default=None,
        description="Total PnL (realized + unrealized)",
    )
    
    # Returns
    total_return_amount: float | None = Field(
        default=None,
        description="Total return amount (ending - starting - deposits)",
    )
    total_return_pct: float | None = Field(
        default=None,
        description="Total return percentage",
    )
    
    # Best/Worst performers
    best_performer_symbol: str | None = Field(
        default=None,
        description="Best performing symbol by return",
    )
    best_performer_return_pct: float | None = Field(
        default=None,
        description="Best performer return percentage",
    )
    worst_performer_symbol: str | None = Field(
        default=None,
        description="Worst performing symbol by return",
    )
    worst_performer_return_pct: float | None = Field(
        default=None,
        description="Worst performer return percentage",
    )
    
    # Data quality
    data_completeness: DataCompleteness = Field(
        default=DataCompleteness.COMPLETE,
        description="Data completeness indicator",
    )
    is_stale: bool = Field(
        default=False,
        description="True if data may be outdated",
    )
    
    @field_validator(
        "starting_value", "ending_value", "net_deposits",
        "realized_pnl", "unrealized_pnl", "total_pnl",
        "total_return_amount", "total_return_pct",
        "best_performer_return_pct", "worst_performer_return_pct",
        mode="before",
    )
    @classmethod
    def round_financial_fields(cls, value: Any) -> float | None:
        return _sanitize_float(value)


class MonthlyReturnPoint(_SanitizedBase):
    """Single monthly return data point."""
    
    period_date: date = Field(description="Month end date")
    label: str = Field(description="Period label (e.g., '2024-01')")
    starting_value: float | None = Field(default=None)
    ending_value: float | None = Field(default=None)
    return_pct: float | None = Field(default=None)
    cumulative_return_pct: float | None = Field(default=None)
    benchmark_return_pct: float | None = Field(default=None)
    
    @field_validator(
        "starting_value", "ending_value", "return_pct",
        "cumulative_return_pct", "benchmark_return_pct",
        mode="before",
    )
    @classmethod
    def round_fields(cls, value: Any) -> float | None:
        return _sanitize_float(value)


class YearlyReturnPoint(_SanitizedBase):
    """Single yearly return data point."""
    
    year: int = Field(description="Year")
    starting_value: float | None = Field(default=None)
    ending_value: float | None = Field(default=None)
    return_pct: float | None = Field(default=None)
    cumulative_return_pct: float | None = Field(default=None)
    benchmark_return_pct: float | None = Field(default=None)
    best_performer_symbol: str | None = Field(default=None)
    worst_performer_symbol: str | None = Field(default=None)
    
    @field_validator(
        "starting_value", "ending_value", "return_pct",
        "cumulative_return_pct", "benchmark_return_pct",
        mode="before",
    )
    @classmethod
    def round_fields(cls, value: Any) -> float | None:
        return _sanitize_float(value)


class MonthlyReportResponse(_SanitizedBase):
    """Monthly portfolio report response."""
    
    portfolio_id: uuid.UUID = Field(description="Portfolio identifier")
    base_currency: str = Field(default="IRR", description="Currency")
    report_type: ReportPeriod = Field(default=ReportPeriod.MONTHLY)
    
    # Period info
    year: int = Field(description="Report year")
    month: int = Field(description="Report month (1-12)")
    period_start: date = Field(description="Period start date")
    period_end: date = Field(description="Period end date")
    
    # Performance
    performance: PeriodPerformanceDTO = Field(
        description="Period performance metrics",
    )
    
    # Monthly return series (for charts)
    monthly_returns: list[MonthlyReturnPoint] = Field(
        default_factory=list,
        description="Monthly return data points",
    )
    
    # Metadata
    data_completeness: DataCompleteness = Field(
        default=DataCompleteness.COMPLETE,
    )
    is_stale: bool = Field(default=False)
    generated_at: datetime = Field(
        default_factory=lambda: datetime.now(UTC),
        description="Report generation timestamp",
    )


class YearlyReportResponse(_SanitizedBase):
    """Yearly portfolio report response."""
    
    portfolio_id: uuid.UUID = Field(description="Portfolio identifier")
    base_currency: str = Field(default="IRR", description="Currency")
    report_type: ReportPeriod = Field(default=ReportPeriod.YEARLY)
    
    # Period info
    year: int = Field(description="Report year")
    period_start: date = Field(description="Period start date")
    period_end: date = Field(description="Period end date")
    
    # Performance
    performance: PeriodPerformanceDTO = Field(
        description="Period performance metrics",
    )
    
    # Monthly breakdown within the year
    monthly_breakdown: list[MonthlyReturnPoint] = Field(
        default_factory=list,
        description="Monthly return data points within the year",
    )
    
    # Yearly return series (for multi-year comparison)
    yearly_returns: list[YearlyReturnPoint] = Field(
        default_factory=list,
        description="Yearly return data points",
    )
    
    # Metadata
    data_completeness: DataCompleteness = Field(
        default=DataCompleteness.COMPLETE,
    )
    is_stale: bool = Field(default=False)
    generated_at: datetime = Field(
        default_factory=lambda: datetime.now(UTC),
        description="Report generation timestamp",
    )


class SymbolPerformanceDTO(_SanitizedBase):
    """Performance metrics for a single symbol in a period."""
    
    asset_id: uuid.UUID
    ticker_symbol: str
    quantity: float
    starting_price: float | None = None
    ending_price: float | None = Field(default=None)
    return_pct: float | None = Field(default=None)
    weight_pct: float | None = Field(default=None)
    contribution_to_return: float | None = Field(default=None)
    
    @field_validator(
        "quantity", "starting_price", "ending_price", "return_pct",
        "weight_pct", "contribution_to_return",
        mode="before",
    )
    @classmethod
    def round_fields(cls, value: Any) -> float | None:
        return _sanitize_float(value)
