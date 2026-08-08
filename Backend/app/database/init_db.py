"""Database initialisation helpers.

The authoritative schema is defined by the SQL scripts in ``Database/SQL`` and
executed by ``scripts/setup_database``. ``init_db`` is provided so the
application can create the ORM-mapped tables when the schema has not yet been
installed (e.g. fresh local development or CI against SQLite). Views, stored
procedures, functions and seed data always come from the SQL scripts.
"""

from __future__ import annotations

from app.core.logging import get_logger
from app.database.base import Base
from app.database.session import engine

logger = get_logger("database.init")


def create_tables() -> None:
    """Create all mapped tables if they do not already exist."""
    # Import all models so they are registered on Base.metadata.
    from app import models  # noqa: F401

    Base.metadata.create_all(bind=engine)
    logger.info("database_tables_ready")


def dispose_engine() -> None:
    engine.dispose()
