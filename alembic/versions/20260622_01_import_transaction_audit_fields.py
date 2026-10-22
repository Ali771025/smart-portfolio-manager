"""add import audit fields to trade and cash ledgers

Revision ID: 20260622_01
Revises: 20260619_03
Create Date: 2026-06-22 00:00:00.000000
"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql


revision = "20260622_01"
down_revision = "20260619_03"
branch_labels = None
depends_on = None


def _table_exists(name: str) -> bool:
    return name in sa.inspect(op.get_bind()).get_table_names()


def _column_names(table_name: str) -> set[str]:
    return {col["name"] for col in sa.inspect(op.get_bind()).get_columns(table_name)}


def _index_names(table_name: str) -> set[str]:
    return {idx["name"] for idx in sa.inspect(op.get_bind()).get_indexes(table_name)}


def _add_column_if_missing(table_name: str, column: sa.Column) -> None:
    if column.name not in _column_names(table_name):
        op.add_column(table_name, column)


def _create_index_if_missing(index_name: str, table_name: str, columns: list[str]) -> None:
    if index_name not in _index_names(table_name):
        op.create_index(index_name, table_name, columns, unique=False)


def upgrade() -> None:
    if _table_exists("transactions"):
        _add_column_if_missing(
            "transactions",
            sa.Column("import_batch_id", postgresql.UUID(as_uuid=True), nullable=True),
        )
        _add_column_if_missing("transactions", sa.Column("source_broker", sa.String(length=32), nullable=True))
        _add_column_if_missing("transactions", sa.Column("source_file_hash", sa.String(length=64), nullable=True))
        _add_column_if_missing("transactions", sa.Column("source_row_number", sa.Integer(), nullable=True))
        _add_column_if_missing("transactions", sa.Column("raw_type", sa.String(length=64), nullable=True))
        _add_column_if_missing("transactions", sa.Column("normalized_type", sa.String(length=32), nullable=True))
        _add_column_if_missing("transactions", sa.Column("net_amount", sa.Numeric(24, 8), nullable=True))
        _add_column_if_missing("transactions", sa.Column("fee_or_adjustment", sa.Numeric(24, 8), nullable=True))
        _add_column_if_missing("transactions", sa.Column("cash_effect", sa.Numeric(24, 8), nullable=True))
        _add_column_if_missing("transactions", sa.Column("debit_amount", sa.Numeric(24, 8), nullable=True))
        _add_column_if_missing("transactions", sa.Column("credit_amount", sa.Numeric(24, 8), nullable=True))
        _add_column_if_missing("transactions", sa.Column("balance_after", sa.Numeric(24, 8), nullable=True))

        _create_index_if_missing("ix_transactions_import_batch_id", "transactions", ["import_batch_id"])
        _create_index_if_missing("ix_transactions_source_file_hash", "transactions", ["source_file_hash"])
        _create_index_if_missing("ix_transactions_normalized_type", "transactions", ["normalized_type"])

        bind = op.get_bind()
        fk_names = {fk["name"] for fk in sa.inspect(bind).get_foreign_keys("transactions")}
        if "fk_transactions_import_batch_id_import_jobs" not in fk_names and _table_exists("import_jobs"):
            op.create_foreign_key(
                "fk_transactions_import_batch_id_import_jobs",
                "transactions",
                "import_jobs",
                ["import_batch_id"],
                ["id"],
                ondelete="SET NULL",
            )

    if _table_exists("portfolio_cash_transactions"):
        _add_column_if_missing(
            "portfolio_cash_transactions",
            sa.Column("raw_type", sa.String(length=64), nullable=True),
        )
        _add_column_if_missing(
            "portfolio_cash_transactions",
            sa.Column("fee_or_adjustment", sa.Numeric(24, 8), nullable=True),
        )
        _add_column_if_missing(
            "portfolio_cash_transactions",
            sa.Column("cash_effect", sa.Numeric(24, 8), nullable=True),
        )
        _add_column_if_missing(
            "portfolio_cash_transactions",
            sa.Column("debit_amount", sa.Numeric(24, 8), nullable=True),
        )
        _add_column_if_missing(
            "portfolio_cash_transactions",
            sa.Column("credit_amount", sa.Numeric(24, 8), nullable=True),
        )
        _add_column_if_missing(
            "portfolio_cash_transactions",
            sa.Column("balance_after", sa.Numeric(24, 8), nullable=True),
        )


def downgrade() -> None:
    if _table_exists("portfolio_cash_transactions"):
        for column_name in (
            "balance_after",
            "credit_amount",
            "debit_amount",
            "cash_effect",
            "fee_or_adjustment",
            "raw_type",
        ):
            if column_name in _column_names("portfolio_cash_transactions"):
                op.drop_column("portfolio_cash_transactions", column_name)

    if _table_exists("transactions"):
        bind = op.get_bind()
        fk_names = {fk["name"] for fk in sa.inspect(bind).get_foreign_keys("transactions")}
        if "fk_transactions_import_batch_id_import_jobs" in fk_names:
            op.drop_constraint("fk_transactions_import_batch_id_import_jobs", "transactions", type_="foreignkey")

        for index_name in (
            "ix_transactions_normalized_type",
            "ix_transactions_source_file_hash",
            "ix_transactions_import_batch_id",
        ):
            if index_name in _index_names("transactions"):
                op.drop_index(index_name, table_name="transactions")

        for column_name in (
            "balance_after",
            "credit_amount",
            "debit_amount",
            "cash_effect",
            "fee_or_adjustment",
            "net_amount",
            "normalized_type",
            "raw_type",
            "source_row_number",
            "source_file_hash",
            "source_broker",
            "import_batch_id",
        ):
            if column_name in _column_names("transactions"):
                op.drop_column("transactions", column_name)
