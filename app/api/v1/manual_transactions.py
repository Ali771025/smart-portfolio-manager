"""Manual transaction write API with polymorphic validation and RFC 7807 errors."""

from __future__ import annotations

from typing import Any, Annotated, cast

from fastapi import APIRouter, Body, Depends, Header, Request, status
from fastapi.responses import JSONResponse
from pydantic import TypeAdapter, ValidationError
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.deps import CurrentUser
from app.schemas.manual_transaction import (
    ManualTransactionCreateRequest,
    ManualTransactionPayload,
    ManualTransactionRead,
    ProblemDetails,
    ValidationFieldError,
)
from app.services.manual_transaction_service import (
    ManualTransactionProblem,
    ManualTransactionService,
)

router = APIRouter()
_payload_adapter: TypeAdapter[ManualTransactionPayload] = TypeAdapter(ManualTransactionCreateRequest)


def _problem_response(problem: ProblemDetails) -> JSONResponse:
    return JSONResponse(
        status_code=problem.status,
        content=problem.model_dump(mode="json"),
        media_type="application/problem+json",
    )


def _format_validation_errors(exc: ValidationError) -> list[ValidationFieldError]:
    errors: list[ValidationFieldError] = []
    for entry in exc.errors():
        path = _loc_to_field(entry.get("loc", ()))
        errors.append(
            ValidationFieldError(
                field=path,
                message=entry.get("msg", "Invalid input"),
            )
        )
    return errors


def _loc_to_field(location: tuple[Any, ...]) -> str:
    tokens: list[str] = []
    for token in location:
        if token in {"body", "payload"}:
            continue
        tokens.append(str(token))
    return ".".join(tokens) if tokens else "body"


@router.post(
    "/manual-transactions",
    response_model=ManualTransactionRead,
    status_code=status.HTTP_201_CREATED,
    responses={
        409: {"model": ProblemDetails, "content": {"application/problem+json": {}}},
        422: {"model": ProblemDetails, "content": {"application/problem+json": {}}},
    },
)
async def create_manual_transaction(
    request: Request,
    current_user: CurrentUser,
    db: Annotated[AsyncSession, Depends(get_db)],
    idempotency_key: Annotated[str, Header(alias="Idempotency-Key", min_length=8, max_length=128)],
    payload: dict[str, Any] = Body(...),
) -> ManualTransactionRead | JSONResponse:
    try:
        command = cast(ManualTransactionPayload, _payload_adapter.validate_python(payload))
    except ValidationError as exc:
        return _problem_response(
            ProblemDetails(
                type="https://smartportfolio.dev/problems/validation-error",
                title="Validation failed",
                status=422,
                detail="Manual transaction payload is invalid.",
                instance=str(request.url.path),
                errors=_format_validation_errors(exc),
            )
        )

    service = ManualTransactionService(db)
    try:
        transaction = await service.process_transaction(
            payload=command,
            user_id=current_user.id,
            idempotency_key=idempotency_key,
        )
    except ManualTransactionProblem as exc:
        return _problem_response(
            ProblemDetails(
                type="https://smartportfolio.dev/problems/manual-transaction-error",
                title=exc.title,
                status=exc.status_code,
                detail=exc.detail,
                instance=str(request.url.path),
                errors=(
                    [ValidationFieldError(**error) for error in exc.errors]
                    if exc.errors
                    else None
                ),
            )
        )

    return ManualTransactionRead.model_validate(transaction)
