# SmartPOS Database — Seed Data

Required runtime records applied by the setup scripts.

**File:** `SeedData/SeedData.sql`

| Table | Rows | Notes |
|-------|------|-------|
| `permissions` | 50 | 14 modules × view/create/update/delete + dashboard.view, reports.view |
| `roles` | 3 | `ADMIN`, `MANAGER`, `CASHIER` |
| `role_permissions` | 95 | ADMIN 50 / MANAGER 34 / CASHIER 11 |
| `users` | 3 | `admin`, `cashier`, `manager` (placeholder hashes, must_change_password=1) |
| `password_history` | 3 | seeded alongside users |
| `business_information` | 1 | SmartPOS Store |
| `currencies` | 4 | USD (base), EUR, GBP, NGN |
| `tax_rates` | 3 | NONE (default), VAT_STANDARD (7.5), VAT_ZERO |
| `categories` | 5 | Beverages, Food, Electronics, Office Supplies, Cleaning Supplies |
| `suppliers` | 3 | SUP-001..003 |
| `payment_methods` | 4 | CASH, CARD, MOBILE, BANK_TRANSFER |
| `return_reasons` | 5 | DEFECTIVE, WRONG_ITEM, etc. |
| `notification_types` | 6 | LOW_STOCK, SALE, RETURN, CREDIT, SYSTEM, SECURITY |
| `settings` | 12 | general/tax/receipt/notifications/system |

## Important Notes

- Seeded `password_hash` values are **placeholders**. The backend install
  routine should replace them (or users are forced to change password on first
  login via `must_change_password = 1`).
- All inserts are guarded with `IF NOT EXISTS` and are idempotent.
- Role-permission grants are resolved via `INSERT...SELECT` joins on
  `permission_code`, never identity values, so ordering is irrelevant.

See also `../SampleData/SampleData.sql` for optional illustrative data.