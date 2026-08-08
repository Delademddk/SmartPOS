"""Health check endpoint (liveness + DB readiness)."""

from __future__ import annotations

from fastapi import APIRouter, Depends
from sqlalchemy import text
from sqlalchemy.orm import Session

from app.api.dependencies.database import get_db_session
from app.utils.response import success_response

router = APIRouter(prefix="/health", tags=["System"])


@router.get("")
def health(db: Session = Depends(get_db_session)) -> dict:
    """Return service health including a lightweight database probe."""
    db_status = "ok"
    try:
        db.execute(text("SELECT 1"))
    except Exception:  # noqa: BLE001 - readiness reporting, not error handling
        db_status = "unavailable"
    return success_response(
        {
            "status": "ok" if db_status == "ok" else "degraded",
            "database": db_status,
        }
    )
