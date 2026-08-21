# SmartPOS — System Architecture

**Document ID:** DOC-SA-012  
**Version:** 1.0  
**Status:** Approved  
**Author:** SmartPOS Documentation Team  
**Date:** August 7, 2026  

---

## 1. Purpose

This document describes the **overall system architecture** of SmartPOS. It
specifies the architectural style (Layered / Clean Architecture), the
responsibilities of each layer, the communication mechanisms between layers,
and the interaction between frontend, backend, and database.

---

## 2. Architectural Style

SmartPOS follows **Clean Architecture** (a.k.a. Onion Architecture) with three
primary concentric layers:

```
┌─────────────────────────────────────────────┐
│  PRESENTATION LAYER                          │
│  React SPA (Vite, TypeScript, Tailwind)      │
├─────────────────────────────────────────────┤
│  APPLICATION LAYER                            │
│  FastAPI REST API (Python)                   │
│  - Routers, Services, Repositories           │
├─────────────────────────────────────────────┤
│  DATA LAYER                                   │
│  Microsoft SQL Server                        │
│  - Tables, Views, SPs, Triggers, Functions   │
└─────────────────────────────────────────────┘
```

### 2.1 Core Principles

| Principle | Application in SmartPOS |
|-----------|------------------------|
| **Independence of Frameworks** | Frontend uses React; backend uses FastAPI — neither constrains the other. |
| **Dependency Rule** | Inner layers (Data, Application) have no knowledge of outer layers (Presentation). |
| **Separation of Concerns** | Each layer has a single responsibility. |
| **Testability** | All layers are independently testable. |
| **UI Independent** | Business logic in backend services is independent of frontend frameworks. |
| **DB Independent** | ORM (SQLAlchemy) abstracts database specifics; migrations via Alembic. |
| **External Agency Independent** | Third-party integrations (if any) injected, not hardcoded. |

---

## 3. Layered Architecture Description

### 3.1 Presentation Layer (Frontend)

**Technology:** React, Vite, TypeScript, Tailwind CSS, React Router, TanStack
Query, Axios, React Hook Form, Zod, Lucide React.

**Responsibilities:**
- Render UI components (pages, layouts, reusable components).
- Client-side routing via React Router.
- Form validation via Zod + React Hook Form.
- Server state management via TanStack Query.
- API calls via Axios with JWT authorization header.
- Role-aware navigation (menu items filtered by role).

**Structure (from [Project Bible](AI/SMARTPOS_PROJECT_BIBLE.md):**

```
Frontend/src/
├── assets/        — Images, icons, fonts
├── components/    — Reusable UI components (Button, Input, Card, etc.)
├── pages/         — Route-level page components
├── layouts/       — Layout components (AdminLayout, AuthLayout)
├── hooks/         — Custom React hooks
├── services/      — Business logic hooks (useSales, useProducts)
├── api/           — Axios instance + endpoint functions
├── context/       — React context providers (AuthContext)
├── types/         — TypeScript type definitions
├── utils/         — Utility functions
├── routes/        — Route definitions
└── public/        — Static assets
```

For full details see [16_Frontend_Architecture](../16_Frontend_Architecture/README.md).

### 3.2 Application Layer (Backend API)

**Technology:** Python, FastAPI, SQLAlchemy, Alembic, Pydantic, PyJWT, bcrypt/Argon2.

**Responsibilities:**
- Expose RESTful endpoints.
- Validate input (Pydantic schemas).
- Enforce business logic (services).
- Enforce authorization (RBAC middleware).
- Persist and retrieve data (repositories via SQLAlchemy).
- Generate Swagger/OpenAPI documentation automatically.
- Audit logging of all significant actions.

**Structure (from [Project Bible](AI/SMARTPOS_PROJECT_BIBLE.md)):**

```
Backend/app/
├── api/
│   ├── routers/       — Route definitions (one per module)
│   ├── schemas/       — Pydantic request/response models
│   └── dependencies/  — Shared dependencies (auth, db session)
├── services/          — Business logic layer
├── repositories/      — Data access layer (SQLAlchemy queries)
├── models/            — SQLAlchemy ORM models
├── database/          — Connection, base model, session management
├── middleware/        — Auth, CORS, logging, error handling
├── core/              — Configuration, security, constants
├── utils/             — Helper functions (hashing, token generation)
└── tests/             — Unit, integration, and API tests
```

For full details see [15_Backend_Architecture](../15_Backend_Architecture/README.md).

### 3.3 Data Layer (Database)

**Technology:** Microsoft SQL Server, T-SQL stored procedures, views, functions,
triggers.

**Responsibilities:**
- Store all application data in a fully normalized schema (3NF+).
- Enforce data integrity via foreign keys, check constraints, and uniqueness.
- Encapsulate business logic at the DB layer via stored procedures and triggers.
- Optimize reporting via views.
- Manage schema evolution via Alembic migrations.

For full details see [13_Database_Overview](../13_Database_Overview/README.md).

---

## 4. Clean Architecture Boundary Mapping

```
┌──────────────────────────────────────────────────────────────┐
│  [Presentation]  React SPA                                    │
│  [Use Case]      Axios HTTP requests to API endpoints         │
│  [Interface]     REST/JSON                                    │
├──────────────────────────────────────────────────────────────┤
│  [Presentation]  FastAPI Routers                              │
│  [Use Case]      Application Services                         │
│  [Interface]     HTTP/REST, Pydantic Schemas                  │
├──────────────────────────────────────────────────────────────┤
│  [Use Case]      Repository Interfaces                        │
│  [Interface]     SQLAlchemy ORM, Alembic                      │
│  [Frameworks &  SQL Server driver (pyodbc)                    │
│   Drivers]       Microsoft SQL Server                         │
├──────────────────────────────────────────────────────────────┤
│  [Enterprise]    Database schema, constraints, SPs, triggers │
│  Business Rules                                                │
└──────────────────────────────────────────────────────────────┘
```

---

## 5. Communication Flow

### 5.1 Request Lifecycle (Sales Example)

```
Browser ——(1)——> API (POST /sales)
              ——(2)——> Service Layer (validate, business logic)
              ——(3)——> Repository (SQLAlchemy)
              ——(4)——> SQL Server (transaction)
              ——(5)——> SQL Server (trigger: stock_movement + audit_log)
              ——(6)——> Return: 201 Created + receipt data
              ——(7)——> Browser renders receipt
```

### 5.2 Authentication Flow Summary

```
Browser ——(1)——> API (POST /auth/login)
              ——(2)——> middleware (rate limit)
              ——(3)——> service (validate, bcrypt check)
              ——(4)——> DB (users table)
              ——(5)——> Return JWT access + refresh tokens
              ——(6)——> Browser stores tokens in localStorage
              ——(7)——> All subsequent requests include JWT in Authorization header
              ——(8)——> API middleware decodes JWT, checks role
```

See [Diagrams/authentication-flow.mmd](../Diagrams/authentication-flow.mmd) and
[Diagrams/application-flow.mmd](../Diagrams/application-flow.mmd).

---

## 6. Technology Interaction Matrix

| Component | Communicates With | Protocol | Data Format |
|-----------|-------------------|----------|-------------|
| Browser (React) | Backend API | HTTPS/REST | JSON |
| Backend API | SQL Server | TCP/IP (ODBC/TDS) | Tabular (via SQLAlchemy) |
| Backend API | Swagger UI | Internal | HTML/JSON |
| Backend API | Internal services | In-process | Python objects |
| SQL Server Triggers | SQL Server Tables | Internal | T-SQL |
| SQL Server SPs | SQL Server Tables | Internal | T-SQL |

---

## 7. Diagram References

See the following Mermaid diagrams for visual representations:

- [system-architecture.mmd](../Diagrams/system-architecture.mmd) — Overall
  layered architecture
- [application-flow.mmd](../Diagrams/application-flow.mmd) — Communication
  between frontend, backend, and database
- [deployment-architecture.mmd](../Diagrams/deployment-architecture.mmd) —
  Deployment topology
- [folder-structure.mmd](../Diagrams/folder-structure.mmd) — Project folder
  tree

---

## 8. Related Documents

- [13_Database_Overview](../13_Database_Overview/README.md)
- [14_API_Architecture](../14_API_Architecture/README.md)
- [15_Backend_Architecture](../15_Backend_Architecture/README.md)
- [16_Frontend_Architecture](../16_Frontend_Architecture/README.md)
- [21_Project_Structure](../21_Project_Structure/README.md)

---

## 9. Revision History

| Version | Date | Author | Description |
|---------|------|--------|-------------|
| 1.0 | 2026-08-07 | SmartPOS Documentation Team | Initial release |
