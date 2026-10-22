"""Add manual break-even price to asset positions.

Revision ID: 20260617_01
Revises: 20260616_01
Create Date: 2026-06-17
"""

from __future__ import annotations

from alembic import op
import sqlalchemy as sa


revision = "20260617_01"
down_revision = "20260616_01"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "asset_positions",
        sa.Column(
            "manual_break_even_price",
            sa.Numeric(24, 8),
            nullable=True,
            comment=(
                "User-entered break-even sell price for this portfolio asset, "
                "including expected buy/sell fees when provided."
            ),
        ),
    )


def downgrade() -> None:
    op.drop_column("asset_positions", "manual_break_even_price")
