"""ORM models for Module 01 - Authentication (RBAC)."""

from __future__ import annotations

from datetime import datetime

from sqlalchemy import (
    Boolean,
    DateTime,
    ForeignKey,
    Integer,
    String,
    UniqueConstraint,
    Unicode,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database.base import Base, utcnow


class Role(Base):
    __tablename__ = "roles"

    role_id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    role_code: Mapped[str] = mapped_column(Unicode(50), nullable=False, unique=True)
    role_name: Mapped[str] = mapped_column(Unicode(100), nullable=False)
    description: Mapped[str | None] = mapped_column(Unicode(255), nullable=True)
    is_system: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    is_active: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, nullable=False, default=utcnow)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime, nullable=False, default=utcnow, onupdate=utcnow
    )
    created_by: Mapped[int | None] = mapped_column(Integer, nullable=True)
    updated_by: Mapped[int | None] = mapped_column(Integer, nullable=True)

    permissions: Mapped[list["Permission"]] = relationship(
        secondary="role_permissions", back_populates="roles"
    )


class Permission(Base):
    __tablename__ = "permissions"

    permission_id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    permission_code: Mapped[str] = mapped_column(Unicode(100), nullable=False, unique=True)
    permission_name: Mapped[str] = mapped_column(Unicode(150), nullable=False)
    description: Mapped[str | None] = mapped_column(Unicode(255), nullable=True)
    module_name: Mapped[str] = mapped_column(Unicode(100), nullable=False)
    is_system: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    is_active: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, nullable=False, default=utcnow)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime, nullable=False, default=utcnow, onupdate=utcnow
    )
    created_by: Mapped[int | None] = mapped_column(Integer, nullable=True)
    updated_by: Mapped[int | None] = mapped_column(Integer, nullable=True)

    roles: Mapped[list["Role"]] = relationship(
        secondary="role_permissions", back_populates="permissions"
    )


class RolePermission(Base):
    __tablename__ = "role_permissions"
    __table_args__ = (
        UniqueConstraint("role_id", "permission_id", name="uq_role_permissions_role_permission"),
    )

    role_permission_id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    role_id: Mapped[int] = mapped_column(ForeignKey("roles.role_id"), nullable=False)
    permission_id: Mapped[int] = mapped_column(ForeignKey("permissions.permission_id"), nullable=False)
    granted_by: Mapped[int | None] = mapped_column(Integer, nullable=True)
    granted_at: Mapped[datetime] = mapped_column(DateTime, nullable=False, default=utcnow)
