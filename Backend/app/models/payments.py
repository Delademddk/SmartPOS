"""ORM models for Module 09 - Payments and receipts."""

from __future__ import annotations

from datetime import datetime

from sqlalchemy import (
    Boolean,
    DateTime,
    ForeignKey,
    Integer,
    Numeric,
    Unicode,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database.base import Base, utcnow


class PaymentMethod(Base):
    __tablename__ = "payment_methods"

    payment_method_id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    method_code: Mapped[str] = mapped_column(Unicode(30), nullable=False, unique=True)
    method_name: Mapped[str] = mapped_column(Unicode(100), nullable=False)
    is_cash: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    is_active: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)
    sort_order: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    created_at: Mapped[datetime] = mapped_column(DateTime, nullable=False, default=utcnow)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime, nullable=False, default=utcnow, onupdate=utcnow
    )


class Payment(Base):
    __tablename__ = "payments"

    payment_id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    sale_id: Mapped[int] = mapped_column(ForeignKey("sales.sale_id"), nullable=False)
    payment_method_id: Mapped[int] = mapped_column(
        ForeignKey("payment_methods.payment_method_id"), nullable=False
    )
    amount: Mapped[float] = mapped_column(Numeric(19, 4), nullable=False)
    reference_number: Mapped[str | None] = mapped_column(Unicode(100), nullable=True)
    received_at: Mapped[datetime] = mapped_column(DateTime, nullable=False, default=utcnow)
    received_by: Mapped[int | None] = mapped_column(ForeignKey("users.user_id"), nullable=True)
    pay_status: Mapped[str] = mapped_column(Unicode(20), nullable=False, default="COMPLETED")
    notes: Mapped[str | None] = mapped_column(Unicode(255), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, nullable=False, default=utcnow)

    sale = relationship("Sale", back_populates="payments")
    method = relationship("PaymentMethod", lazy="joined")

    @property
    def method_name(self) -> str | None:
        return self.method.method_name if self.method else None

    @property
    def method_code(self) -> str | None:
        return self.method.method_code if self.method else None


class Receipt(Base):
    __tablename__ = "receipts"

    receipt_id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    receipt_number: Mapped[str] = mapped_column(Unicode(50), nullable=False, unique=True)
    sale_id: Mapped[int] = mapped_column(ForeignKey("sales.sale_id"), nullable=False)
    gross_total: Mapped[float] = mapped_column(Numeric(19, 4), nullable=False)
    discount_amount: Mapped[float] = mapped_column(Numeric(19, 4), nullable=False, default=0)
    tax_amount: Mapped[float] = mapped_column(Numeric(19, 4), nullable=False, default=0)
    net_total: Mapped[float] = mapped_column(Numeric(19, 4), nullable=False)
    amount_paid: Mapped[float] = mapped_column(Numeric(19, 4), nullable=False)
    change_due: Mapped[float] = mapped_column(Numeric(19, 4), nullable=False, default=0)
    generated_by: Mapped[int | None] = mapped_column(ForeignKey("users.user_id"), nullable=True)
    generated_at: Mapped[datetime] = mapped_column(DateTime, nullable=False, default=utcnow)

    sale = relationship("Sale", lazy="joined")

    @property
    def items(self) -> list:
        return list(self.sale.items) if self.sale else []
