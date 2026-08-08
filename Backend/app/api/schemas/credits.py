"""Pydantic schemas for customers and credit sales."""

from __future__ import annotations

from datetime import date, datetime

from pydantic import Field

from app.api.schemas.common import CreateModel, ORMModel, UpdateModel


class CustomerRead(ORMModel):
    customer_id: int
    customer_code: str
    full_name: str
    phone: str | None = None
    email: str | None = None
    address: str | None = None
    credit_limit: float
    is_active: bool
    created_at: datetime
    updated_at: datetime


class CustomerCreate(CreateModel):
    customer_code: str = Field(..., min_length=1, max_length=30, pattern=r"^[A-Za-z0-9\-_]+$")
    full_name: str = Field(..., min_length=1, max_length=150)
    phone: str | None = Field(default=None, max_length=30)
    email: str | None = Field(default=None, max_length=255)
    address: str | None = Field(default=None, max_length=255)
    credit_limit: float = Field(default=0, ge=0)


class CustomerUpdate(UpdateModel):
    full_name: str | None = Field(default=None, min_length=1, max_length=150)
    phone: str | None = Field(default=None, max_length=30)
    email: str | None = Field(default=None, max_length=255)
    address: str | None = Field(default=None, max_length=255)
    credit_limit: float | None = Field(default=None, ge=0)
    is_active: bool | None = None


class CreditSaleRead(ORMModel):
    credit_sale_id: int
    sale_id: int
    receipt_number: str | None = None
    customer_id: int
    customer_name: str | None = None
    total_amount: float
    amount_paid: float
    outstanding_balance: float
    due_date: date | None = None
    status: str
    days_overdue: int = 0
    created_at: datetime
    updated_at: datetime


class CreditPaymentRead(ORMModel):
    credit_payment_id: int
    credit_sale_id: int
    payment_id: int | None = None
    amount: float
    payment_date: datetime
    received_by: int | None = None
    notes: str | None = None


class CreditSettlementRequest(CreateModel):
    amount: float = Field(..., gt=0)
    payment_method_id: int | None = None
    payment_id: int | None = None
    notes: str | None = Field(default=None, max_length=255)
