"""Simple in-memory rate limiting middleware.

Keeps per-client counters for login attempts (tight limit) and general API
traffic (loose limit). Not intended for multi-process deployments; swap in a
Redis-backed limiter in production.
"""

from __future__ import annotations

import time
from collections import defaultdict, deque

from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request
from starlette.responses import JSONResponse

from app.core.config import get_settings
from app.utils.response import error_payload

_LOGIN_PATHS = {"/api/v1/auth/login"}


class RateLimitMiddleware(BaseHTTPMiddleware):
    """Sliding-window rate limiter keyed on client IP."""

    def __init__(self, app, *args, **kwargs) -> None:  # noqa: ANN001
        super().__init__(app, *args, **kwargs)
        self._buckets: dict[str, deque] = defaultdict(deque)

    def _check(self, key: str, limit: int, window: int) -> bool:
        now = time.monotonic()
        bucket = self._buckets[key]
        while bucket and bucket[0] < now - window:
            bucket.popleft()
        if len(bucket) >= limit:
            return False
        bucket.append(now)
        return True

    async def dispatch(self, request: Request, call_next):
        settings = get_settings()
        client = request.client.host if request.client else "unknown"

        if request.url.path in _LOGIN_PATHS:
            ok = self._check(
                f"login:{client}",
                settings.login_rate_limit,
                settings.login_rate_window_seconds,
            )
        else:
            ok = self._check(
                f"general:{client}",
                settings.general_rate_limit,
                settings.general_rate_window_seconds,
            )

        if not ok:
            return JSONResponse(
                status_code=429,
                content=error_payload(
                    "RATE_LIMITED", "Too many requests. Please try again later."
                ),
            )
        return await call_next(request)
