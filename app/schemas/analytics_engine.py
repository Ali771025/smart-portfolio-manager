"""Strict DTOs for the advanced analytics and ledger ingestion flows."""

from __future__ import annotations

import uuid
from datetime import datetime
from decimal import Decimal
from typing import Annotated, Any

from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator

from app.models.enums import InventoryAccountingMethod, LedgerEventType

MoneyDecimal = Annotated[Decimal, Field(max_digits=24, decimal_places=8)]
QuantityDecimal = Annotated[Decimal, Field(max_digits=28, decimal_places=10)]
MetricDecimal = Annotated[Decimal, Field(max_digits=18, decimal_places=10)]


class StrictSchema(BaseModel):
    """Base model with strict payload controls for enterprise APIs."""

    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)


class ProblemDetails(StrictSchema):
    """RFC 7807 Problem Details response contract."""

    type: str = "about:blank"
    title: str
    status: int
    detail: str
    instance: str


class LedgerEvent(StrictSchema):
    """Idempotent immutable ledger event contract (command side)."""

    event_id: uuid.UUID | None = None
    portfolio_id: uuid.UUID
    asset_id: uuid.UUID | None = None
    event_type: LedgerEventType
    inventory_method: InventoryAccountingMethod = InventoryAccountingMethod.WAC

    event_time: datetime
    quantity: QuantityDecimal = Field(default=Decimal("0"), ge=Decimal("0"))
    price: MoneyDecimal = Field(default=Decimal("0"), ge=Decimal("0"))
    fees: MoneyDecimal = Field(default=Decimal("0"), ge=Decimal("0"))
    gross_amount: MoneyDecimal = Field(default=Decimal("0"))
    net_amount: MoneyDecimal = Field(default=Decimal("0"))
    realized_pnl: MoneyDecimal = Field(default=Decimal("0"))

    idempotency_key: str = Field(min_length=8, max_length=128, pattern=r"^[A-Za-z0-9._:-]+$")
    event_hash: str | None = Field(default=None, pattern=r"^[a-fA-F0-9]{64}$")
    payload: dict[str, Any] | None = None

    @field_validator("event_time")
    @classmethod
    def validate_event_time_timezone(cls, value: datetime) -> datetime:
        if value.tzinfo is None or value.utcoffset() is None:
            raise ValueError("event_time must be timezone-aware")
        return value

    @model_validator(mode="after")
    def validate_trade_requirements(self) -> "LedgerEvent":
        trade_event_types = {LedgerEventType.TRADE_BUY, LedgerEventType.TRADE_SELL}
        if self.event_type in trade_event_types:
            if self.asset_id is None:
                raise ValueError("asset_id is required for trade events")
            if self.quantity <= 0:
                raise ValueError("quantity must be > 0 for trade events")
            if self.price <= 0:
                raise ValueError("price must be > 0 for trade events")
        return self


class AnalyticsPoint(StrictSchema):
    """Single analytics bucket point aligned with time-series aggregates."""

    bucket_start: datetime
    total_market_value: MoneyDecimal
    total_cost_basis: MoneyDecimal
    realized_pnl_cumulative: MoneyDecimal
    unrealized_pnl: MoneyDecimal
    twr: MetricDecimal | None = None
    mwr: MetricDecimal | None = None
    max_drawdown: MetricDecimal | None = None
    sharpe_ratio: MetricDecimal | None = None

    @field_validator("bucket_start")
    @classmethod
    def validate_bucket_start_timezone(cls, value: datetime) -> datetime:
        if value.tzinfo is None or value.utcoffset() is None:
            raise ValueError("bucket_start must be timezone-aware")
        return value


class AnalyticsResponse(StrictSchema):
    """Read-side response for low-latency analytical queries (query side)."""

    portfolio_id: uuid.UUID
    inventory_method: InventoryAccountingMethod
    generated_at: datetime
    window_start: datetime
    window_end: datetime
    currency: str = Field(min_length=3, max_length=3)

    total_realized_pnl: MoneyDecimal
    total_unrealized_pnl: MoneyDecimal
    max_drawdown: MetricDecimal | None = None
    sharpe_ratio: MetricDecimal | None = None

    points: list[AnalyticsPoint] = Field(default_factory=list)

    @field_validator("generated_at", "window_start", "window_end")
    @classmethod
    def validate_response_timezones(cls, value: datetime) -> datetime:
        if value.tzinfo is None or value.utcoffset() is None:
            raise ValueError("datetime fields must be timezone-aware")
        return value

    @model_validator(mode="after")
    def validate_window(self) -> "AnalyticsResponse":
        if self.window_end < self.window_start:
            raise ValueError("window_end must be greater than or equal to window_start")
        return self


class OHLCVPoint(StrictSchema):
    """One aggregated OHLCV bar from the read-side continuous aggregate."""

    bucket_start: datetime
    open_price: MoneyDecimal
    high_price: MoneyDecimal
    low_price: MoneyDecimal
    close_price: MoneyDecimal
    volume: int = Field(ge=0)
    notional: MoneyDecimal

    @field_validator("bucket_start")
    @classmethod
    def validate_ohlcv_bucket_timezone(cls, value: datetime) -> datetime:
        if value.tzinfo is None or value.utcoffset() is None:
            raise ValueError("bucket_start must be timezone-aware")
        return value


class OHLCVResponse(StrictSchema):
    """Low-latency OHLCV response for charting and downstream quant consumers."""

    asset_id: uuid.UUID
    ticker_symbol: str
    generated_at: datetime
    window_start: datetime
    window_end: datetime
    points: list[OHLCVPoint] = Field(default_factory=list)

    @field_validator("generated_at", "window_start", "window_end")
    @classmethod
    def validate_ohlcv_timezones(cls, value: datetime) -> datetime:
        if value.tzinfo is None or value.utcoffset() is None:
            raise ValueError("datetime fields must be timezone-aware")
        return value

    @model_validator(mode="after")
    def validate_ohlcv_window(self) -> "OHLCVResponse":
        if self.window_end < self.window_start:
            raise ValueError("window_end must be greater than or equal to window_start")
        return self
