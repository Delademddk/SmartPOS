"""Sales endpoints (Feature 10)."""

from __future__ import annotations

from datetime import datetime
from typing import Annotated

from fastapi import APIRouter, Depends, Query, status
from sqlalchemy.orm import Session

from app.api.dependencies.auth import get_current_user, require_permission
from app.api.dependencies.database import get_db_session, get_pagination
from app.api.schemas.sales import (
    SaleCreate,
    SaleRead,
    VoidSaleRequest,
)
from app.core.constants import PermissionCode
from app.models.users import User
from app.services.sales_service import SalesService
from app.utils.pagination import PageParams
from app.utils.response import pagination_meta, success_response

router = APIRouter(prefix="/sales", tags=["Sales"])


@router.get("", response_model=dict)
def list_sales(
    user: Annotated[User, Depends(require_permission(PermissionCode.SALES_VIEW))],
    db: Session = Depends(get_db_session),
    page: PageParams = Depends(get_pagination),
    search: str | None = Query(default=None),
    status_filter: str | None = Query(default=None, alias="status"),
    sale_type: str | None = Query(default=None),
    user_id: int | None = Query(default=None),
    customer_id: int | None = Query(default=None),
    date_from: datetime | None = Query(default=None),
    date_to: datetime | None = Query(default=None),
) -> dict:
    rows, total = SalesService(db).list(
        page, search, status_filter, sale_type, user_id, customer_id, date_from, date_to
    )
    return success_response(
        [SaleRead.model_validate(s).model_dump() for s in rows],
        meta=pagination_meta(page.page, page.page_size, total),
    )


@router.post("", response_model=dict, status_code=status.HTTP_201_CREATED)
def create_sale(
    payload: SaleCreate,
    user: Annotated[User, Depends(require_permission(PermissionCode.SALES_CREATE))],
    db: Session = Depends(get_db_session),
) -> dict:
    return success_response(SaleRead.model_validate(SalesService(db).create_sale(payload, user)).model_dump())


@router.get("/my-sales", response_model=dict)
def my_sales(
    user: Annotated[User, Depends(get_current_user)],
    db: Session = Depends(get_db_session),
    page: PageParams = Depends(get_pagination),
) -> dict:
    rows, total = SalesService(db).my_sales(user, page)
    return success_response(
        [SaleRead.model_validate(s).model_dump() for s in rows],
        meta=pagination_meta(page.page, page.page_size, total),
    )


@router.get("/by-receipt/{receipt_number}", response_model=dict)
def get_sale_by_receipt(
    receipt_number: str,
    user: Annotated[User, Depends(require_permission(PermissionCode.SALES_VIEW))],
    db: Session = Depends(get_db_session),
) -> dict:
    return success_response(SaleRead.model_validate(SalesService(db).get_by_receipt(receipt_number)).model_dump())


@router.get("/{sale_id}", response_model=dict)
def get_sale(
    sale_id: int,
    user: Annotated[User, Depends(require_permission(PermissionCode.SALES_VIEW))],
    db: Session = Depends(get_db_session),
) -> dict:
    return success_response(SaleRead.model_validate(SalesService(db).get(sale_id)).model_dump())


@router.post("/{sale_id}/void", response_model=dict)
def void_sale(
    sale_id: int,
    payload: VoidSaleRequest,
    user: Annotated[User, Depends(require_permission(PermissionCode.SALES_UPDATE))],
    db: Session = Depends(get_db_session),
) -> dict:
    return success_response(SaleRead.model_validate(SalesService(db).void_sale(sale_id, user, payload.reason)).model_dump())


@router.get("/{sale_id}/receipt", response_model=dict)
def get_sale_receipt(
    sale_id: int,
    user: Annotated[User, Depends(require_permission(PermissionCode.SALES_VIEW))],
    db: Session = Depends(get_db_session),
) -> dict:
    service = SalesService(db)
    sale = service.get(sale_id)
    return success_response(service.receipt_view(sale.receipt_number))
