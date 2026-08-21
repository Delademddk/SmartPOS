# Module 06 — Suppliers

**SQL source:** `Database/SQL/06_Suppliers/`
**Purpose:** Supplier master data, contacts and interaction history.

## Tables

| Table | Purpose |
|-------|---------|
| `suppliers` | Supplier master; `supplier_code` and `supplier_name` unique. Soft-deletable. |
| `supplier_contacts` | Multiple contacts per supplier (one primary). |
| `supplier_history` | Append-only event log (CREATED / UPDATED / CONTACT_CHANGED / DELETED / NOTE). |

## Stored Procedures

| Procedure | Purpose |
|-----------|---------|
| `SP_GetSuppliers` / `SP_GetSupplier` | List / fetch one supplier. |
| `SP_CreateSupplier` | Insert supplier + initial history event. |
| `SP_UpdateSupplier` | Update fields + history event. |
| `SP_DeleteSupplier` | Soft delete; refuses when products still reference the supplier. |
| `SP_GetSupplierContacts` | List contacts for a supplier. |
| `SP_AddSupplierContact` / `SP_UpdateSupplierContact` / `SP_DeleteSupplierContact` | Contact lifecycle (one primary enforced). |
| `SP_LogSupplierHistory` | Append an explicit history event (used by other procedures). |

## Dependencies

- Module 05 (`products.supplier_id`).
- `TRG_suppliers_audit` writes `audit_logs`.

## Notes

- Primary-contact uniqueness is enforced at the procedure level inside a transaction.
- History is append-only; there is no update path for `supplier_history`.
