"""ORM models for Module 03 - Business information, currencies, tax rates."""

from __future__ import annotations

from datetime import datetime

from sqlalchemy import (
    Boolean,
    DateTime,
    Integer,
    Numeric,
    SmallInteger,
    Unicode,
)
from sqlalchemy.orm import Mapped, mapped_column

from app.database.base import Base, utcnow


class BusinessInformation(Base):
    __tablename__ = "business_information"

    business_info_id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    business_name: Mapped[str] = mapped_column(Unicode(150), nullable=False)
    legal_name: Mapped[str | None] = mapped_column(Unicode(150), nullable=True)
    tax_id: Mapped[str | None] = mapped_column(Unicode(50), nullable=True)
    address_line1: Mapped[str | None] = mapped_column(Unicode(255), nullable=True)
    address_line2: Mapped[str | None] = mapped_column(Unicode(255), nullable=True)
    city: Mapped[str | None] = mapped_column(Unicode(100), nullable=True)
    state: Mapped[str | None] = mapped_column(Unicode(100), nullable=True)
    postal_code: Mapped[str | None] = mapped_column(Unicode(20), nullable=True)
    country: Mapped[str | None] = mapped_column(Unicode(100), nullable=True)
    phone: Mapped[str | None] = mapped_column(Unicode(30), nullable=True)
    email: Mapped[str | None] = mapped_column(Unicode(255), nullable=True)
    website: Mapped[str | None] = mapped_column(Unicode(255), nullable=True)
    currency_code: Mapped[str] = mapped_column(Unicode(3), nullable=False, default="USD")
    timezone: Mapped[str] = mapped_column(Unicode(100), nullable=False, default="UTC")
    is_active: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, nullable=False, default=utcnow)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime, nullable=False, default=utcnow, onupdate=utcnow
    )
    created_by: Mapped[int | None] = mapped_column(Integer, nullable=True)
    updated_by: Mapped[int | None] = mapped_column(Integer, nullable=True)


class Currency(Base):
    __tablename__ = "currencies"

    currency_id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    currency_code: Mapped[str] = mapped_column(Unicode(3), nullable=False, unique=True)
    currency_name: Mapped[str] = mapped_column(Unicode(100), nullable=False)
    symbol: Mapped[str] = mapped_column(Unicode(10), nullable=False)
    decimal_places: Mapped[int] = mapped_column(SmallInteger, nullable=False, default=2)
    is_base: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    is_active: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, nullable=False, default=utcnow)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime, nullable=False, default=utcnow, onupdate=utcnow
    )


class TaxRate(Base):
    __tablename__ = "tax_rates"

    tax_rate_id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    tax_name: Mapped[str] = mapped_column(Unicode(100), nullable=False)
    tax_code: Mapped[str] = mapped_column(Unicode(20), nullable=False, unique=True)
    rate_percent: Mapped[float] = mapped_column(Numeric(7, 4), nullable=False)
    is_default: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    is_active: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, nullable=False, default=utcnow)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime, nullable=False, default=utcnow, onupdate=utcnow
    )
