"""Watchlist and alert models for user-defined price/volume monitoring.

Models:
  - Watchlist: User's collection of tracked symbols
  - WatchlistItem: Individual symbol in a watchlist
  - AlertRule: User-defined alert condition
  - AlertEvent: Record of triggered alerts

Design:
  - All models use UUIDMixin and TimestampMixin for consistency
  - Alert rules are validated strictly at creation
  - Alert events are immutable once created
  - Supports multiple notification channels
"""

from __future__ import annotations

import uuid
from datetime import date, datetime
from decimal import Decimal

from sqlalchemy import (
    Boolean,
    DateTime,
    Enum as PGEnum,
    Float,
    ForeignKey,
    Index,
    Integer,
    Numeric,
    String,
    Text,
    UniqueConstraint,
    CheckConstraint,
)
from sqlalchemy.dialects.postgresql import JSONB, UUID as PG_UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base
from app.models.mixins import UUIDMixin, TimestampMixin

from typing import TYPE_CHECKING
if TYPE_CHECKING:
    from app.models.user import User


class Watchlist(UUIDMixin, TimestampMixin, Base):
    """User's watchlist containing tracked symbols.

    Each user can have multiple watchlists, each containing
    multiple symbols with optional alert rules.
    """
    __tablename__ = "watchlists"

    __table_args__ = (
        Index("ix_watchlist_user_id", "user_id"),
    )

    user_id: Mapped[uuid.UUID] = mapped_column(
        PG_UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
    )
    name: Mapped[str] = mapped_column(
        String(100),
        nullable=False,
    )
    description: Mapped[str | None] = mapped_column(
        Text,
        nullable=True,
    )
    is_default: Mapped[bool] = mapped_column(
        Boolean,
        default=False,
        server_default="false",
    )

    # Relationships
    items: Mapped[list["WatchlistItem"]] = relationship(
        back_populates="watchlist",
        cascade="all, delete-orphan",
    )

    def __repr__(self) -> str:
        return f"<Watchlist {self.name} user={self.user_id}>"


class WatchlistItem(UUIDMixin, TimestampMixin, Base):
    """Individual symbol in a watchlist.

    Links a watchlist to an asset and stores the date the symbol was added.
    """
    __tablename__ = "watchlist_items"

    __table_args__ = (
        UniqueConstraint(
            "watchlist_id", "asset_id",
            name="uq_watchlist_asset",
        ),
        Index("ix_watchlist_item_watchlist_id", "watchlist_id"),
    )

    watchlist_id: Mapped[uuid.UUID] = mapped_column(
        PG_UUID(as_uuid=True),
        ForeignKey("watchlists.id", ondelete="CASCADE"),
        nullable=False,
    )
    asset_id: Mapped[uuid.UUID] = mapped_column(
        PG_UUID(as_uuid=True),
        ForeignKey("assets.id", ondelete="CASCADE"),
        nullable=False,
    )
    added_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
    )

    # Relationships
    watchlist: Mapped["Watchlist"] = relationship(back_populates="items")
    alerts: Mapped[list["AlertRule"]] = relationship(
        back_populates="watchlist_item",
        cascade="all, delete-orphan",
    )

    def __repr__(self) -> str:
        return f"<WatchlistItem watchlist={self.watchlist_id} asset={self.asset_id}>"


class AlertRule(UUIDMixin, TimestampMixin, Base):
    """User-defined alert condition for a watchlist item.

    Alert rules define conditions that, when met, trigger notifications.
    Rules are evaluated by background tasks against current market data.
    """
    __tablename__ = "alert_rules"

    __table_args__ = (
        Index("ix_alert_rule_user_id", "user_id"),
        Index("ix_alert_rule_status", "status"),
        Index("ix_alert_rule_watchlist_item_id", "watchlist_item_id"),
    )

    user_id: Mapped[uuid.UUID] = mapped_column(
        PG_UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
    )
    watchlist_item_id: Mapped[uuid.UUID] = mapped_column(
        PG_UUID(as_uuid=True),
        ForeignKey("watchlist_items.id", ondelete="CASCADE"),
        nullable=False,
    )

    # Alert condition
    alert_type: Mapped[str] = mapped_column(
        String(50),
        nullable=False,
        comment="Alert type: PRICE_ABOVE, PRICE_BELOW, etc.",
    )
    threshold: Mapped[float] = mapped_column(
        Float,
        nullable=False,
        comment="Threshold value for the alert condition",
    )
    threshold_pct: Mapped[float | None] = mapped_column(
        Float,
        nullable=True,
        comment="Percentage threshold for change-based alerts",
    )

    # Status and frequency
    status: Mapped[str] = mapped_column(
        String(20),
        default="ACTIVE",
        server_default="ACTIVE",
        nullable=False,
    )
    frequency: Mapped[str] = mapped_column(
        String(20),
        default="always",
        server_default="always",
        nullable=False,
        comment="How often alert can trigger: once, daily, always",
    )

    # Notification settings
    notification_channels: Mapped[dict | None] = mapped_column(
        JSONB,
        nullable=True,
        default=["in_app"],
        comment="List of notification channels",
    )
    message_template: Mapped[str | None] = mapped_column(
        Text,
        nullable=True,
        comment="Custom alert message template",
    )

    # Expiration
    expires_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
        comment="When the alert expires",
    )

    # Trigger tracking
    last_triggered_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
        comment="When alert last triggered",
    )
    trigger_count: Mapped[int] = mapped_column(
        Integer,
        default=0,
        server_default="0",
        nullable=False,
    )

    # Relationships
    watchlist_item: Mapped["WatchlistItem"] = relationship(back_populates="alerts")
    events: Mapped[list["AlertEvent"]] = relationship(
        back_populates="alert_rule",
        cascade="all, delete-orphan",
    )

    def __repr__(self) -> str:
        return f"<AlertRule {self.alert_type} threshold={self.threshold} status={self.status}>"


class AlertEvent(UUIDMixin, Base):
    """Record of a triggered alert.

    Immutable once created. Tracks when an alert was triggered
    and whether notifications were sent.
    """
    __tablename__ = "alert_events"

    __table_args__ = (
        Index("ix_alert_event_alert_id", "alert_id"),
        Index("ix_alert_event_triggered_at", "triggered_at"),
    )

    alert_id: Mapped[uuid.UUID] = mapped_column(
        PG_UUID(as_uuid=True),
        ForeignKey("alert_rules.id", ondelete="CASCADE"),
        nullable=False,
    )

    # Trigger details
    triggered_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
    )
    price_at_trigger: Mapped[float] = mapped_column(
        Float,
        nullable=False,
        comment="Price when alert triggered",
    )
    threshold_value: Mapped[float] = mapped_column(
        Float,
        nullable=False,
        comment="Threshold that was crossed",
    )
    change_pct: Mapped[float | None] = mapped_column(
        Float,
        nullable=True,
        comment="Percentage change at trigger",
    )

    # Notification tracking
    notification_sent: Mapped[bool] = mapped_column(
        Boolean,
        default=False,
        server_default="false",
        nullable=False,
    )
    notification_channels: Mapped[dict | None] = mapped_column(
        JSONB,
        nullable=True,
        comment="Channels that were notified",
    )

    # Acknowledgment
    acknowledged_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
        comment="When user acknowledged the alert",
    )

    # Relationships
    alert_rule: Mapped["AlertRule"] = relationship(back_populates="events")

    def __repr__(self) -> str:
        return f"<AlertEvent alert={self.alert_id} triggered={self.triggered_at}>"
