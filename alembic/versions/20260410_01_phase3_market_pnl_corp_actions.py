"""phase3 market integration pnl and corporate actions

Revision ID: 20260410_01
Revises:
Create Date: 2026-04-10 00:00:00.000000
"""

from __future__ import annotations

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = "20260410_01"
down_revision = None
branch_labels = None
depends_on = None


benchmark_type_enum = sa.Enum(
    "GOLD_18K",
    "USD_IRR",
    "TEDPIX",
    name="benchmark_type_enum",
)


def upgrade() -> None:
    conn = op.get_bind()
    inspector = sa.inspect(conn)
    existing_tables = set(inspector.get_table_names())

    # Fresh database bootstrap: create the latest complete schema.
    # This repository currently has a single Alembic revision.
    required_core_tables = {"users", "assets", "portfolios", "asset_price_history"}
    if not required_core_tables.issubset(existing_tables):
        from app.models import Base

        Base.metadata.create_all(bind=conn, checkfirst=True)
        return

    # Incremental path for databases that already have core tables.
    type_exists = conn.execute(
        sa.text("SELECT 1 FROM pg_type WHERE typname = 'corporate_action_type_enum'")
    ).scalar()

    if type_exists:
        op.execute("ALTER TYPE corporate_action_type_enum ADD VALUE IF NOT EXISTS 'CAPITAL_INCREASE'")

    if "asset_price_history" in existing_tables:
        price_columns = {col["name"] for col in inspector.get_columns("asset_price_history")}
        if "adjustment_factor" not in price_columns:
            op.add_column(
                "asset_price_history",
                sa.Column(
                    "adjustment_factor",
                    sa.Numeric(18, 4),
                    nullable=False,
                    server_default="1.0000",
                ),
            )
            op.alter_column("asset_price_history", "adjustment_factor", server_default=None)

    benchmark_type_enum.create(op.get_bind(), checkfirst=True)

    if "benchmark_history" not in existing_tables:
        op.create_table(
            "benchmark_history",
            sa.Column("id", sa.UUID(), nullable=False),
            sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
            sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
            sa.Column("benchmark_type", benchmark_type_enum, nullable=False),
            sa.Column("date", sa.Date(), nullable=False),
            sa.Column("open_price", sa.Numeric(18, 4), nullable=False),
            sa.Column("high_price", sa.Numeric(18, 4), nullable=False),
            sa.Column("low_price", sa.Numeric(18, 4), nullable=False),
            sa.Column("close_price", sa.Numeric(18, 4), nullable=False),
            sa.Column("adjusted_close", sa.Numeric(18, 4), nullable=False),
            sa.Column("adjustment_factor", sa.Numeric(18, 4), nullable=False, server_default="1.0000"),
            sa.Column("volume", sa.BigInteger(), nullable=True),
            sa.Column("source", sa.String(length=64), nullable=False),
            sa.PrimaryKeyConstraint("id"),
            sa.UniqueConstraint("benchmark_type", "date", name="uq_benchmark_type_date"),
        )
        op.create_index("ix_benchmark_type_date", "benchmark_history", ["benchmark_type", "date"], unique=False)

    if "dividend_transactions" not in existing_tables:
        op.create_table(
            "dividend_transactions",
            sa.Column("id", sa.UUID(), nullable=False),
            sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
            sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
            sa.Column("portfolio_id", sa.UUID(), nullable=False),
            sa.Column("asset_id", sa.UUID(), nullable=False),
            sa.Column("effective_date", sa.Date(), nullable=False),
            sa.Column("dps_amount", sa.Numeric(18, 4), nullable=False),
            sa.Column("holding_quantity", sa.Numeric(18, 4), nullable=False),
            sa.Column("total_dividend_profit", sa.Numeric(18, 4), nullable=False),
            sa.Column("idempotency_key", sa.String(length=255), nullable=False),
            sa.Column("notes", sa.String(length=500), nullable=True),
            sa.ForeignKeyConstraint(["asset_id"], ["assets.id"], ondelete="CASCADE"),
            sa.ForeignKeyConstraint(["portfolio_id"], ["portfolios.id"], ondelete="CASCADE"),
            sa.PrimaryKeyConstraint("id"),
            sa.UniqueConstraint("portfolio_id", "idempotency_key", name="uq_dividend_idempotency"),
        )
        op.create_index(
            "ix_dividend_portfolio_asset",
            "dividend_transactions",
            ["portfolio_id", "asset_id"],
            unique=False,
        )
        op.create_index("ix_dividend_effective_date", "dividend_transactions", ["effective_date"], unique=False)

    if "corporate_action_executions" not in existing_tables:
        op.create_table(
            "corporate_action_executions",
            sa.Column("id", sa.UUID(), nullable=False),
            sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
            sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
            sa.Column("portfolio_id", sa.UUID(), nullable=False),
            sa.Column("asset_id", sa.UUID(), nullable=False),
            sa.Column(
                "action_type",
                sa.Enum(
                    "STOCK_SPLIT",
                    "CASH_DIVIDEND",
                    "STOCK_DIVIDEND",
                    "RIGHTS_ISSUE",
                    "CAPITAL_INCREASE",
                    name="corporate_action_type_enum",
                ),
                nullable=False,
            ),
            sa.Column("executed_at", sa.DateTime(timezone=True), nullable=False),
            sa.Column("issue_quantity", sa.Numeric(18, 4), nullable=False),
            sa.Column("issue_price", sa.Numeric(18, 4), nullable=False),
            sa.Column("old_quantity", sa.Numeric(18, 4), nullable=False),
            sa.Column("old_wac", sa.Numeric(18, 4), nullable=False),
            sa.Column("new_quantity", sa.Numeric(18, 4), nullable=False),
            sa.Column("new_wac", sa.Numeric(18, 4), nullable=False),
            sa.Column("idempotency_key", sa.String(length=255), nullable=False),
            sa.ForeignKeyConstraint(["asset_id"], ["assets.id"], ondelete="CASCADE"),
            sa.ForeignKeyConstraint(["portfolio_id"], ["portfolios.id"], ondelete="CASCADE"),
            sa.PrimaryKeyConstraint("id"),
            sa.UniqueConstraint("portfolio_id", "idempotency_key", name="uq_corp_action_idempotency"),
        )
        op.create_index(
            "ix_corp_exec_portfolio_asset",
            "corporate_action_executions",
            ["portfolio_id", "asset_id"],
            unique=False,
        )


def downgrade() -> None:
    conn = op.get_bind()
    inspector = sa.inspect(conn)
    existing_tables = set(inspector.get_table_names())

    if "corporate_action_executions" in existing_tables:
        op.execute("DROP INDEX IF EXISTS ix_corp_exec_portfolio_asset")
        op.drop_table("corporate_action_executions")

    if "dividend_transactions" in existing_tables:
        op.execute("DROP INDEX IF EXISTS ix_dividend_effective_date")
        op.execute("DROP INDEX IF EXISTS ix_dividend_portfolio_asset")
        op.drop_table("dividend_transactions")

    if "benchmark_history" in existing_tables:
        op.execute("DROP INDEX IF EXISTS ix_benchmark_type_date")
        op.drop_table("benchmark_history")

    if "asset_price_history" in existing_tables:
        price_columns = {col["name"] for col in inspector.get_columns("asset_price_history")}
        if "adjustment_factor" in price_columns:
            op.drop_column("asset_price_history", "adjustment_factor")

    benchmark_type_enum.drop(op.get_bind(), checkfirst=True)
