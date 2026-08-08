"""Returns endpoints (Feature 13)."""

from __future__ import annotations

from typing import Annotated

from fastapi import APIRouter, Depends, Query, status
from sqlalchemy.orm import Session

from app.api.dependencies.auth import require_permission
from app.api.dependencies.database import get_db_session, get_pagination
from app.api.schemas.returns import (
    ReturnCreate,
    ReturnRead,
    ReturnReasonRead,
)
from app.core.constants import PermissionCode
from app.models.users import User
from app.services.returns_service import ReturnService
from app.utils.pagination import PageParams
from app.utils.response import pagination_meta, success_response

router = APIRouter(prefix="/returns", tags=["Returns"])


@router.get("/reasons", response_model=dict)
def list_return_reasons(
    user: Annotated[User, Depends(require_permission(PermissionCode.RETURNS_VIEW))],
    db: Session = Depends(get_db_session),
) -> dict:
    return success_response(
        [ReturnReasonRead.model_validate(r).model_dump() for r in ReturnService(db).list_reasons()]
    )


@router.get("", response_model=dict)
def list_returns(
    user: Annotated[User, Depends(require_permission(PermissionCode.RETURNS_VIEW))],
    db: Session = Depends(get_db_session),
    page: PageParams = Depends(get_pagination),
    sale_id: int | None = Query(default=None),
    status_filter: str | None = Query(default=None, alias="status"),
) -> dict:
    rows, total = ReturnService(db).list(page, sale_id, status_filter)
    return success_response(
        [ReturnRead.model_validate(r).model_dump() for r in rows],
        meta=pagination_meta(page.page, page.page_size, total),
    )


@router.post("", response_model=dict, status_code=status.HTTP_201_CREATED)
def process_return(
    payload: ReturnCreate,
    user: Annotated[User, Depends(require_permission(PermissionCode.RETURNS_CREATE))],
    db: Session = Depends(get_db_session),
) -> dict:
    return success_response(ReturnRead.model_validate(ReturnService(db).process(payload, user)).model_dump())


@router.get("/{return_id}", response_model=dict)
def get_return(
    return_id: int,
    user: Annotated[User, Depends(require_permission(PermissionCode.RETURNS_VIEW))],
    db: Session = Depends(get_db_session),
) -> dict:
    return success_response(ReturnRead.model_validate(ReturnService(db).get(return_id)).model_dump())
