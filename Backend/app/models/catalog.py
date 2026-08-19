"""ORM models for Modules 04/05/06 - Categories, Products, Suppliers."""

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
from app.models.common import AuditableMixin, SoftDeleteMixin, TimestampMixin


class Category(TimestampMixin, AuditableMixin, SoftDeleteMixin, Base):
    __tablename__ = "categories"

    category_id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    category_name: Mapped[str] = mapped_column(Unicode(100), nullable=False)
    parent_id: Mapped[int | None] = mapped_column(ForeignKey("categories.category_id"), nullable=True)
    description: Mapped[str | None] = mapped_column(Unicode(255), nullable=True)
    sort_order: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    is_active: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)

    parent = relationship("Category", remote_side=[category_id], backref="children")
    products = relationship("Product", back_populates="category", foreign_keys="Product.category_id")

    @property
    def child_count(self) -> int:
        return len([c for c in self.children if not c.is_deleted])

    @property
    def product_count(self) -> int:
        return len([p for p in self.products if not p.is_deleted])


class Product(TimestampMixin, AuditableMixin, SoftDeleteMixin, Base):
    __tablename__ = "products"

    product_id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    sku: Mapped[str] = mapped_column(Unicode(50), nullable=False, unique=True)
    barcode: Mapped[str | None] = mapped_column(Unicode(50), nullable=True, unique=True)
    product_name: Mapped[str] = mapped_column(Unicode(200), nullable=False)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    category_id: Mapped[int | None] = mapped_column(ForeignKey("categories.category_id"), nullable=True)
    supplier_id: Mapped[int | None] = mapped_column(ForeignKey("suppliers.supplier_id"), nullable=True)
    unit: Mapped[str] = mapped_column(Unicode(20), nullable=False, default="pcs")
    unit_price: Mapped[float] = mapped_column(Numeric(19, 4), nullable=False, default=0)
    cost_price: Mapped[float | None] = mapped_column(Numeric(19, 4), nullable=True)
    image_url: Mapped[str | None] = mapped_column(Unicode(500), nullable=True)
    low_stock_threshold: Mapped[int] = mapped_column(Integer, nullable=False, default=10)
    is_service: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    is_active: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)

    category = relationship("Category", back_populates="products", lazy="joined")
    supplier = relationship("Supplier", lazy="joined")
    inventory = relationship("Inventory", back_populates="product", uselist=False, lazy="joined")

    @property
    def category_name(self) -> str | None:
        return self.category.category_name if self.category else None

    @property
    def supplier_name(self) -> str | None:
        return self.supplier.supplier_name if self.supplier else None

    @property
    def quantity_on_hand(self) -> int:
        return self.inventory.quantity_on_hand if self.inventory else 0

    @property
    def stock_status(self) -> str:
        qty = self.quantity_on_hand
        if qty <= 0:
            return "OUT_OF_STOCK"
        if qty <= self.low_stock_threshold:
            return "LOW_STOCK"
        return "IN_STOCK"


class ProductImage(Base):
    __tablename__ = "product_images"

    image_id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    product_id: Mapped[int] = mapped_column(ForeignKey("products.product_id"), nullable=False)
    image_url: Mapped[str] = mapped_column(Unicode(500), nullable=False)
    image_alt: Mapped[str | None] = mapped_column(Unicode(200), nullable=True)
    is_primary: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    sort_order: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    created_at: Mapped[datetime] = mapped_column(DateTime, nullable=False, default=utcnow)


class Supplier(TimestampMixin, AuditableMixin, SoftDeleteMixin, Base):
    __tablename__ = "suppliers"

    supplier_id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    supplier_code: Mapped[str] = mapped_column(Unicode(30), nullable=False, unique=True)
    supplier_name: Mapped[str] = mapped_column(Unicode(150), nullable=False, unique=True)
    contact_person: Mapped[str | None] = mapped_column(Unicode(150), nullable=True)
    email: Mapped[str | None] = mapped_column(Unicode(255), nullable=True)
    phone: Mapped[str | None] = mapped_column(Unicode(30), nullable=True)
    address_line1: Mapped[str | None] = mapped_column(Unicode(255), nullable=True)
    address_line2: Mapped[str | None] = mapped_column(Unicode(255), nullable=True)
    city: Mapped[str | None] = mapped_column(Unicode(100), nullable=True)
    state: Mapped[str | None] = mapped_column(Unicode(100), nullable=True)
    postal_code: Mapped[str | None] = mapped_column(Unicode(20), nullable=True)
    country: Mapped[str | None] = mapped_column(Unicode(100), nullable=True)
    notes: Mapped[str | None] = mapped_column(Text, nullable=True)
    is_active: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)

    contacts = relationship("SupplierContact", back_populates="supplier", cascade="all, delete-orphan")
    history = relationship("SupplierHistory", back_populates="supplier", cascade="all, delete-orphan")


class SupplierContact(Base):
    __tablename__ = "supplier_contacts"

    contact_id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    supplier_id: Mapped[int] = mapped_column(ForeignKey("suppliers.supplier_id"), nullable=False)
    full_name: Mapped[str] = mapped_column(Unicode(150), nullable=False)
    job_title: Mapped[str | None] = mapped_column(Unicode(100), nullable=True)
    email: Mapped[str | None] = mapped_column(Unicode(255), nullable=True)
    phone: Mapped[str | None] = mapped_column(Unicode(30), nullable=True)
    is_primary: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    is_active: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, nullable=False, default=utcnow)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime, nullable=False, default=utcnow, onupdate=utcnow
    )

    supplier = relationship("Supplier", back_populates="contacts")


class SupplierHistory(Base):
    __tablename__ = "supplier_history"

    history_id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    supplier_id: Mapped[int] = mapped_column(ForeignKey("suppliers.supplier_id"), nullable=False)
    history_type: Mapped[str] = mapped_column(Unicode(50), nullable=False)
    description: Mapped[str | None] = mapped_column(Unicode(255), nullable=True)
    changed_by: Mapped[int | None] = mapped_column(Integer, nullable=True)
    changed_at: Mapped[datetime] = mapped_column(DateTime, nullable=False, default=utcnow)

    supplier = relationship("Supplier", back_populates="history")
