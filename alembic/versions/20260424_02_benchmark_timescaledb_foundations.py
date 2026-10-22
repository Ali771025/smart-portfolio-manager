"""benchmark hypertables and continuous aggregates for attribution

Revision ID: 20260424_02
Revises: 20260424_01
Create Date: 2026-04-24 13:00:00.000000
"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql


# revision identifiers, used by Alembic.
revision = "20260424_02"
down_revision = "20260424_01"
branch_labels = None
depends_on = None


benchmark_value_type_enum = postgresql.ENUM(
    "INDEX_LEVEL",
    "ANNUAL_RATE",
    name="benchmark_value_type_enum",
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
    has_timescaledb = _ensure_timescaledb()

    benchmark_value_type_enum.create(bind=conn, checkfirst=True)

    if not _table_exists("benchmark_ticks"):
        op.create_table(
            "benchmark_ticks",
            sa.Column("benchmark_code", sa.String(length=32), nullable=False),
            sa.Column("tick_time", sa.DateTime(timezone=True), nullable=False),
            sa.Column("sequence_no", sa.BigInteger(), nullable=False, server_default="0"),
            sa.Column("value_type", benchmark_value_type_enum, nullable=False),
            sa.Column("price_level", sa.Numeric(24, 8), nullable=True),
            sa.Column("annual_rate", sa.Numeric(12, 8), nullable=True),
            sa.Column("source", sa.String(length=32), nullable=False, server_default="SYSTEM"),
            sa.Column("ingest_idempotency_key", sa.String(length=128), nullable=True),
            sa.Column("payload", postgresql.JSONB(astext_type=sa.Text()), nullable=True),
            sa.Column(
                "created_at",
                sa.DateTime(timezone=True),
                nullable=False,
                server_default=sa.text("now()"),
            ),
            sa.CheckConstraint(
                "benchmark_code IN ('TOTAL_INDEX', 'EQUAL_WEIGHTED', 'BANK_DEPOSIT', 'FIXED_INCOME')",
                name="ck_benchmark_ticks_supported_codes",
            ),
            sa.CheckConstraint(
                "(price_level IS NOT NULL) <> (annual_rate IS NOT NULL)",
                name="ck_benchmark_ticks_single_value_source",
            ),
            sa.CheckConstraint(
                "price_level IS NULL OR price_level > 0",
                name="ck_benchmark_ticks_price_level_positive",
            ),
            sa.CheckConstraint(
                "annual_rate IS NULL OR (annual_rate >= -0.50 AND annual_rate <= 2.00)",
                name="ck_benchmark_ticks_annual_rate_bounds",
            ),
            sa.CheckConstraint(
                "sequence_no >= 0",
                name="ck_benchmark_ticks_sequence_non_negative",
            ),
            sa.PrimaryKeyConstraint(
                "benchmark_code",
                "tick_time",
                "sequence_no",
                name="pk_benchmark_ticks",
            ),
        )
        op.create_index(
            "ix_benchmark_ticks_tick_time",
            "benchmark_ticks",
            ["tick_time"],
        )
        op.create_index(
            "ix_benchmark_ticks_code_time",
            "benchmark_ticks",
            ["benchmark_code", "tick_time"],
        )

    if not has_timescaledb:
        return

    op.execute(
        """
        SELECT create_hypertable(
            'benchmark_ticks',
            'tick_time',
            partitioning_column => 'benchmark_code',
            number_partitions => 8,
            chunk_time_interval => INTERVAL '14 days',
            if_not_exists => TRUE,
            migrate_data => TRUE
        )
        """
    )

    op.execute(
        """
        ALTER TABLE benchmark_ticks
        SET (
            timescaledb.compress = true,
            timescaledb.compress_segmentby = 'benchmark_code,value_type',
            timescaledb.compress_orderby = 'tick_time DESC'
        )
        """
    )

    op.execute(
        """
        DO $$
        BEGIN
            PERFORM add_compression_policy('benchmark_ticks', INTERVAL '45 days');
        EXCEPTION
            WHEN duplicate_object THEN NULL;
            WHEN feature_not_supported THEN NULL;
            WHEN undefined_function THEN NULL;
        END
        $$;
        """
    )

    if not _matview_exists("benchmark_daily_ohlc"):
        op.execute(
            """
            CREATE MATERIALIZED VIEW benchmark_daily_ohlc
            WITH (timescaledb.continuous) AS
            SELECT
                benchmark_code,
                value_type,
                time_bucket(INTERVAL '1 day', tick_time) AS bucket_day,
                first(COALESCE(price_level, annual_rate), tick_time) AS open_value,
                max(COALESCE(price_level, annual_rate)) AS high_value,
                min(COALESCE(price_level, annual_rate)) AS low_value,
                last(COALESCE(price_level, annual_rate), tick_time) AS close_value,
                last(price_level, tick_time) AS close_price_level,
                last(annual_rate, tick_time) AS close_annual_rate,
                count(*)::bigint AS sample_count
            FROM benchmark_ticks
            GROUP BY benchmark_code, value_type, bucket_day
            WITH NO DATA
            """
        )
    op.execute(
        """
        CREATE INDEX IF NOT EXISTS ix_benchmark_daily_ohlc_code_day
        ON benchmark_daily_ohlc (benchmark_code, bucket_day DESC)
        """
    )

    if not _matview_exists("benchmark_monthly_ohlc"):
        op.execute(
            """
            CREATE MATERIALIZED VIEW benchmark_monthly_ohlc
            WITH (timescaledb.continuous) AS
            SELECT
                benchmark_code,
                value_type,
                time_bucket(INTERVAL '1 month', tick_time) AS bucket_month,
                first(COALESCE(price_level, annual_rate), tick_time) AS open_value,
                max(COALESCE(price_level, annual_rate)) AS high_value,
                min(COALESCE(price_level, annual_rate)) AS low_value,
                last(COALESCE(price_level, annual_rate), tick_time) AS close_value,
                count(*)::bigint AS sample_count
            FROM benchmark_ticks
            GROUP BY benchmark_code, value_type, bucket_month
            WITH NO DATA
            """
        )
    op.execute(
        """
        CREATE INDEX IF NOT EXISTS ix_benchmark_monthly_ohlc_code_month
        ON benchmark_monthly_ohlc (benchmark_code, bucket_month DESC)
        """
    )

    op.execute(
        """
        DO $$
        BEGIN
            PERFORM add_continuous_aggregate_policy(
                'benchmark_daily_ohlc',
                start_offset => INTERVAL '5 years',
                end_offset => INTERVAL '1 day',
                schedule_interval => INTERVAL '15 minutes'
            );
        EXCEPTION
            WHEN duplicate_object THEN NULL;
            WHEN feature_not_supported THEN NULL;
            WHEN undefined_function THEN NULL;
        END
        $$;
        """
    )

    op.execute(
        """
        DO $$
        BEGIN
            PERFORM add_continuous_aggregate_policy(
                'benchmark_monthly_ohlc',
                start_offset => INTERVAL '15 years',
                end_offset => INTERVAL '1 day',
                schedule_interval => INTERVAL '1 hour'
            );
        EXCEPTION
            WHEN duplicate_object THEN NULL;
            WHEN feature_not_supported THEN NULL;
            WHEN undefined_function THEN NULL;
        END
        $$;
        """
    )


def downgrade() -> None:
    op.execute(
        """
        DO $$
        BEGIN
            PERFORM remove_continuous_aggregate_policy('benchmark_daily_ohlc');
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
            PERFORM remove_continuous_aggregate_policy('benchmark_monthly_ohlc');
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
            PERFORM remove_compression_policy('benchmark_ticks');
        EXCEPTION
            WHEN undefined_object THEN NULL;
            WHEN undefined_function THEN NULL;
            WHEN feature_not_supported THEN NULL;
        END
        $$;
        """
    )

    op.execute("DROP MATERIALIZED VIEW IF EXISTS benchmark_daily_ohlc")
    op.execute("DROP MATERIALIZED VIEW IF EXISTS benchmark_monthly_ohlc")

    if _table_exists("benchmark_ticks"):
        op.drop_index("ix_benchmark_ticks_code_time", table_name="benchmark_ticks")
        op.drop_index("ix_benchmark_ticks_tick_time", table_name="benchmark_ticks")
        op.drop_table("benchmark_ticks")

    benchmark_value_type_enum.drop(op.get_bind(), checkfirst=True)
