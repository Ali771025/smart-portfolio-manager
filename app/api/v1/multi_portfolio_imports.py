"""Multi-portfolio broker-aware import endpoints (preview + confirm + performance)."""

from __future__ import annotations

import uuid
from decimal import Decimal
from typing import Annotated

from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.deps import CurrentUser
from app.models.enums import TransactionType
from app.schemas.multi_portfolio_import import (
    AggregatePerformanceRead,
    ConfirmImportRequest,
    ImportPreviewResponse,
    ImportResultResponse,
    ManagerComparisonRow,
    ManualQuickTransactionRequest,
    PortfolioManagerAssignmentRequest,
    PortfolioPerformanceRead,
)
from app.services.multi_portfolio_import_service import (
    ImportValidationError,
    MultiPortfolioImportService,
    PortfolioOwnershipError,
    PreviewNotFoundError,
    UnsupportedBrokerTemplateError,
)

router = APIRouter(prefix="/imports/multi", tags=["Multi Portfolio Imports"])


@router.post("/preview", response_model=ImportPreviewResponse)
async def preview_import(
    current_user: CurrentUser,
    db: Annotated[AsyncSession, Depends(get_db)],
    portfolio_id: uuid.UUID = Form(...),
    file: UploadFile = File(...),
) -> ImportPreviewResponse:
    if not file.filename:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Uploaded file must have a filename.")

    content = await file.read()
    service = MultiPortfolioImportService(db)
    try:
        return await service.build_preview(
            user_id=current_user.id,
            portfolio_id=portfolio_id,
            file_bytes=content,
            source_filename=file.filename,
        )
    except PortfolioOwnershipError as ex:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(ex)) from ex
    except UnsupportedBrokerTemplateError as ex:
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail=str(ex)) from ex
    except ImportValidationError as ex:
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail=str(ex)) from ex


@router.post("/confirm", response_model=ImportResultResponse)
async def confirm_import(
    payload: ConfirmImportRequest,
    current_user: CurrentUser,
    db: Annotated[AsyncSession, Depends(get_db)],
) -> ImportResultResponse:
    service = MultiPortfolioImportService(db)
    try:
        return await service.confirm_import(
            user_id=current_user.id,
            preview_id=payload.preview_id,
        )
    except PreviewNotFoundError as ex:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="پیش‌نمایش منقضی شده یا یافت نشد. لطفاً دوباره پیش‌نمایش را دریافت کنید.",
        ) from ex
    except ImportValidationError as ex:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=str(ex),
        ) from ex
    except PortfolioOwnershipError as ex:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(ex)) from ex


@router.post("/manual", status_code=status.HTTP_201_CREATED)
async def add_manual_transaction(
    payload: ManualQuickTransactionRequest,
    current_user: CurrentUser,
    db: Annotated[AsyncSession, Depends(get_db)],
) -> dict[str, str]:
    service = MultiPortfolioImportService(db)
    try:
        transaction_type = TransactionType(payload.transaction_type)
        transaction = await service.add_manual_transaction(
            user_id=current_user.id,
            portfolio_id=payload.portfolio_id,
            symbol=payload.symbol,
            transaction_type=transaction_type,
            quantity=Decimal(payload.quantity),
            price=Decimal(payload.price),
            notes=payload.notes,
        )
        return {"transaction_id": str(transaction.id), "status": "created"}
    except PortfolioOwnershipError as ex:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(ex)) from ex


@router.put("/portfolios/{portfolio_id}/manager")
async def assign_portfolio_manager(
    portfolio_id: uuid.UUID,
    payload: PortfolioManagerAssignmentRequest,
    current_user: CurrentUser,
    db: Annotated[AsyncSession, Depends(get_db)],
) -> dict[str, str]:
    service = MultiPortfolioImportService(db)
    try:
        await service.assign_portfolio_manager(
            user_id=current_user.id,
            portfolio_id=portfolio_id,
            manager=payload.manager,
        )
        return {"status": "updated", "manager": payload.manager.value}
    except PortfolioOwnershipError as ex:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(ex)) from ex


@router.get("/performance/portfolio/{portfolio_id}", response_model=PortfolioPerformanceRead)
async def portfolio_performance(
    portfolio_id: uuid.UUID,
    current_user: CurrentUser,
    db: Annotated[AsyncSession, Depends(get_db)],
) -> PortfolioPerformanceRead:
    service = MultiPortfolioImportService(db)
    try:
        payload = await service.get_portfolio_performance(
            user_id=current_user.id,
            portfolio_id=portfolio_id,
        )
        return PortfolioPerformanceRead.model_validate(payload)
    except PortfolioOwnershipError as ex:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(ex)) from ex


@router.get("/performance/aggregate", response_model=AggregatePerformanceRead)
async def aggregate_performance(
    current_user: CurrentUser,
    db: Annotated[AsyncSession, Depends(get_db)],
) -> AggregatePerformanceRead:
    service = MultiPortfolioImportService(db)
    payload = await service.get_aggregate_performance(user_id=current_user.id)
    return AggregatePerformanceRead.model_validate(payload)


@router.get("/performance/managers/compare", response_model=list[ManagerComparisonRow])
async def compare_managers(
    current_user: CurrentUser,
    db: Annotated[AsyncSession, Depends(get_db)],
) -> list[ManagerComparisonRow]:
    service = MultiPortfolioImportService(db)
    payload = await service.compare_managers(user_id=current_user.id)
    return [ManagerComparisonRow.model_validate(row) for row in payload]
