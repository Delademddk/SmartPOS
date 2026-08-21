# Module 09 — Payments

**SQL source:** `Database/SQL/09_Payments/`
**Purpose:** Tender types, payments and receipt generation.

## Tables

| Table | Purpose |
|-------|---------|
| `payment_methods` | Tender types (`CASH`, `CARD`, `MOBILE`, `BANK_TRANSFER`, ...); `is_cash` marks cash. |
| `payments` | Payments against a sale (`amount`, method, status). Credit settlements update balances via `SP_RecordPayment`. |
| `receipts` | Generated receipts per sale (gross, discount, tax, net, paid, change). |

## Stored Procedures

| Procedure | Purpose |
|-----------|---------|
| `SP_GetPaymentMethods` | List tender types. |
| `SP_CreatePaymentMethod` / `SP_UpdatePaymentMethod` | Manage methods; the last active cash method cannot be deactivated. |
| `SP_GetSalePayments` / `SP_GetPayment` | List payments for a sale / fetch one. |
| `SP_RecordPayment` | Apply a payment: records `payments`, updates `sales.amount_received`, and (for credit sales) reduces the `credit_sales` balance / marks settled. |
| `SP_GetReceipt` / `SP_GetReceiptBySale` / `SP_GenerateReceipt` | Retrieve / regenerate receipts with computed change. |

## Dependencies

- Module 08 (`sales`), Module 10 (credit balance updates), Module 11 (returns refunds).
- Currency display via `FN_CurrencySymbol` / business info.

## Notes

- Multi-tender: several `payments` rows can reference one sale.
- `SP_RecordPayment` and `SP_GenerateReceipt` run in one transaction; failed payment rolls back the receipt.
- Refunds flow through `SP_ProcessReturn` (Module 11), which references payment/receipt records.
