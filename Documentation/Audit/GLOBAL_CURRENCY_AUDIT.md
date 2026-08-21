# SmartPOS Global Currency Configuration — Audit

Audit date: 2026-08-19
Scope: End-to-end application currency flow (business profile → settings API → FastAPI → SQL Server → frontend formatter → every money display across the application).

---

## 1. Architecture Overview

The application currency is represented in three related places:

| Storage | Table | Role |
|---|---|---|
| Business profile | `dbo.business_information.currency_code` | **Authoritative** — canonical value (default `USD`) |
| Currency catalogue | `dbo.currencies` | Supported codes, names, symbols, decimal places |
| Application settings | `dbo.settings` | Display mirrors: `currency_symbol`, `currency_code`, `currency_locale` |

The settings table values are **mirrors only**. They are derived from `business_information.currency_code` + `currencies` + the centralized locale map and are kept in sync by the backend. They are not a second source of truth.

| Layer | Piece | Purpose |
|---|---|---|
| Backend config | `app/core/currency.py` | Centralized `CURRENCY_LOCALES` map, defaults, `locale_for_currency()` |
| Backend service | `BusinessService.get_currency_config() / update_currency()` | Read/set the authoritative currency, mirror settings, audit |
| Backend API | `GET/PUT /settings/currency` | Dedicated currency endpoints |
| Database | SeedData + Migration 003 | GHS currency, `currency_code`/`currency_locale` settings rows |
| Frontend store | `format.ts` | `setCurrencyConfig` / `getCurrencyConfig` / `subscribeCurrency` + canonical `formatCurrency` |
| Frontend hook | `useCurrency` | Reactive subscription (re-renders on currency change) |
| Frontend settings | `useSettings` | Loads `/settings/currency`, exposes `currency`/`currencyCode`/`currencySymbol`/`currencyLocale`/`formatMoney` |

---

## 2. Currency Catalogue

Seeded currencies (verified in DB and SQL seed):

| Code | Name | Symbol | Locale | Base |
|---|---|---|---|---|
| USD | US Dollar | `$` | en-US | yes |
| GHS | Ghana Cedi | `GH₵` | en-GH | no |
| EUR | Euro | `€` | en-IE | no |
| GBP | British Pound | `£` | en-GB | no |
| NGN | Nigerian Naira | `₦` | en-NG | no |

GHS was **missing** before this feature (root cause R1).

---

## 3. Root Causes Discovered

### R1 — GHS not present in the currency catalogue
The `currencies` table only contained USD/EUR/GBP/NGN, so switching to Ghana Cedi was impossible.

### R2 — No dedicated, validated currency endpoint
`currency_code` could only be changed via the free-text "Currency Code" field on the Business Info tab, which accepted any string with no validation against the catalogue and no permission check specific to currency.

### R3 — Settings mirrors were mutable and duplicated
`settings.currency_symbol` existed as a display setting but could be created/edited/deleted directly via the generic settings API, allowing it to drift from `business_information.currency_code`. Only `currency_symbol` was mirrored — `currency_code` and `currency_locale` were not.

### R4 — No locale information exposed
`GET /settings/public` returned only `currency_symbol`. The frontend had to guess the locale, making reliable `Intl.NumberFormat` formatting (grouping, symbol placement, negative format) impossible.

### R5 — Frontend formatter was a static module variable
`format.ts` used `setCurrencySymbol()` + a module-level `activeCurrencySymbol`; components only re-formatted when they happened to re-render, and there was no subscription mechanism.

### R6 — Hardcoded currency in one page
`InventoryPage.tsx` had hardcoded `$` in the movement unit-cost column and the restock form label (`Unit Cost ($)`).

---

## 4. Data & Behavior Verification

- Intl output verified in Node 22 for every supported code (e.g. `GHS` + `en-GH` → `GH₵100.00`; `USD` + `en-US` → `$100.00`; negative amounts render as `-$500.00`).
- Backend settings API tests: 83 backend tests pass (16 settings/currency-related tests).
- Frontend tests: 61 pass (format tests cover USD/GHS/EUR, negative amounts, null/undefined safety, unsupported-code fallback).
- `tsc -b`, ESLint, and `vite build` all pass.

---

## 5. Boundary / Non-Goals

- No exchange-rate conversion and no stored monetary value is ever modified when the currency changes.
- No localStorage persistence — the currency always comes from the backend.
- No duplicate settings system — the existing `settings` table is reused and its currency rows are now managed/single-source.
- No UI redesign — a dedicated currency control is added to the existing App Settings tab.
