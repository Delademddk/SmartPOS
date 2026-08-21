# DASHBOARD DATA AUDIT — ROOT CAUSE ANALYSIS

## 1. Original Error

```
Unexpected Application Error!

Cannot read properties of undefined (reading 'toLocaleString')

TypeError: Cannot read properties of undefined (reading 'toLocaleString')
    at formatCurrency (src/utils/format.ts:2)
    at DashboardPage.tsx (SalesTrendWidget)
    at Array.map
```

## 2. Component Causing the Error

`SalesTrendWidget` in `Frontend/src/pages/admin/DashboardPage.tsx`.

The widget mapped over the response and called:

```ts
data.map((item) => formatCurrency(item.total))   // item.total was undefined
```

## 3. Exact Undefined Property

`item.total` was **undefined**.

The frontend typed the `/dashboard/sales-trend-7d` response as
`Array<{ date: string; total: number; count: number }>`, but the backend returns
a different contract (see below), so `item.total` (and `item.count`) never existed.

## 4. Actual API Response (real SQL Server)

Verified by running `DashboardService` against the live SQL Server database
(`DESKTOP-BP6RL8D`, db `SmartPOS`).

`GET /api/v1/dashboard/sales-trend-7d` data:

```json
[
  { "date": "2026-08-13", "weekday": "Thursday", "total_sales": 0.0, "sale_count": 0 },
  { "date": "2026-08-14", "weekday": "Friday",   "total_sales": 5.0, "sale_count": 1 },
  ...
  { "date": "2026-08-19", "weekday": "Wednesday","total_sales": 6.0, "sale_count": 2 }
]
```

`GET /api/v1/dashboard/top-products?days=30&limit=5` data:

```json
[
  { "product_id": 1, "product_name": "Coca-Cola 500ml", "sku": "BEV-001",
    "qty_sold": 4.0, "revenue": 20.0, "share_pct": 76.92 },
  { "product_id": 2, "product_name": "Blue Pen", "sku": "SKU-33",
    "qty_sold": 3.0, "revenue": 6.0, "share_pct": 23.08 }
]
```

`GET /api/v1/dashboard/kpis` data:

```json
{
  "today_sales_total": 6.0, "today_sales_count": 2, "today_returns_total": 0.0,
  "today_refunds": 0, "low_stock_count": 1, "out_of_stock_count": 0,
  "pending_credit_balance": 0.0, "active_users_count": 3, "total_products_active": 3
}
```

## 5. Expected Frontend Response

The frontend must consume the backend contract exactly:

| Endpoint | Backend fields | Frontend (old, wrong) |
| --- | --- | --- |
| `/dashboard/sales-trend-7d` | `date`, `weekday`, `total_sales`, `sale_count` | `date`, `total`, `count` |
| `/dashboard/top-products` | `product_id`, `product_name`, `sku`, `qty_sold`, `revenue`, `share_pct` | `product_name`, `total_qty`, `total_revenue` |
| `/dashboard/kpis` | `today_sales_total`, `today_sales_count`, `today_returns_total`, `today_refunds`, `low_stock_count`, `out_of_stock_count`, `pending_credit_balance`, `active_users_count`, `total_products_active` | `DashboardKPIs` (already correct) |

## 6. Database Query Involved

`Backend/app/services/dashboard_service.py → sales_trend_7d()`:

```sql
SELECT CAST(sale_date AS DATE) AS sale_date,
       COALESCE(SUM(total_amount), 0) AS total,
       COUNT(sale_id) AS cnt
FROM sales
WHERE status = 'COMPLETED' AND sale_date >= :start
GROUP BY CAST(sale_date AS DATE)
```

The row is then mapped to the response dict:

```python
{ "date": day.isoformat(), "weekday": day.strftime("%A"),
  "total_sales": total, "sale_count": cnt }
```

Real SQL Server data for this query (last 7 days):

```
sale_date=2026-08-14 total=5.0 cnt=1
sale_date=2026-08-19 total=6.0 cnt=2
```

## 7. Root Cause

**API contract mismatch (field-name mismatch) between the backend and the frontend
in two dashboard widgets.**

- Backend `sales_trend_7d()` correctly returns `total_sales` / `sale_count`
  (values always numeric via `COALESCE(SUM(...), 0)` / `float(...)`).
- Backend `top_products()` correctly returns `qty_sold` / `revenue`.
- The frontend used invented field names `total` / `count` and `total_qty` / `total_revenue`.
  Because `item.total` was `undefined`, `formatCurrency(undefined)` called
  `undefined.toLocaleString(...)` and threw the TypeError.

Why the crash surfaced in `SalesTrendWidget` specifically: `sales-trend-7d` always
returns a non-empty 7-row array (zero-filled days included), so `data?.length` was
truthy and the map always ran. `top-products` returned an empty array when there were
no sales in range, which short-circuited before `formatCurrency(item.total_revenue)` ran.

The backend was **not** wrong: names were consistent with the rest of the API, and
aggregates were properly `COALESCE`d to `0` (never NULL). The correct fix was to align
the frontend contract to the backend — not to rename backend fields and not to hide
the widget.

## 8. Files Changed

| File | Change |
| --- | --- |
| `SmartPOS/Frontend/src/types/models.ts` | Added `DashboardSalesTrendItem` and `DashboardTopProduct` interfaces matching the real backend response |
| `SmartPOS/Frontend/src/pages/admin/DashboardPage.tsx` | `SalesTrendWidget` now uses `item.total_sales` / `item.sale_count`; `TopProductsWidget` now uses `item.qty_sold` / `item.revenue`; both typed with the new interfaces |
| `SmartPOS/Frontend/src/utils/format.ts` | `formatCurrency` now accepts `number | null | undefined` and treats missing values as `0` (defensive safeguard, see §9) |
| `SmartPOS/Frontend/src/tests/utils/format.test.ts` | Added regression tests for `formatCurrency(null)` / `formatCurrency(undefined)` |

## 9. Corrective Action

1. **Primary fix (frontend contract alignment):** corrected the TypeScript response
   types and property references in `DashboardPage.tsx` to match the real backend
   response (`total_sales`, `sale_count`, `qty_sold`, `revenue`). No `any`, no
   weakened types; the new interfaces are non-nullable `number` fields that the
   backend guarantees.
2. **Defensive safeguard:** `formatCurrency` now safely treats `null`/`undefined`
   monetary values as `$0.00`. This is a safeguard only — the data contract is now
   correct, so the guard is not masking a bug.
3. **No redesign, no mock data, no widget hiding, no backend changes.**
   Dashboard layout, styling, loading/empty/error states were preserved.

## 10. Tests Performed

- Real SQL Server data presence check (sales, sale_items, products, inventory, users).
- Real `DashboardService` execution against SQL Server confirming exact response keys/values.
- API contract end-to-end check via the FastAPI `TestClient` (seeded SQLite harness)
  confirming `total_sales`/`sale_count` and `qty_sold`/`revenue` are returned.
- Backend test suite: `python3 -m pytest app/tests -q` → **65 passed**.
- Frontend: `tsc -b` **clean**; ESLint `--max-warnings 0` **clean**;
  Vitest **54 passed** (includes 2 new formatter regression tests);
  `vite build` **succeeds**.

## 11. Final Verification Result

- `formatCurrency` no longer receives `undefined` — the dashboard contract is aligned.
- SalesTrendWidget renders 7 real rows from SQL Server (Aug 13–19, 2026) with real totals.
- TopProductsWidget renders real top products (Coca-Cola 500ml GH₵-equivalent 20.00, Blue Pen 6.00).
- Empty days render as `0.00 / 0 sales` (backend `COALESCE`d) and empty datasets render
  the existing "No sales data yet." empty state — the app never crashes on missing data.
- The existing `ErrorBoundary` in `App.tsx` remains as the last-resort guard; the primary
  data fix removes the runtime exception under normal valid API conditions.