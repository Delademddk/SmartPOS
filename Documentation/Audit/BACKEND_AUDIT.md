# BACKEND AUDIT - SmartPOS (FastAPI)

## Audit Date
2026-08-09

## Stack
- FastAPI + SQLAlchemy 2.0 (async-ready session made sync via helper), Pydantic v2
- App root: `SmartPOS/Backend`, entry point `app/main.py`, uvicorn on `localhost:8000`
- Response envelope: `{success, data, meta}`; errors `{success:false, error:{code,message,details,timestamp,request_id}}`
- Permission gate: `require_permission(PermissionCode.XXX)` dependency (JWT)

## Finding 1 (CRITICAL) - Invalid boolean filtering for SQL Server

### Problem
`GET /categories` and `POST /categories` (and most other reads/creates) returned HTTP 500.

### Root cause
SQLAlchemy's `.is_(True)` / `.is_(False)` operators compile to `column IS 1` / `column IS 0` in the T-SQL dialect. SQL Server does not accept `IS 1` / `IS 0` next to a column reference, raising:

```
ProgrammingError: (pyodbc.ProgrammingError) ('42000', "[42000] [Microsoft][ODBC Driver 18 for SQL Server][SQL Server]Incorrect syntax near '0'. ...")
```

The exception surfaced through the global error handler as a generic `INTERNAL_ERROR` 500. This pattern was present at **28 call sites across 8 files** and silently disabled read and write flows across catalog, ops, auth, reports, notifications, and dashboard modules.

### Files affected and occurrences
| File | Lines |
|------|-------|
| `app/repositories/catalog_repo.py` | 44, 56, 79, 86, 114, 188 (`is_deleted`) |
| `app/repositories/system_repo.py` | 57 (`Notification.is_read`) |
| `app/repositories/ops_repo.py` | 40, 207 (`Product`/`Customer` `is_deleted`) |
| `app/repositories/auth_repo.py` | 50, 106, 123 (`User.is_active`, `Permission.is_active`, `UserSession.is_revoked`) |
| `app/services/reports_service.py` | 182, 304, 306 (`Product`/`Supplier` `is_deleted`) |
| `app/services/notifications_service.py` | 157, 158 (`User.is_active`, `User.is_deleted`) |
| `app/services/dashboard_service.py` | 74, 80, 91, 92, 97, 98, 276, 336, 341 (`is_deleted`, `is_active`, `is_read`) |
| `app/api/dependencies/auth.py` | 95, 112 (`UserSession.is_revoked`, `Permission.is_active`) |

### Fix applied
Replaced `.is_(True)` → `== True` and `.is_(False)` → `== False` at every site. `.is_(None)` comparisons were left unchanged. `== True`/`== False` compile to valid T-SQL (`column = 1` / `column = 0`).

### Verified
- Backend imports cleanly (`python -c "import app.main"`).
- `GET /categories` returned 200 with all 5 records.
- `POST /categories` returned 201 and persisted to SQL Server.
- All 40 documented GET routes returned HTTP 200 (see API_TEST_RESULTS.md).

## Finding 2 (HIGH) - `func.date()` not supported on SQL Server

### Problem
`GET /dashboard/sales-trend-7d` returned HTTP 500.

### Root cause
`dashboard_service.py` `sales_trend_7d` used `func.date(Sale.sale_date)`. `DATE()` is not a built-in T-SQL function, so SQL Server raised `'date' is not a recognized built-in function name.`

### Fix applied
Replaced both `func.date(Sale.sale_date)` calls with `cast(Sale.sale_date, Date)` and added `Date` and `cast` to the `sqlalchemy` import in `app/services/dashboard_service.py`.

### Verified
`GET /dashboard/sales-trend-7d` → HTTP 200.

## Finding 3 (HIGH) - `metadata` field name collision in audit schema

### Problem
`GET /audit/activity` returned HTTP 500 (validation crash when serializing activity log rows).

### Root cause
The Pydantic model `ActivityLogRead` in `app/api/schemas/audit.py` declared a field named `metadata`. `metadata` is a class attribute on SQLAlchemy's declarative `Base`, so `from_attributes`/serialization collided and crashed with a `pydantic`/SQLAlchemy attribute error.

### Fix applied
Renamed the schema field `metadata` → `metadata_json` in `app/api/schemas/audit.py`.

### Verified
`GET /audit/activity` → HTTP 200.

## Other Checks (no change required)
- **Sessions**: `get_db` yields one session per request; repository methods use the injected session; `commit`/`refresh` used correctly on create; `flush` + `commit` ordering is sound. No nested-transaction bug found.
- **Routing**: `POST /categories` calls `category_service.create_category`, which checks for duplicates (`DUPLICATE_RESOURCE` 409) and delegates to `catalog_repo.create_category`.
- **Auth**: JWT minted with `app.core.security.create_access_token(1, "ADMIN", "admin")` using the same secret as the running server; permission checks (`CATEGORIES_VIEW`, `CATEGORIES_CREATE`) passed for this token.
- **Envelope**: Consistent across endpoints.
- **Error handler**: Converts `SQLAlchemyError` to a generic 500. This masked the true T-SQL errors during diagnosis; a log-level improvement (`details` echoing the exception when not in production) is a low-priority suggestion, not a fix.

## Conclusion
All backend defects that broke the category data flow (and the extra dashboard/audit routes) are fixed and verified. The backend now serves all 40 GET routes with HTTP 200.
