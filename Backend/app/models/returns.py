"""ORM models for Module 11 - Returns."""

from __future__ import annotations

from datetime import datetime

from sqlalchemy import (
    Boolean,
    DateTime,
    ForeignKey,
    Integer,
    Numeric,
    Text,
    Unicode,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database.base import Base, utcnow


class ReturnReason(Base):
    __tablename__ = "return_reasons"

    return_reason_id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    reason_code: Mapped[str] = mapped_column(Unicode(30), nullable=False, unique=True)
    reason_name: Mapped[str] = mapped_column(Unicode(100), nullable=False)
    is_active: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, nullable=False, default=utcnow)


class Return(Base):
    __tablename__ = "returns"

    return_id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    return_number: Mapped[str] = mapped_column(Unicode(50), nullable=False, unique=True)
    sale_id: Mapped[int] = mapped_column(ForeignKey("sales.sale_id"), nullable=False)
    customer_id: Mapped[int | None] = mapped_column(ForeignKey("customers.customer_id"), nullable=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.user_id"), nullable=False)
    return_reason_id: Mapped[int | None] = mapped_column(
        ForeignKey("return_reasons.return_reason_id"), nullable=True
    )
    status: Mapped[str] = mapped_column(Unicode(20), nullable=False, default="COMPLETED")
    total_refund_amount: Mapped[float] = mapped_column(Numeric(19, 4), nullable=False, default=0)
    notes: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, nullable=False, default=utcnow)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime, nullable=False, default=utcnow, onupdate=utcnow
    )

    items = relationship(
        "ReturnItem", back_populates="return_header", cascade="all, delete-orphan", lazy="selectin"
    )
    sale = relationship("Sale", lazy="joined")
    customer = relationship("Customer", lazy="joined")
    processor = relationship("User", lazy="joined")
    return_reason = relationship("ReturnReason", lazy="joined")

    @property
    def sale_receipt_number(self) -> str | None:
        return self.sale.receipt_number if self.sale else None

    @property
    def customer_name(self) -> str | None:
        return self.customer.full_name if self.customer else None

    @property
    def processor_name(self) -> str | None:
        return self.processor.full_name if self.processor else None

    @property
    def return_reason_name(self) -> str | None:
        return self.return_reason.reason_name if self.return_reason else None


class ReturnItem(Base):
    __tablename__ = "return_items"

    return_item_id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    return_id: Mapped[int] = mapped_column(ForeignKey("returns.return_id"), nullable=False)
    sale_item_id: Mapped[int] = mapped_column(ForeignKey("sale_items.sale_item_id"), nullable=False)
    product_id: Mapped[int] = mapped_column(ForeignKey("products.product_id"), nullable=False)
    quantity: Mapped[float] = mapped_column(Numeric(12, 3), nullable=False)
    unit_price: Mapped[float] = mapped_column(Numeric(19, 4), nullable=False)
    refund_amount: Mapped[float] = mapped_column(Numeric(19, 4), nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime, nullable=False, default=utcnow)

    return_header = relationship("Return", back_populates="items")
    product = relationship("Product", lazy="joined")

    @property
    def product_name(self) -> str | None:
        return self.product.product_name if self.product else None
