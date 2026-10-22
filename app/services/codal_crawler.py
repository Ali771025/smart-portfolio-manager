"""Crawler orchestration for normalized Codal disclosures."""

from __future__ import annotations

import logging
from dataclasses import dataclass
from datetime import UTC, datetime
from typing import TYPE_CHECKING

from app.core import market_cache
from app.core.config import settings
from app.services.market_provider import CodalDisclosure, CodalDisclosureFilters, CodalProvider

if TYPE_CHECKING:
    from app.repositories.market_data import MarketDataRepository

logger = logging.getLogger("codal_crawler")


@dataclass(slots=True, frozen=True)
class CodalCrawlerReport:
    started_at: datetime
    finished_at: datetime
    status: str
    records_received: int
    records_valid: int
    records_upserted: int
    errors_count: int
    error_message: str | None = None


class CodalCrawler:
    def __init__(self, *, provider: CodalProvider, repository: MarketDataRepository) -> None:
        self._provider = provider
        self._repository = repository

    async def run(self, filters: CodalDisclosureFilters | None = None) -> CodalCrawlerReport:
        started_at = datetime.now(UTC)
        received = 0
        valid: list[CodalDisclosure] = []
        upserted = 0
        status = "success"
        error_message: str | None = None

        try:
            requested = filters or CodalDisclosureFilters(
                page=1,
                page_size=settings.CODAL_CRAWLER_PAGE_SIZE,
            )
            rows = await self._provider.get_disclosures(requested)
            received = len(rows)
            valid = self._validate(rows)
            if valid:
                upserted = await self._repository.upsert_disclosures(valid)
                await self._repository.commit()
                await market_cache.cache_disclosures(valid[: settings.CODAL_CACHE_LIMIT])
            else:
                status = "empty"
        except Exception as exc:
            status = "error"
            error_message = str(exc)
            try:
                await self._repository.rollback()
            except Exception:
                pass

        finished_at = datetime.now(UTC)
        report = CodalCrawlerReport(
            started_at=started_at,
            finished_at=finished_at,
            status=status,
            records_received=received,
            records_valid=len(valid),
            records_upserted=upserted,
            errors_count=1 if error_message else 0,
            error_message=error_message,
        )
        try:
            await self._repository.record_ingestion_run(
                source="CODAL",
                provider=self._provider.name,
                run_type="disclosures",
                started_at=started_at,
                finished_at=finished_at,
                status=status,
                records_received=received,
                records_valid=len(valid),
                records_inserted=upserted,
                errors_count=report.errors_count,
                last_success_at=finished_at if status == "success" else None,
                error_message=error_message,
                metadata_json={"page_size": settings.CODAL_CRAWLER_PAGE_SIZE},
            )
            await self._repository.commit()
        except Exception as exc:
            logger.warning("codal.ingestion_run_record_failed error=%s", exc)

        logger.info(
            "codal.complete status=%s received=%d valid=%d upserted=%d errors=%d",
            status,
            received,
            len(valid),
            upserted,
            report.errors_count,
        )
        return report

    @staticmethod
    def _validate(rows: list[CodalDisclosure]) -> list[CodalDisclosure]:
        by_tracking_number: dict[str, CodalDisclosure] = {}
        for item in rows:
            if not item.tracking_number.strip() or not item.symbol.strip() or not item.title.strip():
                continue
            by_tracking_number[item.tracking_number] = item
        return sorted(
            by_tracking_number.values(),
            key=lambda item: item.published_at or item.sent_at or datetime.min.replace(tzinfo=UTC),
            reverse=True,
        )
