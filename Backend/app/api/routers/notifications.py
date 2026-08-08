"""Notification endpoints (Feature 14)."""

from __future__ import annotations

from typing import Annotated

from fastapi import APIRouter, Depends, Query, status
from sqlalchemy.orm import Session

from app.api.dependencies.auth import get_current_user, require_permission
from app.api.dependencies.database import get_db_session, get_pagination
from app.api.schemas.notifications import (
    NotificationCreate,
    NotificationRead,
    NotificationTypeRead,
)
from app.core.constants import PermissionCode
from app.models.users import User
from app.services.notifications_service import NotificationService
from app.utils.pagination import PageParams
from app.utils.response import pagination_meta, success_response

router = APIRouter(prefix="/notifications", tags=["Notifications"])


@router.get("/types", response_model=dict)
def list_notification_types(
    user: Annotated[User, Depends(get_current_user)],
    db: Session = Depends(get_db_session),
) -> dict:
    return success_response(
        [
            NotificationTypeRead.model_validate(t).model_dump()
            for t in NotificationService(db).list_types()
        ]
    )


@router.get("", response_model=dict)
def list_notifications(
    user: Annotated[User, Depends(get_current_user)],
    db: Session = Depends(get_db_session),
    page: PageParams = Depends(get_pagination),
    is_read: bool | None = Query(default=None),
) -> dict:
    rows, total = NotificationService(db).list_for_user(user, page, is_read)
    return success_response(
        [NotificationRead.model_validate(n).model_dump() for n in rows],
        meta=pagination_meta(page.page, page.page_size, total),
    )


@router.get("/unread-count", response_model=dict)
def unread_count(
    user: Annotated[User, Depends(get_current_user)],
    db: Session = Depends(get_db_session),
) -> dict:
    return success_response({"unread_count": NotificationService(db).unread_count(user)})


@router.get("/{notification_id}", response_model=dict)
def get_notification(
    notification_id: int,
    user: Annotated[User, Depends(get_current_user)],
    db: Session = Depends(get_db_session),
) -> dict:
    return success_response(
        NotificationRead.model_validate(
            NotificationService(db).get_for_user(user, notification_id)
        ).model_dump()
    )


@router.post("/{notification_id}/read", response_model=dict)
def mark_notification_read(
    notification_id: int,
    user: Annotated[User, Depends(get_current_user)],
    db: Session = Depends(get_db_session),
) -> dict:
    return success_response(
        NotificationRead.model_validate(
            NotificationService(db).mark_read(user, notification_id)
        ).model_dump()
    )


@router.post("/{notification_id}/dismiss", response_model=dict)
def dismiss_notification(
    notification_id: int,
    user: Annotated[User, Depends(get_current_user)],
    db: Session = Depends(get_db_session),
) -> dict:
    return success_response(
        NotificationRead.model_validate(
            NotificationService(db).mark_dismissed(user, notification_id)
        ).model_dump()
    )


@router.post("/mark-all-read", response_model=dict)
def mark_all_read(
    user: Annotated[User, Depends(get_current_user)],
    db: Session = Depends(get_db_session),
) -> dict:
    count = NotificationService(db).mark_all_read(user)
    return success_response({"message": f"{count} notification(s) marked as read."})


@router.post(
    "",
    response_model=dict,
    status_code=status.HTTP_201_CREATED,
)
def create_notification(
    payload: NotificationCreate,
    user: Annotated[User, Depends(require_permission(PermissionCode.NOTIFICATIONS_CREATE))],
    db: Session = Depends(get_db_session),
) -> dict:
    return success_response(
        NotificationRead.model_validate(
            NotificationService(db).create(payload, user)
        ).model_dump()
    )
