"""Global exception handler translating domain errors into the error envelope."""

from __future__ import annotations

import uuid
from typing import Any

from fastapi import FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from starlette.exceptions import HTTPException as StarletteHTTPException

from app.core.logging import get_logger
from app.exceptions import SmartPOSError
from app.utils.response import REQUEST_ID_CONTEXT, error_payload

logger = get_logger("middleware.errors")


def _request_id(request: Request) -> str:
    rid = request.headers.get("x-request-id")
    if rid:
        return rid
    rid = str(uuid.uuid4())
    request.scope[REQUEST_ID_CONTEXT] = rid
    return rid


def install_exception_handlers(app: FastAPI) -> None:
    @app.exception_handler(SmartPOSError)
    async def smartpos_error_handler(request: Request, exc: SmartPOSError) -> JSONResponse:
        rid = _request_id(request)
        details = [
            {
                "field": (d.get("field") if isinstance(d, dict) else None),
                "message": (d.get("message", str(d)) if isinstance(d, dict) else str(d)),
            }
            for d in exc.details
        ]
        logger.warning(
            "domain_error",
            code=exc.code,
            message=exc.message,
            resource_type=exc.resource_type,
            resource_id=exc.resource_id,
            request_id=rid,
        )
        return JSONResponse(
            status_code=exc.status_code,
            content=error_payload(exc.code, exc.message, details, rid),
            headers={"x-request-id": rid},
        )

    @app.exception_handler(RequestValidationError)
    async def validation_error_handler(
        request: Request, exc: RequestValidationError
    ) -> JSONResponse:
        rid = _request_id(request)
        details = []
        for err in exc.errors():
            loc = ".".join(str(part) for part in err.get("loc", []) if part != "body")
            details.append(
                {"field": loc or "body", "message": err.get("msg", "Invalid value")}
            )
        return JSONResponse(
            status_code=422,
            content=error_payload("VALIDATION_ERROR", "Request validation failed.", details, rid),
            headers={"x-request-id": rid},
        )

    @app.exception_handler(StarletteHTTPException)
    async def http_exception_handler(
        request: Request, exc: StarletteHTTPException
    ) -> JSONResponse:
        rid = _request_id(request)
        return JSONResponse(
            status_code=exc.status_code,
            content=error_payload("HTTP_ERROR", str(exc.detail), None, rid),
            headers={"x-request-id": rid},
        )

    @app.exception_handler(Exception)
    async def unhandled_exception_handler(request: Request, exc: Exception) -> JSONResponse:
        rid = _request_id(request)
        logger.exception("unhandled_error", request_id=rid, path=request.url.path)
        return JSONResponse(
            status_code=500,
            content=error_payload("INTERNAL_ERROR", "An unexpected error occurred.", None, rid),
            headers={"x-request-id": rid},
        )
