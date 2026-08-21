# DATABASE AUDIT - SmartPOS

## Audit Date
2026-08-09

## Environment

| Item | Value |
|------|-------|
| Server | `DESKTOP-BP6RL8D` |
| Engine | Microsoft SQL Server 2022 (16.0.1000.6), Developer Edition on Windows 10 |
| Database | `SmartPOS` |
| Auth | SQL Server login `sa` |
| Connection driver | `ODBC Driver 18 for SQL Server` |

### Connection string (Backend/.env)
```
DATABASE_URL=mssql+pyodbc://sa:12345@DESKTOP-BP6RL8D:1433/SmartPOS?driver=ODBC+Driver+18+for+SQL+Server&TrustServerCertificate=yes
```

## Connectivity Verification

- **From the backend**: The FastAPI app started successfully, meaning SQLAlchemy could import and the DB engine was reachable from the Windows-hosted backend process.
- **Direct query (pyodbc, Windows python)**: A direct `pyodbc.connect()` to `SmartPOS` succeeded; table counts and row content were read back (see below).
- **Result**: The backend is connected to the correct database instance and the expected tables exist. No connectivity, schema, or seed-data problem was found.

## Schema / Data Snapshot

Queried `SmartPOS` (schema `dbo`):

| Table | Row count |
|-------|-----------|
| `dbo.categories` | 5 |
| `dbo.products` | 1 |
| `dbo.users` | 3 |
| `dbo.roles` | 3 |

### Categories present (all `is_active = 1`, `is_deleted = 0`)
1. Beverages
2. Food
3. Electronics
4. Office Supplies
5. Cleaning Supplies

### Columns of `dbo.categories`
The table does **not** contain any `category_code` column. Relevant columns (per `Database/SQL/04_Categories/tables.sql`):

- `category_id` (PK, identity)
- `category_name`
- `description`
- `parent_id` (nullable self-reference)
- `is_active`
- `is_deleted`
- `created_at`, `updated_at`, `created_by`, `updated_by`

> **Finding:** The frontend required and sent `category_code`, which has never existed in the database. The backend ORM model and Pydantic schemas also have no such field.

## Seed Data Notes
- `Database/SQL/SeedData.sql` shipped placeholder bcrypt hashes (`$2b$12$...`); the `users` table in the live DB contains real bcrypt hashes and `must_change_password = 0`. The seed script is a template, not an active migration.
- Seed data present: 3 users (admin, cashier, manager) and 3 roles. A previously-created product exists (1 row).

## Transactions / Persistence
- Tables use `is_deleted` soft-delete flags; writes for categories route through the backend repository layer.
- Verified in this audit: a category inserted through the API (`POST /api/v1/categories`) was immediately readable in SQL Server via `pyodbc` (`category_id`, `category_name`, `is_active`, `is_deleted`), confirming commits reach the database. Test rows were removed afterwards; the DB was restored to the original 5 categories.

## Database-Side Findings and Resolutions

| # | Finding | Severity | Resolution |
|---|---------|----------|------------|
| 1 | Backend queries used `column IS 1`/`column IS 0` (invalid T-SQL for boolean filters) | Critical (caused 500s) | Fixed in backend query layer (see BACKEND_AUDIT.md) - not a database data issue |
| 2 | No `category_code` column exists while the frontend assumed one | High (caused 422) | Fixed in frontend (see FRONTEND_AUDIT.md) - not a database data issue |
| 3 | `func.date()` used on a datetime column | Medium (caused 500 on one dashboard route) | Fixed in backend (cast to `Date`) |
| 4 | Seed data placeholders | Low | Documented; live DB is correct |

## Conclusion
The database is healthy, reachable, correctly configured, and contains valid seed data. None of the reported symptoms (`no data shown`, `category not saved`) originated in the database layer; they were caused by backend SQL generation and a frontend contract mismatch.
