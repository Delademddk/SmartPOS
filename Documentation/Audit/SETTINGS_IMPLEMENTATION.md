# SmartPOS Settings Implementation

Date: 2026-08-19
Predecessor: `SETTINGS_SYSTEM_AUDIT.md` (root causes P1–P7).

This document records the changes that make the settings flow work end-to-end: UI → API → FastAPI → SQL Server → application behavior (POS, dashboard, receipts, inventory, header/sidebar).

---

## 1. Summary of Changes

| Root cause | Change | Files |
|---|---|---|
| P1 | Align the Business Info contract between frontend and backend | Backend (none needed — schema was already correct), Frontend types + Settings page |
| P2 | POS now queries the correct tax-rate endpoint and auto-selects the default tax from the `default_tax_rate_id` setting | `POSPage.tsx`, backend `PUBLIC_SETTING_KEYS` |
| P3 | App Settings data types now match the DB (`string/int/decimal/bool/json`) | `SettingsPage.tsx`, `models.ts` |
| P4 | Settings categories now match the DB (`general/tax/notifications/receipt/system`) | `SettingsPage.tsx`, `models.ts` |
| P5 | Settings are now consumed app-wide (currency, business name, default tax, low-stock default) | new `useSettings` hook, `format.ts`, `App.tsx`, `POSPage.tsx`, `Header.tsx`, `Sidebar.tsx`, `SalesPage.tsx`, backend `settings.py`, `products_service.py` |
| P6 | Receipts use the configured footer and flattened money fields | `ReceiptRead`, `SalesService.receipt_view`, `SalesPage.tsx` |
| P7 | Read-only display settings are available to every authenticated user | new `GET /settings/public`, relaxed `GET /business/info` |

---

## 2. Backend Changes

### 2.1 Receipt payload — `app/api/schemas/sales.py`
`ReceiptRead` now carries the flattened, enriched fields the frontend printer needs: `business_name`, `business_address`, `business_phone`, `business_email`, `receipt_footer`, `subtotal`, `total_amount`, `amount_received`, `change_amount`, `cashier_name`, `sale_date`. The legacy `gross_total/net_total/amount_paid/change_due` fields are retained for compatibility.

### 2.2 Receipt assembly — `app/services/sales_service.py`
New `SalesService.receipt_view(receipt_number)` builds the enriched payload:
- reads the business profile (falls back to `settings.business_name` when no profile row exists),
- reads display settings (`receipt_footer`, etc.),
- joins `address_line1` + `address_line2`,
- flattens the monetary totals from the `Receipt` row,
- returns the enriched dict.
Bug fixed during verification: the settings map is now loaded independently of the business profile, so the footer/name fallback works even when `business_information` has no row.

The sales router receipt endpoint now calls `receipt_view` instead of the raw schema serialization.

### 2.3 Public display settings — `app/api/routers/settings.py`
New endpoint `GET /settings/public` (declared **before** `GET /settings/{key}` so it is not shadowed) returns the display-only subset of settings to any authenticated user:

```
currency_symbol, business_name, receipt_footer, receipt_show_tax,
receipt_show_discount, default_tax_rate_id, timezone, low_stock_threshold_default
```

`GET /business/info` in `app/api/routers/business.py` was relaxed from `settings.view` to `get_current_user` (read-only for all; writes remain admin-only).

### 2.4 Default low-stock threshold — `app/services/products_service.py`
Product creation now reads `low_stock_threshold_default` from the settings table when the request does not explicitly send `low_stock_threshold` (detected via `model_dump(exclude_unset=True)`), falling back to `10`.

### 2.5 Business profile ⇄ settings sync — `app/services/business_service.py`
Because the business name and currency exist in two places (profile + settings), the backend keeps them consistent:
- `update_business_info` mirrors `business_name` → `settings.business_name`, and `currency_code` → `settings.currency_symbol` (looked up in `currencies`, so USD → `$`).
- `update_setting` mirrors `business_name` back to `business_information.business_name`.
Added `CurrencyRepository.get_by_code()` in `app/repositories/catalog_repo.py`.

---

## 3. Frontend Changes

### 3.1 Types — `src/types/models.ts`
- `BusinessInfo`: `business_id` → `business_info_id`; `address` → `address_line1`/`address_line2`; removed `currency_id`, `logo_url`; added `website`, `timezone`, `is_active`, `business_info_id`.
- `BusinessInfoUpdate`: matches the backend `BusinessInfoUpdate` (incl. `address_line1`, `address_line2`, `website`, `timezone`; no `logo_url`).
- New `SettingDataType` (`string|int|decimal|bool|json`) and `SettingCategory` (`general|tax|notifications|receipt|system`) unions; `SettingCreate`/`SettingUpdate` use them.
- `Receipt`: added `business_email`, `receipt_footer`.

### 3.2 Settings page — `src/pages/settings/SettingsPage.tsx`
- Business Info edit form: `address` → `address_line1`/`address_line2`, `logo_url` → `website`, added `timezone`. No field sends `address`/`logo_url`, so the backend no longer returns 422.
- App Settings: `data_type` enum is now the DB values; categories are now `general/tax/notifications/receipt/system`; boolean value editor keyed on `bool`; numeric input for `int`/`decimal`; type badges render `bool`.
- After any settings create/update/delete the `["settings"]` query (which includes the `["settings","public"]` consumers) is invalidated so the app reflects changes immediately.

### 3.3 Currency formatting — `src/utils/format.ts`
`formatCurrency(amount, symbol = activeCurrencySymbol)` now uses a module-level symbol that defaults to `$` and can be changed via `setCurrencySymbol(symbol)` (empty values fall back to `$`). Existing call sites are unchanged; the symbol is set once the app loads display settings.

### 3.4 Settings hook + bootstrap — `src/hooks/useSettings.ts`, `src/App.tsx`
`useSettings()` loads `GET /settings/public` via TanStack Query (`queryKey: ["settings","public"]`) and exposes:
- `settings` (map of key → value),
- `businessName`, `currencySymbol`, `receiptFooter`, `defaultTaxRateId`, `lowStockThresholdDefault`,
- `formatMoney(amount)` (currency-aware formatter).

A `<SettingsBootstrap/>` component in `App.tsx` calls the hook once so `setCurrencySymbol` runs for the whole app.

### 3.5 POS — `src/pages/pos/POSPage.tsx`
- Tax rates loaded from `/business/tax-rates` (was 404 on `/tax-rates`).
- Default tax: prefers the `default_tax_rate_id` setting, falls back to the `is_default` tax row — so the `default_tax_rate_id` setting now drives the POS.
- Amounts use `formatMoney` from `useSettings`.

### 3.6 Header / Sidebar — `src/components/layout/Header.tsx`, `Sidebar.tsx`
Sidebar brand replaced the hardcoded "SmartPOS" with the `business_name` setting; the Header shows the business name next to the menu toggle.

### 3.7 Receipt print — `src/pages/sales/SalesPage.tsx`
- Footer uses `receipt.receipt_footer` (fallback `Thank you!`).
- Tax line respects `receipt_show_tax`, discount line respects `receipt_show_discount`.
- Prints `business_email`.
- Amounts use the configured currency symbol (via the global `formatCurrency`).

---

## 4. Data Types & Categories (canonical values)

| Domain | Canonical values (DB) |
|---|---|
| `settings.data_type` | `string`, `int`, `decimal`, `bool`, `json` |
| `settings.category` | `general`, `tax`, `notifications`, `receipt`, `system` |

---

## 5. Conventions / Notes
- No new settings system; the existing `dbo.settings` + `dbo.business_information` are the single source of truth.
- No localStorage is used for settings.
- `GET /settings/public` is the only read channel for cashiers; it returns only display settings and never secrets.
- Environment variables continue to control only technical configuration (server, DB, auth secret) — not business settings.