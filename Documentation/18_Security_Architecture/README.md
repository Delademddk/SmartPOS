# SmartPOS — Security Architecture

**Document ID:** DOC-SEC-018  
**Version:** 1.0  
**Status:** Approved  
**Author:** SmartPOS Documentation Team  
**Date:** August 7, 2026  

---

## 1. Purpose

This document defines the **security architecture** for the SmartPOS system.
It covers authentication, authorization, password storage, environment-based
configuration, audit logging, and defense-in-depth measures against common
vulnerabilities (XSS, CSRF, SQL injection).

All security measures align with the
[Project Bible](../AI/SMARTPOS_PROJECT_BIBLE.md#security-requirements).

---

## 2. Authentication

### 2.1 Overview

SmartPOS uses **JWT (JSON Web Tokens)** for stateless authentication. A
two-token strategy is used:

| Token Type | Purpose | TTL |
|------------|---------|-----|
| **Access Token** | Authenticate each API request | 15 minutes |
| **Refresh Token** | Obtain a new access token | 7 days |

### 2.2 Login Flow

```
1. User submits username + password to POST /api/v1/auth/login
2. Backend validates credentials (bcrypt verify)
3. If valid and account active:
   a. Generate access_token (JWT, 15-min, signed with JWT_SECRET)
   b. Generate refresh_token (JWT, 7-day, signed with JWT_SECRET)
   c. Hash refresh_token, store in `refresh_tokens` table
   d. Log login event to `audit_logs`
   e. Return { access_token, refresh_token, expires_in, user }
4. If invalid: log failed attempt; return 401
```

### 2.3 Token Storage

| Token | Storage Location | Protection |
|-------|------------------|------------|
| Access Token | Browser memory / localStorage | Bearer header |
| Refresh Token | HttpOnly cookie (preferred) or localStorage | Not accessible to JS if HttpOnly |

### 2.4 Refresh Token Rotation

Each time the refresh endpoint is called:
1. Validate the presented refresh token (signature + expiry + not revoked).
2. Issue a new access and refresh token.
3. Invalidate the old refresh token (mark as revoked in DB).

This prevents token replay attacks.

### 2.5 Logout

- Client sends refresh token to `POST /api/v1/auth/logout`.
- Backend marks the refresh token as revoked in the database.
- Client clears all tokens from storage.

### 2.6 Rate Limiting

| Endpoint | Limit | Window |
|----------|-------|--------|
| `/auth/login` | 5 failed attempts | 15 minutes / IP |
| `/auth/refresh` | 10 requests | 15 minutes / IP |
| Account lockout after 5 consecutive failures | — | — |

After lockout, the account remains locked for 15 minutes or until an Admin
manually unlocks it.

---

## 3. Authorization (Role-Based Access Control)

### 3.1 Roles

| Role | ID | Description |
|------|----|-------------|
| Administrator | 1 | Full system access |
| Cashier | 2 | Limited POS operations |

Roles are encoded in the JWT payload as a `role` claim during login.

### 3.2 RBAC Enforcement

Authorization is enforced at two levels:

#### 3.2.1 Backend — Dependency-Based

```python
def require_admin(user: User = Depends(get_current_user)):
    if user.role != "admin":
        raise HTTPException(status_code=403, detail="Admin access required")
    return user

def require_cashier(user: User = Depends(get_current_user)):
    if user.role != "cashier":
        raise HTTPException(status_code=403, detail="Cashier access required")
    return user
```

Applied per-route:

```python
@router.post("/products")
async def create_product(current_user=Depends(require_admin)): ...

@router.post("/sales")
async def create_sale(current_user=Depends(require_cashier)): ...
```

#### 3.2.2 Frontend — Role-Aware Navigation

- Sidebar navigation is built dynamically based on the user's role.
- API calls include the JWT; the backend enforces permissions independent of
  the UI.

### 3.3 Permissions Matrix Summary

See [07_User_Roles_and_Permissions](../07_User_Roles_and_Permissions/README.md#5-permissions-matrix)
for the complete matrix.

---

## 4. Password Storage

### 4.1 Hashing Algorithm

- **Primary:** bcrypt with cost factor 12 (default).
- **Alternative:** Argon2id (configurable via environment variable).

### 4.2 Storage

- Passwords are hashed **before** insertion into the `users` table.
- The `users` table stores only the **hash** in the `password_hash` column —
  **never** plaintext.

### 4.3 Complexity Requirements

| Requirement | Rule |
|-------------|------|
| Minimum length | 8 characters |
| Uppercase | ≥ 1 |
| Lowercase | ≥ 1 |
| Digit | ≥ 1 |
| Special character | ≥ 1 |

### 4.4 Password Hashing Code Example

```python
# utils/hashing.py
import bcrypt

def hash_password(password: str) -> str:
    salt = bcrypt.gensalt(rounds=12)
    return bcrypt.hashpw(password.encode(), salt).decode()

def verify_password(plain: str, hashed: str) -> bool:
    return bcrypt.checkpw(plain.encode(), hashed.encode())
```

---

## 5. Audit Trail

### 5.1 Audit Log Structure

| Column | Type | Description |
|--------|------|-------------|
| `log_id` | int (PK) | Auto-increment primary key |
| `user_id` | int (FK) | Who performed the action (nullable for system) |
| `action_type` | string(50) | `LOGIN`, `LOGOUT`, `SALE_CREATED`, `PRODUCT_UPDATED`, etc. |
| `resource_type` | string(50) | `user`, `product`, `sale`, `return`, `setting`, etc. |
| `resource_id` | string | ID of the affected resource |
| `details` | JSON | Additional context (e.g., `{"old_price": 100, "new_price": 120}`) |
| `ip_address` | string | IP address of the requesting client |
| `timestamp` | datetime | UTC timestamp |

### 5.2 What Gets Logged

| Action | Logged? |
|--------|---------|
| Login (success + failure) | Yes |
| Logout | Yes |
| Create user | Yes |
| Deactivate user | Yes |
| Reset password | Yes |
| Change password | Yes |
| Create product | Yes |
| Update product | Yes |
| Delete product | Yes |
| Create sale | Yes |
| Void sale | Yes |
| Process return | Yes |
| Restock | Yes |
| Update settings | Yes |
| Generate report | Optional (configurable) |

### 5.3 Immutability

- Audit logs can **only be inserted** — no `UPDATE` or `DELETE` allowed.
- A database trigger (`TRG_audit_logs_no_delete`) enforces this constraint.

> **Related:** [BR-AUD-01](../10_Business_Rules/README.md#br-aud-01-every-important-action-is-auditable),
> [BR-AUD-02](../10_Business_Rules/README.md#br-aud-02-audit-logs-are-immutable)

---

## 6. Notifications

### 6.1 Types

| Type | Audience | Trigger |
|------|----------|---------|
| Low Stock | Admin | BR-INV-06: Stock drops to or below threshold |
| Sale Completed | Admin | Sale created |
| Return Processed | Admin | Return processed |
| Credit Sale | Admin | Credit sale created |
| System | Admin | Config change, maintenance events |

### 6.2 Delivery

In Phase 1, notifications are delivered **in-app only** via the `notifications`
table. A frontend polling mechanism (via TanStack Query) checks for new
notifications every 60 seconds. WebSocket-based real-time delivery is planned
for Phase 2.

### 6.3 Notification Deduplication

Per [BR-NOT-03](../10_Business_Rules/README.md), if a product is already
below its threshold and another movement makes it still below, **no new
notification** is created. A new one is generated only after stock goes above
threshold and then drops again.

---

## 7. Environment & Secret Management

### 7.1 Environment Variables

All secrets and configuration values are read from environment variables.
See [15_Backend_Architecture — §9](../15_Backend_Architecture/README.md#9-configuration).

### 7.2 No Hardcoded Secrets

| Item | Policy |
|------|--------|
| JWT secret | From `JWT_SECRET_KEY` env var |
| Database connection | From `DATABASE_URL` env var |
| API URLs (frontend) | From `VITE_API_BASE_URL` env var |
| Encryption key | From `ENCRYPTION_KEY` env var |

No secrets are stored in source control. A `.env.example` file is provided with
clear placeholders.

---

## 8. Injection Attack Prevention

### 8.1 SQL Injection

- All database access is via **SQLAlchemy ORM** — raw SQL is avoided.
- When stored procedures are used, parameters are passed via SQLAlchemy's
  `text()` with bound parameters.
- Database constraints and check constraints prevent impossible states
  regardless of application-layer validation.

### 8.2 Command Injection

- No user input is passed to shell commands or subprocesses.
- File paths from users are validated against a whitelist of allowed characters.

---

## 9. XSS Prevention

- React's built-in HTML escaping is used for all rendered content.
- User-supplied HTML is sanitized before rendering (DOMPurify if needed).
- Content-Security-Policy (CSP) header is set:
  `default-src 'self'; script-src 'self'`.
- No use of `dangerouslySetInnerHTML` except for strictly sanitized content.

---

## 10. CSRF Prevention

For Phase 1 (stateless JWT in `Authorization` header), CSRF is mitigated by:

1. Tokens are sent via Bearer header (not cookies).
2. CORS is restricted to the trusted frontend origin.
3. SameSite cookie attribute is set to `Strict` (if refresh tokens use
   cookies).

In Phase 2, if cookie-based sessions are introduced, CSRF tokens will be
implemented.

---

## 11. Transport Security

### 11.1 HTTPS

- All API communication must use HTTPS in production (TLS 1.2+).
- Frontend served over HTTPS; API base URL is `https://`.

### 11.2 HTTP Strict Transport Security (HSTS)

```
Strict-Transport-Security: max-age=31536000; includeSubDomains
```

### 11.3 Security Headers

| Header | Value |
|--------|-------|
| `X-Content-Type-Options` | `nosniff` |
| `X-Frame-Options` | `DENY` |
| `X-XSS-Protection` | `0` (deprecated; rely on CSP) |
| `Content-Security-Policy` | `default-src 'self'; script-src 'self'` |
| `Strict-Transport-Security` | `max-age=31536000; includeSubDomains` |

---

## 12. Session Management

| Aspect | Implementation |
|--------|----------------|
| Session storage | Stateless JWT tokens in browser local storage / HttpOnly cookie |
| Idle timeout | Access token expires after 15 minutes; auto-refresh attempts silent |
| Absolute timeout | Refresh token expires after 7 days |
| Re-authentication | Required after refresh token expires |
| Session invalidation | Logout revokes refresh token in database |

---

## 13. Input Validation (Security Layer)

- **Frontend:** Zod schemas reject invalid input before API call.
- **Backend:** Pydantic models validate all input.
- **Database:** Check constraints and foreign keys enforce integrity.
- **Rate limiting:** Prevents brute-force and DoS.

---

## 14. Dependency Security

- Python packages audited via `pip-audit` in CI.
- npm packages audited via `npm audit` in CI.
- Known vulnerable versions blocked by package lock files.
- Regular dependency updates via Dependabot / Renovate (Phase 2).

---

## 15. Security Testing

| Test Type | Tools | Frequency |
|-----------|-------|-----------|
| Static analysis (SAST) | Bandit (Python), ESLint security plugin | Every commit (CI) |
| Dependency scanning | pip-audit, npm audit | Every commit (CI) |
| Penetration testing | OWASP ZAP, Burp Suite | Quarterly |
| Vulnerability scanning | Trivy (Docker images) | Before release |

> **Related:** [19_Testing_Strategy — §9 (Security Testing)](../19_Testing_Strategy/README.md#9-security-testing)

---

## 16. Incident Response

| Scenario | Response |
|----------|----------|
| Unauthorized access detected | Audit log entry reviewed; affected user notified; password reset enforced |
| SQL injection attempt | Logged; IP blocked temporarily; security team notified |
| Token theft suspected | Token revoked; user forced to re-authenticate |
| Data breach | Incident response plan activated; forensic analysis; notifications as required |

---

## 17. Related Documents

- [12_System_Architecture](../12_System_Architecture/README.md)
- [15_Backend_Architecture](../15_Backend_Architecture/README.md)
- [05_Functional_Requirements — Authentication](../05_Functional_Requirements/README.md)
- [07_User_Roles_and_Permissions](../07_User_Roles_and_Permissions/README.md)
- [10_Business_Rules](../10_Business_Rules/README.md)
- [13_Database_Overview](../13_Database_Overview/README.md)
- [06_Non_Functional_Requirements — §8 (Security)](../06_Non_Functional_Requirements/README.md#8-security)
- [SMARTPOS_PROJECT_BIBLE.md](..//../AI/SMARTPOS_PROJECT_BIBLE.md#security-requirements)

---

## 18. Revision History

| Version | Date | Author | Description |
|---------|------|--------|-------------|
| 1.0 | 2026-08-07 | SmartPOS Documentation Team | Initial release |
