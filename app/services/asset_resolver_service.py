"""Shared asset resolve/upsert service for import pipelines and APIs."""

from __future__ import annotations

from dataclasses import dataclass
from datetime import UTC, datetime
from decimal import Decimal

from sqlalchemy import func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.asset import Asset
from app.models.enums import AssetType
from app.services.import_pipeline.normalization import normalize_symbol

ZERO = Decimal("0")


@dataclass(slots=True, frozen=True)
class AssetResolveInput:
    symbol: str
    market: str = "TSETMC"
    display_name: str | None = None


@dataclass(slots=True, frozen=True)
class AssetResolveResult:
    asset: Asset
    created: bool


class AssetResolverService:
    def __init__(self, db: AsyncSession) -> None:
        self.db = db

    async def resolve_one(self, payload: AssetResolveInput) -> AssetResolveResult:
        normalized = self._normalize_input(payload)
        asset = await self._find_asset(
            symbol=normalized.symbol,
            market=normalized.market,
        )
        if asset is not None:
            return AssetResolveResult(asset=asset, created=False)

        asset = Asset(
            ticker_symbol=normalized.symbol,
            normalized_symbol=normalized.symbol,
            name_fa=normalized.display_name or normalized.symbol,
            name_en=normalized.display_name or normalized.symbol,
            asset_type=AssetType.STOCK,
            exchange=normalized.market,
            isin=None,
            tsetmc_id=None,
            display_metadata=None,
            current_price=ZERO,
            previous_close_price=ZERO,
            price_updated_at=datetime.now(UTC),
            is_active=True,
            is_tradeable=True,
        )
        try:
            async with self.db.begin_nested():
                self.db.add(asset)
                await self.db.flush()
                return AssetResolveResult(asset=asset, created=True)
        except IntegrityError:
            existing = await self._find_asset(
                symbol=normalized.symbol,
                market=normalized.market,
            )
            if existing is None:
                raise
            return AssetResolveResult(asset=existing, created=False)

    async def resolve_symbol(
        self,
        *,
        symbol_raw: str,
        symbol_normalized: str | None = None,
        market: str = "TSETMC",
        display_name: str | None = None,
        allow_create: bool = True,
    ) -> AssetResolveResult:
        """Resolve/create asset from import rows using raw + normalized symbol inputs."""

        normalized_key = normalize_symbol(symbol_normalized or symbol_raw)
        if not normalized_key:
            raise ValueError("Asset symbol is required.")
        existing = await self._find_asset(symbol=normalized_key, market=market.strip().upper() or "TSETMC")
        if existing is not None:
            return AssetResolveResult(asset=existing, created=False)
        if not allow_create:
            raise LookupError(f"Asset symbol '{symbol_raw}' is not mapped.")
        payload = AssetResolveInput(
            symbol=normalized_key,
            market=market,
            display_name=(display_name or symbol_raw or normalized_key),
        )
        return await self.resolve_one(payload)

    async def resolve_bulk(
        self,
        payloads: list[AssetResolveInput],
    ) -> dict[tuple[str, str], AssetResolveResult]:
        normalized_payloads = [self._normalize_input(payload) for payload in payloads]
        if not normalized_payloads:
            return {}

        unique_pairs = {(payload.symbol, payload.market) for payload in normalized_payloads}
        symbols = sorted({symbol for symbol, _ in unique_pairs})
        markets = sorted({market for _, market in unique_pairs})

        existing_result = await self.db.execute(
            select(Asset).where(
                func.upper(Asset.normalized_symbol).in_(symbols),
                func.upper(Asset.exchange).in_(markets),
            )
        )
        existing_assets = list(existing_result.scalars().all())
        by_pair: dict[tuple[str, str], AssetResolveResult] = {
            (asset.normalized_symbol.strip().upper(), asset.exchange.strip().upper()): AssetResolveResult(
                asset=asset,
                created=False,
            )
            for asset in existing_assets
        }

        missing_payloads: list[AssetResolveInput] = []
        for payload in normalized_payloads:
            key = (payload.symbol, payload.market)
            if key not in by_pair:
                missing_payloads.append(payload)

        for payload in missing_payloads:
            key = (payload.symbol, payload.market)
            if key in by_pair:
                continue
            created = await self.resolve_one(payload)
            by_pair[key] = created

        return by_pair

    async def _find_asset(self, *, symbol: str, market: str) -> Asset | None:
        result = await self.db.execute(
            select(Asset).where(
                func.upper(Asset.normalized_symbol) == symbol,
                func.upper(Asset.exchange) == market,
            )
        )
        return result.scalar_one_or_none()

    @staticmethod
    def _normalize_input(payload: AssetResolveInput) -> AssetResolveInput:
        normalized_symbol = normalize_symbol(payload.symbol)
        if not normalized_symbol:
            raise ValueError("Asset symbol is required.")
        normalized_market = payload.market.strip().upper() or "TSETMC"
        display_name = payload.display_name.strip() if payload.display_name else None
        if display_name == "":
            display_name = None
        return AssetResolveInput(
            symbol=normalized_symbol,
            market=normalized_market,
            display_name=display_name,
        )
