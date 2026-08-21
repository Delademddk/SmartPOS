# Module 07 — Inventory

**SQL source:** `Database/SQL/07_Inventory/`
**Purpose:** Current stock, movements journal and physical reconciliation.

## Tables

| Table | Purpose |
|-------|---------|
| `inventory` | Current snapshot per product (`quantity_on_hand`, `quantity_reserved`, `reorder_level`); unique on `product_id`; non-negative enforced. |
| `inventory_transactions` | Append-only journal. `movement_type` in `SALE`/`RESTOCK`/`RETURN`/`ADJUSTMENT`/`VOID`/`TRANSFER`; signed `quantity`; before/after snapshots. |
| `stock_reconciliations` | Physical count adjustments linked to the resulting `inventory_transactions` row. |
| `low_stock_alerts` | Open/resolved/dismissed alerts raised by `TRG_inventory_low_stock`. |

## Stored Procedures

| Procedure | Purpose |
|-----------|---------|
| `SP_RestockProduct` | Add stock (purchase/transfer-in); writes a `RESTOCK` movement and updates `inventory`. |
| `SP_AdjustStock` | Correct stock (damage/theft/expiry/correction); writes an `ADJUSTMENT` movement (and `stock_reconciliations` where applicable). |
| `SP_GetStockLevel` | Return current quantity + status via `FN_StockStatus`. |

## Dependencies

- Module 05 (`products`).
- `TRG_inventory_low_stock` creates/resolves `low_stock_alerts` and notifies ADMIN/MANAGER.
- Sales (`SP_CreateSale`) and returns (`SP_ProcessReturn`) decrement/increment stock through movements.

## Notes

- All quantity changes are **transactional** (mutate `inventory` + insert `inventory_transactions` in one transaction).
- Negative balances are impossible: procedures validate before writing.
- The movement journal is never deleted (audit + reporting rely on it).
