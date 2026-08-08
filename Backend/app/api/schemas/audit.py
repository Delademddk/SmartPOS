"""Pydantic schemas for audit, activity, security and error logs."""

from __future__ import annotations

from datetime import datetime

from pydantic import BaseModel

from app.api.schemas.common import ORMModel


class AuditLogRead(ORMModel):
    log_id: int
    user_id: int | None = None
    username: str | None = None
    action_type: str
    resource_type: str
    resource_id: str | None = None
    old_values: str | None = None
    new_values: str | None = None
    ip_address: str | None = None
    user_agent: str | None = None
    details: str | None = None
    created_at: datetime


class ActivityLogRead(ORMModel):
    activity_id: int
    user_id: int | None = None
    username: str | None = None
    activity_type: str
    activity_desc: str | None = None
    entity_type: str | None = None
    entity_id: str | None = None
    metadata: str | None = None
    ip_address: str | None = None
    created_at: datetime


class SecurityLogRead(ORMModel):
    security_log_id: int
    user_id: int | None = None
    event_type: str
    username: str | None = None
    ip_address: str | None = None
    user_agent: str | None = None
    message: str | None = None
    created_at: datetime


class ErrorLogRead(ORMModel):
    error_id: int
    user_id: int | None = None
    error_code: str | None = None
    message: str
    source: str | None = None
    http_status: int | None = None
    ip_address: str | None = None
    occurred_at: datetime


class LogQueryParams(BaseModel):
    page: int = 1
    page_size: int = 50
    search: str | None = None
    date_from: datetime | None = None
    date_to: datetime | None = None
