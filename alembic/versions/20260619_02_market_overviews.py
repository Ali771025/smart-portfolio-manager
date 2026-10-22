"""Add durable market overview snapshots.

Revision ID: 20260619_02
Revises: 20260619_01
Create Date: 2026-06-19
"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql


revision = "20260619_02"
down_revision = "20260619_01"
branch_labels = None
depends_on = None


def upgrade() -> None:
    tables = set(sa.inspect(op.get_bind()).get_table_names())
    if "market_overviews" in tables:
        return
    op.create_table(
        "market_overviews",
        sa.Column("id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("total_index_value", sa.Numeric(24, 8), nullable=False),
        sa.Column("total_index_change", sa.Numeric(24, 8), nullable=True),
        sa.Column("equal_weight_index_value", sa.Numeric(24, 8), nullable=False),
        sa.Column("equal_weight_index_change", sa.Numeric(24, 8), nullable=True),
        sa.Column("market_value", sa.Numeric(32, 8), nullable=True),
        sa.Column("trades_count", sa.BigInteger(), nullable=False, server_default="0"),
        sa.Column("trades_value", sa.Numeric(32, 8), nullable=True),
        sa.Column("trades_volume", sa.BigInteger(), nullable=False, server_default="0"),
        sa.Column("price_info_timestamp", sa.DateTime(timezone=True), nullable=False),
        sa.Column("server_received_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("source", sa.String(length=64), nullable=False, server_default="TSETMC"),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint(
            "source",
            "price_info_timestamp",
            name="uq_market_overview_source_timestamp",
        ),
        sa.CheckConstraint("total_index_value >= 0", name="ck_market_overview_total_index_non_negative"),
        sa.CheckConstraint(
            "equal_weight_index_value >= 0",
            name="ck_market_overview_equal_weight_non_negative",
        ),
        sa.CheckConstraint("market_value IS NULL OR market_value >= 0", name="ck_market_overview_value_non_negative"),
        sa.CheckConstraint("trades_count >= 0", name="ck_market_overview_trades_count_non_negative"),
        sa.CheckConstraint("trades_value IS NULL OR trades_value >= 0", name="ck_market_overview_trades_value_non_negative"),
        sa.CheckConstraint("trades_volume >= 0", name="ck_market_overview_trades_volume_non_negative"),
    )
    op.create_index(
        "ix_market_overview_price_info_desc",
        "market_overviews",
        ["price_info_timestamp"],
    )


def downgrade() -> None:
    if "market_overviews" in set(sa.inspect(op.get_bind()).get_table_names()):
        op.drop_table("market_overviews")
