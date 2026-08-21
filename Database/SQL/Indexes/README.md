# SmartPOS Database — Indexes

Indexes are declared inside each module's `tables.sql` after the table DDL so
they are applied in dependency order with the schema.

## Naming

| Prefix | Purpose | Example |
|--------|---------|---------|
| `IX_<table>_<columns>` | Non-clustered index | `IX_products_category_id` |
| `UQ_<table>_<columns>` | Unique constraint (index) | `UQ_products_sku` |

## Indexing Policy

1. **Every foreign key column gets a supporting index.**
2. Columns used in `WHERE`, `JOIN`, and `ORDER BY` that are selective get a
   non-clustered index.
3. Reporting aggregation columns (dates, status, movement types) get covering
   indexes (`INCLUDE`) where they materially speed up report views.
4. Full-text search is intentionally not used; `SP_SearchProducts` performs a
   leading-wildcard `LIKE` which is acceptable for POS catalogs. For very large
   catalogs, consider `CONTAINSTABLE` or a secondary search index.

## Notable Indexes

| Index | Table | Columns | Purpose |
|-------|-------|---------|---------|
| `IX_products_category_id` | products | category_id | category filter |
| `IX_products_name` | products | product_name INCLUDE (sku, unit_price) | search |
| `IX_sales_user_date` | sales | (user_id, sale_date) | cashier reports |
| `IX_sale_items_sale_id` | sale_items | sale_id INCLUDE (product_id, quantity, line_total) | join perf |
| `IX_inventory_transactions_product_created` | inventory_transactions | (product_id, created_at) | movement history |
| `IX_audit_logs_created_at` | audit_logs | created_at | audit pagination |
| `IX_notifications_user_read` | notifications | (user_id, is_read, created_at) | notification list |
| `IX_credit_sales_customer_id` | credit_sales | customer_id INCLUDE (outstanding_balance, status) | credit tracking |

## Index Maintenance

See `../Documentation/PerformanceGuide.md` and `../Documentation/MaintenanceGuide.md`.