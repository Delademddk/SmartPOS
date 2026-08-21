# SmartPOS — Project Charter

**Document ID:** DOC-PJCT-001  
**Version:** 1.0  
**Status:** Approved  
**Author:** SmartPOS Documentation Team  
**Date:** August 7, 2026  

---

## 1. Purpose

This Project Charter establishes the foundation, scope, objectives, stakeholders,
and success criteria for the **SmartPOS Enterprise Point of Sale (POS) &
Inventory Management System**. It is the authoritative high-level agreement
between the business and engineering stakeholders and serves as the entry point
into the full documentation package. This document is referenced by every
subsequent specification, design, and test document.

All detailed technical, functional, and operational requirements are defined in
later documents:
- [03_Software_Requirements_Specification](../03_Software_Requirements_Specification/README.md)
- [05_Functional_Requirements](../05_Functional_Requirements/README.md)
- [10_Business_Rules](../10_Business_Rules/README.md)

---

## 2. Project Vision

Develop a modern, scalable, secure, enterprise-grade Point of Sale (POS) and
Inventory Management System suitable for deployment in real businesses. The
system must be **production-ready** — not a tutorial, demo, or school assignment.
After environment configuration (database credentials and secrets), the
application must build and run without requiring manual restructuring or
missing-file fixes.

---

## 3. Project Objectives

| # | Objective | Key Result |
|---|-----------|------------|
| 1 | Implement a complete POS sales module | Cashiers can create, complete, and return sales with full transaction records |
| 2 | Implement end-to-end inventory management | Stock levels adjust automatically on sales, returns, and restocks |
| 3 | Provide enterprise-grade security | All passwords hashed, JWT authentication, RBAC, audit logging |
| 4 | Support two distinct user roles | Administrator and Cashier with strictly enforced permissions |
| 5 | Deliver comprehensive reporting | Sales, inventory, and user-activity reports exportable |
| 6 | Enable automated notifications | Low-stock, sale, and system-event notifications |
| 7 | Ensure production-ready deployment | Full deployment, backup, restore, and troubleshooting guides |

---

## 4. Business Goals

| Goal | Description |
|------|-------------|
| **Increase operational efficiency** | Reduce manual inventory reconciliation and sales recording time |
| **Reduce human error** | Eliminate arithmetic and stock-count errors through automated logic |
| **Improve decision-making** | Provide real-time dashboards and reports for business owners |
| **Ensure regulatory compliance** | Maintain audit trails and protect customer/financial data |
| **Enable scalability** | Support multi-store or multi-user growth without architectural redesign |
| **Lower total cost of ownership** | Open-source stack, automated setup scripts, containerized deployment |

---

## 5. Scope Definition

### In-Scope

- **Product management** — CRUD for products, categories, and suppliers
- **Inventory management** — real-time stock levels, stock movement tracking,
  low-stock alerts
- **Sales processing** — create sales, partial payments, credit sales, returns
- **Credit sales** — customer balance tracking and settlement
- **User management** — create, deactivate, and reset passwords (Admin only)
- **Dashboard & reporting** — role-aware dashboards, sales/inventory reports
- **Notifications** — system notifications for low stock, sales, returns
- **Business settings** — application-level configuration store
- **Audit logging** — immutable record of every significant action
- **Authentication & authorization** — JWT, role-based access control
- **Database layer** — fully normalized SQL Server schema, stored procedures,
  views, triggers, functions, seed/sample data
- **API layer** — RESTful, validated, paginated, versioned, Swagger-documented
- **Frontend** — responsive React/TS/Vite UI with reusable components
- **Infrastructure** — setup scripts, deployment, backup, and restore guides
- **Testing** — unit, integration, API, component, regression, performance, and
  security testing documentation and scripts

### Out-of-Scope

- Mobile application (iOS/Android native apps)
- E-commerce / online storefront
- Payment gateway integration (cash/card entry assumed)
- Multi-currency or multi-language (beyond English baseline)
- Third-party marketplace integrations (e.g., Shopify, Amazon)
- Point-of-sale hardware SDK integration (barcode scanner, receipt printer
  drivers) — assumed generic HID/keyboard-wedge input
- Cloud hosting provider lock-in (deployment is provider-agnostic)

---

## 6. Success Criteria

| Criterion | Target |
|-----------|--------|
| All CRUD endpoints return correct responses under 200 ms p95 | Performance |
| 100% of API endpoints return 401/403 for unauthorized access | Security |
| All passwords stored as bcrypt/Argon2 hashes — no plaintext anywhere | Security |
| Every sale decrements inventory; every return restores it | Business Logic |
| Every stock movement is logged with timestamp, user, and quantity | Audit |
| No SQL injection, XSS, or CSRF vulnerabilities pass automated scan | Security |
| Setup scripts allow a fresh install from `.env` config alone | Deployment |
| Test coverage ≥ 80% for backend business logic | Quality |
| UI renders correctly on screens from 320 px to 1920 px width | Responsiveness |

---

## 7. Stakeholders

| Role | Responsibilities | Expectations |
|------|------------------|--------------|
| **Project Sponsor** | Business vision, budget approval | ROI, timely delivery |
| **Business Owner** | Daily operations oversight | Accurate reports, low stock alerts |
| **Administrator** | Full system configuration & management | All features available, audit trails |
| **Cashier** | Daily POS operations | Fast, minimal-click sales workflow |
| **IT / DevOps** | Infrastructure, deployment, backups | Clear setup guides, reliable deployment |
| **QA Engineer** | Testing strategy & validation | Defined test plans, reproducible bugs |
| **Product Manager** | Feature prioritization & backlog | Clear user stories, traceability |
| **Security Officer** | Security compliance | No vulnerabilities, proper authz |
| **End Users** | Cashiers and Business Owners using the system | Intuitive, fast, error-resistant |

---

## 8. Risks

| ID | Risk | Likelihood | Impact | Mitigation |
|----|------|-----------|--------|------------|
| R-01 | SQL Server incompatibility across versions | Medium | High | Pin to supported version, document prerequisites |
| R-02 | Slow sales workflow reduces cashier productivity | High | High | Keyboard-first UI design, hotkey support |
| R-03 | Data loss from incomplete backup strategy | Medium | Critical | Scheduled backups, documented restore procedures |
| R-04 | JWT token theft leads to unauthorized access | Medium | High | Short token TTL, refresh-token rotation, HTTPS-only |
| R-05 | Over-normalized DB causes slow reporting joins | Medium | Medium | Index strategy + reporting views documented |
| R-06 | Environment misconfiguration blocks deployment | High | Medium | `.env.example` templates + setup verification scripts |
| R-07 | Unauthorized data access via weak RBAC | Medium | Critical | Centralized permission checks, automated tests |

---

## 9. Assumptions

1. SQL Server 2019+ is available (or Docker SQL Server image is deployable).
2. End users have a modern browser (Chrome, Firefox, Edge, Safari latest - 2).
3. Network is trusted internally but all API traffic should still use HTTPS in
   production.
4. Point-of-sale hardware (if any) acts as a keyboard wedge or standard HID
   device.
5. Business owners have basic computing literacy to read reports and dashboards.
6. The two defined roles (Administrator, Cashier) are sufficient for the initial
   scope; role granularity can expand later.
7. Internet access is available for initial dependency installation.
8. All configurable values can be supplied via environment variables.

---

## 10. Constraints

1. **Technology stack is fixed** — see [Technology Stack](..//../02_Project_Overview/README.md#technology-stack)
   in the Project Overview.
2. **Database must be Microsoft SQL Server** — no alternative databases allowed.
3. **No hardcoded secrets** — all secrets must come from environment variables.
4. **No placeholder or incomplete business logic** — every module must be fully
   functional.
5. **Frontend uses TypeScript exclusively** — no plain JavaScript files.
6. **Backend uses Python with FastAPI** — no alternative frameworks.
7. **Clean Architecture and SOLID principles** must be followed.
8. **No generated code may use TODO, placeholder, dummy, or "coming soon"
   markers.**

---

## 11. References

- [02_Project_Overview](../02_Project_Overview/README.md) — Full project overview
- [03_Software_Requirements_Specification](../03_Software_Requirements_Specification/README.md)
- [05_Functional_Requirements](../05_Functional_Requirements/README.md)
- [06_Non_Functional_Requirements](../06_Non_Functional_Requirements/README.md)
- [10_Business_Rules](../10_Business_Rules/README.md)
- [SMARTPOS_PROJECT_BIBLE.md](../AI/SMARTPOS_PROJECT_BIBLE.md) — Master specification

---

## 12. Revision History

| Version | Date | Author | Description |
|---------|------|--------|-------------|
| 1.0 | 2026-08-07 | SmartPOS Documentation Team | Initial release |
