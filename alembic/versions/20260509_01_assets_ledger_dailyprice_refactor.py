"""refactor assets ledger and daily prices for decimal-accurate valuation

Revision ID: 20260509_01
Revises: 20260505_02
Create Date: 2026-05-09 00:00:00.000000
"""

from __future__ import annotations

import uuid
from datetime import UTC, datetime, time

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql


# revision identifiers, used by Alembic.
revision = "20260509_01"
down_revision = "20260505_02"
branch_labels = None
depends_on = None


def _table_exists(name: str) -> bool:
    inspector = sa.inspect(op.get_bind())
    return name in inspector.get_table_names()


def _column_names(table_name: str) -> set[str]:
    inspector = sa.inspect(op.get_bind())
    return {col["name"] for col in inspector.get_columns(table_name)}


def _index_names(table_name: str) -> set[str]:
    inspector = sa.inspect(op.get_bind())
    return {idx["name"] for idx in inspector.get_indexes(table_name)}


def _unique_constraint_names(table_name: str) -> set[str]:
    inspector = sa.inspect(op.get_bind())
    return {uc["name"] for uc in inspector.get_unique_constraints(table_name)}


def _ensure_timescaledb() -> bool:
    conn = op.get_bind()
    return bool(
        conn.execute(
            sa.text(
                """
                SELECT EXISTS (
                    SELECT 1
                    FROM pg_extension
                    WHERE extname = 'timescaledb'
                )
                """
            )
        ).scalar()
    )


def upgrade() -> None:
    conn = op.get_bind()

    if _table_exists("assets"):
        op.alter_column(
            "assets",
            "current_price",
            existing_type=sa.Numeric(18, 4),
            type_=sa.Numeric(24, 8),
            existing_nullable=False,
        )
        op.alter_column(
            "assets",
            "previous_close_price",
            existing_type=sa.Numeric(18, 4),
            type_=sa.Numeric(24, 8),
            existing_nullable=False,
        )

        asset_cols = _column_names("assets")
        if "version_id" not in asset_cols:
            op.add_column(
                "assets",
                sa.Column("version_id", sa.Integer(), nullable=False, server_default="1"),
            )
            op.alter_column("assets", "version_id", server_default=None)

    if _table_exists("transactions"):
        tx_cols = _column_names("transactions")
        if "idempotency_key" in tx_cols:
            op.alter_column(
                "transactions",
                "idempotency_key",
                existing_type=sa.String(length=255),
                type_=sa.String(length=128),
                existing_nullable=False,
            )

        if "version_id" not in tx_cols:
            op.add_column(
                "transactions",
                sa.Column("version_id", sa.Integer(), nullable=False, server_default="1"),
            )
            op.alter_column("transactions", "version_id", server_default=None)

        tx_uniques = _unique_constraint_names("transactions")
        if "uq_txn_portfolio_idempotency" not in tx_uniques:
            op.create_unique_constraint(
                "uq_txn_portfolio_idempotency",
                "transactions",
                ["portfolio_id", "idempotency_key"],
            )

    if not _table_exists("daily_prices"):
        op.create_table(
            "daily_prices",
            sa.Column("id", postgresql.UUID(as_uuid=True), nullable=False),
            sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.text("now()")),
            sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.text("now()")),
            sa.Column("asset_id", postgresql.UUID(as_uuid=True), nullable=False),
            sa.Column("price_time", sa.DateTime(timezone=True), nullable=False),
            sa.Column("date", sa.Date(), nullable=False),
            sa.Column("open_price", sa.Numeric(24, 8), nullable=False),
            sa.Column("high_price", sa.Numeric(24, 8), nullable=False),
            sa.Column("low_price", sa.Numeric(24, 8), nullable=False),
            sa.Column("close_price", sa.Numeric(24, 8), nullable=False),
            sa.Column("adjusted_close", sa.Numeric(24, 8), nullable=False),
            sa.Column("adjustment_factor", sa.Numeric(24, 8), nullable=False, server_default="1.00000000"),
            sa.Column("volume", sa.BigInteger(), nullable=False, server_default="0"),
            sa.Column("version_id", sa.Integer(), nullable=False, server_default="1"),
            sa.CheckConstraint("open_price >= 0", name="ck_daily_price_open_non_negative"),
            sa.CheckConstraint("high_price >= 0", name="ck_daily_price_high_non_negative"),
            sa.CheckConstraint("low_price >= 0", name="ck_daily_price_low_non_negative"),
            sa.CheckConstraint("close_price >= 0", name="ck_daily_price_close_non_negative"),
            sa.CheckConstraint("adjusted_close >= 0", name="ck_daily_price_adjusted_non_negative"),
            sa.CheckConstraint("volume >= 0", name="ck_daily_price_volume_non_negative"),
            sa.ForeignKeyConstraint(["asset_id"], ["assets.id"], ondelete="CASCADE"),
            sa.PrimaryKeyConstraint("id"),
            sa.UniqueConstraint("asset_id", "date", name="uq_daily_price_asset_date"),
        )
        op.create_index("ix_daily_price_asset_date_desc", "daily_prices", ["asset_id", "date"], unique=False)
        op.create_index("ix_daily_price_asset_time_desc", "daily_prices", ["asset_id", "price_time"], unique=False)

        op.alter_column("daily_prices", "adjustment_factor", server_default=None)
        op.alter_column("daily_prices", "volume", server_default=None)
        op.alter_column("daily_prices", "version_id", server_default=None)

    if _table_exists("asset_price_history") and _table_exists("daily_prices"):
        existing_count = conn.execute(sa.text("SELECT count(*) FROM daily_prices")).scalar() or 0
        if existing_count == 0:
            rows = conn.execute(
                sa.text(
                    """
                    SELECT
                        asset_id,
                        date,
                        open_price,
                        high_price,
                        low_price,
                        close_price,
                        adjusted_close,
                        adjustment_factor,
                        volume,
                        created_at,
                        updated_at
                    FROM asset_price_history
                    ORDER BY asset_id, date
                    """
                )
            ).mappings()

            insert_stmt = sa.text(
                """
                INSERT INTO daily_prices (
                    id,
                    created_at,
                    updated_at,
                    asset_id,
                    price_time,
                    date,
                    open_price,
                    high_price,
                    low_price,
                    close_price,
                    adjusted_close,
                    adjustment_factor,
                    volume,
                    version_id
                ) VALUES (
                    :id,
                    :created_at,
                    :updated_at,
                    :asset_id,
                    :price_time,
                    :date,
                    :open_price,
                    :high_price,
                    :low_price,
                    :close_price,
                    :adjusted_close,
                    :adjustment_factor,
                    :volume,
                    1
                )
                """
            )

            for row in rows:
                naive_midnight = datetime.combine(row["date"], time.min)
                conn.execute(
                    insert_stmt,
                    {
                        "id": uuid.uuid4(),
                        "created_at": row["created_at"],
                        "updated_at": row["updated_at"],
                        "asset_id": row["asset_id"],
                        "price_time": naive_midnight.replace(tzinfo=UTC),
                        "date": row["date"],
                        "open_price": row["open_price"],
                        "high_price": row["high_price"],
                        "low_price": row["low_price"],
                        "close_price": row["close_price"],
                        "adjusted_close": row["adjusted_close"],
                        "adjustment_factor": row["adjustment_factor"],
                        "volume": row["volume"],
                    },
                )

    op.execute(
        """
        DO $$
        BEGIN
            CREATE EXTENSION IF NOT EXISTS timescaledb;
        EXCEPTION
            WHEN insufficient_privilege OR feature_not_supported OR undefined_file THEN NULL;
        END
        $$;
        """
    )

    if _ensure_timescaledb() and _table_exists("daily_prices"):
        op.execute(
            """
            SELECT create_hypertable(
                'daily_prices',
                'price_time',
                chunk_time_interval => INTERVAL '30 days',
                if_not_exists => TRUE,
                migrate_data => TRUE
            )
            """
        )


def downgrade() -> None:
    if _table_exists("daily_prices"):
        op.drop_index("ix_daily_price_asset_time_desc", table_name="daily_prices")
        op.drop_index("ix_daily_price_asset_date_desc", table_name="daily_prices")
        op.drop_table("daily_prices")

    if _table_exists("transactions"):
        tx_uniques = _unique_constraint_names("transactions")
        if "uq_txn_portfolio_idempotency" in tx_uniques:
            op.drop_constraint("uq_txn_portfolio_idempotency", "transactions", type_="unique")

        tx_cols = _column_names("transactions")
        if "version_id" in tx_cols:
            op.drop_column("transactions", "version_id")

        if "idempotency_key" in tx_cols:
            op.alter_column(
                "transactions",
                "idempotency_key",
                existing_type=sa.String(length=128),
                type_=sa.String(length=255),
                existing_nullable=False,
            )

    if _table_exists("assets"):
        asset_cols = _column_names("assets")
        if "version_id" in asset_cols:
            op.drop_column("assets", "version_id")

        op.alter_column(
            "assets",
            "current_price",
            existing_type=sa.Numeric(24, 8),
            type_=sa.Numeric(18, 4),
            existing_nullable=False,
        )
        op.alter_column(
            "assets",
            "previous_close_price",
            existing_type=sa.Numeric(24, 8),
            type_=sa.Numeric(18, 4),
            existing_nullable=False,
        )
