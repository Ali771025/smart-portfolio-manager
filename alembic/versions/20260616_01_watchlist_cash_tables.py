"""add watchlist alerts and portfolio cash transaction tables

Revision ID: 20260616_01
Revises: 20260509_01
Create Date: 2026-06-16 00:00:00.000000
"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql


revision = "20260616_01"
down_revision = "20260509_01"
branch_labels = None
depends_on = None


def _table_exists(name: str) -> bool:
    return name in sa.inspect(op.get_bind()).get_table_names()


def upgrade() -> None:
    if not _table_exists("watchlists"):
        op.create_table(
            "watchlists",
            sa.Column("id", postgresql.UUID(as_uuid=True), nullable=False),
            sa.Column("user_id", postgresql.UUID(as_uuid=True), nullable=False),
            sa.Column("name", sa.String(length=100), nullable=False),
            sa.Column("description", sa.Text(), nullable=True),
            sa.Column("is_default", sa.Boolean(), nullable=False, server_default="false"),
            sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.text("now()")),
            sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.text("now()")),
            sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
            sa.PrimaryKeyConstraint("id"),
        )
        op.create_index("ix_watchlist_user_id", "watchlists", ["user_id"], unique=False)
        op.alter_column("watchlists", "is_default", server_default=None)

    if not _table_exists("watchlist_items"):
        op.create_table(
            "watchlist_items",
            sa.Column("id", postgresql.UUID(as_uuid=True), nullable=False),
            sa.Column("watchlist_id", postgresql.UUID(as_uuid=True), nullable=False),
            sa.Column("asset_id", postgresql.UUID(as_uuid=True), nullable=False),
            sa.Column("added_at", sa.DateTime(timezone=True), nullable=False),
            sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.text("now()")),
            sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.text("now()")),
            sa.ForeignKeyConstraint(["asset_id"], ["assets.id"], ondelete="CASCADE"),
            sa.ForeignKeyConstraint(["watchlist_id"], ["watchlists.id"], ondelete="CASCADE"),
            sa.PrimaryKeyConstraint("id"),
            sa.UniqueConstraint("watchlist_id", "asset_id", name="uq_watchlist_asset"),
        )
        op.create_index(
            "ix_watchlist_item_watchlist_id",
            "watchlist_items",
            ["watchlist_id"],
            unique=False,
        )

    if not _table_exists("alert_rules"):
        op.create_table(
            "alert_rules",
            sa.Column("id", postgresql.UUID(as_uuid=True), nullable=False),
            sa.Column("user_id", postgresql.UUID(as_uuid=True), nullable=False),
            sa.Column("watchlist_item_id", postgresql.UUID(as_uuid=True), nullable=False),
            sa.Column("alert_type", sa.String(length=50), nullable=False),
            sa.Column("threshold", sa.Float(), nullable=False),
            sa.Column("threshold_pct", sa.Float(), nullable=True),
            sa.Column("status", sa.String(length=20), nullable=False, server_default="ACTIVE"),
            sa.Column("frequency", sa.String(length=20), nullable=False, server_default="always"),
            sa.Column("notification_channels", postgresql.JSONB(astext_type=sa.Text()), nullable=True),
            sa.Column("message_template", sa.Text(), nullable=True),
            sa.Column("expires_at", sa.DateTime(timezone=True), nullable=True),
            sa.Column("last_triggered_at", sa.DateTime(timezone=True), nullable=True),
            sa.Column("trigger_count", sa.Integer(), nullable=False, server_default="0"),
            sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.text("now()")),
            sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.text("now()")),
            sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
            sa.ForeignKeyConstraint(["watchlist_item_id"], ["watchlist_items.id"], ondelete="CASCADE"),
            sa.PrimaryKeyConstraint("id"),
        )
        op.create_index("ix_alert_rule_user_id", "alert_rules", ["user_id"], unique=False)
        op.create_index("ix_alert_rule_status", "alert_rules", ["status"], unique=False)
        op.create_index(
            "ix_alert_rule_watchlist_item_id",
            "alert_rules",
            ["watchlist_item_id"],
            unique=False,
        )
        op.alter_column("alert_rules", "status", server_default=None)
        op.alter_column("alert_rules", "frequency", server_default=None)
        op.alter_column("alert_rules", "trigger_count", server_default=None)

    if not _table_exists("alert_events"):
        op.create_table(
            "alert_events",
            sa.Column("id", postgresql.UUID(as_uuid=True), nullable=False),
            sa.Column("alert_id", postgresql.UUID(as_uuid=True), nullable=False),
            sa.Column("triggered_at", sa.DateTime(timezone=True), nullable=False),
            sa.Column("price_at_trigger", sa.Float(), nullable=False),
            sa.Column("threshold_value", sa.Float(), nullable=False),
            sa.Column("change_pct", sa.Float(), nullable=True),
            sa.Column("notification_sent", sa.Boolean(), nullable=False, server_default="false"),
            sa.Column("notification_channels", postgresql.JSONB(astext_type=sa.Text()), nullable=True),
            sa.Column("acknowledged_at", sa.DateTime(timezone=True), nullable=True),
            sa.ForeignKeyConstraint(["alert_id"], ["alert_rules.id"], ondelete="CASCADE"),
            sa.PrimaryKeyConstraint("id"),
        )
        op.create_index("ix_alert_event_alert_id", "alert_events", ["alert_id"], unique=False)
        op.create_index("ix_alert_event_triggered_at", "alert_events", ["triggered_at"], unique=False)
        op.alter_column("alert_events", "notification_sent", server_default=None)

    if not _table_exists("portfolio_cash_transactions"):
        op.create_table(
            "portfolio_cash_transactions",
            sa.Column("id", postgresql.UUID(as_uuid=True), nullable=False),
            sa.Column("portfolio_id", postgresql.UUID(as_uuid=True), nullable=False),
            sa.Column("asset_id", postgresql.UUID(as_uuid=True), nullable=True),
            sa.Column("import_batch_id", postgresql.UUID(as_uuid=True), nullable=False),
            sa.Column("source_broker", sa.String(length=32), nullable=False),
            sa.Column("source_row_number", sa.Integer(), nullable=False),
            sa.Column("normalized_type", sa.String(length=32), nullable=False),
            sa.Column("event_date", sa.String(length=32), nullable=False),
            sa.Column("raw_description", sa.Text(), nullable=False, server_default=""),
            sa.Column("normalized_description", sa.Text(), nullable=False, server_default=""),
            sa.Column("amount", sa.Numeric(24, 8), nullable=False, server_default="0.00000000"),
            sa.Column("quantity", sa.Numeric(24, 8), nullable=False, server_default="0.00000000"),
            sa.Column("price_per_unit", sa.Numeric(24, 8), nullable=False, server_default="0.00000000"),
            sa.Column("gross_amount", sa.Numeric(24, 8), nullable=False, server_default="0.00000000"),
            sa.Column("fees", sa.Numeric(24, 8), nullable=False, server_default="0.00000000"),
            sa.Column("tax", sa.Numeric(24, 8), nullable=False, server_default="0.00000000"),
            sa.Column("net_amount", sa.Numeric(24, 8), nullable=False, server_default="0.00000000"),
            sa.Column("source_file_hash", sa.String(length=64), nullable=True),
            sa.Column("row_hash", sa.String(length=64), nullable=False),
            sa.Column("idempotency_key", sa.String(length=128), nullable=False),
            sa.Column("diagnostics", postgresql.JSONB(astext_type=sa.Text()), nullable=True),
            sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.text("now()")),
            sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.text("now()")),
            sa.CheckConstraint("source_row_number >= 0", name="ck_cash_txn_row_number_non_negative"),
            sa.ForeignKeyConstraint(["asset_id"], ["assets.id"], ondelete="RESTRICT"),
            sa.ForeignKeyConstraint(["import_batch_id"], ["import_jobs.id"], ondelete="CASCADE"),
            sa.ForeignKeyConstraint(["portfolio_id"], ["portfolios.id"], ondelete="CASCADE"),
            sa.PrimaryKeyConstraint("id"),
            sa.UniqueConstraint("portfolio_id", "idempotency_key", name="uq_cash_txn_portfolio_idempotency"),
            sa.UniqueConstraint("row_hash", name="uq_cash_txn_row_hash"),
        )
        op.create_index("ix_cash_txn_portfolio_date", "portfolio_cash_transactions", ["portfolio_id", "event_date"])
        op.create_index("ix_portfolio_cash_transactions_asset_id", "portfolio_cash_transactions", ["asset_id"])
        op.create_index("ix_portfolio_cash_transactions_import_batch_id", "portfolio_cash_transactions", ["import_batch_id"])
        op.create_index("ix_portfolio_cash_transactions_normalized_type", "portfolio_cash_transactions", ["normalized_type"])
        op.create_index("ix_portfolio_cash_transactions_portfolio_id", "portfolio_cash_transactions", ["portfolio_id"])
        op.create_index("ix_portfolio_cash_transactions_source_file_hash", "portfolio_cash_transactions", ["source_file_hash"])
        op.create_index("ix_portfolio_cash_transactions_row_hash", "portfolio_cash_transactions", ["row_hash"])
        op.create_index("ix_portfolio_cash_transactions_idempotency_key", "portfolio_cash_transactions", ["idempotency_key"])

        for column in (
            "raw_description",
            "normalized_description",
            "amount",
            "quantity",
            "price_per_unit",
            "gross_amount",
            "fees",
            "tax",
            "net_amount",
        ):
            op.alter_column("portfolio_cash_transactions", column, server_default=None)


def downgrade() -> None:
    for table_name in (
        "portfolio_cash_transactions",
        "alert_events",
        "alert_rules",
        "watchlist_items",
        "watchlists",
    ):
        if _table_exists(table_name):
            op.drop_table(table_name)
