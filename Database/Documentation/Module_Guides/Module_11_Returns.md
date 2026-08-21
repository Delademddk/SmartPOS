# Module 11 — Returns

**SQL source:** `Database/SQL/11_Returns/`
**Purpose:** Returns and refunds against original sales.

## Tables

| Table | Purpose |
|-------|---------|
| `return_reasons` | Canned reasons (DEFECTIVE, WRONG_ITEM, ...). |
| `returns` | Header: original sale, customer, processor, reason, refund total, `status` (`PENDING`/`COMPLETED`/`REJECTED`). |
| `return_items` | Lines referencing the original `sale_items`, with `unit_price` / `refund_amount` snapshots. |

## Stored Procedures

| Procedure | Purpose |
|-----------|---------|
| `SP_ProcessReturn` | **Atomic** return: creates the header + lines, validates against the original sale items (cannot return more than sold minus already returned), restores stock (`RETURN` movements), records the refund payment/receipt, and marks affected lines `is_returned`. Accepts lines as JSON parsed with `OPENJSON`. |

## Dependencies

- Module 08 (`sales` / `sale_items`), Module 09 (`payments`/`receipts`), Module 10 (credit customers).
- `return_reasons` optional on the header.

## Notes

- Over-return protection is enforced inside the transaction using `returned_qty` on `sale_items`.
- The refund amount uses the original line snapshot — later price changes never affect refunds.
- A rejected/voided return rolls back stock changes with the rest of the transaction.
