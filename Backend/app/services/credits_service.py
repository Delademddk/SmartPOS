"""Credit sales service (Feature 12): customers, balances, settlement."""

from __future__ import annotations

from datetime import date, datetime

from app.api.schemas.credits import (
    CreditSettlementRequest,
    CustomerCreate,
    CustomerUpdate,
)
from app.core.constants import CreditStatus
from app.database.base import utcnow
from app.exceptions import (
    BadRequestError,
    DuplicateResourceError,
    NotFoundError,
    ValidationError_,
)
from app.models.credits import CreditPayment, CreditSale, Customer
from app.models.users import User
from app.repositories.ops_repo import (
    CreditPaymentRepository,
    CreditSaleRepository,
    CustomerRepository,
    PaymentMethodRepository,
    PaymentRepository,
)
from app.services.audit_service import AuditService
from app.services.base import BaseService
from app.utils.pagination import PageParams


class CreditService(BaseService):
    service_name = "credits"

    def __init__(self, session) -> None:  # noqa: ANN001
        super().__init__(session)
        self.customers = CustomerRepository(session)
        self.credit_sales = CreditSaleRepository(session)
        self.credit_payments = CreditPaymentRepository(session)
        self.payments = PaymentRepository(session)
        self.methods = PaymentMethodRepository(session)
        self.audit = AuditService(session)

    # ------------------------------------------------------------------
    # Customers
    # ------------------------------------------------------------------
    def list_customers(self, page: PageParams, search: str | None) -> tuple[list[Customer], int]:
        return self.customers.search(search=search, page=page.page, page_size=page.page_size)

    def get_customer(self, customer_id: int) -> Customer:
        customer = self.customers.get(customer_id)
        if customer is None or customer.is_deleted:
            raise NotFoundError("Customer not found.")
        return customer

    def create_customer(self, payload: CustomerCreate, actor: User) -> Customer:
        if self.customers.get_by_code(payload.customer_code):
            raise DuplicateResourceError("Customer code already exists.", resource_type="Customer")
        customer = Customer(**payload.model_dump(), created_by=actor.user_id, updated_by=actor.user_id)
        self.customers.add(customer)
        self.audit.activity(
            activity_type="CUSTOMER_CREATED",
            activity_desc=f"Created customer {customer.full_name}",
            entity_type="Customer",
            entity_id=customer.customer_id,
            user_id=actor.user_id,
        )
        self.session.commit()
        return self.customers.get(customer.customer_id)

    def update_customer(self, customer_id: int, payload: CustomerUpdate, actor: User) -> Customer:
        customer = self.get_customer(customer_id)
        data = payload.model_dump(exclude_unset=True)
        for field, value in data.items():
            if value is not None:
                setattr(customer, field, value)
        customer.updated_by = actor.user_id
        self.audit.activity(
            activity_type="CUSTOMER_UPDATED",
            activity_desc=f"Updated customer {customer.full_name}",
            entity_type="Customer",
            entity_id=customer.customer_id,
            user_id=actor.user_id,
        )
        self.session.commit()
        return self.customers.get(customer.customer_id)

    def delete_customer(self, customer_id: int, actor: User) -> None:
        customer = self.get_customer(customer_id)
        customer.is_deleted = True
        customer.is_active = False
        customer.deleted_at = utcnow()
        self.audit.activity(
            activity_type="CUSTOMER_DELETED",
            activity_desc=f"Deleted customer {customer.full_name}",
            entity_type="Customer",
            entity_id=customer.customer_id,
            user_id=actor.user_id,
        )
        self.session.commit()

    # ------------------------------------------------------------------
    # Credit sales & settlement
    # ------------------------------------------------------------------
    def list_credit_sales(
        self,
        page: PageParams,
        customer_id: int | None,
        status: str | None,
    ) -> tuple[list[CreditSale], int]:
        return self.credit_sales.list_filtered(
            customer_id=customer_id,
            status=status,
            page=page.page,
            page_size=page.page_size,
        )

    def get_credit_sale(self, credit_sale_id: int) -> CreditSale:
        credit_sale = self.credit_sales.get(credit_sale_id)
        if credit_sale is None:
            raise NotFoundError("Credit sale not found.")
        return credit_sale

    def create_from_sale(
        self,
        *,
        sale_id: int,
        customer_id: int,
        total_amount: float,
        amount_paid: float,
        due_date: date | None,
    ) -> CreditSale:
        customer = self.get_customer(customer_id)
        outstanding = total_amount - amount_paid
        if outstanding < 0:
            raise ValidationError_(
                "Amount paid cannot exceed the sale total.",
                [{"field": "amount_paid", "message": "Exceeds total"}],
            )

        current_balance = self.customers.outstanding_balance(customer_id)
        if outstanding + current_balance > customer.credit_limit:
            raise BadRequestError(
                "This credit sale would exceed the customer's credit limit."
            )

        status = CreditStatus.SETTLED.value if outstanding <= 0 else CreditStatus.OPEN.value
        credit_sale = CreditSale(
            sale_id=sale_id,
            customer_id=customer_id,
            total_amount=total_amount,
            amount_paid=amount_paid,
            outstanding_balance=outstanding,
            due_date=due_date,
            status=status,
        )
        self.credit_sales.add(credit_sale)
        return credit_sale

    def settle(self, credit_sale_id: int, payload: CreditSettlementRequest, user: User) -> CreditSale:
        credit_sale = self.get_credit_sale(credit_sale_id)
        if credit_sale.status in (CreditStatus.SETTLED.value, CreditStatus.WRITTEN_OFF.value):
            raise BadRequestError("This credit sale is already settled.")

        amount = payload.amount
        if amount > credit_sale.outstanding_balance:
            raise ValidationError_(
                "Payment exceeds the outstanding balance.",
                [{"field": "amount", "message": "Exceeds outstanding balance"}],
            )

        credit_sale.amount_paid = float(credit_sale.amount_paid) + amount
        credit_sale.outstanding_balance = float(credit_sale.outstanding_balance) - amount
        if credit_sale.outstanding_balance <= 0:
            credit_sale.status = CreditStatus.SETTLED.value
        else:
            credit_sale.status = CreditStatus.PARTIAL.value
        credit_sale.updated_at = utcnow()

        payment_id = None
        if payload.payment_method_id:
            method = self.methods.get(payload.payment_method_id)
            if method is None:
                raise NotFoundError("Payment method not found.")
            payment = self.payments.add(
                self.payments.model(
                    sale_id=credit_sale.sale_id,
                    payment_method_id=method.payment_method_id,
                    amount=amount,
                    reference_number=payload.payment_id and str(payload.payment_id) or None,
                    received_by=user.user_id,
                    pay_status="COMPLETED",
                    notes=payload.notes,
                )
            )
            self.session.flush()
            payment_id = payment.payment_id

        self.credit_payments.add(
            CreditPayment(
                credit_sale_id=credit_sale.credit_sale_id,
                payment_id=payment_id,
                amount=amount,
                received_by=user.user_id,
                notes=payload.notes,
            )
        )
        self.audit.activity(
            activity_type="CREDIT_SETTLED",
            activity_desc=f"Settled {amount} against credit sale {credit_sale.credit_sale_id}",
            entity_type="CreditSale",
            entity_id=credit_sale.credit_sale_id,
            user_id=user.user_id,
        )
        self.audit.record(
            action_type="UPDATE",
            resource_type="CreditSale",
            resource_id=credit_sale.credit_sale_id,
            user_id=user.user_id,
            new_values={"outstanding_balance": float(credit_sale.outstanding_balance)},
        )
        self.session.commit()
        return self.credit_sales.get(credit_sale.credit_sale_id)

    def payment_history(self, credit_sale_id: int) -> list[CreditPayment]:
        self.get_credit_sale(credit_sale_id)
        return [
            p
            for p in self.credit_payments.list_all()
            if p.credit_sale_id == credit_sale_id
        ]
