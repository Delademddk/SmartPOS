"""Pydantic schemas for roles and permissions."""

from __future__ import annotations

from datetime import datetime

from pydantic import Field

from app.api.schemas.common import CreateModel, ORMModel, UpdateModel


class PermissionRead(ORMModel):
    permission_id: int
    permission_code: str
    permission_name: str
    description: str | None = None
    module_name: str
    is_system: bool
    is_active: bool


class RoleRead(ORMModel):
    role_id: int
    role_code: str
    role_name: str
    description: str | None = None
    is_system: bool
    is_active: bool
    created_at: datetime
    updated_at: datetime


class RoleWithPermissions(RoleRead):
    permissions: list[PermissionRead] = []


class RoleCreate(CreateModel):
    role_code: str = Field(..., min_length=1, max_length=50, pattern=r"^[A-Z_]+$")
    role_name: str = Field(..., min_length=1, max_length=100)
    description: str | None = Field(default=None, max_length=255)


class RoleUpdate(UpdateModel):
    role_name: str | None = Field(default=None, min_length=1, max_length=100)
    description: str | None = Field(default=None, max_length=255)
    is_active: bool | None = None


class AssignPermissionsRequest(CreateModel):
    permission_ids: list[int] = Field(..., min_length=1)
