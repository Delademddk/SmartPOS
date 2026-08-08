"""Pydantic schemas for reports and dashboard."""

from __future__ import annotations

from datetime import date

from pydantic import BaseModel, Field

from app.api.schemas.common import CreateModel


class ReportRequest(CreateModel):
    report_type: str = Field(
        ...,
        pattern=r"^(daily|weekly|monthly|annual|inventory|profit|cashier|supplier|credit|returns|tax|payment_methods)$",
    )
    date_from: date | None = None
    date_to: date | None = None
    category_id: int | None = None
    supplier_id: int | None = None
    product_id: int | None = None
    cashier_id: int | None = None
    customer_id: int | None = None
    payment_method_id: int | None = None


class ReportRow(BaseModel):
    data: dict[str, object]


class ReportResponse(BaseModel):
    report_type: str
    period: dict[str, str] | None = None
    rows: list[dict[str, object]]
    summary: dict[str, float | int] = {}


class DashboardKPIs(BaseModel):
    today_sales_total: float
    today_sales_count: int
    today_returns_total: float
    today_refunds: int
    low_stock_count: int
    out_of_stock_count: int
    pending_credit_balance: float
    active_users_count: int
    total_products_active: int
