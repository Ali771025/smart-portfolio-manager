"""Application service for external market-data providers.

The service depends only on provider protocols and normalized DTOs. It does
not parse provider-specific payloads or import optional crawler libraries.
"""

from __future__ import annotations

from datetime import date

from app.services.market_provider import (
    CodalDisclosure,
    CodalDisclosureDetail,
    CodalDisclosureFilters,
    CodalProvider,
    FipiranProvider,
    Fund,
    FundNav,
    FundReturn,
    MarketDataProvider,
    MarketQuote,
    PriceBar,
)


class ExternalMarketDataService:
    def __init__(
        self,
        market_provider: MarketDataProvider,
        codal_provider: CodalProvider | None = None,
        fipiran_provider: FipiranProvider | None = None,
    ) -> None:
        self._market_provider = market_provider
        self._codal_provider = codal_provider
        self._fipiran_provider = fipiran_provider

    async def latest_quote(self, symbol_or_instrument_id: str) -> MarketQuote | None:
        return await self._market_provider.get_latest_quote(symbol_or_instrument_id)

    async def daily_prices(
        self,
        instrument_id: str,
        from_date: date,
        to_date: date,
    ) -> list[PriceBar]:
        return await self._market_provider.get_daily_prices(instrument_id, from_date, to_date)

    async def disclosures(self, filters: CodalDisclosureFilters) -> list[CodalDisclosure]:
        if self._codal_provider is None:
            return []
        return await self._codal_provider.get_disclosures(filters)

    async def disclosure_detail(self, tracking_number: str) -> CodalDisclosureDetail | None:
        if self._codal_provider is None:
            return None
        return await self._codal_provider.get_disclosure_detail(tracking_number)

    async def funds(self) -> list[Fund]:
        if self._fipiran_provider is None:
            return []
        return await self._fipiran_provider.get_funds()

    async def fund_nav(self, fund_id: str) -> FundNav | None:
        if self._fipiran_provider is None:
            return None
        return await self._fipiran_provider.get_fund_nav(fund_id)

    async def fund_returns(self, fund_id: str, window: str) -> list[FundReturn]:
        if self._fipiran_provider is None:
            return []
        return await self._fipiran_provider.get_fund_returns(fund_id, window)
