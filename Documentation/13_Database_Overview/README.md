# SmartPOS — Database Overview

**Document ID:** DOC-DB-013  
**Version:** 1.0  
**Status:** Approved  
**Author:** SmartPOS Documentation Team  
**Date:** August 7, 2026  

---

## 1. Purpose

This document provides a high-level overview of the SmartPOS **Microsoft SQL
Server** database design. It covers the database philosophy, normalization
strategy, naming conventions, table relationships, indexing strategy,
transaction model, and high-level table descriptions. Detailed schema (SQL
DDL) lives in the `Database/` folder per the Project Bible.

---

## 2. Database Philosophy

SmartPOS adheres to the database philosophy defined in the
[Project Bible](../AI/SMARTPOS_PROJECT_BIBLE.md#database-philosophy):

- **Fully normalized** (3NF+) to eliminate redundancy and update anomalies.
- Follows **Microsoft SQL Server best practices**.
- Uses **meaningful table and column names**.
- Enforces **foreign keys** for referential integrity.
- Uses **constraints** (check, unique, not-null) to enforce business rules.
- Uses **indexes** for query performance.
- Optimizes **joins** and **reporting queries**.
- Generates:
  - Tables
  - Views
  - Functions
  - Triggers
  - Stored Procedures
  - Seed Data
  - Sample Data
  - Migration scripts (Alembic)
  - Database documentation
  - Data dictionary
  - ERD diagrams
  - Backup and restore scripts
- **No placeholder SQL** — every object is production-ready and functional.
- **No incomplete database objects.**

---

## 3. Normalization Strategy

The database is normalized to **Third Normal Form (3NF)** with the following
exceptions for audit trail integrity:

- The `stock_movements` table intentionally **denormalizes** product name and
  user name to preserve historical accuracy even if those records are deleted
  or updated later.
- The `audit_logs` table stores `resource_type` and `resource_id` as strings to
  avoid hard foreign key dependencies that would complicate schema evolution.

---

## 4. Naming Conventions

| Object Type | Convention | Example |
|-------------|------------|---------|
| Tables | Plural, snake_case | `products`, `sales`, `stock_movements` |
| Columns | snake_case | `product_id`, `first_name` |
| Primary Keys | Singular + `_id` | `product_id`, `sale_id` |
| Foreign Keys | Singular + `_id` | `product_id`, `user_id` |
| Indexes | `IX_<table>_<columns>` | `IX_products_category_id` |
| Unique Constraints | `UQ_<table>_<columns>` | `UQ_products_sku` |
| Check Constraints | `CK_<table>_<condition>` | `CK_products_price_non_negative` |
| Default Constraints | `DF_<table>_<column>` | `DF_products_created_at` |
| Triggers | `TRG_<table>_<event>` | `TRG_products_audit` |
| Stored Procedures | `SP_<purpose>` | `SP_CreateSale`, `SP_RestockProduct` |
| Views | `VW_<purpose>` | `VW_SalesSummary`, `VW_LowStockReport` |
| Functions | `FN_<purpose>` | `FN_CalculateDueAmount` |

---

## 5. Table Inventory

### 5.1 Core Tables

| Table | Purpose | Key Columns |
|-------|---------|-------------|
| `users` | System users (Admin, Cashier) | `user_id`, `username`, `email`, `role`, `is_active`, `password_hash` |
| `products` | Product catalog | `product_id`, `sku`, `name`, `price`, `cost`, `stock_quantity`, `low_stock_threshold`, `category_id`, `supplier_id`, `is_deleted` |
| `categories` | Product categories (hierarchical) | `category_id`, `name`, `parent_id`, `description`, `is_deleted` |
| `suppliers` | Supplier contact info | `supplier_id`, `name`, `contact_person`, `email`, `phone`, `address`, `is_deleted` |
| `inventory` | Current stock snapshot (view-backed) | — (derived from `products`) |
| `stock_movements` | Audit of all stock changes | `movement_id`, `product_id`, `quantity`, `movement_type`, `reference_id`, `user_id`, `reason`, `timestamp` |
| `sales` | Sale header records | `sale_id`, `receipt_number`, `user_id`, `total_amount`, `payment_method`, `is_credit`, `status`, `created_at` |
| `sale_items` | Sale line items | `item_id`, `sale_id`, `product_id`, `quantity`, `unit_price`, `discount` |
| `returns` | Return header records | `return_id`, `sale_id`, `reason`, `refund_amount`, `created_at` |
| `return_items` | Return line items | `item_id`, `return_id`, `sale_item_id`, `quantity`, `unit_price` |
| `credit_balances` | Customer credit tracking | `balance_id`, `customer_name`, `sale_id`, `total_amount`, `outstanding_balance` |
| `credit_payments` | Settlements against credit | `payment_id`, `balance_id`, `amount`, `payment_method`, `created_at` |
| `audit_logs` | System action logs | `log_id`, `user_id`, `action_type`, `resource_type`, `resource_id`, `details`, `ip_address`, `timestamp` |
| `notifications` | In-app notifications | `notification_id`, `user_id`, `title`, `message`, `type`, `is_read`, `entity_id`, `entity_type`, `created_at` |
| `settings` | Key-value configuration | `setting_key`, `setting_value`, `data_type`, `description` |

### 5.2 Supporting Tables

| Table | Purpose |
|-------|---------|
| `refresh_tokens` | JWT refresh token storage (hashed, revocable) |
| `sale_items_returned` | Tracks which sale items have been returned to prevent double-returns |

---

## 6. Relationships (High-Level)

```
users (1) ────< sales (1) ────< sale_items (*)> products (*) ────> categories
    │                             │               │
    │                             │               └─────> suppliers
    │                             │
    │                             └── return_items > returns > sales (self-ref)
    │
    ├── credit_balances > sales
    │       │
    │       └── credit_payments
    │
    ├── stock_movements > products, users
    │
    ├── audit_logs > users (optional)
    │
    ├── notifications > users
    │
    └── settings (standalone)
```

---

## 7. Indexing Strategy

| Table | Indexed Columns | Index Type | Purpose |
|-------|-----------------|------------|---------|
| `products` | `sku` | UNIQUE | Fast lookup by SKU |
| `products` | `name` | NONCLUSTERED | Text search |
| `products` | `category_id` | NONCLUSTERED | Filter by category |
| `products` | `supplier_id` | NONCLUSTERED | Filter by supplier |
| `products` | `stock_quantity` | NONCLUSTERED | Low-stock queries |
| `sales` | `created_at` | NONCLUSTERED | Date-range reports |
| `sales` | `user_id, created_at` | NONCLUSTERED | Cashier sales reports |
| `sale_items` | `sale_id` | NONCLUSTERED | Join performance |
| `sale_items` | `product_id` | NONCLUSTERED | Product sales analysis |
| `users` | `username` | UNIQUE | Login lookup |
| `users` | `email` | UNIQUE | Password reset lookup |
| `stock_movements` | `product_id, timestamp` | NONCLUSTERED | Movement history |
| `stock_movements` | `movement_type, timestamp` | NONCLUSTERED | Audit filtering |
| `audit_logs` | `timestamp` | NONCLUSTERED | Audit log pagination |
| `audit_logs` | `user_id, timestamp` | NONCLUSTERED | User activity reports |
| `notifications` | `user_id, is_read, created_at` | NONCLUSTERED | Notification list |
| `credit_balances` | `customer_name` | NONCLUSTERED | Customer lookup |
| `settings` | `setting_key` | UNIQUE | Configuration lookup |
| `refresh_tokens` | `token_hash` | UNIQUE | Token lookup |
| `returns` | `sale_id` | NONCLUSTERED | Return lookups |

---

## 8. Transaction Model

### 8.1 Transactional Boundaries

| Operation | Transactions Involved |
|-----------|----------------------|
| Create Sale | Single transaction: `sales` + `sale_items` + stock decrement + `stock_movements` + `audit_logs` |
| Process Return | Single transaction: `returns` + `return_items` + stock restore + `stock_movements` + `audit_logs` |
| Restock | Single transaction: stock increment + `stock_movements` + possible notification update |
| Create Product | Single transaction: `products` insert + `audit_logs` |
| Create User | Single transaction: `users` insert + `audit_logs` |
| Change Password | Single transaction: `users` update + `audit_logs` |

### 8.2 Isolation Level

- Default isolation level: **READ COMMITTED SNAPSHOT** (to minimize locking
  contention on reporting queries).

### 8.3 Concurrency Control

- Stock movements use **row-level locking** on the target `products` row
  during `UPDATE` to prevent race conditions (lost updates).
- Sales creation acquires an **update lock** on product rows when checking
  and decrementing stock.

---

## 9. Database Objects Beyond Tables

### 9.1 Views

| View Name | Purpose |
|-----------|---------|
| `VW_LowStockReport` | Products where `stock_quantity <= low_stock_threshold` |
| `VW_SalesSummary` | Daily/monthly sales aggregations |
| `VW_StockMovementHistory` | Full movement history with product and user names |
| `VW_UserActivity` | All audit log entries with user details |
| `VW_AuditTrail` | Full audit trail with resource descriptions |

### 9.2 Stored Procedures

| SP Name | Purpose |
|---------|---------|
| `SP_CreateSale` | Atomic sale creation with stock decrement |
| `SP_ProcessReturn` | Atomic return processing with stock restoration |
| `SP_RestockProduct` | Restock with movement logging and notification logic |
| `SP_GenerateSalesReport` | Complex sales aggregation for reports |
| `SP_ArchiveAuditLogs` | Move old audit logs to archive table |

### 9.3 Triggers

| Trigger Name | Table | Event | Purpose |
|--------------|-------|-------|---------|
| `TRG_stock_decrease_after_sale` | `sale_items` | AFTER INSERT | Decrement product stock |
| `TRG_stock_increase_after_return` | `return_items` | AFTER INSERT | Restore product stock |
| `TRG_log_stock_movement` | `products` | AFTER UPDATE | Log movement on stock changes |
| `TRG_create_low_stock_notification` | `products` | AFTER UPDATE | Generate notification if stock ≤ threshold |
| `TRG_audit_users` | `users` | AFTER INSERT/UPDATE/DELETE | Log user changes |
| `TRG_audit_products` | `products` | AFTER INSERT/UPDATE/DELETE | Log product changes |
| `TRG_audit_sales` | `sales` | AFTER INSERT/UPDATE/DELETE | Log sale changes |

### 9.4 Functions

| Function Name | Purpose |
|---------------|---------|
| `FN_CalculateStockStatus` | Returns "IN_STOCK", "LOW_STOCK", or "OUT_OF_STOCK" |
| `FN_GetCustomerBalance` | Returns outstanding credit balance for a customer |
| `FN_DateToVarchar` | Standard date formatting for reports |

---

## 10. Seed Data

| Table | Sample Records |
|-------|----------------|
| `users` | 1 Admin (admin@smartpos.local), 1 Cashier (cashier@smartpos.local) |
| `categories` | "Beverages", "Food", "Electronics", "Supplies" |
| `suppliers` | "Global Distributors", "Local Market", "Tech Wholesale" |
| `products` | 10–20 sample products across categories |
| `settings` | Default settings: `currency_symbol` = "$", `low_stock_threshold_default` = 10, `receipt_footer` = "..." |
| `settings` | `date_format` = "YYYY-MM-DD", `timezone` = "UTC" |

---

## 11. ERD Reference

A visual Entity-Relationship Diagram (ERD) is available as a Mermaid diagram at
[Diagrams/database-erd.mmd](../12_Database_Overview/../Diagrams/database-erd.mmd).

---

## 12. Related Documents

- [12_System_Architecture — Data Layer](../12_System_Architecture/README.md#33-data-layer-database)
- [15_Backend_Architecture](../15_Backend_Architecture/README.md)
- [14_API_Architecture](../14_API_Architecture/README.md)
- [18_Security_Architecture — §3 (Audit Trail)](../18_Security_Architecture/README.md#3-audit-trail)
- [SMARTPOS_PROJECT_BIBLE.md](..//../AI/SMARTPOS_PROJECT_BIBLE.md#database-philosophy)

---

## 13. Revision History

| Version | Date | Author | Description |
|---------|------|--------|-------------|
| 1.0 | 2026-08-07 | SmartPOS Documentation Team | Initial release |
