"""Repositories for business, categories, products and suppliers."""

from __future__ import annotations

from sqlalchemy import func, or_, select
from sqlalchemy.orm import Session

from app.models.business import BusinessInformation, Currency, TaxRate
from app.models.catalog import (
    Category,
    Product,
    ProductImage,
    Supplier,
    SupplierContact,
    SupplierHistory,
)
from app.models.inventory import Inventory
from app.repositories.base import BaseRepository


class BusinessInfoRepository(BaseRepository[BusinessInformation]):
    model = BusinessInformation

    def get_single(self) -> BusinessInformation | None:
        stmt = select(BusinessInformation).order_by(BusinessInformation.business_info_id)
        return self.session.scalar(stmt)


class CurrencyRepository(BaseRepository[Currency]):
    model = Currency


class TaxRateRepository(BaseRepository[TaxRate]):
    model = TaxRate


class CategoryRepository(BaseRepository[Category]):
    model = Category

    def get_by_name_parent(self, name: str, parent_id: int | None) -> Category | None:
        stmt = select(Category).where(
            Category.category_name == name,
            Category.parent_id == parent_id,
            Category.is_deleted.is_(False),
        )
        return self.session.scalar(stmt)

    def search(
        self,
        search: str | None,
        parent_id: int | None,
        is_active: bool | None,
        page: int,
        page_size: int,
    ) -> tuple[list[Category], int]:
        filters = [Category.is_deleted.is_(False)]
        if search:
            filters.append(Category.category_name.ilike(f"%{search}%"))
        if parent_id is not None:
            filters.append(Category.parent_id == parent_id)
        if is_active is not None:
            filters.append(Category.is_active.is_(is_active))

        total = int(
            self.session.scalar(select(func.count()).select_from(Category).where(*filters)) or 0
        )
        stmt = (
            select(Category)
            .where(*filters)
            .order_by(Category.sort_order.asc(), Category.category_name.asc())
            .offset((page - 1) * page_size)
            .limit(page_size)
        )
        return list(self.session.scalars(stmt).all()), total

    def has_products(self, category_id: int) -> bool:
        stmt = select(Product.product_id).where(
            Product.category_id == category_id,
            Product.is_deleted.is_(False),
        )
        return self.session.scalar(stmt) is not None

    def has_children(self, category_id: int) -> bool:
        stmt = select(Category.category_id).where(
            Category.parent_id == category_id,
            Category.is_deleted.is_(False),
        )
        return self.session.scalar(stmt) is not None


class ProductRepository(BaseRepository[Product]):
    model = Product

    def get_by_sku(self, sku: str) -> Product | None:
        stmt = select(Product).where(Product.sku == sku)
        return self.session.scalar(stmt)

    def get_by_barcode(self, barcode: str) -> Product | None:
        stmt = select(Product).where(Product.barcode == barcode)
        return self.session.scalar(stmt)

    def search(
        self,
        search: str | None,
        category_id: int | None,
        supplier_id: int | None,
        is_active: bool | None,
        min_price: float | None,
        max_price: float | None,
        stock_status: str | None,
        page: int,
        page_size: int,
    ) -> tuple[list[Product], int]:
        filters = [Product.is_deleted.is_(False)]
        if search:
            like = f"%{search}%"
            filters.append(
                or_(
                    Product.product_name.ilike(like),
                    Product.sku.ilike(like),
                    Product.barcode.ilike(like),
                )
            )
        if category_id:
            filters.append(Product.category_id == category_id)
        if supplier_id:
            filters.append(Product.supplier_id == supplier_id)
        if is_active is not None:
            filters.append(Product.is_active.is_(is_active))
        if min_price is not None:
            filters.append(Product.unit_price >= min_price)
        if max_price is not None:
            filters.append(Product.unit_price <= max_price)

        base_stmt = select(Product).where(*filters)
        total = int(self.session.scalar(select(func.count()).select_from(base_stmt.subquery())) or 0)

        if stock_status == "OUT_OF_STOCK":
            base_stmt = base_stmt.join(Inventory).where(Inventory.quantity_on_hand <= 0)
        elif stock_status == "LOW_STOCK":
            base_stmt = base_stmt.join(Inventory).where(
                Inventory.quantity_on_hand <= Product.low_stock_threshold,
                Inventory.quantity_on_hand > 0,
            )
        elif stock_status == "IN_STOCK":
            base_stmt = base_stmt.join(Inventory).where(
                Inventory.quantity_on_hand > Product.low_stock_threshold
            )

        stmt = (
            base_stmt.order_by(Product.product_name.asc())
            .offset((page - 1) * page_size)
            .limit(page_size)
        )
        return list(self.session.scalars(stmt).unique().all()), total


class ProductImageRepository(BaseRepository[ProductImage]):
    model = ProductImage

    def list_for_product(self, product_id: int) -> list[ProductImage]:
        stmt = (
            select(ProductImage)
            .where(ProductImage.product_id == product_id)
            .order_by(ProductImage.sort_order.asc())
        )
        return list(self.session.scalars(stmt).all())


class SupplierRepository(BaseRepository[Supplier]):
    model = Supplier

    def get_by_code(self, code: str) -> Supplier | None:
        stmt = select(Supplier).where(Supplier.supplier_code == code)
        return self.session.scalar(stmt)

    def get_by_name(self, name: str) -> Supplier | None:
        stmt = select(Supplier).where(Supplier.supplier_name == name)
        return self.session.scalar(stmt)

    def search(
        self,
        search: str | None,
        is_active: bool | None,
        page: int,
        page_size: int,
    ) -> tuple[list[Supplier], int]:
        filters = [Supplier.is_deleted.is_(False)]
        if search:
            like = f"%{search}%"
            filters.append(
                or_(
                    Supplier.supplier_name.ilike(like),
                    Supplier.supplier_code.ilike(like),
                    Supplier.contact_person.ilike(like),
                    Supplier.email.ilike(like),
                )
            )
        if is_active is not None:
            filters.append(Supplier.is_active.is_(is_active))

        total = int(
            self.session.scalar(select(func.count()).select_from(Supplier).where(*filters)) or 0
        )
        stmt = (
            select(Supplier)
            .where(*filters)
            .order_by(Supplier.supplier_name.asc())
            .offset((page - 1) * page_size)
            .limit(page_size)
        )
        return list(self.session.scalars(stmt).all()), total


class SupplierContactRepository(BaseRepository[SupplierContact]):
    model = SupplierContact


class SupplierHistoryRepository(BaseRepository[SupplierHistory]):
    model = SupplierHistory

    def list_for_supplier(self, supplier_id: int, page: int, page_size: int) -> tuple[list[SupplierHistory], int]:
        filters = [SupplierHistory.supplier_id == supplier_id]
        total = int(
            self.session.scalar(select(func.count()).select_from(SupplierHistory).where(*filters)) or 0
        )
        stmt = (
            select(SupplierHistory)
            .where(*filters)
            .order_by(SupplierHistory.changed_at.desc())
            .offset((page - 1) * page_size)
            .limit(page_size)
        )
        return list(self.session.scalars(stmt).all()), total
