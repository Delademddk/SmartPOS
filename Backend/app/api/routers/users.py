"""User management endpoints (Feature 04)."""

from __future__ import annotations

from typing import Annotated

from fastapi import APIRouter, Depends, Query, status
from sqlalchemy.orm import Session

from app.api.dependencies.auth import get_current_user, require_permission
from app.api.dependencies.database import get_db_session, get_pagination
from app.api.schemas.users import (
    ProfileUpdate,
    ResetPasswordRequest,
    UserCreate,
    UserRead,
    UserUpdate,
)
from app.core.constants import PermissionCode
from app.models.users import User
from app.services.auth_service import AuthService
from app.services.users_service import UserService
from app.utils.pagination import PageParams
from app.utils.response import pagination_meta, success_response

router = APIRouter(prefix="/users", tags=["Users"])


@router.get("", response_model=dict)
def list_users(
    user: Annotated[User, Depends(require_permission(PermissionCode.USERS_VIEW))],
    db: Session = Depends(get_db_session),
    page: PageParams = Depends(get_pagination),
    search: str | None = Query(default=None),
    role_id: int | None = Query(default=None),
    include_inactive: bool = Query(default=False),
) -> dict:
    rows, total = UserService(db).list(page, search, role_id, include_inactive)
    return success_response(
        [UserRead.model_validate(u).model_dump() for u in rows],
        meta=pagination_meta(page.page, page.page_size, total),
    )


@router.post("", response_model=dict, status_code=status.HTTP_201_CREATED)
def create_user(
    payload: UserCreate,
    user: Annotated[User, Depends(require_permission(PermissionCode.USERS_CREATE))],
    db: Session = Depends(get_db_session),
) -> dict:
    return success_response(UserRead.model_validate(UserService(db).create(payload, user)).model_dump())


@router.get("/me", response_model=dict)
def my_profile(
    user: Annotated[User, Depends(get_current_user)],
    db: Session = Depends(get_db_session),
) -> dict:
    return success_response(UserRead.model_validate(db.get(User, user.user_id)).model_dump())


@router.put("/me", response_model=dict)
def update_profile(
    payload: ProfileUpdate,
    user: Annotated[User, Depends(get_current_user)],
    db: Session = Depends(get_db_session),
) -> dict:
    return success_response(UserRead.model_validate(UserService(db).update_profile(user, payload)).model_dump())


@router.get("/{user_id}", response_model=dict)
def get_user(
    user_id: int,
    user: Annotated[User, Depends(require_permission(PermissionCode.USERS_VIEW))],
    db: Session = Depends(get_db_session),
) -> dict:
    return success_response(UserRead.model_validate(UserService(db).get(user_id)).model_dump())


@router.put("/{user_id}", response_model=dict)
def update_user(
    user_id: int,
    payload: UserUpdate,
    user: Annotated[User, Depends(require_permission(PermissionCode.USERS_UPDATE))],
    db: Session = Depends(get_db_session),
) -> dict:
    return success_response(UserRead.model_validate(UserService(db).update(user_id, payload, user)).model_dump())


@router.post("/{user_id}/deactivate", response_model=dict)
def deactivate_user(
    user_id: int,
    user: Annotated[User, Depends(require_permission(PermissionCode.USERS_UPDATE))],
    db: Session = Depends(get_db_session),
) -> dict:
    return success_response(UserRead.model_validate(UserService(db).deactivate(user_id, user)).model_dump())


@router.post("/{user_id}/reset-password", status_code=200)
def reset_password(
    user_id: int,
    payload: ResetPasswordRequest,
    user: Annotated[User, Depends(require_permission(PermissionCode.USERS_UPDATE))],
    db: Session = Depends(get_db_session),
) -> dict:
    AuthService(db).reset_password(user, user_id, payload.new_password)
    return success_response({"message": "Password reset successfully."})


@router.delete("/{user_id}", status_code=200)
def delete_user(
    user_id: int,
    user: Annotated[User, Depends(require_permission(PermissionCode.USERS_DELETE))],
    db: Session = Depends(get_db_session),
) -> dict:
    UserService(db).delete(user_id, user)
    return success_response({"message": "User deleted successfully."})
