"""Authentication business logic: OTP registration, verification, and login."""

from __future__ import annotations

import base64
import hashlib
import hmac
import json
import logging
import secrets
from datetime import timezone, datetime

from cryptography.fernet import Fernet, InvalidToken
from passlib.context import CryptContext
from passlib.exc import UnknownHashError
from redis.asyncio import Redis
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import noload

from app.core.config import settings
from app.core.security import create_access_token, create_refresh_token
from app.models.user import User
from app.schemas.auth import LoginRequest, RegisterInitRequest, TokenResponse, VerifyOTPRequest

logger = logging.getLogger(__name__)

PENDING_REGISTRATION_TTL_SECONDS = 120
OTP_RATE_LIMIT_MAX = 3
OTP_RATE_LIMIT_WINDOW_SECONDS = 3600


class AuthServiceError(Exception):
    """Base class for auth-service domain errors."""


class EmailAlreadyRegisteredError(AuthServiceError):
    pass


class OTPRateLimitExceededError(AuthServiceError):
    def __init__(self, *, retry_after_seconds: int | None = None) -> None:
        self.retry_after_seconds = retry_after_seconds
        if retry_after_seconds and retry_after_seconds > 0:
            message = (
                "OTP request limit reached (3 per hour). "
                f"Try again in {retry_after_seconds} seconds."
            )
        else:
            message = "OTP request limit reached (3 per hour). Try again later."
        super().__init__(message)


class OTPInvalidOrExpiredError(AuthServiceError):
    pass


class InvalidCredentialsError(AuthServiceError):
    pass


class InactiveUserError(AuthServiceError):
    pass


class RedisUnavailableError(AuthServiceError):
    pass


class AuthService:
    """Use-case service for registration and login flows."""

    def __init__(self, *, db: AsyncSession, redis: Redis | None) -> None:
        self._db = db
        self._redis = redis
        self._password_context = CryptContext(
            schemes=["argon2", "pbkdf2_sha256"],
            # Keep legacy PBKDF2 hashes valid without forcing a costly
            # re-hash during login (which can cause request timeouts).
            deprecated="auto",
            argon2__rounds=4,
            argon2__memory_cost=102400,
            argon2__parallelism=8,
        )
        self._fernet = Fernet(self._derive_fernet_key(settings.SECRET_KEY))

    async def register_init(self, payload: RegisterInitRequest) -> str:
        """Generate OTP and cache pending registration in Redis with 2-minute TTL."""

        normalized_email = payload.email.lower()

        if await self._email_exists(normalized_email):
            raise EmailAlreadyRegisteredError("Email is already registered.")

        await self._enforce_otp_rate_limit(normalized_email)

        otp = f"{secrets.randbelow(1_000_000):06d}"
        registration_key = self._registration_key(normalized_email)

        otp_hash = self._hash_otp(normalized_email, otp)
        encrypted_password = self._fernet.encrypt(payload.password.encode("utf-8")).decode("utf-8")

        cached_payload = {
            "email": normalized_email,
            "encrypted_password": encrypted_password,
            "otp_hash": otp_hash,
            "created_at": datetime.now(timezone.utc).isoformat(),
        }

        redis = self._require_redis()
        await redis.setex(
            name=registration_key,
            time=PENDING_REGISTRATION_TTL_SECONDS,
            value=json.dumps(cached_payload),
        )

        return otp

    async def register_verify(self, payload: VerifyOTPRequest) -> TokenResponse:
        """Validate OTP, create user in PostgreSQL, and return JWT pair."""

        normalized_email = payload.email.lower()
        redis = self._require_redis()
        registration_key = self._registration_key(normalized_email)

        raw_cached = await redis.get(registration_key)
        if not raw_cached:
            raise OTPInvalidOrExpiredError("OTP is invalid or expired.")

        try:
            cached_payload = json.loads(raw_cached)
            expected_otp_hash = str(cached_payload["otp_hash"])
            encrypted_password = str(cached_payload["encrypted_password"])
        except (KeyError, TypeError, ValueError, json.JSONDecodeError) as exc:
            await redis.delete(registration_key)
            raise OTPInvalidOrExpiredError("OTP record is corrupted or expired.") from exc

        if not hmac.compare_digest(expected_otp_hash, self._hash_otp(normalized_email, payload.otp)):
            raise OTPInvalidOrExpiredError("OTP is invalid or expired.")

        try:
            plain_password = self._fernet.decrypt(encrypted_password.encode("utf-8")).decode("utf-8")
        except InvalidToken as exc:
            await redis.delete(registration_key)
            raise OTPInvalidOrExpiredError("OTP payload cannot be decrypted.") from exc

        if await self._email_exists(normalized_email):
            await redis.delete(registration_key)
            raise EmailAlreadyRegisteredError("Email is already registered.")

        user = User(
            email=normalized_email,
            hashed_password=self._hash_password(plain_password),
            full_name=self._derive_default_full_name(normalized_email),
            is_verified=True,
        )
        self._db.add(user)

        try:
            await self._db.commit()
        except IntegrityError as exc:
            await self._db.rollback()
            raise EmailAlreadyRegisteredError("Email is already registered.") from exc

        await self._db.refresh(user)
        await redis.delete(registration_key)

        return TokenResponse(
            access_token=create_access_token(user.id),
            refresh_token=create_refresh_token(user.id),
            token_type="bearer",
        )

    async def login(self, payload: LoginRequest) -> TokenResponse:
        """Authenticate user credentials and return JWT pair."""

        normalized_email = payload.email.lower()
        result = await self._db.execute(
            select(User)
            .options(noload("*"))
            .where(User.email == normalized_email)
        )
        user = result.scalar_one_or_none()

        if user is None:
            raise InvalidCredentialsError("Incorrect email or password.")

        try:
            is_valid_password = self._password_context.verify(payload.password, user.hashed_password)
        except (UnknownHashError, ValueError):
            is_valid_password = False

        if not is_valid_password:
            raise InvalidCredentialsError("Incorrect email or password.")

        if not user.is_active:
            raise InactiveUserError("Account is deactivated.")

        if self._password_context.needs_update(user.hashed_password):
            user.hashed_password = self._hash_password(payload.password)
            await self._db.commit()

        return TokenResponse(
            access_token=create_access_token(user.id),
            refresh_token=create_refresh_token(user.id),
            token_type="bearer",
        )

    @staticmethod
    def send_registration_otp_email_mock(*, email: str, otp: str) -> None:
        """Mocked async-email equivalent used by BackgroundTasks/Celery integrations."""

        logger.info("[MOCK EMAIL] Registration OTP for %s: %s", email, otp)

    async def _enforce_otp_rate_limit(self, email: str) -> None:
        redis = self._require_redis()
        rate_key = self._otp_rate_key(email)

        count = await redis.incr(rate_key)
        if count == 1:
            await redis.expire(rate_key, OTP_RATE_LIMIT_WINDOW_SECONDS)

        if count > OTP_RATE_LIMIT_MAX:
            ttl = await redis.ttl(rate_key)
            raise OTPRateLimitExceededError(retry_after_seconds=ttl if ttl > 0 else None)

    async def _email_exists(self, email: str) -> bool:
        result = await self._db.execute(select(User.id).where(User.email == email))
        return result.scalar_one_or_none() is not None

    def _hash_password(self, password: str) -> str:
        return self._password_context.hash(password, scheme="argon2")

    @staticmethod
    def _derive_fernet_key(secret_key: str) -> bytes:
        digest = hashlib.sha256(secret_key.encode("utf-8")).digest()
        return base64.urlsafe_b64encode(digest)

    @staticmethod
    def _derive_default_full_name(email: str) -> str:
        local_part = email.split("@", 1)[0]
        normalized = local_part.replace(".", " ").replace("_", " ").strip()
        if not normalized:
            return "User"
        return " ".join(part.capitalize() for part in normalized.split())

    @staticmethod
    def _registration_key(email: str) -> str:
        return f"auth:register:pending:{hashlib.sha256(email.encode('utf-8')).hexdigest()}"

    @staticmethod
    def _otp_rate_key(email: str) -> str:
        return f"auth:otp:rate:{hashlib.sha256(email.encode('utf-8')).hexdigest()}"

    @staticmethod
    def _hash_otp(email: str, otp: str) -> str:
        message = f"{email}:{otp}".encode("utf-8")
        return hmac.new(
            key=settings.SECRET_KEY.encode("utf-8"),
            msg=message,
            digestmod=hashlib.sha256,
        ).hexdigest()

    def _require_redis(self) -> Redis:
        if self._redis is None:
            raise RedisUnavailableError("Redis is unavailable. Please try again later.")
        return self._redis
