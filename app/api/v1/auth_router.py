"""Auth router with OTP-based registration and JWT login."""

from __future__ import annotations

from typing import Annotated

from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException, Request, status
from pydantic import ValidationError
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.redis import get_redis
from app.schemas.auth import LoginRequest, RegisterInitRequest, TokenResponse, VerifyOTPRequest
from app.services.auth_service import (
    AuthService,
    EmailAlreadyRegisteredError,
    InactiveUserError,
    InvalidCredentialsError,
    OTPInvalidOrExpiredError,
    OTPRateLimitExceededError,
    RedisUnavailableError,
)

router = APIRouter()


def get_auth_service(db: Annotated[AsyncSession, Depends(get_db)]) -> AuthService:
    """Dependency injector for the authentication service."""

    return AuthService(db=db, redis=get_redis())


async def _extract_login_payload(request: Request) -> LoginRequest:
    content_type = request.headers.get("content-type", "").split(";", 1)[0].strip().lower()

    if content_type == "application/json":
        body = await request.json()
        candidate = {
            "email": body.get("email") or body.get("username"),
            "password": body.get("password"),
        }
    elif content_type in {"application/x-www-form-urlencoded", "multipart/form-data"}:
        form_data = await request.form()
        candidate = {
            "email": form_data.get("email") or form_data.get("username"),
            "password": form_data.get("password"),
        }
    else:
        raise HTTPException(
            status_code=status.HTTP_415_UNSUPPORTED_MEDIA_TYPE,
            detail="Unsupported content type for login.",
        )

    try:
        return LoginRequest.model_validate(candidate)
    except ValidationError as exc:
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail=exc.errors()) from exc


@router.post("/register-init", status_code=status.HTTP_202_ACCEPTED)
async def register_init(
    payload: RegisterInitRequest,
    background_tasks: BackgroundTasks,
    auth_service: Annotated[AuthService, Depends(get_auth_service)],
) -> dict[str, str]:
    """Start registration by generating OTP and caching pending data in Redis."""

    try:
        otp = await auth_service.register_init(payload)
    except EmailAlreadyRegisteredError as exc:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=str(exc)) from exc
    except OTPRateLimitExceededError as exc:
        raise HTTPException(status_code=status.HTTP_429_TOO_MANY_REQUESTS, detail=str(exc)) from exc
    except RedisUnavailableError as exc:
        raise HTTPException(status_code=status.HTTP_503_SERVICE_UNAVAILABLE, detail=str(exc)) from exc

    background_tasks.add_task(
        AuthService.send_registration_otp_email_mock,
        email=payload.email,
        otp=otp,
    )

    return {
        "message": "If the email is eligible, a one-time password has been sent. It expires in 2 minutes.",
    }


@router.post(
    "/register-verify",
    response_model=TokenResponse,
    status_code=status.HTTP_201_CREATED,
)
async def register_verify(
    payload: VerifyOTPRequest,
    auth_service: Annotated[AuthService, Depends(get_auth_service)],
) -> TokenResponse:
    """Verify OTP, create user, and issue JWT access+refresh tokens."""

    try:
        return await auth_service.register_verify(payload)
    except EmailAlreadyRegisteredError as exc:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=str(exc)) from exc
    except OTPInvalidOrExpiredError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc
    except RedisUnavailableError as exc:
        raise HTTPException(status_code=status.HTTP_503_SERVICE_UNAVAILABLE, detail=str(exc)) from exc


@router.post("/login", response_model=TokenResponse)
async def login(
    request: Request,
    auth_service: Annotated[AuthService, Depends(get_auth_service)],
) -> TokenResponse:
    """Authenticate by email/password and return JWT access+refresh tokens."""

    payload = await _extract_login_payload(request)

    try:
        return await auth_service.login(payload)
    except InvalidCredentialsError as exc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=str(exc),
            headers={"WWW-Authenticate": "Bearer"},
        ) from exc
    except InactiveUserError as exc:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=str(exc)) from exc
