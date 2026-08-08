"""Pydantic schemas for returns."""

from __future__ import annotations

from datetime import datetime

from pydantic import Field

from app.api.schemas.common import CreateModel, ORMModel


class ReturnItemCreate(CreateModel):
    sale_item_id: int
    quantity: float = Field(..., gt=0)


class ReturnCreate(CreateModel):
    sale_id: int
    return_reason_id: int | None = None
    items: list[ReturnItemCreate] = Field(..., min_length=1)
    notes: str | None = None


class ReturnItemRead(ORMModel):
    return_item_id: int
    sale_item_id: int
    product_id: int
    product_name: str | None = None
    quantity: float
    unit_price: float
    refund_amount: float


class ReturnRead(ORMModel):
    return_id: int
    return_number: str
    sale_id: int
    sale_receipt_number: str | None = None
    customer_id: int | None = None
    customer_name: str | None = None
    user_id: int
    processor_name: str | None = None
    return_reason_id: int | None = None
    return_reason_name: str | None = None
    status: str
    total_refund_amount: float
    notes: str | None = None
    created_at: datetime
    items: list[ReturnItemRead] = []


class ReturnReasonRead(ORMModel):
    return_reason_id: int
    reason_code: str
    reason_name: str
    is_active: bool
