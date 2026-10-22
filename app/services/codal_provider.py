"""Codal JSON provider behind the normalized provider boundary."""

from __future__ import annotations

from typing import Any

import httpx

from app.core.config import settings
from app.services.market_normalizers import CodalNormalizer
from app.services.market_provider import (
    CodalDisclosure,
    CodalDisclosureDetail,
    CodalDisclosureFilters,
    CodalProvider,
)


class HttpCodalProvider(CodalProvider):
    """HTTP Codal provider that returns normalized disclosure DTOs only."""

    def __init__(
        self,
        base_url: str | None = None,
        search_path: str | None = None,
        timeout: float | None = None,
    ) -> None:
        self._base_url = (base_url or settings.CODAL_BASE_URL).rstrip("/")
        self._search_path = search_path or settings.CODAL_SEARCH_PATH
        self._timeout = timeout or settings.CODAL_REQUEST_TIMEOUT
        self._client: httpx.AsyncClient | None = None

    @property
    def name(self) -> str:
        return "codal"

    async def _get_client(self) -> httpx.AsyncClient:
        if self._client is None:
            self._client = httpx.AsyncClient(base_url=self._base_url, timeout=self._timeout)
        return self._client

    async def get_disclosures(
        self,
        filters: CodalDisclosureFilters,
    ) -> list[CodalDisclosure]:
        """Fetch Codal's JSON search service and return normalized letters."""
        client = await self._get_client()
        params: dict[str, str | int] = {
            "PageNumber": max(filters.page, 1),
            "PageSize": min(max(filters.page_size, 1), 200),
        }
        if filters.symbol:
            params["Symbol"] = filters.symbol.strip()
        if filters.category:
            params["LetterType"] = filters.category.strip()
        if filters.from_date:
            params["FromDate"] = filters.from_date.isoformat()
        if filters.to_date:
            params["ToDate"] = filters.to_date.isoformat()

        response = await client.get(self._search_path, params=params)
        response.raise_for_status()
        rows = self._extract_rows(response.json())
        return [
            disclosure
            for row in rows
            if (disclosure := CodalNormalizer.disclosure_from_mapping(row)) is not None
        ]

    async def get_disclosure_detail(
        self,
        tracking_number: str,
    ) -> CodalDisclosureDetail | None:
        client = await self._get_client()
        response = await client.get(
            self._search_path,
            params={"TracingNo": tracking_number, "PageNumber": 1, "PageSize": 10},
        )
        response.raise_for_status()
        for row in self._extract_rows(response.json()):
            normalized = CodalNormalizer.detail_from_mapping(row)
            if normalized and normalized.tracking_number == tracking_number:
                return normalized
        return None

    @staticmethod
    def _extract_rows(payload: Any) -> list[dict[str, Any]]:
        if isinstance(payload, list):
            return [row for row in payload if isinstance(row, dict)]
        if not isinstance(payload, dict):
            return []
        for key in ("Letters", "letters", "Results", "results", "Data", "data"):
            rows = payload.get(key)
            if isinstance(rows, list):
                return [row for row in rows if isinstance(row, dict)]
        return []

    async def close(self) -> None:
        if self._client is not None:
            await self._client.aclose()
            self._client = None
