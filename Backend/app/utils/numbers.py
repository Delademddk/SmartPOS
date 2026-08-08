"""Number generation utilities (receipts, returns)."""

from __future__ import annotations

import secrets
from datetime import UTC, datetime


def _timestamp_prefix() -> str:
    return datetime.now(UTC).strftime("%Y%m%d%H%M%S")


def _suffix() -> str:
    return secrets.token_hex(3).upper()


def generate_receipt_number() -> str:
    return f"SLS-{_timestamp_prefix()}-{_suffix()}"


def generate_return_number() -> str:
    return f"RET-{_timestamp_prefix()}-{_suffix()}"
