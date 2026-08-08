"""Returns service (Feature 13).

Processes returns against sale items, restores inventory, marks returned
quantities and records the refund.
"""

from __future__ import annotations

from decimal import ROUND_HALF_UP, Decimal

from app.api.schemas.returns import ReturnCreate
from app.core.constants import MovementType, ReturnStatus, SaleStatus
from app.database.base import utcnow
from app.exceptions import (
    BadRequestError,
    InvalidOperationError,
    NotFoundError,
    ReturnLimitExceededError,
    ValidationError_,
)
from app.models.returns import Return as ReturnHeader
from app.models.returns import ReturnItem, ReturnReason
from app.models.sales import Sale, SaleItem
from app.models.users import User
from app.repositories.ops_repo import (
    ReturnItemRepository,
    ReturnReasonRepository,
    ReturnRepository,
    SaleItemRepository,
    SaleRepository,
)
from app.services.audit_service import AuditService
from app.services.base import BaseService
from app.services.inventory_service import InventoryService
from app.utils.numbers import generate_return_number
from app.utils.pagination import PageParams


def _money(value: float) -> float:
    return float(Decimal(str(value)).quantize(Decimal("0.0001"), rounding=ROUND_HALF_UP))


class ReturnService(BaseService):
    service_name = "returns"

    def __init__(self, session) -> None:  # noqa: ANN001
        super().__init__(session)
        self.returns = ReturnRepository(session)
        self.return_items = ReturnItemRepository(session)
        self.reasons = ReturnReasonRepository(session)
        self.sales = SaleRepository(session)
        self.sale_items = SaleItemRepository(session)
        self.inventory_service = InventoryService(session)
        self.audit = AuditService(session)

    # ------------------------------------------------------------------
    def list(
        self,
        page: PageParams,
        sale_id: int | None,
        status: str | None,
    ) -> tuple[list[ReturnHeader], int]:
        return self.returns.list_filtered(
            sale_id=sale_id,
            status=status,
            page=page.page,
            page_size=page.page_size,
        )

    def get(self, return_id: int) -> ReturnHeader:
        return_header = self.returns.get(return_id)
        if return_header is None:
            raise NotFoundError("Return not found.")
        return return_header

    def list_reasons(self) -> list[ReturnReason]:
        return [r for r in self.reasons.list_all() if r.is_active]

    # ------------------------------------------------------------------
    def process(self, payload: ReturnCreate, user: User) -> ReturnHeader:
        sale = self.sales.get(payload.sale_id)
        if sale is None:
            raise NotFoundError("Sale not found.")
        if sale.status != SaleStatus.COMPLETED.value:
            raise InvalidOperationError("Only completed sales can be returned.")

        if payload.return_reason_id is not None:
            reason = self.reasons.get(payload.return_reason_id)
            if reason is None or not reason.is_active:
                raise ValidationError_(
                    "Return reason does not exist.",
                    [{"field": "return_reason_id", "message": "Invalid reason"}],
                )

        sale_items_by_id = {item.sale_item_id: item for item in sale.items}

        return_header = ReturnHeader(
            return_number=generate_return_number(),
            sale_id=sale.sale_id,
            customer_id=sale.customer_id,
            user_id=user.user_id,
            return_reason_id=payload.return_reason_id,
            status=ReturnStatus.COMPLETED.value,
            notes=payload.notes,
        )
        self.returns.add(return_header)
        self.session.flush()

        total_refund = 0.0
        for line in payload.items:
            item = sale_items_by_id.get(line.sale_item_id)
            if item is None:
                raise ValidationError_(
                    f"Sale item {line.sale_item_id} does not belong to this sale.",
                    [{"field": "items", "message": "Invalid sale_item_id"}],
                )
            available = float(item.quantity) - float(item.returned_qty)
            if line.quantity > available:
                raise ReturnLimitExceededError(
                    f"Cannot return more than {available:g} of sale item {item.sale_item_id}."
                )

            refund_amount = _money(line.quantity * float(item.line_total) / float(item.quantity))
            total_refund += refund_amount

            item.returned_qty = float(item.returned_qty) + line.quantity
            if float(item.returned_qty) >= float(item.quantity):
                item.is_returned = True

            self.return_items.add(
                ReturnItem(
                    return_id=return_header.return_id,
                    sale_item_id=item.sale_item_id,
                    product_id=item.product_id,
                    quantity=line.quantity,
                    unit_price=float(item.unit_price),
                    refund_amount=refund_amount,
                )
            )
            self.inventory_service.restore_stock(
                product_id=item.product_id,
                quantity=line.quantity,
                movement_type=MovementType.RETURN.value,
                reference_type="Return",
                reference_id=return_header.return_id,
                user_id=user.user_id,
                reason=f"Return {return_header.return_number}",
            )

        return_header.total_refund_amount = _money(total_refund)

        if all(item.is_returned for item in sale.items) and total_refund >= float(sale.total_amount):
            sale.status = SaleStatus.REFUNDED.value
            sale.updated_at = utcnow()

        self.audit.activity(
            activity_type="RETURN_PROCESSED",
            activity_desc=f"Processed return {return_header.return_number} for {total_refund:,.2f}",
            entity_type="Return",
            entity_id=return_header.return_id,
            user_id=user.user_id,
        )
        self.audit.record(
            action_type="INSERT",
            resource_type="Return",
            resource_id=return_header.return_id,
            user_id=user.user_id,
            new_values={
                "return_number": return_header.return_number,
                "total_refund_amount": total_refund,
                "sale_id": sale.sale_id,
            },
        )
        self.session.commit()
        return self.returns.get(return_header.return_id)
