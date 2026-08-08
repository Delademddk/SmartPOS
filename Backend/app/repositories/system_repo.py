"""Repositories for notifications, settings and audit logs."""

from __future__ import annotations

from datetime import datetime

from sqlalchemy import func, or_, select
from sqlalchemy.orm import Session

from app.models.audit import (
    ActivityLog,
    AuditLog,
    ErrorLog,
    SecurityLog,
)
from app.models.notifications import Notification, NotificationHistory, NotificationType
from app.models.settings import Setting, UserSetting
from app.repositories.base import BaseRepository


class NotificationTypeRepository(BaseRepository[NotificationType]):
    model = NotificationType

    def get_by_code(self, code: str) -> NotificationType | None:
        stmt = select(NotificationType).where(NotificationType.type_code == code)
        return self.session.scalar(stmt)


class NotificationRepository(BaseRepository[Notification]):
    model = Notification

    def list_for_user(
        self,
        user_id: int,
        is_read: bool | None,
        page: int,
        page_size: int,
    ) -> tuple[list[Notification], int]:
        filters = [Notification.user_id == user_id]
        if is_read is not None:
            filters.append(Notification.is_read.is_(is_read))
        total = int(
            self.session.scalar(select(func.count()).select_from(Notification).where(*filters)) or 0
        )
        stmt = (
            select(Notification)
            .where(*filters)
            .order_by(Notification.created_at.desc())
            .offset((page - 1) * page_size)
            .limit(page_size)
        )
        return list(self.session.scalars(stmt).all()), total

    def unread_count(self, user_id: int) -> int:
        stmt = select(func.count()).select_from(Notification).where(
            Notification.user_id == user_id,
            Notification.is_read.is_(False),
        )
        return int(self.session.scalar(stmt) or 0)


class NotificationHistoryRepository(BaseRepository[NotificationHistory]):
    model = NotificationHistory


class SettingRepository(BaseRepository[Setting]):
    model = Setting

    def get_by_key(self, key: str) -> Setting | None:
        stmt = select(Setting).where(Setting.setting_key == key)
        return self.session.scalar(stmt)


class UserSettingRepository(BaseRepository[UserSetting]):
    model = UserSetting

    def get_for_user(self, user_id: int, key: str) -> UserSetting | None:
        stmt = select(UserSetting).where(
            UserSetting.user_id == user_id,
            UserSetting.setting_key == key,
        )
        return self.session.scalar(stmt)


class AuditLogRepository(BaseRepository[AuditLog]):
    model = AuditLog

    def list_filtered(
        self,
        user_id: int | None,
        resource_type: str | None,
        action_type: str | None,
        date_from: datetime | None,
        date_to: datetime | None,
        page: int,
        page_size: int,
    ) -> tuple[list[AuditLog], int]:
        filters = []
        if user_id:
            filters.append(AuditLog.user_id == user_id)
        if resource_type:
            filters.append(AuditLog.resource_type == resource_type)
        if action_type:
            filters.append(AuditLog.action_type == action_type)
        if date_from:
            filters.append(AuditLog.created_at >= date_from)
        if date_to:
            filters.append(AuditLog.created_at <= date_to)

        total = int(self.session.scalar(select(func.count()).select_from(AuditLog).where(*filters)) or 0)
        stmt = (
            select(AuditLog)
            .where(*filters)
            .order_by(AuditLog.created_at.desc())
            .offset((page - 1) * page_size)
            .limit(page_size)
        )
        return list(self.session.scalars(stmt).all()), total


class ActivityLogRepository(BaseRepository[ActivityLog]):
    model = ActivityLog


class SecurityLogRepository(BaseRepository[SecurityLog]):
    model = SecurityLog

    def log_event(
        self,
        event_type: str,
        user_id: int | None,
        username: str | None,
        ip_address: str | None,
        user_agent: str | None,
        message: str | None,
    ) -> SecurityLog:
        entry = SecurityLog(
            user_id=user_id,
            event_type=event_type,
            username=username,
            ip_address=ip_address,
            user_agent=user_agent,
            message=message,
        )
        self.session.add(entry)
        return entry


class ErrorLogRepository(BaseRepository[ErrorLog]):
    model = ErrorLog

    def log(
        self,
        message: str,
        error_code: str | None,
        stack_trace: str | None,
        source: str | None,
        http_status: int | None,
        user_id: int | None,
        ip_address: str | None,
    ) -> ErrorLog:
        entry = ErrorLog(
            user_id=user_id,
            error_code=error_code,
            message=message,
            stack_trace=stack_trace,
            source=source,
            http_status=http_status,
            ip_address=ip_address,
        )
        self.session.add(entry)
        return entry
