"""Pydantic schemas for categories."""

from __future__ import annotations

from datetime import datetime

from pydantic import Field

from app.api.schemas.common import CreateModel, ORMModel, UpdateModel


class CategoryRead(ORMModel):
    category_id: int
    category_name: str
    parent_id: int | None = None
    description: str | None = None
    sort_order: int
    is_active: bool
    created_at: datetime
    updated_at: datetime
    child_count: int = 0
    product_count: int = 0


class CategoryCreate(CreateModel):
    category_name: str = Field(..., min_length=1, max_length=100)
    parent_id: int | None = None
    description: str | None = Field(default=None, max_length=255)
    sort_order: int = 0


class CategoryUpdate(UpdateModel):
    category_name: str | None = Field(default=None, min_length=1, max_length=100)
    parent_id: int | None = None
    description: str | None = Field(default=None, max_length=255)
    sort_order: int | None = None
    is_active: bool | None = None
