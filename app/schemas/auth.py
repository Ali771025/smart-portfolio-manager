"""Authentication request/response schemas (Pydantic v2)."""

from __future__ import annotations

import re

from pydantic import BaseModel, ConfigDict, EmailStr, Field, field_validator, model_validator

PASSWORD_COMPLEXITY_REGEX = re.compile(r"^(?=.*[A-Za-z])(?=.*\d).{8,128}$")
OTP_REGEX = re.compile(r"^\d{6}$")


class AuthSchemaBase(BaseModel):
    """Strict schema base for auth contracts."""

    model_config = ConfigDict(extra="forbid")


class RegisterInitRequest(AuthSchemaBase):
    email: EmailStr
    password: str = Field(min_length=8, max_length=128)
    re_password: str = Field(min_length=8, max_length=128)

    @field_validator("email")
    @classmethod
    def normalize_email(cls, value: EmailStr) -> str:
        return str(value).strip().lower()

    @field_validator("password", "re_password")
    @classmethod
    def validate_password_strength(cls, value: str) -> str:
        if not PASSWORD_COMPLEXITY_REGEX.match(value):
            raise ValueError("Password must be 8-128 chars and include at least one letter and one number.")
        return value

    @model_validator(mode="after")
    def validate_passwords_match(self) -> "RegisterInitRequest":
        if self.password != self.re_password:
            raise ValueError("password and re_password must exactly match.")
        return self


class VerifyOTPRequest(AuthSchemaBase):
    email: EmailStr
    otp: str = Field(min_length=6, max_length=6)

    @field_validator("email")
    @classmethod
    def normalize_email(cls, value: EmailStr) -> str:
        return str(value).strip().lower()

    @field_validator("otp")
    @classmethod
    def validate_otp(cls, value: str) -> str:
        if not OTP_REGEX.match(value):
            raise ValueError("OTP must be exactly 6 digits.")
        return value


class LoginRequest(AuthSchemaBase):
    email: str = Field(min_length=1, max_length=320)
    password: str = Field(min_length=1, max_length=1024)

    @field_validator("email")
    @classmethod
    def normalize_email(cls, value: str) -> str:
        normalized = value.strip().lower()
        if not normalized:
            raise ValueError("email cannot be blank.")
        return normalized


class TokenResponse(AuthSchemaBase):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
