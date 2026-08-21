# SmartPOS Settings System Audit

Audit date: 2026-08-19
Scope: End-to-end settings flow (UI → API → FastAPI → SQL Server → application configuration → frontend → actual behavior).

---

## 1. Architecture Overview

SmartPOS stores configuration in three related but distinct places:

| Storage | Table(s) | Purpose |
|---|---|---|
| Business profile | `dbo.business_information` (single row) | Business name, legal name, tax id, addresses, contact details, `currency_code`, `timezone` |
| Currency catalogue | `dbo.currencies` | Currency codes, names, symbols, decimal places |
| Tax configuration | `dbo.tax_rates` | Tax rates, default flag, active flag |
| Application settings | `dbo.settings` (key-value) | `currency_symbol`, `business_name`, `timezone`, `receipt_footer`, `default_tax_rate_id`, `low_stock_threshold_default`, `low_stock_notification_enabled`, `receipt_show_tax`, `receipt_show_discount`, `session_timeout_minutes`, `lockout_threshold`, `password_history_count` |
| Per-user settings | `dbo.user_settings` | (not surfaced in the UI) |

The Settings page has three tabs, each backed by a different API:

| Tab | Endpoint | Backed by |
|---|---|---|
| Business Info | `GET/PUT /business/info` | `business_information` |
| Tax Rates | `GET/POST/PUT/DELETE /business/tax-rates` | `tax_rates` |
| App Settings | `GET/POST/PUT/DELETE /settings` | `settings` |

All endpoints sit behind JWT auth. Writes require `settings.create/update/delete` permissions (admin-only). The route `/settings` is guarded in the frontend by `ProtectedRoute allowedRoles={[ADMIN]}`.

---

## 2. Settings Inventory

### 2.1 Seeded `dbo.settings` rows (verified live on 2026-08-19)

| Setting | Seed Value | data_type | category | Intended use |
|---|---|---|---|---|
| `currency_symbol` | `$` | string | general | Symbol displayed next to amounts across UI and receipts |
| `business_name` | `SmartPOS Store` | string | general | Display name of the business |
| `timezone` | `UTC` | string | general | Timezone used for timestamps and reports |
| `receipt_footer` | `Thank you for your business!` | string | general | Text printed at the bottom of every receipt |
| `default_tax_rate_id` | `2` (VAT_STANDARD) | int | tax | Default tax rate applied to new sales |
| `low_stock_threshold_default` | `10` | int | notifications | Default low-stock threshold for newly created products |
| `low_stock_notification_enabled` | `true` | bool | notifications | Master switch for low-stock alert notifications |
| `receipt_show_tax` | `true` | bool | receipt | Show tax breakdown on receipts |
| `receipt_show_discount` | `true` | bool | receipt | Show discount lines on receipts |
| `session_timeout_minutes` | `60` | int | system | Idle session timeout in minutes |
| `lockout_threshold` | `5` | int | system | Failed login attempts before account lockout |
| `password_history_count` | `5` | int | system | Password hashes retained to prevent reuse |

### 2.2 Business information fields exposed by the API

`GET /business/info` returns `business_info_id, business_name, legal_name, tax_id, address_line1, address_line2, city, state, postal_code, country, phone, email, website, currency_code, timezone, is_active, updated_at`.

### 2.3 Settings exposed by the frontend

Business Info tab fields: `business_name, legal_name, tax_id, email, phone, address, city, state, postal_code, country, currency_code, logo_url`.
App Settings categories: `general, appearance, receipt, notifications, integrations`.

---

## 3. Problems Discovered

### P1 — Frontend/backend contract mismatch on Business Info (BLOCKING)

The frontend `BusinessInfo` type and the edit form use fields that the backend does not have, and the backend exposes fields the frontend does not know about.

| Frontend expects | Backend provides | Result |
|---|---|---|
| `business_id` | `business_info_id` | Always `undefined` |
| `address` | `address_line1`, `address_line2` | Always `undefined`; form resets it as `undefined` |
| `currency_id` | `currency_code` | Always `undefined` |
| `logo_url` | *(no column exists)* | Always `undefined` |
| — (missing) | `website`, `timezone`, `is_active` | Never shown/edited |

**Consequence:** when a user types a value into the `address` field, the `PUT /business/info` payload contains `address`, which the backend Pydantic schema (`extra="forbid"`) rejects with HTTP 422. The business info update therefore **fails whenever an address is entered** (`SettingsPage` shows "Failed to update business info"). `logo_url` is silently dropped when it is empty, and has no storage at all when set.

### P2 — POS cannot load tax rates (BLOCKING)

`POSPage` requests `GET /tax-rates?page=1&page_size=200` but no such router exists — the router is mounted at `/business/tax-rates`. The tax-rate query always 404s, so:

- the POS tax selector is always empty ("No tax" only),
- no tax is ever applied in the POS cart,
- the default tax rate is never auto-selected.

This is the concrete reason the **tax setting does not affect the POS**.

### P3 — App Settings data_type enum mismatch (BLOCKING for numeric/bool settings)

The frontend `settingSchema` restricts `data_type` to `string | number | boolean | json`. The backend `SettingCreate`/`SettingUpdate` Pydantic schemas (and the SQL check constraint `CK_settings_data_type`) only accept `string | int | decimal | bool | json`. Any attempt to create/update a setting with `data_type = number` or `boolean` returns HTTP 422. Numeric and boolean application settings **cannot be saved**.

### P4 — Settings categories do not match the database

Frontend categories `general, appearance, receipt, notifications, integrations` vs. database categories `general, tax, notifications, receipt, system`. The "App Settings" tab shows two empty categories (`appearance`, `integrations`) and hides four real categories (`tax`, `system`). Seeded settings such as `default_tax_rate_id`, `session_timeout_minutes`, `lockout_threshold`, `password_history_count` are invisible/uneditable.

### P5 — Settings are never consumed by the application (the core complaint)

No part of the frontend reads `currency_symbol`, `business_name`, `receipt_footer`, or `default_tax_rate_id` outside the Settings page itself:

- `formatCurrency()` hardcodes `$` (`Frontend/src/utils/format.ts`). Currency changes have no effect anywhere (POS, dashboard, sales, credits, returns, payments, reports, products).
- The header/sidebar do not display the business name; the sidebar hardcodes "SmartPOS".
- The receipt print in `SalesPage` uses `receipt.business_name`, `receipt.business_address`, `receipt.business_phone`, `receipt.subtotal`, `receipt.total_amount`, `receipt.amount_received`, `receipt.change_amount`, `receipt.cashier_name`, `receipt.sale_date` — none of which exist in the backend `ReceiptRead` schema (which returns `gross_total`, `net_total`, `amount_paid`, `change_due`, and a nested `sale`). The printed receipt shows blanks for business identity and totals.
- `low_stock_threshold_default` is never read; product creation hardcodes a default of 10.
- `default_tax_rate_id` is never read; the POS relies only on the `is_default` flag on `tax_rates`.

### P6 — Receipt print has no footer / business identity

The print template hardcodes `Thank you!` instead of using the `receipt_footer` setting, and has no business identity because of P5.

### P7 — Authorization gap for cashiers

`GET /business/info` and `GET /settings` require `settings.view`. Cashiers (the primary POS users) cannot read the settings needed to render currency, business name, or receipt footer. The application needs a read-only, authenticated-any-user channel for the subset of settings used for display.

---

## 4. Root Causes

1. **Broken API contracts** (P1, P3): frontend field names/types do not match the backend schemas, which reject extra fields (`extra="forbid"`).
2. **Wrong API endpoint** (P2): POS queries `/tax-rates` instead of `/business/tax-rates`.
3. **Category enumeration drift** (P4): the frontend hardcodes categories that no longer match the seeded database values.
4. **No settings consumption layer** (P5, P6): the frontend has no central place that loads settings and propagates them; currency formatting is hardcoded; receipt printing reads fields the API never returns.
5. **Over-restrictive read authorization** (P7): display settings are locked behind admin-only permissions, so cashier-facing screens cannot fetch them.

---

## 5. What Is NOT Broken

- Backend `GET /settings`, `PUT /settings/{key}`, `POST /settings`, `DELETE /settings/{key}` persist correctly to SQL Server (verified live — see `SETTINGS_VERIFICATION.md`).
- Backend `PUT /business/info`, tax-rate CRUD, and their transactions/audit logs work (they fail only because the frontend sends extra fields).
- Tax calculation on the backend (`SalesService._compute_tax`) correctly uses the tax rate from the database when a valid `tax_rate_id` is supplied.
- Low-stock classification consistently uses the per-product `low_stock_threshold` across dashboard, inventory, POS and reports.