# SmartPOS — Project Overview

**Document ID:** DOC-OVVW-002  
**Version:** 1.0  
**Status:** Approved  
**Author:** SmartPOS Documentation Team  
**Date:** August 7, 2026  

---

## 1. Purpose

This document provides a comprehensive overview of the **SmartPOS Enterprise
Point of Sale & Inventory Management System**. It describes the problem being
solved, the target users, expected benefits, feature inventory, system
modules, architecture overview, and the technology stack. This is the single
entry point for any stakeholder seeking to understand *what* SmartPOS is and
*why* it exists, before diving into detailed requirements, architecture, or
design documents.

For project-level governance details, see
[01_Project_Charter](../01_Project_Charter/README.md).

---

## 2. Problem Statement

Modern small-to-medium enterprises rely on manual spreadsheets, handwritten
receipts, or basic POS software that lacks:

1. **Real-time inventory synchronization** — leading to stock-outs and
   over-ordering.
2. **Secure, auditable transaction records** — leading to revenue leakage and
   accountability gaps.
3. **Role-based access control** — leading to unauthorized changes by staff.
4. **Automated reporting** — leading to poor operational decisions.
5. **Production-grade deployment** — leading to unreliable, non-recoverable
   systems after failures.

Without a unified system, businesses suffer from:
- Revenue leakage due to untracked returns and credit sales.
- Operational inefficiency from manual reordering and reconciliation.
- Security vulnerabilities from poor password and session management.
- Inability to scale — adding users or registers requires significant rework.

SmartPOS solves these issues by providing a single, secure, fully-integrated
application covering sales, inventory, user management, reporting, and
notifications — built on enterprise-grade principles from the ground up.

---

## 3. Target Users

| Role | Description | Primary Goals |
|------|-------------|---------------|
| **Administrator** | System owner or manager with full access | Configure products, manage users, view all reports, adjust settings |
| **Cashier** | Front-line staff processing sales | Fast, accurate, minimal-click sales; view own sales history |
| **Business Owner** | Decision-maker reviewing performance | Access dashboards, sales trends, inventory health |
| **IT / DevOps** | Deployment and maintenance personnel | Reliable deployment, backups, troubleshooting |

---

## 4. Expected Benefits

| Benefit | Description |
|---------|-------------|
| **Operational Efficiency** | Automated stock adjustments, integrated sales, and reporting reduce manual work. |
| **Revenue Protection** | Full audit trail of every sale, return, and inventory movement prevents loss. |
| **Data Integrity** | Normalized database with constraints, triggers, and stored procedures ensures consistency. |
| **Security** | Bcrypt/Argon2 password hashing, JWT auth, RBAC, and audit logging protect data. |
| **Scalability** | Clean Architecture and tiered design allow horizontal and feature growth. |
| **Rapid Deployment** | Setup scripts and `.env` templates allow a production-ready install in minutes. |
| **Error Reduction** | Input validation at API and UI layers, plus database constraints, prevent bad data. |
| **Decision Support** | Dashboards and reports give real-time visibility into business health. |

---

## 5. Features List

| # | Feature | Description |
|---|---------|-------------|
| 1 | Product Management | Create, read, update, delete products with pricing, SKU, and stock levels |
| 2 | Category Management | Organize products into hierarchical categories |
| 3 | Supplier Management | Track supplier contact details and purchase history |
| 4 | Inventory Management | Monitor stock levels, low-stock alerts, and movement history |
| 5 | Sales Processing | Fast keyboard-driven sales workflow with cart, payment, and receipt |
| 6 | Return Processing | Reverse sales, restore inventory, and issue refunds |
| 7 | Credit Sales | Sell on credit to customers; track outstanding balances and settlements |
| 8 | User Management | Admin creates/deactivates users; cashiers change own password |
| 9 | Stock Movement Tracking | Every inventory change logged with timestamp, actor, and reason |
| 10 | Reporting | Sales, inventory, and user activity reports with filters |
| 11 | Dashboards | Role-specific dashboards with KPIs and charts |
| 12 | Notifications | Real-time in-app notifications for low stock, sales, returns |
| 13 | Business Settings | Centralized key-value configuration store |
| 14 | Authentication | JWT-based login with refresh-token flow |
| 15 | Audit Trail | Immutable record of every significant system action |
| 16 | Environment Configuration | All secrets and configs via `.env` files |

---

## 6. Modules

SmartPOS is composed of the following logical modules, each mapping to a
feature in the feature list and to backend routers / frontend pages:

### Core Modules

| Module | Description | Key Backend Router |
|--------|-------------|--------------------|
| **Authentication** | Login, token issuance, refresh, logout | `auth` |
| **Users** | Create, deactivate, search users (Admin) | `users` |
| **Products** | Full product CRUD with pricing and SKUs | `products` |
| **Categories** | Hierarchical category management | `categories` |
| **Suppliers** | Supplier CRUD and supplier-product relations | `suppliers` |
| **Inventory** | Stock levels, movement tracking, restock | `inventory` |
| **Sales** | POS sales creation, transaction records | `sales` |
| **Returns** | Return processing, inventory restoration | `returns` |
| **Credit Sales** | Customer balances and settlements | `credit_sales` |
| **Reports** | Sales, inventory, and audit reports | `reports` |
| **Dashboards** | KPI summaries and charts | `dashboards` |
| **Notifications** | In-app notifications | `notifications` |
| **Settings** | Business configuration | `settings` |
| **Audit Log** | Immutable action logging | (middleware) |

---

## 7. Architecture Overview

SmartPOS follows **Clean Architecture** with three primary tiers:

```
┌─────────────────────────────────────────────────────────┐
│                    Presentation Layer                     │
│          (React SPA — Vite + TypeScript)                │
├─────────────────────────────────────────────────────────┤
│                    Application Layer                     │
│   (FastAPI REST API — routers, services, repositories)  │
├─────────────────────────────────────────────────────────┤
│                     Data Layer                           │
│   (Microsoft SQL Server — tables, SPs, views, triggers) │
└─────────────────────────────────────────────────────────┘
```

### Layer Responsibilities

| Layer | Responsibilities | Technologies |
|-------|------------------|--------------|
| **Frontend (Presentation)** | UI rendering, routing, state management, form handling, API client | React, Vite, TypeScript, Tailwind CSS, React Router, TanStack Query, Axios, React Hook Form, Zod |
| **Backend (API)** | Request handling, validation, authorization, business logic, data persistence | Python, FastAPI, SQLAlchemy, Alembic, Pydantic, JWT, bcrypt/Argon2 |
| **Database (Data)** | Data storage, integrity, performance, reporting | Microsoft SQL Server, stored procedures, views, functions, triggers |

### Communication Flow

1. The **frontend** SPA makes authenticated HTTPS requests via Axios to the
   **backend** API.
2. The **backend** validates, authorizes, executes business logic, and persists
   data through SQLAlchemy ORM to **SQL Server**.
3. **SQL Server** enforces constraints via foreign keys, checks, triggers,
   and stored procedures.
4. Notifications are pushed to the frontend via polling or WebSocket (Phase 2),
   with current Phase 1 supporting REST polling.

For detailed architecture, see:
- [12_System_Architecture](../12_System_Architecture/README.md)
- [15_Backend_Architecture](../15_Backend_Architecture/README.md)
- [16_Frontend_Architecture](../16_Frontend_Architecture/README.md)

---

## 8. Technology Stack

### Frontend

| Technology | Version Constraint | Purpose |
|------------|--------------------|---------|
| React | 18+ | UI library |
| Vite | 5+ | Build tool & dev server |
| TypeScript | 5+ | Type safety |
| Tailwind CSS | 3+ | Styling |
| React Router | 6+ | Client-side routing |
| TanStack Query | 5+ | Server state management |
| Axios | 1.x | HTTP client |
| React Hook Form | 7+ | Form management |
| Zod | 3+ | Schema validation |
| Lucide React | 0.4+ | Icon library |
| ESLint | 9+ | Linting |
| Prettier | 3+ | Code formatting |

### Backend

| Technology | Version Constraint | Purpose |
|------------|--------------------|---------|
| Python | 3.11+ | Language |
| FastAPI | 0.110+ | Web framework |
| SQLAlchemy | 2.0+ | ORM |
| Alembic | 1.13+ | Migrations |
| Pydantic | 2.7+ | Data validation |
| PyJWT | 2.8+ | JWT handling |
| bcrypt / Argon2 | latest | Password hashing |
| python-docx / openpyxl | latest | Report export |
| Swagger / OpenAPI | built-in | API documentation |

### Database

| Technology | Version Constraint | Purpose |
|------------|--------------------|---------|
| Microsoft SQL Server | 2019+ | Primary data store |
| Normalized schema | 3NF | Data integrity |
| Stored procedures | T-SQL | Business logic at DB layer |
| Views | T-SQL | Reporting convenience |
| Functions | T-SQL | Computed values |
| Triggers | T-SQL | Audit and integrity enforcement |

### DevOps & Tooling

| Tool | Purpose |
|------|---------|
| Git | Version control |
| Docker | Containerization (deployment) |
| PowerShell / Batch | Setup scripts on Windows |
| pytest | Backend testing |
| Vitest | Frontend testing |
| Playwright | End-to-end testing |
| Swagger UI | API documentation UI |

---

## 9. Deployment Model

SmartPOS is designed for **local/network deployment**:

- **Frontend**: Static files served via Vite dev server (development) or built
  static bundle served by any HTTP server (production).
- **Backend**: FastAPI application, served via Uvicorn/Gunicorn (development) or
  behind a reverse proxy (production).
- **Database**: Microsoft SQL Server instance (local or networked).

See [20_Deployment_Strategy](../20_Deployment_Strategy/README.md) for full
details.

---

## 10. Key Design Principles

1. **Clean Architecture** — separation of concerns, dependency inversion.
2. **SOLID** — maintainable, testable code.
3. **Defense in Depth** — validation at UI, API, and DB layers.
4. **No Hardcoded Secrets** — all configuration via environment variables.
5. **Production-Ready** — fully implemented, no placeholders or TODOs.
6. **Auditable** — every significant action is logged.
7. **Responsive & Accessible** — modern, keyboard-friendly UI.

---

## 11. References

- [01_Project_Charter](../01_Project_Charter/README.md)
- [03_Software_Requirements_Specification](../03_Software_Requirements_Specification/README.md)
- [12_System_Architecture](../12_System_Architecture/README.md)
- [SMARTPOS_PROJECT_BIBLE.md](../AI/SMARTPOS_PROJECT_BIBLE.md)

---

## 12. Revision History

| Version | Date | Author | Description |
|---------|------|--------|-------------|
| 1.0 | 2026-08-07 | SmartPOS Documentation Team | Initial release |
