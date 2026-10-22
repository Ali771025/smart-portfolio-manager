"""advanced analytics engine timescaledb foundations

Revision ID: 20260424_01
Revises: 20260421_01
Create Date: 2026-04-24 00:00:00.000000
"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql


# revision identifiers, used by Alembic.
revision = "20260424_01"
down_revision = "20260421_01"
branch_labels = None
depends_on = None


ledger_event_type_enum = postgresql.ENUM(
    "TRADE_BUY",
    "TRADE_SELL",
    "CASH_DEPOSIT",
    "CASH_WITHDRAWAL",
    "CORPORATE_ACTION",
    "FEE",
    name="ledger_event_type_enum",
    create_type=False,
    _create_events=False,
)

inventory_accounting_method_enum = postgresql.ENUM(
    "WAC",
    "FIFO",
    name="inventory_accounting_method_enum",
    create_type=False,
    _create_events=False,
)


def _table_exists(name: str) -> bool:
    inspector = sa.inspect(op.get_bind())
    return name in inspector.get_table_names()


def _matview_exists(name: str) -> bool:
    conn = op.get_bind()
    return bool(
        conn.execute(
            sa.text(
                """
                SELECT EXISTS (
                    SELECT 1
                    FROM pg_matviews
                    WHERE schemaname = current_schema()
                      AND matviewname = :name
                )
                """
            ),
            {"name": name},
        ).scalar()
    )


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

    # Keep this migration portable on hosts where extension install is blocked.
    has_timescaledb = _ensure_timescaledb()

    ledger_event_type_enum.create(bind=conn, checkfirst=True)
    inventory_accounting_method_enum.create(bind=conn, checkfirst=True)

    if not _table_exists("ledger_events"):
        op.create_table(
            "ledger_events",
            sa.Column("id", sa.UUID(), nullable=False),
            sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
            sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
            sa.Column("portfolio_id", sa.UUID(), nullable=False),
            sa.Column("asset_id", sa.UUID(), nullable=True),
            sa.Column("event_type", ledger_event_type_enum, nullable=False),
            sa.Column(
                "inventory_method",
                inventory_accounting_method_enum,
                nullable=False,
                server_default="WAC",
            ),
            sa.Column("event_time", sa.DateTime(timezone=True), nullable=False),
            sa.Column("quantity", sa.Numeric(28, 10), nullable=False, server_default="0"),
            sa.Column("price", sa.Numeric(24, 8), nullable=False, server_default="0"),
            sa.Column("fees", sa.Numeric(24, 8), nullable=False, server_default="0"),
            sa.Column("gross_amount", sa.Numeric(24, 8), nullable=False, server_default="0"),
            sa.Column("net_amount", sa.Numeric(24, 8), nullable=False, server_default="0"),
            sa.Column("realized_pnl", sa.Numeric(24, 8), nullable=False, server_default="0"),
            sa.Column("idempotency_key", sa.String(length=128), nullable=False),
            sa.Column("event_hash", sa.String(length=64), nullable=False),
            sa.Column("payload", postgresql.JSONB(astext_type=sa.Text()), nullable=True),
            sa.CheckConstraint("quantity >= 0", name="ck_ledger_events_quantity_non_negative"),
            sa.CheckConstraint("price >= 0", name="ck_ledger_events_price_non_negative"),
            sa.CheckConstraint("fees >= 0", name="ck_ledger_events_fees_non_negative"),
            sa.ForeignKeyConstraint(["asset_id"], ["assets.id"], ondelete="RESTRICT"),
            sa.ForeignKeyConstraint(["portfolio_id"], ["portfolios.id"], ondelete="CASCADE"),
            sa.PrimaryKeyConstraint("id"),
            sa.UniqueConstraint("event_hash", name="uq_ledger_events_event_hash"),
            sa.UniqueConstraint(
                "portfolio_id",
                "idempotency_key",
                name="uq_ledger_events_portfolio_idempotency",
            ),
        )
        op.create_index("ix_ledger_events_portfolio_time", "ledger_events", ["portfolio_id", "event_time"])
        op.create_index("ix_ledger_events_asset_time", "ledger_events", ["asset_id", "event_time"])
        op.create_index("ix_ledger_events_event_type", "ledger_events", ["event_type"])

    if not _table_exists("market_ticks"):
        op.create_table(
            "market_ticks",
            sa.Column("asset_id", sa.UUID(), nullable=False),
            sa.Column("tick_time", sa.DateTime(timezone=True), nullable=False),
            sa.Column("sequence_no", sa.BigInteger(), nullable=False, server_default="0"),
            sa.Column("price", sa.Numeric(24, 8), nullable=False),
            sa.Column("volume", sa.BigInteger(), nullable=False, server_default="0"),
            sa.Column("notional", sa.Numeric(28, 8), nullable=False, server_default="0"),
            sa.Column("source", sa.String(length=32), nullable=False, server_default="UNKNOWN"),
            sa.Column("ingest_idempotency_key", sa.String(length=128), nullable=True),
            sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.text("now()")),
            sa.CheckConstraint("price >= 0", name="ck_market_ticks_price_non_negative"),
            sa.CheckConstraint("volume >= 0", name="ck_market_ticks_volume_non_negative"),
            sa.CheckConstraint("sequence_no >= 0", name="ck_market_ticks_sequence_non_negative"),
            sa.ForeignKeyConstraint(["asset_id"], ["assets.id"], ondelete="CASCADE"),
            sa.PrimaryKeyConstraint("asset_id", "tick_time", "sequence_no", name="pk_market_ticks"),
        )
        op.create_index("ix_market_ticks_asset_time", "market_ticks", ["asset_id", "tick_time"])
        op.create_index("ix_market_ticks_time", "market_ticks", ["tick_time"])

    if not _table_exists("portfolio_analytics_snapshots"):
        op.create_table(
            "portfolio_analytics_snapshots",
            sa.Column("id", sa.UUID(), nullable=False),
            sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
            sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
            sa.Column("portfolio_id", sa.UUID(), nullable=False),
            sa.Column("snapshot_at", sa.DateTime(timezone=True), nullable=False),
            sa.Column("total_market_value", sa.Numeric(24, 8), nullable=False),
            sa.Column("total_cost_basis", sa.Numeric(24, 8), nullable=False),
            sa.Column("unrealized_pnl", sa.Numeric(24, 8), nullable=False, server_default="0"),
            sa.Column("realized_pnl_cumulative", sa.Numeric(24, 8), nullable=False, server_default="0"),
            sa.Column("realized_pnl_delta", sa.Numeric(24, 8), nullable=False, server_default="0"),
            sa.Column("twr", sa.Numeric(18, 10), nullable=True),
            sa.Column("mwr", sa.Numeric(18, 10), nullable=True),
            sa.Column("max_drawdown", sa.Numeric(18, 10), nullable=True),
            sa.Column("sharpe_ratio", sa.Numeric(18, 10), nullable=True),
            sa.Column("metrics_payload", postgresql.JSONB(astext_type=sa.Text()), nullable=True),
            sa.CheckConstraint(
                "total_market_value >= 0",
                name="ck_portfolio_analytics_total_market_value_non_negative",
            ),
            sa.CheckConstraint(
                "total_cost_basis >= 0",
                name="ck_portfolio_analytics_total_cost_basis_non_negative",
            ),
            sa.ForeignKeyConstraint(["portfolio_id"], ["portfolios.id"], ondelete="CASCADE"),
            sa.PrimaryKeyConstraint("id"),
            sa.UniqueConstraint(
                "portfolio_id",
                "snapshot_at",
                name="uq_portfolio_analytics_snapshot_time",
            ),
        )
        op.create_index(
            "ix_portfolio_analytics_portfolio_time",
            "portfolio_analytics_snapshots",
            ["portfolio_id", "snapshot_at"],
        )

    if not has_timescaledb:
        return

    op.execute(
        """
        SELECT create_hypertable(
            'market_ticks',
            'tick_time',
            chunk_time_interval => INTERVAL '1 day',
            if_not_exists => TRUE,
            migrate_data => TRUE
        )
        """
    )
    op.execute(
        """
        SELECT create_hypertable(
            'portfolio_analytics_snapshots',
            'snapshot_at',
            chunk_time_interval => INTERVAL '7 days',
            if_not_exists => TRUE,
            migrate_data => TRUE
        )
        """
    )

    op.execute(
        """
        ALTER TABLE market_ticks
        SET (
            timescaledb.compress = true,
            timescaledb.compress_segmentby = 'asset_id',
            timescaledb.compress_orderby = 'tick_time DESC'
        )
        """
    )
    op.execute(
        """
        ALTER TABLE portfolio_analytics_snapshots
        SET (
            timescaledb.compress = true,
            timescaledb.compress_segmentby = 'portfolio_id',
            timescaledb.compress_orderby = 'snapshot_at DESC'
        )
        """
    )

    op.execute(
        """
        DO $$
        BEGIN
            PERFORM add_compression_policy('market_ticks', INTERVAL '7 days');
        EXCEPTION
            WHEN duplicate_object THEN NULL;
        END
        $$;
        """
    )
    op.execute(
        """
        DO $$
        BEGIN
            PERFORM add_compression_policy('portfolio_analytics_snapshots', INTERVAL '30 days');
        EXCEPTION
            WHEN duplicate_object THEN NULL;
        END
        $$;
        """
    )

    if not _matview_exists("market_ticks_1m_ohlcv"):
        op.execute(
            """
            CREATE MATERIALIZED VIEW market_ticks_1m_ohlcv
            WITH (timescaledb.continuous) AS
            SELECT
                asset_id,
                time_bucket(INTERVAL '1 minute', tick_time) AS bucket_start,
                first(price, tick_time) AS open_price,
                max(price) AS high_price,
                min(price) AS low_price,
                last(price, tick_time) AS close_price,
                sum(volume) AS total_volume,
                sum(notional) AS total_notional
            FROM market_ticks
            GROUP BY asset_id, bucket_start
            WITH NO DATA
            """
        )
    op.execute(
        """
        CREATE INDEX IF NOT EXISTS ix_market_ticks_1m_ohlcv_asset_bucket
        ON market_ticks_1m_ohlcv (asset_id, bucket_start DESC)
        """
    )

    if not _matview_exists("portfolio_pnl_daily_rollup"):
        op.execute(
            """
            CREATE MATERIALIZED VIEW portfolio_pnl_daily_rollup
            WITH (timescaledb.continuous) AS
            SELECT
                portfolio_id,
                time_bucket(INTERVAL '1 day', snapshot_at) AS bucket_start,
                last(total_market_value, snapshot_at) AS close_market_value,
                last(total_cost_basis, snapshot_at) AS close_cost_basis,
                last(unrealized_pnl, snapshot_at) AS close_unrealized_pnl,
                last(realized_pnl_cumulative, snapshot_at) AS realized_pnl_cumulative,
                sum(realized_pnl_delta) AS realized_pnl_delta
            FROM portfolio_analytics_snapshots
            GROUP BY portfolio_id, bucket_start
            WITH NO DATA
            """
        )
    op.execute(
        """
        CREATE INDEX IF NOT EXISTS ix_portfolio_pnl_daily_rollup_portfolio_bucket
        ON portfolio_pnl_daily_rollup (portfolio_id, bucket_start DESC)
        """
    )

    op.execute(
        """
        DO $$
        BEGIN
            PERFORM add_continuous_aggregate_policy(
                'market_ticks_1m_ohlcv',
                start_offset => INTERVAL '14 days',
                end_offset => INTERVAL '1 minute',
                schedule_interval => INTERVAL '1 minute'
            );
        EXCEPTION
            WHEN duplicate_object THEN NULL;
            WHEN undefined_function THEN NULL;
            WHEN feature_not_supported THEN NULL;
        END
        $$;
        """
    )
    op.execute(
        """
        DO $$
        BEGIN
            PERFORM add_continuous_aggregate_policy(
                'portfolio_pnl_daily_rollup',
                start_offset => INTERVAL '365 days',
                end_offset => INTERVAL '1 day',
                schedule_interval => INTERVAL '15 minutes'
            );
        EXCEPTION
            WHEN duplicate_object THEN NULL;
            WHEN undefined_function THEN NULL;
            WHEN feature_not_supported THEN NULL;
        END
        $$;
        """
    )


def downgrade() -> None:
    op.execute(
        """
        DO $$
        BEGIN
            PERFORM remove_continuous_aggregate_policy('market_ticks_1m_ohlcv');
        EXCEPTION
            WHEN undefined_object THEN NULL;
            WHEN undefined_function THEN NULL;
            WHEN feature_not_supported THEN NULL;
        END
        $$;
        """
    )
    op.execute(
        """
        DO $$
        BEGIN
            PERFORM remove_continuous_aggregate_policy('portfolio_pnl_daily_rollup');
        EXCEPTION
            WHEN undefined_object THEN NULL;
            WHEN undefined_function THEN NULL;
            WHEN feature_not_supported THEN NULL;
        END
        $$;
        """
    )

    op.execute(
        """
        DO $$
        BEGIN
            PERFORM remove_compression_policy('market_ticks');
        EXCEPTION
            WHEN undefined_object THEN NULL;
            WHEN undefined_function THEN NULL;
            WHEN feature_not_supported THEN NULL;
        END
        $$;
        """
    )
    op.execute(
        """
        DO $$
        BEGIN
            PERFORM remove_compression_policy('portfolio_analytics_snapshots');
        EXCEPTION
            WHEN undefined_object THEN NULL;
            WHEN undefined_function THEN NULL;
            WHEN feature_not_supported THEN NULL;
        END
        $$;
        """
    )

    op.execute("DROP MATERIALIZED VIEW IF EXISTS market_ticks_1m_ohlcv")
    op.execute("DROP MATERIALIZED VIEW IF EXISTS portfolio_pnl_daily_rollup")

    if _table_exists("portfolio_analytics_snapshots"):
        op.drop_index("ix_portfolio_analytics_portfolio_time", table_name="portfolio_analytics_snapshots")
        op.drop_table("portfolio_analytics_snapshots")

    if _table_exists("market_ticks"):
        op.drop_index("ix_market_ticks_time", table_name="market_ticks")
        op.drop_index("ix_market_ticks_asset_time", table_name="market_ticks")
        op.drop_table("market_ticks")

    if _table_exists("ledger_events"):
        op.drop_index("ix_ledger_events_event_type", table_name="ledger_events")
        op.drop_index("ix_ledger_events_asset_time", table_name="ledger_events")
        op.drop_index("ix_ledger_events_portfolio_time", table_name="ledger_events")
        op.drop_table("ledger_events")

    inventory_accounting_method_enum.drop(op.get_bind(), checkfirst=True)
    ledger_event_type_enum.drop(op.get_bind(), checkfirst=True)
