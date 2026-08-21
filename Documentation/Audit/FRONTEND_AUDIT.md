# FRONTEND AUDIT - SmartPOS (React + Vite)

## Audit Date
2026-08-09

## Stack
- React 18 + TypeScript, Vite dev server on `localhost:5173`, axios client, TanStack Query v5, React Hook Form + Zod
- App root: `SmartPOS/Frontend`
- API base: `VITE_API_URL=http://localhost:8000/api/v1` (`Frontend/.env`); dev proxy `/api` → `http://localhost:8000`
- Type model file: `src/types/models.ts`

## Finding 1 (CRITICAL) - `category_code` contract mismatch

### Problem
The Categories page never showed data properly (it relied on a field that does not exist) and, more importantly, `POST /categories` returned HTTP 422 `Extra inputs are not permitted`, so a category created from the UI was never persisted.

### Root cause
The UI was written against a `category_code` column. Evidence:

- `src/pages/categories/CategoriesPage.tsx`:
  - Zod schema: `category_code: z.string().min(1, "...")` (required)
  - React Hook Form `defaultValues` included `category_code: ""`
  - The create payload sent `category_code` to the API
  - The table rendered a "Code" column reading `category.category_code`
- `src/types/models.ts` `Category` interface declared `category_code: string`

Neither the SQL Server table (`dbo.categories`), the SQLAlchemy `Category` model, nor the Pydantic `CategoryCreate` schema has a `category_code` field. `CategoryCreate` uses `extra="forbid"`, so the stray field was rejected with HTTP 422 before any database write occurred.

### Fix applied
In `src/pages/categories/CategoriesPage.tsx`:
- Removed `category_code` from the Zod schema
- Removed `category_code` from `defaultValues`
- Removed the "Code" table header and cell (the value was always `undefined`)
- Create/edit payloads no longer include `category_code`

In `src/types/models.ts`:
- Removed `category_code` from the `Category` interface

### Verified
- `POST /categories` with the exact UI payload (no `category_code`) → HTTP 201, persisted to SQL Server.
- TypeScript compile + production build succeed.

## Finding 2 (HIGH) - `page_size=1000` exceeded backend cap

### Problem
The `allCategories` query used `page_size=1000`. The backend pagination helper caps `page_size` at `le=200`, producing HTTP 422 for the dropdown query.

### Root cause
`src/pages/categories/CategoriesPage.tsx` used `{ page_size: 1000 }` for the flat category list used by the parent-category dropdown.

### Fix applied
Changed `page_size: 1000` → `page_size: 200`.

### Verified
`GET /categories?page_size=200` → HTTP 200.

## Finding 3 (MEDIUM, pre-existing) - broken `tsconfig.json`

### Problem
`npm run build` failed at typecheck: `Option 'ignoreDeprecations' must be a specific version, e.g. '5.0'.`.

### Root cause
`Frontend/tsconfig.json` contained an invalid value `"ignoreDeprecations": "6.0"` (not a valid TS version). The project uses TypeScript 5.x. This was an uncommitted local change that broke the build independently of the data-flow issue.

### Fix applied
Changed `"ignoreDeprecations": "6.0"` → `"ignoreDeprecations": "5.0"`.

### Verified
`tsc -b` succeeds; `vite build` produces a production bundle.

## Checked and OK (no change)
- **axios client** (`src/services/client.ts`): correct base URL resolution (`import.meta.env.VITE_API_URL ?? "/api/v1"`), JSON headers, axios interceptor unwraps the `{success, data, meta}` envelope and throws on `!success`. No change needed.
- **Query invalidation**: After create/update/delete, `queryClient.invalidateQueries({ queryKey: ["categories"] })` re-fetches the list; because the backend was broken, this never became visible. Works now.
- **TanStack Query hooks**: `listCategories` and `allCategories` use `staleTime`/`enabled` correctly; no infinite loop, no stale-forever cache.
- **Auth header**: token attached globally via the interceptor; endpoints were 401/403 free once the backend 500s were removed.
- **CORS**: dev proxy avoids CORS; direct hits to `localhost:8000` are served with the backend's configured CORS middleware. No CORS error was observed.

## Remaining Finding (documented, out of scope)
- `src/pages/products/ProductsPage.tsx` has the same class of mismatch for products: create/update payloads include `product_code`, `tax_rate_id`, `reorder_level`, while the backend `ProductCreate`/`ProductUpdate` schemas use `sku` and `low_stock_threshold` (no `tax_rate_id`). Product create/update from the UI would return 422. Recommended alignment: `product_code` → `sku`, `reorder_level` → `low_stock_threshold`, drop `tax_rate_id`. Left for a separate feature-scoped change to keep this repair minimal.
- `src/pages/audit/AuditPage.tsx` reads `action` / `description` while the backend now returns `activity_type` / `activity_desc`; the columns render blank but the route no longer errors.

## Conclusion
The category data flow on the frontend is fixed: payloads now match the backend contract, queries respect pagination limits, and the project typechecks and builds. Verified end-to-end in VERIFICATION_RESULTS.md.
