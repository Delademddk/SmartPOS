"""Pydantic schemas for notifications."""

from __future__ import annotations

from datetime import datetime

from pydantic import Field

from app.api.schemas.common import CreateModel, ORMModel


class NotificationRead(ORMModel):
    notification_id: int
    user_id: int
    notification_type_id: int
    type_code: str | None = None
    type_name: str | None = None
    title: str
    message: str
    severity: str
    entity_type: str | None = None
    entity_id: str | None = None
    is_read: bool
    read_at: datetime | None = None
    is_dismissed: bool
    created_at: datetime


class NotificationCreate(CreateModel):
    user_id: int
    notification_type_id: int
    title: str = Field(..., min_length=1, max_length=150)
    message: str = Field(..., min_length=1)
    severity: str = Field(default="INFO", pattern=r"^(INFO|WARNING|CRITICAL)$")
    entity_type: str | None = Field(default=None, max_length=100)
    entity_id: str | None = Field(default=None, max_length=100)


class NotificationTypeRead(ORMModel):
    notification_type_id: int
    type_code: str
    type_name: str
    description: str | None = None
    is_active: bool
