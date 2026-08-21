# SmartPOS Database — Naming & Coding Standards

**Scope:** Every SQL object produced for the SmartPOS database MUST follow these
standards so modules integrate cleanly, indexes are predictable, and the schema
remains maintainable and compliant with the Project Bible.

---

## 1. Object Naming

| Object | Convention | Example |
|--------|-----------|---------|
| Database | PascalCase | `SmartPOS` |
| Schema | lowercase | `dbo` |
| Tables | plural snake_case | `products`, `stock_movements`, `role_permissions` |
| Views | `VW_<Purpose>` | `VW_SalesSummary`, `VW_LowStockReport` |
| Stored Procedures | `SP_<Purpose>` | `SP_CreateSale`, `SP_RestockProduct` |
| Functions | `FN_<Purpose>` | `FN_CalculateDueAmount` |
| Triggers | `TRG_<table>_<event>` | `TRG_products_audit` |
| Indexes | `IX_<table>_<columns>` | `IX_products_category_id` |
| Unique Constraint | `UQ_<table>_<columns>` | `UQ_users_username` |
| Check Constraint | `CK_<table>_<condition>` | `CK_products_price_non_negative` |
| Default Constraint | `DF_<table>_<column>` | `DF_products_created_at` |
| Foreign Key | `FK_<child>_<parent>` | `FK_sale_items_sales` |

## Column Names

- Columns are `snake_case`.
- Primary keys are named `<table_singular>_id` (e.g., `product_id`).
- Foreign keys are named `<referenced_singular>_id`.
- Boolean flags use `is_` prefix: `is_active`, `is_deleted`, `is_read`.
- Timestamps: `created_at`, `updated_at`, `deleted_at`, `last_login_at`.
- Monetary columns append the unit/meaning: `unit_price`, `total_amount`,
  `cost_price`, `subtotal`, `tax_amount`, `discount_amount`, `outstanding_balance`.

## Audit Fields (required on every mutable table)

| Column | Type | Purpose |
|--------|------|---------|
| `created_at` | `DATETIME2(0)` | Row creation timestamp |
| `updated_at` | `DATETIME2(0)` | Last modification timestamp |
| `created_by` | `INT NULL` → `users` | Acting user |
| `updated_by` | `INT NULL` → `users` | Last modifying user |
| `is_deleted` | `BIT` | Soft-delete flag (default `0`) |
| `deleted_at` | `DATETIME2(0) NULL` | Soft-delete timestamp |
| `deleted_by` | `INT NULL` → `users` | Soft-delete actor |

## Naming for values

- Enum-like string values use UPPER_SNAKE with a `_type`, `_status`, or broad
  column name (e.g., `role_code = 'ADMIN'`, `movement_type = 'SALE'`,
  `sale_status = 'COMPLETED'`).

## Indexing rules

- Every FK **MUST** have a supporting index.
- Columns used in `WHERE`/`ORDER BY`/`JOIN` predicates that are selective get a
  non-clustered index.
- `UQ_` constraints are created where uniqueness is a business rule (username,
  email, SKU, setting_key, permission code, role code).
- Prefix: `IX_` for indexes, `UQ_` for unique constraints (both are physical
  indexes in SQL Server, but the name documents intent).

## Soft Delete

- Business records (users, products, categories, suppliers, settings) use soft
  deletes via `is_deleted`, `deleted_at`, `deleted_by`.
- Operational/transactional records (sales, payments, stock movements, audit
  logs) are hard-deleted only when requeued; normally retained.

## Transactions

- Stored procedures that change multiple tables MUST run inside a transaction.
- Isolation: `READ COMMITTED SNAPSHOT` recommended; see documentation, not
  enforced inside procedures.

## Error handling

- Procedures use structured `TRY...CATCH`.
- Raise errors with `THROW` using a meaningful `sp_addmessage`-registered
  number or a clear message. The backend only relies on the JSON message.

---

## Revision History

| Version | Date | Description |
|---------|------|-------------|
| 1.0 | 2026-08-07 | Initial naming & conventions standard |