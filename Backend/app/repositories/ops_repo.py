"""Repositories for inventory, sales, payments, credits, returns."""

from __future__ import annotations

from datetime import date, datetime

from sqlalchemy import func, or_, select
from sqlalchemy.orm import Session

from app.models.credits import CreditPayment, CreditSale, Customer
from app.models.inventory import (
    Inventory,
    InventoryTransaction,
    LowStockAlert,
    StockReconciliation,
)
from app.models.payments import Payment, PaymentMethod, Receipt
from app.models.returns import Return, ReturnItem, ReturnReason
from app.models.sales import Sale, SaleItem
from app.repositories.base import BaseRepository


class InventoryRepository(BaseRepository[Inventory]):
    model = Inventory

    def get_by_product(self, product_id: int) -> Inventory | None:
        stmt = select(Inventory).where(Inventory.product_id == product_id)
        return self.session.scalar(stmt)

    def list_with_products(
        self,
        search: str | None,
        stock_status: str | None,
        page: int,
        page_size: int,
    ) -> tuple[list[Inventory], int]:
        filters = [Inventory.quantity_on_hand >= 0]
        from app.models.catalog import Product

        base = select(Inventory).join(Product).where(Product.is_deleted.is_(False))
        if search:
            like = f"%{search}%"
            base = base.where(
                or_(
                    Product.product_name.ilike(like),
                    Product.sku.ilike(like),
                )
            )
        if stock_status == "OUT_OF_STOCK":
            base = base.where(Inventory.quantity_on_hand <= 0)
        elif stock_status == "LOW_STOCK":
            base = base.where(
                Inventory.quantity_on_hand <= Product.low_stock_threshold,
                Inventory.quantity_on_hand > 0,
            )
        elif stock_status == "IN_STOCK":
            base = base.where(Inventory.quantity_on_hand > Product.low_stock_threshold)

        total = int(self.session.scalar(select(func.count()).select_from(base.subquery())) or 0)
        stmt = (
            base.order_by(Product.product_name.asc())
            .offset((page - 1) * page_size)
            .limit(page_size)
        )
        return list(self.session.scalars(stmt).unique().all()), total


class InventoryTransactionRepository(BaseRepository[InventoryTransaction]):
    model = InventoryTransaction

    def list_filtered(
        self,
        product_id: int | None,
        movement_type: str | None,
        date_from: datetime | None,
        date_to: datetime | None,
        page: int,
        page_size: int,
    ) -> tuple[list[InventoryTransaction], int]:
        filters = []
        if product_id:
            filters.append(InventoryTransaction.product_id == product_id)
        if movement_type:
            filters.append(InventoryTransaction.movement_type == movement_type)
        if date_from:
            filters.append(InventoryTransaction.created_at >= date_from)
        if date_to:
            filters.append(InventoryTransaction.created_at <= date_to)

        total = int(
            self.session.scalar(
                select(func.count()).select_from(InventoryTransaction).where(*filters)
            )
            or 0
        )
        stmt = (
            select(InventoryTransaction)
            .where(*filters)
            .order_by(InventoryTransaction.created_at.desc())
            .offset((page - 1) * page_size)
            .limit(page_size)
        )
        return list(self.session.scalars(stmt).all()), total


class StockReconciliationRepository(BaseRepository[StockReconciliation]):
    model = StockReconciliation


class LowStockAlertRepository(BaseRepository[LowStockAlert]):
    model = LowStockAlert

    def open_alerts(self) -> list[LowStockAlert]:
        stmt = select(LowStockAlert).where(LowStockAlert.status == "OPEN")
        return list(self.session.scalars(stmt).all())

    def open_for_product(self, product_id: int) -> LowStockAlert | None:
        stmt = select(LowStockAlert).where(
            LowStockAlert.product_id == product_id,
            LowStockAlert.status == "OPEN",
        )
        return self.session.scalar(stmt)


class SaleRepository(BaseRepository[Sale]):
    model = Sale

    def get_by_receipt_number(self, receipt_number: str) -> Sale | None:
        stmt = select(Sale).where(Sale.receipt_number == receipt_number)
        return self.session.scalar(stmt)

    def search(
        self,
        search: str | None,
        status: str | None,
        sale_type: str | None,
        user_id: int | None,
        customer_id: int | None,
        date_from: datetime | None,
        date_to: datetime | None,
        page: int,
        page_size: int,
    ) -> tuple[list[Sale], int]:
        filters = []
        if search:
            filters.append(Sale.receipt_number.ilike(f"%{search}%"))
        if status:
            filters.append(Sale.status == status)
        if sale_type:
            filters.append(Sale.sale_type == sale_type)
        if user_id:
            filters.append(Sale.user_id == user_id)
        if customer_id:
            filters.append(Sale.customer_id == customer_id)
        if date_from:
            filters.append(Sale.sale_date >= date_from)
        if date_to:
            filters.append(Sale.sale_date <= date_to)

        total = int(self.session.scalar(select(func.count()).select_from(Sale).where(*filters)) or 0)
        stmt = (
            select(Sale)
            .where(*filters)
            .order_by(Sale.sale_date.desc())
            .offset((page - 1) * page_size)
            .limit(page_size)
        )
        return list(self.session.scalars(stmt).unique().all()), total


class SaleItemRepository(BaseRepository[SaleItem]):
    model = SaleItem


class PaymentMethodRepository(BaseRepository[PaymentMethod]):
    model = PaymentMethod

    def get_by_code(self, code: str) -> PaymentMethod | None:
        stmt = select(PaymentMethod).where(PaymentMethod.method_code == code)
        return self.session.scalar(stmt)


class PaymentRepository(BaseRepository[Payment]):
    model = Payment

    def list_for_sale(self, sale_id: int) -> list[Payment]:
        stmt = select(Payment).where(Payment.sale_id == sale_id).order_by(Payment.received_at)
        return list(self.session.scalars(stmt).all())


class ReceiptRepository(BaseRepository[Receipt]):
    model = Receipt

    def get_by_number(self, receipt_number: str) -> Receipt | None:
        stmt = select(Receipt).where(Receipt.receipt_number == receipt_number)
        return self.session.scalar(stmt)


class CustomerRepository(BaseRepository[Customer]):
    model = Customer

    def get_by_code(self, code: str) -> Customer | None:
        stmt = select(Customer).where(Customer.customer_code == code)
        return self.session.scalar(stmt)

    def search(self, search: str | None, page: int, page_size: int) -> tuple[list[Customer], int]:
        filters = [Customer.is_deleted.is_(False)]
        if search:
            like = f"%{search}%"
            filters.append(
                or_(
                    Customer.full_name.ilike(like),
                    Customer.customer_code.ilike(like),
                    Customer.phone.ilike(like),
                )
            )
        total = int(
            self.session.scalar(select(func.count()).select_from(Customer).where(*filters)) or 0
        )
        stmt = (
            select(Customer)
            .where(*filters)
            .order_by(Customer.full_name.asc())
            .offset((page - 1) * page_size)
            .limit(page_size)
        )
        return list(self.session.scalars(stmt).all()), total

    def outstanding_balance(self, customer_id: int) -> float:
        stmt = select(func.coalesce(func.sum(CreditSale.outstanding_balance), 0)).where(
            CreditSale.customer_id == customer_id,
            CreditSale.status.in_(["OPEN", "PARTIAL", "OVERDUE"]),
        )
        return float(self.session.scalar(stmt) or 0)


class CreditSaleRepository(BaseRepository[CreditSale]):
    model = CreditSale

    def get_by_sale_id(self, sale_id: int) -> CreditSale | None:
        stmt = select(CreditSale).where(CreditSale.sale_id == sale_id)
        return self.session.scalar(stmt)

    def list_filtered(
        self,
        customer_id: int | None,
        status: str | None,
        page: int,
        page_size: int,
    ) -> tuple[list[CreditSale], int]:
        filters = []
        if customer_id:
            filters.append(CreditSale.customer_id == customer_id)
        if status:
            filters.append(CreditSale.status == status)
        total = int(
            self.session.scalar(select(func.count()).select_from(CreditSale).where(*filters)) or 0
        )
        stmt = (
            select(CreditSale)
            .where(*filters)
            .order_by(CreditSale.created_at.desc())
            .offset((page - 1) * page_size)
            .limit(page_size)
        )
        return list(self.session.scalars(stmt).unique().all()), total


class CreditPaymentRepository(BaseRepository[CreditPayment]):
    model = CreditPayment


class ReturnReasonRepository(BaseRepository[ReturnReason]):
    model = ReturnReason


class ReturnRepository(BaseRepository[Return]):
    model = Return

    def get_by_number(self, number: str) -> Return | None:
        stmt = select(Return).where(Return.return_number == number)
        return self.session.scalar(stmt)

    def list_filtered(
        self,
        sale_id: int | None,
        status: str | None,
        page: int,
        page_size: int,
    ) -> tuple[list[Return], int]:
        filters = []
        if sale_id:
            filters.append(Return.sale_id == sale_id)
        if status:
            filters.append(Return.status == status)
        total = int(
            self.session.scalar(select(func.count()).select_from(Return).where(*filters)) or 0
        )
        stmt = (
            select(Return)
            .where(*filters)
            .order_by(Return.created_at.desc())
            .offset((page - 1) * page_size)
            .limit(page_size)
        )
        return list(self.session.scalars(stmt).unique().all()), total


class ReturnItemRepository(BaseRepository[ReturnItem]):
    model = ReturnItem
