# SmartPOS — Non-Functional Requirements

**Document ID:** DOC-NFR-006  
**Version:** 1.0  
**Status:** Approved  
**Author:** SmartPOS Documentation Team  
**Date:** August 7, 2026  

---

## 1. Purpose

This document specifies all **non-functional requirements** (NFRs) for the
SmartPOS Enterprise POS & Inventory Management System. These are the quality
attributes, constraints, and standards that the system must satisfy in
addition to the functional requirements defined in
[05_Functional_Requirements](../05_Functional_Requirements/README.md).

---

## 2. Performance

| Requirement ID | Requirement |
|----------------|-------------|
| NFR-PERF-01 | API endpoints must respond with p95 ≤ 200 ms under normal load (≤ 100 concurrent users). |
| NFR-PERF-02 | Frontend page load time must be ≤ 2 seconds for initial render on a 3G-equivalent connection. |
| NFR-PERF-03 | Sales cart must render product search results in ≤ 500 ms. |
| NFR-PERF-04 | Database queries used in dashboards must execute in ≤ 100 ms with proper indexing. |
| NFR-PERF-05 | Report generation for date ranges ≤ 30 days must complete in ≤ 5 seconds. |
| NFR-PERF-06 | JWT token validation must complete in ≤ 5 ms per request. |

**Measurement method:** Automated load testing using Locust or k6 with results
captured in [19_Testing_Strategy](../19_Testing_Strategy/README.md#performance-testing).

---

## 3. Availability

| Requirement ID | Requirement |
|----------------|-------------|
| NFR-AVAIL-01 | System uptime must be ≥ 99.5% measured monthly. |
| NFR-AVAIL-02 | Maintenance windows must be scheduled outside business hours (configurable by region). |
| NFR-AVAIL-03 | Database failover must restore service within ≤ 5 minutes. |
| NFR-AVAIL-04 | Backend service auto-restarts on crash (Docker/Kubernetes health check). |
| NFR-AVAIL-05 | Health check endpoint (`/health`) must respond within ≤ 1 second. |

> **Related:** [20_Deployment_Strategy](../20_Deployment_Strategy/README.md)

---

## 4. Maintainability

| Requirement ID | Requirement |
|----------------|-------------|
| NFR-MTN-01 | Codebase must follow Clean Architecture with clear separation of layers. |
| NFR-MTN-02 | Each module's code must be covered by unit tests (≥ 80% coverage). |
| NFR-MTN-03 | All API endpoints must be documented via Swagger/OpenAPI auto-generation. |
| NFR-MTN-04 | Database schema changes must be tracked via Alembic migrations. |
| NFR-MTN-05 | Code must pass ESLint and Prettier checks in CI pipeline. |
| NFR-MTN-06 | No code may contain `TODO`, `FIXME`, `placeholder`, or commented-out blocks. |

**Reference:** [22_Coding_Standards](../22_Coding_Standards/README.md)

---

## 5. Scalability

| Requirement ID | Requirement |
|----------------|-------------|
| NFR-SCAL-01 | Backend must be horizontally scalable (stateless API servers). |
| NFR-SCAL-02 | Database must support read replicas for reporting queries. |
| NFR-SCAL-03 | API must support pagination with max page_size of 100. |
| NFR-SCAL-04 | Session state must be stored in JWT tokens (no server-side session store). |
| NFR-SCAL-05 | System must support up to 50 concurrent cashiers per backend instance. |
| NFR-SCAL-06 | Static frontend assets must be cacheable via CDN. |

> **Related:** [12_System_Architecture](../12_System_Architecture/README.md), [20_Deployment_Strategy](../20_Deployment_Strategy/README.md)

---

## 6. Reliability

| Requirement ID | Requirement |
|----------------|-------------|
| NFR-REL-01 | Database transactions must be ACID-compliant. |
| NFR-REL-02 | Every sale must be atomic — either fully committed or fully rolled back. |
| NFR-REL-03 | Stock movements and transaction records must be committed in a single transaction. |
| NFR-REL-04 | The system must detect and prevent duplicate transaction IDs. |
| NFR-REL-05 | Unhandled exceptions must not cause data corruption — transaction rollback must occur. |

---

## 7. Accessibility

| Requirement ID | Requirement |
|----------------|-------------|
| NFR-ACC-01 | UI must comply with WCAG 2.1 Level AA standards. |
| NFR-ACC-02 | All interactive elements must be keyboard-navigable. |
| NFR-ACC-03 | All images and icons must have appropriate `alt` text or ARIA labels. |
| NFR-ACC-04 | Color must not be the sole means of conveying information. |
| NFR-ACC-05 | Focus indicators must be visible for all interactive elements. |
| NFR-ACC-06 | Form fields must have associated labels. |

> **Related:** [17_UI_UX_Specification](../17_UI_UX_Specification/README.md#accessibility-guidelines)

---

## 8. Security

| Requirement ID | Requirement |
|----------------|-------------|
| NFR-SEC-01 | All passwords must be hashed using bcrypt or Argon2 (never plaintext). |
| NFR-SEC-02 | Authentication must use JWT with access (15 min) and refresh (7 day) token TTL. |
| NFR-SEC-03 | JWT secrets must never be hardcoded — read from environment variables. |
| NFR-SEC-04 | API endpoints must enforce role-based authorization (Admin vs Cashier). |
| NFR-SEC-05 | No SQL injection — all database access via SQLAlchemy ORM (parameterized queries). |
| NFR-SEC-06 | No XSS — React's built-in escaping + Content-Security-Policy header. |
| NFR-SEC-07 | CSRF protection via SameSite cookies or token-based headers. |
| NFR-SEC-08 | Rate limiting on login endpoint (max 5 attempts per 15 minutes per IP). |
| NFR-SEC-09 | All communication must use HTTPS in production. |
| NFR-SEC-10 | Audit logging for all create/update/delete actions. |
| NFR-SEC-11 | Sensitive data must not appear in logs or API responses. |
| NFR-SEC-12 | JWT tokens must be verified on every protected request. |
| NFR-SEC-13 | Refresh token revocation on logout. |
| NFR-SEC-14 | Account lockout after 5 failed login attempts. |

> **Related:** [18_Security_Architecture](../18_Security_Architecture/README.md)

---

## 9. Backup

| Requirement ID | Requirement |
|----------------|-------------|
| NFR-BACKUP-01 | Database backups must run daily at a configurable time (default: 02:00 UTC). |
| NFR-BACKUP-02 | Backups must be stored in a separate location from the primary server. |
| NFR-BACKUP-03 | Backup retention: 30 daily, 12 weekly, 6 monthly full backups. |
| NFR-BACKUP-04 | Backup scripts must verify backup integrity after creation. |
| NFR-BACKUP-05 | Backup and restore procedures must be documented in [20_Deployment_Strategy](../20_Deployment_Strategy/README.md). |

---

## 10. Recovery

| Requirement ID | Requirement |
|----------------|-------------|
| NFR-REC-01 | System must recover from database failure within ≤ 4 hours (RTO). |
| NFR-REC-02 | Maximum data loss tolerance: 24 hours (RPO) for non-critical data, 0 for transactions. |
| NFR-REC-03 | Recovery procedures must be tested quarterly with a simulated failure. |
| NFR-REC-04 | Point-in-time recovery must be possible for transaction logs. |

> **Related:** [20_Deployment_Strategy](../20_Deployment_Strategy/README.md#restore-strategy)

---

## 11. Logging

| Requirement ID | Requirement |
|----------------|-------------|
| NFR-LOG-01 | All API requests must be logged (method, path, status, duration, user_id). |
| NFR-LOG-02 | All authentication events (login success/failure, logout) must be logged. |
| NFR-LOG-03 | All business-critical actions (sale, return, restock, user creation) must be logged. |
| NFR-LOG-04 | Logs must include timestamp (UTC), severity level, and request correlation ID. |
| NFR-LOG-05 | Logs must not contain passwords, full JWT tokens, or PII. |
| NFR-LOG-06 | Log retention: 90 days for operational logs; 2 years for audit logs. |
| NFR-LOG-07 | Logs must be stored in a structured format (JSON) for searchability. |

> **Related:** [13_Database_Overview](../13_Database_Overview/README.md) — Audit Logs table; [18_Security_Architecture](../18_Security_Architecture/README.md#audit-trail)

---

## 12. Monitoring

| Requirement ID | Requirement |
|----------------|-------------|
| NFR-MON-01 | System must expose a `/health` endpoint for uptime monitoring. |
| NFR-MON-02 | API response times must be monitored with p50, p95, p99 metrics. |
| NFR-MON-03 | Database connection pool utilization must be monitored. |
| NFR-MON-04 | Error rates must be tracked (4xx, 5xx responses). |
| NFR-MON-05 | Low-stock conditions must trigger monitoring alerts. |
| NFR-MON-06 | Log aggregation must be available (e.g., ELK stack or similar). |

> **Related:** [19_Testing_Strategy](../19_Testing_Strategy/README.md)

---

## 13. Localization

| Requirement ID | Requirement |
|----------------|-------------|
| NFR-LOC-01 | UI strings must be externalized for future internationalization. |
| NFR-LOC-02 | Number formatting must use locale-aware formatting (configurable). |
| NFR-LOC-03 | Date/time must be displayed in a configurable format (ISO 8601 default). |
| NFR-LOC-04 | Currency must use a configurable symbol (default: `$`). |
| NFR-LOC-05 | All user-facing text must be English in Phase 1; i18n framework must be in place for future expansion. |

---

## 14. Compliance & Regulations

| Requirement ID | Requirement |
|----------------|-------------|
| NFR-COMP-01 | System must maintain a complete audit trail of all user actions. |
| NFR-COMP-02 | Personal data (if any customer info stored) must be protected per applicable data protection laws. |
| NFR-COMP-03 | Access logs must be retained for minimum required period as per local regulations. |

---

## References

- [SMARTPOS_PROJECT_BIBLE.md](../AI/SMARTPOS_PROJECT_BIBLE.md)
- [03_Software_Requirements_Specification](../03_Software_Requirements_Specification/README.md)
- [18_Security_Architecture](../18_Security_Architecture/README.md)
- [20_Deployment_Strategy](../20_Deployment_Strategy/README.md)
- [19_Testing_Strategy](../19_Testing_Strategy/README.md)

---

## Revision History

| Version | Date | Author | Description |
|---------|------|--------|-------------|
| 1.0 | 2026-08-07 | SmartPOS Documentation Team | Initial release |
