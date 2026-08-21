# SmartPOS Database — Security Guide

**Document ID:** DOC-DB-SECURITY
**Version:** 1.0
**Status:** Approved
**Date:** August 7, 2026

Security guidance for the SmartPOS SQL Server database: access control,
secrets handling, RBAC, audit, and operational hardening. Designed for a
POS deployment where a compromised credential must not expose sale
history, customer credit, or password material.

---

## 1. Security Principles

1. **Least privilege.** The application connects with a dedicated login that
   can `EXECUTE` stored procedures and `SELECT` from views/functions — and
   **nothing else**. It has **no direct table access**.
2. **Defense in depth.** RBAC inside the app, `EXECUTE`-only at the database,
   hashed secrets at rest, TLS/encryption in transit, and a full audit trail.
3. **No secrets in code or config files.** Connection strings come from
   environment variables (see [`ConfigurationGuide.md`](ConfigurationGuide.md)).
4. **All passwords and tokens hashed.** The database never stores plaintext
   secrets; even the seed placeholders are hashes (to be replaced at install).
5. **Audit everything that matters.** Changes to security-relevant data and
   all authentication events are recorded.

---

## 2. Authentication & Secrets

### 2.1 Password handling

- `users.password_hash` stores the **hash**, never the plaintext.
- Passwords are hashed with a strong, salted algorithm **in the application
  layer** before they reach the stored procedures (`SP_CreateUser`,
  `SP_ChangePassword`, `SP_ResetPassword`, ...).
- Password history is retained (max 5 per user via
  `TRG_password_history_retention`) so users cannot immediately reuse old
  passwords; `password_changed_at` is updated on every change.
- `must_change_password = 1` forces a password rotation at first login.
- `failed_login_attempts` and `locked_until` implement account lockout; a
  successful login resets the counter.

### 2.2 Tokens (sessions & resets)

- Session and password-reset tokens are stored **hashed** using
  `FN_HashToken` (SHA2-256). The plaintext token is only ever returned once
  to the caller.
- `user_sessions.expires_at` limits session lifetime; `is_revoked` allows
  instant logout/revocation.
- `password_resets` tokens expire (`expires_at`), are single-use
  (`used_at`), and invalidate outstanding tokens on password change.

### 2.3 SQL logins

Use **SQL Server authentication with strong passwords**, or Windows/integrated
auth when the domain allows it (`DB_TRUSTED_CONNECTION`). Never use the `sa`
account for the application — create a dedicated login:

```sql
CREATE LOGIN pos_app WITH PASSWORD = '<generated-strong-password>',
    CHECK_POLICY = ON, CHECK_EXPIRATION = ON;
```

The `pos_app` login is scoped by a database user mapped to the
application role (see §3).

---

## 3. Application Access Model

### 3.1 Database user & role

```sql
USE SmartPOS;
CREATE USER pos_app FOR LOGIN pos_app;
CREATE ROLE pos_app_role;
ALTER ROLE pos_app_role ADD MEMBER pos_app;
```

### 3.2 Least-privilege grants

The application role gets:

| Principal type | Grants |
|----------------|--------|
| Stored procedures | `EXECUTE` on all `SP_*` (and **not** `EXECUTE AS OWNER` unless audited) |
| Views | `SELECT` on `VW_*` |
| Scalar functions | `EXECUTE`/`SELECT` on `FN_*` |
| Tables | **None** — no direct `SELECT`/`INSERT`/`UPDATE`/`DELETE` |
| DDL / server state | None |

```sql
GRANT EXECUTE ON SCHEMA::dbo TO pos_app_role;   -- scoped to SP/FN objects
GRANT SELECT ON SCHEMA::dbo TO pos_app_role;    -- only views in this schema
-- Do NOT grant INSERT/UPDATE/DELETE/SELECT on tables directly.
```

> If `GRANT EXECUTE ON SCHEMA` is too broad, grant per-object with a script
> generated from the object inventory in [`Database/SQL/README.md`](../SQL/README.md).

Because the role cannot touch tables directly, even a compromised
application account cannot `UPDATE users SET password_hash = ...`, truncate
`audit_logs`, or read `sale_items` wholesale. All data access flows through
the audited procedures.

### 3.3 Permissions at the SQL level (`VW_UserPermissions` / `FN_HasPermission`)

Row-level authorization is enforced **inside** procedures using
`FN_HasPermission(@UserId, 'permission.code')`. The effective role/permission
matrix is maintained in `roles`, `permissions`, `role_permissions` (Module 01)
and surfaced through `VW_UserPermissions`. The application should rely on
these for UI gating **and** the database should re-check them at the procedure
boundary for sensitive operations.

### 3.4 Connection strings

Example (matches `Configuration/database.env.example`):

```
Server=localhost,1433;Database=SmartPOS;User Id=pos_app;
Password=<from-env>;TrustServerCertificate=true;
Encrypt=true;Application Name=SmartPOS-POS;
```

- **Encrypt=true** — encrypt the connection (SQL Server 2016+ `TrustServerCertificate` semantics).
- Use `Pooling=true` with `Max Pool Size` sized to expected concurrency.
- Never hard-code credentials; inject from environment (see
  [`ConfigurationGuide.md`](ConfigurationGuide.md)).

---

## 4. Injection & Input Safety

1. **Parameterized procedures.** All data access is through stored
   procedures with typed parameters — no dynamic SQL concatenation of user
   input anywhere in `Database/SQL/`.
2. **Strict validation.** Procedures `THROW` on invalid input (negative
   quantities, missing required fields, non-existent references).
3. **JSON input parsing.** `SP_CreateSale` and `SP_ProcessReturn` accept
   JSON line items parsed with `OPENJSON`. Validate inside the JSON: quantity
   `> 0`, prices within sane bounds, no unknown keys — then re-check against
   database state (stock, sale totals) inside the transaction.
4. **Never concatenate SQL.** If a procedure must build dynamic statements
   (e.g. `SP_ExportReport`), build the WHERE clause from validated parameters
   only — never from user-supplied strings — and prefer `sp_executesql` with
   parameters.
5. **Escape and constrain free text** at the application layer (names,
   addresses) to the declared column lengths; rely on `LEN` checks in
   procedures where relevant.

---

## 5. Audit & Monitoring

### 5.1 Audit triggers

`TRG_products_audit`, `TRG_categories_audit`, `TRG_suppliers_audit`,
`TRG_users_audit`, `TRG_settings_audit` write JSON before/after snapshots to
`audit_logs` on INSERT/UPDATE/DELETE (including soft deletes).

**Critical rule:** `TRG_users_audit` **never includes `password_hash`** in the
JSON snapshots — password material must not leak into audit logs.

### 5.2 Security log

`security_logs` records authentication events:
`LOGIN_SUCCESS`, `LOGIN_FAILED`, `LOGOUT`, `LOCKOUT`, `RESET`, `REVOKED`.
Written by `SP_Login`, `SP_Logout`, `SP_ValidateSession`,
`SP_RequestPasswordReset`, `SP_CompletePasswordReset` and lockout paths.

### 5.3 Reviewing security events

```sql
SELECT TOP 100 event_type, user_id, ip_address, user_agent,
       event_details, created_at
FROM security_logs
ORDER BY created_at DESC;

-- Failed-login bursts (possible brute force)
SELECT user_id, COUNT(*) AS failures, MIN(created_at) AS first_at,
       MAX(created_at) AS last_at
FROM security_logs
WHERE event_type = 'LOGIN_FAILED'
  AND created_at >= DATEADD(HOUR, -1, SYSUTCDATETIME())
GROUP BY user_id
HAVING COUNT(*) >= 10
ORDER BY failures DESC;
```

### 5.4 Operational/error logs

`activity_logs` (key user actions) and `error_logs` (procedure/application
errors with stack trace) support troubleshooting and forensics. Monitor
`error_logs` for repeated failures as an early indicator of attack attempts.

---

## 6. Infrastructure Hardening

### 6.1 SQL Server instance

- Use **Windows or SQL authentication with strong policies** (complexity +
  expiration enabled via `CHECK_POLICY`/`CHECK_EXPIRATION`).
- **Rename or disable `sa`** and never use it from applications:
  ```sql
  ALTER LOGIN sa DISABLE;
  ```
- Restrict remote access to trusted subnets; prefer TLS 1.2+ for the SQL
  connection (`Encrypt=true`, `TrustServerCertificate=true` only with a real
  cert in production).
- Run the instance as a **low-privilege service account**; grant the service
  account only what SQL Server requires.
- Do **not** expose SQL Server (1433) to the public internet — put it behind
  a firewall/VPN; the POS clients reach it over the private network.

### 6.2 Backups

- Backups are encrypted (`BACKUP DATABASE ... WITH ENCRYPTION`) using a
  database master key protected by a service/master key, or by an external
  key management solution.
- Store off-site copies and test restores — see
  [`BackupGuide.md`](BackupGuide.md) and [`RestoreGuide.md`](RestoreGuide.md).
- Backup files contain **live application data** (customer credit, sale
  history) — protect them like production data; the `Backup/` folder must not
  be world-readable.

### 6.3 Application

- POS clients authenticate with the **dedicated `pos_app` login** — never
  reuse the DBA account.
- Rotate the application login password periodically; rotate session/reset
  tokens on every password change.
- Keep `FN_HasPermission` checks in place even if the UI hides features —
  the database is the enforcement point, not the UI.

---

## 7. Seed Data & Defaults

The shipped seed (`SeedData/SeedData.sql`) creates built-in roles and
permissions. **Important installation steps**:

1. The seeded `password_hash` values are **placeholders**. The installer must
   set a real hash immediately after build (see
   [`DeploymentGuide.md`](DeploymentGuide.md) and
   [`Module_20_Setup.md`](Module_Guides/Module_20_Setup.md)).
2. Seed accounts are created with `must_change_password = 1` so they cannot
   be used indefinitely with the default credential.
3. Remove or lock any diagnostic/test logins before production.

---

## 8. Security Checklist

- [ ] `sa` disabled; dedicated `pos_app` login with strong password policy.
- [ ] `pos_app_role`: `EXECUTE`/`SELECT` on schema::dbo only; **no table grants**.
- [ ] Seed placeholder password hashes replaced; seed accounts force password change.
- [ ] `TRG_users_audit` verified to exclude `password_hash`.
- [ ] `security_logs` reviewed for failed-login bursts after go-live.
- [ ] `Encrypt=true` on all client connection strings; port 1433 firewalled.
- [ ] Backups encrypted; off-site copies; test restores scheduled.
- [ ] `run_tests.sh` security suite (`06_security_roles.sql` + others) passes.

---

## 9. Revision History

| Version | Date | Description |
|---------|------|-------------|
| 1.0 | 2026-08-07 | Initial security guide |
