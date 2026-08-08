"""User management service (Feature 04)."""

from __future__ import annotations

from typing import Any

from app.api.schemas.users import (
    ProfileUpdate,
    UserCreate,
    UserUpdate,
)
from app.core.security import hash_password
from app.database.base import utcnow
from app.exceptions import (
    BadRequestError,
    CannotDeleteInUseError,
    ConflictError,
    DuplicateResourceError,
    ForbiddenError,
    NotFoundError,
    ValidationError_,
)
from app.models.users import User
from app.repositories.auth_repo import (
    PasswordHistoryRepository,
    RoleRepository,
    SessionRepository,
    UserRepository,
)
from app.repositories.ops_repo import SaleRepository
from app.services.audit_service import AuditService
from app.services.base import BaseService
from app.utils.pagination import PageParams
from app.validators.common import is_valid_email, is_valid_username, validate_password_policy


class UserService(BaseService):
    service_name = "users"

    def __init__(self, session) -> None:  # noqa: ANN001
        super().__init__(session)
        self.users = UserRepository(session)
        self.roles = RoleRepository(session)
        self.sessions = SessionRepository(session)
        self.password_history = PasswordHistoryRepository(session)
        self.sales = SaleRepository(session)
        self.audit = AuditService(session)

    # ------------------------------------------------------------------
    def list(
        self,
        page: PageParams,
        search: str | None,
        role_id: int | None,
        include_inactive: bool,
    ) -> tuple[list[User], int]:
        return self.users.search(
            search=search,
            role_id=role_id,
            include_inactive=include_inactive,
            page=page.page,
            page_size=page.page_size,
        )

    def get(self, user_id: int) -> User:
        user = self.users.get(user_id)
        if user is None or user.is_deleted:
            raise NotFoundError("User not found.")
        return user

    def get_by_username_or_email(self, value: str) -> User:
        user = self.users.get_by_username_or_email(value)
        if user is None or user.is_deleted:
            raise NotFoundError("User not found.")
        return user

    def create(self, payload: UserCreate, actor: User) -> User:
        if not is_valid_username(payload.username):
            raise ValidationError_(
                "Invalid username. Use 3-50 alphanumeric characters or underscores.",
                [{"field": "username", "message": "Invalid format"}],
            )
        if not is_valid_email(payload.email):
            raise ValidationError_(
                "A valid email is required.",
                [{"field": "email", "message": "Invalid email format"}],
            )
        validate_password_policy(payload.password)

        if self.users.get_by_username(payload.username):
            raise DuplicateResourceError(
                "Username already exists.",
                resource_type="User",
            )
        if self.users.get_by_email(payload.email):
            raise DuplicateResourceError(
                "Email already exists.",
                resource_type="User",
            )
        role = self.roles.get(payload.role_id)
        if role is None or not role.is_active:
            raise ValidationError_(
                "Role does not exist or is inactive.",
                [{"field": "role_id", "message": "Invalid role"}],
            )

        password_hash = hash_password(payload.password)
        user = User(
            username=payload.username,
            email=payload.email,
            password_hash=password_hash,
            full_name=payload.full_name,
            phone=payload.phone,
            role_id=role.role_id,
            is_active=True,
            is_locked=False,
            must_change_password=payload.must_change_password,
            created_by=actor.user_id,
            updated_by=actor.user_id,
        )
        self.users.add(user)
        self.session.flush()

        self.password_history.add(
            self.password_history.model(
                user_id=user.user_id,
                password_hash=password_hash,
                changed_by=actor.user_id,
            )
        )
        self.audit.activity(
            activity_type="USER_CREATED",
            activity_desc=f"Created user {user.username}",
            entity_type="User",
            entity_id=user.user_id,
            user_id=actor.user_id,
        )
        self.audit.record(
            action_type="INSERT",
            resource_type="User",
            resource_id=user.user_id,
            user_id=actor.user_id,
            new_values={"username": user.username, "role_id": user.role_id},
        )
        self.session.commit()
        return self.users.get(user.user_id)

    def update(self, user_id: int, payload: UserUpdate, actor: User) -> User:
        user = self.get(user_id)
        data = payload.model_dump(exclude_unset=True)

        if "role_id" in data and data["role_id"] is not None:
            role = self.roles.get(data["role_id"])
            if role is None or not role.is_active:
                raise ValidationError_(
                    "Role does not exist or is inactive.",
                    [{"field": "role_id", "message": "Invalid role"}],
                )
            user.role_id = role.role_id

        if "full_name" in data and data["full_name"] is not None:
            user.full_name = data["full_name"].strip()
        if "phone" in data:
            user.phone = data["phone"]
        if "is_active" in data and data["is_active"] is not None:
            if data["is_active"] is False and user.user_id == actor.user_id:
                raise BadRequestError("You cannot deactivate your own account.")
            user.is_active = data["is_active"]

        user.updated_by = actor.user_id
        self.audit.activity(
            activity_type="USER_UPDATED",
            activity_desc=f"Updated user {user.username}",
            entity_type="User",
            entity_id=user.user_id,
            user_id=actor.user_id,
        )
        self.audit.record(
            action_type="UPDATE",
            resource_type="User",
            resource_id=user.user_id,
            user_id=actor.user_id,
            new_values=data,
        )
        self.session.commit()
        return self.users.get(user.user_id)

    def deactivate(self, user_id: int, actor: User) -> User:
        if user_id == actor.user_id:
            raise BadRequestError("You cannot deactivate your own account.")
        user = self.get(user_id)
        user.is_active = False
        user.updated_by = actor.user_id
        self.sessions.revoke_all_for_user(user.user_id, revoked_by=actor.user_id)
        self.audit.activity(
            activity_type="USER_DEACTIVATED",
            activity_desc=f"Deactivated user {user.username}",
            entity_type="User",
            entity_id=user.user_id,
            user_id=actor.user_id,
        )
        self.audit.record(
            action_type="DELETE",
            resource_type="User",
            resource_id=user.user_id,
            user_id=actor.user_id,
            new_values={"is_active": False},
        )
        self.session.commit()
        return self.users.get(user.user_id)

    def delete(self, user_id: int, actor: User) -> None:
        user = self.get(user_id)
        if user.user_id == actor.user_id:
            raise BadRequestError("You cannot delete your own account.")
        if self.sales.count(self.sales.model.user_id == user_id) > 0:
            raise CannotDeleteInUseError("This user has sales history and cannot be deleted.")
        user.is_deleted = True
        user.is_active = False
        user.deleted_at = utcnow()
        user.deleted_by = actor.user_id
        self.sessions.revoke_all_for_user(user.user_id, revoked_by=actor.user_id)
        self.audit.activity(
            activity_type="USER_DELETED",
            activity_desc=f"Deleted user {user.username}",
            entity_type="User",
            entity_id=user.user_id,
            user_id=actor.user_id,
        )
        self.session.commit()

    def update_profile(self, user: User, payload: ProfileUpdate) -> User:
        data = payload.model_dump(exclude_unset=True)
        if "full_name" in data and data["full_name"]:
            user.full_name = data["full_name"].strip()
        if "phone" in data:
            user.phone = data["phone"]
        if "email" in data and data["email"]:
            if not is_valid_email(data["email"]):
                raise ValidationError_(
                    "A valid email is required.",
                    [{"field": "email", "message": "Invalid email format"}],
                )
            existing = self.users.get_by_email(data["email"])
            if existing and existing.user_id != user.user_id:
                raise DuplicateResourceError("Email already exists.", resource_type="User")
            user.email = data["email"]
        user.updated_by = user.user_id
        self.session.commit()
        return self.users.get(user.user_id)
