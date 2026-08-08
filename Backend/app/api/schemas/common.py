"""Common Pydantic schemas used across the API."""

from __future__ import annotations

from typing import Any, Generic, TypeVar

from pydantic import BaseModel, ConfigDict, Field

T = TypeVar("T")


class ORMModel(BaseModel):
    """Base schema with ORM-mode serialisation enabled."""

    model_config = ConfigDict(from_attributes=True)


class CreateModel(BaseModel):
    """Base schema for create payloads: reject unknown fields."""

    model_config = ConfigDict(extra="forbid")


class UpdateModel(BaseModel):
    """Base schema for update payloads: all fields optional."""

    model_config = ConfigDict(extra="forbid")


class Envelope(BaseModel, Generic[T]):
    success: bool = True
    data: T | None = None
    meta: dict[str, Any] | None = None


class Message(BaseModel):
    message: str


class PaginationParams(BaseModel):
    page: int = Field(default=1, ge=1)
    page_size: int = Field(default=50, ge=1, le=200)
