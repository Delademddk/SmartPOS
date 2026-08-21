# SmartPOS Settings Verification

Date: 2026-08-19
Related: `SETTINGS_SYSTEM_AUDIT.md`, `SETTINGS_IMPLEMENTATION.md`.

All checks below were executed after the implementation changes.

---

## 1. Automated Test Results

### 1.1 Backend (FastAPI + pytest)
Command: `.venv/Scripts/python.exe -m pytest app/tests -q`

Result: **76 passed** (baseline was 65; +9 new settings API tests +2 receipt-view unit tests).

New tests in `app/tests/api/test_settings_api.py`:
- `test_settings_create_update_read_persist` — create → update → read round-trip.
- `test_settings_update_preserves_unrelated_fields` — updating one setting leaves others intact.
- `test_settings_reject_invalid_data_type` — `number` is rejected (422).
- `test_settings_accept_db_data_types` — `int`, `decimal`, `bool` accepted.
- `test_public_settings_readable_by_cashier` — cashier can read display settings but not system settings.
- `test_public_settings_require_auth` — 401 without token.
- `test_cashier_cannot_write_settings` — 403 for writes.
- `test_business_info_update_contract` — PUT with the exact frontend contract succeeds; `address`/`logo_url` are rejected (422).
- `test_business_info_readable_by_cashier` — cashier can read the business profile.

New tests in `app/tests/unit/test_sales_service.py`:
- `test_receipt_view_enriches_business_and_settings` — receipt carries business identity, footer, flattened totals.
- `test_receipt_view_falls_back_to_settings_when_no_profile` — footer/name fallback works with no business profile row.

### 1.2 Frontend (Vitest)
Command: `npm run test`
Result: **59 passed** (baseline 56; +3 `setCurrencySymbol` tests in `format.test.ts`).

### 1.3 Typecheck / Lint / Build
- `npx tsc -b` → clean.
- `npm run lint` → clean (0 errors, 0 warnings).
- `npm run build` → production build succeeded.

---

## 2. Live Database Verification (SQL Server `SmartPOS`)

Connection: `ODBC Driver 18 for SQL Server` / `DESKTOP-BP6RL8D` (read-only + rolled-back transaction).

### 2.1 `dbo.settings` matches the audit inventory (12 rows)

```
business_name            = 'SmartPOS Store'   (string,  general)
currency_symbol          = '$'                (string,  general)
timezone                 = 'UTC'              (string,  general)
receipt_footer           = 'Thank you for your business!' (string, general)
default_tax_rate_id      = '2'                (int,     tax)
low_stock_threshold_default = '10'            (int,     notifications)
low_stock_notification_enabled = 'true'       (bool,    notifications)
receipt_show_tax         = 'true'             (bool,    receipt)
receipt_show_discount    = 'true'             (bool,    receipt)
session_timeout_minutes  = '60'               (int,     system)
lockout_threshold        = '5'                (int,     system)
password_history_count   = '5'                (int,     system)
```

### 2.2 `dbo.business_information`
```
business_info_id = 1, business_name = 'SmartPOS Store', currency_code = 'USD',
timezone = 'UTC', website = 'https://www.smartpos.local'
```

### 2.3 `dbo.currencies`
`USD` symbol is `$`, matching `settings.currency_symbol = '$'` — the profile ⇄ settings sync keeps these consistent.

### 2.4 Sync behavior (rolled-back transaction)
Simulating the backend `update_business_info` (update `business_information.business_name` + mirror to `settings.business_name`) was applied, verified, and rolled back — confirming both sources stay in sync and the round-trip is non-destructive.

---

## 3. End-to-End Behavior Checks (mapping to the audit's root causes)

| Check | Before | After |
|---|---|---|
| Save Business Info with address | 422 → "Failed to update business info" | Field names match the backend; PUT succeeds and persists |
| POS tax selector | Empty (404 on `/tax-rates`) | Loads `/business/tax-rates`; default tax auto-selected from `default_tax_rate_id` |
| Save numeric/bool setting | 422 (`number`/`boolean` not valid) | `int`/`decimal`/`bool` accepted and persisted |
| Settings categories | `appearance`/`integrations` empty; `tax`/`system` hidden | All DB categories visible and editable |
| Currency symbol | Hardcoded `$` | Loaded from `currency_symbol` into `formatCurrency` app-wide (POS, dashboard, receipts, etc.) |
| Business name | Sidebar hardcoded "SmartPOS" | Header + sidebar show `business_name` setting |
| Receipt footer | Hardcoded "Thank you!" | Prints `receipt_footer`; business email shown; `receipt_show_tax`/`receipt_show_discount` honoured |
| Cashier access | 403 on settings/business reads | Cashier can read `/settings/public` + `/business/info`; writes still 403 |
| New product low-stock default | Hardcoded 10 | Uses `low_stock_threshold_default` when not explicitly set |

---

## 4. Residual Notes
- The POS default tax respects the `default_tax_rate_id` setting first, then the `is_default` flag on `tax_rates` — two sources that the backend keeps aligned via the seed.
- Full HTTP smoke testing against a running instance was not possible from this shell (WSL cannot reach the Windows-hosted server on `127.0.0.1`); the API logic is covered by the 76 backend tests, and the running server on port 8000 must be restarted to pick up the new endpoints.