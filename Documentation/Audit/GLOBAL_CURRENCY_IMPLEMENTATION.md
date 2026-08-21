# SmartPOS Global Currency Configuration — Implementation

Date: 2026-08-19
Predecessor: `GLOBAL_CURRENCY_AUDIT.md` (root causes R1–R6).

This document records the changes that make the application currency globally configurable and applied end-to-end: Settings UI → API → FastAPI → SQL Server → frontend store → every money display (POS, dashboard, products, inventory, sales, credits, payments, returns, reports, receipts).

---

## 1. Summary of Changes

| Root cause | Change | Files |
|---|---|---|
| R1 | Added GHS to the currency catalogue (seed + migration) | `SeedData.sql`, `Migration/003_...sql` |
| R2 | Dedicated validated currency endpoints with permission check | `routers/settings.py`, `business_service.py`, `schemas/settings.py` |
| R3 | Currency settings rows are now managed (create/delete blocked, symbol/locale edits rejected, code edits routed) | `business_service.py` |
| R4 | `currency_code` + `currency_locale` exposed via public settings; locale exposed in currency config | `routers/settings.py`, `business_service.py` |
| R5 | Reactive currency store + canonical `Intl`-based formatter + `useCurrency` subscription hook | `format.ts`, `useCurrency.ts`, `useSettings.ts` |
| R6 | Removed hardcoded `$` in inventory movements and restock form | `InventoryPage.tsx` |

---

## 2. Backend Changes

### 2.1 Centralized currency configuration — `app/core/currency.py` (new)

Single source for the locale mapping and defaults:

```
CURRENCY_LOCALES = {"USD": "en-US", "GHS": "en-GH", "EUR": "en-IE", "GBP": "en-GB", "NGN": "en-NG"}
DEFAULT_CURRENCY_CODE = "USD"
DEFAULT_CURRENCY_SYMBOL = "$"
DEFAULT_CURRENCY_LOCALE = "en-US"
DEFAULT_CURRENCY_DECIMAL_PLACES = 2
locale_for_currency(code) -> str
```

### 2.2 Currency service methods — `app/services/business_service.py`

- `get_currency_config()` — returns `{currency_code, currency_symbol, currency_locale, decimal_places}`. Reads the authoritative `business_information.currency_code`, looks up the `currencies` row, derives the locale; falls back to USD defaults if no profile/currency exists.
- `_ensure_currency(code)` — validates a 3-letter code against the active catalogue, raises `ValidationError` (422) otherwise.
- `update_currency(code, actor)` — writes `business_information.currency_code`, mirrors the settings rows, records a `CURRENCY_UPDATED` audit activity, commits, returns the new config.
- `_sync_currency_settings(currency, actor)` — upserts `currency_symbol`, `currency_code`, `currency_locale` into `dbo.settings` with `currency_symbol`/`currency_code`/`currency_locale` descriptions.
- `update_business_info` now validates `currency_code` through `_ensure_currency` and mirrors it via `_sync_currency_settings` (replacing the old symbol-only mirror).

### 2.3 Managed settings rows (single source of truth)

`_CURRENCY_MIRROR_KEYS = {"currency_symbol", "currency_code", "currency_locale"}`:

- `create_setting` → rejects (422) any of the mirror keys.
- `delete_setting` → rejects (422) any of the mirror keys.
- `update_setting` → routes `currency_code` edits through `update_currency`; rejects direct `currency_symbol` / `currency_locale` edits.

### 2.4 API — `app/api/routers/settings.py`

- `GET /settings/currency` — any authenticated user; returns the currency config.
- `PUT /settings/currency` — requires `SETTINGS_UPDATE` (admin); body `CurrencyUpdate{currency_code}`.
- Both declared **before** `GET/PUT /settings/{key}` so they are not shadowed.
- `PUBLIC_SETTING_KEYS` now includes `currency_code` and `currency_locale` so `/settings/public` exposes the full mirror set to every authenticated user.

### 2.5 Schema — `app/api/schemas/settings.py`

`CurrencyUpdate(currency_code: str)` with a `min_length=3, max_length=3` validation.

### 2.6 Database

- `SeedData.sql`: added GHS to the `currencies` seed (idempotent) and the `currency_code` (`USD`) / `currency_locale` (`en-US`) settings rows; seed counts updated (5 currencies, 14 settings).
- `Database/SQL/Migrations/003_add_ghs_currency_and_currency_settings.sql` (new, idempotent): inserts GHS and the two settings rows if missing.

---

## 3. Frontend Changes

### 3.1 Canonical formatter + reactive store — `src/utils/format.ts`

- `CurrencyConfig { code, symbol, locale, decimalPlaces }`.
- `setCurrencyConfig(config)` / `getCurrencyConfig()` / `subscribeCurrency(listener)` — module-level store with subscriber notification.
- `formatCurrencyWithConfig(amount, config)` — the single canonical currency-formatting routine; uses `Intl.NumberFormat(locale, { style: "currency", currency: code, min/max fraction digits })`; falls back to `${symbol}${amount}` for unsupported codes or Intl failures; never throws on `null`/`undefined`.
- `formatCurrency(amount)` — formats with the active config.
- Unsupported codes are guarded by a `SUPPORTED_CURRENCY_CODES` set so an invalid code can never render a generic `¤` symbol.

### 3.2 Reactive hook — `src/hooks/useCurrency.ts` (new)

`useCurrency()` returns the active config via `useSyncExternalStore(subscribeCurrency, getCurrencyConfig)`, re-rendering the component whenever the currency changes.

### 3.3 Settings hook — `src/hooks/useSettings.ts`

- Loads `GET /settings/currency` alongside `GET /settings/public`.
- Exposes `currency`, `currencyCode`, `currencySymbol`, `currencyLocale` and a deterministic `formatMoney` (formats directly from the query-derived config, not module state).
- Syncing effect calls `setCurrencyConfig(...)` so every existing `formatCurrency()` call site reflects the configured currency.

### 3.4 App Settings currency control — `src/pages/settings/SettingsPage.tsx`

New `CurrencySettingsCard` at the top of the App Settings tab:
- Lists active currencies from `GET /business/currencies`.
- Shows current code, symbol, and a live formatted preview (`Intl`-based).
- Saving calls `PUT /settings/currency` and invalidates `["settings"]` and `["business-info"]` so POS/dashboard/header re-render with the new currency.

### 3.5 Reactive subscriptions on money pages

`useCurrency()` added to every component that renders money: Dashboard, Products (+ Price modal), Sales (list + sale detail + void/receipt), Credits, Payments, Returns (list + create + detail), Reports, Inventory.

### 3.6 Hardcoded currency removed — `src/pages/inventory/InventoryPage.tsx`

Movement unit-cost column now uses `formatCurrency(movement.unit_cost)`; the restock form label uses the active symbol (`Unit Cost (GH₵)` when configured).

---

## 4. Tests

- Backend (`app/tests/api/test_settings_api.py`): updated `currency_symbol`-based tests to neutral settings; new tests for GET/PUT `/settings/currency` (default USD, GHS switch and back, invalid codes 422, cashier read OK / write 403, business-info currency validation, mirror keys managed + `currency_code` route-through).
- Backend conftest seeds the currency catalogue so validation flows work.
- Frontend `src/tests/utils/format.test.ts`: rewritten for `formatCurrencyWithConfig` / `setCurrencyConfig` (USD/GHS/EUR, negative `-$500.00`, null/undefined safety, uppercase normalization, empty/unsupported code fallback, invalid-code fallback).
