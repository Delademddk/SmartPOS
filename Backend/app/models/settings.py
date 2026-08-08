"""ORM models for Module 15 - Settings."""

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
from sqlalchemy.orm import Mapped, mapped_column

from app.database.base import Base, utcnow


class Setting(Base):
    __tablename__ = "settings"

    setting_id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    setting_key: Mapped[str] = mapped_column(Unicode(100), nullable=False, unique=True)
    setting_value: Mapped[str | None] = mapped_column(Text, nullable=True)
    data_type: Mapped[str] = mapped_column(Unicode(20), nullable=False, default="string")
    category: Mapped[str] = mapped_column(Unicode(50), nullable=False, default="general")
    description: Mapped[str | None] = mapped_column(Unicode(255), nullable=True)
    is_active: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, nullable=False, default=utcnow)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime, nullable=False, default=utcnow, onupdate=utcnow
    )
    created_by: Mapped[int | None] = mapped_column(Integer, nullable=True)
    updated_by: Mapped[int | None] = mapped_column(Integer, nullable=True)


class UserSetting(Base):
    __tablename__ = "user_settings"

    user_setting_id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.user_id"), nullable=False)
    setting_key: Mapped[str] = mapped_column(Unicode(100), nullable=False)
    setting_value: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, nullable=False, default=utcnow)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime, nullable=False, default=utcnow, onupdate=utcnow
    )
