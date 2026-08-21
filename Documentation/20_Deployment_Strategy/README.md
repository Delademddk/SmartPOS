# SmartPOS — Deployment Strategy

**Document ID:** DOC-DEPLOY-020  
**Version** 1.0  
**Status:** Approved  
**Author:** SmartPOS Documentation Team  
**Date:** August 7, 2026  

---

## 1. Purpose

This document defines the **deployment strategy** for SmartPOS. It covers the
development, testing, and production environments, configuration management,
backup and restore strategies, versioning, and the release process.

> **Reference:** [Project Bible — Deployment Expectations](../AI/SMARTPOS_PROJECT_BIBLE.md#deployment-expectations),
> [Setup Scripts](../AI/SMARTPOS_PROJECT_BIBLE.md#setup-scripts).

---

## 2. Environments

### 2.1 Development Environment

| Component | Details |
|-----------|---------|
| Backend | FastAPI dev server (`uvicorn --reload`) at `http://localhost:8000` |
| Frontend | Vite dev server at `http://localhost:5173` |
| Database | Local SQL Server instance (Docker or native) |
| Configuration | `.env` files in `Backend/` and `Frontend/` |
| Code Changes | Hot-reload enabled |
| Debugging | Swagger UI at `http://localhost:8000/docs` |

### 2.2 Testing Environment

| Component | Details |
|-----------|---------|
| Backend | Same as dev, but against a test database |
| Frontend | Same as dev |
| Database | Dedicated test SQL Server instance |
| Configuration | `.env.test` files |
| Automation | pytest (backend), vitest (frontend), Playwright (E2E) |

### 2.3 Staging Environment

| Component | Details |
|-----------|---------|
| Backend | Uvicorn + Gunicorn behind Nginx |
| Frontend | Production build served via Nginx |
| Database | Staging SQL Server |
| Configuration | Production-like `.env` |
| Purpose | UAT and pre-release validation |

### 2.4 Production Environment

| Component | Details |
|-----------|---------|
| Backend | Uvicorn workers (4+) behind Nginx reverse proxy, TLS 1.2+ |
| Frontend | Static files (`dist/`) served via Nginx |
| Database | Dedicated SQL Server instance with backups enabled |
| Configuration | `.env.production` (all secrets configured) |
| Monitoring | Health endpoint, structured logging, external monitoring (Phase 2) |

---

## 3. Technology Stack for Deployment

| Component | Technology |
|-----------|------------|
| Container | Docker |
| Orchestration | Docker Compose (dev/staging) / Kubernetes (prod, Phase 2) |
| Reverse Proxy | Nginx |
| TLS | Let's Encrypt (or internal CA) |
| CI/CD | GitHub Actions |
| Package Management | pip (backend), npm (frontend) |

---

## 4. Setup Scripts

Per the Project Bible, the following setup scripts are generated in the
`Scripts/` directory:

| Script | Purpose |
|--------|---------|
| `setup_database.bat` | Create database, run seed data, apply constraints |
| `setup_backend.bat` | Install Python dependencies, set up virtualenv, run migrations |
| `setup_frontend.bat` | Install npm dependencies, build (optional) |
| `start_project.bat` | Start all services (backend API + frontend dev server) |

### 4.1 setup_database.bat (Outline)

```bat
@echo off
echo [1/4] Checking SQL Server connection...
echo [2/4] Creating SmartPOS database...
echo [3/4] Applying schema (Tables, Constraints, Indexes)...
echo [4/4] Loading seed data...
echo Database setup complete.
pause
```

### 4.2 setup_backend.bat (Outline)

```bat
@echo off
echo [1/4] Creating virtual environment...
python -m venv venv
call venv\Scripts\activate
echo [2/4] Installing dependencies...
pip install -r requirements.txt
echo [3/4] Running Alembic migrations...
alembic upgrade head
echo [4/4] Backend setup complete.
pause
```

### 4.3 setup_frontend.bat (Outline)

```bat
@echo off
echo [1/3] Installing npm dependencies...
cd Frontend
npm install
echo [2/3] Building production assets...
echo [3/3] Frontend setup complete.
pause
```

### 4.4 start_project.bat (Outline)

```bat
@echo off
echo Starting SmartPOS...
start "Backend" cmd /k "venv\Scripts\activate && uvicorn app.main:app --reload --port 8000"
start "Frontend" cmd /k "cd Frontend && npm run dev"
echo SmartPOS is starting. Backend: http://localhost:8000, Frontend: http://localhost:5173
pause
```

---

## 5. Docker Deployment (Recommended)

### 5.1 docker-compose.yml (Development)

```yaml
version: "3.9"
services:
  db:
    image: mcr.microsoft.com/mssql/server:2022-latest
    environment:
      - ACCEPT_EULA=Y
      - SA_PASSWORD=${DB_SA_PASSWORD}
    ports:
      - "1433:1433"
    volumes:
      - sql_data:/var/opt/mssql

  backend:
    build: ./Backend
    env_file: ./Backend/.env
    ports:
      - "8000:8000"
    depends_on:
      - db

  frontend:
    build: ./Frontend
    ports:
      - "5173:80"
    depends_on:
      - backend

volumes:
  sql_data:
```

### 5.2 Docker Deployment (Production)

- Frontend built with `npm run build` and served as static files.
- Backend runs with Gunicorn + Uvicorn workers behind Nginx.
- SSL handled by Nginx with Let's Encrypt certificates.

---

## 6. Configuration Management

### 6.1 Environment Files

| File | Purpose | Git-ignored? |
|------|---------|--------------|
| `Backend/.env` | Local development secrets | Yes |
| `Backend/.env.example` | Template with placeholder values | No |
| `Backend/.env.production` | Production secrets | Yes |
| `Frontend/.env` | Local dev config | Yes |
| `Frontend/.env.example` | Template | No |
| `Frontend/.env.production` | Production config | Yes |

### 6.2 Secret Management (Production)

- Secrets injected via environment variables in the deployment environment.
- Docker secrets or Kubernetes secrets used in containerized deployments.
- No secrets in source control.

> **Related:** [18_Security_Architecture — §7](../18_Security_Architecture/README.md#7-environment--secret-management)

---

## 7. Database Setup & Migration

### 7.1 Initial Setup

1. Create the database (`SmartPOS`).
2. Run `scripts/setup_database.bat` to apply schema.
3. Run Alembic migrations: `alembic upgrade head`.
4. Load seed data (default admin, categories, suppliers, settings).

### 7.2 Migrations

- All schema changes are managed via **Alembic**.
- Migration scripts stored in `Backend/app/alembic/versions/`.
- Migrations run automatically on startup in production (`alembic upgrade head`).

### 7.3 Sample Data

- Sample products, sales, and returns are provided in
  `Database/SampleData/` for demonstration and training.

---

## 8. Backup Strategy

### 8.1 Backup Schedule

| Backup Type | Frequency | Retention |
|-------------|-----------|-----------|
| Full Database Backup | Daily at 02:00 UTC | 30 daily |
| Differential Backup | Every 6 hours | 7 daily |
| Transaction Log Backup | Every 15 minutes | 48 hourly |
| Weekly Full Backup | Weekly | 12 weekly |
| Monthly Full Backup | Monthly | 6 monthly |

### 8.2 Backup Scripts

Backups are created via SQL Server's `BACKUP DATABASE` and `BACKUP LOG` T-SQL
commands, scheduled via SQL Server Agent or cron.

Scripts located in `Database/Backup/`:

| Script | Purpose |
|--------|---------|
| `backup_full.sql` | Full database backup |
| `backup_log.sql` | Transaction log backup |
| `backup_full.bat` | Windows batch wrapper |
| `backup_restore.bat` | Restore procedure wrapper |

### 8.3 Backup Storage

- Backups stored on a **separate disk/volume** from the primary database.
- Backups also copied to cloud storage (e.g., Azure Blob Storage) for
  disaster recovery.

---

## 9. Restore Strategy

### 9.1 Restore Process

1. Identify the most recent clean full backup.
2. Apply all transaction log backups taken after the full backup.
3. Restore to the desired point in time.

### 9.2 Restore Scripts

Located in `Database/Backup/`:

| Script | Purpose |
|--------|---------|
| `restore_database.bat` | Full database restore |
| `restore_to_point_in_time.sql` | Point-in-time recovery |

### 9.3 Recovery Time Objective (RTO)

- **Critical (transactions):** RTO ≤ 4 hours.
- **Non-critical (reports):** RTO ≤ 24 hours.

### 9.4 Recovery Point Objective (RPO)

- **Transactions:** RPO = 15 minutes (transaction log backups).
- **Non-critical data:** RPO = 24 hours (daily backups).

---

## 10. Versioning

### 10.1 Semantic Versioning

SmartPOS uses Semantic Versioning: `MAJOR.MINOR.PATCH`.

| Version Type | Meaning | Release Frequency |
|--------------|---------|-------------------|
| **MAJOR** | Breaking changes to API or DB schema | Rare |
| **MINOR** | New features, backward-compatible | Every 2–4 weeks |
| **PATCH** | Bug fixes, security patches | As needed |

### 10.2 API Versioning

- API version is in the URL path: `/api/v1/`.
- Breaking changes increment the major version (`/api/v2/`).

---

## 11. Release Process

### 11.1 Pre-Release Checklist

| Item | Owner | Status |
|------|-------|--------|
| All tests pass (unit, integration, API, E2E) | DevOps / QA | ☐ |
| Linting passes | Dev team | ☐ |
| Security scan complete (no critical issues) | Security | ☐ |
| Documentation updated | Docs team | ☐ |
| Dockerfile builds successfully | DevOps | ☐ |
| Release notes written | Product Manager | ☐ |
| Backup verified | DBA | ☐ |
| Staging deployment verified | QA | ☐ |

### 11.2 Deployment Steps

1. Create a release branch from `main`.
2. Bump version numbers in all packages.
3. Update `CHANGELOG.md`.
4. Build and run all tests.
5. Create a Git tag.
6. Push Docker images to registry.
7. Deploy to staging.
8. Run E2E tests on staging.
9. Deploy to production (manual approval required).
10. Post-deployment smoke test.
11. Announce release.

### 11.3 Rollback Procedure

If a production deployment fails:

1. Revert to the previous Docker image tag.
2. Restore database from the most recent backup (if schema migration broke).
3. Notify all stakeholders.
4. Investigate and fix root cause.
5. Re-attempt deployment after fix verified.

---

## 12. Monitoring & Observability (Phase 2)

While Phase 1 includes basic health checks and logging, Phase 2 will add:

| Feature | Tool |
|---------|------|
| Application Performance Monitoring (APM) | Sentry, Prometheus + Grafana |
| Log Aggregation | ELK Stack (Elasticsearch, Logstash, Kibana) |
| Infrastructure Monitoring | Prometheus + Grafana |
| Alerting | PagerDuty, Slack webhooks |
| Health Dashboard | Custom admin page |

---

## 13. Related Documents

- [20_Deployment_Strategy — Self](./) (this document)
- [12_System_Architecture](../12_System_Architecture/README.md)
- [13_Database_Overview](../13_Database_Overview/README.md)
- [18_Security_Architecture](../18_Security_Architecture/README.md#7-environment--secret-management)
- [19_Testing_Strategy](../19_Testing_Strategy/README.md)
- [AI/SMARTPOS_PROJECT_BIBLE.md](..//../AI/SMARTPOS_PROJECT_BIBLE.md#deployment-expectations)
- [Diagrams/deployment-architecture.mmd](../Diagrams/deployment-architecture.mmd)

---

## 14. Revision History

| Version | Date | Author | Description |
|---------|------|--------|-------------|
| 1.0 | 2026-08-07 | SmartPOS Documentation Team | Initial release |
