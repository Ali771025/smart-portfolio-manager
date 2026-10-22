"""
User identity and authentication model.

This is the root aggregate for all user-owned data.
Password is stored as a one-way hash; plaintext is NEVER persisted.
"""

import uuid

from sqlalchemy import String, Boolean, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base
from app.models.mixins import UUIDMixin, TimestampMixin

# Forward-reference type hints (resolved at runtime by SQLAlchemy)
from typing import TYPE_CHECKING
if TYPE_CHECKING:
    from app.models.portfolio import Portfolio
    from app.models.billing import UserSubscription, Invoice


class User(UUIDMixin, TimestampMixin, Base):
    __tablename__ = "users"

    # ── Identity ───────────────────────────────────────────
    email: Mapped[str] = mapped_column(
        String(320),      # RFC 5321 max length
        unique=True,
        index=True,
        nullable=False,
    )
    hashed_password: Mapped[str] = mapped_column(
        String(128),      # fits PBKDF2/bcrypt style hashes comfortably
        nullable=False,
    )
    full_name: Mapped[str] = mapped_column(
        String(255),
        nullable=False,
    )
    phone_number: Mapped[str | None] = mapped_column(
        String(20),
        nullable=True,
    )

    # ── Account flags ─────────────────────────────────────
    is_active: Mapped[bool] = mapped_column(
        Boolean,
        default=True,
        server_default="true",
        nullable=False,
    )
    is_verified: Mapped[bool] = mapped_column(
        Boolean,
        default=False,
        server_default="false",
        nullable=False,
    )
    is_superuser: Mapped[bool] = mapped_column(
        Boolean,
        default=False,
        server_default="false",
        nullable=False,
    )

    # ── Profile ────────────────────────────────────────────
    bio: Mapped[str | None] = mapped_column(Text, nullable=True)
    avatar_url: Mapped[str | None] = mapped_column(String(512), nullable=True)

    # ── Relationships ──────────────────────────────────────
    # A user owns many portfolios, subscriptions, and invoices.
    portfolios: Mapped[list["Portfolio"]] = relationship(
        back_populates="owner",
        lazy="selectin",         # eager-load for common dashboard queries
        cascade="all, delete-orphan",
        order_by="Portfolio.created_at.desc()",
    )
    subscriptions: Mapped[list["UserSubscription"]] = relationship(
        back_populates="user",
        lazy="selectin",
        cascade="all, delete-orphan",
    )
    invoices: Mapped[list["Invoice"]] = relationship(
        back_populates="user",
        lazy="noload",           # loaded on-demand via explicit joins
        cascade="all, delete-orphan",
    )

    def __repr__(self) -> str:
        return f"<User id={self.id} email={self.email}>"
