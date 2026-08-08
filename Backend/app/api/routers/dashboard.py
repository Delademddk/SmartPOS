"""Dashboard endpoints (Feature 16)."""

from __future__ import annotations

from typing import Annotated

from fastapi import APIRouter, Depends, Query, Response
from sqlalchemy.orm import Session

from app.api.dependencies.auth import get_current_user, require_permission
from app.api.dependencies.database import get_db_session
from app.core.constants import PermissionCode
from app.models.users import User
from app.services.dashboard_service import DashboardService
from app.utils.response import success_response

router = APIRouter(prefix="/dashboard", tags=["Dashboard"])


@router.get("/kpis", response_model=dict)
def dashboard_kpis(
    user: Annotated[User, Depends(require_permission(PermissionCode.DASHBOARD_VIEW))],
    db: Session = Depends(get_db_session),
) -> dict:
    return success_response(DashboardService(db).kpis())


@router.get("/recent-sales", response_model=dict)
def recent_sales(
    user: Annotated[User, Depends(get_current_user)],
    db: Session = Depends(get_db_session),
    limit: int = Query(default=20, ge=1, le=100),
) -> dict:
    return success_response(DashboardService(db).recent_sales(limit=limit))


@router.get("/sales-trend-7d", response_model=dict)
def sales_trend(
    user: Annotated[User, Depends(get_current_user)],
    db: Session = Depends(get_db_session),
) -> dict:
    return success_response(DashboardService(db).sales_trend_7d())


@router.get("/top-products", response_model=dict)
def top_products(
    user: Annotated[User, Depends(get_current_user)],
    db: Session = Depends(get_db_session),
    days: int = Query(default=30, ge=1, le=365),
    limit: int = Query(default=10, ge=1, le=50),
) -> dict:
    return success_response(DashboardService(db).top_products(days=days, limit=limit))


@router.get("/sales-by-category", response_model=dict)
def sales_by_category(
    user: Annotated[User, Depends(get_current_user)],
    db: Session = Depends(get_db_session),
    days: int = Query(default=30, ge=1, le=365),
) -> dict:
    return success_response(DashboardService(db).sales_by_category(days=days))


@router.get("/sales-by-payment-method", response_model=dict)
def sales_by_payment_method(
    user: Annotated[User, Depends(get_current_user)],
    db: Session = Depends(get_db_session),
) -> dict:
    return success_response(DashboardService(db).sales_by_payment_method())


@router.get("/outstanding-credit", response_model=dict)
def outstanding_credit(
    user: Annotated[User, Depends(get_current_user)],
    db: Session = Depends(get_db_session),
    limit: int = Query(default=20, ge=1, le=100),
) -> dict:
    return success_response(DashboardService(db).outstanding_credit(limit=limit))


@router.get("/recent-notifications", response_model=dict)
def recent_notifications(
    user: Annotated[User, Depends(get_current_user)],
    db: Session = Depends(get_db_session),
    limit: int = Query(default=10, ge=1, le=50),
) -> dict:
    return success_response(DashboardService(db).recent_notifications(limit=limit))


@router.get("/me", response_model=dict)
def cashier_dashboard(
    user: Annotated[User, Depends(get_current_user)],
    db: Session = Depends(get_db_session),
) -> dict:
    return success_response(DashboardService(db).cashier_dashboard(user))
