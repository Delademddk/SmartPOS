"""Standard API response envelope helpers.

All responses follow the API architecture:

Successful:
    {"success": true, "data": ..., "meta": {...}}

Error:
    {"success": false, "error": {"code": ..., "message": ..., "details": [...],
                                 "timestamp": ..., "request_id": ...}}
"""

from __future__ import annotations

import time
from typing import Any

from fastapi import Response

REQUEST_ID_CONTEXT = "x-request-id"


def success_response(
    data: Any,
    meta: dict[str, Any] | None = None,
    status_code: int = 200,
    response: Response | None = None,
) -> dict[str, Any]:
    """Build a successful response envelope."""
    body = {"success": True, "data": data}
    if meta:
        body["meta"] = meta
    return body


def pagination_meta(
    page: int,
    page_size: int,
    total_items: int,
) -> dict[str, Any]:
    """Build the meta block for paginated collections."""
    total_pages = (total_items + page_size - 1) // page_size if page_size else 0
    return {
        "page": page,
        "page_size": page_size,
        "total_items": total_items,
        "total_pages": total_pages,
    }


def error_payload(
    code: str,
    message: str,
    details: list[dict[str, Any]] | None = None,
    request_id: str | None = None,
) -> dict[str, Any]:
    """Build the error envelope."""
    return {
        "success": False,
        "error": {
            "code": code,
            "message": message,
            "details": details or [],
            "timestamp": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
            "request_id": request_id,
        },
    }
