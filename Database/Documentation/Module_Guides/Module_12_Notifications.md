# Module 12 — Notifications

**SQL source:** `Database/SQL/12_Notifications/`
**Purpose:** In-app notifications (low stock, sales, returns, credit, system, security).

## Tables

| Table | Purpose |
|-------|---------|
| `notification_types` | Categories (LOW_STOCK, SALE, RETURN, CREDIT, SYSTEM, SECURITY). |
| `notifications` | Per-recipient notifications: severity, read/dismissed flags, polymorphic `entity_type`/`entity_id`. |
| `notification_history` | Delivered/processed notification records. |

## Stored Procedures

| Procedure | Purpose |
|-----------|---------|
| `SP_GetNotifications` | List a user's notifications (unread first). |
| `SP_GetUnreadCount` | Badge count of unread notifications. |
| `SP_MarkNotificationRead` | Mark one notification read (by recipient). |
| `SP_DismissNotification` | Dismiss a notification. |
| `SP_CreateNotification` | Create a notification for a user/type with optional entity reference. |
| `SP_GetNotificationTypes` | List notification types. |
| `SP_ResetNotifications` | Mark all of a user's notifications read/dismissed. |

## Dependencies

- Module 02 (`users`); written by `TRG_inventory_low_stock` (Module 19) on low-stock events.
- Dashboard reads `VW_RecentNotifications` (Module 14).

## Notes

- The polymorphic entity reference (`entity_type`/`entity_id`) is intentional — a notification may point at any resource without hard FK coupling.
- Read/dismissed flags drive the unread badge; resolved alerts are pruned per the maintenance retention policy.
