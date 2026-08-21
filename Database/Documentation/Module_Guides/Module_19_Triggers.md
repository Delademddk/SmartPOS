# Module 19 — Triggers

**SQL source:** `Database/SQL/Triggers/All_Triggers.sql`
**Purpose:** Automated audit, stock alerts and retention enforcement.

## Triggers

| Trigger | On (event) | Purpose |
|---------|-----------|---------|
| `TRG_products_audit` | `products` INSERT/UPDATE/DELETE | JSON audit snapshots (incl. `SOFT_DELETE`). |
| `TRG_categories_audit` | `categories` INSERT/UPDATE/DELETE | JSON audit snapshots. |
| `TRG_suppliers_audit` | `suppliers` INSERT/UPDATE/DELETE | JSON audit snapshots. |
| `TRG_users_audit` | `users` INSERT/UPDATE/DELETE | JSON audit snapshots — **never includes `password_hash`**. |
| `TRG_settings_audit` | `settings` INSERT/UPDATE/DELETE | JSON audit snapshots. |
| `TRG_inventory_low_stock` | `inventory` UPDATE | Raises `low_stock_alerts` when stock crosses the threshold; resolves when restocked; notifies ADMIN/MANAGER (Module 12). |
| `TRG_password_history_retention` | `password_history` INSERT | Keeps at most 5 history rows per user. |

## Dependencies

- Modules 02, 04, 05, 06, 07, 12, 15, 16 (data + notifications + audit).

## Notes

- **Security rule:** the `users` audit trigger excludes `password_hash` and
  token columns from the JSON snapshots to prevent secret leakage into
  `audit_logs`.
- Triggers leave `user_id` NULL in audit rows; the **application must record
  the actor** by writing the explicit audit/activity row (procedures pass the
  acting `@UserId` into the audit calls).
- Trigger behavior is verified by the test suite; if a business rule is
  refactored, update both the trigger and the matching test.
