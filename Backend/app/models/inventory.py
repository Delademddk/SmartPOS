"""ORM models for Module 07 - Inventory."""

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


class Inventory(Base):
    __tablename__ = "inventory"

    inventory_id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    product_id: Mapped[int] = mapped_column(ForeignKey("products.product_id"), nullable=False, unique=True)
    quantity_on_hand: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    quantity_reserved: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    reorder_level: Mapped[int | None] = mapped_column(Integer, nullable=True)
    last_restocked_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    last_sold_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime, nullable=False, default=utcnow, onupdate=utcnow
    )

    product = relationship("Product", back_populates="inventory")

    @property
    def sku(self) -> str | None:
        return self.product.sku if self.product else None

    @property
    def product_name(self) -> str | None:
        return self.product.product_name if self.product else None

    @property
    def low_stock_threshold(self) -> int | None:
        return self.product.low_stock_threshold if self.product else None

    @property
    def available_quantity(self) -> int:
        return max(self.quantity_on_hand - self.quantity_reserved, 0)

    @property
    def stock_status(self) -> str:
        qty = self.quantity_on_hand
        threshold = self.low_stock_threshold
        if qty <= 0:
            return "OUT_OF_STOCK"
        if threshold is not None and qty <= threshold:
            return "LOW_STOCK"
        return "IN_STOCK"


class InventoryTransaction(Base):
    __tablename__ = "inventory_transactions"

    transaction_id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    product_id: Mapped[int] = mapped_column(ForeignKey("products.product_id"), nullable=False)
    movement_type: Mapped[str] = mapped_column(Unicode(30), nullable=False)
    quantity: Mapped[int] = mapped_column(Integer, nullable=False)
    quantity_before: Mapped[int] = mapped_column(Integer, nullable=False)
    quantity_after: Mapped[int] = mapped_column(Integer, nullable=False)
    unit_cost: Mapped[float | None] = mapped_column(Numeric(19, 4), nullable=True)
    reference_type: Mapped[str | None] = mapped_column(Unicode(50), nullable=True)
    reference_id: Mapped[str | None] = mapped_column(Unicode(100), nullable=True)
    reason: Mapped[str | None] = mapped_column(Unicode(255), nullable=True)
    user_id: Mapped[int | None] = mapped_column(ForeignKey("users.user_id"), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, nullable=False, default=utcnow)

    product = relationship("Product", lazy="joined")
    user = relationship("User", lazy="joined")

    @property
    def product_name(self) -> str | None:
        return self.product.product_name if self.product else None

    @property
    def sku(self) -> str | None:
        return self.product.sku if self.product else None

    @property
    def username(self) -> str | None:
        return self.user.username if self.user else None


class StockReconciliation(Base):
    __tablename__ = "stock_reconciliations"

    reconciliation_id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    product_id: Mapped[int] = mapped_column(ForeignKey("products.product_id"), nullable=False)
    system_quantity: Mapped[int] = mapped_column(Integer, nullable=False)
    counted_quantity: Mapped[int] = mapped_column(Integer, nullable=False)
    difference: Mapped[int] = mapped_column(Integer, nullable=False)
    adjustment_type: Mapped[str] = mapped_column(Unicode(30), nullable=False)
    reason: Mapped[str | None] = mapped_column(Unicode(255), nullable=True)
    user_id: Mapped[int | None] = mapped_column(ForeignKey("users.user_id"), nullable=True)
    transaction_id: Mapped[int | None] = mapped_column(
        ForeignKey("inventory_transactions.transaction_id"), nullable=True
    )
    reconciled_at: Mapped[datetime] = mapped_column(DateTime, nullable=False, default=utcnow)


class LowStockAlert(Base):
    __tablename__ = "low_stock_alerts"

    alert_id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    product_id: Mapped[int] = mapped_column(ForeignKey("products.product_id"), nullable=False)
    quantity_on_hand: Mapped[int] = mapped_column(Integer, nullable=False)
    low_stock_threshold: Mapped[int] = mapped_column(Integer, nullable=False)
    status: Mapped[str] = mapped_column(Unicode(20), nullable=False, default="OPEN")
    raised_at: Mapped[datetime] = mapped_column(DateTime, nullable=False, default=utcnow)
    resolved_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)

    product = relationship("Product", lazy="joined")

    @property
    def product_name(self) -> str | None:
        return self.product.product_name if self.product else None

    @property
    def sku(self) -> str | None:
        return self.product.sku if self.product else None
