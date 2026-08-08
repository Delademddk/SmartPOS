"""Pydantic schemas for business information, currencies and tax rates."""

from __future__ import annotations

from datetime import datetime

from pydantic import Field

from app.api.schemas.common import CreateModel, ORMModel, UpdateModel


class BusinessInfoRead(ORMModel):
    business_info_id: int
    business_name: str
    legal_name: str | None = None
    tax_id: str | None = None
    address_line1: str | None = None
    address_line2: str | None = None
    city: str | None = None
    state: str | None = None
    postal_code: str | None = None
    country: str | None = None
    phone: str | None = None
    email: str | None = None
    website: str | None = None
    currency_code: str
    timezone: str
    is_active: bool
    updated_at: datetime


class BusinessInfoUpdate(UpdateModel):
    business_name: str | None = Field(default=None, min_length=1, max_length=150)
    legal_name: str | None = Field(default=None, max_length=150)
    tax_id: str | None = Field(default=None, max_length=50)
    address_line1: str | None = Field(default=None, max_length=255)
    address_line2: str | None = Field(default=None, max_length=255)
    city: str | None = Field(default=None, max_length=100)
    state: str | None = Field(default=None, max_length=100)
    postal_code: str | None = Field(default=None, max_length=20)
    country: str | None = Field(default=None, max_length=100)
    phone: str | None = Field(default=None, max_length=30)
    email: str | None = Field(default=None, max_length=255)
    website: str | None = Field(default=None, max_length=255)
    currency_code: str | None = Field(default=None, min_length=3, max_length=3)
    timezone: str | None = Field(default=None, max_length=100)


class CurrencyRead(ORMModel):
    currency_id: int
    currency_code: str
    currency_name: str
    symbol: str
    decimal_places: int
    is_base: bool
    is_active: bool


class TaxRateRead(ORMModel):
    tax_rate_id: int
    tax_name: str
    tax_code: str
    rate_percent: float
    is_default: bool
    is_active: bool


class TaxRateCreate(CreateModel):
    tax_name: str = Field(..., min_length=1, max_length=100)
    tax_code: str = Field(..., min_length=1, max_length=20)
    rate_percent: float = Field(..., ge=0, le=100)
    is_default: bool = False


class TaxRateUpdate(UpdateModel):
    tax_name: str | None = Field(default=None, min_length=1, max_length=100)
    tax_code: str | None = Field(default=None, min_length=1, max_length=20)
    rate_percent: float | None = Field(default=None, ge=0, le=100)
    is_default: bool | None = None
    is_active: bool | None = None
