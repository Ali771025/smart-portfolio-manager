"""Read-side repository for benchmark attribution time-series."""

from __future__ import annotations

import uuid
from dataclasses import dataclass
from datetime import date
from decimal import Decimal
from typing import Any

import sqlalchemy as sa
from sqlalchemy import exc as sa_exc
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker

from app.models.enums import BenchmarkType
from app.models.market_data import BenchmarkHistory, PortfolioSnapshot
from app.models.portfolio import Portfolio


_BENCHMARK_HISTORY_FALLBACKS: dict[str, BenchmarkType] = {
    "TOTAL_INDEX": BenchmarkType.TEDPIX,
}


@dataclass(slots=True, frozen=True)
class PortfolioContextRow:
    """Ownership and currency context for an attribution request."""

    portfolio_id: uuid.UUID
    base_currency: str


class BenchmarkingReadRepository:
    """Repository optimized for low-latency benchmark attribution queries."""

    def __init__(self, *, session_factory: async_sessionmaker[AsyncSession]) -> None:
        self.session_factory = session_factory

    @staticmethod
    def _is_missing_relation_error(exc: Exception, relation_name: str) -> bool:
        message = str(exc).lower()
        return (
            "undefinedtableerror" in message
            or f'relation "{relation_name.lower()}" does not exist' in message
        )

    @staticmethod
    def _fallback_benchmark_type_for_code(benchmark_code: str) -> BenchmarkType | None:
        return _BENCHMARK_HISTORY_FALLBACKS.get(benchmark_code.strip().upper())

    async def get_portfolio_context(
        self,
        *,
        portfolio_id: uuid.UUID,
        user_id: uuid.UUID,
    ) -> PortfolioContextRow | None:
        async with self.session_factory() as db:
            result = await db.execute(
                sa.select(Portfolio.id, Portfolio.base_currency)
                .where(
                    Portfolio.id == portfolio_id,
                    Portfolio.user_id == user_id,
                    Portfolio.is_active.is_(True),
                )
                .limit(1)
            )
            row = result.first()
            if row is None:
                return None

            return PortfolioContextRow(
                portfolio_id=row.id,
                base_currency=row.base_currency.value,
            )

    async def fetch_latest_portfolio_date(self, *, portfolio_id: uuid.UUID) -> date | None:
        stmt = sa.text(
            """
            SELECT max(bucket_start)::date AS latest_day
            FROM portfolio_pnl_daily_rollup
            WHERE portfolio_id = :portfolio_id
            """
        )
        async with self.session_factory() as db:
            rollup_latest: date | None = None
            try:
                result = await db.execute(stmt, {"portfolio_id": portfolio_id})
                rollup_latest = result.scalar_one_or_none()
            except sa_exc.ProgrammingError as exc:
                if not self._is_missing_relation_error(exc, "portfolio_pnl_daily_rollup"):
                    raise
                # The failed statement aborts the transaction; clear it before fallback.
                await db.rollback()

            fallback_stmt = (
                sa.select(sa.func.max(PortfolioSnapshot.snapshot_date))
                .where(PortfolioSnapshot.portfolio_id == portfolio_id)
            )
            fallback_result = await db.execute(fallback_stmt)
            snapshot_latest = fallback_result.scalar_one_or_none()
            if rollup_latest is None:
                return snapshot_latest
            if snapshot_latest is None:
                return rollup_latest
            return max(rollup_latest, snapshot_latest)

    async def fetch_portfolio_nav_rows(
        self,
        *,
        portfolio_id: uuid.UUID,
        start_date: date,
        end_date: date,
    ) -> list[dict[str, Any]]:
        stmt = sa.text(
            """
            SELECT
                bucket_start::date AS as_of,
                close_market_value::double precision AS nav
            FROM portfolio_pnl_daily_rollup
            WHERE portfolio_id = :portfolio_id
              AND bucket_start::date >= :start_date
              AND bucket_start::date <= :end_date
            ORDER BY bucket_start::date ASC
            """
        )
        async with self.session_factory() as db:
            rollup_rows: list[dict[str, Any]] = []
            try:
                result = await db.execute(
                    stmt,
                    {
                        "portfolio_id": portfolio_id,
                        "start_date": start_date,
                        "end_date": end_date,
                    },
                )
                rows = result.mappings().all()
                rollup_rows = [
                    {"as_of": row["as_of"], "nav": float(row["nav"] or 0.0)}
                    for row in rows
                ]
            except sa_exc.ProgrammingError as exc:
                if not self._is_missing_relation_error(exc, "portfolio_pnl_daily_rollup"):
                    raise
                # Reset failed transaction before issuing fallback query.
                await db.rollback()

            fallback_stmt = (
                sa.select(
                    PortfolioSnapshot.snapshot_date.label("as_of"),
                    PortfolioSnapshot.total_market_value.label("nav"),
                )
                .where(
                    PortfolioSnapshot.portfolio_id == portfolio_id,
                    PortfolioSnapshot.snapshot_date >= start_date,
                    PortfolioSnapshot.snapshot_date <= end_date,
                )
                .order_by(PortfolioSnapshot.snapshot_date.asc())
            )
            fallback_result = await db.execute(fallback_stmt)
            fallback_rows = fallback_result.mappings().all()
            snapshot_rows = [
                {"as_of": row["as_of"], "nav": float(row["nav"] or 0.0)}
                for row in fallback_rows
            ]
            if not rollup_rows:
                return snapshot_rows
            if not snapshot_rows:
                return rollup_rows

            merged_by_date: dict[date, dict[str, Any]] = {
                row["as_of"]: row for row in rollup_rows
            }
            # Snapshot rows override/extend rollup rows to avoid stale NAV after imports.
            for row in snapshot_rows:
                merged_by_date[row["as_of"]] = row
            return [merged_by_date[key] for key in sorted(merged_by_date)]

    async def fetch_portfolio_cash_flow_rows(
        self,
        *,
        portfolio_id: uuid.UUID,
        start_date: date,
        end_date: date,
    ) -> list[dict[str, Any]]:
        stmt = sa.text(
            """
            SELECT
                date_trunc('day', event_time)::date AS as_of,
                SUM(
                    CASE
                        WHEN event_type = 'CASH_DEPOSIT' THEN net_amount
                        WHEN event_type = 'CASH_WITHDRAWAL' THEN -ABS(net_amount)
                        ELSE 0
                    END
                )::double precision AS cash_flow
            FROM ledger_events
            WHERE portfolio_id = :portfolio_id
              AND event_time::date >= :start_date
              AND event_time::date <= :end_date
              AND event_type IN ('CASH_DEPOSIT', 'CASH_WITHDRAWAL')
            GROUP BY as_of
            ORDER BY as_of ASC
            """
        )
        async with self.session_factory() as db:
            try:
                result = await db.execute(
                    stmt,
                    {
                        "portfolio_id": portfolio_id,
                        "start_date": start_date,
                        "end_date": end_date,
                    },
                )
            except sa_exc.ProgrammingError as exc:
                if self._is_missing_relation_error(exc, "ledger_events"):
                    return []
                raise
            return [
                {"as_of": row["as_of"], "cash_flow": float(row["cash_flow"] or 0.0)}
                for row in result.mappings().all()
            ]

    async def fetch_benchmark_rows(
        self,
        *,
        benchmark_code: str,
        start_date: date,
        end_date: date,
    ) -> list[dict[str, Any]]:
        stmt = sa.text(
            """
            SELECT
                bucket_day::date AS as_of,
                close_price_level,
                close_annual_rate
            FROM benchmark_daily_ohlc
            WHERE benchmark_code = :benchmark_code
              AND bucket_day::date >= :start_date
              AND bucket_day::date <= :end_date
            ORDER BY bucket_day::date ASC
            """
        )
        async with self.session_factory() as db:
            daily_rows: list[dict[str, Any]] = []
            try:
                result = await db.execute(
                    stmt,
                    {
                        "benchmark_code": benchmark_code,
                        "start_date": start_date,
                        "end_date": end_date,
                    },
                )
                daily_rows = result.mappings().all()
            except sa_exc.ProgrammingError as exc:
                if self._is_missing_relation_error(exc, "benchmark_daily_ohlc"):
                    await db.rollback()
                else:
                    raise

            if daily_rows:
                return [
                    {
                        "as_of": row["as_of"],
                        "close_price_level": self._coerce_optional_float(row["close_price_level"]),
                        "close_annual_rate": self._coerce_optional_float(row["close_annual_rate"]),
                    }
                    for row in daily_rows
                ]

            fallback_type = self._fallback_benchmark_type_for_code(benchmark_code)
            if fallback_type is None:
                return []

            fallback_stmt = (
                sa.select(
                    BenchmarkHistory.date.label("as_of"),
                    BenchmarkHistory.adjusted_close.label("close_price_level"),
                )
                .where(
                    BenchmarkHistory.benchmark_type == fallback_type,
                    BenchmarkHistory.date >= start_date,
                    BenchmarkHistory.date <= end_date,
                )
                .order_by(BenchmarkHistory.date.asc())
            )
            fallback_result = await db.execute(fallback_stmt)
            return [
                {
                    "as_of": row["as_of"],
                    "close_price_level": self._coerce_optional_float(row["close_price_level"]),
                    "close_annual_rate": 0.0,
                }
                for row in fallback_result.mappings().all()
            ]

    @staticmethod
    def _coerce_optional_float(value: Any) -> float | None:
        if value is None:
            return None
        return float(value or Decimal("0"))
