"""FastAPI dependencies for database sessions and pagination."""

from __future__ import annotations

from collections.abc import Generator

from fastapi import Depends, Query
from sqlalchemy.orm import Session

from app.database.session import get_db as _get_db
from app.utils.pagination import PageParams, normalize_pagination


def get_db_session() -> Generator[Session, None, None]:
    """Yield a database session and guarantee rollback/close on error."""
    yield from _get_db()


def get_pagination(
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=50, ge=1, le=200),
) -> PageParams:
    """Validate query-string pagination parameters."""
    return normalize_pagination(page, page_size)


def get_db_session_dependency() -> type[Session]:
    """Return the session dependency marker for type hints."""
    return Session  # type: ignore[return-value]
