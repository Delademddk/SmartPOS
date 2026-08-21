# Module 02 — Users

**SQL source:** `Database/SQL/02_Users/`
**Purpose:** Application user accounts, sessions, password lifecycle and resets.

## Tables

| Table | Purpose |
|-------|---------|
| `users` | Accounts. Unique `username`/`email`; `password_hash` only; `role_id` FK; lockout + `must_change_password` flags. |
| `user_sessions` | Revocable sessions (`token_hash` via `FN_HashToken`, `expires_at`, `is_revoked`). |
| `password_history` | Previous hashes; capped at 5 per user by `TRG_password_history_retention`. |
| `password_resets` | One-time, expiring reset tokens (hashed). |

## Stored Procedures

| Procedure | Purpose |
|-----------|---------|
| `SP_GetUsers` / `SP_GetUser` | List (with role info) / fetch one user. |
| `SP_CreateUser` | Create account (hash supplied by app), optionally force password change. |
| `SP_UpdateUser` | Update profile/role; guard against demoting the last ADMIN. |
| `SP_DeactivateUser` | Soft-disable an account (revokes active sessions). |
| `SP_ResetPassword` | Admin forces a new password; writes `password_history`, logs `security_logs`. |
| `SP_ChangePassword` | Self-service change after verifying current password; enforces reuse policy. |
| `SP_RequestPasswordReset` | Issue a one-time reset token (hashed at rest). |
| `SP_CompletePasswordReset` | Redeem a token and set a new password; invalidates outstanding tokens. |

## Dependencies

- Module 01 (`roles`), Module 16 (audit/logs), Module 12 (notifications).
- `TRG_users_audit` writes `audit_logs` — **never includes `password_hash`**.
- Retired sessions/password reset rows are purged per the maintenance retention policy.

## Notes

- `FN_GetUserDisplayName` provides a NULL-safe display name for reports.
- Username/email uniqueness is enforced by unique constraints (verified by the test suite).
