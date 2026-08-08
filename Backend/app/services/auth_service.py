"""Authentication service.

Handles login, logout, token refresh, password change and password reset.
Sessions are persisted in ``user_sessions`` with a SHA-256 hash of the
refresh token's ``jti`` so they can be revoked.
"""

from __future__ import annotations

from datetime import UTC, datetime, timedelta

from app.api.schemas.auth import (
    ChangePasswordRequest,
    LoginRequest,
    LoginResponse,
    RefreshRequest,
    RefreshResponse,
    RequestPasswordResetRequest,
    CompletePasswordResetRequest,
    TokenResponse,
    UserSummary,
)
from app.core.config import get_settings
from app.core.security import (
    create_access_token,
    create_refresh_token,
    decode_token,
    generate_token,
    hash_token,
    hash_password,
    verify_password,
    access_token_expires_in_seconds,
)
from app.exceptions import (
    AccountDisabledError,
    AccountLockedError,
    BadRequestError,
    ConflictError,
    DuplicateResourceError,
    InvalidCredentialsError,
    NotFoundError,
    PasswordPolicyError,
    TokenInvalidError,
)
from app.models.users import PasswordReset, User, UserSession
from app.repositories.auth_repo import (
    PasswordHistoryRepository,
    PasswordResetRepository,
    SessionRepository,
    UserRepository,
)
from app.services.audit_service import AuditService
from app.services.base import BaseService
from app.validators.common import validate_password_policy


def _user_summary(user: User) -> UserSummary:
    return UserSummary(
        user_id=user.user_id,
        username=user.username,
        email=user.email,
        full_name=user.full_name,
        role_id=user.role_id,
        role_code=user.role.role_code if user.role else None,
        role_name=user.role.role_name if user.role else None,
        is_active=user.is_active,
        must_change_password=user.must_change_password,
        last_login_at=user.last_login_at,
    )


class AuthService(BaseService):
    service_name = "auth"

    def __init__(self, session) -> None:  # noqa: ANN001
        super().__init__(session)
        self.users = UserRepository(session)
        self.sessions = SessionRepository(session)
        self.password_history = PasswordHistoryRepository(session)
        self.password_resets = PasswordResetRepository(session)
        self.audit = AuditService(session)

    # ------------------------------------------------------------------
    # Login / logout / refresh
    # ------------------------------------------------------------------
    def login(self, payload: LoginRequest, ip_address: str | None, user_agent: str | None) -> LoginResponse:
        settings = get_settings()
        user = self.users.get_by_username_or_email(payload.username)

        if user is None or user.is_deleted:
            self.audit.security(
                event_type="LOGIN_FAILED",
                username=payload.username,
                ip_address=ip_address,
                user_agent=user_agent,
                message="Unknown account.",
            )
            self.session.commit()
            raise InvalidCredentialsError("Invalid username or password.")

        if not verify_password(payload.password, user.password_hash):
            user.failed_login_attempts = min(user.failed_login_attempts + 1, 255)
            if user.failed_login_attempts >= settings.lockout_threshold:
                user.is_locked = True
            self.audit.security(
                event_type="LOGIN_FAILED",
                user_id=user.user_id,
                username=user.username,
                ip_address=ip_address,
                user_agent=user_agent,
                message="Invalid password.",
            )
            self.session.commit()
            raise InvalidCredentialsError("Invalid username or password.")

        if not user.is_active:
            self.audit.security(
                event_type="LOGIN_FAILED",
                user_id=user.user_id,
                username=user.username,
                ip_address=ip_address,
                user_agent=user_agent,
                message="Account disabled.",
            )
            self.session.commit()
            raise AccountDisabledError("Account is disabled.")

        if user.is_locked:
            self.audit.security(
                event_type="LOCKOUT",
                user_id=user.user_id,
                username=user.username,
                ip_address=ip_address,
                user_agent=user_agent,
                message="Account locked.",
            )
            self.session.commit()
            raise AccountLockedError("Account is locked. Contact an administrator.")

        # ---- success ----
        now = datetime.now(UTC)
        user.failed_login_attempts = 0
        user.last_login_at = now.replace(tzinfo=None)
        user.last_login_ip = ip_address

        jti = generate_token()
        session = UserSession(
            user_id=user.user_id,
            session_token=hash_token(jti),
            ip_address=ip_address,
            user_agent=user_agent,
            issued_at=now.replace(tzinfo=None),
            expires_at=(now + timedelta(days=settings.jwt_refresh_token_expire_days)).replace(tzinfo=None),
            is_revoked=False,
        )
        self.sessions.add(session)
        self.audit.security(
            event_type="LOGIN_SUCCESS",
            user_id=user.user_id,
            username=user.username,
            ip_address=ip_address,
            user_agent=user_agent,
            message="Login successful.",
        )
        self.audit.activity(
            activity_type="LOGIN",
            activity_desc=f"User {user.username} logged in",
            entity_type="User",
            entity_id=user.user_id,
            user_id=user.user_id,
            ip_address=ip_address,
            user_agent=user_agent,
        )
        self.session.flush()
        access_token = create_access_token(user.user_id, user.role.role_code, user.username)
        refresh_token = create_refresh_token(user.user_id, jti)

        self.audit.record(
            action_type="LOGIN",
            resource_type="User",
            resource_id=user.user_id,
            user_id=user.user_id,
            ip_address=ip_address,
            user_agent=user_agent,
        )
        self.session.commit()
        self.logger.info("login_success", user_id=user.user_id, username=user.username)

        return LoginResponse(
            access_token=access_token,
            refresh_token=refresh_token,
            expires_in=access_token_expires_in_seconds(),
            user=_user_summary(user),
        )

    def logout(self, refresh_token: str, ip_address: str | None, user_agent: str | None) -> None:
        try:
            payload = decode_token(refresh_token, expected_type="refresh")
        except ValueError as exc:
            raise TokenInvalidError(str(exc)) from exc
        jti = payload.get("jti")
        if jti:
            self.sessions.revoke_token(hash_token(jti))
        user_id = int(payload.get("sub", 0)) or None
        self.audit.security(
            event_type="LOGOUT",
            user_id=user_id,
            ip_address=ip_address,
            user_agent=user_agent,
            message="Session revoked.",
        )
        self.session.commit()
        self.logger.info("logout", user_id=user_id)

    def refresh(self, payload: RefreshRequest, ip_address: str | None, user_agent: str | None) -> RefreshResponse:
        try:
            decoded = decode_token(payload.refresh_token, expected_type="refresh")
        except ValueError as exc:
            raise TokenInvalidError(str(exc)) from exc

        jti = decoded.get("jti")
        session = self.sessions.get_by_token(hash_token(jti)) if jti else None
        if session is None or session.is_revoked:
            raise TokenInvalidError("Session is no longer valid.")
        if session.expires_at < datetime.now(UTC).replace(tzinfo=None):
            raise TokenInvalidError("Refresh token has expired.")

        user = self.users.get(session.user_id)
        if user is None or not user.is_active or user.is_deleted:
            raise TokenInvalidError("User account is no longer active.")

        self.audit.security(
            event_type="TOKEN_REFRESH",
            user_id=user.user_id,
            username=user.username,
            ip_address=ip_address,
            user_agent=user_agent,
            message="Access token refreshed.",
        )
        self.session.commit()

        access_token = create_access_token(user.user_id, user.role.role_code, user.username)
        return RefreshResponse(
            access_token=access_token,
            expires_in=access_token_expires_in_seconds(),
        )

    # ------------------------------------------------------------------
    # Password management
    # ------------------------------------------------------------------
    def change_password(
        self,
        user: User,
        payload: ChangePasswordRequest,
        current_session_jti: str | None,
    ) -> None:
        if not verify_password(payload.current_password, user.password_hash):
            raise InvalidCredentialsError("Current password is incorrect.")
        validate_password_policy(payload.new_password)

        history = self.password_history.recent_hashes(user.user_id, get_settings().jwt_refresh_token_expire_days)
        for old_hash in history:
            if verify_password(payload.new_password, old_hash):
                raise PasswordPolicyError(
                    "New password must not match any of your recent passwords."
                )

        new_hash = hash_password(payload.new_password)
        user.password_hash = new_hash
        user.must_change_password = False
        user.failed_login_attempts = 0

        self.password_history.add(
            self.password_history.model(
                user_id=user.user_id,
                password_hash=new_hash,
                changed_by=user.user_id,
            )
        )
        self.sessions.revoke_all_for_user(
            user.user_id, revoked_by=user.user_id
        )
        self.audit.activity(
            activity_type="PASSWORD_CHANGED",
            activity_desc="User changed own password",
            entity_type="User",
            entity_id=user.user_id,
            user_id=user.user_id,
        )
        self.session.commit()

    def reset_password(self, admin: User, user_id: int, new_password: str) -> None:
        validate_password_policy(new_password)
        target = self.users.get(user_id)
        if target is None:
            raise NotFoundError("User not found.")
        if target.is_deleted:
            raise NotFoundError("User not found.")

        new_hash = hash_password(new_password)
        target.password_hash = new_hash
        target.must_change_password = True
        target.failed_login_attempts = 0
        target.is_locked = False

        self.password_history.add(
            self.password_history.model(
                user_id=target.user_id,
                password_hash=new_hash,
                changed_by=admin.user_id,
            )
        )
        self.sessions.revoke_all_for_user(target.user_id, revoked_by=admin.user_id)
        self.audit.activity(
            activity_type="PASSWORD_RESET",
            activity_desc=f"Password reset for {target.username}",
            entity_type="User",
            entity_id=target.user_id,
            user_id=admin.user_id,
        )
        self.session.commit()

    def request_password_reset(
        self,
        payload: RequestPasswordResetRequest,
        ip_address: str | None,
    ) -> None:
        user = self.users.get_by_email(payload.email)
        token = generate_token()
        self.password_resets.add(
            PasswordReset(
                user_id=user.user_id if user else 0,
                reset_token=hash_token(token),
                ip_address=ip_address,
                expires_at=datetime.now(UTC).replace(tzinfo=None) + timedelta(hours=1),
            )
        )
        self.audit.security(
            event_type="RESET",
            user_id=user.user_id if user else None,
            username=payload.email,
            ip_address=ip_address,
            message="Password reset requested.",
        )
        self.session.commit()
        self.logger.info("password_reset_requested", email=payload.email)

    def complete_password_reset(self, payload: CompletePasswordResetRequest) -> None:
        validate_password_policy(payload.new_password)
        reset = self.password_resets.get_unused_by_token(hash_token(payload.token))
        if reset is None or reset.expires_at < datetime.now(UTC).replace(tzinfo=None):
            raise TokenInvalidError("Reset token is invalid or expired.")

        user = self.users.get(reset.user_id)
        if user is None:
            raise NotFoundError("User not found.")

        new_hash = hash_password(payload.new_password)
        user.password_hash = new_hash
        user.must_change_password = False
        user.failed_login_attempts = 0
        user.is_locked = False

        self.password_history.add(
            self.password_history.model(
                user_id=user.user_id,
                password_hash=new_hash,
                changed_by=user.user_id,
            )
        )
        reset.used_at = datetime.now(UTC).replace(tzinfo=None)
        self.sessions.revoke_all_for_user(user.user_id, revoked_by=user.user_id)
        self.session.commit()
