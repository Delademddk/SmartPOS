# SmartPOS Global Currency Configuration — Verification

Date: 2026-08-19
Related: `GLOBAL_CURRENCY_AUDIT.md`, `GLOBAL_CURRENCY_IMPLEMENTATION.md`.

All checks below were executed after the implementation changes.

---

## 1. Automated Test Results

### 1.1 Backend (FastAPI + pytest)
Command: `.venv/Scripts/python.exe -m pytest` (from `SmartPOS/Backend`)

Result: **83 passed** (baseline was 76).

New/updated tests in `app/tests/api/test_settings_api.py`:
- `test_get_currency_default_is_usd` — `GET /settings/currency` returns `USD` / `$` / `en-US`.
- `test_update_currency_to_ghs_and_back` — PUT `GHS` → config + `business/info.currency_code` + mirrored settings rows all become `GHS`/`GH₵`/`en-GH`; PUT back to `USD` restores `$`/`en-US`.
- `test_update_currency_rejects_unknown_code` — `XXX` and `US` are rejected (422).
- `test_cashier_cannot_update_currency` — cashier write is 403.
- `test_currency_config_readable_by_cashier` — cashier read is 200.
- `test_business_info_update_validates_currency` — invalid code on `PUT /business/info` is 422.
- `test_currency_mirror_settings_are_managed` — direct create of `currency_code` is 422; direct edit of `currency_symbol` is 422; `currency_code` edit routes through `update_currency`.
- Updated `test_settings_update_preserves_unrelated_fields` and `test_public_settings_readable_by_cashier` to use neutral settings instead of `currency_symbol` (now a managed mirror key).

Test conftest now seeds the currency catalogue (USD/GHS/EUR/GBP/NGN).

### 1.2 Frontend (Vitest)
Command: `node node_modules/vitest/vitest.mjs run` (from `SmartPOS/Frontend`)

Result: **61 passed** (baseline 59).

`src/tests/utils/format.test.ts` covers: USD `$1,234.56`, GHS `GH₵100.00`, EUR `€100.00`, zero, negative `-$500.00`, `null`/`undefined` → `$0.00`, uppercase normalization (`ghs` → `GH₵`), empty-code fallback to USD, unsupported-code fallback to symbol concatenation (no generic `¤`).

### 1.3 Typecheck / Lint / Build
- `node node_modules/typescript/bin/tsc -b` → clean.
- `node node_modules/eslint/bin/eslint.js src` → clean (0 errors).
- `node node_modules/vite/bin/vite.js build` → production build succeeded.

---

## 2. Intl Formatting Verification (Node 22)

| Currency | Locale | `100.00` | `-500.00` |
|---|---|---|---|
| USD | en-US | `$100.00` | `-$500.00` |
| GHS | en-GH | `GH₵100.00` | `-GH₵500.00` |
| EUR | en-IE | `€100.00` | `-€100.00` |
| GBP | en-GB | `£100.00` | `-£500.00` |
| NGN | en-NG | `₦100.00` | `-₦500.00` |

Negative amounts format with the minus sign before the symbol (browser-standard `Intl` behavior).

---

## 3. End-to-End Currency Switch Matrix (expected behavior)

Administrator goes to **Settings → App Settings → Application Currency**, selects **Ghana Cedi (GHS)**:

| Layer | Expected after switching to GHS |
|---|---|
| `business_information.currency_code` | `GHS` |
| `settings.currency_symbol` | `GH₵` |
| `settings.currency_code` | `GHS` |
| `settings.currency_locale` | `en-GH` |
| `GET /settings/currency` | `{currency_code: "GHS", currency_symbol: "GH₵", currency_locale: "en-GH", decimal_places: 2}` |
| POS page totals / change | `GH₵`-formatted |
| Product prices / cost | `GH₵`-formatted |
| Dashboard KPIs | `GH₵`-formatted |
| Inventory movement unit cost | `GH₵`-formatted (no hardcoded `$`) |
| Sales list / detail / receipt print | `GH₵`-formatted |
| Credits / payments / returns / reports | `GH₵`-formatted |
| Audit log | `CURRENCY_UPDATED` activity recorded |
| Stored monetary values | Unchanged (no conversion) |

Switching back to USD restores `$` / `en-US` everywhere without a page reload (reactive subscription).

---

## 4. Boundary Checks

- Invalid / unknown currency code on either endpoint → 422, DB untouched.
- Cashier can read currency config but a write attempt → 403.
- Direct mutation of `currency_symbol` / `currency_code` / `currency_locale` via the generic settings API → 422 (mirror keys are managed).
- `formatCurrency` called before settings load or with no business profile → defaults to USD, never throws.
