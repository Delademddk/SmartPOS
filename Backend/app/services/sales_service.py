"""Sales service (Feature 10).

Creates sales with transactional stock deduction, payment recording, credit
ledger creation, receipt generation and notification dispatch. Supports sale
voiding with stock restoration.
"""

from __future__ import annotations

from datetime import UTC, datetime
from decimal import ROUND_HALF_UP, Decimal

from app.api.schemas.sales import SaleCreate, SaleRead
from app.core.constants import (
    MovementType,
    NotificationSeverity,
    SaleStatus,
    SaleType,
)
from app.database.base import utcnow
from app.exceptions import (
    BadRequestError,
    InvalidOperationError,
    NotFoundError,
    ValidationError_,
)
from app.models.catalog import Product
from app.models.credits import CreditSale
from app.models.payments import Payment, Receipt
from app.models.sales import Sale, SaleItem
from app.models.users import User
from app.repositories.catalog_repo import ProductRepository
from app.repositories.ops_repo import (
    CreditSaleRepository,
    PaymentRepository,
    ReceiptRepository,
    SaleItemRepository,
    SaleRepository,
)
from app.repositories.system_repo import NotificationRepository, NotificationTypeRepository
from app.services.audit_service import AuditService
from app.services.base import BaseService
from app.services.credits_service import CreditService
from app.services.inventory_service import InventoryService
from app.services.notifications_service import NotificationService
from app.services.payments_service import PaymentService
from app.utils.numbers import generate_receipt_number
from app.utils.pagination import PageParams


def _line_total(unit_price: float, quantity: float, discount_rate: float) -> float:
    value = Decimal(str(unit_price)) * Decimal(str(quantity)) * (Decimal(1) - Decimal(str(discount_rate)))
    return float(value.quantize(Decimal("0.0001"), rounding=ROUND_HALF_UP))


def _money(value: float) -> float:
    return float(Decimal(str(value)).quantize(Decimal("0.0001"), rounding=ROUND_HALF_UP))


class SalesService(BaseService):
    service_name = "sales"

    def __init__(self, session) -> None:  # noqa: ANN001
        super().__init__(session)
        self.sales = SaleRepository(session)
        self.sale_items = SaleItemRepository(session)
        self.products = ProductRepository(session)
        self.payments = PaymentRepository(session)
        self.receipts = ReceiptRepository(session)
        self.credit_sales = CreditSaleRepository(session)
        self.notifications = NotificationRepository(session)
        self.notification_types = NotificationTypeRepository(session)
        self.inventory_service = InventoryService(session)
        self.payment_service = PaymentService(session)
        self.credit_service = CreditService(session)
        self.notification_service = NotificationService(session)
        self.audit = AuditService(session)

    # ------------------------------------------------------------------
    # Queries
    # ------------------------------------------------------------------
    def list(
        self,
        page: PageParams,
        search: str | None,
        status: str | None,
        sale_type: str | None,
        user_id: int | None,
        customer_id: int | None,
        date_from: datetime | None,
        date_to: datetime | None,
    ) -> tuple[list[Sale], int]:
        return self.sales.search(
            search=search,
            status=status,
            sale_type=sale_type,
            user_id=user_id,
            customer_id=customer_id,
            date_from=date_from,
            date_to=date_to,
            page=page.page,
            page_size=page.page_size,
        )

    def get(self, sale_id: int) -> Sale:
        sale = self.sales.get(sale_id)
        if sale is None:
            raise NotFoundError("Sale not found.")
        return sale

    def get_by_receipt(self, receipt_number: str) -> Sale:
        sale = self.sales.get_by_receipt_number(receipt_number)
        if sale is None:
            raise NotFoundError("Sale not found.")
        return sale

    def my_sales(self, user: User, page: PageParams) -> tuple[list[Sale], int]:
        return self.sales.search(
            search=None,
            status=None,
            sale_type=None,
            user_id=user.user_id,
            customer_id=None,
            date_from=None,
            date_to=None,
            page=page.page,
            page_size=page.page_size,
        )

    # ------------------------------------------------------------------
    # Create sale
    # ------------------------------------------------------------------
    def create_sale(self, payload: SaleCreate, cashier: User) -> Sale:
        sale_type = payload.sale_type
        if sale_type in (SaleType.CREDIT.value, SaleType.CREDIT_PARTIAL.value):
            if payload.customer_id is None:
                raise ValidationError_(
                    "A customer is required for credit sales.",
                    [{"field": "customer_id", "message": "Required for credit sales"}],
                )
            self.credit_service.get_customer(payload.customer_id)

        products: dict[int, Product] = {}
        for line in payload.items:
            product = self.products.get(line.product_id)
            if product is None or product.is_deleted:
                raise NotFoundError(
                    f"Product {line.product_id} not found.",
                    resource_type="Product",
                    resource_id=line.product_id,
                )
            if not product.is_active:
                raise BadRequestError(
                    f"Product '{product.product_name}' is archived and cannot be sold."
                )
            products[line.product_id] = product
            self.inventory_service.ensure_sufficient_stock(product, line.quantity)

        # ---- compute totals ----
        subtotal = _money(sum(
            _line_total(
                line.unit_price if line.unit_price is not None else products[line.product_id].unit_price,
                line.quantity,
                line.discount_rate,
            )
            for line in payload.items
        ))
        discount_amount = _money(payload.discount_amount)
        tax_amount = self._compute_tax(subtotal, discount_amount, payload.tax_rate_id)
        total_amount = _money(subtotal - discount_amount + tax_amount)

        payments_sum = _money(sum(p.amount for p in payload.payments))
        if sale_type == SaleType.CASH.value:
            amount_received = _money(payload.amount_received if payload.amount_received is not None else payments_sum)
            if amount_received < total_amount:
                raise ValidationError_(
                    "Amount received is less than the sale total.",
                    [{"field": "amount_received", "message": "Must be >= total"}],
                )
        else:
            amount_received = payments_sum

        # ---- build header ----
        sale = Sale(
            receipt_number=generate_receipt_number(),
            sale_date=utcnow(),
            user_id=cashier.user_id,
            customer_id=payload.customer_id,
            tax_rate_id=payload.tax_rate_id,
            sale_type=sale_type,
            subtotal=subtotal,
            discount_amount=discount_amount,
            tax_amount=tax_amount,
            total_amount=total_amount,
            amount_received=amount_received,
            status=SaleStatus.COMPLETED.value,
            notes=payload.notes,
        )
        self.sales.add(sale)
        self.session.flush()

        # ---- items + stock deduction ----
        for line in payload.items:
            product = products[line.product_id]
            unit_price = line.unit_price if line.unit_price is not None else product.unit_price
            line_total = _line_total(unit_price, line.quantity, line.discount_rate)
            line_tax = _money(line_total * (self._tax_rate(payload.tax_rate_id) / 100))
            self.sale_items.add(
                SaleItem(
                    sale_id=sale.sale_id,
                    product_id=product.product_id,
                    quantity=line.quantity,
                    unit_price=unit_price,
                    discount_rate=line.discount_rate,
                    tax_amount=line_tax,
                    line_total=line_total,
                )
            )
            self.inventory_service.deduct_stock(
                product_id=product.product_id,
                quantity=line.quantity,
                movement_type=MovementType.SALE.value,
                reference_type="Sale",
                reference_id=sale.sale_id,
                user_id=cashier.user_id,
            )

        # ---- payments ----
        for payment_line in payload.payments:
            self.payment_service._validate_method(payment_line.payment_method_id)
            self.payments.add(
                Payment(
                    sale_id=sale.sale_id,
                    payment_method_id=payment_line.payment_method_id,
                    amount=_money(payment_line.amount),
                    reference_number=payment_line.reference_number,
                    received_by=cashier.user_id,
                    pay_status="COMPLETED",
                )
            )
        if sale_type == SaleType.CASH.value and amount_received > 0 and not payload.payments:
            cash_method = self.payment_service.get_method_by_code("CASH")
            self.payments.add(
                Payment(
                    sale_id=sale.sale_id,
                    payment_method_id=cash_method.payment_method_id,
                    amount=amount_received,
                    received_by=cashier.user_id,
                    pay_status="COMPLETED",
                )
            )

        # ---- credit ledger ----
        if sale_type in (SaleType.CREDIT.value, SaleType.CREDIT_PARTIAL.value):
            self.credit_service.create_from_sale(
                sale_id=sale.sale_id,
                customer_id=payload.customer_id,
                total_amount=total_amount,
                amount_paid=amount_received,
                due_date=self._parse_due_date(payload.due_date),
            )

        # ---- receipt + notification ----
        self._generate_receipt(sale, amount_received, cashier)
        self._notify_sale_created(sale, cashier)
        self.audit.activity(
            activity_type="SALE_CREATED",
            activity_desc=f"Created sale {sale.receipt_number}",
            entity_type="Sale",
            entity_id=sale.sale_id,
            user_id=cashier.user_id,
        )
        self.audit.record(
            action_type="INSERT",
            resource_type="Sale",
            resource_id=sale.sale_id,
            user_id=cashier.user_id,
            new_values={
                "receipt_number": sale.receipt_number,
                "total_amount": float(sale.total_amount),
                "sale_type": sale.sale_type,
            },
        )
        self.session.commit()
        return self.sales.get(sale.sale_id)

    # ------------------------------------------------------------------
    # Void sale
    # ------------------------------------------------------------------
    def void_sale(self, sale_id: int, user: User, reason: str | None) -> Sale:
        sale = self.get(sale_id)
        if sale.status == SaleStatus.VOIDED.value:
            raise InvalidOperationError("Sale is already voided.")
        if sale.status == SaleStatus.REFUNDED.value:
            raise InvalidOperationError("A refunded sale cannot be voided.")

        sale.status = SaleStatus.VOIDED.value
        sale.notes = reason or sale.notes
        sale.updated_at = utcnow()

        for item in sale.items:
            self.inventory_service.restore_stock(
                product_id=item.product_id,
                quantity=item.quantity,
                movement_type=MovementType.VOID.value,
                reference_type="Sale",
                reference_id=sale.sale_id,
                user_id=user.user_id,
                reason=f"Voided sale {sale.receipt_number}",
            )

        credit_sale = self.credit_sales.get_by_sale_id(sale.sale_id)
        if credit_sale is not None and credit_sale.outstanding_balance > 0:
            raise InvalidOperationError(
                "Cannot void a credit sale with an outstanding balance. Settle it first."
            )

        self.audit.activity(
            activity_type="SALE_VOIDED",
            activity_desc=f"Voided sale {sale.receipt_number}",
            entity_type="Sale",
            entity_id=sale.sale_id,
            user_id=user.user_id,
        )
        self.audit.record(
            action_type="UPDATE",
            resource_type="Sale",
            resource_id=sale.sale_id,
            user_id=user.user_id,
            new_values={"status": SaleStatus.VOIDED.value, "reason": reason},
        )
        self.session.commit()
        return self.sales.get(sale.sale_id)

    # ------------------------------------------------------------------
    # Receipt
    # ------------------------------------------------------------------
    def _generate_receipt(self, sale: Sale, amount_paid: float, user: User) -> Receipt:
        change_due = _money(amount_paid - float(sale.total_amount)) if sale.sale_type == "CASH" else 0
        receipt = Receipt(
            receipt_number=sale.receipt_number,
            sale_id=sale.sale_id,
            gross_total=_money(float(sale.subtotal)),
            discount_amount=float(sale.discount_amount),
            tax_amount=float(sale.tax_amount),
            net_total=float(sale.total_amount),
            amount_paid=_money(amount_paid),
            change_due=change_due,
            generated_by=user.user_id,
        )
        self.receipts.add(receipt)
        return receipt

    def get_receipt(self, receipt_number: str) -> Receipt:
        receipt = self.receipts.get_by_number(receipt_number)
        if receipt is None:
            raise NotFoundError("Receipt not found.")
        return receipt

    # ------------------------------------------------------------------
    # Helpers
    # ------------------------------------------------------------------
    def _tax_rate(self, tax_rate_id: int | None) -> float:
        if tax_rate_id is None:
            return 0.0
        from app.repositories.catalog_repo import TaxRateRepository

        tax = TaxRateRepository(self.session).get(tax_rate_id)
        if tax is None:
            raise ValidationError_(
                "Tax rate does not exist.",
                [{"field": "tax_rate_id", "message": "Invalid tax rate"}],
            )
        return float(tax.rate_percent)

    def _compute_tax(self, subtotal: float, discount: float, tax_rate_id: int | None) -> float:
        rate = self._tax_rate(tax_rate_id)
        if rate <= 0:
            return 0.0
        taxable = subtotal - discount
        return _money(taxable * (rate / 100))

    def _notify_sale_created(self, sale: Sale, cashier: User) -> None:
        for admin in self.notification_service._admin_users():
            if admin.user_id == cashier.user_id:
                continue
            self.notification_service.notify(
                user_id=admin.user_id,
                type_code="SALE",
                title="New sale completed",
                message=f"Sale {sale.receipt_number} for {sale.total_amount:,.2f} was completed.",
                severity=NotificationSeverity.INFO.value,
                entity_type="Sale",
                entity_id=str(sale.sale_id),
            )

    def _parse_due_date(self, value: str | None) -> "object | None":
        if not value:
            return None
        try:
            return datetime.strptime(value, "%Y-%m-%d").date()
        except ValueError as exc:
            raise ValidationError_(
                "Due date must use YYYY-MM-DD format.",
                [{"field": "due_date", "message": "Invalid date format"}],
            ) from exc
