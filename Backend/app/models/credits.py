"""ORM models for Module 10 - Credit sales (customers, credit_sales, credit_payments)."""

from __future__ import annotations

from datetime import date, datetime

from sqlalchemy import (
    Boolean,
    Date,
    DateTime,
    ForeignKey,
    Integer,
    Numeric,
    Unicode,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database.base import Base, utcnow
from app.models.common import TimestampMixin


class Customer(TimestampMixin, Base):
    __tablename__ = "customers"

    customer_id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    customer_code: Mapped[str] = mapped_column(Unicode(30), nullable=False, unique=True)
    full_name: Mapped[str] = mapped_column(Unicode(150), nullable=False)
    phone: Mapped[str | None] = mapped_column(Unicode(30), nullable=True)
    email: Mapped[str | None] = mapped_column(Unicode(255), nullable=True)
    address: Mapped[str | None] = mapped_column(Unicode(255), nullable=True)
    credit_limit: Mapped[float] = mapped_column(Numeric(19, 4), nullable=False, default=0)
    is_active: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)
    is_deleted: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    deleted_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    created_by: Mapped[int | None] = mapped_column(Integer, nullable=True)
    updated_by: Mapped[int | None] = mapped_column(Integer, nullable=True)

    credit_sales = relationship("CreditSale", back_populates="customer")


class CreditSale(Base):
    __tablename__ = "credit_sales"

    credit_sale_id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    sale_id: Mapped[int] = mapped_column(ForeignKey("sales.sale_id"), nullable=False, unique=True)
    customer_id: Mapped[int] = mapped_column(ForeignKey("customers.customer_id"), nullable=False)
    total_amount: Mapped[float] = mapped_column(Numeric(19, 4), nullable=False)
    amount_paid: Mapped[float] = mapped_column(Numeric(19, 4), nullable=False, default=0)
    outstanding_balance: Mapped[float] = mapped_column(Numeric(19, 4), nullable=False)
    due_date: Mapped[date | None] = mapped_column(Date, nullable=True)
    status: Mapped[str] = mapped_column(Unicode(20), nullable=False, default="OPEN")
    created_at: Mapped[datetime] = mapped_column(DateTime, nullable=False, default=utcnow)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime, nullable=False, default=utcnow, onupdate=utcnow
    )

    customer = relationship("Customer", back_populates="credit_sales")
    payments = relationship(
        "CreditPayment", back_populates="credit_sale", cascade="all, delete-orphan"
    )
    sale = relationship("Sale", back_populates="credit_sales", lazy="joined")

    @property
    def receipt_number(self) -> str | None:
        return self.sale.receipt_number if self.sale else None

    @property
    def customer_name(self) -> str | None:
        return self.customer.full_name if self.customer else None

    @property
    def days_overdue(self) -> int:
        if self.due_date is None:
            return 0
        if self.status not in ("OPEN", "PARTIAL", "OVERDUE"):
            return 0
        from datetime import date

        return max((date.today() - self.due_date).days, 0)


class CreditPayment(Base):
    __tablename__ = "credit_payments"

    credit_payment_id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    credit_sale_id: Mapped[int] = mapped_column(
        ForeignKey("credit_sales.credit_sale_id"), nullable=False
    )
    payment_id: Mapped[int | None] = mapped_column(ForeignKey("payments.payment_id"), nullable=True)
    amount: Mapped[float] = mapped_column(Numeric(19, 4), nullable=False)
    payment_date: Mapped[datetime] = mapped_column(DateTime, nullable=False, default=utcnow)
    received_by: Mapped[int | None] = mapped_column(ForeignKey("users.user_id"), nullable=True)
    notes: Mapped[str | None] = mapped_column(Unicode(255), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, nullable=False, default=utcnow)

    credit_sale = relationship("CreditSale", back_populates="payments")
