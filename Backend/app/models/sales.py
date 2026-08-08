"""ORM models for Module 08 - Sales."""

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


class Sale(Base):
    __tablename__ = "sales"

    sale_id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    receipt_number: Mapped[str] = mapped_column(Unicode(50), nullable=False, unique=True)
    sale_date: Mapped[datetime] = mapped_column(DateTime, nullable=False, default=utcnow)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.user_id"), nullable=False)
    customer_id: Mapped[int | None] = mapped_column(ForeignKey("customers.customer_id"), nullable=True)
    tax_rate_id: Mapped[int | None] = mapped_column(ForeignKey("tax_rates.tax_rate_id"), nullable=True)
    sale_type: Mapped[str] = mapped_column(Unicode(20), nullable=False, default="CASH")
    subtotal: Mapped[float] = mapped_column(Numeric(19, 4), nullable=False, default=0)
    discount_amount: Mapped[float] = mapped_column(Numeric(19, 4), nullable=False, default=0)
    tax_amount: Mapped[float] = mapped_column(Numeric(19, 4), nullable=False, default=0)
    total_amount: Mapped[float] = mapped_column(Numeric(19, 4), nullable=False, default=0)
    amount_received: Mapped[float] = mapped_column(Numeric(19, 4), nullable=False, default=0)
    status: Mapped[str] = mapped_column(Unicode(20), nullable=False, default="COMPLETED")
    notes: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, nullable=False, default=utcnow)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime, nullable=False, default=utcnow, onupdate=utcnow
    )

    items = relationship(
        "SaleItem", back_populates="sale", cascade="all, delete-orphan", lazy="selectin"
    )
    cashier = relationship("User", lazy="joined")
    customer = relationship("Customer", lazy="joined")
    payments = relationship("Payment", back_populates="sale", lazy="selectin")
    credit_sales = relationship("CreditSale", back_populates="sale", lazy="selectin")

    @property
    def cashier_name(self) -> str | None:
        return self.cashier.full_name if self.cashier else None

    @property
    def customer_name(self) -> str | None:
        return self.customer.full_name if self.customer else None


class SaleItem(Base):
    __tablename__ = "sale_items"

    sale_item_id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    sale_id: Mapped[int] = mapped_column(ForeignKey("sales.sale_id"), nullable=False)
    product_id: Mapped[int] = mapped_column(ForeignKey("products.product_id"), nullable=False)
    quantity: Mapped[float] = mapped_column(Numeric(12, 3), nullable=False)
    unit_price: Mapped[float] = mapped_column(Numeric(19, 4), nullable=False)
    discount_rate: Mapped[float] = mapped_column(Numeric(5, 4), nullable=False, default=0)
    tax_amount: Mapped[float] = mapped_column(Numeric(19, 4), nullable=False, default=0)
    line_total: Mapped[float] = mapped_column(Numeric(19, 4), nullable=False)
    is_returned: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    returned_qty: Mapped[float] = mapped_column(Numeric(12, 3), nullable=False, default=0)
    created_at: Mapped[datetime] = mapped_column(DateTime, nullable=False, default=utcnow)

    sale = relationship("Sale", back_populates="items")
    product = relationship("Product", lazy="joined")

    @property
    def product_name(self) -> str | None:
        return self.product.product_name if self.product else None

    @property
    def sku(self) -> str | None:
        return self.product.sku if self.product else None
