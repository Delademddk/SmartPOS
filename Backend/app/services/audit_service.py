"""Audit trail service.

Writes audit, activity and security log entries used across every module so
that important actions remain auditable (Project Bible business rule).
"""

from __future__ import annotations

import json
from typing import Any

from sqlalchemy.orm import Session

from app.core.logging import get_logger
from app.repositories.system_repo import (
    ActivityLogRepository,
    AuditLogRepository,
    ErrorLogRepository,
    SecurityLogRepository,
)

logger = get_logger("services.audit")


def _json(values: dict[str, Any] | None) -> str | None:
    if not values:
        return None
    return json.dumps(values, default=str)


class AuditService:
    def __init__(self, session: Session) -> None:
        self.session = session
        self.audit_repo = AuditLogRepository(session)
        self.activity_repo = ActivityLogRepository(session)
        self.security_repo = SecurityLogRepository(session)
        self.error_repo = ErrorLogRepository(session)

    def record(
        self,
        *,
        action_type: str,
        resource_type: str,
        resource_id: int | str | None = None,
        user_id: int | None = None,
        old_values: dict[str, Any] | None = None,
        new_values: dict[str, Any] | None = None,
        details: dict[str, Any] | None = None,
        ip_address: str | None = None,
        user_agent: str | None = None,
    ) -> None:
        entry = self.audit_repo.add(
            self.audit_repo.model(
                user_id=user_id,
                action_type=action_type,
                resource_type=resource_type,
                resource_id=str(resource_id) if resource_id is not None else None,
                old_values=_json(old_values),
                new_values=_json(new_values),
                ip_address=ip_address,
                user_agent=user_agent,
                details=_json(details),
            )
        )
        self.session.flush()
        logger.info(
            "audit_recorded",
            action_type=action_type,
            resource_type=resource_type,
            resource_id=resource_id,
            user_id=user_id,
        )
        return entry  # type: ignore[return-value]

    def activity(
        self,
        *,
        activity_type: str,
        activity_desc: str | None = None,
        entity_type: str | None = None,
        entity_id: int | str | None = None,
        metadata: dict[str, Any] | None = None,
        user_id: int | None = None,
        ip_address: str | None = None,
        user_agent: str | None = None,
    ) -> None:
        self.activity_repo.add(
            self.activity_repo.model(
                user_id=user_id,
                activity_type=activity_type,
                activity_desc=activity_desc,
                entity_type=entity_type,
                entity_id=str(entity_id) if entity_id is not None else None,
                metadata=_json(metadata),
                ip_address=ip_address,
                user_agent=user_agent,
            )
        )

    def security(
        self,
        *,
        event_type: str,
        user_id: int | None = None,
        username: str | None = None,
        ip_address: str | None = None,
        user_agent: str | None = None,
        message: str | None = None,
    ) -> None:
        self.security_repo.log_event(
            event_type=event_type,
            user_id=user_id,
            username=username,
            ip_address=ip_address,
            user_agent=user_agent,
            message=message,
        )

    def error(
        self,
        *,
        message: str,
        error_code: str | None = None,
        stack_trace: str | None = None,
        source: str | None = None,
        http_status: int | None = None,
        user_id: int | None = None,
        ip_address: str | None = None,
    ) -> None:
        self.error_repo.log(
            message=message,
            error_code=error_code,
            stack_trace=stack_trace,
            source=source,
            http_status=http_status,
            user_id=user_id,
            ip_address=ip_address,
        )

    def flush(self) -> None:
        self.session.flush()
