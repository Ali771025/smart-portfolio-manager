"""add import job diagnostics jsonb column

Revision ID: 20260505_02
Revises: 20260505_01
Create Date: 2026-05-05 00:20:00.000000
"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql


# revision identifiers, used by Alembic.
revision = "20260505_02"
down_revision = "20260505_01"
branch_labels = None
depends_on = None


def _column_names(table_name: str) -> set[str]:
    inspector = sa.inspect(op.get_bind())
    return {col["name"] for col in inspector.get_columns(table_name)}


def upgrade() -> None:
    cols = _column_names("import_jobs")
    if "diagnostics" not in cols:
        op.add_column(
            "import_jobs",
            sa.Column(
                "diagnostics",
                postgresql.JSONB(astext_type=sa.Text()),
                nullable=False,
                server_default="{}",
            ),
        )
        op.alter_column("import_jobs", "diagnostics", server_default=None)


def downgrade() -> None:
    cols = _column_names("import_jobs")
    if "diagnostics" in cols:
        op.drop_column("import_jobs", "diagnostics")
