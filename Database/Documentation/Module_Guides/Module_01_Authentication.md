# Module 01 — Authentication (RBAC)

**SQL source:** `Database/SQL/01_Authentication/`
**Purpose:** Role-Based Access Control foundation used by every other module.

## Tables

| Table | Purpose |
|-------|---------|
| `roles` | Security roles. `role_code` (e.g. `ADMIN`, `MANAGER`, `CASHIER`) is the stable key; `is_system` protects built-in roles. |
| `permissions` | Granular permissions (`permission_code`, grouped by `module_name`). |
| `role_permissions` | Association grants a permission to a role; unique on `(role_id, permission_id)`. |

## Stored Procedures

| Procedure | Purpose |
|-----------|---------|
| `SP_Login` | Authenticate (`username`/`email` + password hash), enforce lockout, create session, log `security_logs`. |
| `SP_Logout` | Revoke the current session and log `LOGOUT`. |
| `SP_ValidateSession` | Validate a session token; enforce `expires_at` and `is_revoked`. |
| `SP_GetRoles` / `SP_GetRole` | List / fetch one role. |
| `SP_CreateRole` / `SP_UpdateRole` / `SP_DeleteRole` | Manage roles; system roles are protected from deletion. |
| `SP_GetPermissions` | List permissions (optionally by module). |

## Dependencies

- Referenced by Module 02 (`users.role_id`), `FN_HasPermission`, `VW_UserPermissions`.
- Seeded roles/grants: ADMIN (50), MANAGER (34), CASHIER (11) = 95 permissions grants.

## Notes

- Passwords are stored **hashed**; login compares hashes, never plaintext.
- Lockout: `failed_login_attempts` / `locked_until` on `users`.
- `SP_DeleteRole` refuses to delete roles still assigned to users.
