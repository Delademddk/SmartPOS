"""Audit and log query endpoints (Feature 17)."""

from __future__ import annotations

from datetime import datetime
from typing import Annotated

from fastapi import APIRouter, Depends, Query, Response
from sqlalchemy.orm import Session

from app.api.dependencies.auth import require_permission
from app.api.dependencies.database import get_db_session, get_pagination
from app.api.schemas.audit import (
    ActivityLogRead,
    AuditLogRead,
    ErrorLogRead,
    SecurityLogRead,
)
from app.core.constants import PermissionCode
from app.models.users import User
from app.services.audit_log_service import AuditLogService
from app.utils.pagination import PageParams
from app.utils.response import pagination_meta, success_response

router = APIRouter(prefix="/audit", tags=["Audit Logs"])


@router.get("/logs", response_model=dict)
def list_audit_logs(
    user: Annotated[User, Depends(require_permission(PermissionCode.AUDIT_VIEW))],
    db: Session = Depends(get_db_session),
    page: PageParams = Depends(get_pagination),
    user_id: int | None = Query(default=None),
    resource_type: str | None = Query(default=None),
    action_type: str | None = Query(default=None),
    date_from: datetime | None = Query(default=None),
    date_to: datetime | None = Query(default=None),
) -> dict:
    rows, total = AuditLogService(db).list_audit_logs(
        page, user_id, resource_type, action_type, date_from, date_to
    )
    return success_response(
        [AuditLogRead.model_validate(r).model_dump() for r in rows],
        meta=pagination_meta(page.page, page.page_size, total),
    )


@router.get("/activity", response_model=dict)
def list_activity_logs(
    user: Annotated[User, Depends(require_permission(PermissionCode.AUDIT_VIEW))],
    db: Session = Depends(get_db_session),
    page: PageParams = Depends(get_pagination),
) -> dict:
    rows, total = AuditLogService(db).list_activity_logs(page)
    return success_response(
        [ActivityLogRead.model_validate(r).model_dump() for r in rows],
        meta=pagination_meta(page.page, page.page_size, total),
    )


@router.get("/security", response_model=dict)
def list_security_logs(
    user: Annotated[User, Depends(require_permission(PermissionCode.AUDIT_VIEW))],
    db: Session = Depends(get_db_session),
    page: PageParams = Depends(get_pagination),
) -> dict:
    rows, total = AuditLogService(db).list_security_logs(page)
    return success_response(
        [SecurityLogRead.model_validate(r).model_dump() for r in rows],
        meta=pagination_meta(page.page, page.page_size, total),
    )


@router.get("/errors", response_model=dict)
def list_error_logs(
    user: Annotated[User, Depends(require_permission(PermissionCode.AUDIT_VIEW))],
    db: Session = Depends(get_db_session),
    page: PageParams = Depends(get_pagination),
) -> dict:
    rows, total = AuditLogService(db).list_error_logs(page)
    return success_response(
        [ErrorLogRead.model_validate(r).model_dump() for r in rows],
        meta=pagination_meta(page.page, page.page_size, total),
    )
