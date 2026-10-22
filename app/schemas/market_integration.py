"""Pydantic schemas for market ingestion and benchmark synchronization."""

from __future__ import annotations

import uuid
from datetime import date, datetime
from decimal import Decimal

from pydantic import BaseModel, ConfigDict, Field, model_validator

from app.models.enums import BenchmarkType


class MarketSyncTaskResponse(BaseModel):
    """Async task metadata returned after dispatching Celery jobs."""

    task_id: str
    state: str = "PENDING"
    message: str


class BenchmarkCandleIn(BaseModel):
    """Incoming benchmark OHLC payload used by manual backfills."""

    benchmark_type: BenchmarkType
    date: date
    open_price: Decimal = Field(gt=Decimal("0"))
    high_price: Decimal = Field(gt=Decimal("0"))
    low_price: Decimal = Field(gt=Decimal("0"))
    close_price: Decimal = Field(gt=Decimal("0"))
    adjusted_close: Decimal = Field(gt=Decimal("0"))
    adjustment_factor: Decimal = Field(default=Decimal("1.0000"), gt=Decimal("0"))
    volume: int | None = Field(default=None, ge=0)
    source: str = Field(default="MANUAL", min_length=2, max_length=64)

    @model_validator(mode="after")
    def validate_ohlc(self) -> "BenchmarkCandleIn":
        if self.high_price < self.low_price:
            raise ValueError("high_price must be greater than or equal to low_price")
        if not (self.low_price <= self.open_price <= self.high_price):
            raise ValueError("open_price must be within [low_price, high_price]")
        if not (self.low_price <= self.close_price <= self.high_price):
            raise ValueError("close_price must be within [low_price, high_price]")
        return self


class BenchmarkHistoryRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    benchmark_type: BenchmarkType
    date: date
    open_price: Decimal
    high_price: Decimal
    low_price: Decimal
    close_price: Decimal
    adjusted_close: Decimal
    adjustment_factor: Decimal
    volume: int | None
    source: str
    created_at: datetime
    updated_at: datetime


class BenchmarkSeriesPoint(BaseModel):
    date: date
    value: Decimal


class BenchmarkSeriesResponse(BaseModel):
    benchmark_type: BenchmarkType
    adjusted: bool
    series: list[BenchmarkSeriesPoint]


class ProviderHealthResponse(BaseModel):
    """Response schema for market data provider health check."""

    provider_name: str
    status: str  # "healthy", "degraded", "unavailable"
    latency_ms: float | None = None
    last_success_at: str | None = None
    error_message: str | None = None
    details: dict[str, str] = Field(default_factory=dict)
