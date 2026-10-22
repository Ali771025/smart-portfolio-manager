"""Stable API contracts for normalized Codal disclosures."""

from __future__ import annotations

from datetime import datetime

from pydantic import BaseModel, ConfigDict


class DisclosureResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    tracking_number: str
    symbol: str
    company_name: str | None = None
    title: str
    letter_code: str | None = None
    sent_at: datetime | None = None
    published_at: datetime | None = None
    category: str | None = None
    url: str | None = None
    has_attachment: bool
    source: str


class DisclosureDetailResponse(DisclosureResponse):
    pass
