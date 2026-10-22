"""Contracts and Arrow schemas for benchmark alignment and attribution."""

from __future__ import annotations

import uuid
from datetime import datetime
from decimal import Decimal
from enum import Enum
from typing import Annotated, Any

from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator

try:  # pragma: no cover - optional at runtime
    import pyarrow as pa
except Exception:  # pragma: no cover - optional at runtime
    pa = None


MoneyDecimal = Annotated[Decimal, Field(max_digits=24, decimal_places=8)]
ReturnDecimal = Annotated[Decimal, Field(max_digits=18, decimal_places=10)]
RateDecimal = Annotated[Decimal, Field(max_digits=12, decimal_places=8)]


class BenchmarkCode(str, Enum):
    """Stable benchmark identifiers used in storage and API payloads."""

    PORTFOLIO = "PORTFOLIO"
    TOTAL_INDEX = "TOTAL_INDEX"
    EQUAL_WEIGHTED = "EQUAL_WEIGHTED"
    BANK_DEPOSIT = "BANK_DEPOSIT"
    FIXED_INCOME = "FIXED_INCOME"


class BenchmarkWindow(str, Enum):
    """Common attribution windows cached by Redis/LRU tiers."""

    ONE_MONTH = "1M"
    THREE_MONTH = "3M"
    YTD = "YTD"
    ONE_YEAR = "1Y"
    CUSTOM = "CUSTOM"


class StrictSchema(BaseModel):
    """Base class that forbids extra fields and strips string inputs."""

    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)


class ProblemDetails(StrictSchema):
    """RFC 7807 problem details payload for attribution endpoints."""

    type: str = "about:blank"
    title: str
    status: int
    detail: str
    instance: str


class BenchmarkAttributionPoint(StrictSchema):
    """One aligned daily point for portfolio-vs-benchmark comparison."""

    as_of: datetime
    portfolio_nav: MoneyDecimal | None = None
    portfolio_cash_flow: MoneyDecimal = Field(default=Decimal("0"))
    portfolio_daily_return: ReturnDecimal | None = None
    portfolio_twr_cumulative: ReturnDecimal | None = None

    total_index_cumulative: ReturnDecimal | None = None
    equal_weighted_cumulative: ReturnDecimal | None = None
    bank_deposit_cumulative: ReturnDecimal | None = None
    fixed_income_cumulative: ReturnDecimal | None = None

    @field_validator("as_of")
    @classmethod
    def validate_as_of_timezone(cls, value: datetime) -> datetime:
        if value.tzinfo is None or value.utcoffset() is None:
            raise ValueError("as_of must be timezone-aware")
        return value


class BenchmarkAttributionResponse(StrictSchema):
    """Serializable response model for aligned true-TWR attribution payloads."""

    portfolio_id: uuid.UUID
    generated_at: datetime
    window_start: datetime
    window_end: datetime
    window: BenchmarkWindow
    base_currency: str = Field(default="IRR", min_length=3, max_length=3)
    points: list[BenchmarkAttributionPoint] = Field(default_factory=list)

    @field_validator("generated_at", "window_start", "window_end")
    @classmethod
    def validate_timezones(cls, value: datetime) -> datetime:
        if value.tzinfo is None or value.utcoffset() is None:
            raise ValueError("datetime values must be timezone-aware")
        return value

    @model_validator(mode="after")
    def validate_time_window(self) -> "BenchmarkAttributionResponse":
        if self.window_end < self.window_start:
            raise ValueError("window_end must be greater than or equal to window_start")
        return self


class BenchmarkDailyObservation(StrictSchema):
    """Typed read-model row from TimescaleDB daily continuous aggregates."""

    benchmark_code: BenchmarkCode
    as_of: datetime
    close_price_level: MoneyDecimal | None = None
    close_annual_rate: RateDecimal | None = None

    @field_validator("as_of")
    @classmethod
    def validate_observation_timezone(cls, value: datetime) -> datetime:
        if value.tzinfo is None or value.utcoffset() is None:
            raise ValueError("as_of must be timezone-aware")
        return value


def _build_alignment_arrow_schema() -> Any:
    if pa is None:
        return None
    return pa.schema(
        [
            pa.field("as_of", pa.timestamp("us", tz="UTC"), nullable=False),
            pa.field("portfolio_nav", pa.float64()),
            pa.field("portfolio_cash_flow", pa.float64()),
            pa.field("portfolio_daily_return", pa.float64()),
            pa.field("portfolio_twr_cumulative", pa.float64()),
            pa.field("total_index_cumulative", pa.float64()),
            pa.field("equal_weighted_cumulative", pa.float64()),
            pa.field("bank_deposit_cumulative", pa.float64()),
            pa.field("fixed_income_cumulative", pa.float64()),
        ]
    )


def _build_daily_observation_arrow_schema() -> Any:
    if pa is None:
        return None
    return pa.schema(
        [
            pa.field("benchmark_code", pa.string(), nullable=False),
            pa.field("as_of", pa.timestamp("us", tz="UTC"), nullable=False),
            pa.field("close_price_level", pa.float64()),
            pa.field("close_annual_rate", pa.float64()),
        ]
    )


BENCHMARK_ALIGNMENT_ARROW_SCHEMA = _build_alignment_arrow_schema()
BENCHMARK_DAILY_OBSERVATION_ARROW_SCHEMA = _build_daily_observation_arrow_schema()
