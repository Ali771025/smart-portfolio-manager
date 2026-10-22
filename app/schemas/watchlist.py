"""Pydantic v2 DTOs for watchlist and price alerts.

Response contracts for:
  - Watchlist CRUD operations
  - Alert rule definitions
  - Alert event history
  - Alert status and notifications

Watchlists allow users to track symbols and set price/volume alerts.
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

class WatchlistBaseModel(BaseModel):
    """Base DTO for watchlist schemas with strict validation."""

    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)


def _sanitize_price(value: Any) -> float | None:
    """Sanitize price value (finite, 2 decimal places)."""
    if value is None:
        return None
    parsed = float(value)
    if not math.isfinite(parsed):
        return None
    return round(parsed, 2)


# ═══════════════════════════════════════════════════════════════
# Enums
# ═══════════════════════════════════════════════════════════════

class AlertType(str, Enum):
    """Types of price/volume alerts."""
    PRICE_ABOVE = "PRICE_ABOVE"
    PRICE_BELOW = "PRICE_BELOW"
    PRICE_CHANGE_PCT_ABOVE = "PRICE_CHANGE_PCT_ABOVE"
    PRICE_CHANGE_PCT_BELOW = "PRICE_CHANGE_PCT_BELOW"
    VOLUME_ABOVE = "VOLUME_ABOVE"
    VOLUME_BELOW = "VOLUME_BELOW"
    VOLUME_SPIKE = "VOLUME_SPIKE"
    PRICE_CROSS_ABOVE = "PRICE_CROSS_ABOVE"
    PRICE_CROSS_BELOW = "PRICE_CROSS_BELOW"


class AlertStatus(str, Enum):
    """Current status of an alert rule."""
    ACTIVE = "ACTIVE"
    TRIGGERED = "TRIGGERED"
    PAUSED = "PAUSED"
    EXPIRED = "EXPIRED"
    CANCELLED = "CANCELLED"


class AlertFrequency(str, Enum):
    """How often an alert can trigger."""
    ONCE = "once"
    DAILY = "daily"
    ALWAYS = "always"


class NotificationChannel(str, Enum):
    """Channels for alert notifications."""
    PUSH = "push"
    EMAIL = "email"
    SMS = "sms"
    IN_APP = "in_app"


class WatchlistSortBy(str, Enum):
    """Sort options for watchlist listing."""
    NAME = "name"
    CREATED_AT = "created_at"
    SYMBOL_COUNT = "symbol_count"
    ALERT_COUNT = "alert_count"


# ═══════════════════════════════════════════════════════════════
# Watchlist
# ═══════════════════════════════════════════════════════════════

class WatchlistSymbolDTO(WatchlistBaseModel):
    """A single symbol in a watchlist with current market data."""
    symbol: str = Field(description="Ticker symbol (e.g., فولاد)")
    name_fa: str | None = Field(default=None, description="Persian name")
    name_en: str | None = Field(default=None, description="English name")
    ins_code: str | None = Field(default=None, description="TSETMC instrument code")
    current_price: float | None = Field(
        default=None,
        description="Latest price",
    )
    price_change_pct: float | None = Field(
        default=None,
        description="Daily price change percentage",
    )
    volume: int | None = Field(default=None, description="Trading volume")
    is_tradeable: bool = Field(default=True, description="Whether tradeable")
    added_at: datetime = Field(description="When added to watchlist")

    @field_validator("current_price", "price_change_pct", mode="before")
    @classmethod
    def round_price_fields(cls, value: Any) -> float | None:
        return _sanitize_price(value)


class WatchlistDTO(WatchlistBaseModel):
    """Watchlist with symbols summary."""
    id: uuid.UUID = Field(description="Watchlist identifier")
    name: str = Field(description="Watchlist name")
    description: str | None = Field(default=None, description="Optional description")
    symbols: list[WatchlistSymbolDTO] = Field(
        default_factory=list,
        description="Symbols in the watchlist",
    )
    symbol_count: int = Field(default=0, description="Number of symbols")
    alert_count: int = Field(default=0, description="Number of active alerts")
    created_at: datetime = Field(description="Creation timestamp")
    updated_at: datetime = Field(description="Last update timestamp")


class WatchlistCreateRequest(WatchlistBaseModel):
    """Request to create a new watchlist."""
    name: str = Field(min_length=1, max_length=100, description="Watchlist name")
    description: str | None = Field(default=None, max_length=500)
    symbols: list[str] = Field(
        default_factory=list,
        description="Initial symbols to add",
    )


class WatchlistUpdateRequest(WatchlistBaseModel):
    """Request to update a watchlist."""
    name: str | None = Field(default=None, min_length=1, max_length=100)
    description: str | None = Field(default=None, max_length=500)


class WatchlistSymbolsRequest(WatchlistBaseModel):
    """Request to add/remove symbols from a watchlist."""
    add_symbols: list[str] = Field(
        default_factory=list,
        description="Symbols to add",
    )
    remove_symbols: list[str] = Field(
        default_factory=list,
        description="Symbols to remove",
    )


class WatchlistListResponse(WatchlistBaseModel):
    """Response for listing watchlists."""
    watchlists: list[WatchlistDTO] = Field(default_factory=list)
    total_count: int = Field(default=0)


# ═══════════════════════════════════════════════════════════════
# Alert Rules
# ═══════════════════════════════════════════════════════════════

class AlertRuleDTO(WatchlistBaseModel):
    """Alert rule definition."""
    id: uuid.UUID = Field(description="Alert rule identifier")
    symbol: str = Field(description="Ticker symbol")
    alert_type: AlertType = Field(description="Type of alert")
    threshold: float = Field(description="Threshold value for the alert")
    threshold_pct: float | None = Field(
        default=None,
        description="Percentage threshold (for percentage-based alerts)",
    )
    status: AlertStatus = Field(description="Current alert status")
    frequency: AlertFrequency = Field(
        default=AlertFrequency.ALWAYS,
        description="How often alert can trigger",
    )
    notification_channels: list[NotificationChannel] = Field(
        default_factory=lambda: [NotificationChannel.IN_APP],
        description="Notification delivery channels",
    )
    message_template: str | None = Field(
        default=None,
        description="Custom alert message template",
    )
    expires_at: datetime | None = Field(
        default=None,
        description="When the alert expires",
    )
    created_at: datetime = Field(description="Creation timestamp")
    updated_at: datetime = Field(description="Last update timestamp")
    last_triggered_at: datetime | None = Field(
        default=None,
        description="When alert last triggered",
    )
    trigger_count: int = Field(default=0, description="Number of times triggered")

    @field_validator("threshold", "threshold_pct", mode="before")
    @classmethod
    def round_threshold_fields(cls, value: Any) -> float | None:
        return _sanitize_price(value)


class AlertRuleCreateRequest(WatchlistBaseModel):
    """Request to create an alert rule."""
    symbol: str = Field(min_length=1, max_length=50, description="Ticker symbol")
    alert_type: AlertType = Field(description="Type of alert")
    threshold: float = Field(description="Threshold value")
    threshold_pct: float | None = Field(
        default=None,
        description="Percentage threshold",
    )
    frequency: AlertFrequency = Field(default=AlertFrequency.ALWAYS)
    notification_channels: list[NotificationChannel] = Field(
        default_factory=lambda: [NotificationChannel.IN_APP],
    )
    message_template: str | None = Field(default=None, max_length=500)
    expires_at: datetime | None = Field(default=None)


class AlertRuleUpdateRequest(WatchlistBaseModel):
    """Request to update an alert rule."""
    threshold: float | None = Field(default=None)
    threshold_pct: float | None = Field(default=None)
    status: AlertStatus | None = Field(default=None)
    frequency: AlertFrequency | None = Field(default=None)
    notification_channels: list[NotificationChannel] | None = Field(default=None)
    message_template: str | None = Field(default=None, max_length=500)
    expires_at: datetime | None = Field(default=None)


class AlertRuleListResponse(WatchlistBaseModel):
    """Response for listing alert rules."""
    alerts: list[AlertRuleDTO] = Field(default_factory=list)
    total_count: int = Field(default=0)
    active_count: int = Field(default=0)


# ═══════════════════════════════════════════════════════════════
# Alert Events (History)
# ═══════════════════════════════════════════════════════════════

class AlertEventDTO(WatchlistBaseModel):
    """Alert trigger event record."""
    id: uuid.UUID = Field(description="Event identifier")
    alert_id: uuid.UUID = Field(description="Associated alert rule")
    symbol: str = Field(description="Ticker symbol")
    alert_type: AlertType = Field(description="Type of alert that triggered")
    triggered_at: datetime = Field(description="When the alert triggered")
    price_at_trigger: float = Field(description="Price when alert triggered")
    threshold_value: float = Field(description="Threshold that was crossed")
    change_pct: float | None = Field(
        default=None,
        description="Percentage change at trigger",
    )
    notification_sent: bool = Field(
        default=False,
        description="Whether notification was sent",
    )
    notification_channels: list[NotificationChannel] = Field(
        default_factory=list,
        description="Channels that were notified",
    )
    acknowledged_at: datetime | None = Field(
        default=None,
        description="When user acknowledged the alert",
    )

    @field_validator("price_at_trigger", "threshold_value", "change_pct", mode="before")
    @classmethod
    def round_event_fields(cls, value: Any) -> float | None:
        return _sanitize_price(value)


class AlertEventListResponse(WatchlistBaseModel):
    """Response for listing alert events."""
    events: list[AlertEventDTO] = Field(default_factory=list)
    total_count: int = Field(default=0)
    unacknowledged_count: int = Field(default=0)


# ═══════════════════════════════════════════════════════════════
# Alert Summary
# ═══════════════════════════════════════════════════════════════

class AlertSummaryDTO(WatchlistBaseModel):
    """Summary of alert activity for the user."""
    total_active_alerts: int = Field(default=0)
    total_triggered_today: int = Field(default=0)
    total_unacknowledged: int = Field(default=0)
    alerts_by_type: dict[str, int] = Field(
        default_factory=dict,
        description="Count of alerts by type",
    )
    most_triggered_symbol: str | None = Field(
        default=None,
        description="Symbol with most triggers today",
    )


class AlertSummaryResponse(WatchlistBaseModel):
    """Response for alert summary."""
    summary: AlertSummaryDTO = Field(default_factory=AlertSummaryDTO)
    recent_events: list[AlertEventDTO] = Field(
        default_factory=list,
        description="Recent alert events (last 10)",
    )
