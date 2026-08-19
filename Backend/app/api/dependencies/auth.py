"""Authentication and authorization dependencies."""

from __future__ import annotations

from typing import Annotated

from fastapi import Depends, Header, Request
from sqlalchemy.orm import Session

from app.api.dependencies.database import get_db_session
from app.core.constants import PermissionCode
from app.core.logging import get_logger
from app.core.security import decode_token, hash_token
from app.exceptions import (
    AccountDisabledError,
    ForbiddenError,
    SessionRevokedError,
    TokenExpiredError,
    TokenInvalidError,
    UnauthorizedError,
)
from app.models.auth import Permission, RolePermission
from app.models.users import User, UserSession

logger = get_logger("auth.dependencies")

ALGORITHMS: set[str] = set()


def _extract_bearer_token(authorization: str | None) -> str:
    if not authorization:
        raise UnauthorizedError("Authentication required.")
    scheme, _, token = authorization.partition(" ")
    if scheme.lower() != "bearer" or not token:
        raise UnauthorizedError("Invalid authorization header.")
    return token


def _request_context(request: Request) -> tuple[str | None, str | None]:
    ip = request.client.host if request.client else None
    user_agent = request.headers.get("user-agent")
    return ip, user_agent


def _load_active_user(db: Session, user_id: int) -> User:
    user = db.get(User, user_id)
    if user is None or user.is_deleted:
        raise TokenInvalidError("User no longer exists.")
    if not user.is_active:
        raise AccountDisabledError("Account is disabled.")
    return user


def get_current_user(
    request: Request,
    authorization: Annotated[str | None, Header()] = None,
    db: Session = Depends(get_db_session),
) -> User:
    """Decode the access token and return the authenticated user."""
    token = _extract_bearer_token(authorization)
    try:
        payload = decode_token(token, expected_type="access")
    except ValueError as exc:
        message = str(exc)
        if "expired" in message:
            raise TokenExpiredError(message) from exc
        raise TokenInvalidError(message) from exc
    user_id = int(payload["sub"])
    return _load_active_user(db, user_id)


def get_current_user_from_refresh(
    request: Request,
    authorization: Annotated[str | None, Header()] = None,
    db: Session = Depends(get_db_session),
) -> User:
    """Decode the refresh token, validate the stored session, return user."""
    token = _extract_bearer_token(authorization)
    try:
        payload = decode_token(token, expected_type="refresh")
    except ValueError as exc:
        message = str(exc)
        if "expired" in message:
            raise TokenExpiredError(message) from exc
        raise TokenInvalidError(message) from exc

    jti = payload.get("jti")
    if not jti:
        raise TokenInvalidError("Refresh token is missing its session id.")

    session = (
        db.query(UserSession)
        .filter(
            UserSession.session_token == hash_token(jti),
            UserSession.is_revoked == False,
        )
        .first()
    )
    if session is None:
        raise SessionRevokedError("Session is no longer valid.")
    return _load_active_user(db, int(payload["sub"]))


def _user_has_permission(db: Session, user: User, permission_code: str) -> bool:
    if user.role_code == "ADMIN":
        return True
    exists = (
        db.query(Permission)
        .join(RolePermission, RolePermission.permission_id == Permission.permission_id)
        .filter(
            Permission.permission_code == permission_code,
            Permission.is_active == True,
            RolePermission.role_id == user.role_id,
        )
        .first()
    )
    return exists is not None


def require_permission(permission_code: PermissionCode):
    """Build a dependency that enforces a specific permission code."""

    def dependency(
        user: User = Depends(get_current_user),
        db: Session = Depends(get_db_session),
    ) -> User:
        if not _user_has_permission(db, user, permission_code.value):
            raise ForbiddenError(
                "You do not have permission to perform this action.",
                resource_type="permission",
            )
        return user

    return dependency


def require_role(role_code: str):
    """Build a dependency that enforces a specific role code."""

    def dependency(user: User = Depends(get_current_user)) -> User:
        if user.role.role_code != role_code:
            raise ForbiddenError(
                f"Role '{role_code}' is required for this action.",
            )
        return user

    return dependency
