# SmartPOS — Project Structure

**Document ID:** DOC-STR-021  
**Version** 1.0  
**Status:** Approved  
**Author:** SmartPOS Documentation Team  
**Date:** August 7, 2026  

---

## 1. Purpose

This document documents the **complete project structure** for SmartPOS as
defined in the [Project Bible](../AI/SMARTPOS_PROJECT_BIBLE.md#project-structure).
It explains the purpose of every major directory and file.

---

## 2. Root-Level Structure

```
SmartPOS/
├── Documentation/
├── Database/
├── Backend/
├── Frontend/
├── Testing/
├── Deployment/
├── Scripts/
├── Assets/
├── AI/
├── README.md
├── LICENSE
├── CHANGELOG.md
└── .gitignore
```

### Directory Descriptions

| Item | Purpose |
|------|---------|
| `Documentation/` | This documentation package — all specs, architecture, and diagrams |
| `Database/` | SQL Server schema, migrations, seed/sample data, backup/restore scripts |
| `Backend/` | FastAPI Python application — routers, services, repositories, models, tests |
| `Frontend/` | React/TypeScript/Vite frontend application |
| `Testing/` | End-to-end and automated test suites (Playwright, etc.) |
| `Deployment/` | Docker configs, CI/CD workflows, production deployment manifests |
| `Scripts/` | Setup scripts (`setup_database.bat`, `setup_frontend.bat`, `start_project.bat`) |
| `Assets/` | Project-wide assets (logo, brand assets, documentation images) |
| `AI/` | AI-generated specifications and the Project Bible |
| `README.md` | Root README — project entry point |
| `LICENSE` | Project license file |
| `CHANGELOG.md` | Version history |
| `.gitignore` | Git ignore rules |

---

## 3. Documentation Folder Structure

```
Documentation/
├── README.md                                  # This directory's README
├── 01_Project_Charter/README.md
├── 02_Project_Overview/README.md
├── 03_Software_Requirements_Specification/README.md
├── 04_Business_Requirements/README.md
├── 05_Functional_Requirements/README.md
├── 06_Non_Functional_Requirements/README.md
├── 07_User_Roles_and_Permissions/README.md
├── 08_User_Stories/README.md
├── 09_Use_Cases/README.md
├── 10_Business_Rules/README.md
├── 11_System_Workflows/README.md
├── 12_System_Architecture/README.md
├── 13_Database_Overview/README.md
├── 14_API_Architecture/README.md
├── 15_Backend_Architecture/README.md
├── 16_Frontend_Architecture/README.md
├── 17_UI_UX_Specification/README.md
├── 18_Security_Architecture/README.md
├── 19_Testing_Strategy/README.md
├── 20_Deployment_Strategy/README.md
├── 21_Project_Structure/README.md              # This file
├── 22_Coding_Standards/README.md
├── 23_Glossary/README.md
├── 24_Appendices/README.md
├── Master_Documentation/README.md
├── Diagrams/
│   ├── system-architecture.mmd
│   ├── application-flow.mmd
│   ├── authentication-flow.mmd
│   ├── sales-flow.mmd
│   ├── inventory-flow.mmd
│   ├── user-management-flow.mmd
│   ├── database-erd.mmd
│   ├── deployment-architecture.mmd
│   ├── folder-structure.mmd
│   └── navigation-flow.mmd
└── Wireframes/
    ├── README.md
    ├── admin-dashboard.md
    ├── cashier-dashboard.md
    ├── login.md
    ├── products.md
    ├── categories.md
    ├── suppliers.md
    ├── inventory.md
    ├── sales.md
    ├── returns.md
    ├── reports.md
    ├── users.md
    ├── settings.md
    └── notifications.md
```

### Documentation Numbering

| Number | Topic | Purpose |
|--------|-------|---------|
| 01 | Project Charter | Scope, objectives, stakeholders, risks |
| 02 | Project Overview | Overview, features, tech stack |
| 03 | SRS | IEEE-style full requirements spec |
| 04 | Business Requirements | Business goals & processes |
| 05 | Functional Requirements | Per-module functional specs |
| 06 | Non-Functional Requirements | Performance, security, etc. |
| 07 | User Roles & Permissions | RBAC matrix |
| 08 | User Stories | Agile user stories |
| 09 | Use Cases | Detailed use case specs |
| 10 | Business Rules | Domain business rules |
| 11 | System Workflows | Step-by-step process flows |
| 12 | System Architecture | Layered / clean architecture |
| 13 | Database Overview | Schema, tables, ER diagram |
| 14 | API Architecture | REST conventions, auth, endpoints |
| 15 | Backend Architecture | Folder structure, layers, services |
| 16 | Frontend Architecture | Folder structure, routing, state |
| 17 | UI/UX Specification | Per-screen design specs |
| 18 | Security Architecture | Auth, authz, audit, vulnerabilities |
| 19 | Testing Strategy | Test plan, tools, coverage |
| 20 | Deployment Strategy | Environments, backup, releases |
| 21 | Project Structure | This document |
| 22 | Coding Standards | Naming, formatting, principles |
| 23 | Glossary | Terms, abbreviations, definitions |
| 24 | Appendices | Future enhancements, references |
| Master | Master Documentation | Cross-document traceability |

---

## 4. Database Folder Structure

```
Database/
├── Documentation/
├── ERD/
├── Diagrams/
├── SQL/
│   ├── Tables/
│   ├── Constraints/
│   ├── Indexes/
│   ├── Views/
│   ├── StoredProcedures/
│   ├── Functions/
│   ├── Triggers/
│   ├── SeedData/
│   └── SampleData/
├── Migrations/
├── Backup/
├── Scripts/
└── Testing/
        └── README.md
```

| Subdirectory | Purpose |
|--------------|---------|
| `Documentation/` | Data dictionary, schema documentation |
| `ERD/` | Entity-relationship diagrams |
| `Diagrams/` | Additional diagram files |
| `SQL/Tables/` | DDL for all tables |
| `SQL/Constraints/` | Foreign keys, checks, unique constraints |
| `SQL/Indexes/` | Index definitions |
| `SQL/Views/` | Reporting views |
| `SQL/StoredProcedures/` | Business-logic stored procedures |
| `SQL/Functions/` | SQL scalar/table functions |
| `SQL/Triggers/` | Audit and integrity triggers |
| `SQL/SeedData/` | Default data (admin user, categories, settings) |
| `SQL/SampleData/` | Example data for demos |
| `Migrations/` | Alembic migration scripts |
| `Backup/` | Backup and restore scripts |
| `Scripts/` | Database setup scripts |
| `Testing/` | Test data and scripts |

---

## 5. Backend Folder Structure

```
Backend/
├── app/
│   ├── api/
│   │   ├── routers/        # FastAPI APIRouters per module
│   │   ├── schemas/        # Pydantic request/response models
│   │   └── dependencies/   # Auth, DB session, pagination deps
│   ├── services/           # Business logic
│   ├── repositories/       # Data access (SQLAlchemy)
│   ├── models/             # SQLAlchemy ORM models
│   ├── database/           # Engine, session, base model
│   ├── middleware/         # Auth, CORS, logging, error handling
│   ├── core/               # Config, security, constants
│   ├── utils/              # Hashing, tokens, pagination
│   ├── tests/              # Unit, integration, API tests
│   └── alembic/            # Migrations (versions/)
├── requirements.txt
├── .env.example
├── .env
└── README.md
```

> See [15_Backend_Architecture](../15_Backend_Architecture/README.md) for
> full details on each directory.

---

## 6. Frontend Folder Structure

```
Frontend/
├── src/
│   ├── assets/              # Images, icons, fonts
│   ├── components/
│   │   ├── ui/              # Reusable primitives
│   │   ├── layout/          # Header, Sidebar, Footer
│   │   ├── forms/           # Form components
│   │   └── common/          # Loading, error, empty states
│   ├── pages/               # Route-level components
│   │   ├── auth/            # Login
│   │   ├── admin/           # Admin pages
│   │   ├── cashier/         # Cashier pages
│   │   └── shared/          # 404, settings, notifications
│   ├── layouts/             # Layout wrappers
│   ├── hooks/               # Custom React hooks
│   ├── services/            # Business logic hooks
│   ├── api/                 # Axios instance + endpoints
│   ├── context/             # Auth context
│   ├── types/              # TypeScript types
│   ├── utils/            # Utility functions
│   ├── routes/         # Route config
│   └── public/     # Static assets
├── package.json
├── vite.config.ts
├── tailwind.config.js
├── tsconfig.json
├── .env.example
├── .env
└── README.md
```

> See [16_Frontend_Architecture](../16_Frontend_Architecture/README.md) for
> full details on each directory.

---

## 7. Testing Folder Structure

```
Testing/
├── e2e/                     # Playwright end-to-end test suites
├── data/                    # Test data files
├── scripts/                 # Test orchestration scripts
├── reports/                 # Generated test reports
└── README.md                # Testing overview
```

---

## 8. Deployment Folder Structure

```
Deployment/
├── docker/
│   ├── Dockerfile.backend
│   ├── Dockerfile.frontend
│   └── docker-compose.yml
├── kubernetes/
│   ├── deployment.yaml
│   ├── service.yaml
│   └── ingress.yaml
├── nginx/
│   ├── nginx.conf
│   └── default.conf
├── ci-cd/
│   └── github-actions/
│       ├── build.yml
│       ├── test.yml
│       └── deploy.yml
└── README.md
```

---

## 9. Visual Folder Structure

See [Diagrams/folder-structure.mmd](../Diagrams/folder-structure.mmd) for a
visual representation of the project tree.

---

## 10. Related Documents

- [15_Backend_Architecture](../15_Backend_Architecture/README.md)
- [16_Frontend_Architecture](../16_Frontend_Architecture/README.md)
- [12_System_Architecture](../12_System_Architecture/README.md)
- [13_Database_Overview](../13_Database_Overview/README.md)
- [SMARTPOS_PROJECT_BIBLE.md](..//../AI/SMARTPOS_PROJECT_BIBLE.md#project-structure)

---

## 11. Revision History

| Version | Date | Author | Description |
|---------|------|--------|-------------|
| 1.0 | 2026-08-07 | SmartPOS Documentation Team | Initial release |
