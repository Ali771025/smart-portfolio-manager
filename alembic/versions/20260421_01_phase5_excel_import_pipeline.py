"""phase5 excel import pipeline ledger hardening

Revision ID: 20260421_01
Revises: 20260410_01
Create Date: 2026-04-21 00:00:00.000000
"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision = "20260421_01"
down_revision = "20260410_01"
branch_labels = None
depends_on = None


import_job_status_enum = postgresql.ENUM(
    "PENDING",
    "PROCESSING",
    "COMPLETED",
    "FAILED",
    name="import_job_status_enum",
    create_type=False,
)


def _table_exists(name: str) -> bool:
    conn = op.get_bind()
    inspector = sa.inspect(conn)
    return name in inspector.get_table_names()


def _column_names(table_name: str) -> set[str]:
    conn = op.get_bind()
    inspector = sa.inspect(conn)
    return {col["name"] for col in inspector.get_columns(table_name)}


def upgrade() -> None:
    conn = op.get_bind()
    inspector = sa.inspect(conn)
    existing_tables = set(inspector.get_table_names())
    op.execute("CREATE EXTENSION IF NOT EXISTS pgcrypto")
    op.execute(
        """
        DO $$
        BEGIN
            IF NOT EXISTS (
                SELECT 1
                FROM pg_type t
                JOIN pg_namespace n ON n.oid = t.typnamespace
                WHERE t.typname = 'import_job_status_enum'
                  AND n.nspname = current_schema()
            ) THEN
                CREATE TYPE import_job_status_enum AS ENUM (
                    'PENDING', 'PROCESSING', 'COMPLETED', 'FAILED'
                );
            END IF;
        END
        $$;
        """
    )

    if "import_jobs" not in existing_tables:
        op.create_table(
            "import_jobs",
            sa.Column("id", sa.UUID(), nullable=False),
            sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
            sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
            sa.Column("user_id", sa.UUID(), nullable=False),
            sa.Column("portfolio_id", sa.UUID(), nullable=False),
            sa.Column("source_filename", sa.String(length=255), nullable=False),
            sa.Column("broker_format", sa.String(length=32), nullable=True),
            sa.Column("status", import_job_status_enum, nullable=False),
            sa.Column("started_at", sa.DateTime(timezone=True), nullable=True),
            sa.Column("completed_at", sa.DateTime(timezone=True), nullable=True),
            sa.Column("total_rows", sa.Integer(), nullable=False, server_default="0"),
            sa.Column("parsed_rows", sa.Integer(), nullable=False, server_default="0"),
            sa.Column("inserted_rows", sa.Integer(), nullable=False, server_default="0"),
            sa.Column("duplicates_skipped", sa.Integer(), nullable=False, server_default="0"),
            sa.Column("failed_rows", sa.Integer(), nullable=False, server_default="0"),
            sa.Column("error_details", postgresql.JSONB(astext_type=sa.Text()), nullable=False, server_default="[]"),
            sa.ForeignKeyConstraint(["portfolio_id"], ["portfolios.id"], ondelete="CASCADE"),
            sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
            sa.PrimaryKeyConstraint("id"),
            sa.CheckConstraint("total_rows >= 0", name="ck_import_jobs_total_rows_non_negative"),
            sa.CheckConstraint("parsed_rows >= 0", name="ck_import_jobs_parsed_rows_non_negative"),
            sa.CheckConstraint("inserted_rows >= 0", name="ck_import_jobs_inserted_rows_non_negative"),
            sa.CheckConstraint("duplicates_skipped >= 0", name="ck_import_jobs_duplicates_non_negative"),
            sa.CheckConstraint("failed_rows >= 0", name="ck_import_jobs_failed_rows_non_negative"),
        )
        op.create_index("ix_import_jobs_user_created", "import_jobs", ["user_id", "created_at"], unique=False)
        op.create_index("ix_import_jobs_status_created", "import_jobs", ["status", "created_at"], unique=False)
        op.create_index("ix_import_jobs_user_id", "import_jobs", ["user_id"], unique=False)
        op.create_index("ix_import_jobs_portfolio_id", "import_jobs", ["portfolio_id"], unique=False)
        op.create_index("ix_import_jobs_status", "import_jobs", ["status"], unique=False)
    else:
        cols = _column_names("import_jobs")
        if "error_details" not in cols:
            op.add_column(
                "import_jobs",
                sa.Column("error_details", postgresql.JSONB(astext_type=sa.Text()), nullable=False, server_default="[]"),
            )
            op.alter_column("import_jobs", "error_details", server_default=None)

    if "transactions" in existing_tables:
        txn_columns = _column_names("transactions")
        if "reference_hash" not in txn_columns:
            op.add_column("transactions", sa.Column("reference_hash", sa.String(length=64), nullable=True))
            op.execute(
                """
                UPDATE transactions
                SET reference_hash = encode(
                    digest(
                        COALESCE(portfolio_id::text, '') || '|' || COALESCE(idempotency_key, ''),
                        'sha256'
                    ),
                    'hex'
                )
                WHERE reference_hash IS NULL
                """
            )
            op.alter_column("transactions", "reference_hash", existing_type=sa.String(length=64), nullable=False)

        indexes = {index["name"] for index in inspector.get_indexes("transactions")}
        unique_constraints = {constraint["name"] for constraint in inspector.get_unique_constraints("transactions")}
        if "uq_transactions_reference_hash" not in unique_constraints:
            op.create_unique_constraint("uq_transactions_reference_hash", "transactions", ["reference_hash"])
        if "ix_transactions_reference_hash" not in indexes:
            op.create_index("ix_transactions_reference_hash", "transactions", ["reference_hash"], unique=False)


def downgrade() -> None:
    if _table_exists("transactions"):
        inspector = sa.inspect(op.get_bind())
        indexes = {index["name"] for index in inspector.get_indexes("transactions")}
        unique_constraints = {c["name"] for c in inspector.get_unique_constraints("transactions")}

        if "uq_transactions_reference_hash" in unique_constraints:
            op.drop_constraint("uq_transactions_reference_hash", "transactions", type_="unique")
        if "ix_transactions_reference_hash" in indexes:
            op.drop_index("ix_transactions_reference_hash", table_name="transactions")

    if _table_exists("import_jobs"):
        op.drop_index("ix_import_jobs_status", table_name="import_jobs")
        op.drop_index("ix_import_jobs_portfolio_id", table_name="import_jobs")
        op.drop_index("ix_import_jobs_user_id", table_name="import_jobs")
        op.drop_index("ix_import_jobs_status_created", table_name="import_jobs")
        op.drop_index("ix_import_jobs_user_created", table_name="import_jobs")
        op.drop_table("import_jobs")

    import_job_status_enum.drop(op.get_bind(), checkfirst=True)
