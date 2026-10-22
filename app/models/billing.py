"""
SaaS billing domain: Plans, Subscriptions, and Invoices.

Financial columns use NUMERIC(18, 4) — NO floats.
"""

import uuid
from datetime import datetime
from decimal import Decimal

from sqlalchemy import (
    String, Boolean, Integer, Numeric, DateTime, Text,
    ForeignKey, Enum as PGEnum,
)
from sqlalchemy.dialects.postgresql import UUID as PG_UUID, JSONB
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base
from app.models.mixins import UUIDMixin, TimestampMixin
from app.models.enums import SubscriptionTier, SubscriptionStatus, InvoiceStatus

from typing import TYPE_CHECKING
if TYPE_CHECKING:
    from app.models.user import User


class SubscriptionPlan(UUIDMixin, TimestampMixin, Base):
    """
    Defines a product tier (e.g., Free, Pro) with pricing & limits.
    Rows are admin-managed; users subscribe to one at a time.
    """
    __tablename__ = "subscription_plans"

    name: Mapped[str] = mapped_column(
        String(100), unique=True, nullable=False,
    )
    tier: Mapped[SubscriptionTier] = mapped_column(
        PGEnum(SubscriptionTier, name="subscription_tier_enum", create_type=True),
        nullable=False,
        index=True,
    )
    description: Mapped[str | None] = mapped_column(Text, nullable=True)

    # ── Pricing (NUMERIC — NEVER float) ──────────────────
    price_monthly: Mapped[Decimal] = mapped_column(
        Numeric(18, 4), nullable=False, default=Decimal("0.0000"),
    )
    price_yearly: Mapped[Decimal] = mapped_column(
        Numeric(18, 4), nullable=False, default=Decimal("0.0000"),
    )
    currency: Mapped[str] = mapped_column(
        String(3), nullable=False, default="USD",
    )

    # ── Entitlements ─────────────────────────────────────
    max_portfolios: Mapped[int] = mapped_column(
        Integer, nullable=False, default=1,
    )
    max_assets_per_portfolio: Mapped[int] = mapped_column(
        Integer, nullable=False, default=50,
    )
    features: Mapped[dict | None] = mapped_column(
        JSONB, nullable=True, default=dict,
        comment="Flexible feature flags, e.g. {'realtime_data': true}",
    )
    is_active: Mapped[bool] = mapped_column(
        Boolean, default=True, server_default="true", nullable=False,
    )

    # ── Relationships ────────────────────────────────────
    user_subscriptions: Mapped[list["UserSubscription"]] = relationship(
        back_populates="plan",
        lazy="noload",
    )

    def __repr__(self) -> str:
        return f"<SubscriptionPlan {self.name} ({self.tier.value})>"


class UserSubscription(UUIDMixin, TimestampMixin, Base):
    """
    Junction entity that tracks a user's active plan subscription,
    including its lifecycle dates and status transitions.
    """
    __tablename__ = "user_subscriptions"

    # ── Foreign Keys ─────────────────────────────────────
    user_id: Mapped[uuid.UUID] = mapped_column(
        PG_UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    plan_id: Mapped[uuid.UUID] = mapped_column(
        PG_UUID(as_uuid=True),
        ForeignKey("subscription_plans.id", ondelete="RESTRICT"),
        nullable=False,
        index=True,
    )

    # ── State ────────────────────────────────────────────
    status: Mapped[SubscriptionStatus] = mapped_column(
        PGEnum(SubscriptionStatus, name="subscription_status_enum", create_type=True),
        nullable=False,
        default=SubscriptionStatus.TRIALING,
        index=True,
    )
    started_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False,
    )
    expires_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False,
    )
    cancelled_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True,
    )

    # ── External payment reference ───────────────────────
    stripe_subscription_id: Mapped[str | None] = mapped_column(
        String(255), nullable=True, unique=True,
    )

    # ── Relationships ────────────────────────────────────
    user: Mapped["User"] = relationship(back_populates="subscriptions")
    plan: Mapped["SubscriptionPlan"] = relationship(back_populates="user_subscriptions")
    invoices: Mapped[list["Invoice"]] = relationship(
        back_populates="subscription",
        lazy="noload",
        cascade="all, delete-orphan",
    )

    def __repr__(self) -> str:
        return f"<UserSubscription user={self.user_id} status={self.status.value}>"


class Invoice(UUIDMixin, TimestampMixin, Base):
    """
    Immutable billing record for each payment event.
    Amount fields are NUMERIC(18, 4) for cent-precision accounting.
    """
    __tablename__ = "invoices"

    # ── Foreign Keys ─────────────────────────────────────
    user_id: Mapped[uuid.UUID] = mapped_column(
        PG_UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    subscription_id: Mapped[uuid.UUID | None] = mapped_column(
        PG_UUID(as_uuid=True),
        ForeignKey("user_subscriptions.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )

    # ── Financial fields (STRICT NUMERIC) ────────────────
    amount: Mapped[Decimal] = mapped_column(
        Numeric(18, 4), nullable=False,
    )
    tax_amount: Mapped[Decimal] = mapped_column(
        Numeric(18, 4), nullable=False, default=Decimal("0.0000"),
    )
    total_amount: Mapped[Decimal] = mapped_column(
        Numeric(18, 4), nullable=False,
    )
    currency: Mapped[str] = mapped_column(
        String(3), nullable=False, default="USD",
    )

    # ── Status & dates ───────────────────────────────────
    status: Mapped[InvoiceStatus] = mapped_column(
        PGEnum(InvoiceStatus, name="invoice_status_enum", create_type=True),
        nullable=False,
        default=InvoiceStatus.DRAFT,
        index=True,
    )
    issued_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False,
    )
    paid_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True,
    )
    description: Mapped[str | None] = mapped_column(Text, nullable=True)

    # ── External reference ───────────────────────────────
    stripe_invoice_id: Mapped[str | None] = mapped_column(
        String(255), nullable=True, unique=True,
    )

    # ── Relationships ────────────────────────────────────
    user: Mapped["User"] = relationship(back_populates="invoices")
    subscription: Mapped["UserSubscription | None"] = relationship(
        back_populates="invoices",
    )

    def __repr__(self) -> str:
        return f"<Invoice {self.id} amount={self.total_amount} {self.currency}>"
