"""Supplier endpoints (Feature 08)."""

from __future__ import annotations

from typing import Annotated

from fastapi import APIRouter, Depends, Query, status
from sqlalchemy.orm import Session

from app.api.dependencies.auth import require_permission
from app.api.dependencies.database import get_db_session, get_pagination
from app.api.schemas.suppliers import (
    SupplierContactCreate,
    SupplierContactRead,
    SupplierContactUpdate,
    SupplierCreate,
    SupplierDetail,
    SupplierHistoryRead,
    SupplierRead,
    SupplierUpdate,
)
from app.core.constants import PermissionCode
from app.models.users import User
from app.services.suppliers_service import SupplierService
from app.utils.pagination import PageParams
from app.utils.response import pagination_meta, success_response

router = APIRouter(prefix="/suppliers", tags=["Suppliers"])


@router.get("", response_model=dict)
def list_suppliers(
    user: Annotated[User, Depends(require_permission(PermissionCode.SUPPLIERS_VIEW))],
    db: Session = Depends(get_db_session),
    page: PageParams = Depends(get_pagination),
    search: str | None = Query(default=None),
    is_active: bool | None = Query(default=None),
) -> dict:
    rows, total = SupplierService(db).list(page, search, is_active)
    return success_response(
        [SupplierRead.model_validate(s).model_dump() for s in rows],
        meta=pagination_meta(page.page, page.page_size, total),
    )


@router.post("", response_model=dict, status_code=status.HTTP_201_CREATED)
def create_supplier(
    payload: SupplierCreate,
    user: Annotated[User, Depends(require_permission(PermissionCode.SUPPLIERS_CREATE))],
    db: Session = Depends(get_db_session),
) -> dict:
    return success_response(SupplierRead.model_validate(SupplierService(db).create(payload, user)).model_dump())


@router.get("/{supplier_id}", response_model=dict)
def get_supplier(
    supplier_id: int,
    user: Annotated[User, Depends(require_permission(PermissionCode.SUPPLIERS_VIEW))],
    db: Session = Depends(get_db_session),
) -> dict:
    supplier = SupplierService(db).get(supplier_id)
    detail = SupplierDetail(
        **SupplierRead.model_validate(supplier).model_dump(),
        contacts=[SupplierContactRead.model_validate(c).model_dump() for c in supplier.contacts],
    )
    return success_response(detail.model_dump())


@router.put("/{supplier_id}", response_model=dict)
def update_supplier(
    supplier_id: int,
    payload: SupplierUpdate,
    user: Annotated[User, Depends(require_permission(PermissionCode.SUPPLIERS_UPDATE))],
    db: Session = Depends(get_db_session),
) -> dict:
    return success_response(SupplierRead.model_validate(SupplierService(db).update(supplier_id, payload, user)).model_dump())


@router.delete("/{supplier_id}", status_code=200)
def delete_supplier(
    supplier_id: int,
    user: Annotated[User, Depends(require_permission(PermissionCode.SUPPLIERS_DELETE))],
    db: Session = Depends(get_db_session),
) -> dict:
    SupplierService(db).delete(supplier_id, user)
    return success_response({"message": "Supplier deleted successfully."})


@router.get("/{supplier_id}/contacts", response_model=dict)
def list_supplier_contacts(
    supplier_id: int,
    user: Annotated[User, Depends(require_permission(PermissionCode.SUPPLIERS_VIEW))],
    db: Session = Depends(get_db_session),
) -> dict:
    service = SupplierService(db)
    service.get(supplier_id)
    contacts = [
        c
        for c in service.contacts.list_all()
        if c.supplier_id == supplier_id and c.is_active
    ]
    return success_response([SupplierContactRead.model_validate(c).model_dump() for c in contacts])


@router.post(
    "/{supplier_id}/contacts",
    response_model=dict,
    status_code=status.HTTP_201_CREATED,
)
def add_supplier_contact(
    supplier_id: int,
    payload: SupplierContactCreate,
    user: Annotated[User, Depends(require_permission(PermissionCode.SUPPLIERS_UPDATE))],
    db: Session = Depends(get_db_session),
) -> dict:
    return success_response(
        SupplierContactRead.model_validate(
            SupplierService(db).add_contact(supplier_id, payload, user)
        ).model_dump()
    )


@router.put("/{supplier_id}/contacts/{contact_id}", response_model=dict)
def update_supplier_contact(
    supplier_id: int,
    contact_id: int,
    payload: SupplierContactUpdate,
    user: Annotated[User, Depends(require_permission(PermissionCode.SUPPLIERS_UPDATE))],
    db: Session = Depends(get_db_session),
) -> dict:
    return success_response(
        SupplierContactRead.model_validate(
            SupplierService(db).update_contact(supplier_id, contact_id, payload, user)
        ).model_dump()
    )


@router.delete("/{supplier_id}/contacts/{contact_id}", status_code=200)
def delete_supplier_contact(
    supplier_id: int,
    contact_id: int,
    user: Annotated[User, Depends(require_permission(PermissionCode.SUPPLIERS_UPDATE))],
    db: Session = Depends(get_db_session),
) -> dict:
    SupplierService(db).delete_contact(supplier_id, contact_id, user)
    return success_response({"message": "Contact removed successfully."})


@router.get("/{supplier_id}/history", response_model=dict)
def list_supplier_history(
    supplier_id: int,
    user: Annotated[User, Depends(require_permission(PermissionCode.SUPPLIERS_VIEW))],
    db: Session = Depends(get_db_session),
    page: PageParams = Depends(get_pagination),
) -> dict:
    rows, total = SupplierService(db).list_history(supplier_id, page)
    return success_response(
        [SupplierHistoryRead.model_validate(h).model_dump() for h in rows],
        meta=pagination_meta(page.page, page.page_size, total),
    )
