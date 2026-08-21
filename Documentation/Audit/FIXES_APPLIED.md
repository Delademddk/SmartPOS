# FIXES APPLIED - SmartPOS

## Audit Date
2026-08-09

All changes verified. Change list matches `git diff --stat` in `SmartPOS/`.

## Backend (9 files)

### 1. `Backend/app/repositories/catalog_repo.py`
- **Problem:** `.is_(False)` on `Category.is_deleted` compiled to `IS 0` (invalid T-SQL) in category list/get/count/create/delete queries.
- **Fix:** `.is_(False)` → `== False` (lines 44, 56, 79, 86, 114, 188).

### 2. `Backend/app/repositories/system_repo.py`
- **Problem:** `.is_(False)` on `Notification.is_read` compiled to `IS 0`.
- **Fix:** `.is_(False)` → `== False` (line 57).

### 3. `Backend/app/repositories/ops_repo.py`
- **Problem:** `.is_(False)` on `Product.is_deleted` / `Customer.is_deleted` compiled to `IS 0`.
- **Fix:** `.is_(False)` → `== False` (lines 40, 207).

### 4. `Backend/app/repositories/auth_repo.py`
- **Problem:** `.is_(True)` / `.is_(False)` on `User.is_active`, `Permission.is_active`, `UserSession.is_revoked` compiled to `IS 1` / `IS 0`.
- **Fix:** `.is_(True)` → `== True`, `.is_(False)` → `== False` (lines 50, 106, 123).

### 5. `Backend/app/services/reports_service.py`
- **Problem:** `.is_(False)` on `Product.is_deleted` / `Supplier.is_deleted` compiled to `IS 0`.
- **Fix:** `.is_(False)` → `== False` (lines 182, 304, 306).

### 6. `Backend/app/services/notifications_service.py`
- **Problem:** `.is_(True)` / `.is_(False)` on `User.is_active` / `User.is_deleted` compiled to `IS 1` / `IS 0`.
- **Fix:** `.is_(True)` → `== True`, `.is_(False)` → `== False` (lines 157, 158).

### 7. `Backend/app/services/dashboard_service.py`
- **Problem A:** `.is_(True/False)` on `Product`, `Category`, `Notification` columns compiled to `IS 1` / `IS 0`.
- **Fix A:** replaced at lines 74, 80, 91, 92, 97, 98, 276, 336, 341.
- **Problem B:** `sales_trend_7d` used `func.date(Sale.sale_date)` (`'date' is not a recognized built-in function name`).
- **Fix B:** `func.date(...)` → `cast(Sale.sale_date, Date)` (2 sites); added `Date, cast` to the `sqlalchemy` import.

### 8. `Backend/app/api/dependencies/auth.py`
- **Problem:** `.is_(False)` on `UserSession.is_revoked` / `Permission.is_active` in the permission-check path (the first thing every protected request hits) compiled to `IS 0`.
- **Fix:** `.is_(False)` → `== False`, `.is_(True)` → `== True` (lines 95, 112).

### 9. `Backend/app/api/schemas/audit.py`
- **Problem:** `ActivityLogRead` field named `metadata` collided with SQLAlchemy `Base.metadata`, crashing `/audit/activity` with HTTP 500.
- **Fix:** renamed schema field `metadata` → `metadata_json` (line 35).

## Frontend (3 files)

### 10. `Frontend/src/pages/categories/CategoriesPage.tsx`
- **Problem A:** Zod schema, `defaultValues`, and create/edit payloads included `category_code` (not in DB/ORM/schema → HTTP 422 on create).
- **Fix A:** removed `category_code` from the Zod schema, `defaultValues`, and payloads.
- **Problem B:** table rendered a "Code" column reading `category.category_code` (always `undefined`).
- **Fix B:** removed the header and cell.
- **Problem C:** `allCategories` query used `page_size: 1000`, exceeding the backend `le=200` cap → HTTP 422 on the dropdown query.
- **Fix C:** `page_size: 1000` → `page_size: 200`.

### 11. `Frontend/src/types/models.ts`
- **Problem:** `Category` interface declared `category_code: string` (non-existent field).
- **Fix:** removed `category_code` from the `Category` interface.

### 12. `Frontend/tsconfig.json`
- **Problem:** invalid `"ignoreDeprecations": "6.0"` broke `tsc -b` (`TS5103: Option 'ignoreDeprecations' must be a specific version, e.g. '5.0'.`). Pre-existing uncommitted change, unrelated to the data flow.
- **Fix:** `"ignoreDeprecations": "6.0"` → `"5.0"`.

## Not Changed (verified OK)
- `Frontend/src/services/client.ts` (envelope unwrapping, base URL, auth header) - correct.
- `Frontend/src/hooks/...` category query hooks and invalidation logic - correct.
- `Backend/app/api/schemas/categories.py`, `Backend/app/models/...` - authoritative (no `category_code`).
- `.env` files, CORS, routers, services, transactions - correct.

## Notes on unrelated pre-existing uncommitted changes
`Frontend/src/App.tsx` and `Frontend/src/context/AuthContext.tsx` already contained uncommitted local edits (Toaster placement, auth context) before this audit. They were not modified by this repair.
