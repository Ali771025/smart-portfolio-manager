"""Schemas for asset resolve/upsert contracts."""

from __future__ import annotations

import uuid

from pydantic import BaseModel, Field, field_validator


class AssetResolveRequest(BaseModel):
    symbol: str = Field(min_length=1, max_length=50)
    market: str = Field(default="TSETMC", min_length=1, max_length=50)
    display_name: str | None = Field(default=None, max_length=255)

    @field_validator("symbol", mode="before")
    @classmethod
    def _normalize_symbol(cls, value: object) -> object:
        if isinstance(value, str):
            return value.strip()
        return value

    @field_validator("market", mode="before")
    @classmethod
    def _normalize_market(cls, value: object) -> object:
        if isinstance(value, str):
            return value.strip().upper()
        return value

    @field_validator("display_name", mode="before")
    @classmethod
    def _normalize_display_name(cls, value: object) -> object:
        if isinstance(value, str):
            cleaned = value.strip()
            return cleaned or None
        return value


class AssetResolveResponse(BaseModel):
    asset_id: uuid.UUID
    symbol: str
    created: bool


class BulkAssetResolveRequest(BaseModel):
    assets: list[AssetResolveRequest] = Field(min_length=1)


class BulkAssetResolveItemResponse(BaseModel):
    asset_id: uuid.UUID
    symbol: str
    market: str
    created: bool


class BulkAssetResolveResponse(BaseModel):
    results: list[BulkAssetResolveItemResponse]

