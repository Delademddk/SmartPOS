"""Unit tests for shared validators."""

from __future__ import annotations

import pytest

from app.exceptions import PasswordPolicyError
from app.validators.common import is_valid_email, is_valid_username, validate_password_policy


class TestPasswordPolicy:
    @pytest.mark.parametrize(
        "password",
        [
            "Admin@123",
            "Str0ng!Pass",
            "P@ssw0rdX",
        ],
    )
    def test_accepts_valid_passwords(self, password: str) -> None:
        validate_password_policy(password)

    @pytest.mark.parametrize(
        "password",
        [
            "short",
            "alllowercase1!",
            "ALLUPPERCASE1!",
            "NoSpecialChar1",
            "NoDigit!Pass",
        ],
    )
    def test_rejects_invalid_passwords(self, password: str) -> None:
        with pytest.raises(PasswordPolicyError):
            validate_password_policy(password)


class TestEmail:
    def test_valid_email(self) -> None:
        assert is_valid_email("user@example.com") is True

    def test_invalid_email(self) -> None:
        assert is_valid_email("not-an-email") is False
        assert is_valid_email("") is False
        assert is_valid_email(None) is False


class TestUsername:
    def test_valid_username(self) -> None:
        assert is_valid_username("admin") is True
        assert is_valid_username("cashier_1") is True

    def test_invalid_username(self) -> None:
        assert is_valid_username("ab") is False
        assert is_valid_username("has space") is False
        assert is_valid_username(None) is False
