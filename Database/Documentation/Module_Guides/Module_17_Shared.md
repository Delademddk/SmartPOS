# Module 17 — Shared Functions

**SQL source:** `Database/SQL/17_Shared/functions.sql`
**Purpose:** Reusable scalar functions used across procedures, views and reports.

## Functions

| Function | Purpose |
|----------|---------|
| `FN_SmartPOS_Setting` | Read a system setting with a fallback default (`dbo.settings`). |
| `FN_StockStatus` | Classify a quantity: `IN_STOCK` / `LOW_STOCK` / `OUT_OF_STOCK`. |
| `FN_HasPermission` | SQL-side RBAC guard: does `user_id` have `permission_code` via their role? |
| `FN_HashToken` | SHA2-256 hash for session/reset tokens stored at rest. |
| `FN_CalculateLineTotal` | `(unit_price × qty) × (1 − discount_rate)` with clamping. |
| `FN_GetUserDisplayName` | NULL-safe `display_name` for a user. |
| `FN_CurrencySymbol` | Configured currency symbol (default `$`). |

## Dependencies

- Module 01 (permissions), Module 02 (users), Module 03/15 (settings/currency).
- Consumed by Modules 05, 07, 08, 13, 14.

## Notes

- Functions are deterministic where possible so the optimizer can use them in indexed predicates.
- `FN_HashToken` is used by `user_sessions` and `password_resets` — tokens are never stored plaintext.
- `FN_HasPermission` is the enforcement point behind security checks in procedures (see [`SecurityGuide.md`](../SecurityGuide.md) §3.3).
