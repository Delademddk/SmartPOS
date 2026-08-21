# SmartPOS Database — Relationship Documentation

**Document ID:** DOC-DB-RELATIONS
**Version:** 1.0
**Status:** Approved
**Date:** August 7, 2026

This document is the authoritative catalogue of every foreign-key (FK)
relationship in the SmartPOS database, including cardinality, delete
behavior, and the business purpose of each relationship.

> **Delete behavior note:** Every FK in the schema uses the default
> **`NO ACTION`** — there are **no cascading deletes or updates** anywhere.
> This is intentional: the system uses **soft deletes**
> (`is_deleted = 1`, `deleted_at`, `deleted_by`) for master records, and
> transactional records (sales, payments, returns, inventory movements) are
> never physically deleted. This protects the audit trail and receipt
> history from accidental cascading loss.

---

## 1. Relationship Conventions

| Convention | Rule |
|------------|------|
| FK name | `FK_<child_table>_<parent_table>` (e.g. `FK_sale_items_sales`) |
| Child column | `<parent_singular>_id` (e.g. `sale_id`, `role_id`) |
| Self-reference | `parent_id` for hierarchies (only `categories`) |
| Cardinality | Always **1:N** (one parent, many children) |
| Delete behavior | Always `NO ACTION` |
| `ON UPDATE` | `NO ACTION` (surrogate IDs are immutable) |

---

## 2. Module 01 — Authentication

| FK | Child column(s) | Parent | Parent column | Cardinality | Purpose |
|----|------------------|--------|---------------|-------------|---------|
| `FK_role_permissions_role` | `role_id` | `roles` | `role_id` | 1:N | A role owns the permission grants listed in `role_permissions`. |
| `FK_role_permissions_permission` | `permission_id` | `permissions` | `permission_id` | 1:N | A permission can be granted to many roles. |

---

## 3. Module 02 — Users

| FK | Child column(s) | Parent | Parent column | Cardinality | Purpose |
|----|------------------|--------|---------------|-------------|---------|
| `FK_users_role` | `role_id` | `roles` | `role_id` | 1:N | Every user belongs to exactly one role (RBAC). |
| `FK_user_sessions_user` | `user_id` | `users` | `user_id` | 1:N | One user can have many active/expired/revoked sessions. |
| `FK_password_history_user` | `user_id` | `users` | `user_id` | 1:N | A user's previous password hashes (max 5, enforced by trigger). |
| `FK_password_resets_user` | `user_id` | `users` | `user_id` | 1:N | Password reset tokens are issued per user and expire. |

---

## 4. Module 04 — Categories

| FK | Child column(s) | Parent | Parent column | Cardinality | Purpose |
|----|------------------|--------|---------------|-------------|---------|
| `FK_categories_parent` | `parent_id` | `categories` | `category_id` | 1:N (self) | Hierarchical product categories; a category may have many children. A category can never be its own ancestor (guarded in `SP_UpdateCategory`). |

---

## 5. Module 05 — Products

| FK | Child column(s) | Parent | Parent column | Cardinality | Purpose |
|----|------------------|--------|---------------|-------------|---------|
| `FK_products_category` | `category_id` | `categories` | `category_id` | 1:N | Products may belong to a category. NULL when uncategorized. |
| `FK_products_supplier` | `supplier_id` | `suppliers` | `supplier_id` | 1:N | Products may have a preferred supplier. NULL when not supplied. |
| `FK_product_images_product` | `product_id` | `products` | `product_id` | 1:N | A product can have many images (one marked primary). |

---

## 6. Module 06 — Suppliers

| FK | Child column(s) | Parent | Parent column | Cardinality | Purpose |
|----|------------------|--------|---------------|-------------|---------|
| `FK_supplier_contacts_supplier` | `supplier_id` | `suppliers` | `supplier_id` | 1:N | One supplier has many contacts. |
| `FK_supplier_history_supplier` | `supplier_id` | `suppliers` | `supplier_id` | 1:N | Append-only history events belong to a supplier. |

---

## 7. Module 07 — Inventory

| FK | Child column(s) | Parent | Parent column | Cardinality | Purpose |
|----|------------------|--------|---------------|-------------|---------|
| `FK_inventory_product` | `product_id` | `products` | `product_id` | 1:N | Each product has at most one current stock snapshot (unique). |
| `FK_inventory_transactions_product` | `product_id` | `products` | `product_id` | 1:N | Every stock movement belongs to a product. |
| `FK_stock_reconciliations_transaction` | `inventory_transaction_id` | `inventory_transactions` | `inventory_transaction_id` | 1:N | A physical reconciliation documents the movement it produced. |
| `FK_low_stock_alerts_product` | `product_id` | `products` | `product_id` | 1:N | Low-stock alerts are raised per product. |

---

## 8. Module 08 — Sales

| FK | Child column(s) | Parent | Parent column | Cardinality | Purpose |
|----|------------------|--------|---------------|-------------|---------|
| `FK_sales_user` | `user_id` | `users` | `user_id` | 1:N | The cashier who created the sale. |
| `FK_sales_tax_rate` | `tax_rate_id` | `tax_rates` | `tax_rate_id` | 1:N | The tax rate snapshot applied to the sale header. |
| `FK_sale_items_sale` | `sale_id` | `sales` | `sale_id` | 1:N | A sale consists of many line items. |
| `FK_sale_items_product` | `product_id` | `products` | `product_id` | 1:N | Each line item is a product sold. |

---

## 9. Module 09 — Payments

| FK | Child column(s) | Parent | Parent column | Cardinality | Purpose |
|----|------------------|--------|---------------|-------------|---------|
| `FK_payments_sale` | `sale_id` | `sales` | `sale_id` | 1:N | A sale can be paid by many payments (partial/multi-tender). |
| `FK_payments_payment_method` | `payment_method_id` | `payment_methods` | `payment_method_id` | 1:N | Each payment uses a tender type. |
| `FK_receipts_sale` | `sale_id` | `sales` | `sale_id` | 1:N | A sale can have one or more receipts generated. |

---

## 10. Module 10 — Credit Sales

| FK | Child column(s) | Parent | Parent column | Cardinality | Purpose |
|----|------------------|--------|---------------|-------------|---------|
| `FK_credit_sales_sale` | `sale_id` | `sales` | `sale_id` | 1:N | Each credit sale has exactly one credit ledger row (unique). |
| `FK_credit_sales_customer` | `customer_id` | `customers` | `customer_id` | 1:N | A credit balance belongs to a customer. |
| `FK_credit_payments_credit_sale` | `credit_sale_id` | `credit_sales` | `credit_sale_id` | 1:N | Many payments reduce a credit balance over time. |
| `FK_credit_payments_payment` | `payment_id` | `payments` | `payment_id` | 1:N | A credit payment may correspond to a receipted payment. |

---

## 11. Module 11 — Returns

| FK | Child column(s) | Parent | Parent column | Cardinality | Purpose |
|----|------------------|--------|---------------|-------------|---------|
| `FK_returns_sale` | `sale_id` | `sales` | `sale_id` | 1:N | A return always references the original sale. |
| `FK_returns_customer` | `customer_id` | `customers` | `customer_id` | 1:N | The customer returning goods (nullable for cash walk-ins). |
| `FK_returns_return_reason` | `return_reason_id` | `return_reasons` | `return_reason_id` | 1:N | The (optional) reason for the return. |
| `FK_return_items_return` | `return_id` | `returns` | `return_id` | 1:N | A return consists of many returned line items. |
| `FK_return_items_sale_item` | `sale_item_id` | `sale_items` | `sale_item_id` | 1:N | Each returned line references the original sale line (prevents over-returning). |
| `FK_return_items_product` | `product_id` | `products` | `product_id` | 1:N | Reporting convenience: the product returned. |

---

## 12. Module 12 — Notifications

| FK | Child column(s) | Parent | Parent column | Cardinality | Purpose |
|----|------------------|--------|---------------|-------------|---------|
| `FK_notifications_user` | `user_id` | `users` | `user_id` | 1:N | Notifications are delivered to a specific recipient. |
| `FK_notifications_type` | `notification_type_id` | `notification_types` | `notification_type_id` | 1:N | Each notification has a type (LOW_STOCK, SALE, ...). |
| `FK_notification_history_notification` | `notification_id` | `notifications` | `notification_id` | 1:N | Processing/delivery records per notification. |

---

## 13. Module 16 — Audit & Logging

| FK | Child column(s) | Parent | Parent column | Cardinality | Purpose |
|----|------------------|--------|---------------|-------------|---------|
| `FK_audit_logs_user` | `user_id` | `users` | `user_id` | 1:N | The actor who caused the audited change. |
| `FK_activity_logs_user` | `user_id` | `users` | `user_id` | 1:N | The user performing the activity. |
| `FK_security_logs_user` | `user_id` | `users` | `user_id` | 1:N | The subject of an authentication event (NULL for failed logins of unknown accounts). |
| `FK_error_logs_user` | `user_id` | `users` | `user_id` | 1:N | The user active when the error occurred. |

> Notifications also carry polymorphic `entity_type`/`entity_id` string
> references (see `DatabaseDesign.md` §2.1). These are **not** foreign keys
> by design — a notification may reference any resource.

---

## 14. Relationship Map (Module → Chain)

```
roles ─┬─< users ─┬─< user_sessions
       │           ├─< password_history
       │           ├─< password_resets
       │           ├─< notifications ──< notification_history
       │           ├─< audit_logs / activity_logs / security_logs / error_logs
       │           └─< sales (cashier)
       └─< role_permissions ──> permissions

categories ──< categories (self, parent_id)
categories ──< products ──< product_images
suppliers ───< products ──< inventory ──< low_stock_alerts
                     │     └─< inventory_transactions ──< stock_reconciliations
                     └─< sale_items ──> sales
tax_rates ──< sales ──< payments ──> payment_methods
sales ──< receipts
customers ──< credit_sales ──< credit_payments ──> payments
return_reasons ──< returns ──< return_items ──> sale_items, products
```

---

## 15. Why NO ACTION Is Correct Here

1. **Receipt/history integrity.** Cascade-deleting a `sales` row would
   silently destroy `sale_items`, `payments`, `receipts`, `returns` and
   audit records. Sales are immutable by law/accounting practice.
2. **Soft deletes.** Master records are never physically deleted; the app
   marks `is_deleted` and the FK remains satisfied.
3. **Surrogate immutability.** IDs never change, so `ON UPDATE CASCADE` is
   pointless.
4. **Explicit code.** Every procedure that must "delete" resolves the
   relationship explicitly in a transaction (e.g. `SP_DeleteCategory`
   checks for children; `SP_DeleteProduct` checks for sales).

When a delete is blocked by a child row, the calling procedure raises a
clear, catchable error (pattern: `THROW 500xx, '...', 1`) rather than
relying on an opaque FK violation.

---

## 16. Verification

The relationship catalogue is verified at build time by the integrity test
suite:

- `Testing/00_schema_integrity.sql` — asserts every FK in this document exists.
- `Testing/02_relationship_integrity.sql` — asserts NO ACTION on all FKs.
- `Testing/06_security_roles.sql` — asserts RBAC wiring (users→roles→permissions).

Run with `Testing/run_tests.sh` (see [`DeploymentGuide.md`](DeploymentGuide.md)).

---

## 17. Revision History

| Version | Date | Description |
|---------|------|-------------|
| 1.0 | 2026-08-07 | Initial relationship documentation |
