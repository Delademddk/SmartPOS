"""Pydantic schemas for authentication."""

from __future__ import annotations

from datetime import datetime

from pydantic import Field

from app.api.schemas.common import CreateModel, ORMModel


class LoginRequest(CreateModel):
    username: str = Field(..., min_length=1, max_length=255, description="Username or email")
    password: str = Field(..., min_length=1, max_length=255)


class RefreshRequest(CreateModel):
    refresh_token: str = Field(..., min_length=1)


class TokenResponse(ORMModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    expires_in: int


class UserSummary(ORMModel):
    user_id: int
    username: str
    email: str
    full_name: str
    role_id: int
    role_code: str | None = None
    role_name: str | None = None
    is_active: bool
    must_change_password: bool
    last_login_at: datetime | None = None


class LoginResponse(ORMModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    expires_in: int
    user: UserSummary


class RefreshResponse(ORMModel):
    access_token: str
    token_type: str = "bearer"
    expires_in: int


class LogoutRequest(CreateModel):
    refresh_token: str = Field(..., min_length=1)


class ChangePasswordRequest(CreateModel):
    current_password: str = Field(..., min_length=1)
    new_password: str = Field(..., min_length=8)

from pydantic import EmailStr


class RequestPasswordResetRequest(CreateModel):
    email: EmailStr = Field(..., description="Account email address")


class CompletePasswordResetRequest(CreateModel):
    token: str = Field(..., min_length=1, description="Password reset token")
    new_password: str = Field(..., min_length=8, description="New account password")