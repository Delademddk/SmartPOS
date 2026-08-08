"""Common ORM mixins shared across models."""

from __future__ import annotations

from datetime import datetime

from sqlalchemy import Boolean, DateTime, Integer
from sqlalchemy.orm import Mapped, mapped_column

from app.database.base import utcnow


class TimestampMixin:
    """created_at / updated_at columns (UTC)."""

    created_at: Mapped[datetime] = mapped_column(
        DateTime, nullable=False, default=utcnow
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime, nullable=False, default=utcnow, onupdate=utcnow
    )


class AuditableMixin:
    """created_by / updated_by actor columns."""

    created_by: Mapped[int | None] = mapped_column(Integer, nullable=True)
    updated_by: Mapped[int | None] = mapped_column(Integer, nullable=True)


class SoftDeleteMixin:
    """is_deleted / deleted_at / deleted_by soft-delete columns."""

    is_deleted: Mapped[bool] = mapped_column(
        Boolean, nullable=False, default=False
    )
    deleted_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    deleted_by: Mapped[int | None] = mapped_column(Integer, nullable=True)
