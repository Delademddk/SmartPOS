"""SmartPOS FastAPI application entrypoint.

Wires configuration, middleware, exception handlers and all feature routers
under the configured `/api/v1` prefix.
"""

from __future__ import annotations

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api.routers import (
    audit,
    auth,
    business,
    categories,
    credits,
    dashboard,
    health,
    inventory,
    notifications,
    payments,
    products,
    reports,
    returns,
    roles,
    sales,
    settings as settings_router,   # <- renamed router import
    suppliers,
    users,
)
from app.core.config import get_settings
from app.core.logging import get_logger, setup_logging
from app.middleware.access_log import AccessLogMiddleware
from app.middleware.error_handler import install_exception_handlers
from app.middleware.rate_limit import RateLimitMiddleware
from app.middleware.request_id import RequestIDMiddleware

logger = get_logger("app.main")


def create_app() -> FastAPI:
    config = get_settings()  # <- renamed config variable
    setup_logging()

    app = FastAPI(
        title=config.app_name,
        version=config.app_version,
        description=(
            "SmartPOS Point of Sale REST API. "
            "All responses use a standard envelope."
        ),
        docs_url="/docs" if not config.is_production else None,
        redoc_url="/redoc" if not config.is_production else None,
    )

    app.add_middleware(
        CORSMiddleware,
        allow_origins=config.cors_origins,
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )
    app.add_middleware(RequestIDMiddleware)
    app.add_middleware(AccessLogMiddleware)
    app.add_middleware(RateLimitMiddleware)

    install_exception_handlers(app)

    prefix = config.api_v1_prefix

    app.include_router(health.router, prefix=prefix)
    app.include_router(auth.router, prefix=prefix)
    app.include_router(roles.router, prefix=prefix)
    app.include_router(users.router, prefix=prefix)
    app.include_router(business.router, prefix=prefix)
    app.include_router(settings_router.router, prefix=prefix)  # <- fixed
    app.include_router(categories.router, prefix=prefix)
    app.include_router(products.router, prefix=prefix)
    app.include_router(suppliers.router, prefix=prefix)
    app.include_router(inventory.router, prefix=prefix)
    app.include_router(sales.router, prefix=prefix)
    app.include_router(payments.router, prefix=prefix)
    app.include_router(credits.router, prefix=prefix)
    app.include_router(returns.router, prefix=prefix)
    app.include_router(notifications.router, prefix=prefix)
    app.include_router(audit.router, prefix=prefix)
    app.include_router(reports.router, prefix=prefix)
    app.include_router(dashboard.router, prefix=prefix)

    @app.get("/", include_in_schema=False)
    def root() -> dict:
        return {
            "service": config.app_name,
            "version": config.app_version,
            "docs": "/docs",
        }

    logger.info(
        "application_started",
        name=config.app_name,
        version=config.app_version,
        env=config.app_env,
    )

    return app


app = create_app()