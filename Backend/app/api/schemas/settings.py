"""Pydantic schemas for application settings."""

from __future__ import annotations

from datetime import datetime

from pydantic import Field

from app.api.schemas.common import CreateModel, ORMModel, UpdateModel


class SettingRead(ORMModel):
    setting_id: int
    setting_key: str
    setting_value: str | None = None
    data_type: str
    category: str
    description: str | None = None
    is_active: bool
    updated_at: datetime


class SettingCreate(CreateModel):
    setting_key: str = Field(..., min_length=1, max_length=100)
    setting_value: str | None = None
    data_type: str = Field(default="string", pattern=r"^(string|int|decimal|bool|json)$")
    category: str = Field(default="general", max_length=50)
    description: str | None = Field(default=None, max_length=255)


class SettingUpdate(UpdateModel):
    setting_value: str | None = None
    data_type: str | None = Field(
        default=None, pattern=r"^(string|int|decimal|bool|json)$"
    )
    category: str | None = Field(default=None, max_length=50)
    description: str | None = Field(default=None, max_length=255)
    is_active: bool | None = None


class CurrencyUpdate(UpdateModel):
    """Request body for changing the global application currency."""

    currency_code: str = Field(..., min_length=3, max_length=3)


class UserSettingRead(ORMModel):
    user_setting_id: int
    user_id: int
    setting_key: str
    setting_value: str | None = None
