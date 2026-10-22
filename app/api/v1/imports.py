"""Trade import API endpoints for broker Excel ingestion."""

from __future__ import annotations

import logging
import uuid
from datetime import datetime
from typing import Annotated

from fastapi import APIRouter, BackgroundTasks, Depends, File, Form, HTTPException, UploadFile, status
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.deps import CurrentUser
from app.schemas.import_excel import (
    ImportExcelCreateResponse,
    ImportExcelErrorRead,
    ImportExcelErrorsResponse,
    ImportExcelJobRead,
)
from app.schemas.import_pipeline import ParseImportResponse
from app.schemas.imports import ImportJobRead, ImportTargetMode, ImportTargetRequest, ImportTradesReport
from app.schemas.imports import ImportRefreshStatusResponse
from app.models.enums import PortfolioCurrency, PortfolioManagerType
from app.models.asset_position import AssetPosition
from app.models.market_data import PortfolioSnapshot
from app.models.portfolio import Portfolio
from app.models.import_job import ImportJob
from app.services.import_excel_service import (
    ExcelImportService,
    PortfolioOwnershipError as ExcelPortfolioOwnershipError,
)
from app.services.import_pipeline.parser_service import (
    EmptyWorkbookError,
    ExcelImportParserService,
    UnreadableWorkbookError,
    UnsupportedBrokerFormatError,
)
from app.services.import_service import ImportService, PortfolioOwnershipError
from app.services.analytics_service import _portfolio_cache_version_key as analytics_version_key
from app.services.advanced_benchmark_service import PORTFOLIO_VERSION_KEY_PREFIX as benchmark_version_prefix
from app.core.redis import get_redis

router = APIRouter(prefix="/import", tags=["Imports"])
logger = logging.getLogger(__name__)

MAX_IMPORT_FILE_SIZE_BYTES = 10 * 1024 * 1024
ALLOWED_EXCEL_EXTENSIONS = (".xlsx", ".xlsm", ".xls")
ALLOWED_EXCEL_CONTENT_TYPES = {
    "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",  # .xlsx
    "application/vnd.ms-excel.sheet.macroEnabled.12",  # .xlsm
    "application/vnd.ms-excel",  # .xls
}
GENERIC_BINARY_CONTENT_TYPE = "application/octet-stream"


def _parse_portfolio_id_form(value: str | uuid.UUID | None) -> uuid.UUID | None:
    if value is None:
        return None
    if isinstance(value, uuid.UUID):
        return value
    normalized = str(value).strip()
    if not normalized:
        return None
    try:
        return uuid.UUID(normalized)
    except ValueError as ex:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="شناسه پرتفوی معتبر نیست. لطفاً یک پرتفوی معتبر انتخاب کنید.",
        ) from ex


def _parse_import_target_form(
    target_mode: ImportTargetMode = Form(default=ImportTargetMode.EXISTING),
    portfolio_id: str | None = Form(default=None),
    name: str | None = Form(default=None),
    preview_only: bool = Form(default=False),
) -> ImportTargetRequest:
    return ImportTargetRequest(
        target_mode=target_mode,
        portfolio_id=_parse_portfolio_id_form(portfolio_id),
        name=name,
        preview_only=preview_only,
    )


async def _resolve_import_portfolio_id(
    *,
    db: AsyncSession,
    current_user: CurrentUser,
    target: ImportTargetRequest,
) -> uuid.UUID:
    if target.target_mode == ImportTargetMode.EXISTING:
        if target.portfolio_id is None:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="portfolio_id is required when target_mode='existing'.",
            )
        return target.portfolio_id

    portfolio_name = (target.name or "").strip()
    if not portfolio_name:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="name is required when target_mode='new'.",
        )

    duplicate_result = await db.execute(
        select(Portfolio.id).where(
            Portfolio.user_id == current_user.id,
            Portfolio.is_active.is_(True),
            func.lower(Portfolio.name) == portfolio_name.lower(),
        )
    )
    existing_portfolio_id = duplicate_result.scalar_one_or_none()
    if existing_portfolio_id is not None:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=(
                "A portfolio with this name already exists. "
                "Use target_mode='existing' and the existing portfolio_id to append this import batch."
            ),
        )

    portfolio = Portfolio(
        user_id=current_user.id,
        name=portfolio_name,
        description="Created by import flow",
        base_currency=PortfolioCurrency.IRR,
        manager_type=PortfolioManagerType.UNKNOWN,
    )
    db.add(portfolio)
    await db.commit()
    await db.refresh(portfolio)
    return portfolio.id


def _matches_excel_signature(content: bytes, *, filename: str) -> bool:
    lower_name = filename.lower()
    if lower_name.endswith((".xlsx", ".xlsm")):
        return content.startswith(b"PK\x03\x04")
    if lower_name.endswith(".xls"):
        return content.startswith(bytes.fromhex("D0CF11E0A1B11AE1"))
    return False


@router.post(
    "/parse",
    response_model=ParseImportResponse,
)
async def parse_broker_file(
    current_user: CurrentUser,  # noqa: ARG001 - auth guard for import preview
    file: UploadFile = File(...),
) -> ParseImportResponse:
    """Detect broker format via strategy signatures and return normalized rows."""

    if not file.filename:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Uploaded file must have a filename.")
    if not file.filename.lower().endswith(ALLOWED_EXCEL_EXTENSIONS):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Only Excel files (.xlsx, .xlsm, .xls) are supported.",
        )

    content = await file.read()
    if not content:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Uploaded file is empty.")
    if len(content) > MAX_IMPORT_FILE_SIZE_BYTES:
        raise HTTPException(
            status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
            detail="Uploaded file exceeds the 10 MB limit.",
        )
    if (
        file.content_type
        and file.content_type not in ALLOWED_EXCEL_CONTENT_TYPES
        and file.content_type != GENERIC_BINARY_CONTENT_TYPE
    ):
        raise HTTPException(
            status_code=status.HTTP_415_UNSUPPORTED_MEDIA_TYPE,
            detail=f"Unsupported file content type '{file.content_type}'.",
        )
    if not _matches_excel_signature(content, filename=file.filename):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Uploaded file does not match a valid Excel workbook signature.",
        )

    service = ExcelImportParserService()

    try:
        return service.parse(content)
    except UnsupportedBrokerFormatError as ex:
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail=str(ex)) from ex
    except EmptyWorkbookError as ex:
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail=str(ex)) from ex
    except UnreadableWorkbookError as ex:
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail=str(ex)) from ex
    except Exception as ex:  # noqa: BLE001
        logger.exception("Failed to parse uploaded broker file: filename=%s", file.filename)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to parse uploaded file.",
        ) from ex


@router.post(
    "/trades",
    response_model=ImportTradesReport,
    status_code=status.HTTP_201_CREATED,
)
async def import_trade_history(
    current_user: CurrentUser,
    db: Annotated[AsyncSession, Depends(get_db)],
    background_tasks: BackgroundTasks,
    target: Annotated[ImportTargetRequest, Depends(_parse_import_target_form)],
    file: UploadFile = File(...),
) -> ImportTradesReport:
    """Import broker transaction history with reconciliation and idempotency reporting."""
    current_user_id = current_user.id

    if not file.filename:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Uploaded file must have a filename.")
    if not file.filename.lower().endswith(ALLOWED_EXCEL_EXTENSIONS):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Only Excel files (.xlsx, .xlsm, .xls) are supported.",
        )

    content = await file.read()
    if not content:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Uploaded file is empty.")
    if len(content) > MAX_IMPORT_FILE_SIZE_BYTES:
        raise HTTPException(
            status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
            detail="Uploaded file exceeds the 10 MB limit.",
        )
    if (
        file.content_type
        and file.content_type not in ALLOWED_EXCEL_CONTENT_TYPES
        and file.content_type != GENERIC_BINARY_CONTENT_TYPE
    ):
        raise HTTPException(
            status_code=status.HTTP_415_UNSUPPORTED_MEDIA_TYPE,
            detail=f"Unsupported file content type '{file.content_type}'.",
        )
    if not _matches_excel_signature(content, filename=file.filename):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Uploaded file does not match a valid Excel workbook signature.",
        )

    service = ImportService(db)
    if target.preview_only:
        try:
            return await service.preview_trades(
                file_bytes=content,
                source_filename=file.filename,
            )
        except ValueError as ex:
            logger.warning("Trade preview rejected: filename=%s reason=%s", file.filename, ex)
            raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail=str(ex)) from ex
        except Exception as ex:  # noqa: BLE001
            logger.exception("Trade preview failed: filename=%s", file.filename)
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Failed to preview uploaded trades.",
            ) from ex

    portfolio_id = await _resolve_import_portfolio_id(
        db=db,
        current_user=current_user,
        target=target,
    )

    try:
        # Use the deterministic normalized Excel pipeline for trade imports as well,
        # then map its diagnostics into the legacy ImportTradesReport contract.
        excel_service = ExcelImportService(db)
        job = await excel_service.create_import_job(
            user_id=current_user_id,
            portfolio_id=portfolio_id,
            file_bytes=content,
            source_filename=file.filename,
        )
        await excel_service.process_job(job_id=job.id)
        job = await excel_service.get_job(job_id=job.id, user_id=current_user_id)

        diagnostics = job.diagnostics if isinstance(job.diagnostics, dict) else {}
        summary = diagnostics.get("summary", {}) if isinstance(diagnostics.get("summary"), dict) else {}
        row_results = diagnostics.get("row_results", []) if isinstance(diagnostics.get("row_results"), list) else []
        import_warnings = [
            item
            for item in row_results
            if isinstance(item, dict) and item.get("status") in {"warning", "skipped"}
        ]

        import_errors: list[dict[str, object]] = []
        for item in row_results:
            if not isinstance(item, dict) or item.get("status") != "error":
                continue
            row_number = item.get("row_number")
            import_errors.append(
                {
                    "type": "import_row_error",
                    "problem_type": "import_row_error",
                    "title": "Import Row Error",
                    "status": 422,
                    "detail": str(item.get("message") or "Import row failed."),
                    "instance": f"/api/v1/import/jobs/{job.id}/rows/{row_number if isinstance(row_number, int) else 0}",
                    "row_number": row_number if isinstance(row_number, int) else None,
                    "row_payload": item,
                }
            )

        report = ImportTradesReport(
            job=ImportJobRead.model_validate(job),
            import_batch_id=job.id,
            portfolio_id=job.portfolio_id,
            broker=str(diagnostics.get("broker", "") or ""),
            source_file_name=str(diagnostics.get("source_file_name", job.source_filename)),
            file_hash=str(diagnostics.get("file_hash", "") or ""),
            imported_at=job.completed_at,
            status=str(diagnostics.get("status", "") or ""),
            summary={
                "total_rows": int(summary.get("total_rows", 0)),
                "inserted_trades": int(summary.get("inserted_trades", summary.get("inserted_transactions", 0))),
                "inserted_cash_events": int(summary.get("inserted_cash_events", 0)),
                "duplicates_skipped": int(summary.get("duplicates_skipped", summary.get("duplicate_rows", 0))),
                "warning_rows": int(summary.get("warning_rows", 0)),
                "error_rows": int(summary.get("error_rows", 0)),
            },
            detected_by_type=(
                diagnostics.get("detected_by_type", {})
                if isinstance(diagnostics.get("detected_by_type"), dict)
                else {}
            ),
            row_results=row_results,
            imported=int(summary.get("inserted_rows", job.inserted_rows)),
            skipped=int(summary.get("skipped_rows", 0)),
            warnings=import_warnings,
            inserted_count=int(summary.get("inserted_rows", job.inserted_rows)),
            duplicates_skipped_count=int(summary.get("duplicates_skipped", summary.get("duplicate_rows", job.duplicates_skipped))),
            failed_count=int(summary.get("error_rows", job.failed_rows)),
            errors=import_errors,
            inserted_reference_hashes=(
                diagnostics.get("inserted_reference_hashes", [])
                if isinstance(diagnostics.get("inserted_reference_hashes"), list)
                else []
            ),
            analysis={
                "import_batch_id": str(job.id),
                "broker": diagnostics.get("broker", ""),
                "status": str(diagnostics.get("status", "") or ""),
            },
        )

        if job.status == "FAILED" and report.inserted_count == 0:
            first_error = report.errors[0].detail if report.errors else "Unknown error"
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail=f"Import failed: {first_error}",
            )
        return report
    except HTTPException:
        # Preserve explicit API errors (e.g. 422 import failures) without
        # falling through to the generic 500 handler.
        raise
    except ExcelPortfolioOwnershipError as ex:
        logger.info(
            "Trade import denied due to missing/inaccessible portfolio: user_id=%s portfolio_id=%s",
            current_user_id,
            portfolio_id,
        )
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(ex)) from ex
    except PortfolioOwnershipError as ex:
        logger.info(
            "Trade import denied due to missing/inaccessible portfolio: user_id=%s portfolio_id=%s",
            current_user_id,
            portfolio_id,
        )
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(ex)) from ex
    except ValueError as ex:
        logger.warning("Trade import rejected: user_id=%s filename=%s reason=%s", current_user_id, file.filename, ex)
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail=str(ex)) from ex
    except Exception as ex:  # noqa: BLE001
        logger.exception(
            "Trade import failed: user_id=%s portfolio_id=%s filename=%s",
            current_user_id,
            portfolio_id,
            file.filename,
        )
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to import uploaded trades.",
        ) from ex


@router.post(
    "/portfolio-snapshot",
    response_model=ImportTradesReport,
)
async def import_portfolio_snapshot(
    current_user: CurrentUser,
    db: Annotated[AsyncSession, Depends(get_db)],
    target: Annotated[ImportTargetRequest, Depends(_parse_import_target_form)],
    file: UploadFile = File(...),
) -> ImportTradesReport:
    """Import portfolio holdings snapshot as initial balances."""
    current_user_id = current_user.id

    if not file.filename:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Uploaded file must have a filename.")
    if not file.filename.lower().endswith(ALLOWED_EXCEL_EXTENSIONS):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Only Excel files (.xlsx, .xlsm, .xls) are supported.",
        )

    content = await file.read()
    if not content:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Uploaded file is empty.")
    if len(content) > MAX_IMPORT_FILE_SIZE_BYTES:
        raise HTTPException(
            status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
            detail="Uploaded file exceeds the 10 MB limit.",
        )
    if (
        file.content_type
        and file.content_type not in ALLOWED_EXCEL_CONTENT_TYPES
        and file.content_type != GENERIC_BINARY_CONTENT_TYPE
    ):
        raise HTTPException(
            status_code=status.HTTP_415_UNSUPPORTED_MEDIA_TYPE,
            detail=f"Unsupported file content type '{file.content_type}'.",
        )
    if not _matches_excel_signature(content, filename=file.filename):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Uploaded file does not match a valid Excel workbook signature.",
        )

    service = ImportService(db)
    if target.preview_only:
        try:
            return await service.preview_portfolio_snapshot(
                file_bytes=content,
                source_filename=file.filename,
            )
        except ValueError as ex:
            logger.warning("Snapshot preview rejected: filename=%s reason=%s", file.filename, ex)
            raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail=str(ex)) from ex
        except Exception as ex:  # noqa: BLE001
            logger.exception("Snapshot preview failed: filename=%s", file.filename)
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Failed to preview uploaded snapshot.",
            ) from ex

    portfolio_id = await _resolve_import_portfolio_id(
        db=db,
        current_user=current_user,
        target=target,
    )

    try:
        return await service.import_portfolio_snapshot(
            user_id=current_user_id,
            portfolio_id=portfolio_id,
            file_bytes=content,
            source_filename=file.filename,
        )
    except HTTPException:
        raise
    except PortfolioOwnershipError as ex:
        logger.info(
            "Snapshot import denied due to missing/inaccessible portfolio: user_id=%s portfolio_id=%s",
            current_user_id,
            portfolio_id,
        )
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(ex)) from ex
    except ValueError as ex:
        logger.warning("Snapshot import rejected: user_id=%s filename=%s reason=%s", current_user_id, file.filename, ex)
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail=str(ex)) from ex
    except Exception as ex:  # noqa: BLE001
        logger.exception(
            "Snapshot import failed: user_id=%s portfolio_id=%s filename=%s",
            current_user_id,
            portfolio_id,
            file.filename,
        )
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to import uploaded snapshot.",
        ) from ex


@router.post(
    "/excel",
    response_model=ImportExcelCreateResponse,
    status_code=status.HTTP_202_ACCEPTED,
)
async def upload_excel_for_async_import(
    current_user: CurrentUser,
    db: Annotated[AsyncSession, Depends(get_db)],
    background_tasks: BackgroundTasks,
    portfolio_id: str = Form(...),
    file: UploadFile = File(...),
) -> ImportExcelCreateResponse:
    """Upload an Excel file and queue asynchronous broker parsing/import."""
    parsed_portfolio_id = _parse_portfolio_id_form(portfolio_id)
    if parsed_portfolio_id is None:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="انتخاب پرتفوی برای ورود فایل الزامی است.",
        )

    if not file.filename:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Uploaded file must have a filename.")
    if not file.filename.lower().endswith(ALLOWED_EXCEL_EXTENSIONS):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Only Excel files (.xlsx, .xlsm, .xls) are supported.",
        )
    content = await file.read()
    if not content:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Uploaded file is empty.")
    if len(content) > MAX_IMPORT_FILE_SIZE_BYTES:
        raise HTTPException(
            status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
            detail="Uploaded file exceeds the 10 MB limit.",
        )
    if (
        file.content_type
        and file.content_type not in ALLOWED_EXCEL_CONTENT_TYPES
        and file.content_type != GENERIC_BINARY_CONTENT_TYPE
    ):
        raise HTTPException(
            status_code=status.HTTP_415_UNSUPPORTED_MEDIA_TYPE,
            detail=f"Unsupported file content type '{file.content_type}'.",
        )
    if not _matches_excel_signature(content, filename=file.filename):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Uploaded file does not match a valid Excel workbook signature.",
        )

    service = ExcelImportService(db)
    try:
        job = await service.create_import_job(
            user_id=current_user.id,
            portfolio_id=parsed_portfolio_id,
            file_bytes=content,
            source_filename=file.filename,
        )
    except ExcelPortfolioOwnershipError as ex:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(ex)) from ex
    except ValueError as ex:
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail=str(ex)) from ex

    background_tasks.add_task(ExcelImportService.process_job_background, job.id)
    return ImportExcelCreateResponse(job=ImportExcelJobRead.model_validate(job))


@router.get(
    "/{job_id}",
    response_model=ImportExcelJobRead,
)
async def get_excel_import_status(
    job_id: uuid.UUID,
    current_user: CurrentUser,
    db: Annotated[AsyncSession, Depends(get_db)],
) -> ImportExcelJobRead:
    service = ExcelImportService(db)
    try:
        job = await service.get_job(job_id=job_id, user_id=current_user.id)
    except ExcelPortfolioOwnershipError as ex:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(ex)) from ex
    return ImportExcelJobRead.model_validate(job)


@router.get(
    "/{job_id}/result",
    response_model=ImportExcelJobRead,
)
async def get_excel_import_result(
    job_id: uuid.UUID,
    current_user: CurrentUser,
    db: Annotated[AsyncSession, Depends(get_db)],
) -> ImportExcelJobRead:
    """Alias for frontend import result screens."""

    return await get_excel_import_status(
        job_id=job_id,
        current_user=current_user,
        db=db,
    )


@router.get(
    "/{job_id}/errors",
    response_model=ImportExcelErrorsResponse,
)
async def get_excel_import_errors(
    job_id: uuid.UUID,
    current_user: CurrentUser,
    db: Annotated[AsyncSession, Depends(get_db)],
) -> ImportExcelErrorsResponse:
    service = ExcelImportService(db)
    try:
        errors = await service.get_job_errors(job_id=job_id, user_id=current_user.id)
    except ExcelPortfolioOwnershipError as ex:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(ex)) from ex
    return ImportExcelErrorsResponse(
        job_id=job_id,
        errors=[ImportExcelErrorRead.model_validate(item) for item in errors],
    )


@router.get(
    "/portfolios/{portfolio_id}/refresh-status",
    response_model=ImportRefreshStatusResponse,
)
async def get_portfolio_refresh_status(
    portfolio_id: uuid.UUID,
    current_user: CurrentUser,
    db: Annotated[AsyncSession, Depends(get_db)],
) -> ImportRefreshStatusResponse:
    """Return latest import/recompute/cache freshness diagnostics for a portfolio."""

    owned_portfolio_result = await db.execute(
        select(Portfolio.id).where(
            Portfolio.id == portfolio_id,
            Portfolio.user_id == current_user.id,
            Portfolio.is_active.is_(True),
        )
    )
    if owned_portfolio_result.scalar_one_or_none() is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Portfolio not found.")

    latest_job_result = await db.execute(
        select(ImportJob)
        .where(
            ImportJob.user_id == current_user.id,
            ImportJob.portfolio_id == portfolio_id,
        )
        .order_by(ImportJob.created_at.desc())
        .limit(1)
    )
    latest_job = latest_job_result.scalar_one_or_none()

    warnings: list[str] = []
    last_import_at = latest_job.completed_at if latest_job is not None else None
    last_positions_rebuild_at = None
    last_valuation_rebuild_at = None
    last_analytics_rebuild_at = None
    last_dashboard_updated_at = None

    if latest_job is not None:
        diagnostics = latest_job.diagnostics if isinstance(latest_job.diagnostics, dict) else {}
        post_recompute = diagnostics.get("post_import_recompute")
        if isinstance(post_recompute, dict):
            recomputed_at_raw = post_recompute.get("recomputed_at")
            if isinstance(recomputed_at_raw, str):
                parsed = None
                try:
                    parsed = datetime.fromisoformat(recomputed_at_raw.replace("Z", "+00:00"))
                except ValueError:
                    parsed = None
                if parsed is not None:
                    last_positions_rebuild_at = parsed
                    last_valuation_rebuild_at = parsed
                    last_analytics_rebuild_at = parsed
                    last_dashboard_updated_at = parsed
        if latest_job.status.value != "COMPLETED":
            warnings.append("Latest import job is not completed.")
    else:
        warnings.append("No import job found for this portfolio.")

    positions_rebuild_result = await db.execute(
        select(func.max(AssetPosition.last_updated)).where(
            AssetPosition.portfolio_id == portfolio_id,
        )
    )
    latest_position_update = positions_rebuild_result.scalar_one_or_none()
    if last_positions_rebuild_at is None:
        last_positions_rebuild_at = latest_position_update

    valuation_rebuild_result = await db.execute(
        select(func.max(PortfolioSnapshot.updated_at)).where(
            PortfolioSnapshot.portfolio_id == portfolio_id,
        )
    )
    latest_snapshot_update = valuation_rebuild_result.scalar_one_or_none()
    if last_valuation_rebuild_at is None:
        last_valuation_rebuild_at = latest_snapshot_update
    if last_analytics_rebuild_at is None:
        last_analytics_rebuild_at = last_positions_rebuild_at
    if last_dashboard_updated_at is None:
        last_dashboard_updated_at = last_valuation_rebuild_at

    redis_client = get_redis()
    cache_status: dict[str, str | int | bool | None] = {
        "redis_available": redis_client is not None,
        "analytics_cache_version": None,
        "benchmark_cache_version": None,
    }
    if redis_client is not None:
        try:
            analytics_raw = await redis_client.get(analytics_version_key(portfolio_id))
            benchmark_raw = await redis_client.get(f"{benchmark_version_prefix}:{portfolio_id}")
            cache_status["analytics_cache_version"] = (
                analytics_raw.decode("utf-8") if isinstance(analytics_raw, bytes) else analytics_raw
            )
            cache_status["benchmark_cache_version"] = (
                benchmark_raw.decode("utf-8") if isinstance(benchmark_raw, bytes) else benchmark_raw
            )
        except Exception:
            warnings.append("Cache status read failed.")

    if last_import_at is not None and last_positions_rebuild_at is None:
        warnings.append("Import exists but recompute timestamp is missing in diagnostics.")
    if last_import_at is not None and last_valuation_rebuild_at is not None:
        try:
            if last_valuation_rebuild_at < last_import_at:
                warnings.append("Valuation snapshot appears older than the latest import.")
        except TypeError:
            # Mixed aware/naive timestamp flavors can occur across DB drivers.
            pass

    return ImportRefreshStatusResponse(
        portfolio_id=portfolio_id,
        last_import_at=last_import_at,
        last_positions_rebuild_at=last_positions_rebuild_at,
        last_valuation_rebuild_at=last_valuation_rebuild_at,
        last_analytics_rebuild_at=last_analytics_rebuild_at,
        last_dashboard_updated_at=last_dashboard_updated_at,
        cache_status=cache_status,
        warnings=warnings,
    )
