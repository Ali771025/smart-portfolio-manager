"""Add market last and closing price columns.

Revision ID: 20260618_01
Revises: 20260617_01
Create Date: 2026-06-18
"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op


revision = "20260618_01"
down_revision = "20260617_01"
branch_labels = None
depends_on = None


def _column_names(table_name: str) -> set[str]:
    inspector = sa.inspect(op.get_bind())
    return {col["name"] for col in inspector.get_columns(table_name)}


def upgrade() -> None:
    asset_columns = _column_names("assets")
    if "last_trade_price" not in asset_columns:
        op.add_column(
            "assets",
            sa.Column(
                "last_trade_price",
                sa.Numeric(24, 8),
                nullable=False,
                server_default="0.00000000",
                comment="Latest Last Price / pDrCotVal from TSETMC.",
            ),
        )
    if "closing_price" not in asset_columns:
        op.add_column(
            "assets",
            sa.Column(
                "closing_price",
                sa.Numeric(24, 8),
                nullable=False,
                server_default="0.00000000",
                comment="Latest Closing Price / pClosing from TSETMC.",
            ),
        )
    op.execute(
        """
        UPDATE assets
        SET
            last_trade_price = COALESCE(NULLIF(last_trade_price, 0), current_price, 0),
            closing_price = COALESCE(NULLIF(closing_price, 0), current_price, 0)
        """
    )
    op.alter_column("assets", "last_trade_price", server_default=None)
    op.alter_column("assets", "closing_price", server_default=None)
    op.create_check_constraint(
        "ck_asset_last_trade_price_non_negative",
        "assets",
        "last_trade_price >= 0",
    )
    op.create_check_constraint(
        "ck_asset_closing_price_non_negative",
        "assets",
        "closing_price >= 0",
    )

    daily_price_columns = _column_names("daily_prices")
    if "last_trade_price" not in daily_price_columns:
        op.add_column(
            "daily_prices",
            sa.Column(
                "last_trade_price",
                sa.Numeric(24, 8),
                nullable=False,
                server_default="0.00000000",
                comment="TSETMC Last Price / pDrCotVal for this trading day.",
            ),
        )
        op.execute(
            """
            UPDATE daily_prices
            SET last_trade_price = COALESCE(NULLIF(last_trade_price, 0), close_price, 0)
            """
        )
        op.alter_column("daily_prices", "last_trade_price", server_default=None)
    op.create_check_constraint(
        "ck_daily_price_last_trade_non_negative",
        "daily_prices",
        "last_trade_price >= 0",
    )


def downgrade() -> None:
    op.drop_constraint("ck_daily_price_last_trade_non_negative", "daily_prices", type_="check")
    if "last_trade_price" in _column_names("daily_prices"):
        op.drop_column("daily_prices", "last_trade_price")

    op.drop_constraint("ck_asset_closing_price_non_negative", "assets", type_="check")
    op.drop_constraint("ck_asset_last_trade_price_non_negative", "assets", type_="check")
    asset_columns = _column_names("assets")
    if "closing_price" in asset_columns:
        op.drop_column("assets", "closing_price")
    if "last_trade_price" in asset_columns:
        op.drop_column("assets", "last_trade_price")
