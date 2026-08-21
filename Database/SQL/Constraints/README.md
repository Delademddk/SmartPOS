# SmartPOS Database — Constraints

Constraints are declared inside each module's `tables.sql` alongside the table
they constrain, so they are always applied with the schema in dependency order.

## Constraint Naming

| Prefix | Purpose | Example |
|--------|---------|---------|
| `PK_<table>` | Primary key | `PK_products` |
| `FK_<child>_<parent>` | Foreign key | `FK_sale_items_sales` |
| `UQ_<table>_<columns>` | Unique constraint | `UQ_products_sku` |
| `CK_<table>_<condition>` | Check constraint | `CK_products_unit_price_non_negative` |
| `DF_<table>_<column>` | Default constraint | `DF_products_created_at` |

## Key Business-Rule Constraints

| Constraint | Rule |
|------------|------|
| `CK_products_unit_price_non_negative` | unit_price >= 0 |
| `CK_products_cost_price_non_negative` | cost_price >= 0 |
| `CK_sale_items_discount_rate` | discount_rate BETWEEN 0 AND 1 |
| `CK_sale_items_qty_positive` | quantity > 0 |
| `CK_sale_items_returned_not_exceed` | returned_qty <= quantity |
| `CK_sales_status` | status IN (COMPLETED, VOIDED, REFUNDED) |
| `CK_sales_type` | sale_type IN (CASH, CREDIT, CREDIT_PARTIAL) |
| `CK_credit_sales_balance_non_negative` | outstanding_balance >= 0 |
| `CK_credit_sales_status` | status IN (OPEN, PARTIAL, SETTLED, OVERDUE, WRITTEN_OFF) |
| `CK_inventory_quantity_non_negative` | quantity_on_hand >= 0 |
| `CK_inventory_transactions_movement_type_upper` | movement_type is UPPERCASE |
| `CK_returns_status` | status IN (PENDING, COMPLETED, REJECTED) |
| `CK_categories_not_self_parent` | parent_id <> category_id |
| `CK_notifications_severity` | severity IN (INFO, WARNING, CRITICAL) |
| `CK_settings_data_type` | data_type IN (string, int, decimal, bool, json) |
| `CK_currencies_code_format` | currency_code length 3 |
| `CK_users_email_format` | email LIKE '%_@_%._%' |
| `CK_tax_rates_rate_max` | rate_percent <= 100 |

## Referential Integrity

All foreign keys default to `NO ACTION` (no cascade) so that deleting a parent
row is blocked unless the caller performs an explicit soft delete or a
controlled cleanup. This protects transactional and audit data.