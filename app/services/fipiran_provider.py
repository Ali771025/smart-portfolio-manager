"""Optional Fipiran adapters behind the normalized fund provider protocol."""

from __future__ import annotations

import asyncio
import importlib
import inspect
import logging
from collections.abc import Callable, Mapping
from dataclasses import asdict, is_dataclass
from typing import Any

from app.core.config import settings
from app.services.market_normalizers import FipiranNormalizer
from app.services.market_provider import FipiranProvider, Fund, FundNav, FundReturn

logger = logging.getLogger("fipiran_provider")


def _rows(payload: Any) -> list[Mapping[str, Any]]:
    if payload is None:
        return []
    if hasattr(payload, "to_dict"):
        try:
            payload = payload.to_dict("records")
        except TypeError:
            payload = payload.to_dict()
    if is_dataclass(payload):
        payload = asdict(payload)
    if isinstance(payload, Mapping):
        for key in ("funds", "Funds", "data", "Data", "results", "Results", "items"):
            nested = payload.get(key)
            if isinstance(nested, list):
                payload = nested
                break
        else:
            payload = [payload]
    if not isinstance(payload, (list, tuple)):
        return []
    result: list[Mapping[str, Any]] = []
    for item in payload:
        if is_dataclass(item):
            item = asdict(item)
        elif not isinstance(item, Mapping) and hasattr(item, "__dict__"):
            item = vars(item)
        if isinstance(item, Mapping):
            result.append(item)
    return result


async def _invoke(loader: Callable[..., Any], *args: Any) -> Any:
    if inspect.iscoroutinefunction(loader):
        return await loader(*args)
    result = await asyncio.to_thread(loader, *args)
    return await result if inspect.isawaitable(result) else result


class LibraryFipiranProvider(FipiranProvider):
    """Adapter for an unstable library API supplied through configured callables."""

    def __init__(
        self,
        *,
        funds_loader: Callable[..., Any],
        nav_loader: Callable[..., Any] | None = None,
        returns_loader: Callable[..., Any] | None = None,
        provider_name: str = "fipiran-library",
    ) -> None:
        self._funds_loader = funds_loader
        self._nav_loader = nav_loader
        self._returns_loader = returns_loader
        self._name = provider_name

    @property
    def name(self) -> str:
        return self._name

    async def get_funds(self) -> list[Fund]:
        return [
            fund
            for row in _rows(await _invoke(self._funds_loader))
            if (fund := FipiranNormalizer.fund_from_mapping(row)) is not None
        ]

    async def get_fund_nav(self, fund_id: str) -> FundNav | None:
        if self._nav_loader is not None:
            navs = [
                nav
                for row in _rows(await _invoke(self._nav_loader, fund_id))
                if (nav := FipiranNormalizer.nav_from_mapping(row, fund_id)) is not None
            ]
            return max(navs, key=lambda item: item.nav_date) if navs else None
        fund = next((item for item in await self.get_funds() if item.fund_id == fund_id), None)
        if fund is None or fund.nav is None or fund.nav_date is None:
            return None
        return FundNav(
            fund_id=fund.fund_id,
            nav_date=fund.nav_date,
            statistical_nav=fund.nav,
            source=fund.source,
        )

    async def get_fund_returns(self, fund_id: str, window: str) -> list[FundReturn]:
        if self._returns_loader is not None:
            return [
                FipiranNormalizer.return_from_mapping(row, fund_id, window)
                for row in _rows(await _invoke(self._returns_loader, fund_id, window))
            ]
        fund = next((item for item in await self.get_funds() if item.fund_id == fund_id), None)
        if fund is None:
            return []
        value = {
            "1m": fund.return_1m,
            "3m": fund.return_3m,
            "6m": fund.return_6m,
            "1y": fund.return_1y,
        }.get(window.lower())
        return [FundReturn(fund_id=fund_id, window=window, return_percent=value, as_of_date=fund.nav_date)] if value is not None else []

    async def close(self) -> None:
        return None


class DisabledFipiranProvider(FipiranProvider):
    """Safe fallback when the optional package or configured hooks are unavailable."""

    def __init__(self, reason: str = "Fipiran provider is not configured") -> None:
        self.reason = reason

    @property
    def name(self) -> str:
        return "fipiran-disabled"

    async def get_funds(self) -> list[Fund]:
        return []

    async def get_fund_nav(self, fund_id: str) -> FundNav | None:
        return None

    async def get_fund_returns(self, fund_id: str, window: str) -> list[FundReturn]:
        return []

    async def close(self) -> None:
        return None


def _resolve_callable(module: Any, path: str) -> Callable[..., Any] | None:
    if not path.strip():
        return None
    value = module
    for part in path.split("."):
        value = getattr(value, part)
    if not callable(value):
        raise TypeError(f"Configured Fipiran hook is not callable: {path}")
    return value


def build_fipiran_provider() -> FipiranProvider:
    mode = settings.FIPIRAN_PROVIDER_MODE.strip().lower()
    if mode in {"disabled", "stub", "off"}:
        return DisabledFipiranProvider("FIPIRAN_PROVIDER_MODE disables ingestion")
    try:
        module = importlib.import_module(settings.FIPIRAN_LIBRARY_MODULE)
        funds_loader = _resolve_callable(module, settings.FIPIRAN_FUNDS_CALLABLE)
        if funds_loader is None:
            return DisabledFipiranProvider("FIPIRAN_FUNDS_CALLABLE is not configured")
        return LibraryFipiranProvider(
            funds_loader=funds_loader,
            nav_loader=_resolve_callable(module, settings.FIPIRAN_NAV_CALLABLE),
            returns_loader=_resolve_callable(module, settings.FIPIRAN_RETURNS_CALLABLE),
            provider_name=f"{settings.FIPIRAN_LIBRARY_MODULE}-library",
        )
    except (ImportError, AttributeError, TypeError) as exc:
        logger.warning("Fipiran provider unavailable: %s", exc)
        return DisabledFipiranProvider(str(exc))


class HttpFipiranProvider(DisabledFipiranProvider):
    """Backward-compatible stub; no undocumented HTTP payload is exposed."""

    def __init__(self, base_url: str | None = None, timeout: float | None = None) -> None:
        _ = (base_url, timeout)
        super().__init__(
            "Direct Fipiran HTTP integration is disabled; configure library callable hooks"
        )
