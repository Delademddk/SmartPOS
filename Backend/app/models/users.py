"""ORM models for Module 02 - Users."""

from __future__ import annotations

from datetime import datetime

from sqlalchemy import (
    Boolean,
    DateTime,
    ForeignKey,
    Integer,
    SmallInteger,
    String,
    Unicode,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database.base import Base, utcnow


class User(Base):
    __tablename__ = "users"

    user_id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    username: Mapped[str] = mapped_column(Unicode(50), nullable=False, unique=True)
    email: Mapped[str] = mapped_column(Unicode(255), nullable=False, unique=True)
    password_hash: Mapped[str] = mapped_column(Unicode(255), nullable=False)
    full_name: Mapped[str] = mapped_column(Unicode(150), nullable=False)
    phone: Mapped[str | None] = mapped_column(Unicode(30), nullable=True)
    role_id: Mapped[int] = mapped_column(ForeignKey("roles.role_id"), nullable=False)
    is_active: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)
    is_locked: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    failed_login_attempts: Mapped[int] = mapped_column(
        SmallInteger, nullable=False, default=0
    )
    must_change_password: Mapped[bool] = mapped_column(
        Boolean, nullable=False, default=False
    )
    last_login_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    last_login_ip: Mapped[str | None] = mapped_column(Unicode(45), nullable=True)
    is_deleted: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    deleted_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    deleted_by: Mapped[int | None] = mapped_column(Integer, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, nullable=False, default=utcnow)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime, nullable=False, default=utcnow, onupdate=utcnow
    )
    created_by: Mapped[int | None] = mapped_column(Integer, nullable=True)
    updated_by: Mapped[int | None] = mapped_column(Integer, nullable=True)

    role = relationship("Role", lazy="joined")

    @property
    def role_code(self) -> str | None:
        return self.role.role_code if self.role else None

    @property
    def role_name(self) -> str | None:
        return self.role.role_name if self.role else None


class UserSession(Base):
    __tablename__ = "user_sessions"

    session_id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.user_id"), nullable=False)
    session_token: Mapped[str] = mapped_column(Unicode(255), nullable=False, unique=True)
    ip_address: Mapped[str | None] = mapped_column(Unicode(45), nullable=True)
    user_agent: Mapped[str | None] = mapped_column(Unicode(255), nullable=True)
    issued_at: Mapped[datetime] = mapped_column(DateTime, nullable=False, default=utcnow)
    expires_at: Mapped[datetime] = mapped_column(DateTime, nullable=False)
    is_revoked: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    revoked_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    revoked_by: Mapped[int | None] = mapped_column(Integer, nullable=True)


class PasswordHistory(Base):
    __tablename__ = "password_history"

    history_id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.user_id"), nullable=False)
    password_hash: Mapped[str] = mapped_column(Unicode(255), nullable=False)
    changed_at: Mapped[datetime] = mapped_column(DateTime, nullable=False, default=utcnow)
    changed_by: Mapped[int | None] = mapped_column(Integer, nullable=True)


class PasswordReset(Base):
    __tablename__ = "password_resets"

    reset_id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.user_id"), nullable=False)
    reset_token: Mapped[str] = mapped_column(Unicode(255), nullable=False, unique=True)
    ip_address: Mapped[str | None] = mapped_column(Unicode(45), nullable=True)
    requested_at: Mapped[datetime] = mapped_column(DateTime, nullable=False, default=utcnow)
    expires_at: Mapped[datetime] = mapped_column(DateTime, nullable=False)
    used_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
