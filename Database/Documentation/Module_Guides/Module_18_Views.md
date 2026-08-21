# Module 18 — Core Operational Views

**SQL source:** `Database/SQL/Views/Core_Operational_Views.sql`
**Purpose:** Frequently-joined, reusable views over operational data.

## Views

| View | Content |
|------|---------|
| `VW_UserPermissions` | Effective permissions per active user (users × role × permissions). |
| `VW_ProductStock` | Products joined with current stock + `FN_StockStatus` classification. |
| `VW_SalesWithLines` | Denormalized sale header + lines for reporting convenience. |
| `VW_CustomerBalances` | Per-customer outstanding credit. |
| `VW_LowStock` | Products at or below `low_stock_threshold`. |

## Dependencies

- Modules 01, 02, 05, 07, 10 (data sources).
- Consumed by Modules 13 (reports) and 14 (dashboard) where applicable.

## Notes

- These views are the app-facing **read model** — the application role is
  granted `SELECT` on the `dbo` schema views and has **no** table access
  (see [`SecurityGuide.md`](../SecurityGuide.md) §3).
- `VW_LowStock` powers the low-stock panel; `VW_UserPermissions` powers
  UI permission gating and should be re-checked at the procedure boundary via `FN_HasPermission`.
