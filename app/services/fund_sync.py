"""Application service for idempotent fund and NAV ingestion."""

from __future__ import annotations

import logging
from dataclasses import dataclass, replace
from datetime import UTC, datetime, time
from decimal import Decimal
from typing import TYPE_CHECKING

from app.services.market_provider import FipiranProvider, Fund, FundNav
from app.core.config import settings
from app.services.fund_benchmark import is_fixed_income_fund_type

if TYPE_CHECKING:
    from app.repositories.market_data import MarketDataRepository

logger = logging.getLogger("fund_sync")


@dataclass(slots=True, frozen=True)
class FundSyncReport:
    started_at: datetime
    finished_at: datetime
    status: str
    funds_received: int
    funds_upserted: int
    navs_upserted: int
    benchmark_ticks_upserted: int
    errors_count: int
    error_message: str | None = None


class FundSyncService:
    def __init__(self, *, provider: FipiranProvider, repository: MarketDataRepository) -> None:
        self._provider = provider
        self._repository = repository

    async def run(self) -> FundSyncReport:
        started_at = datetime.now(UTC)
        funds: list[Fund] = []
        navs: list[FundNav] = []
        funds_upserted = 0
        navs_upserted = 0
        benchmark_ticks_upserted = 0
        status = "success"
        error_message: str | None = None
        try:
            funds = self._deduplicate(await self._provider.get_funds())
            normalized_funds: list[Fund] = []
            for fund in funds:
                nav = self._nav_from_fund(fund)
                if nav is None:
                    nav = await self._provider.get_fund_nav(fund.fund_id)
                if nav is not None:
                    navs.append(nav)
                    latest_value = nav.statistical_nav or nav.redemption_nav or nav.subscription_nav
                    if latest_value is not None:
                        fund = replace(fund, nav=latest_value, nav_date=nav.nav_date)
                normalized_funds.append(fund)
            funds = normalized_funds
            if funds:
                funds_upserted = await self._repository.upsert_funds(funds)
                navs_upserted = await self._repository.upsert_fund_navs(navs)
            else:
                status = "unavailable" if self._provider.name.endswith("disabled") else "empty"
            benchmark_ticks_upserted = await self._sync_benchmark_tick(funds, navs)
            if funds_upserted or navs_upserted or benchmark_ticks_upserted:
                await self._repository.commit()
        except Exception as exc:
            status = "error"
            error_message = str(exc)
            try:
                await self._repository.rollback()
            except Exception:
                pass

        finished_at = datetime.now(UTC)
        report = FundSyncReport(
            started_at=started_at,
            finished_at=finished_at,
            status=status,
            funds_received=len(funds),
            funds_upserted=funds_upserted,
            navs_upserted=navs_upserted,
            benchmark_ticks_upserted=benchmark_ticks_upserted,
            errors_count=1 if error_message else 0,
            error_message=error_message,
        )
        try:
            await self._repository.record_ingestion_run(
                source="FIPIRAN",
                provider=self._provider.name,
                run_type="funds_nav",
                started_at=started_at,
                finished_at=finished_at,
                status=status,
                records_received=len(funds),
                records_valid=len(funds),
                records_inserted=funds_upserted + navs_upserted,
                errors_count=report.errors_count,
                last_success_at=finished_at if status == "success" else None,
                error_message=error_message,
                metadata_json={
                    "funds_upserted": funds_upserted,
                    "navs_upserted": navs_upserted,
                    "benchmark_ticks_upserted": benchmark_ticks_upserted,
                },
            )
            await self._repository.commit()
        except Exception as exc:
            logger.warning("fund_sync.ingestion_run_record_failed error=%s", exc)
        return report

    @staticmethod
    def _deduplicate(funds: list[Fund]) -> list[Fund]:
        return list({item.fund_id: item for item in funds}.values())

    @staticmethod
    def _nav_from_fund(fund: Fund) -> FundNav | None:
        if fund.nav is None or fund.nav_date is None:
            return None
        return FundNav(
            fund_id=fund.fund_id,
            nav_date=fund.nav_date,
            statistical_nav=fund.nav,
            source=fund.source,
        )

    async def _sync_benchmark_tick(self, funds: list[Fund], navs: list[FundNav]) -> int:
        mode = settings.RISK_FREE_BENCHMARK_MODE.strip().lower()
        selected_id = settings.RISK_FREE_FUND_ID.strip()
        if mode in {"fund", "fixed_income_fund"} and selected_id:
            fund = next(
                (item for item in funds if item.fund_id == selected_id and is_fixed_income_fund_type(item.type)),
                None,
            )
            nav = max(
                (item for item in navs if item.fund_id == selected_id),
                key=lambda item: item.nav_date,
                default=None,
            )
            value = None if nav is None else nav.statistical_nav or nav.redemption_nav or nav.subscription_nav
            if fund is not None and nav is not None and value is not None and value > 0:
                tick_time = datetime.combine(nav.nav_date, time.min, tzinfo=UTC)
                return await self._repository.upsert_benchmark_tick(
                    benchmark_code="FIXED_INCOME",
                    tick_time=tick_time,
                    value_type="INDEX_LEVEL",
                    price_level=value,
                    annual_rate=None,
                    source=fund.source,
                    idempotency_key=f"fund:{selected_id}:{nav.nav_date.isoformat()}",
                )
            if not settings.RISK_FREE_ALLOW_CONFIGURED_FALLBACK:
                return 0

        rate = Decimal(str(settings.RISK_FREE_ANNUAL_RATE))
        if rate < 0 or rate > 100:
            return 0
        today = datetime.now(UTC).date()
        return await self._repository.upsert_benchmark_tick(
            benchmark_code="BANK_DEPOSIT",
            tick_time=datetime.combine(today, time.min, tzinfo=UTC),
            value_type="ANNUAL_RATE",
            price_level=None,
            annual_rate=rate / Decimal("100"),
            source="CONFIGURATION",
            idempotency_key=f"configured-risk-free:{today.isoformat()}",
        )
