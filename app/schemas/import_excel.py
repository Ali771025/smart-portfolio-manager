"""Schemas for asynchronous Excel import jobs and error reporting."""

from __future__ import annotations

import uuid
from datetime import datetime
from typing import Any

from pydantic import BaseModel, ConfigDict, Field

from app.models.enums import ImportJobStatus


class ImportExcelErrorRead(BaseModel):
    row_number: int | None = None
    raw_text: str = ""
    error_reason: str
    type: str | None = None
    symbol: str | None = None
    asset_id: str | None = None
    quantity: str | None = None
    price: str | None = None
    amount: str | None = None
    normalized_description: str | None = None
    suggestion: str | None = None


class ImportExcelJobRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    user_id: uuid.UUID
    portfolio_id: uuid.UUID
    source_filename: str
    broker_format: str | None = None
    status: ImportJobStatus
    total_rows: int = 0
    parsed_rows: int = 0
    inserted_rows: int = 0
    duplicates_skipped: int = 0
    failed_rows: int = 0
    started_at: datetime | None = None
    completed_at: datetime | None = None
    created_at: datetime
    updated_at: datetime
    diagnostics: dict[str, Any] = Field(default_factory=dict)


class ImportExcelCreateResponse(BaseModel):
    job: ImportExcelJobRead


class ImportExcelErrorsResponse(BaseModel):
    job_id: uuid.UUID
    errors: list[ImportExcelErrorRead] = Field(default_factory=list)
