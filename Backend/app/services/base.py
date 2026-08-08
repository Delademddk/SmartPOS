"""Base service class providing transaction and error-safe patterns."""

from __future__ import annotations

from typing import Any

from sqlalchemy.orm import Session

from app.core.logging import get_logger
from app.exceptions import SmartPOSError


class BaseService:
    """Common service behaviour: logger + session + safe commit."""

    service_name = "base"

    def __init__(self, session: Session) -> None:
        self.session = session
        self.logger = get_logger(f"services.{self.service_name}")

    def commit_or_raise(self) -> None:
        try:
            self.session.commit()
        except Exception as exc:  # noqa: BLE001
            self.session.rollback()
            self.logger.exception("transaction_failed", error=str(exc))
            raise

    def refresh(self, obj: Any) -> Any:
        self.session.refresh(obj)
        return obj

    def raise_error(self, error: SmartPOSError) -> None:
        raise error
