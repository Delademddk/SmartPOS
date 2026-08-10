"""Repositories for authentication, roles, permissions and users."""

from __future__ import annotations

from sqlalchemy import func, or_, select
from sqlalchemy.orm import Session

from app.models.auth import Permission, Role, RolePermission
from app.models.users import PasswordHistory, PasswordReset, User, UserSession
from app.repositories.base import BaseRepository


class UserRepository(BaseRepository[User]):
    model = User

    def get_by_username_or_email(self, value: str) -> User | None:
        stmt = select(User).where(or_(User.username == value, User.email == value))
        return self.session.scalar(stmt)

    def get_by_email(self, email: str) -> User | None:
        stmt = select(User).where(User.email == email)
        return self.session.scalar(stmt)

    def get_by_username(self, username: str) -> User | None:
        stmt = select(User).where(User.username == username)
        return self.session.scalar(stmt)

    def search(
        self,
        search: str | None,
        role_id: int | None,
        include_inactive: bool,
        page: int,
        page_size: int,
    ) -> tuple[list[User], int]:
        filters = []
        if search:
            like = f"%{search}%"
            filters.append(
                or_(
                    User.username.ilike(like),
                    User.email.ilike(like),
                    User.full_name.ilike(like),
                    User.phone.ilike(like),
                )
            )
        if role_id:
            filters.append(User.role_id == role_id)
        if not include_inactive:
            filters.append(User.is_active == True)

        total_stmt = select(func.count()).select_from(User).where(*filters)
        total = int(self.session.scalar(total_stmt) or 0)

        stmt = (
            select(User)
            .where(*filters)
            .order_by(User.created_at.desc())
            .offset((page - 1) * page_size)
            .limit(page_size)
        )
        return list(self.session.scalars(stmt).all()), total


class RoleRepository(BaseRepository[Role]):
    model = Role

    def get_by_code(self, code: str) -> Role | None:
        stmt = select(Role).where(Role.role_code == code)
        return self.session.scalar(stmt)


class PermissionRepository(BaseRepository[Permission]):
    model = Permission

    def get_by_code(self, code: str) -> Permission | None:
        stmt = select(Permission).where(Permission.permission_code == code)
        return self.session.scalar(stmt)


class RolePermissionRepository(BaseRepository[RolePermission]):
    model = RolePermission

    def permission_ids_for_role(self, role_id: int) -> list[int]:
        stmt = select(RolePermission.permission_id).where(RolePermission.role_id == role_id)
        return list(self.session.scalars(stmt).all())

    def replace_role_permissions(self, role_id: int, permission_ids: list[int], granted_by: int | None) -> None:
        self.session.query(RolePermission).filter(RolePermission.role_id == role_id).delete()
        for permission_id in permission_ids:
            self.session.add(
                RolePermission(
                    role_id=role_id,
                    permission_id=permission_id,
                    granted_by=granted_by,
                )
            )

    def has_permission(self, user: User, permission_code: str) -> bool:
        stmt = (
            select(RolePermission)
            .join(Permission, Permission.permission_id == RolePermission.permission_id)
            .where(
                RolePermission.role_id == user.role_id,
                Permission.permission_code == permission_code,
                Permission.is_active == True,
            )
        )
        return self.session.scalar(stmt) is not None


class SessionRepository(BaseRepository[UserSession]):
    model = UserSession

    def get_by_token(self, token_hash: str) -> UserSession | None:
        stmt = select(UserSession).where(UserSession.session_token == token_hash)
        return self.session.scalar(stmt)

    def revoke_all_for_user(self, user_id: int, revoked_by: int | None = None) -> None:
        sessions = self.session.scalars(
            select(UserSession).where(
                UserSession.user_id == user_id,
                UserSession.is_revoked == False,
            )
        ).all()
        for session in sessions:
            session.is_revoked = True
            session.revoked_by = revoked_by

    def revoke_token(self, token_hash: str, revoked_by: int | None = None) -> bool:
        session = self.get_by_token(token_hash)
        if session and not session.is_revoked:
            session.is_revoked = True
            session.revoked_by = revoked_by
            return True
        return False


class PasswordHistoryRepository(BaseRepository[PasswordHistory]):
    model = PasswordHistory

    def recent_hashes(self, user_id: int, limit: int) -> list[str]:
        stmt = (
            select(PasswordHistory.password_hash)
            .where(PasswordHistory.user_id == user_id)
            .order_by(PasswordHistory.changed_at.desc())
            .limit(limit)
        )
        return list(self.session.scalars(stmt).all())


class PasswordResetRepository(BaseRepository[PasswordReset]):
    model = PasswordReset

    def get_unused_by_token(self, token_hash: str) -> PasswordReset | None:
        stmt = select(PasswordReset).where(
            PasswordReset.reset_token == token_hash,
            PasswordReset.used_at.is_(None),
        )
        return self.session.scalar(stmt)
