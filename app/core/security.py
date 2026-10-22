"""
Password hashing (PBKDF2-SHA256) and JWT token lifecycle.

Security invariants:
  - Passwords are NEVER stored or logged in plaintext.
  - JWT payloads contain only the `sub` (user ID) and `exp` claims -
    never roles or PII (those are fetched from DB per request).
  - Token expiry is strictly enforced; clock skew is not tolerated.
"""

import uuid
from datetime import datetime, timedelta, timezone

import jwt
from passlib.context import CryptContext

from app.core.config import get_settings

settings = get_settings()

# -------------------- Password Hashing ----------------------
# Use PBKDF2-SHA256 so hashing works across platforms without a native
# bcrypt backend. This avoids passlib+bcrypt compatibility issues where
# registration can fail with "password cannot be longer than 72 bytes".

pwd_context = CryptContext(
    schemes=["pbkdf2_sha256"],
    deprecated="auto",
    pbkdf2_sha256__rounds=390000,
)


def hash_password(plain_password: str) -> str:
    """Return a PBKDF2-SHA256 hash of the given plaintext password."""
    return pwd_context.hash(plain_password)


def verify_password(plain_password: str, hashed_password: str) -> bool:
    """
    Constant-time comparison of a plaintext password against its
    stored password hash. Returns True on match, False otherwise.
    """
    return pwd_context.verify(plain_password, hashed_password)


# -------------------- JWT Tokens ----------------------------

class TokenError(Exception):
    """Raised when a JWT cannot be decoded or has expired."""
    pass


def create_access_token(
    subject: uuid.UUID,
    expires_delta: timedelta | None = None,
) -> str:
    """
    Encode a JWT access token.

    Args:
        subject: The user's UUID (stored in the `sub` claim as a string).
        expires_delta: Optional custom TTL; defaults to settings value.

    Returns:
        A compact JWS string (header.payload.signature).
    """
    now = datetime.now(timezone.utc)
    expire = now + (
        expires_delta
        if expires_delta is not None
        else timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)
    )

    payload: dict = {
        "sub": str(subject),
        "iat": now,
        "exp": expire,
        "type": "access",
    }
    return jwt.encode(payload, settings.SECRET_KEY, algorithm=settings.ALGORITHM)


def create_refresh_token(subject: uuid.UUID) -> str:
    """
    Encode a long-lived refresh token (stored securely on the client).
    """
    now = datetime.now(timezone.utc)
    expire = now + timedelta(days=settings.REFRESH_TOKEN_EXPIRE_DAYS)

    payload: dict = {
        "sub": str(subject),
        "iat": now,
        "exp": expire,
        "type": "refresh",
    }
    return jwt.encode(payload, settings.SECRET_KEY, algorithm=settings.ALGORITHM)


def decode_access_token(token: str) -> dict:
    """
    Decode and validate a JWT access token.

    Returns:
        The decoded payload dict.

    Raises:
        TokenError: On expiry, invalid signature, or malformed token.
    """
    try:
        payload = jwt.decode(
            token,
            settings.SECRET_KEY,
            algorithms=[settings.ALGORITHM],
            options={"require": ["sub", "exp", "type"]},
        )
        if payload.get("type") != "access":
            raise TokenError("Invalid token type: expected 'access'")
        return payload
    except jwt.ExpiredSignatureError:
        raise TokenError("Access token has expired")
    except jwt.InvalidTokenError as exc:
        raise TokenError(f"Invalid token: {exc}")
