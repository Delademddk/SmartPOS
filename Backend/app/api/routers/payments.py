"""Payment method and payment record endpoints (Feature 11)."""

from __future__ import annotations

from typing import Annotated

from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from app.api.dependencies.auth import require_permission
from app.api.dependencies.database import get_db_session, get_pagination
from app.api.schemas.sales import PaymentRead
from app.core.constants import PermissionCode
from app.models.payments import PaymentMethod
from app.models.users import User
from app.services.payments_service import PaymentService
from app.utils.pagination import PageParams
from app.utils.response import pagination_meta, success_response

router = APIRouter(prefix="/payments", tags=["Payments"])


@router.get("/methods", response_model=dict)
def list_payment_methods(
    user: Annotated[User, Depends(require_permission(PermissionCode.PAYMENTS_VIEW))],
    db: Session = Depends(get_db_session),
) -> dict:
    methods: list[PaymentMethod] = PaymentService(db).list_methods()
    return success_response(
        [
            {
                "payment_method_id": m.payment_method_id,
                "method_code": m.method_code,
                "method_name": m.method_name,
                "is_cash": m.is_cash,
                "is_active": m.is_active,
                "sort_order": m.sort_order,
            }
            for m in methods
        ]
    )


@router.get("", response_model=dict)
def list_payments(
    user: Annotated[User, Depends(require_permission(PermissionCode.PAYMENTS_VIEW))],
    db: Session = Depends(get_db_session),
    page: PageParams = Depends(get_pagination),
    sale_id: int | None = Query(default=None),
    method_id: int | None = Query(default=None),
) -> dict:
    rows, total = PaymentService(db).list(page, sale_id, method_id)
    return success_response(
        [PaymentRead.model_validate(p).model_dump() for p in rows],
        meta=pagination_meta(page.page, page.page_size, total),
    )


@router.get("/sale/{sale_id}", response_model=dict)
def list_sale_payments(
    sale_id: int,
    user: Annotated[User, Depends(require_permission(PermissionCode.PAYMENTS_VIEW))],
    db: Session = Depends(get_db_session),
) -> dict:
    rows = PaymentService(db).list_for_sale(sale_id)
    return success_response([PaymentRead.model_validate(p).model_dump() for p in rows])
