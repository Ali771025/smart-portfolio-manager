"""Add normalized market data ingestion tables.

Revision ID: 20260619_01
Revises: 20260618_01
Create Date: 2026-06-19
"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql


revision = "20260619_01"
down_revision = "20260618_01"
branch_labels = None
depends_on = None


def _table_names() -> set[str]:
    return set(sa.inspect(op.get_bind()).get_table_names())


def _column_names(table_name: str) -> set[str]:
    inspector = sa.inspect(op.get_bind())
    return {col["name"] for col in inspector.get_columns(table_name)}


def _constraint_names(table_name: str) -> set[str]:
    inspector = sa.inspect(op.get_bind())
    names = {item["name"] for item in inspector.get_unique_constraints(table_name)}
    names.update(item["name"] for item in inspector.get_check_constraints(table_name))
    return {name for name in names if name}


def _index_names(table_name: str) -> set[str]:
    return {
        item["name"]
        for item in sa.inspect(op.get_bind()).get_indexes(table_name)
        if item["name"]
    }


def _timestamps() -> list[sa.Column]:
    return [
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
    ]


def _uuid_pk() -> sa.Column:
    return sa.Column("id", postgresql.UUID(as_uuid=True), nullable=False)


def _create_index_if_missing(name: str, table: str, columns: list[str]) -> None:
    if name not in _index_names(table):
        op.create_index(name, table, columns)


def upgrade() -> None:
    tables = _table_names()

    daily_columns = _column_names("daily_prices")
    if "instrument_id" not in daily_columns:
        op.add_column("daily_prices", sa.Column("instrument_id", sa.String(length=64), nullable=True))
    if "yesterday_price" not in daily_columns:
        op.add_column("daily_prices", sa.Column("yesterday_price", sa.Numeric(24, 8), nullable=True))
    if "value" not in daily_columns:
        op.add_column("daily_prices", sa.Column("value", sa.Numeric(24, 8), nullable=True))
    if "trade_count" not in daily_columns:
        op.add_column("daily_prices", sa.Column("trade_count", sa.BigInteger(), nullable=False, server_default="0"))
        op.alter_column("daily_prices", "trade_count", server_default=None)
    if "source" not in daily_columns:
        op.add_column("daily_prices", sa.Column("source", sa.String(length=64), nullable=False, server_default="UNKNOWN"))
        op.alter_column("daily_prices", "source", server_default=None)

    op.alter_column("daily_prices", "asset_id", nullable=True)
    for col in ("open_price", "high_price", "low_price", "close_price", "last_trade_price", "adjusted_close"):
        if col in _column_names("daily_prices"):
            op.alter_column("daily_prices", col, nullable=True)

    constraints = _constraint_names("daily_prices")
    if "uq_daily_price_instrument_date" not in constraints:
        op.create_unique_constraint(
            "uq_daily_price_instrument_date",
            "daily_prices",
            ["instrument_id", "date"],
        )
    _create_index_if_missing(
        "ix_daily_price_instrument_date_desc",
        "daily_prices",
        ["instrument_id", "date"],
    )

    if "instruments" not in tables:
        op.create_table(
            "instruments",
            _uuid_pk(),
            sa.Column("ins_code", sa.String(length=64), nullable=True),
            sa.Column("instrument_id", sa.String(length=64), nullable=False),
            sa.Column("isin", sa.String(length=32), nullable=True),
            sa.Column("symbol", sa.String(length=64), nullable=False),
            sa.Column("company_name", sa.String(length=512), nullable=True),
            sa.Column("market", sa.String(length=64), nullable=True),
            sa.Column("board", sa.String(length=64), nullable=True),
            sa.Column("sector_code", sa.String(length=64), nullable=True),
            sa.Column("sector_name", sa.String(length=256), nullable=True),
            sa.Column("instrument_type", sa.String(length=64), nullable=True),
            sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.text("true")),
            *_timestamps(),
            sa.PrimaryKeyConstraint("id"),
            sa.UniqueConstraint("instrument_id", name="uq_instruments_instrument_id"),
            sa.UniqueConstraint("ins_code", name="uq_instruments_ins_code"),
        )
        op.create_index("ix_instruments_symbol", "instruments", ["symbol"])
        op.create_index("ix_instruments_active_market", "instruments", ["is_active", "market"])

    if "market_quotes" not in tables:
        op.create_table(
            "market_quotes",
            _uuid_pk(),
            sa.Column("instrument_id", sa.String(length=64), nullable=False),
            sa.Column("symbol", sa.String(length=64), nullable=False),
            sa.Column("trade_date", sa.Date(), nullable=True),
            sa.Column("event_time", sa.DateTime(timezone=True), nullable=False),
            sa.Column("first_price", sa.Numeric(24, 8), nullable=True),
            sa.Column("last_price", sa.Numeric(24, 8), nullable=True),
            sa.Column("closing_price", sa.Numeric(24, 8), nullable=True),
            sa.Column("yesterday_price", sa.Numeric(24, 8), nullable=True),
            sa.Column("high_price", sa.Numeric(24, 8), nullable=True),
            sa.Column("low_price", sa.Numeric(24, 8), nullable=True),
            sa.Column("trade_count", sa.BigInteger(), nullable=False, server_default="0"),
            sa.Column("volume", sa.BigInteger(), nullable=False, server_default="0"),
            sa.Column("value", sa.Numeric(24, 8), nullable=True),
            sa.Column("buy_count", sa.BigInteger(), nullable=True),
            sa.Column("sell_count", sa.BigInteger(), nullable=True),
            sa.Column("status", sa.String(length=64), nullable=True),
            sa.Column("received_at", sa.DateTime(timezone=True), nullable=True),
            sa.Column("source", sa.String(length=64), nullable=False, server_default="TSETMC"),
            *_timestamps(),
            sa.PrimaryKeyConstraint("id"),
            sa.UniqueConstraint("instrument_id", "event_time", name="uq_market_quote_instrument_event"),
            sa.CheckConstraint("closing_price IS NULL OR closing_price >= 0", name="ck_market_quote_closing_non_negative"),
            sa.CheckConstraint("last_price IS NULL OR last_price >= 0", name="ck_market_quote_last_non_negative"),
            sa.CheckConstraint("volume >= 0", name="ck_market_quote_volume_non_negative"),
            sa.CheckConstraint("value IS NULL OR value >= 0", name="ck_market_quote_value_non_negative"),
            sa.CheckConstraint("trade_count >= 0", name="ck_market_quote_trade_count_non_negative"),
        )
        op.create_index("ix_market_quote_instrument_event_desc", "market_quotes", ["instrument_id", "event_time"])
        op.create_index("ix_market_quote_symbol_event_desc", "market_quotes", ["symbol", "event_time"])

    if "client_types" not in tables:
        op.create_table(
            "client_types",
            _uuid_pk(),
            sa.Column("instrument_id", sa.String(length=64), nullable=False),
            sa.Column("trade_date", sa.Date(), nullable=False),
            sa.Column("individual_buy_count", sa.BigInteger(), nullable=False, server_default="0"),
            sa.Column("individual_buy_volume", sa.BigInteger(), nullable=False, server_default="0"),
            sa.Column("individual_sell_count", sa.BigInteger(), nullable=False, server_default="0"),
            sa.Column("individual_sell_volume", sa.BigInteger(), nullable=False, server_default="0"),
            sa.Column("legal_buy_count", sa.BigInteger(), nullable=False, server_default="0"),
            sa.Column("legal_buy_volume", sa.BigInteger(), nullable=False, server_default="0"),
            sa.Column("legal_sell_count", sa.BigInteger(), nullable=False, server_default="0"),
            sa.Column("legal_sell_volume", sa.BigInteger(), nullable=False, server_default="0"),
            *_timestamps(),
            sa.PrimaryKeyConstraint("id"),
            sa.UniqueConstraint("instrument_id", "trade_date", name="uq_client_type_instrument_date"),
        )
        op.create_index("ix_client_type_instrument_date", "client_types", ["instrument_id", "trade_date"])

    if "order_book" not in tables:
        op.create_table(
            "order_book",
            _uuid_pk(),
            sa.Column("instrument_id", sa.String(length=64), nullable=False),
            sa.Column("event_time", sa.DateTime(timezone=True), nullable=False),
            sa.Column("level", sa.Integer(), nullable=False),
            sa.Column("buy_price", sa.Numeric(24, 8), nullable=True),
            sa.Column("buy_volume", sa.BigInteger(), nullable=True),
            sa.Column("buy_count", sa.BigInteger(), nullable=True),
            sa.Column("sell_price", sa.Numeric(24, 8), nullable=True),
            sa.Column("sell_volume", sa.BigInteger(), nullable=True),
            sa.Column("sell_count", sa.BigInteger(), nullable=True),
            *_timestamps(),
            sa.PrimaryKeyConstraint("id"),
            sa.UniqueConstraint("instrument_id", "event_time", "level", name="uq_order_book_instrument_event_level"),
        )
        op.create_index("ix_order_book_instrument_event", "order_book", ["instrument_id", "event_time"])

    if "market_indices" not in tables:
        op.create_table(
            "market_indices",
            _uuid_pk(),
            sa.Column("index_code", sa.String(length=64), nullable=False),
            sa.Column("name", sa.String(length=256), nullable=False),
            sa.Column("value", sa.Numeric(24, 8), nullable=False),
            sa.Column("change", sa.Numeric(24, 8), nullable=True),
            sa.Column("change_percent", sa.Numeric(18, 8), nullable=True),
            sa.Column("event_time", sa.DateTime(timezone=True), nullable=False),
            sa.Column("source", sa.String(length=64), nullable=False, server_default="TSETMC"),
            *_timestamps(),
            sa.PrimaryKeyConstraint("id"),
            sa.UniqueConstraint("index_code", "event_time", name="uq_market_index_code_event"),
        )
        op.create_index("ix_market_index_code_event_desc", "market_indices", ["index_code", "event_time"])

    if "disclosures" not in tables:
        op.create_table(
            "disclosures",
            _uuid_pk(),
            sa.Column("tracking_number", sa.String(length=128), nullable=False),
            sa.Column("symbol", sa.String(length=64), nullable=False),
            sa.Column("company_name", sa.String(length=512), nullable=True),
            sa.Column("title", sa.Text(), nullable=False),
            sa.Column("letter_code", sa.String(length=128), nullable=True),
            sa.Column("sent_at", sa.DateTime(timezone=True), nullable=True),
            sa.Column("published_at", sa.DateTime(timezone=True), nullable=True),
            sa.Column("category", sa.String(length=128), nullable=True),
            sa.Column("url", sa.Text(), nullable=True),
            sa.Column("has_attachment", sa.Boolean(), nullable=False, server_default=sa.text("false")),
            sa.Column("source", sa.String(length=64), nullable=False, server_default="CODAL"),
            *_timestamps(),
            sa.PrimaryKeyConstraint("id"),
            sa.UniqueConstraint("tracking_number", name="uq_disclosure_tracking_number"),
        )
        op.create_index("ix_disclosure_symbol_published", "disclosures", ["symbol", "published_at"])

    if "funds" not in tables:
        op.create_table(
            "funds",
            _uuid_pk(),
            sa.Column("fund_id", sa.String(length=128), nullable=False),
            sa.Column("name", sa.String(length=512), nullable=False),
            sa.Column("type", sa.String(length=128), nullable=True),
            sa.Column("nav", sa.Numeric(24, 8), nullable=True),
            sa.Column("nav_date", sa.Date(), nullable=True),
            sa.Column("return_1m", sa.Numeric(18, 8), nullable=True),
            sa.Column("return_3m", sa.Numeric(18, 8), nullable=True),
            sa.Column("return_6m", sa.Numeric(18, 8), nullable=True),
            sa.Column("return_1y", sa.Numeric(18, 8), nullable=True),
            sa.Column("source", sa.String(length=64), nullable=False, server_default="FIPIRAN"),
            *_timestamps(),
            sa.PrimaryKeyConstraint("id"),
            sa.UniqueConstraint("fund_id", name="uq_funds_fund_id"),
        )
        op.create_index("ix_funds_name", "funds", ["name"])

    if "ingestion_runs" not in tables:
        op.create_table(
            "ingestion_runs",
            _uuid_pk(),
            sa.Column("source", sa.String(length=64), nullable=False),
            sa.Column("provider", sa.String(length=64), nullable=True),
            sa.Column("run_type", sa.String(length=64), nullable=False),
            sa.Column("started_at", sa.DateTime(timezone=True), nullable=False),
            sa.Column("finished_at", sa.DateTime(timezone=True), nullable=True),
            sa.Column("status", sa.String(length=32), nullable=False, server_default="running"),
            sa.Column("records_received", sa.BigInteger(), nullable=False, server_default="0"),
            sa.Column("records_valid", sa.BigInteger(), nullable=False, server_default="0"),
            sa.Column("records_inserted", sa.BigInteger(), nullable=False, server_default="0"),
            sa.Column("records_updated", sa.BigInteger(), nullable=False, server_default="0"),
            sa.Column("errors_count", sa.BigInteger(), nullable=False, server_default="0"),
            sa.Column("last_success_at", sa.DateTime(timezone=True), nullable=True),
            sa.Column("records_seen", sa.BigInteger(), nullable=False, server_default="0"),
            sa.Column("records_upserted", sa.BigInteger(), nullable=False, server_default="0"),
            sa.Column("records_failed", sa.BigInteger(), nullable=False, server_default="0"),
            sa.Column("error_message", sa.Text(), nullable=True),
            sa.Column("metadata_json", postgresql.JSONB(), nullable=True),
            *_timestamps(),
            sa.PrimaryKeyConstraint("id"),
        )
        op.create_index("ix_ingestion_runs_source_started", "ingestion_runs", ["source", "started_at"])
        op.create_index("ix_ingestion_runs_status", "ingestion_runs", ["status"])


def downgrade() -> None:
    for table in (
        "ingestion_runs",
        "funds",
        "disclosures",
        "market_indices",
        "order_book",
        "client_types",
        "market_quotes",
        "instruments",
    ):
        if table in _table_names():
            op.drop_table(table)

    constraints = _constraint_names("daily_prices")
    if "uq_daily_price_instrument_date" in constraints:
        op.drop_constraint("uq_daily_price_instrument_date", "daily_prices", type_="unique")
    if "ix_daily_price_instrument_date_desc" in _index_names("daily_prices"):
        op.drop_index("ix_daily_price_instrument_date_desc", table_name="daily_prices")
    for column in ("source", "trade_count", "value", "yesterday_price", "instrument_id"):
        if column in _column_names("daily_prices"):
            op.drop_column("daily_prices", column)
