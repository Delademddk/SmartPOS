"""Request ID middleware: attach/generate a request id for tracing."""

from __future__ import annotations

import uuid

from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request
from starlette.responses import Response

from app.utils.response import REQUEST_ID_CONTEXT


class RequestIDMiddleware(BaseHTTPMiddleware):
    """Ensure every request carries an ``x-request-id`` header/context."""

    async def dispatch(self, request: Request, call_next):
        rid = request.headers.get("x-request-id") or str(uuid.uuid4())
        request.scope[REQUEST_ID_CONTEXT] = rid
        response: Response = await call_next(request)
        response.headers["x-request-id"] = rid
        return response
