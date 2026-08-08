"""Report endpoints (Feature 15)."""

from __future__ import annotations

from typing import Annotated

from fastapi import APIRouter, Depends, Response
from sqlalchemy.orm import Session

from app.api.dependencies.auth import require_permission
from app.api.dependencies.database import get_db_session
from app.api.schemas.reports import ReportRequest
from app.core.constants import PermissionCode
from app.models.users import User
from app.services.reports_service import ReportsService
from app.utils.response import success_response

router = APIRouter(prefix="/reports", tags=["Reports"])


@router.post("", response_model=dict)
def generate_report(
    payload: ReportRequest,
    user: Annotated[User, Depends(require_permission(PermissionCode.REPORTS_VIEW))],
    db: Session = Depends(get_db_session),
) -> dict:
    report = ReportsService(db).generate(payload)
    return success_response(report.model_dump())
