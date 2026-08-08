"""Category endpoints (Feature 06)."""

from __future__ import annotations

from typing import Annotated

from fastapi import APIRouter, Depends, Query, status
from sqlalchemy.orm import Session

from app.api.dependencies.auth import require_permission
from app.api.dependencies.database import get_db_session, get_pagination
from app.api.schemas.categories import CategoryCreate, CategoryRead, CategoryUpdate
from app.core.constants import PermissionCode
from app.models.users import User
from app.services.categories_service import CategoryService
from app.utils.pagination import PageParams
from app.utils.response import pagination_meta, success_response

router = APIRouter(prefix="/categories", tags=["Categories"])


@router.get("", response_model=dict)
def list_categories(
    user: Annotated[User, Depends(require_permission(PermissionCode.CATEGORIES_VIEW))],
    db: Session = Depends(get_db_session),
    page: PageParams = Depends(get_pagination),
    search: str | None = Query(default=None),
    parent_id: int | None = Query(default=None),
    is_active: bool | None = Query(default=None),
) -> dict:
    rows, total = CategoryService(db).list(page, search, parent_id, is_active)
    return success_response(
        [CategoryRead.model_validate(c).model_dump() for c in rows],
        meta=pagination_meta(page.page, page.page_size, total),
    )


@router.get("/{category_id}", response_model=dict)
def get_category(
    category_id: int,
    user: Annotated[User, Depends(require_permission(PermissionCode.CATEGORIES_VIEW))],
    db: Session = Depends(get_db_session),
) -> dict:
    return success_response(CategoryRead.model_validate(CategoryService(db).get(category_id)).model_dump())


@router.post("", response_model=dict, status_code=status.HTTP_201_CREATED)
def create_category(
    payload: CategoryCreate,
    user: Annotated[User, Depends(require_permission(PermissionCode.CATEGORIES_CREATE))],
    db: Session = Depends(get_db_session),
) -> dict:
    return success_response(CategoryRead.model_validate(CategoryService(db).create(payload, user)).model_dump())


@router.put("/{category_id}", response_model=dict)
def update_category(
    category_id: int,
    payload: CategoryUpdate,
    user: Annotated[User, Depends(require_permission(PermissionCode.CATEGORIES_UPDATE))],
    db: Session = Depends(get_db_session),
) -> dict:
    return success_response(CategoryRead.model_validate(CategoryService(db).update(category_id, payload, user)).model_dump())


@router.delete("/{category_id}", status_code=200)
def delete_category(
    category_id: int,
    user: Annotated[User, Depends(require_permission(PermissionCode.CATEGORIES_DELETE))],
    db: Session = Depends(get_db_session),
) -> dict:
    CategoryService(db).delete(category_id, user)
    return success_response({"message": "Category deleted successfully."})
