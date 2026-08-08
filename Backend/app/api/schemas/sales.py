"""Pydantic schemas for sales, payments and receipts."""

from __future__ import annotations

from datetime import datetime

from pydantic import Field

from app.api.schemas.common import CreateModel, ORMModel


class SaleItemCreate(CreateModel):
    product_id: int
    quantity: float = Field(..., gt=0, le=1000000)
    unit_price: float | None = Field(default=None, ge=0)
    discount_rate: float = Field(default=0, ge=0, le=1)


class PaymentLineCreate(CreateModel):
    payment_method_id: int
    amount: float = Field(..., gt=0)
    reference_number: str | None = Field(default=None, max_length=100)


class SaleCreate(CreateModel):
    sale_type: str = Field(default="CASH", pattern=r"^(CASH|CREDIT|CREDIT_PARTIAL)$")
    tax_rate_id: int | None = None
    customer_id: int | None = None
    discount_amount: float = Field(default=0, ge=0)
    items: list[SaleItemCreate] = Field(..., min_length=1)
    payments: list[PaymentLineCreate] = Field(default_factory=list)
    amount_received: float | None = Field(default=None, ge=0)
    notes: str | None = None
    due_date: str | None = None


class SaleItemRead(ORMModel):
    sale_item_id: int
    product_id: int
    product_name: str | None = None
    sku: str | None = None
    quantity: float
    unit_price: float
    discount_rate: float
    tax_amount: float
    line_total: float
    is_returned: bool
    returned_qty: float


class PaymentRead(ORMModel):
    payment_id: int
    sale_id: int
    payment_method_id: int
    method_name: str | None = None
    method_code: str | None = None
    amount: float
    reference_number: str | None = None
    received_at: datetime
    received_by: int | None = None
    pay_status: str
    notes: str | None = None


class SaleRead(ORMModel):
    sale_id: int
    receipt_number: str
    sale_date: datetime
    user_id: int
    cashier_name: str | None = None
    customer_id: int | None = None
    customer_name: str | None = None
    tax_rate_id: int | None = None
    sale_type: str
    subtotal: float
    discount_amount: float
    tax_amount: float
    total_amount: float
    amount_received: float
    status: str
    notes: str | None = None
    created_at: datetime
    items: list[SaleItemRead] = []
    payments: list[PaymentRead] = []


class ReceiptRead(ORMModel):
    receipt_id: int
    receipt_number: str
    sale_id: int
    gross_total: float
    discount_amount: float
    tax_amount: float
    net_total: float
    amount_paid: float
    change_due: float
    generated_by: int | None = None
    generated_at: datetime
    items: list[SaleItemRead] = []
    sale: SaleRead | None = None


class VoidSaleRequest(CreateModel):
    reason: str | None = Field(default=None, max_length=255)


class RefundRequest(CreateModel):
    reason: str | None = Field(default=None, max_length=255)
