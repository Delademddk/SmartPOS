# Module 03 — Business Configuration

**SQL source:** `Database/SQL/03_Business/`
**Purpose:** Company profile, currencies and tax configuration used on receipts and reports.

## Tables

| Table | Purpose |
|-------|---------|
| `business_information` | Single-row company profile (name, tax id, address, currency, timezone). |
| `currencies` | Supported currencies; exactly one is `is_base`. |
| `tax_rates` | Configurable rates (`rate_percent`, e.g. `7.5000` = 7.5%); one may be `is_default`. |

## Stored Procedures

| Procedure | Purpose |
|-----------|---------|
| `SP_GetBusinessInformation` | Fetch the company profile. |
| `SP_UpsertBusinessInformation` | Create or update the single profile row. |
| `SP_GetCurrencies` | List currencies. |
| `SP_CreateCurrency` / `SP_UpdateCurrency` | Manage currencies. |
| `SP_SetBaseCurrency` | Mark one currency as base (unset the previous base). |
| `SP_GetTaxRates` | List tax rates (active by default). |
| `SP_CreateTaxRate` / `SP_UpdateTaxRate` / `SP_DeactivateTaxRate` | Manage tax rates; guard the default rate. |

## Dependencies

- Referenced by Module 08 (`sales.tax_rate_id`) and Module 05 (`products` price display).
- `FN_CurrencySymbol` / `FN_SmartPOS_Setting` read currency display configuration.

## Notes

- Deactivating a tax rate is a soft flag; historical sales keep their rate snapshot.
- `SP_SetBaseCurrency` and `SP_DeactivateTaxRate` are transactional (unset-then-set within a transaction).
