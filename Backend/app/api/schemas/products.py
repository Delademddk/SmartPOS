"""Pydantic schemas for products."""

from __future__ import annotations

from datetime import datetime

from pydantic import Field

from app.api.schemas.common import CreateModel, ORMModel, UpdateModel


class ProductRead(ORMModel):
    product_id: int
    sku: str
    barcode: str | None = None
    product_name: str
    description: str | None = None
    category_id: int | None = None
    category_name: str | None = None
    supplier_id: int | None = None
    supplier_name: str | None = None
    unit: str
    unit_price: float
    cost_price: float | None = None
    low_stock_threshold: int
    is_service: bool
    is_active: bool
    quantity_on_hand: int = 0
    stock_status: str | None = None
    created_at: datetime
    updated_at: datetime


class ProductCreate(CreateModel):
    sku: str = Field(..., min_length=1, max_length=50, pattern=r"^[A-Za-z0-9\-_]+$")
    barcode: str | None = Field(default=None, max_length=50)
    product_name: str = Field(..., min_length=1, max_length=200)
    description: str | None = None
    category_id: int | None = None
    supplier_id: int | None = None
    unit: str = Field(default="pcs", max_length=20)
    unit_price: float = Field(..., ge=0)
    cost_price: float | None = Field(default=None, ge=0)
    low_stock_threshold: int = Field(default=10, ge=0)
    is_service: bool = False
    initial_quantity: int = Field(default=0, ge=0)


class ProductUpdate(UpdateModel):
    sku: str | None = Field(default=None, min_length=1, max_length=50, pattern=r"^[A-Za-z0-9\-_]+$")
    barcode: str | None = Field(default=None, max_length=50)
    product_name: str | None = Field(default=None, min_length=1, max_length=200)
    description: str | None = None
    category_id: int | None = None
    supplier_id: int | None = None
    unit: str | None = Field(default=None, max_length=20)
    unit_price: float | None = Field(default=None, ge=0)
    cost_price: float | None = Field(default=None, ge=0)
    low_stock_threshold: int | None = Field(default=None, ge=0)
    is_service: bool | None = None
    is_active: bool | None = None


class PriceUpdate(UpdateModel):
    unit_price: float = Field(..., ge=0)
    cost_price: float | None = Field(default=None, ge=0)


class ProductImageRead(ORMModel):
    image_id: int
    image_url: str
    image_alt: str | None = None
    is_primary: bool
    sort_order: int


class ProductImageCreate(CreateModel):
    image_url: str = Field(..., max_length=500)
    image_alt: str | None = Field(default=None, max_length=200)
    is_primary: bool = False
    sort_order: int = 0
