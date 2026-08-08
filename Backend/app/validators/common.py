"""Reusable validators for password policy and string normalisation."""

from __future__ import annotations

import re

from app.exceptions import PasswordPolicyError

MIN_PASSWORD_LENGTH = 8
PASSWORD_PATTERNS = {
    "uppercase": r"[A-Z]",
    "lowercase": r"[a-z]",
    "digit": r"\d",
    "special": r"[^A-Za-z0-9]",
}


def validate_password_policy(password: str) -> None:
    """Enforce the documented password policy:
    >= 8 chars, at least one uppercase, one lowercase, one digit, one special.
    """
    if password is None:
        raise PasswordPolicyError("Password is required.")

    if len(password) < MIN_PASSWORD_LENGTH:
        raise PasswordPolicyError(
            "Password must be at least 8 characters long.",
            [{"field": "password", "message": f"Minimum {MIN_PASSWORD_LENGTH} characters"}],
        )

    missing = [name for name, pattern in PASSWORD_PATTERNS.items() if not re.search(pattern, password)]
    if missing:
        raise PasswordPolicyError(
            "Password does not meet complexity requirements.",
            [{"field": "password", "message": f"Missing: {', '.join(missing)}"}],
        )


def normalize_string(value: str | None, *, strip: bool = True) -> str | None:
    """Trim and collapse surrounding whitespace."""
    if value is None:
        return None
    return value.strip() if strip else value


def is_valid_email(email: str | None) -> bool:
    """Lightweight email format check mirroring the DB CHECK constraint."""
    if not email:
        return False
    return bool(re.match(r"^[^@\s]+@[^@\s]+\.[^@\s]+$", email))


def is_valid_username(username: str | None) -> bool:
    """Usernames: 3-50 chars, alphanumeric + underscore."""
    if not username:
        return False
    return bool(re.match(r"^[A-Za-z0-9_]{3,50}$", username))
