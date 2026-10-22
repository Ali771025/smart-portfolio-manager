"""phase2 domain entity alignment for import pipeline

Revision ID: 20260505_01
Revises: 20260504_02
Create Date: 2026-05-05 00:00:00.000000
"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql


# revision identifiers, used by Alembic.
revision = "20260505_01"
down_revision = "20260504_02"
branch_labels = None
depends_on = None


def _table_exists(name: str) -> bool:
    inspector = sa.inspect(op.get_bind())
    return name in inspector.get_table_names()


def _column_names(table_name: str) -> set[str]:
    inspector = sa.inspect(op.get_bind())
    return {col["name"] for col in inspector.get_columns(table_name)}


def _index_names(table_name: str) -> set[str]:
    inspector = sa.inspect(op.get_bind())
    return {idx["name"] for idx in inspector.get_indexes(table_name)}


def upgrade() -> None:
    if _table_exists("portfolios"):
        cols = _column_names("portfolios")
        if "broker_metadata" not in cols:
            op.add_column(
                "portfolios",
                sa.Column("broker_metadata", postgresql.JSONB(astext_type=sa.Text()), nullable=True),
            )

    if _table_exists("assets"):
        cols = _column_names("assets")
        if "normalized_symbol" not in cols:
            op.add_column("assets", sa.Column("normalized_symbol", sa.String(length=50), nullable=True))
            op.execute("UPDATE assets SET normalized_symbol = upper(trim(ticker_symbol)) WHERE normalized_symbol IS NULL")
            op.alter_column("assets", "normalized_symbol", existing_type=sa.String(length=50), nullable=False)
        if "display_metadata" not in cols:
            op.add_column(
                "assets",
                sa.Column("display_metadata", postgresql.JSONB(astext_type=sa.Text()), nullable=True),
            )

        indexes = _index_names("assets")
        if "ix_assets_normalized_symbol" not in indexes:
            op.create_index("ix_assets_normalized_symbol", "assets", ["normalized_symbol"], unique=False)

    if _table_exists("transactions"):
        cols = _column_names("transactions")
        if "source_metadata" not in cols:
            op.add_column(
                "transactions",
                sa.Column("source_metadata", postgresql.JSONB(astext_type=sa.Text()), nullable=True),
            )

    if not _table_exists("holding_snapshots"):
        op.create_table(
            "holding_snapshots",
            sa.Column("id", postgresql.UUID(as_uuid=True), nullable=False),
            sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
            sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
            sa.Column("portfolio_id", postgresql.UUID(as_uuid=True), nullable=False),
            sa.Column("asset_id", postgresql.UUID(as_uuid=True), nullable=False),
            sa.Column("snapshot_date", sa.Date(), nullable=False),
            sa.Column("quantity", sa.Numeric(24, 8), nullable=False),
            sa.Column("average_cost", sa.Numeric(24, 8), nullable=False),
            sa.Column("cost_basis", sa.Numeric(24, 8), nullable=False),
            sa.Column("market_price", sa.Numeric(24, 8), nullable=True),
            sa.Column("market_value", sa.Numeric(24, 8), nullable=True),
            sa.Column("unrealized_pnl", sa.Numeric(24, 8), nullable=True),
            sa.Column("weight_pct", sa.Numeric(24, 8), nullable=True),
            sa.Column("source_metadata", postgresql.JSONB(astext_type=sa.Text()), nullable=True),
            sa.ForeignKeyConstraint(["portfolio_id"], ["portfolios.id"], ondelete="CASCADE"),
            sa.ForeignKeyConstraint(["asset_id"], ["assets.id"], ondelete="CASCADE"),
            sa.PrimaryKeyConstraint("id"),
            sa.UniqueConstraint(
                "portfolio_id",
                "asset_id",
                "snapshot_date",
                name="uq_holding_snapshot_portfolio_asset_date",
            ),
        )
        op.create_index(
            "ix_holding_snapshot_portfolio_date",
            "holding_snapshots",
            ["portfolio_id", "snapshot_date"],
            unique=False,
        )
        op.create_index(
            "ix_holding_snapshot_portfolio_asset_date",
            "holding_snapshots",
            ["portfolio_id", "asset_id", "snapshot_date"],
            unique=False,
        )


def downgrade() -> None:
    if _table_exists("holding_snapshots"):
        op.drop_index("ix_holding_snapshot_portfolio_asset_date", table_name="holding_snapshots")
        op.drop_index("ix_holding_snapshot_portfolio_date", table_name="holding_snapshots")
        op.drop_table("holding_snapshots")

    if _table_exists("transactions") and "source_metadata" in _column_names("transactions"):
        op.drop_column("transactions", "source_metadata")

    if _table_exists("assets"):
        indexes = _index_names("assets")
        if "ix_assets_normalized_symbol" in indexes:
            op.drop_index("ix_assets_normalized_symbol", table_name="assets")
        cols = _column_names("assets")
        if "display_metadata" in cols:
            op.drop_column("assets", "display_metadata")
        if "normalized_symbol" in cols:
            op.drop_column("assets", "normalized_symbol")

    if _table_exists("portfolios") and "broker_metadata" in _column_names("portfolios"):
        op.drop_column("portfolios", "broker_metadata")
