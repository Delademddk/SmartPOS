# SmartPOS Database SQL — Tables

Each module folder under `SQL/` contains the `tables.sql` for that module. The
table files are applied by the setup scripts in FK dependency order.

## Module → Table Map

| Module | Tables |
|--------|--------|
| 01 Authentication | `roles`, `permissions`, `role_permissions` |
| 02 Users | `users`, `user_sessions`, `password_history`, `password_resets` |
| 03 Business | `business_information`, `currencies`, `tax_rates` |
| 04 Categories | `categories` |
| 05 Products | `products`, `product_images` |
| 06 Suppliers | `suppliers`, `supplier_contacts`, `supplier_history` |
| 07 Inventory | `inventory`, `inventory_transactions`, `stock_reconciliations`, `low_stock_alerts` |
| 08 Sales | `sales`, `sale_items` |
| 09 Payments | `payment_methods`, `payments`, `receipts` |
| 10 Credit Sales | `customers`, `credit_sales`, `credit_payments` |
| 11 Returns | `return_reasons`, `returns`, `return_items` |
| 12 Notifications | `notification_types`, `notifications`, `notification_history` |
| 15 Settings | `settings`, `user_settings` |
| 16 Audit | `audit_logs`, `activity_logs`, `error_logs`, `security_logs`, `audit_logs_archive` |

Every table uses `TABLENAME` plural snake_case, an identity primary key, audit
fields (`created_at`, `updated_at`, `created_by`, `updated_by` where mutable),
soft-delete flags (`is_deleted`, `deleted_at`, `deleted_by`) for business
records, FK constraints, supporting indexes, and CHECK constraints.

See `../Documentation/NamingStandards.md` for conventions.