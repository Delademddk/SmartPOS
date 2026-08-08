"""Access logging middleware producing structured request logs."""

from __future__ import annotations

import time

from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request

from app.core.config import get_settings
from app.core.logging import get_logger
from app.utils.response import REQUEST_ID_CONTEXT

logger = get_logger("access")


class AccessLogMiddleware(BaseHTTPMiddleware):
    """Log method, path, status, duration and client for each request."""

    async def dispatch(self, request: Request, call_next):
        start = time.perf_counter()
        response = await call_next(request)
        duration_ms = (time.perf_counter() - start) * 1000
        if get_settings().enable_access_log:
            logger.info(
                "request",
                method=request.method,
                path=request.url.path,
                status_code=response.status_code,
                duration_ms=round(duration_ms, 2),
                client=request.client.host if request.client else None,
                request_id=request.scope.get(REQUEST_ID_CONTEXT),
            )
        return response
