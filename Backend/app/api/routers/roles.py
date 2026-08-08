"""Roles and permissions endpoints (Feature 03)."""

from __future__ import annotations

from typing import Annotated

from fastapi import APIRouter, Depends, status
from sqlalchemy.orm import Session

from app.api.dependencies.auth import require_permission
from app.api.dependencies.database import get_db_session
from app.api.schemas.roles import (
    AssignPermissionsRequest,
    PermissionRead,
    RoleCreate,
    RoleRead,
    RoleUpdate,
    RoleWithPermissions,
)
from app.core.constants import PermissionCode
from app.models.users import User
from app.services.roles_service import RoleService
from app.utils.response import success_response

router = APIRouter(prefix="/roles", tags=["Roles & Permissions"])


@router.get("", response_model=dict)
def list_roles(
    user: Annotated[User, Depends(require_permission(PermissionCode.USERS_VIEW))],
    db: Session = Depends(get_db_session),
) -> dict:
    return success_response(
        [RoleRead.model_validate(r).model_dump() for r in RoleService(db).list_roles()]
    )


@router.get("/permissions", response_model=dict)
def list_permissions(
    user: Annotated[User, Depends(require_permission(PermissionCode.USERS_VIEW))],
    db: Session = Depends(get_db_session),
) -> dict:
    return success_response(
        [PermissionRead.model_validate(p).model_dump() for p in RoleService(db).list_permissions()]
    )


@router.post("", response_model=dict, status_code=status.HTTP_201_CREATED)
def create_role(
    payload: RoleCreate,
    user: Annotated[User, Depends(require_permission(PermissionCode.USERS_CREATE))],
    db: Session = Depends(get_db_session),
) -> dict:
    return success_response(RoleRead.model_validate(RoleService(db).create_role(payload, user)).model_dump())


@router.get("/{role_id}", response_model=dict)
def get_role(
    role_id: int,
    user: Annotated[User, Depends(require_permission(PermissionCode.USERS_VIEW))],
    db: Session = Depends(get_db_session),
) -> dict:
    service = RoleService(db)
    role = service.get_role(role_id)
    permissions = service.role_permissions(role_id)
    payload = RoleWithPermissions(
        **RoleRead.model_validate(role).model_dump(),
        permissions=[PermissionRead.model_validate(p).model_dump() for p in permissions],
    )
    return success_response(payload.model_dump())


@router.put("/{role_id}", response_model=dict)
def update_role(
    role_id: int,
    payload: RoleUpdate,
    user: Annotated[User, Depends(require_permission(PermissionCode.USERS_UPDATE))],
    db: Session = Depends(get_db_session),
) -> dict:
    return success_response(RoleRead.model_validate(RoleService(db).update_role(role_id, payload, user)).model_dump())


@router.delete("/{role_id}", status_code=200)
def delete_role(
    role_id: int,
    user: Annotated[User, Depends(require_permission(PermissionCode.USERS_DELETE))],
    db: Session = Depends(get_db_session),
) -> dict:
    RoleService(db).delete_role(role_id, user)
    return success_response({"message": "Role deleted successfully."})


@router.put("/{role_id}/permissions", status_code=200)
def assign_permissions(
    role_id: int,
    payload: AssignPermissionsRequest,
    user: Annotated[User, Depends(require_permission(PermissionCode.USERS_UPDATE))],
    db: Session = Depends(get_db_session),
) -> dict:
    RoleService(db).assign_permissions(role_id, payload, user)
    return success_response({"message": "Permissions updated successfully."})
