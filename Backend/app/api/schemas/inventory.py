"""Pydantic schemas for inventory."""

from __future__ import annotations

from datetime import datetime

from pydantic import Field

from app.api.schemas.common import CreateModel, ORMModel


class InventoryRead(ORMModel):
    inventory_id: int
    product_id: int
    sku: str | None = None
    product_name: str | None = None
    quantity_on_hand: int
    quantity_reserved: int
    available_quantity: int = 0
    reorder_level: int | None = None
    low_stock_threshold: int | None = None
    stock_status: str | None = None
    last_restocked_at: datetime | None = None
    last_sold_at: datetime | None = None
    updated_at: datetime


class RestockRequest(CreateModel):
    product_id: int
    quantity: int = Field(..., gt=0)
    unit_cost: float | None = Field(default=None, ge=0)
    reason: str | None = Field(default=None, max_length=255)


class AdjustStockRequest(CreateModel):
    product_id: int
    adjustment_type: str = Field(..., pattern=r"^(COUNT|DAMAGE|THEFT|EXPIRY|CORRECTION)$")
    system_quantity: int | None = None
    counted_quantity: int | None = Field(default=None, ge=0)
    quantity_change: int | None = None
    reason: str | None = Field(default=None, max_length=255)


class MovementRead(ORMModel):
    transaction_id: int
    product_id: int
    product_name: str | None = None
    sku: str | None = None
    movement_type: str
    quantity: int
    quantity_before: int
    quantity_after: int
    unit_cost: float | None = None
    reference_type: str | None = None
    reference_id: str | None = None
    reason: str | None = None
    username: str | None = None
    created_at: datetime


class LowStockAlertRead(ORMModel):
    alert_id: int
    product_id: int
    product_name: str | None = None
    sku: str | None = None
    quantity_on_hand: int
    low_stock_threshold: int
    status: str
    raised_at: datetime
    resolved_at: datetime | None = None
