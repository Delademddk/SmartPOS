"""ORM models for Module 16 - Audit, activity, error and security logs."""

from __future__ import annotations

from datetime import datetime

from sqlalchemy import (
    DateTime,
    ForeignKey,
    Integer,
    Text,
    Unicode,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database.base import Base, utcnow


class AuditLog(Base):
    __tablename__ = "audit_logs"

    log_id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    user_id: Mapped[int | None] = mapped_column(ForeignKey("users.user_id"), nullable=True)
    action_type: Mapped[str] = mapped_column(Unicode(50), nullable=False)
    resource_type: Mapped[str] = mapped_column(Unicode(100), nullable=False)
    resource_id: Mapped[str | None] = mapped_column(Unicode(100), nullable=True)
    old_values: Mapped[str | None] = mapped_column(Text, nullable=True)
    new_values: Mapped[str | None] = mapped_column(Text, nullable=True)
    ip_address: Mapped[str | None] = mapped_column(Unicode(45), nullable=True)
    user_agent: Mapped[str | None] = mapped_column(Unicode(255), nullable=True)
    details: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, nullable=False, default=utcnow)

    user = relationship("User", lazy="joined")

    @property
    def username(self) -> str | None:
        return self.user.username if self.user else None


class ActivityLog(Base):
    __tablename__ = "activity_logs"

    activity_id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    user_id: Mapped[int | None] = mapped_column(ForeignKey("users.user_id"), nullable=True)
    activity_type: Mapped[str] = mapped_column(Unicode(100), nullable=False)
    activity_desc: Mapped[str | None] = mapped_column(Unicode(255), nullable=True)
    entity_type: Mapped[str | None] = mapped_column(Unicode(100), nullable=True)
    entity_id: Mapped[str | None] = mapped_column(Unicode(100), nullable=True)
    metadata_json: Mapped[str | None] = mapped_column("metadata", Text, nullable=True)
    ip_address: Mapped[str | None] = mapped_column(Unicode(45), nullable=True)
    user_agent: Mapped[str | None] = mapped_column(Unicode(255), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, nullable=False, default=utcnow)

    user = relationship("User", lazy="joined")

    @property
    def username(self) -> str | None:
        return self.user.username if self.user else None


class ErrorLog(Base):
    __tablename__ = "error_logs"

    error_id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    user_id: Mapped[int | None] = mapped_column(ForeignKey("users.user_id"), nullable=True)
    error_code: Mapped[str | None] = mapped_column(Unicode(50), nullable=True)
    message: Mapped[str] = mapped_column(Text, nullable=False)
    stack_trace: Mapped[str | None] = mapped_column(Text, nullable=True)
    source: Mapped[str | None] = mapped_column(Unicode(200), nullable=True)
    http_status: Mapped[int | None] = mapped_column(Integer, nullable=True)
    ip_address: Mapped[str | None] = mapped_column(Unicode(45), nullable=True)
    occurred_at: Mapped[datetime] = mapped_column(DateTime, nullable=False, default=utcnow)


class SecurityLog(Base):
    __tablename__ = "security_logs"

    security_log_id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    user_id: Mapped[int | None] = mapped_column(ForeignKey("users.user_id"), nullable=True)
    event_type: Mapped[str] = mapped_column(Unicode(50), nullable=False)
    username: Mapped[str | None] = mapped_column(Unicode(50), nullable=True)
    ip_address: Mapped[str | None] = mapped_column(Unicode(45), nullable=True)
    user_agent: Mapped[str | None] = mapped_column(Unicode(255), nullable=True)
    message: Mapped[str | None] = mapped_column(Unicode(255), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, nullable=False, default=utcnow)


class AuditLogArchive(Base):
    __tablename__ = "audit_logs_archive"

    archive_id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    log_id: Mapped[int] = mapped_column(Integer, nullable=False)
    user_id: Mapped[int | None] = mapped_column(Integer, nullable=True)
    action_type: Mapped[str] = mapped_column(Unicode(50), nullable=False)
    resource_type: Mapped[str] = mapped_column(Unicode(100), nullable=False)
    resource_id: Mapped[str | None] = mapped_column(Unicode(100), nullable=True)
    old_values: Mapped[str | None] = mapped_column(Text, nullable=True)
    new_values: Mapped[str | None] = mapped_column(Text, nullable=True)
    ip_address: Mapped[str | None] = mapped_column(Unicode(45), nullable=True)
    user_agent: Mapped[str | None] = mapped_column(Unicode(255), nullable=True)
    details: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, nullable=False)
    archived_at: Mapped[datetime] = mapped_column(DateTime, nullable=False, default=utcnow)
