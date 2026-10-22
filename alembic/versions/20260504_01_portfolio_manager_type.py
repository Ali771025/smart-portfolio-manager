"""add explicit portfolio manager type

Revision ID: 20260504_01
Revises: 20260427_01
Create Date: 2026-05-04 00:00:00.000000
"""

from __future__ import annotations

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = "20260504_01"
down_revision = "20260427_01"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute(
        """
        DO $$
        BEGIN
            IF NOT EXISTS (
                SELECT 1
                FROM pg_type t
                JOIN pg_namespace n ON n.oid = t.typnamespace
                WHERE t.typname = 'portfolio_manager_type_enum'
                  AND n.nspname = current_schema()
            ) THEN
                CREATE TYPE portfolio_manager_type_enum AS ENUM (
                    'AGAH', 'MOFID', 'BOURSIRAN', 'UNKNOWN'
                );
            END IF;
        END
        $$;
        """
    )

    op.add_column(
        "portfolios",
        sa.Column(
            "manager_type",
            sa.Enum(
                "AGAH",
                "MOFID",
                "BOURSIRAN",
                "UNKNOWN",
                name="portfolio_manager_type_enum",
            ),
            nullable=False,
            server_default="UNKNOWN",
        ),
    )
    op.alter_column("portfolios", "manager_type", server_default=None)


def downgrade() -> None:
    op.drop_column("portfolios", "manager_type")
    op.execute("DROP TYPE IF EXISTS portfolio_manager_type_enum")
