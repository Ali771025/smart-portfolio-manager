"""
Core portfolio aggregate.

A portfolio is owned by a single user and acts as the container
for all transactions and periodic valuation snapshots.
"""

import uuid

from sqlalchemy import String, Boolean, Text, ForeignKey, Enum as PGEnum
from sqlalchemy.dialects.postgresql import JSONB, UUID as PG_UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base
from app.models.mixins import UUIDMixin, TimestampMixin
from app.models.enums import PortfolioCurrency, PortfolioManagerType

from typing import TYPE_CHECKING
if TYPE_CHECKING:
    from app.models.user import User
    from app.models.transaction import Transaction
    from app.models.market_data import PortfolioSnapshot
    from app.models.corporate_action import DividendTransaction, CorporateActionExecution


class Portfolio(UUIDMixin, TimestampMixin, Base):
    """
    A named basket of holdings.  One user may have multiple portfolios
    (constrained by their subscription plan's `max_portfolios`).
    """
    __tablename__ = "portfolios"

    # ── Foreign Keys ─────────────────────────────────────
    user_id: Mapped[uuid.UUID] = mapped_column(
        PG_UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )

    # ── Descriptive ──────────────────────────────────────
    name: Mapped[str] = mapped_column(
        String(150), nullable=False,
    )
    description: Mapped[str | None] = mapped_column(
        Text, nullable=True,
    )
    broker_metadata: Mapped[dict | None] = mapped_column(
        JSONB,
        nullable=True,
        comment="Optional broker payload (account code, branch, labels, etc).",
    )
    base_currency: Mapped[PortfolioCurrency] = mapped_column(
        PGEnum(PortfolioCurrency, name="portfolio_currency_enum", create_type=True),
        nullable=False,
        default=PortfolioCurrency.USD,
    )
    manager_type: Mapped[PortfolioManagerType] = mapped_column(
        PGEnum(
            PortfolioManagerType,
            name="portfolio_manager_type_enum",
            create_type=True,
        ),
        nullable=False,
        default=PortfolioManagerType.UNKNOWN,
        server_default=PortfolioManagerType.UNKNOWN.value,
    )
    is_active: Mapped[bool] = mapped_column(
        Boolean, default=True, server_default="true", nullable=False,
    )

    # ── Relationships ────────────────────────────────────
    owner: Mapped["User"] = relationship(back_populates="portfolios")

    transactions: Mapped[list["Transaction"]] = relationship(
        back_populates="portfolio",
        lazy="noload",
        cascade="all, delete-orphan",
        order_by="Transaction.executed_at.desc()",
    )
    snapshots: Mapped[list["PortfolioSnapshot"]] = relationship(
        back_populates="portfolio",
        lazy="noload",
        cascade="all, delete-orphan",
        order_by="PortfolioSnapshot.snapshot_date.desc()",
    )
    dividend_transactions: Mapped[list["DividendTransaction"]] = relationship(
        lazy="noload",
        cascade="all, delete-orphan",
        order_by="DividendTransaction.effective_date.desc()",
    )
    corporate_action_executions: Mapped[list["CorporateActionExecution"]] = relationship(
        lazy="noload",
        cascade="all, delete-orphan",
        order_by="CorporateActionExecution.executed_at.desc()",
    )

    def __repr__(self) -> str:
        return f"<Portfolio '{self.name}' user={self.user_id}>"
