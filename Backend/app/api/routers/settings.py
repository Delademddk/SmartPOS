"""Application settings endpoints (Feature 15 - settings)."""

from __future__ import annotations

from typing import Annotated

from fastapi import APIRouter, Depends, Query, status
from sqlalchemy.orm import Session

from app.api.dependencies.auth import require_permission
from app.api.dependencies.database import get_db_session
from app.api.schemas.settings import SettingCreate, SettingRead, SettingUpdate
from app.core.constants import PermissionCode
from app.models.users import User
from app.services.business_service import BusinessService
from app.utils.response import success_response

router = APIRouter(prefix="/settings", tags=["Settings"])


@router.get("", response_model=dict)
def list_settings(
    user: Annotated[User, Depends(require_permission(PermissionCode.SETTINGS_VIEW))],
    db: Session = Depends(get_db_session),
    category: str | None = Query(default=None),
) -> dict:
    return success_response(
        [SettingRead.model_validate(s).model_dump() for s in BusinessService(db).list_settings(category)]
    )


@router.get("/{key}", response_model=dict)
def get_setting(
    key: str,
    user: Annotated[User, Depends(require_permission(PermissionCode.SETTINGS_VIEW))],
    db: Session = Depends(get_db_session),
) -> dict:
    return success_response(SettingRead.model_validate(BusinessService(db).get_setting(key)).model_dump())


@router.post("", response_model=dict, status_code=status.HTTP_201_CREATED)
def create_setting(
    payload: SettingCreate,
    user: Annotated[User, Depends(require_permission(PermissionCode.SETTINGS_CREATE))],
    db: Session = Depends(get_db_session),
) -> dict:
    return success_response(SettingRead.model_validate(BusinessService(db).create_setting(payload, user)).model_dump())


@router.put("/{key}", response_model=dict)
def update_setting(
    key: str,
    payload: SettingUpdate,
    user: Annotated[User, Depends(require_permission(PermissionCode.SETTINGS_UPDATE))],
    db: Session = Depends(get_db_session),
) -> dict:
    return success_response(SettingRead.model_validate(BusinessService(db).update_setting(key, payload, user)).model_dump())


@router.delete("/{key}", status_code=200)
def delete_setting(
    key: str,
    user: Annotated[User, Depends(require_permission(PermissionCode.SETTINGS_DELETE))],
    db: Session = Depends(get_db_session),
) -> dict:
    BusinessService(db).delete_setting(key, user)
    return success_response({"message": "Setting deleted successfully."})
