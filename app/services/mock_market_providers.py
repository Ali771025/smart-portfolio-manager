"""In-memory market-data providers for tests."""

from __future__ import annotations

from datetime import UTC, date, datetime

from app.services.market_provider import (
    ClientTypeBreakdown,
    CodalDisclosure,
    CodalDisclosureDetail,
    CodalDisclosureFilters,
    CodalProvider,
    FipiranProvider,
    Fund,
    FundNav,
    FundReturn,
    IndexSnapshot,
    LiveMarketSnapshot,
    MarketDataProvider,
    MarketIndex,
    MarketOverview,
    MarketInstrument,
    MarketProviderStatus,
    MarketQuote,
    MarketSnapshot,
    OrderBookSnapshot,
    PriceBar,
    ProviderHealth,
    SupervisorMessage,
    SymbolStatus,
)


class MockTSETMCProvider(MarketDataProvider):
    def __init__(
        self,
        *,
        quotes: list[MarketQuote] | None = None,
        instruments: list[MarketInstrument] | None = None,
        daily_prices: dict[str, list[PriceBar]] | None = None,
    ) -> None:
        self._quotes = {quote.instrument_id: quote for quote in quotes or []}
        self._quotes.update({quote.symbol: quote for quote in quotes or []})
        self._instruments = instruments or []
        self._daily_prices = daily_prices or {}

    @property
    def name(self) -> str:
        return "mock-tsetmc"

    async def fetch_live_market_snapshot(self, ins_code: str) -> LiveMarketSnapshot | None:
        quote = self._quotes.get(ins_code)
        if quote is None:
            return None
        return LiveMarketSnapshot(
            ins_code=quote.instrument_id,
            ticker=quote.symbol,
            close_price=quote.closing_price or quote.last_price,
            last_trade_price=quote.last_price or quote.closing_price,
            open_price=quote.first_price or quote.closing_price or quote.last_price,
            high_price=quote.high_price or quote.closing_price or quote.last_price,
            low_price=quote.low_price or quote.closing_price or quote.last_price,
            volume=quote.volume,
            state=quote.status if isinstance(quote.status, InstrumentState) else InstrumentState.UNKNOWN,
            has_corporate_action=False,
            fetched_at=quote.received_at or datetime.now(UTC),
            price_change=quote.price_change,
            price_change_percent=quote.price_change_percent,
        )

    async def get_instruments(self) -> list[MarketInstrument]:
        return list(self._instruments)

    async def get_market_snapshot(self) -> MarketSnapshot:
        quotes = list({quote.instrument_id: quote for quote in self._quotes.values()}.values())
        fetched_at = max((quote.received_at for quote in quotes if quote.received_at), default=datetime.now(UTC))
        return MarketSnapshot(
            provider=self.name,
            fetched_at=fetched_at,
            quotes=quotes,
            instruments_count=len(self._instruments),
        )

    async def get_latest_quote(self, symbol_or_instrument_id: str) -> MarketQuote | None:
        return self._quotes.get(symbol_or_instrument_id)

    async def get_daily_prices(
        self,
        instrument_id: str,
        from_date: date,
        to_date: date,
    ) -> list[PriceBar]:
        return [
            bar for bar in self._daily_prices.get(instrument_id, [])
            if from_date <= bar.date <= to_date
        ]

    async def get_client_types(self, trade_date: date | None = None) -> list[ClientTypeBreakdown]:
        _ = trade_date
        return []

    async def get_order_book(self, instrument_id: str) -> OrderBookSnapshot:
        return OrderBookSnapshot(instrument_id=instrument_id, fetched_at=datetime.now(), levels=[])

    async def get_indices(self) -> list[MarketIndex]:
        return []

    async def get_market_overview(self) -> MarketOverview | None:
        return None

    async def get_symbol_statuses(self) -> list[SymbolStatus]:
        return []

    async def get_supervisor_messages(self) -> list[SupervisorMessage]:
        return []

    async def fetch_symbol_history(
        self,
        ins_code: str,
        start_date: date,
        end_date: date,
    ) -> list[PriceBar]:
        return await self.get_daily_prices(ins_code, start_date, end_date)

    async def fetch_index_snapshot(self, index_code: str) -> IndexSnapshot | None:
        _ = index_code
        return None

    async def healthcheck(self) -> ProviderHealth:
        return ProviderHealth(provider_name=self.name, status=MarketProviderStatus.HEALTHY)

    async def close(self) -> None:
        return None


class MockCodalProvider(CodalProvider):
    def __init__(
        self,
        disclosures: list[CodalDisclosure] | None = None,
        details: dict[str, CodalDisclosureDetail] | None = None,
    ) -> None:
        self._disclosures = disclosures or []
        self._details = details or {}

    @property
    def name(self) -> str:
        return "mock-codal"

    async def get_disclosures(self, filters: CodalDisclosureFilters) -> list[CodalDisclosure]:
        result = self._disclosures
        if filters.symbol:
            result = [item for item in result if item.symbol == filters.symbol]
        return result

    async def get_disclosure_detail(self, tracking_number: str) -> CodalDisclosureDetail | None:
        return self._details.get(tracking_number)

    async def close(self) -> None:
        return None


class MockFipiranProvider(FipiranProvider):
    def __init__(
        self,
        funds: list[Fund] | None = None,
        navs: dict[str, FundNav] | None = None,
        returns: dict[tuple[str, str], list[FundReturn]] | None = None,
    ) -> None:
        self._funds = funds or []
        self._navs = navs or {}
        self._returns = returns or {}

    @property
    def name(self) -> str:
        return "mock-fipiran"

    async def get_funds(self) -> list[Fund]:
        return list(self._funds)

    async def get_fund_nav(self, fund_id: str) -> FundNav | None:
        return self._navs.get(fund_id)

    async def get_fund_returns(self, fund_id: str, window: str) -> list[FundReturn]:
        return list(self._returns.get((fund_id, window), []))

    async def close(self) -> None:
        return None
