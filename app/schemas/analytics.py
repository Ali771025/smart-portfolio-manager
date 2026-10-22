"""Pydantic v2 DTOs for analytics and performance endpoints."""

from __future__ import annotations

import math
import uuid
from datetime import date, datetime
from enum import Enum
from typing import Any, Literal

from pydantic import BaseModel, ConfigDict, Field, field_validator


class ProblemDetails(BaseModel):
    """RFC 7807 problem details payload."""

    type: str = "about:blank"
    title: str
    status: int
    detail: str
    instance: str


class AnalyticsTimeframe(str, Enum):
    ONE_MONTH = "1M"
    THREE_MONTHS = "3M"
    SIX_MONTHS = "6M"
    ONE_YEAR = "1Y"
    ALL = "ALL"


def _sanitize_financial_float(value: Any) -> float | None:
    if value is None:
        return None

    parsed = float(value)
    if not math.isfinite(parsed):
        return None
    return round(parsed, 2)


def _sanitize_metric_float(value: Any) -> float | None:
    if value is None:
        return None

    parsed = float(value)
    if not math.isfinite(parsed):
        return None
    return round(parsed, 6)


class AnalyticsBaseModel(BaseModel):
    """Base DTO with strict float sanitization and null-safe serialization."""

    model_config = ConfigDict(extra="forbid", ser_json_inf_nan="null")


class PerformancePointDTO(AnalyticsBaseModel):
    date: date
    market_value: float | None = Field(default=None)
    cost_basis: float | None = Field(default=None)
    pnl: float | None = Field(default=None)
    roi: float | None = Field(default=None)

    @field_validator("market_value", "cost_basis", "pnl", "roi", mode="before")
    @classmethod
    def round_financial_fields(cls, value: Any) -> float | None:
        return _sanitize_financial_float(value)


class PerformanceResponseDTO(AnalyticsBaseModel):
    portfolio_id: uuid.UUID
    timeframe: AnalyticsTimeframe
    base_currency: str
    current_price: float | None = Field(default=None)
    closing_price: float | None = Field(default=None)
    daily_pnl: float | None = Field(default=None)
    total_unrealized_pnl: float | None = Field(default=None)
    last_market_update: datetime | None = Field(default=None)
    points: list[PerformancePointDTO] = Field(default_factory=list)

    @field_validator(
        "current_price",
        "closing_price",
        "daily_pnl",
        "total_unrealized_pnl",
        mode="before",
    )
    @classmethod
    def round_market_fields(cls, value: Any) -> float | None:
        return _sanitize_financial_float(value)


class ValueAtRiskBandDTO(AnalyticsBaseModel):
    confidence_95: float | None = Field(default=None)
    confidence_99: float | None = Field(default=None)

    @field_validator("confidence_95", "confidence_99", mode="before")
    @classmethod
    def round_metric_fields(cls, value: Any) -> float | None:
        return _sanitize_metric_float(value)


class ValueAtRiskDTO(AnalyticsBaseModel):
    historical: ValueAtRiskBandDTO = Field(default_factory=ValueAtRiskBandDTO)
    parametric: ValueAtRiskBandDTO = Field(default_factory=ValueAtRiskBandDTO)


class AdvancedRiskMetricsResponse(AnalyticsBaseModel):
    sortino_ratio: float | None = Field(default=None)
    maximum_drawdown: float | None = Field(default=None)
    beta: float | None = Field(default=None)
    alpha: float | None = Field(default=None)
    value_at_risk: ValueAtRiskDTO = Field(default_factory=ValueAtRiskDTO)

    @field_validator(
        "sortino_ratio",
        "maximum_drawdown",
        "beta",
        "alpha",
        mode="before",
    )
    @classmethod
    def round_metric_fields(cls, value: Any) -> float | None:
        return _sanitize_metric_float(value)


class MetricsResponseDTO(AnalyticsBaseModel):
    portfolio_id: uuid.UUID
    timeframe: AnalyticsTimeframe
    base_currency: str
    as_of_date: date
    portfolio_value: float | None = Field(default=None)
    cost_basis: float | None = Field(default=None)
    current_price: float | None = Field(default=None)
    closing_price: float | None = Field(default=None)
    daily_pnl: float | None = Field(default=None)
    total_unrealized_pnl: float | None = Field(default=None)
    last_market_update: datetime | None = Field(default=None)
    risk_free_rate: float | None = Field(default=None)
    pnl: float | None = Field(default=None)
    roi: float | None = Field(default=None)
    volatility: float | None = Field(default=None)
    sharpe_ratio: float | None = Field(default=None)
    risk_score: float | None = Field(default=None)
    risk_level: Literal["low", "medium", "high"] | None = Field(default=None)
    risk_assessment: AdvancedRiskMetricsResponse | None = Field(default=None)

    @field_validator(
        "portfolio_value",
        "cost_basis",
        "current_price",
        "closing_price",
        "daily_pnl",
        "total_unrealized_pnl",
        "risk_free_rate",
        "pnl",
        "roi",
        "volatility",
        "sharpe_ratio",
        "risk_score",
        mode="before",
    )
    @classmethod
    def round_financial_fields(cls, value: Any) -> float | None:
        return _sanitize_financial_float(value)
