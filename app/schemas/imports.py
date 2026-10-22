"""Schemas for Excel trade import jobs and response reports."""

from __future__ import annotations

import uuid
from datetime import datetime
from decimal import Decimal
from enum import StrEnum
from typing import Any

from pydantic import BaseModel, ConfigDict, Field
from pydantic import model_validator

from app.models.enums import ImportJobStatus


class ImportRowError(BaseModel):
    """RFC 7807-compatible row-level error payload."""

    model_config = ConfigDict(extra="allow")

    type: str
    title: str
    status: int
    detail: str
    instance: str
    row_number: int | None = None
    row_payload: dict[str, Any] | None = None


class ImportJobRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    user_id: uuid.UUID
    portfolio_id: uuid.UUID
    source_filename: str
    broker_format: str | None
    status: ImportJobStatus
    started_at: datetime | None
    completed_at: datetime | None
    total_rows: int
    parsed_rows: int
    inserted_rows: int
    duplicates_skipped: int
    failed_rows: int
    diagnostics: dict[str, Any] = Field(default_factory=dict)
    created_at: datetime
    updated_at: datetime


class ImportTradesReport(BaseModel):
    """Detailed post-import report consumed by frontend dashboards."""

    job: ImportJobRead | None = None
    import_batch_id: uuid.UUID | None = None
    portfolio_id: uuid.UUID | None = None
    broker: str | None = None
    source_file_name: str | None = None
    file_hash: str | None = None
    imported_at: datetime | None = None
    status: str | None = None
    summary: dict[str, int] = Field(default_factory=dict)
    detected_by_type: dict[str, int] = Field(default_factory=dict)
    row_results: list[dict[str, Any]] = Field(default_factory=list)
    imported: int = Field(default=0, ge=0)
    skipped: int = Field(default=0, ge=0)
    warnings: list[dict[str, Any]] = Field(default_factory=list)
    inserted_count: int = Field(ge=0)
    duplicates_skipped_count: int = Field(ge=0)
    failed_count: int = Field(ge=0)
    errors: list[ImportRowError] = Field(default_factory=list)
    inserted_reference_hashes: list[str] = Field(default_factory=list)
    analysis: dict[str, Decimal | int | str] = Field(default_factory=dict)


class ImportRefreshStatusResponse(BaseModel):
    """Diagnostics payload for post-import refresh/recompute visibility."""

    portfolio_id: uuid.UUID
    last_import_at: datetime | None = None
    last_positions_rebuild_at: datetime | None = None
    last_valuation_rebuild_at: datetime | None = None
    last_analytics_rebuild_at: datetime | None = None
    last_dashboard_updated_at: datetime | None = None
    cache_status: dict[str, str | int | bool | None] = Field(default_factory=dict)
    warnings: list[str] = Field(default_factory=list)


class ImportTargetMode(StrEnum):
    EXISTING = "existing"
    NEW = "new"


class ImportTargetRequest(BaseModel):
    """Explicit import target contract for existing vs new portfolio flows."""

    target_mode: ImportTargetMode = ImportTargetMode.EXISTING
    portfolio_id: uuid.UUID | None = None
    name: str | None = None
    preview_only: bool = False

    @model_validator(mode="after")
    def validate_target(self) -> "ImportTargetRequest":
        if self.preview_only:
            return self

        if self.target_mode == ImportTargetMode.EXISTING and self.portfolio_id is None:
            raise ValueError("portfolio_id is required when target_mode='existing'.")

        if self.target_mode == ImportTargetMode.NEW and not (self.name or "").strip():
            raise ValueError("name is required when target_mode='new'.")

        return self
