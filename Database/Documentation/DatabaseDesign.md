# SmartPOS Database — Database Design

**Document ID:** DOC-DB-DESIGN
**Version:** 1.0
**Status:** Approved
**Date:** August 7, 2026

This document describes the complete design of the **SmartPOS** Microsoft SQL
Server database. It is grounded in the actual schema implemented under
[`Database/SQL/`](../SQL/) and complies with the database philosophy in the
[Project Bible](../../AI/SMARTPOS_PROJECT_BIBLE.md).

---

## 1. Design Goals

1. **Fully normalized (3NF+).** Eliminate redundancy and update anomalies while
   keeping the schema readable and production-maintainable.
2. **Production-ready.** Every table, view, procedure, function and trigger is
   complete and functional — no placeholders.
3. **Referential integrity.** Foreign keys enforce relationships; check,
   unique and default constraints enforce business rules at the data layer.
4. **Optimized for OLTP + reporting.** Indexed joins, filtered lookups, and
   dedicated reporting views for the Reports and Dashboard modules.
5. **Secure by design.** Passwords and tokens stored as hashes only; RBAC via
   roles/permissions; a complete audit trail on every mutable table.
6. **Auditable.** Every important action produces a durable audit record
   (`audit_logs`) or a typed log row (`activity_logs`, `security_logs`,
   `error_logs`).
7. **Idempotent build.** All DDL and seed scripts are safe to re-run; nothing
   depends on identity values in seed logic.
8. **Version 2016+ compatible.** Uses `OPENJSON`, `FOR JSON`,
   `STRING_SPLIT`, `TRY_CAST` and `TRY_...CATCH`; no features newer than
   SQL Server 2016.

---

## 2. Normalization (3NF) Strategy

The schema is normalized to **Third Normal Form (3NF)**:

- **First normal form (1NF):** every column is atomic; every table has a
  single-column surrogate primary key (`<singular>_id`).
- **Second normal form (2NF):** no partial dependencies. Association tables
  such as `role_permissions` use their own surrogate key plus a unique
  constraint on the composite `(role_id, permission_id)`.
- **Third normal form (3NF):** no transitive dependencies. Lookup values
  (category, supplier, role, tax rate, payment method, return reason,
  notification type) are referenced by foreign key, never duplicated by value.

### 2.1 Deliberate, documented denormalizations

Historical accuracy and reporting convenience justify a small set of
intentional denormalizations. Each is noted in the DDL and reproduced here:

| Location | Denormalization | Reason |
|----------|-----------------|--------|
| `sale_items.unit_price`, `discount_rate`, `tax_amount`, `line_total` | Price/discount/tax snapshot at time of sale | A product's `unit_price` may change later; the receipt must reflect what was actually sold. |
| `return_items.unit_price`, `refund_amount`, `product_id` | Snapshot + reporting convenience (`product_id` duplicated from `sale_items`) | Refund amount must match the original sale value; `product_id` avoids extra joins in return reports. |
| `inventory_transactions.quantity_before`, `quantity_after` | Stock level snapshot before/after each movement | Provides a verifiable audit trail even if the inventory row is later adjusted. |
| `audit_logs.old_values`, `new_values` | JSON snapshot of the row before/after change | Preserves the exact pre/post state independent of current table contents. |
| `notifications.entity_type`, `entity_id` | Polymorphic reference stored as strings | Notifications may reference any resource type without hard FK coupling. |
| `stock_reconciliations.system_quantity`, `counted_quantity`, `difference` | Full snapshot of a physical count | A reconciliation is a point-in-time record and must not change later. |

The database deliberately does **not** store running stock quantities on
`products`; the current snapshot lives in `inventory`, and every change to it
is journaled in `inventory_transactions`.

---

## 3. Schema Overview

- **Database:** `SmartPOS`
- **Schema:** `dbo`
- **Tables:** 41 across 14 modules
- **Collation:** `SQL_Latin1_General_CP1_CI_AS` (configured via `DB_DEFAULT_COLLATION`)
- **Timestamp convention:** `DATETIME2(0)` populated with `SYSUTCDATETIME()` (UTC)

| Module | Name | Tables |
|--------|------|--------|
| 01 | Authentication | `roles`, `permissions`, `role_permissions` |
| 02 | Users | `users`, `user_sessions`, `password_history`, `password_resets` |
| 03 | Business | `business_information`, `currencies`, `tax_rates` |
| 04 | Categories | `categories` |
| 05 | Products | `products`, `product_images` |
| 06 | Suppliers | `suppliers`, `supplier_contacts`, `supplier_history` |
| 07 | Inventory | `inventory`, `inventory_transactions`, `stock_reconciliations`, `low_stock_alerts` |
| 08 | Sales | `sales`, `sale_items` |
| 09 | Payments | `payment_methods`, `payments`, `receipts` |
| 10 | Credit Sales | `customers`, `credit_sales`, `credit_payments` |
| 11 | Returns | `return_reasons`, `returns`, `return_items` |
| 12 | Notifications | `notification_types`, `notifications`, `notification_history` |
| 15 | Settings | `settings`, `user_settings` |
| 16 | Audit | `audit_logs`, `activity_logs`, `error_logs`, `security_logs`, `audit_logs_archive` |

Modules 13 (Reports), 14 (Dashboard), 17 (Shared), 18 (Operational Views),
19 (Triggers) and 20 (Setup) contribute non-table objects — see §5.

### 3.1 Build order

Foreign-key dependencies dictate the build order. The full sequence is
documented in [`Database/SQL/README.md`](../SQL/README.md) and executed by the
master build driver in `Scripts/` (see [`DeploymentGuide.md`](DeploymentGuide.md)):

```
01 Authentication → 02 Users → 03 Business → 04 Categories → 06 Suppliers
→ 05 Products → 07 Inventory → 08 Sales → 09 Payments → 10 Credit Sales
→ 11 Returns → 12 Notifications → 15 Settings → 16 Audit
(shared functions, then views, then stored procedures, then triggers, then seed)
```

---

## 4. Module Design Details

Each section lists the purpose of the module and of every table in it.
Procedures for each module are described in the matching `Module_Guides/` file.

### 4.1 Module 01 — Authentication (RBAC)

Establishes the Role-Based Access Control (RBAC) foundation used across the
whole application.

| Table | Purpose |
|-------|---------|
| `roles` | Security roles. `role_code` (e.g. `ADMIN`, `MANAGER`, `CASHIER`) is the stable machine key; `is_system` protects built-in roles from deletion and permission-set replacement. |
| `permissions` | Granular permissions (e.g. `products.create`, `sales.view`) grouped by `module_name`. `permission_code` is the stable machine key. |
| `role_permissions` | Association granting a permission to a role. Unique on `(role_id, permission_id)`. |

Key procedures: `SP_Login`, `SP_Logout`, `SP_ValidateSession`,
`SP_GetRoles`, `SP_GetRole`, `SP_CreateRole`, `SP_UpdateRole`,
`SP_DeleteRole`, `SP_GetPermissions`.

### 4.2 Module 02 — Users

| Table | Purpose |
|-------|---------|
| `users` | Application user accounts. Passwords stored as **hashes only** (`password_hash`); lockout, forced password change and last-login tracking built in. |
| `user_sessions` | Revocable sessions (hashed tokens, `expires_at`, `is_revoked`) used for login session validation. |
| `password_history` | Previous password hashes (retention capped at 5 per user by `TRG_password_history_retention`) to prevent reuse. |
| `password_resets` | One-time, expiring password reset tokens (hashed). |

Key procedures: `SP_GetUsers`, `SP_GetUser`, `SP_CreateUser`,
`SP_UpdateUser`, `SP_DeactivateUser`, `SP_ResetPassword`,
`SP_ChangePassword`, `SP_RequestPasswordReset`, `SP_CompletePasswordReset`.

### 4.3 Module 03 — Business

| Table | Purpose |
|-------|---------|
| `business_information` | Single-row company profile (name, tax id, address, currency, timezone) used on receipts and reports. |
| `currencies` | Supported currencies; exactly one is marked `is_base`. |
| `tax_rates` | Configurable tax rates (`rate_percent`, e.g. `7.5000` = 7.5%); one may be `is_default`. |

Key procedures: `SP_GetBusinessInformation`, `SP_UpsertBusinessInformation`,
`SP_GetCurrencies`, `SP_CreateCurrency`, `SP_UpdateCurrency`,
`SP_SetBaseCurrency`, `SP_GetTaxRates`, `SP_CreateTaxRate`,
`SP_UpdateTaxRate`, `SP_DeactivateTaxRate`.

### 4.4 Module 04 — Categories

| Table | Purpose |
|-------|---------|
| `categories` | Product categories in a **self-referencing hierarchy** (`parent_id` → `categories.category_id`). Name must be unique within the same parent; a category can never be its own ancestor (guarded in `SP_UpdateCategory`). |

Key procedures: `SP_GetCategories`, `SP_GetCategoryTree`,
`SP_CreateCategory`, `SP_UpdateCategory`, `SP_DeleteCategory`,
`SP_GetCategory`.

### 4.5 Module 05 — Products

| Table | Purpose |
|-------|---------|
| `products` | Product catalogue. `sku` and `barcode` unique; `unit_price`, `cost_price`, `low_stock_threshold`, `is_service` (service items have no inventory). Soft-deletable. |
| `product_images` | One or more images per product; exactly one `is_primary`. |

Key procedures: `SP_GetProducts`, `SP_GetProduct`, `SP_CreateProduct`,
`SP_UpdateProduct`, `SP_DeleteProduct`, `SP_RestoreProduct`,
`SP_GetProductByBarcode`, `SP_GetProductBySKU`, `SP_SearchProducts`,
`SP_GetProductImages`, `SP_AddProductImage`, `SP_DeleteProductImage`.

### 4.6 Module 06 — Suppliers

| Table | Purpose |
|-------|---------|
| `suppliers` | Supplier master data (`supplier_code` and `supplier_name` unique). Soft-deletable. |
| `supplier_contacts` | Multiple contacts per supplier (one primary). |
| `supplier_history` | Append-only log of supplier interactions (CREATED / UPDATED / CONTACT_CHANGED / DELETED / NOTE). |

Key procedures: `SP_GetSuppliers`, `SP_GetSupplier`, `SP_CreateSupplier`,
`SP_UpdateSupplier`, `SP_DeleteSupplier`, `SP_GetSupplierContacts`,
`SP_AddSupplierContact`, `SP_UpdateSupplierContact`,
`SP_DeleteSupplierContact`, `SP_LogSupplierHistory`.

### 4.7 Module 07 — Inventory

| Table | Purpose |
|-------|---------|
| `inventory` | Current stock snapshot per product (`quantity_on_hand`, `quantity_reserved`, `reorder_level`). Unique on `product_id`; non-negative quantities enforced. |
| `inventory_transactions` | Append-only stock movement journal (`movement_type` in `SALE`/`RESTOCK`/`RETURN`/`ADJUSTMENT`/`VOID`/`TRANSFER`; `quantity` signed; before/after snapshots). Never deleted. |
| `stock_reconciliations` | Physical count / damage / theft / expiry / correction adjustments, linked to the resulting `inventory_transactions` row. |
| `low_stock_alerts` | Open/resolved/dismissed low-stock alerts raised by `TRG_inventory_low_stock`. |

Key procedures: `SP_RestockProduct`, `SP_AdjustStock`, `SP_GetStockLevel`.

### 4.8 Module 08 — Sales

| Table | Purpose |
|-------|---------|
| `sales` | Sale header: receipt number (unique), cashier (`user_id`), customer, tax rate, `sale_type` (`CASH`/`CREDIT`/`CREDIT_PARTIAL`), subtotal/discount/tax/total, `amount_received`, `status` (`COMPLETED`/`VOIDED`/`REFUNDED`). |
| `sale_items` | Sale line items with price snapshot, discount rate, tax and `line_total`; tracks `returned_qty`/`is_returned`. |

Key procedure: `SP_CreateSale` (atomic header + lines + stock decrement +
movements + optional credit balance + payment).

### 4.9 Module 09 — Payments

| Table | Purpose |
|-------|---------|
| `payment_methods` | Tender types (CASH, CARD, MOBILE, BANK_TRANSFER ...). `is_cash` distinguishes cash; the last active cash method cannot be deactivated (`SP_UpdatePaymentMethod`). |
| `payments` | Payments against a sale (`amount`, method, status). Credit-related payments update credit balances via `SP_RecordPayment`. |
| `receipts` | Generated receipts per sale (gross, discount, tax, net, paid, change). |

Key procedures: `SP_GetPaymentMethods`, `SP_CreatePaymentMethod`,
`SP_UpdatePaymentMethod`, `SP_GetSalePayments`, `SP_GetPayment`,
`SP_RecordPayment`, `SP_GetReceipt`, `SP_GetReceiptBySale`,
`SP_GenerateReceipt`.

### 4.10 Module 10 — Credit Sales

| Table | Purpose |
|-------|---------|
| `customers` | Credit customers (unique `customer_code`, credit limit, soft-deletable). |
| `credit_sales` | Credit ledger per sale: `total_amount`, `amount_paid`, `outstanding_balance`, `due_date`, `status` (`OPEN`/`PARTIAL`/`SETTLED`/`OVERDUE`/`WRITTEN_OFF`). Unique on `sale_id`. |
| `credit_payments` | Payments applied against a credit balance, optionally linked to a `payments` row. |

This module ships tables only; credit creation flows through
`SP_CreateSale` (sale type `CREDIT`) and credit settlements flow through
`SP_RecordPayment`.

### 4.11 Module 11 — Returns

| Table | Purpose |
|-------|---------|
| `return_reasons` | Canned return reasons (DEFECTIVE, WRONG_ITEM, ...). |
| `returns` | Return header: original sale, customer, processor, reason, refund total, `status` (`PENDING`/`COMPLETED`/`REJECTED`). |
| `return_items` | Return lines referencing the original `sale_items`, with refund snapshot. |

Key procedure: `SP_ProcessReturn` (atomic return header + items + stock
restore + movements; cannot return more than sold minus already returned).

### 4.12 Module 12 — Notifications

| Table | Purpose |
|-------|---------|
| `notification_types` | Notification categories (LOW_STOCK, SALE, RETURN, CREDIT, SYSTEM, SECURITY). |
| `notifications` | In-app notifications per recipient with severity, read/dismissed flags and polymorphic entity reference. |
| `notification_history` | Delivered/processed notification records. |

Key procedures: `SP_GetNotifications`, `SP_GetUnreadCount`,
`SP_MarkNotificationRead`, `SP_DismissNotification`,
`SP_CreateNotification`, `SP_GetNotificationTypes`, `SP_ResetNotifications`.

### 4.13 Module 13 — Reports

Reporting views and procedures (read-only). Views: `VW_SalesSummary`,
`VW_DailySales`, `VW_ProductSalesReport`, `VW_InventoryReport`,
`VW_InventoryMovementsReport`, `VW_SupplierReport`, `VW_CreditReport`,
`VW_ReturnsReport`, `VW_ProfitReport`, `VW_PaymentMethodsReport`,
`VW_TaxReport`. Procedures: `SP_SalesReport`, `SP_InventoryReport`,
`SP_InventoryMovementsReport`, `SP_SupplierReport`, `SP_CreditReport`,
`SP_ReturnsReport`, `SP_ProfitReport`, `SP_TaxReport`,
`SP_PaymentMethodsReport`, `SP_ProductSalesReport`, `SP_ExportReport`.
See [`Module_13_Reports.md`](Module_Guides/Module_13_Reports.md).

### 4.14 Module 14 — Dashboard

Dashboard KPI views and procedures. Views: `VW_DashboardKPIs`,
`VW_RecentSales`, `VW_TopProducts`, `VW_SalesTrend7d`,
`VW_SalesByCategory`, `VW_SalesByPaymentMethod`, `VW_RecentNotifications`,
`VW_OutstandingCredit`. Procedures: `SP_GetDashboardMetrics`,
`SP_GetDashboardData`, `SP_GetSalesByCategory`, `SP_GetTopProducts`,
`SP_GetSalesTrend`. See [`Module_14_Dashboard.md`](Module_Guides/Module_14_Dashboard.md).

### 4.15 Module 15 — Settings

| Table | Purpose |
|-------|---------|
| `settings` | Application/system key-value configuration (`data_type` in `string`/`int`/`decimal`/`bool`/`json`; `category` grouping). Unique `setting_key`. |
| `user_settings` | Per-user preferences, unique on `(user_id, setting_key)`. |

Key procedures: `SP_GetSettings`, `SP_GetSetting`, `SP_UpsertSetting`,
`SP_DeleteSetting`, `SP_GetUserSettings`, `SP_UpsertUserSetting`.

### 4.16 Module 16 — Audit & Logging

| Table | Purpose |
|-------|---------|
| `audit_logs` | Change history of business records (`action_type`, `resource_type`, `resource_id`, old/new JSON). Written by audit triggers and explicitly by procedures. |
| `activity_logs` | High-level user activity (logins, exports, key actions). |
| `error_logs` | Stored-procedure / application errors (message, stack trace, source). |
| `security_logs` | Authentication and authorization events (LOGIN_SUCCESS, LOGIN_FAILED, LOGOUT, LOCKOUT, RESET). |
| `audit_logs_archive` | Partitioned storage for rotated audit rows (`SP_ArchiveAuditLogs`). |

Key procedures: `SP_GetAuditLogs`, `SP_GetSecurityLogs`, `SP_GetErrorLogs`,
`SP_ArchiveAuditLogs`.

---

## 5. Non-Table Objects

### 5.1 Shared functions (Module 17)

| Function | Purpose |
|----------|---------|
| `FN_SmartPOS_Setting` | Read an application setting with a fallback default. |
| `FN_StockStatus` | Classify a quantity as `IN_STOCK` / `LOW_STOCK` / `OUT_OF_STOCK`. |
| `FN_HasPermission` | SQL-side RBAC guard (user → role → permission). |
| `FN_HashToken` | SHA2-256 hash for session/reset tokens at rest. |
| `FN_CalculateLineTotal` | `(unit_price × qty) × (1 − discount_rate)` with clamping. |
| `FN_GetUserDisplayName` | NULL-safe display name for a user. |
| `FN_CurrencySymbol` | Configured currency symbol (default `$`). |

### 5.2 Operational views (Module 18)

`VW_UserPermissions` (effective permissions per active user),
`VW_ProductStock` (current stock with status), `VW_SalesWithLines`
(denormalized header + lines), `VW_CustomerBalances` (credit per customer),
`VW_LowStock` (products at/below threshold).

### 5.3 Triggers (Module 19)

| Trigger | Table / Event | Purpose |
|---------|---------------|---------|
| `TRG_products_audit` | `products` INSERT/UPDATE/DELETE | JSON audit snapshots (incl. `SOFT_DELETE`). |
| `TRG_categories_audit` | `categories` INSERT/UPDATE/DELETE | JSON audit snapshots. |
| `TRG_suppliers_audit` | `suppliers` INSERT/UPDATE/DELETE | JSON audit snapshots. |
| `TRG_users_audit` | `users` INSERT/UPDATE/DELETE | JSON audit snapshots — **never includes `password_hash`**. |
| `TRG_settings_audit` | `settings` INSERT/UPDATE/DELETE | JSON audit snapshots. |
| `TRG_inventory_low_stock` | `inventory` UPDATE | Raises/resolves low-stock alerts; notifies ADMIN/MANAGER. |
| `TRG_password_history_retention` | `password_history` INSERT | Keeps at most 5 history rows per user. |

---

## 6. Key Relationships (Prose)

The central transaction chain is **sales → sale_items → returns**. A
`sales` row is created by a cashier (`users`), optionally for a `customer`,
and optionally with a `tax_rate`. Every line is a `sale_items` row pointing
at one `products` row and snapshots its price. `payments` attach to the sale
header; `receipts` are generated per sale. For credit sales, exactly one
`credit_sales` row exists per `sales` row, and `credit_payments` reduce the
outstanding balance. `returns` reference the original sale and are broken
into `return_items` that reference the original `sale_items` and the returned
`products`; the return reason is optional.

**Products** sit at the centre of the catalogue: each belongs to a
`category` (optional, hierarchical) and a `supplier` (optional), has one
`inventory` snapshot row (non-service items) and may have many
`product_images`. **Inventory** mutations are journaled in
`inventory_transactions` (signed quantities with before/after snapshots);
`stock_reconciliations` document physical adjustments and link to the
resulting movement.

**Security and identity** radiate from `users`: sessions
(`user_sessions`), password history and resets, notifications, audit rows,
activity/security/error logs and `created_by`/`updated_by`/`deleted_by`
audit columns on master tables all point at `users`.

The complete relationship catalogue — every FK, cardinality and delete
behavior — is in [`RelationshipDocumentation.md`](RelationshipDocumentation.md).

---

## 7. ERD Reference

The canonical entity-relationship diagram is maintained in the documentation
diagram folders of this repository:

- **Mermaid ERD:** `Documentation/ERD/` and `Database/ERD/Mermaid/`
- **PlantUML ERD:** `Database/ERD/PlantUML/`
- **Diagrams:** `Documentation/Diagrams/` and `Database/Diagrams/`

> Note: at the time of writing, the `Documentation/ERD/`, `Documentation/Diagrams/`,
> `Database/ERD/` and `Database/Diagrams/` folders are reserved for diagram
> assets and should be populated from the schema with a generation tool
> (e.g. a SQL Server → Mermaid exporter). The schema itself is the source of
> truth for every relationship documented in
> [`RelationshipDocumentation.md`](RelationshipDocumentation.md).

A text-level diagram of the core chains:

```
roles (1) ──< users (1) ──< user_sessions
                │              password_history
                │              password_resets
                │              notifications
                │              audit_logs / activity_logs / security_logs / error_logs
                │
categories ──< products ──< product_images
suppliers  ──< products ──< inventory (1:1) ──< inventory_transactions
                                  │              stock_reconciliations
                                  └──< low_stock_alerts
tax_rates ──< sales ──< sale_items ──> products
users ──< sales           │
customers ──< credit_sales ──< credit_payments ──> payments
sales ──< payments ──> payment_methods
sales ──< receipts
sales ──< returns ──< return_items ──> sale_items, products
return_reasons ──< returns
```

---

## 8. Revision History

| Version | Date | Description |
|---------|------|-------------|
| 1.0 | 2026-08-07 | Initial database design document |
