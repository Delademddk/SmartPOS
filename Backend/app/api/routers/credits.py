"""Credit sales and customers endpoints (Feature 12)."""

from __future__ import annotations

from typing import Annotated

from fastapi import APIRouter, Depends, Query, status
from sqlalchemy.orm import Session

from app.api.dependencies.auth import require_permission
from app.api.dependencies.database import get_db_session, get_pagination
from app.api.schemas.credits import (
    CreditPaymentRead,
    CreditSaleRead,
    CreditSettlementRequest,
    CustomerCreate,
    CustomerRead,
    CustomerUpdate,
)
from app.core.constants import PermissionCode
from app.models.users import User
from app.services.credits_service import CreditService
from app.utils.pagination import PageParams
from app.utils.response import pagination_meta, success_response

router = APIRouter(prefix="/credits", tags=["Credit Sales"])


@router.get("/customers", response_model=dict)
def list_customers(
    user: Annotated[User, Depends(require_permission(PermissionCode.CREDIT_SALES_VIEW))],
    db: Session = Depends(get_db_session),
    page: PageParams = Depends(get_pagination),
    search: str | None = Query(default=None),
) -> dict:
    rows, total = CreditService(db).list_customers(page, search)
    return success_response(
        [CustomerRead.model_validate(c).model_dump() for c in rows],
        meta=pagination_meta(page.page, page.page_size, total),
    )


@router.post(
    "/customers",
    response_model=dict,
    status_code=status.HTTP_201_CREATED,
)
def create_customer(
    payload: CustomerCreate,
    user: Annotated[User, Depends(require_permission(PermissionCode.CREDIT_SALES_CREATE))],
    db: Session = Depends(get_db_session),
) -> dict:
    return success_response(CustomerRead.model_validate(CreditService(db).create_customer(payload, user)).model_dump())


@router.get("/customers/{customer_id}", response_model=dict)
def get_customer(
    customer_id: int,
    user: Annotated[User, Depends(require_permission(PermissionCode.CREDIT_SALES_VIEW))],
    db: Session = Depends(get_db_session),
) -> dict:
    return success_response(CustomerRead.model_validate(CreditService(db).get_customer(customer_id)).model_dump())


@router.put("/customers/{customer_id}", response_model=dict)
def update_customer(
    customer_id: int,
    payload: CustomerUpdate,
    user: Annotated[User, Depends(require_permission(PermissionCode.CREDIT_SALES_UPDATE))],
    db: Session = Depends(get_db_session),
) -> dict:
    return success_response(
        CustomerRead.model_validate(
            CreditService(db).update_customer(customer_id, payload, user)
        ).model_dump()
    )


@router.delete("/customers/{customer_id}", status_code=200)
def delete_customer(
    customer_id: int,
    user: Annotated[User, Depends(require_permission(PermissionCode.CREDIT_SALES_DELETE))],
    db: Session = Depends(get_db_session),
) -> dict:
    CreditService(db).delete_customer(customer_id, user)
    return success_response({"message": "Customer deleted successfully."})


@router.get("", response_model=dict)
def list_credit_sales(
    user: Annotated[User, Depends(require_permission(PermissionCode.CREDIT_SALES_VIEW))],
    db: Session = Depends(get_db_session),
    page: PageParams = Depends(get_pagination),
    customer_id: int | None = Query(default=None),
    status_filter: str | None = Query(default=None, alias="status"),
) -> dict:
    rows, total = CreditService(db).list_credit_sales(page, customer_id, status_filter)
    return success_response(
        [CreditSaleRead.model_validate(c).model_dump() for c in rows],
        meta=pagination_meta(page.page, page.page_size, total),
    )


@router.get("/{credit_sale_id}", response_model=dict)
def get_credit_sale(
    credit_sale_id: int,
    user: Annotated[User, Depends(require_permission(PermissionCode.CREDIT_SALES_VIEW))],
    db: Session = Depends(get_db_session),
) -> dict:
    return success_response(CreditSaleRead.model_validate(CreditService(db).get_credit_sale(credit_sale_id)).model_dump())


@router.post("/{credit_sale_id}/settle", response_model=dict)
def settle_credit_sale(
    credit_sale_id: int,
    payload: CreditSettlementRequest,
    user: Annotated[User, Depends(require_permission(PermissionCode.CREDIT_SALES_UPDATE))],
    db: Session = Depends(get_db_session),
) -> dict:
    return success_response(
        CreditSaleRead.model_validate(
            CreditService(db).settle(credit_sale_id, payload, user)
        ).model_dump()
    )


@router.get("/{credit_sale_id}/payments", response_model=dict)
def credit_payment_history(
    credit_sale_id: int,
    user: Annotated[User, Depends(require_permission(PermissionCode.CREDIT_SALES_VIEW))],
    db: Session = Depends(get_db_session),
) -> dict:
    rows = CreditService(db).payment_history(credit_sale_id)
    return success_response([CreditPaymentRead.model_validate(p).model_dump() for p in rows])
