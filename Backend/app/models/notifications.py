"""ORM models for Module 12 - Notifications."""

from __future__ import annotations

from datetime import datetime

from sqlalchemy import (
    Boolean,
    DateTime,
    ForeignKey,
    Integer,
    Text,
    Unicode,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database.base import Base, utcnow


class NotificationType(Base):
    __tablename__ = "notification_types"

    notification_type_id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    type_code: Mapped[str] = mapped_column(Unicode(50), nullable=False, unique=True)
    type_name: Mapped[str] = mapped_column(Unicode(100), nullable=False)
    description: Mapped[str | None] = mapped_column(Unicode(255), nullable=True)
    is_active: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)


class Notification(Base):
    __tablename__ = "notifications"

    notification_id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.user_id"), nullable=False)
    notification_type_id: Mapped[int] = mapped_column(
        ForeignKey("notification_types.notification_type_id"), nullable=False
    )
    title: Mapped[str] = mapped_column(Unicode(150), nullable=False)
    message: Mapped[str] = mapped_column(Text, nullable=False)
    severity: Mapped[str] = mapped_column(Unicode(20), nullable=False, default="INFO")
    entity_type: Mapped[str | None] = mapped_column(Unicode(100), nullable=True)
    entity_id: Mapped[str | None] = mapped_column(Unicode(100), nullable=True)
    is_read: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    read_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    is_dismissed: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    created_at: Mapped[datetime] = mapped_column(DateTime, nullable=False, default=utcnow)

    notification_type = relationship("NotificationType", lazy="joined")

    @property
    def type_code(self) -> str | None:
        return self.notification_type.type_code if self.notification_type else None

    @property
    def type_name(self) -> str | None:
        return self.notification_type.type_name if self.notification_type else None


class NotificationHistory(Base):
    __tablename__ = "notification_history"

    history_id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    notification_id: Mapped[int | None] = mapped_column(
        ForeignKey("notifications.notification_id"), nullable=True
    )
    user_id: Mapped[int] = mapped_column(ForeignKey("users.user_id"), nullable=False)
    notification_type_id: Mapped[int] = mapped_column(
        ForeignKey("notification_types.notification_type_id"), nullable=False
    )
    title: Mapped[str] = mapped_column(Unicode(200), nullable=False)
    message: Mapped[str] = mapped_column(Text, nullable=False)
    delivered_at: Mapped[datetime] = mapped_column(DateTime, nullable=False, default=utcnow)
    status: Mapped[str] = mapped_column(Unicode(20), nullable=False, default="DELIVERED")
