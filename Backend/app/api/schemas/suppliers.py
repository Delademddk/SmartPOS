"""Pydantic schemas for suppliers."""

from __future__ import annotations

from datetime import datetime

from pydantic import Field

from app.api.schemas.common import CreateModel, ORMModel, UpdateModel


class SupplierContactRead(ORMModel):
    contact_id: int
    supplier_id: int
    full_name: str
    job_title: str | None = None
    email: str | None = None
    phone: str | None = None
    is_primary: bool
    is_active: bool


class SupplierRead(ORMModel):
    supplier_id: int
    supplier_code: str
    supplier_name: str
    contact_person: str | None = None
    email: str | None = None
    phone: str | None = None
    city: str | None = None
    state: str | None = None
    country: str | None = None
    notes: str | None = None
    is_active: bool
    created_at: datetime
    updated_at: datetime


class SupplierDetail(SupplierRead):
    contacts: list[SupplierContactRead] = []


class SupplierCreate(CreateModel):
    supplier_code: str = Field(..., min_length=1, max_length=30, pattern=r"^[A-Za-z0-9\-_]+$")
    supplier_name: str = Field(..., min_length=1, max_length=150)
    contact_person: str | None = Field(default=None, max_length=150)
    email: str | None = Field(default=None, max_length=255)
    phone: str | None = Field(default=None, max_length=30)
    address_line1: str | None = Field(default=None, max_length=255)
    address_line2: str | None = Field(default=None, max_length=255)
    city: str | None = Field(default=None, max_length=100)
    state: str | None = Field(default=None, max_length=100)
    postal_code: str | None = Field(default=None, max_length=20)
    country: str | None = Field(default=None, max_length=100)
    notes: str | None = None


class SupplierUpdate(UpdateModel):
    supplier_code: str | None = Field(default=None, min_length=1, max_length=30)
    supplier_name: str | None = Field(default=None, min_length=1, max_length=150)
    contact_person: str | None = Field(default=None, max_length=150)
    email: str | None = Field(default=None, max_length=255)
    phone: str | None = Field(default=None, max_length=30)
    address_line1: str | None = Field(default=None, max_length=255)
    address_line2: str | None = Field(default=None, max_length=255)
    city: str | None = Field(default=None, max_length=100)
    state: str | None = Field(default=None, max_length=100)
    postal_code: str | None = Field(default=None, max_length=20)
    country: str | None = Field(default=None, max_length=100)
    notes: str | None = None
    is_active: bool | None = None


class SupplierContactCreate(CreateModel):
    full_name: str = Field(..., min_length=1, max_length=150)
    job_title: str | None = Field(default=None, max_length=100)
    email: str | None = Field(default=None, max_length=255)
    phone: str | None = Field(default=None, max_length=30)
    is_primary: bool = False


class SupplierContactUpdate(UpdateModel):
    full_name: str | None = Field(default=None, min_length=1, max_length=150)
    job_title: str | None = Field(default=None, max_length=100)
    email: str | None = Field(default=None, max_length=255)
    phone: str | None = Field(default=None, max_length=30)
    is_primary: bool | None = None
    is_active: bool | None = None


class SupplierHistoryRead(ORMModel):
    history_id: int
    supplier_id: int
    history_type: str
    description: str | None = None
    changed_by: int | None = None
    changed_at: datetime
