# PRODUCT QUANTITY FRONTEND IMPLEMENTATION

> Task: Implement the product quantity frontend controls (Add Product quantity, Restock workflows, Inventory) connected to the already-working SmartPOS backend. No redesign; reuse the existing Tailwind design system, modal patterns, and `react-hot-toast`.

## Status

**Implemented and verified.**

- Backend unit/integration tests: **65 passed**
- Frontend typecheck (`tsc -b`): **clean**
- Frontend lint (ESLint, `--max-warnings 0`): **clean**
- Frontend tests (Vitest): **52 passed**
- Frontend production build (`vite build`): **succeeds**
- End-to-end API verification (mirrors exact frontend payloads, SQLite in-memory): **all checks passed**

---

## 1. Existing Backend (no change needed for the core flow)

The backend already fully supports product quantities. The frontend was built against these existing contracts:

| Endpoint | Payload | Effect |
| --- | --- | --- |
| `POST /api/v1/products` | `ProductCreate` includes `initial_quantity: int = Field(default=0, ge=0)` | Creates the product and an initial `RESTOCK` inventory movement |
| `POST /api/v1/inventory/restock` | `{ product_id, quantity: int (gt=0), unit_cost?: Decimal, reason?: str }` | Adds stock, records a `RESTOCK` movement |
| `POST /api/v1/inventory/adjust` | `{ product_id, adjustment_type, system_quantity, counted_quantity, quantity_change, reason }` | Reconciliation / manual adjustment |
| `GET /api/v1/products` | `ProductRead` returns `quantity_on_hand`, `stock_status`, `low_stock_threshold` | Read stock from server |
| `GET /api/v1/inventory` | `InventoryRead` returns `quantity_on_hand`, `available_quantity`, `low_stock_threshold`, `last_restocked_at`, `last_sold_at`, `stock_status` | Inventory table |
| `GET /api/v1/inventory/movements` | `MovementRead` returns `sku`, `reference_type`, `reference_id`, `username`, `quantity_change` | Movements log |
| `GET /api/v1/inventory/low-stock` | `LowStockAlertRead` returns `low_stock_threshold`, `raised_at`, `resolved_at` | Low-stock panel |

**Source of truth:** stock quantities are never computed client-side. The React layer only reads `quantity_on_hand`/`available_quantity` and triggers restock/adjust operations; the backend `InventoryService` owns the arithmetic.

**Schemas enforce `extra="forbid"`** (`app/api/schemas/common.py`), so the frontend must send exactly the known fields — this drove the payload fixes in `InventoryPage` (see §3).

---

## 2. One Small Backend Fix (validation error handling)

Found during end-to-end verification: `POST /products` parses the JSON body manually (`_parse_product_request` in `app/api/routers/products.py`). A pydantic `ValidationError` raised there was **not** converted into the standard FastAPI `RequestValidationError`, so an invalid product payload (e.g. negative `initial_quantity`) produced an **HTTP 500** instead of a clean **422** with validation details.

**Fix (`app/api/routers/products.py`):** added `_parse_schema_payload()` which wraps `schema.model_validate_json()` and re-raises the pydantic error as `RequestValidationError`, so the existing middleware produces the normal 422 error envelope.

- No new endpoints, no schema changes, no DB changes.
- Verified: `initial_quantity: -3` now returns `422` with a clear `error.message` (was 500).
- All 65 backend tests still pass.

---

## 3. Frontend Changes

### `Frontend/tsconfig.json`
- Removed invalid `"ignoreDeprecations": "6.0"` (pre-existing config error; broke `tsc -b` / builds under TypeScript 5.9.3).

### `Frontend/src/types/models.ts` — aligned to backend schemas
- `Product`: removed `product_code`, `tax_rate_id`, `tax_rate_name`, `reorder_level`; added `unit`, `low_stock_threshold`, `is_service`; `cost_price` and `category_id` are now `number | null`.
- `Inventory`: removed `last_restock_date`/`last_count_date`; added `last_restocked_at`, `last_sold_at`, `low_stock_threshold`, `reorder_level: number | null`.
- `InventoryMovement`: added `sku`, `reference_type`, `reference_id`, `username`; removed `reference_number`, `user_id`, `user_name`.
- `LowStockAlert`: `low_stock_threshold`, `raised_at`, `resolved_at`; removed `reorder_level`, `severity`, `created_at`.

### `Frontend/src/pages/products/ProductsPage.tsx`
- **Add Product:** new **Quantity** input (label "Quantity"), zod `quantity: z.coerce.number().int().min(0).optional()`; sent as `initial_quantity` (default `0`). Input only rendered in create mode.
- **Edit Product:** shows read-only **Current Stock** and a **Restock** button; label "Low Stock Threshold" for the threshold field (replaces "Reorder Level"). Edit defaults use `low_stock_threshold`, `category_id ?? 0`, `cost_price ?? 0`.
- **Restock action:** `RestockModal` (existing modal pattern + Tailwind classes) calls `POST /inventory/restock` with `{ product_id, quantity, unit_cost, reason }`, displays the current stock, and shows success/error toasts.
- **Error handling:** `getApiErrorMessage(error, fallback)` unwraps the backend envelope (`error.message` / `error.details[].message` / 422 loc map) → toast message.
- **Query invalidation:** `invalidateProductQueries()` invalidates `products`, `pos-products`, `inventory`, `inventory-movements`, `inventory-low-stock`, `dashboard` after create/update/archive/delete/activate/restock, so quantities refresh everywhere.
- Removed obsolete **Product Code** and **Tax Rate** fields (fields do not exist in the current backend contract).

### `Frontend/src/pages/inventory/InventoryPage.tsx`
- **Fixed broken payloads:** restock/adjust mutations previously sent `{ body: data }` (an extra wrapper) — rejected as 422 by `extra="forbid"`. Now send top-level fields with `product_id: Number(...)`.
- **Query invalidation:** restock/adjust success also invalidates `products`, `pos-products`, `dashboard`.
- **Inventory table:** "Low Stock Threshold" (`item.low_stock_threshold ?? 0`), "Last Restock" (`last_restocked_at`), "Last Sold" (`last_sold_at`).
- **Movements table:** renders `reference_type` + `reference_id` as `TYPE #id`, uses `movement.username`.
- **Low-stock table:** "Low Stock Threshold", "Raised" (`raised_at`); removed Severity column / `SeverityBadge`.
- **Stock detail modal:** "Low Stock Threshold", "Last Restock", "Last Sold" mapped to the new fields.

### Permissions
No new frontend permission gates. `AuthContext.hasPermission` is a stub returning `true`; the backend `require_permission(...)` decorators remain authoritative for `INVENTORY_CREATE`/restock/adjust.

---

## 4. Verification

### End-to-end API flow (mirrors exact frontend payloads)
1. `POST /products` with `initial_quantity: 10` → `201`, `quantity_on_hand=10`.
2. `POST /inventory/restock` `{ product_id, quantity: 25 }` → `201`, `quantity_on_hand=35`.
3. `GET /products/{id}` → `quantity_on_hand=35`; `GET /inventory` → `35`, `low_stock_threshold=5`.
4. Restock with `quantity: 0` / `-1` → `422` (rejected).
5. Create with `initial_quantity: -3` → `422` (after the backend fix).

### Suite results
- Backend: `python3 -m pytest app/tests -q` → **65 passed**.
- Frontend: `tsc -b`, ESLint `--max-warnings 0`, Vitest → **52 passed**, `vite build` succeeds (chunk-size warning only).

---

## 5. Files Changed

| File | Change |
| --- | --- |
| `SmartPOS/Backend/app/api/routers/products.py` | Convert pydantic validation errors to 422 (`_parse_schema_payload`) |
| `SmartPOS/Frontend/tsconfig.json` | Removed invalid `ignoreDeprecations` |
| `SmartPOS/Frontend/src/types/models.ts` | Types aligned to backend schemas |
| `SmartPOS/Frontend/src/pages/products/ProductsPage.tsx` | Quantity field, Current Stock + Restock, RestockModal, invalidation, error handling |
| `SmartPOS/Frontend/src/pages/inventory/InventoryPage.tsx` | Payload fixes, field mapping, broader invalidation |

## 6. Notes / Out of Scope
- No database migration, no new endpoints, no UI redesign.
- Frontend chunk size > 500 kB warning is pre-existing (Vite build warning only).
- The stale `reorder_level` column exists in the DB but is unused by the backend response; the frontend no longer reads or writes it.