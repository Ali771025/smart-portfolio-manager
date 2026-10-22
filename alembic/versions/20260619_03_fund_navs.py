"""add idempotent fund NAV history

Revision ID: 20260619_03
Revises: 20260619_02
"""

from collections.abc import Sequence

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

revision: str = "20260619_03"
down_revision: str | None = "20260619_02"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    bind = op.get_bind()
    tables = set(sa.inspect(bind).get_table_names())
    if "fund_navs" in tables:
        return
    op.create_table(
        "fund_navs",
        sa.Column("id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("fund_id", sa.String(length=128), nullable=False),
        sa.Column("nav_date", sa.Date(), nullable=False),
        sa.Column("subscription_nav", sa.Numeric(24, 8), nullable=True),
        sa.Column("redemption_nav", sa.Numeric(24, 8), nullable=True),
        sa.Column("statistical_nav", sa.Numeric(24, 8), nullable=True),
        sa.Column("source", sa.String(length=64), nullable=False, server_default="FIPIRAN"),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.CheckConstraint(
            "subscription_nav IS NULL OR subscription_nav >= 0",
            name="ck_fund_nav_subscription_non_negative",
        ),
        sa.CheckConstraint(
            "redemption_nav IS NULL OR redemption_nav >= 0",
            name="ck_fund_nav_redemption_non_negative",
        ),
        sa.CheckConstraint(
            "statistical_nav IS NULL OR statistical_nav >= 0",
            name="ck_fund_nav_statistical_non_negative",
        ),
        sa.ForeignKeyConstraint(["fund_id"], ["funds.fund_id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint(
            "fund_id", "nav_date", "source", name="uq_fund_nav_fund_date_source"
        ),
    )
    op.create_index("ix_fund_nav_fund_date_desc", "fund_navs", ["fund_id", "nav_date"])


def downgrade() -> None:
    op.drop_index("ix_fund_nav_fund_date_desc", table_name="fund_navs")
    op.drop_table("fund_navs")
