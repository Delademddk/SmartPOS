"""Payments service (Feature 11)."""

from __future__ import annotations

from app.exceptions import NotFoundError, ValidationError_
from app.models.payments import PaymentMethod
from app.models.users import User
from app.repositories.ops_repo import (
    PaymentMethodRepository,
    PaymentRepository,
    SaleRepository,
)
from app.services.audit_service import AuditService
from app.services.base import BaseService
from app.utils.pagination import PageParams


class PaymentService(BaseService):
    service_name = "payments"

    def __init__(self, session) -> None:  # noqa: ANN001
        super().__init__(session)
        self.payments = PaymentRepository(session)
        self.methods = PaymentMethodRepository(session)
        self.sales = SaleRepository(session)
        self.audit = AuditService(session)

    # ------------------------------------------------------------------
    def list_methods(self) -> list[PaymentMethod]:
        return self.methods.list_all()

    def get_method(self, method_id: int) -> PaymentMethod:
        method = self.methods.get(method_id)
        if method is None:
            raise NotFoundError("Payment method not found.")
        return method

    def get_method_by_code(self, code: str) -> PaymentMethod:
        method = self.methods.get_by_code(code)
        if method is None:
            raise NotFoundError("Payment method not found.")
        return method

    def list_for_sale(self, sale_id: int) -> list:
        return self.payments.list_for_sale(sale_id)

    def list(
        self,
        page: PageParams,
        sale_id: int | None,
        method_id: int | None,
    ) -> tuple[list, int]:
        filters = []
        if sale_id:
            filters.append(self.payments.model.sale_id == sale_id)
        if method_id:
            filters.append(self.payments.model.payment_method_id == method_id)

        all_payments = self.payments.list_all()
        filtered = [p for p in all_payments if p.sale_id == (sale_id or p.sale_id) and p.payment_method_id == (method_id or p.payment_method_id)]
        if sale_id is None and method_id is None:
            filtered = all_payments
        total = len(filtered)
        start = (page.page - 1) * page.page_size
        return filtered[start : start + page.page_size], total

    def _validate_method(self, method_id: int) -> PaymentMethod:
        method = self.get_method(method_id)
        if not method.is_active:
            raise ValidationError_(
                "Payment method is inactive.",
                [{"field": "payment_method_id", "message": "Method inactive"}],
            )
        return method
