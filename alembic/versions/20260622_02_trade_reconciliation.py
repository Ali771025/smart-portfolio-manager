"""add cross-portfolio trade reconciliation persistence

Revision ID: 20260622_02
Revises: 20260622_01
Create Date: 2026-06-22 12:00:00.000000
"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision = "20260622_02"
down_revision = "20260622_01"
branch_labels = None
depends_on = None

status_enum = postgresql.ENUM(
    "SUGGESTED", "CONFIRMED", "REJECTED", "CANCELED", "EXPIRED",
    name="trade_reconciliation_status_enum",
    create_type=False,
)
method_enum = postgresql.ENUM(
    "AUTO", "MANUAL", name="trade_reconciliation_method_enum", create_type=False
)
audit_action_enum = postgresql.ENUM(
    "CREATED", "ALLOCATION_ADDED", "CONFIRMED", "REJECTED", "CANCELED",
    name="trade_reconciliation_audit_action_enum",
    create_type=False,
)


def upgrade() -> None:
    bind = op.get_bind()
    status_enum.create(bind, checkfirst=True)
    method_enum.create(bind, checkfirst=True)
    audit_action_enum.create(bind, checkfirst=True)

    op.create_table(
        "trade_reconciliations",
        sa.Column("id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("user_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("asset_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("sell_transaction_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("destination_portfolio_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("status", status_enum, server_default="SUGGESTED", nullable=False),
        sa.Column("matching_method", method_enum, nullable=False),
        sa.Column("confidence_score", sa.Numeric(5, 4), nullable=True),
        sa.Column("notes", sa.Text(), nullable=True),
        sa.Column("rationale", postgresql.JSONB(astext_type=sa.Text()), nullable=True),
        sa.Column("created_by_user_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("updated_by_user_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("confirmed_by_user_id", postgresql.UUID(as_uuid=True), nullable=True),
        sa.Column("rejected_by_user_id", postgresql.UUID(as_uuid=True), nullable=True),
        sa.Column("canceled_by_user_id", postgresql.UUID(as_uuid=True), nullable=True),
        sa.Column("confirmed_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("rejected_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("canceled_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.CheckConstraint(
            "confidence_score IS NULL OR (confidence_score >= 0 AND confidence_score <= 1)",
            name="ck_trade_reconciliation_confidence_range",
        ),
        sa.ForeignKeyConstraint(["asset_id"], ["assets.id"], ondelete="RESTRICT"),
        sa.ForeignKeyConstraint(["sell_transaction_id"], ["transactions.id"], ondelete="RESTRICT"),
        sa.ForeignKeyConstraint(["destination_portfolio_id"], ["portfolios.id"], ondelete="RESTRICT"),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["created_by_user_id"], ["users.id"], ondelete="RESTRICT"),
        sa.ForeignKeyConstraint(["updated_by_user_id"], ["users.id"], ondelete="RESTRICT"),
        sa.ForeignKeyConstraint(["confirmed_by_user_id"], ["users.id"], ondelete="RESTRICT"),
        sa.ForeignKeyConstraint(["rejected_by_user_id"], ["users.id"], ondelete="RESTRICT"),
        sa.ForeignKeyConstraint(["canceled_by_user_id"], ["users.id"], ondelete="RESTRICT"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_trade_reconciliation_user_status", "trade_reconciliations", ["user_id", "status"])
    op.create_index("ix_trade_reconciliation_user_asset", "trade_reconciliations", ["user_id", "asset_id"])
    op.create_index("ix_trade_reconciliation_sell_status", "trade_reconciliations", ["sell_transaction_id", "status"])

    op.create_table(
        "trade_reconciliation_allocations",
        sa.Column("id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("reconciliation_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("buy_transaction_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("source_portfolio_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("matched_quantity", sa.Numeric(24, 8), nullable=False),
        sa.Column("allocated_buy_cost", sa.Numeric(24, 8), nullable=True),
        sa.Column("allocated_sell_proceeds", sa.Numeric(24, 8), nullable=True),
        sa.Column("realized_pnl", sa.Numeric(24, 8), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.CheckConstraint("matched_quantity > 0", name="ck_reconciliation_allocation_quantity_positive"),
        sa.CheckConstraint("allocated_buy_cost IS NULL OR allocated_buy_cost >= 0", name="ck_reconciliation_allocation_buy_cost_non_negative"),
        sa.CheckConstraint("allocated_sell_proceeds IS NULL OR allocated_sell_proceeds >= 0", name="ck_reconciliation_allocation_sell_proceeds_non_negative"),
        sa.ForeignKeyConstraint(["buy_transaction_id"], ["transactions.id"], ondelete="RESTRICT"),
        sa.ForeignKeyConstraint(["reconciliation_id"], ["trade_reconciliations.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["source_portfolio_id"], ["portfolios.id"], ondelete="RESTRICT"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("reconciliation_id", "buy_transaction_id", name="uq_trade_reconciliation_allocation_buy"),
    )
    op.create_index("ix_reconciliation_allocation_buy", "trade_reconciliation_allocations", ["buy_transaction_id"])
    op.create_index("ix_reconciliation_allocation_source", "trade_reconciliation_allocations", ["source_portfolio_id", "buy_transaction_id"])

    op.create_table(
        "trade_reconciliation_audit_events",
        sa.Column("id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("reconciliation_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("actor_user_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("action", audit_action_enum, nullable=False),
        sa.Column("reason", sa.String(length=1000), nullable=True),
        sa.Column("event_metadata", postgresql.JSONB(astext_type=sa.Text()), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.ForeignKeyConstraint(["actor_user_id"], ["users.id"], ondelete="RESTRICT"),
        sa.ForeignKeyConstraint(["reconciliation_id"], ["trade_reconciliations.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_reconciliation_audit_case_time", "trade_reconciliation_audit_events", ["reconciliation_id", "created_at"])
    op.create_index("ix_reconciliation_audit_actor", "trade_reconciliation_audit_events", ["actor_user_id", "created_at"])


def downgrade() -> None:
    op.drop_table("trade_reconciliation_audit_events")
    op.drop_table("trade_reconciliation_allocations")
    op.drop_table("trade_reconciliations")
    bind = op.get_bind()
    audit_action_enum.drop(bind, checkfirst=True)
    method_enum.drop(bind, checkfirst=True)
    status_enum.drop(bind, checkfirst=True)
