"""SQLAlchemy engine creation."""

from __future__ import annotations

from sqlalchemy import create_engine, event
from sqlalchemy.engine import Engine

from app.core.config import get_settings


def _apply_connect_args(engine: Engine) -> None:
    """Set FastExecuteMany / READ_COMMITTED_SNAPSHOT-friendly settings for mssql."""

    @event.listens_for(engine, "connect")
    def _set_timeout(dbapi_connection, _connection_record):  # noqa: ANN001
        try:
            cursor = dbapi_connection.cursor()
            cursor.execute("SET LOCK_TIMEOUT 5000")
            cursor.close()
        except Exception:  # noqa: BLE001 - best effort only
            pass


def build_engine() -> Engine:
    """Build the SQLAlchemy engine from settings.

    Production uses SQL Server. Tests and local development may override
    ``DATABASE_URL`` with a SQLite URL, which the generic column types used
    across the models support transparently.
    """
    settings = get_settings()
    url = settings.sqlalchemy_database_uri

    kwargs: dict = {
        "pool_pre_ping": True,
        "pool_recycle": 1800,
        "future": True,
    }

    if url.startswith("mssql"):
        kwargs["pool_size"] = 5
        kwargs["max_overflow"] = 10
    elif url.startswith("sqlite"):
        kwargs["connect_args"] = {"check_same_thread": False}

    engine = create_engine(url, **kwargs)

    if url.startswith("mssql"):
        _apply_connect_args(engine)

    return engine
