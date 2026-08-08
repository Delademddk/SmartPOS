"""Roles and permissions service (Feature 03)."""

from __future__ import annotations

from app.api.schemas.roles import (
    AssignPermissionsRequest,
    RoleCreate,
    RoleUpdate,
)
from app.core.constants import RoleCode
from app.exceptions import (
    BadRequestError,
    CannotDeleteInUseError,
    DuplicateResourceError,
    NotFoundError,
    ValidationError_,
)
from app.models.auth import Role
from app.models.users import User
from app.repositories.auth_repo import (
    PermissionRepository,
    RolePermissionRepository,
    RoleRepository,
    UserRepository,
)
from app.services.audit_service import AuditService
from app.services.base import BaseService


class RoleService(BaseService):
    service_name = "roles"

    def __init__(self, session) -> None:  # noqa: ANN001
        super().__init__(session)
        self.roles = RoleRepository(session)
        self.permissions = PermissionRepository(session)
        self.role_permissions = RolePermissionRepository(session)
        self.users = UserRepository(session)
        self.audit = AuditService(session)

    # ------------------------------------------------------------------
    # Roles
    # ------------------------------------------------------------------
    def list_roles(self) -> list[Role]:
        return self.roles.list_all()

    def get_role(self, role_id: int) -> Role:
        role = self.roles.get(role_id)
        if role is None:
            raise NotFoundError("Role not found.")
        return role

    def create_role(self, payload: RoleCreate, actor: User) -> Role:
        if self.roles.get_by_code(payload.role_code):
            raise DuplicateResourceError(
                "Role code already exists.",
                resource_type="Role",
            )
        role = Role(
            role_code=payload.role_code,
            role_name=payload.role_name,
            description=payload.description,
            is_system=False,
            is_active=True,
            created_by=actor.user_id,
            updated_by=actor.user_id,
        )
        self.roles.add(role)
        self.audit.activity(
            activity_type="ROLE_CREATED",
            activity_desc=f"Created role {role.role_code}",
            entity_type="Role",
            entity_id=role.role_id,
            user_id=actor.user_id,
        )
        self.session.commit()
        return self.roles.get(role.role_id)

    def update_role(self, role_id: int, payload: RoleUpdate, actor: User) -> Role:
        role = self.get_role(role_id)
        if role.is_system and payload.is_active is False:
            raise BadRequestError("System roles cannot be deactivated.")
        data = payload.model_dump(exclude_unset=True)
        if "role_name" in data and data["role_name"]:
            role.role_name = data["role_name"].strip()
        if "description" in data:
            role.description = data["description"]
        if "is_active" in data and data["is_active"] is not None:
            role.is_active = data["is_active"]
        role.updated_by = actor.user_id
        self.audit.activity(
            activity_type="ROLE_UPDATED",
            activity_desc=f"Updated role {role.role_code}",
            entity_type="Role",
            entity_id=role.role_id,
            user_id=actor.user_id,
        )
        self.session.commit()
        return self.roles.get(role.role_id)

    def delete_role(self, role_id: int, actor: User) -> None:
        role = self.get_role(role_id)
        if role.is_system:
            raise BadRequestError("System roles cannot be deleted.")
        if self.users.count(self.users.model.role_id == role_id) > 0:
            raise CannotDeleteInUseError("Role is assigned to users and cannot be deleted.")
        self.roles.delete(role)
        self.audit.activity(
            activity_type="ROLE_DELETED",
            activity_desc=f"Deleted role {role.role_code}",
            entity_type="Role",
            entity_id=role_id,
            user_id=actor.user_id,
        )
        self.session.commit()

    # ------------------------------------------------------------------
    # Permissions
    # ------------------------------------------------------------------
    def list_permissions(self) -> list:
        return self.permissions.list_all()

    def role_permissions(self, role_id: int) -> list:
        self.get_role(role_id)
        permission_ids = self.role_permissions.permission_ids_for_role(role_id)
        return [self.permissions.get(pid) for pid in permission_ids]

    def assign_permissions(self, role_id: int, payload: AssignPermissionsRequest, actor: User) -> None:
        role = self.get_role(role_id)
        for permission_id in payload.permission_ids:
            if self.permissions.get(permission_id) is None:
                raise ValidationError_(
                    "One or more permissions do not exist.",
                    [{"field": "permission_ids", "message": "Invalid permission id"}],
                )
        self.role_permissions.replace_role_permissions(
            role_id, payload.permission_ids, granted_by=actor.user_id
        )
        self.audit.activity(
            activity_type="ROLE_PERMISSIONS_UPDATED",
            activity_desc=f"Updated permissions for role {role.role_code}",
            entity_type="Role",
            entity_id=role_id,
            user_id=actor.user_id,
        )
        self.session.commit()
