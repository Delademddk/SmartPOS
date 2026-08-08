"""Security primitives: password hashing and JWT tokens.

Uses bcrypt for password hashing and PyJWT for signed access/refresh tokens.
"""

from __future__ import annotations

import hashlib
import secrets
from datetime import UTC, datetime, timedelta
from typing import Any

import bcrypt
import jwt

from app.core.config import get_settings

# ---------------------------------------------------------------------------
# Password hashing
# ---------------------------------------------------------------------------


def hash_password(password: str, rounds: int | None = None) -> str:
    """Hash a plaintext password with bcrypt."""
    if not password:
        raise ValueError("Password must not be empty.")
    cost = rounds or get_settings().bcrypt_rounds
    return bcrypt.hashpw(password.encode("utf-8"), bcrypt.gensalt(rounds=cost)).decode("utf-8")


def verify_password(password: str, password_hash: str) -> bool:
    """Verify a plaintext password against a bcrypt hash."""
    try:
        return bcrypt.checkpw(password.encode("utf-8"), password_hash.encode("utf-8"))
    except (ValueError, TypeError):
        return False


# ---------------------------------------------------------------------------
# Token hashing for session / reset tokens stored at rest (SHA-256)
# ---------------------------------------------------------------------------


def hash_token(token: str) -> str:
    """One-way SHA-256 hash used when persisting opaque tokens."""
    return hashlib.sha256(token.encode("utf-8")).hexdigest()


def generate_token() -> str:
    """Generate a cryptographically random opaque token."""
    return secrets.token_urlsafe(48)


# ---------------------------------------------------------------------------
# JWT creation / decoding
# ---------------------------------------------------------------------------


def _create_token(
    subject: str,
    claims: dict[str, Any],
    expires_delta: timedelta,
    token_type: str,
) -> str:
    settings = get_settings()
    now = datetime.now(UTC)
    payload: dict[str, Any] = {
        "sub": subject,
        "type": token_type,
        "iat": now,
        "exp": now + expires_delta,
    }
    payload.update(claims)
    return jwt.encode(payload, settings.jwt_secret, algorithm=settings.jwt_algorithm)


def create_access_token(user_id: int, role_code: str, username: str) -> str:
    settings = get_settings()
    return _create_token(
        subject=str(user_id),
        claims={"role": role_code, "username": username},
        expires_delta=timedelta(minutes=settings.jwt_access_token_expire_minutes),
        token_type="access",
    )


def create_refresh_token(user_id: int, jti: str) -> str:
    settings = get_settings()
    return _create_token(
        subject=str(user_id),
        claims={"jti": jti},
        expires_delta=timedelta(days=settings.jwt_refresh_token_expire_days),
        token_type="refresh",
    )


def decode_token(token: str, expected_type: str | None = None) -> dict[str, Any]:
    """Decode and validate a JWT, raising ValueError on any failure."""
    settings = get_settings()
    try:
        payload = jwt.decode(token, settings.jwt_secret, algorithms=[settings.jwt_algorithm])
    except jwt.ExpiredSignatureError as exc:
        raise ValueError("Token has expired.") from exc
    except jwt.InvalidTokenError as exc:
        raise ValueError("Invalid token.") from exc
    if expected_type and payload.get("type") != expected_type:
        raise ValueError("Invalid token type.")
    return payload


def access_token_expires_in_seconds() -> int:
    return get_settings().jwt_access_token_expire_minutes * 60
