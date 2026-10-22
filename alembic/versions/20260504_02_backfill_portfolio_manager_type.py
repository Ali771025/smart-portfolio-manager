"""backfill portfolio manager type from legacy description markers

Revision ID: 20260504_02
Revises: 20260504_01
Create Date: 2026-05-04 00:10:00.000000
"""

from __future__ import annotations

from alembic import op


# revision identifiers, used by Alembic.
revision = "20260504_02"
down_revision = "20260504_01"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Backfill manager_type for rows still UNKNOWN using legacy description markers.
    # This is idempotent and only updates rows that have not been set explicitly.
    op.execute(
        """
        UPDATE portfolios
        SET manager_type = 'AGAH'
        WHERE manager_type = 'UNKNOWN'
          AND (
              upper(coalesce(description, '')) LIKE '%"MANAGER":"AGAH"%'
              OR upper(coalesce(description, '')) LIKE '%[MANAGER]%'
                 AND upper(coalesce(description, '')) LIKE '%AGAH%'
          )
        """
    )
    op.execute(
        """
        UPDATE portfolios
        SET manager_type = 'MOFID'
        WHERE manager_type = 'UNKNOWN'
          AND (
              upper(coalesce(description, '')) LIKE '%"MANAGER":"MOFID"%'
              OR upper(coalesce(description, '')) LIKE '%[MANAGER]%'
                 AND upper(coalesce(description, '')) LIKE '%MOFID%'
          )
        """
    )
    op.execute(
        """
        UPDATE portfolios
        SET manager_type = 'BOURSIRAN'
        WHERE manager_type = 'UNKNOWN'
          AND (
              upper(coalesce(description, '')) LIKE '%"MANAGER":"BOURSIRAN"%'
              OR upper(coalesce(description, '')) LIKE '%[MANAGER]%'
                 AND upper(coalesce(description, '')) LIKE '%BOURSIRAN%'
          )
        """
    )


def downgrade() -> None:
    # Conservative downgrade: only revert known mapped values back to UNKNOWN.
    op.execute(
        """
        UPDATE portfolios
        SET manager_type = 'UNKNOWN'
        WHERE manager_type IN ('AGAH', 'MOFID', 'BOURSIRAN')
        """
    )
