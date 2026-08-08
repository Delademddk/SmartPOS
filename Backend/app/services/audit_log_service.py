"""Audit log queries service (Feature 17)."""

from __future__ import annotations

from datetime import datetime

from app.models.audit import ActivityLog, AuditLog, ErrorLog, SecurityLog
from app.repositories.system_repo import (
    ActivityLogRepository,
    AuditLogRepository,
    ErrorLogRepository,
    SecurityLogRepository,
)
from app.services.base import BaseService
from app.utils.pagination import PageParams


class AuditLogService(BaseService):
    service_name = "audit"

    def __init__(self, session) -> None:  # noqa: ANN001
        super().__init__(session)
        self.audit_repo = AuditLogRepository(session)
        self.activity_repo = ActivityLogRepository(session)
        self.security_repo = SecurityLogRepository(session)
        self.error_repo = ErrorLogRepository(session)

    def list_audit_logs(
        self,
        page: PageParams,
        user_id: int | None,
        resource_type: str | None,
        action_type: str | None,
        date_from: datetime | None,
        date_to: datetime | None,
    ) -> tuple[list[AuditLog], int]:
        return self.audit_repo.list_filtered(
            user_id=user_id,
            resource_type=resource_type,
            action_type=action_type,
            date_from=date_from,
            date_to=date_to,
            page=page.page,
            page_size=page.page_size,
        )

    def list_activity_logs(self, page: PageParams) -> tuple[list[ActivityLog], int]:
        entries = self.activity_repo.list_all()
        entries.sort(key=lambda a: a.created_at, reverse=True)
        total = len(entries)
        start = (page.page - 1) * page.page_size
        return entries[start : start + page.page_size], total

    def list_security_logs(self, page: PageParams) -> tuple[list[SecurityLog], int]:
        entries = self.security_repo.list_all()
        entries.sort(key=lambda a: a.created_at, reverse=True)
        total = len(entries)
        start = (page.page - 1) * page.page_size
        return entries[start : start + page.page_size], total

    def list_error_logs(self, page: PageParams) -> tuple[list[ErrorLog], int]:
        entries = self.error_repo.list_all()
        entries.sort(key=lambda a: a.occurred_at, reverse=True)
        total = len(entries)
        start = (page.page - 1) * page.page_size
        return entries[start : start + page.page_size], total
