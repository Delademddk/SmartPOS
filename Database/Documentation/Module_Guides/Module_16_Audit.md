# Module 16 — Audit & Logging

**SQL source:** `Database/SQL/16_Audit/`
**Purpose:** Complete, durable audit trail and operational logs.

## Tables

| Table | Purpose |
|-------|---------|
| `audit_logs` | Change history (`action_type`, `resource_type`, `resource_id`, `old_values`/`new_values` JSON). |
| `activity_logs` | High-level user activity (logins, exports, key actions). |
| `error_logs` | Procedure/application errors (message, stack trace, source). |
| `security_logs` | Auth events: `LOGIN_SUCCESS`, `LOGIN_FAILED`, `LOGOUT`, `LOCKOUT`, `RESET`, `REVOKED`. |
| `audit_logs_archive` | Partitioned storage for rows rotated by `SP_ArchiveAuditLogs`. |

## Stored Procedures

| Procedure | Purpose |
|-----------|---------|
| `SP_GetAuditLogs` | Query audit history (filter by resource/user/action/date). |
| `SP_GetSecurityLogs` | Query security events (failed-login analysis). |
| `SP_GetErrorLogs` | Query error log. |
| `SP_ArchiveAuditLogs` | Move audit rows older than a cutoff into `audit_logs_archive` (run monthly — see [`MaintenanceGuide.md`](../MaintenanceGuide.md) §4). |

## Dependencies

- Module 02 (`users`) — actor columns.
- Written by audit triggers (`TRG_products_audit`, `TRG_categories_audit`, `TRG_suppliers_audit`, `TRG_users_audit`, `TRG_settings_audit`) and by auth procedures (`SP_Login`, `SP_Logout`, ...).

## Notes

- **`TRG_users_audit` never includes `password_hash`** in JSON snapshots.
- `audit_logs` grows fast — archival is part of the maintenance schedule.
- Security events are reviewed for brute-force patterns; see [`SecurityGuide.md`](../SecurityGuide.md) §5.3.
