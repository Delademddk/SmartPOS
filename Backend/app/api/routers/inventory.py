"""Inventory endpoints (Feature 09)."""

from __future__ import annotations

from datetime import datetime
from typing import Annotated

from fastapi import APIRouter, Depends, Query, status
from sqlalchemy.orm import Session

from app.api.dependencies.auth import require_permission
from app.api.dependencies.database import get_db_session, get_pagination
from app.api.schemas.inventory import (
    AdjustStockRequest,
    InventoryRead,
    LowStockAlertRead,
    MovementRead,
    RestockRequest,
)
from app.core.constants import PermissionCode
from app.models.users import User
from app.services.inventory_service import InventoryService
from app.utils.pagination import PageParams
from app.utils.response import pagination_meta, success_response

router = APIRouter(prefix="/inventory", tags=["Inventory"])


@router.get("", response_model=dict)
def list_inventory(
    user: Annotated[User, Depends(require_permission(PermissionCode.INVENTORY_VIEW))],
    db: Session = Depends(get_db_session),
    page: PageParams = Depends(get_pagination),
    search: str | None = Query(default=None),
    stock_status: str | None = Query(default=None),
) -> dict:
    rows, total = InventoryService(db).list(page, search, stock_status)
    return success_response(
        [InventoryRead.model_validate(i).model_dump() for i in rows],
        meta=pagination_meta(page.page, page.page_size, total),
    )


@router.get("/product/{product_id}", response_model=dict)
def get_stock(
    product_id: int,
    user: Annotated[User, Depends(require_permission(PermissionCode.INVENTORY_VIEW))],
    db: Session = Depends(get_db_session),
) -> dict:
    return success_response(InventoryRead.model_validate(InventoryService(db).get_stock(product_id)).model_dump())


@router.get("/movements", response_model=dict)
def list_movements(
    user: Annotated[User, Depends(require_permission(PermissionCode.INVENTORY_VIEW))],
    db: Session = Depends(get_db_session),
    page: PageParams = Depends(get_pagination),
    product_id: int | None = Query(default=None),
    movement_type: str | None = Query(default=None),
    date_from: datetime | None = Query(default=None),
    date_to: datetime | None = Query(default=None),
) -> dict:
    rows, total = InventoryService(db).movements(
        page, product_id, movement_type, date_from, date_to
    )
    return success_response(
        [MovementRead.model_validate(m).model_dump() for m in rows],
        meta=pagination_meta(page.page, page.page_size, total),
    )


@router.get("/low-stock", response_model=dict)
def list_low_stock(
    user: Annotated[User, Depends(require_permission(PermissionCode.INVENTORY_VIEW))],
    db: Session = Depends(get_db_session),
    page: PageParams = Depends(get_pagination),
    status_filter: str | None = Query(default=None, alias="status"),
) -> dict:
    rows, total = InventoryService(db).low_stock_alerts(page, status_filter)
    return success_response(
        [LowStockAlertRead.model_validate(a).model_dump() for a in rows],
        meta=pagination_meta(page.page, page.page_size, total),
    )


@router.post("/restock", response_model=dict, status_code=status.HTTP_201_CREATED)
def restock(
    payload: RestockRequest,
    user: Annotated[User, Depends(require_permission(PermissionCode.INVENTORY_CREATE))],
    db: Session = Depends(get_db_session),
) -> dict:
    inventory = InventoryService(db).restock(
        product_id=payload.product_id,
        quantity=payload.quantity,
        unit_cost=payload.unit_cost,
        reason=payload.reason,
        user_id=user.user_id,
    )
    return success_response(InventoryRead.model_validate(inventory).model_dump())


@router.post("/adjust", response_model=dict, status_code=status.HTTP_201_CREATED)
def adjust_stock(
    payload: AdjustStockRequest,
    user: Annotated[User, Depends(require_permission(PermissionCode.INVENTORY_UPDATE))],
    db: Session = Depends(get_db_session),
) -> dict:
    return success_response(InventoryRead.model_validate(InventoryService(db).adjust(payload, user)).model_dump())
