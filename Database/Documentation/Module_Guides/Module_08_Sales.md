# Module 08 — Sales

**SQL source:** `Database/SQL/08_Sales/`
**Purpose:** Point-of-sale transaction header and lines.

## Tables

| Table | Purpose |
|-------|---------|
| `sales` | Header: unique `receipt_number`; cashier (`user_id`); `tax_rate_id`; `sale_type` (`CASH`/`CREDIT`/`CREDIT_PARTIAL`); subtotal/discount/tax/total; `amount_received`; `status` (`COMPLETED`/`VOIDED`/`REFUNDED`). |
| `sale_items` | Lines: product snapshot (`unit_price`, `discount_rate`, `tax_amount`, `line_total`), `returned_qty`, `is_returned`. |

## Stored Procedures

| Procedure | Purpose |
|-----------|---------|
| `SP_CreateSale` | **Single atomic transaction** creating header + lines, validating stock, decrementing inventory (movements), applying tax, optionally opening a credit balance, recording a payment, and generating a receipt. Accepts line items as JSON parsed with `OPENJSON`. |

## Dependencies

- Modules 01–07 (users, tax rates, products, inventory, customers, payment methods).
- Module 09 (payments/receipts), Module 10 (credit), Module 11 (returns reference the header/lines).

## Notes

- Line totals via `FN_CalculateLineTotal`; grand total via `FN_SmartPOS_Setting` for rounding config where used.
- `SALE` stock movements are written inside the same transaction — a failed line rolls the whole sale back.
- `VOIDED` sales keep their rows for the audit trail; status is updated, never deleted.
