"""Pydantic schemas for users."""

from __future__ import annotations

from datetime import datetime

from pydantic import Field

from app.api.schemas.common import CreateModel, ORMModel, UpdateModel


class UserRead(ORMModel):
    user_id: int
    username: str
    email: str
    full_name: str
    phone: str | None = None
    role_id: int
    role_code: str | None = None
    role_name: str | None = None
    is_active: bool
    is_locked: bool
    must_change_password: bool
    last_login_at: datetime | None = None
    last_login_ip: str | None = None
    created_at: datetime
    updated_at: datetime


class UserCreate(CreateModel):
    username: str = Field(..., min_length=3, max_length=50, pattern=r"^[A-Za-z0-9_]+$")
    email: str = Field(..., max_length=255)
    password: str = Field(..., min_length=8, max_length=255)
    full_name: str = Field(..., min_length=1, max_length=150)
    phone: str | None = Field(default=None, max_length=30)
    role_id: int
    must_change_password: bool = True


class UserUpdate(UpdateModel):
    full_name: str | None = Field(default=None, min_length=1, max_length=150)
    phone: str | None = Field(default=None, max_length=30)
    role_id: int | None = None
    is_active: bool | None = None


class ResetPasswordRequest(CreateModel):
    new_password: str = Field(..., min_length=8, max_length=255)


class RequestPasswordResetRequest(CreateModel):
    email: str = Field(..., max_length=255)


class CompletePasswordResetRequest(CreateModel):
    token: str = Field(..., min_length=1)
    new_password: str = Field(..., min_length=8, max_length=255)


class ProfileUpdate(UpdateModel):
    full_name: str | None = Field(default=None, min_length=1, max_length=150)
    phone: str | None = Field(default=None, max_length=30)
    email: str | None = Field(default=None, max_length=255)
