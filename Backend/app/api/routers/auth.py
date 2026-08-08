"""Authentication endpoints (Feature 02)."""

from __future__ import annotations

from typing import Annotated

from fastapi import APIRouter, Depends, Request
from sqlalchemy.orm import Session

from app.api.dependencies.auth import get_current_user
from app.api.dependencies.database import get_db_session
from app.api.schemas.auth import (
    ChangePasswordRequest,
    LoginRequest,
    LogoutRequest,
    RefreshRequest,
    RequestPasswordResetRequest,
    CompletePasswordResetRequest,
)
from app.api.schemas.users import UserRead
from app.models.users import User
from app.services.auth_service import AuthService
from app.utils.response import success_response

router = APIRouter(prefix="/auth", tags=["Authentication"])


def _context(request: Request) -> tuple[str | None, str | None]:
    ip = request.client.host if request.client else None
    return ip, request.headers.get("user-agent")


@router.post("/login", response_model=dict)
def login(
    payload: LoginRequest,
    request: Request,
    db: Session = Depends(get_db_session),
) -> dict:
    ip, user_agent = _context(request)
    response = AuthService(db).login(payload, ip, user_agent)
    return success_response(response.model_dump())


@router.post("/refresh", response_model=dict)
def refresh(
    payload: RefreshRequest,
    request: Request,
    db: Session = Depends(get_db_session),
) -> dict:
    ip, user_agent = _context(request)
    response = AuthService(db).refresh(payload, ip, user_agent)
    return success_response(response.model_dump())


@router.post("/logout", status_code=200)
def logout(
    payload: LogoutRequest,
    request: Request,
    db: Session = Depends(get_db_session),
) -> dict:
    ip, user_agent = _context(request)
    AuthService(db).logout(payload.refresh_token, ip, user_agent)
    return success_response({"message": "Logged out successfully."})


@router.get("/me", response_model=dict)
def me(
    user: Annotated[User, Depends(get_current_user)],
    db: Session = Depends(get_db_session),
) -> dict:
    """Return the currently authenticated user profile."""
    current = db.get(User, user.user_id)
    return success_response(UserRead.model_validate(current).model_dump())


@router.post("/change-password", status_code=200)
def change_password(
    payload: ChangePasswordRequest,
    user: Annotated[User, Depends(get_current_user)],
    request: Request,
    db: Session = Depends(get_db_session),
) -> dict:
    AuthService(db).change_password(user, payload, None)
    return success_response({"message": "Password changed successfully."})


@router.post("/request-password-reset", status_code=200)
def request_password_reset(
    payload: RequestPasswordResetRequest,
    request: Request,
    db: Session = Depends(get_db_session),
) -> dict:
    ip, _user_agent = _context(request)
    AuthService(db).request_password_reset(payload, ip)
    return success_response(
        {"message": "If that email exists, a reset link has been generated."}
    )


@router.post("/reset-password", status_code=200)
def complete_password_reset(
    payload: CompletePasswordResetRequest,
    db: Session = Depends(get_db_session),
) -> dict:
    AuthService(db).complete_password_reset(payload)
    return success_response({"message": "Password reset successfully."})
