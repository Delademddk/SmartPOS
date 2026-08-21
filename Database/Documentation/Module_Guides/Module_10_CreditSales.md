# Module 10 — Credit Sales

**SQL source:** `Database/SQL/10_CreditSales/`
**Purpose:** Customer credit ledger for "buy now, pay later" sales.

## Tables

| Table | Purpose |
|-------|---------|
| `customers` | Credit customers (unique `customer_code`, credit limit). Soft-deletable. |
| `credit_sales` | Per-sale ledger: `total_amount`, `amount_paid`, `outstanding_balance`, `due_date`, `status` (`OPEN`/`PARTIAL`/`SETTLED`/`OVERDUE`/`WRITTEN_OFF`). Unique on `sale_id`. |
| `credit_payments` | Payments applied against a credit balance, optionally linked to a `payments` row. |

## Stored Procedures

> **This module ships tables only — there is no `SP_*.sql` file in
> `Database/SQL/10_CreditSales/`.** Credit creation and settlement are
> handled by procedures in adjacent modules:

| Flow | Procedure |
|------|-----------|
| Open a credit sale (sale type `CREDIT`/`CREDIT_PARTIAL`) | `SP_CreateSale` (Module 08) — creates the `credit_sales` row with initial balance |
| Record a payment against the balance | `SP_RecordPayment` (Module 09) — updates `amount_paid` / `outstanding_balance` / `status` and writes `credit_payments` |

## Dependencies

- Module 08 (`sales`), Module 09 (`payments`).
- `VW_CustomerBalances` (Module 18) and `VW_OutstandingCredit` (Module 14) surface outstanding balances.

## Notes

- `outstanding_balance` is derived and kept consistent by the procedures inside a single transaction.
- Credit limits are checked at sale time (`SP_CreateSale`) using the customer's open balance.
- A customer with an overdue balance cannot be hard-deleted (soft delete only).
