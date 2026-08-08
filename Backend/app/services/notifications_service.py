"""Notifications service (Feature 14)."""

from __future__ import annotations

from app.api.schemas.notifications import NotificationCreate
from app.core.constants import NotificationSeverity
from app.exceptions import ForbiddenError, NotFoundError, ValidationError_
from app.models.notifications import Notification, NotificationType
from app.models.users import User
from app.repositories.system_repo import (
    NotificationHistoryRepository,
    NotificationRepository,
    NotificationTypeRepository,
)
from app.services.audit_service import AuditService
from app.services.base import BaseService
from app.utils.pagination import PageParams


class NotificationService(BaseService):
    service_name = "notifications"

    def __init__(self, session) -> None:  # noqa: ANN001
        super().__init__(session)
        self.notifications = NotificationRepository(session)
        self.types = NotificationTypeRepository(session)
        self.history = NotificationHistoryRepository(session)
        self.audit = AuditService(session)

    # ------------------------------------------------------------------
    def list_types(self) -> list[NotificationType]:
        return self.types.list_all()

    def list_for_user(
        self,
        user: User,
        page: PageParams,
        is_read: bool | None,
    ) -> tuple[list[Notification], int]:
        return self.notifications.list_for_user(
            user_id=user.user_id,
            is_read=is_read,
            page=page.page,
            page_size=page.page_size,
        )

    def unread_count(self, user: User) -> int:
        return self.notifications.unread_count(user.user_id)

    def get_for_user(self, user: User, notification_id: int) -> Notification:
        notification = self.notifications.get(notification_id)
        if notification is None:
            raise NotFoundError("Notification not found.")
        if notification.user_id != user.user_id:
            raise ForbiddenError("You cannot access this notification.")
        return notification

    def mark_read(self, user: User, notification_id: int) -> Notification:
        notification = self.get_for_user(user, notification_id)
        if not notification.is_read:
            notification.is_read = True
            from app.database.base import utcnow

            notification.read_at = utcnow()
            self.session.commit()
        return self.notifications.get(notification_id)

    def mark_dismissed(self, user: User, notification_id: int) -> Notification:
        notification = self.get_for_user(user, notification_id)
        notification.is_dismissed = True
        self.session.commit()
        return self.notifications.get(notification_id)

    def mark_all_read(self, user: User) -> int:
        count = 0
        for notification in self.notifications.list_for_user(
            user.user_id, is_read=False, page=1, page_size=1000
        )[0]:
            notification.is_read = True
            from app.database.base import utcnow

            notification.read_at = utcnow()
            count += 1
        self.session.commit()
        return count

    def create(self, payload: NotificationCreate, actor: User | None) -> Notification:
        if self.types.get(payload.notification_type_id) is None:
            raise ValidationError_(
                "Notification type does not exist.",
                [{"field": "notification_type_id", "message": "Invalid type"}],
            )
        notification = Notification(**payload.model_dump())
        self.notifications.add(notification)
        if actor is not None:
            self.audit.activity(
                activity_type="NOTIFICATION_CREATED",
                activity_desc=f"Notification sent to user {payload.user_id}",
                entity_type="Notification",
                entity_id=notification.notification_id,
                user_id=actor.user_id,
            )
        self.session.commit()
        return self.notifications.get(notification.notification_id)

    # ------------------------------------------------------------------
    # Internal helpers
    # ------------------------------------------------------------------
    def notify(
        self,
        *,
        user_id: int,
        type_code: str,
        title: str,
        message: str,
        severity: str = NotificationSeverity.INFO.value,
        entity_type: str | None = None,
        entity_id: str | None = None,
    ) -> Notification | None:
        notification_type = self.types.get_by_code(type_code)
        if notification_type is None:
            self.logger.warning("notification_type_missing", type_code=type_code)
            return None
        notification = Notification(
            user_id=user_id,
            notification_type_id=notification_type.notification_type_id,
            title=title,
            message=message,
            severity=severity,
            entity_type=entity_type,
            entity_id=entity_id,
        )
        self.notifications.add(notification)
        return notification

    def notify_low_stock(self, product_name: str, product_id: int, quantity: int, threshold: int) -> None:
        for admin in self._admin_users():
            self.notify(
                user_id=admin.user_id,
                type_code="LOW_STOCK",
                title="Low stock alert",
                message=(
                    f"'{product_name}' is at {quantity} units, "
                    f"below the threshold of {threshold}."
                ),
                severity=NotificationSeverity.WARNING.value,
                entity_type="Product",
                entity_id=str(product_id),
            )

    def _admin_users(self) -> list[User]:
        from app.models.auth import Role
        from app.models.users import User as UserModel

        admins = self.session.query(UserModel).join(Role).filter(
            Role.role_code == "ADMIN",
            UserModel.is_active.is_(True),
            UserModel.is_deleted.is_(False),
        ).all()
        return list(admins)
