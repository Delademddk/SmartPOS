# SmartPOS — Functional Requirements

**Document ID:** DOC-FR-005  
**Version:** 1.0  
**Status:** Approved  
**Author:** SmartPOS Documentation Team  
**Date:** August 7, 2026  

---

## 1. Purpose

This document defines all **functional requirements** for the SmartPOS
Enterprise POS & Inventory Management System. Each requirement corresponds to
a system feature that must be implemented, tested, and traceable to user
stories ([08_User_Stories](../08_User_Stories/README.md)) and use cases
([09_Use_Cases](../09_Use_Cases/README.md)).

### Document Conventions

- **FR** = Functional Requirement
- **REQ-INPUT** = Input to the system
- **REQ-OUTPUT** = Output from the system
- **REQ-VALIDATION** = Validation rules
- **REQ-DEPENDENCY** = Dependency on another module/rule

---

## Products

### FR-01: Product Listing (Admin & Cashier)

| Attribute | Detail |
|-----------|--------|
| ID | FR-01 |
| Description | List all products with pagination, filtering by category/SKU, and sorting |
| REQ-INPUT | Page number, page size, category filter, SKU filter, sort field, sort direction |
| REQ-OUTPUT | Paginated list of products with `product_id`, `sku`, `name`, `description`, `price`, `cost`, `stock_quantity`, `category_id`, `supplier_id`, `created_at` |
| REQ-VALIDATION | Page ≥ 1; page_size 1–100; sort field must be a valid column |
| REQ-DEPENDENCY | Authentication middleware |
| References | [BR-01](../10_Business_Rules/README.md), [09_Use_Cases — Product CRUD](../09_Use_Cases/README.md#product-crud) |

### FR-02: Product Search

| Attribute | Detail |
|-----------|--------|
| ID | FR-02 |
| Description | Search products by SKU, name, or barcode |
| REQ-INPUT | Search query (min 2 characters) |
| REQ-OUTPUT | Matching products with full details |
| REQ-VALIDATION | Query length ≥ 2 characters |
| REQ-DEPENDENCY | None |
| References | [08_User_Stories — Search products](.../../08_User_Stories/README.md) |

### FR-03: Create Product (Admin)

| Attribute | Detail |
|-----------|--------|
| ID | FR-03 |
| Description | Add a new product to the system |
| REQ-INPUT | `sku` (unique, required), `name` (required), `description`, `price` (≥ 0, required), `cost` (≥ 0), `stock_quantity` (≥ 0, default 0), `category_id` (FK), `supplier_id` (FK), `low_stock_threshold` (default 0) |
| REQ-OUTPUT | Created product with `product_id` and timestamps |
| REQ-VALIDATION | SKU must be unique; price/cost/stock must be non-negative numbers; category and supplier must exist |
| REQ-DEPENDENCY | Categories module, Suppliers module |
| References | [BR-01](..//10_Business_Rules/README.md) |

### FR-04: Read Product (Admin & Cashier)

| Attribute | Detail |
|-----------|--------|
| ID | FR-04 |
| Description | Retrieve full details of a single product |
| REQ-INPUT | `product_id` (path parameter) |
| REQ-OUTPUT | Product details including related category and supplier names |
| REQ-VALIDATION | Product must exist; returns 404 if not found |
| REQ-DEPENDENCY | None |
| References | [FR-01](#fr-01-product-listing-admin--cashier) |

### FR-05: Update Product (Admin)

| Attribute | Detail |
|-----------|--------|
| ID | FR-05 |
| Description | Modify an existing product's details |
| REQ-INPUT | `product_id` (path), body with fields to update |
| REQ-OUTPUT | Updated product |
| REQ-VALIDATION | Product must exist; SKU uniqueness enforced; all validation rules of FR-03 |
| REQ-DEPENDENCY | FR-03 |
| References | [11_Workflows — Edit Product](../11_System_Workflows/README.md#edit-product-workflow) |

### FR-06: Delete Product (Admin)

| Attribute | Detail |
|-----------|--------|
| ID | FR-06 |
| Description | Soft-delete a product (mark as inactive) |
| REQ-INPUT | `product_id` (path) |
| REQ-OUTPUT | Success confirmation; product remains in DB with `is_deleted = true` |
| REQ-VALIDATION | Product must exist; cannot delete if referenced by open sales |
| REQ-DEPENDENCY | BR-09 (soft deletes) |
| References | [BR-09](../10_Business_Rules/README.md) |

### FR-07: Product Stock Adjustment (Admin)

| Attribute | Detail |
|-----------|--------|
| ID | FR-07 |
| Description | Manually adjust stock quantity (e.g., for damaged goods) |
| REQ-INPUT | `product_id`, `adjustment` (signed integer), `reason` |
| REQ-OUTPUT | Updated product with new `stock_quantity`; new stock movement log entry |
| REQ-VALIDATION | Resulting stock must be ≥ 0; requires reason |
| REQ-DEPENDENCY | Stock Movement Tracking module |
| References | [BR-04](../10_Business_Rules/README.md) |

---

## Categories

### FR-08: List Categories (Admin & Cashier)

| Attribute | Detail |
|-----------|--------|
| ID | FR-08 |
| Description | Retrieve all categories in hierarchical order |
| REQ-INPUT | None (optional parent filter) |
| REQ-OUTPUT | List of categories with `category_id`, `name`, `parent_id`, `description` |
| REQ-VALIDATION | None |
| REQ-DEPENDENCY | None |
| References | [FR-01](#fr-01-product-listing-admin--cashier) |

### FR-09: Create Category (Admin)

| Attribute | Detail |
|-----------|--------|
| ID | FR-09 |
| Description | Add a new product category |
| REQ-INPUT | `name` (required, unique), `parent_id` (optional, self-referencing), `description` |
| REQ-OUTPUT | Created category with `category_id` |
| REQ-VALIDATION | Name must be unique at the same level; circular hierarchy prevented |
| REQ-DEPENDENCY | None |
| References | [FR-03](#fr-03-create-product-admin) |

### FR-10: Update Category (Admin)

| Attribute | Detail |
|-----------|--------|
| ID | FR-10 |
| Description | Modify a category |
| REQ-INPUT | `category_id` (path), body fields |
| REQ-OUTPUT | Updated category |
| REQ-VALIDATION | Category must exist; name uniqueness enforced |
| REQ-DEPENDENCY | FR-09 |
| References | — |

### FR-11: Delete Category (Admin)

| Attribute | Detail |
|-----------|--------|
| ID | FR-11 |
| Description | Remove a category (soft delete); prevent deletion if child categories or products exist |
| REQ-INPUT | `category_id` (path) |
| REQ-OUTPUT | Success confirmation |
| REQ-VALIDATION | Category must exist; no children must reference it |
| REQ-DEPENDENCY | BR-09 |
| References | [BR-09](../10_Business_Rules/README.md) |

---

## Suppliers

### FR-12: List Suppliers (Admin)

| Attribute | Detail |
|-----------|--------|
| ID | FR-12 |
| Description | Retrieve all suppliers |
| REQ-INPUT | None |
| REQ-OUTPUT | List with `supplier_id`, `name`, `contact_person`, `email`, `phone`, `address` |
| REQ-VALIDATION | None |
| REQ-DEPENDENCY | None |
| References | — |

### FR-13: Create Supplier (Admin)

| Attribute | Detail |
|-----------|--------|
| ID | FR-13 |
| Description | Add a new supplier |
| REQ-INPUT | `name` (required), `contact_person`, `email`, `phone`, `address` |
| REQ-OUTPUT | Created supplier |
| REQ-VALIDATION | Name must be unique; email must be valid format |
| REQ-DEPENDENCY | None |
| References | — |

### FR-14: Update Supplier (Admin)

| Attribute | Detail |
|-----------|--------|
| ID | FR-14 |
| Description | Modify supplier details |
| REQ-INPUT | `supplier_id` (path), body fields |
| REQ-OUTPUT | Updated supplier |
| REQ-VALIDATION | Supplier must exist; name uniqueness enforced |
| REQ-DEPENDENCY | FR-13 |
| References | — |

### FR-15: Delete Supplier (Admin)

| Attribute | Detail |
|-----------|--------|
| ID | FR-15 |
| Description | Soft-delete a supplier |
| REQ-INPUT | `supplier_id` (path) |
| REQ-OUTPUT | Success confirmation |
| REQ-VALIDATION | Supplier must exist; cannot delete if products reference it |
| REQ-DEPENDENCY | BR-09 |
| References | — |

---

## Inventory

### FR-16: View Inventory (Admin)

| Attribute | Detail |
|-----------|--------|
| ID | FR-16 |
| Description | View current stock quantities with status (in stock, low stock, out of stock) |
| REQ-INPUT | Filter by category, product name; sort by quantity, name |
| REQ-OUTPUT | List of products with `sku`, `name`, `stock_quantity`, `low_stock_threshold`, `status` |
| REQ-VALIDATION | None |
| REQ-DEPENDENCY | Products module |
| References | [BR-01](../10_Business_Rules/README.md), [FR-07](#fr-07-product-stock-adjustment-admin) |

### FR-17: Restock Product (Admin)

| Attribute | Detail |
|-----------|--------|
| ID | FR-17 |
| Description | Increase stock for a product via restock entry |
| REQ-INPUT | `product_id` (required), `quantity` (required, > 0), `reference_number` (optional), `notes` (optional) |
| REQ-OUTPUT | Updated product stock; new stock movement log |
| REQ-VALIDATION | Product must exist; quantity > 0 |
| REQ-DEPENDENCY | Stock Movement Tracking, Notifications |
| References | [BR-02](../10_Business_Rules/README.md), [FR-07](#fr-07-product-stock-adjustment-admin) |

### FR-18: View Stock Movement History (Admin)

| Attribute | Detail |
|-----------|--------|
| ID | FR-18 |
| Description | View chronological log of all inventory changes |
| REQ-INPUT | Filter by product, date range, movement type (sale, restock, adjustment, return) |
| REQ-OUTPUT | List with `product_id`, `quantity`, `type`, `reference_id`, `user_id`, `timestamp`, `reason` |
| REQ-VALIDATION | None |
| REQ-DEPENDENCY | BR-04 |
| References | [13_Database_Overview — Tables](../13_Database_Overview/README.md) |

---

## Sales

### FR-19: Create Sale (Cashier)

| Attribute | Detail |
|-----------|--------|
| ID | FR-19 |
| Description | Process a new sale with cart, payment, and receipt |
| REQ-INPUT | List of `product_id` + `quantity` per item, `payment_method` (cash/card), `amount_tendered`, `discount` (optional), `is_credit` (boolean) |
| REQ-OUTPUT | Created sale with `sale_id`, totals, transaction records, receipt number |
| REQ-VALIDATION | Each product must exist; quantity > 0; `stock_quantity >= quantity` for each item; total calculated and verified; payment amount must cover total (or credit) |
| REQ-DEPENDENCY | Products, Credit Sales, Returns, Audit Trail |
| References | [BR-06](../10/Business_Rules/README.md) |

> **Error cases:** If any item's stock is insufficient, the sale is rejected
> with HTTP 409 and an error detailing which products are out of stock.

### FR-20: View Sales (Admin)

| Attribute | Detail |
|-----------|--------|
| ID | FR-20 |
| Description | Admin views all sales with filtering and pagination |
| REQ-INPUT | Page, page_size, date_from, date_to, cashier_id, payment_method |
| REQ-OUTPUT | Paginated sales with totals, cashier, timestamp, status |
| REQ-VALIDATION | Date range valid; pagination valid |
| REQ-DEPENDENCY | Authentication, RBAC |
| References | [FR-19](#fr-19-create-sale-cashier) |

### FR-21: View Own Sales (Cashier)

| Attribute | Detail |
|-----------|--------|
| ID | FR-21 |
| Description | Cashier views only sales they created |
| REQ-INPUT | Same filters as FR-20, automatically filtered by cashier's user_id |
| REQ-OUTPUT | Paginated sales list |
| REQ-VALIDATION | RBAC — cashier cannot see other users' sales |
| REQ-DEPENDENCY | FR-20, RBAC |
| References | [07_User_Roles](../07_User_Roles_and_Permissions/README.md) |

### FR-22: Void Sale (Admin)

| Attribute | Detail |
|-----------|--------|
| ID | FR-22 |
| Description | Void a completed sale and restore inventory |
| REQ-INPUT | `sale_id` (path), `reason` |
| REQ-OUTPUT | Sale marked voided; inventory restored |
| REQ-VALIDATION | Sale must exist and be in a voidable state (same day, not already voided) |
| REQ-DEPENDENCY | BR-03 (returns restore inventory), Audit Trail |
| References | [BR-03](../10_Business_Rules/README.md) |

---

## Returns

### FR-23: Process Return (Admin)

| Attribute | Detail |
|-----------|--------|
| ID | FR-23 |
| Description | Return items from a previously completed sale |
| REQ-INPUT | `sale_id` (path), list of `product_id` + `quantity`, `reason`, `refund_method` |
| REQ-OUTPUT | Return record with `return_id`, updated sale total, restored inventory |
| REQ-VALIDATION | Sale must exist; each returned product must have been in the original sale; quantity ≤ sold quantity; cannot return already-returned items |
| REQ-DEPENDENCY | FR-19 (sales), BR-03, Stock Movement |
| References | [BR-03](../10_Business_Rules/README.md), [11_Workflows — Return Sale](../11_System_Workflows/README.md#return-sale-workflow) |

### FR-24: View Returns (Admin)

| Attribute | Detail |
|-----------|--------|
| ID | FR-24 |
| Description | List all returns with filtering |
| REQ-INPUT | Page, date range, product filter |
| REQ-OUTPUT | Paginated returns with product, quantity, refund amount, reason, timestamp |
| REQ-VALIDATION | None |
| REQ-DEPENDENCY | FR-23 |
| References | — |

---

## Credit Sales

### FR-25: Credit Sale Recording

| Attribute | Detail |
|-----------|--------|
| Description | When `is_credit = true`, the sale is recorded but the customer balance increases |
| REQ-INPUT | Same as FR-19 with `is_credit = true`, plus optional `customer_name` |
| REQ-OUTPUT | Sale recorded; credit balance created for customer |
| REQ-VALIDATION | Credit limit check (configurable); daily credit limit per cashier |
| REQ-DEPENDENCY | BR-07, Users module |
| References | [BR-07](../10_Business_Rules/README.md) |

### FR-26: View Customer Credit Balances

| Attribute | Detail |
|-----------|--------|
| Description | Admin views all outstanding credit balances |
| REQ-INPUT | Filter by customer name, date range |
| REQ-OUTPUT | List of customers with outstanding balances |
| REQ-VALIDATION | None |
| REQ-DEPENDENCY | FR-25 |
| References | [15_Report — Sales Summary](./05_File_...) — see Reports |

### FR-27: Settle Credit Balance

| Attribute | Detail |
|-----------|--------|
| Description | Record a partial or full payment against a customer's credit balance |
| REQ-INPUT | `customer_id`, `amount` (≤ balance) |
| REQ-OUTPUT | Updated balance; payment record |
| REQ-VALIDATION | Amount ≤ outstanding balance; amount > 0 |
| REQ-DEPENDENCY | FR-25 |
| References | — |

---

## Users

### FR-28: Create User (Admin)

| Attribute | Detail |
|-----------|--------|
| ID | FR-28 |
| Description | Admin creates a new user (cashier or admin) |
| REQ-INPUT | `username` (required, unique), `full_name` (required), `email` (required, valid), `phone`, `role` (admin/cashier) |
| REQ-OUTPUT | Created user with temporary password; user must change password on first login |
| REQ-VALIDATION | Username unique; email valid format; role valid |
| REQ-DEPENDENCY | BR-05 (password hashing), RBAC |
| References | [07_User_Roles](..//07_User_Roles_and_Permissions/README.md) |

### FR-29: Deactivate User (Admin)

| Attribute | Detail |
|-----------|--------|
| ID | FR-29 |
| Description | Deactivate a user (soft delete — cannot log in) |
| REQ-INPUT | `user_id` (path) |
| REQ-OUTPUT | User marked `is_active = false` |
| REQ-VALIDATION | User must exist; cannot deactivate self |
| REQ-DEPENDENCY | RBAC |
| References | — |

### FR-30: Reset Password (Admin)

| Attribute | Detail |
|-----------|--------|
| ID | FR-30 |
| Description | Admin resets a user's password |
| REQ-INPUT | `user_id` (path), generates new temporary password (sent via configured channel) |
| REQ-OUTPUT | User's password hash replaced; user must change on next login |
| REQ-VALIDATION | User must exist; cannot reset own password (must use change-password flow) |
| REQ-DEPENDENCY | BR-05 |
| References | — |

### FR-31: Change Own Password (Cashier & Admin)

| Attribute | Detail |
|-----------|--------|
| ID | FR-31 |
| Description | User changes their own password |
| REQ-INPUT | `current_password`, `new_password`, `confirm_password` |
| REQ-OUTPUT | Password hash updated |
| REQ-VALIDATION | Current password verified; new password ≥ 8 chars, includes uppercase, lowercase, digit, special char |
| REQ-DEPENDENCY | BR-05 |
| References | — |

### FR-32: List Users (Admin)

| Attribute | Detail |
|-----------|--------|
| ID | FR-32 |
| Description | Admin views all users |
| REQ-INPUT | None |
| REQ-OUTPUT | List with `user_id`, `username`, `full_name`, `email`, `phone`, `role`, `is_active`, `created_at` |
| REQ-VALIDATION | RBAC — Admin only |
| REQ-DEPENDENCY | RBAC |
| References | — |

---

## Stock Movement Tracking

### FR-33: Log Stock Movement (System)

| Attribute | Detail |
|-----------|--------|
| ID | FR-33 |
| Description | Every inventory change creates a stock movement log entry |
| REQ-INPUT | `product_id`, `quantity` (signed), `movement_type` (sale, restock, adjustment, return, void), `reference_id` (sale_id/return_id/etc.), `user_id`, `reason` (optional) |
| REQ-OUTPUT | Stock movement record in `stock_movements` table |
| REQ-VALIDATION | All fields required except reason |
| REQ-DEPENDENCY | BR-04, Database triggers |
| References | [BR-04](../10_Business_Rules/README.md), [13_Database_Overview](../13_Database_Overview/README.md) |

### FR-34: Query Stock Movements (Admin)

| Attribute | Detail |
|-----------|--------|
| ID | FR-34 |
| Description | Query stock movement history with full filtering |
| REQ-INPUT | Filters: product, date range, movement type, user |
| REQ-OUTPUT | Paginated list of movements |
| REQ-VALIDATION | None |
| REQ-DEPENDENCY | FR-33 |
| References | [FR-18](#fr-18-view-stock-movement-history-admin) |

---

## Reports

### FR-35: Sales Summary Report

| Attribute | Detail |
|-----------|--------|
| ID | FR-35 |
| Description | Aggregated sales data by period |
| REQ-INPUT | `date_from`, `date_to` |
| REQ-OUTPUT | Total sales count, total revenue, total items sold, breakdown by payment method |
| REQ-VALIDATION | Date range required and valid |
| REQ-DEPENDENCY | Sales module |
| References | [04_Business_Requirements — §6](../04_Business_Requirements/README.md#6-reporting-requirements) |

### FR-36: Inventory Health Report

| Attribute | Detail |
|-----------|--------|
| ID | FR-36 |
| Description | Current stock levels with threshold status |
| REQ-INPUT | None |
| REQ-OUTPUT | List of all products with `stock_quantity`, `low_stock_threshold`, and status |
| REQ-VALIDATION | None |
| REQ-DEPENDENCY | Inventory module |
| References | — |

### FR-37: Export Report

| Attribute | Detail |
|-----------|--------|
| ID | FR-37 |
| Description | Export any report to Excel (.xlsx) or PDF |
| REQ-INPUT | `report_type`, `format` (xlsx/pdf), `filters` |
| REQ-OUTPUT | File download |
| REQ-VALIDATION | Format must be xlsx or pdf; report_type must be valid |
| REQ-DEPENDENCY | FR-35, FR-36 |
| References | — |

---

## Dashboards

### FR-38: Admin Dashboard

| Attribute | Detail |
|-----------|--------|
| ID | FR-38 |
| Description | Display KPIs: total sales today, total revenue, low stock count, active users |
| REQ-INPUT | None (auto-refresh every 60s) |
| REQ-OUTPUT | Dashboard data JSON |
| REQ-VALIDATION | RBAC — Admin only |
| REQ-DEPENDENCY | FR-01, FR-16, FR-35 |
| References | [17_UI_UX_Specification — Admin Dashboard](../17_UI_UX_Specification/README.md#admin-dashboard) |

### FR-39: Cashier Dashboard

| Attribute | Detail |
|-----------|--------|
| ID | FR-39 |
| Description | Display today's sales count, total revenue, items sold |
| REQ-INPUT | None |
| REQ-OUTPUT | Dashboard data JSON |
| REQ-VALIDATION | RBAC — Cashier only sees own data |
| REQ-DEPENDENCY | FR-21 |
| References | [17_UI_UX_Specification — Cashier Dashboard](../17_UI_UX_Specification/README.md#cashier-dashboard) |

---

## Notifications

### FR-40: Low-Stock Notification (System)

| Attribute | Detail |
|-----------|--------|
| ID | FR-40 |
| Description | When stock falls at or below threshold, create a notification |
| REQ-INPUT | Triggered automatically by stock movement (sale or adjustment) |
| REQ-OUTPUT | Notification in `notifications` table for Admin users |
| REQ-VALIDATION | Threshold check: `stock_quantity <= low_stock_threshold` |
| REQ-DEPENDENCY | BR-08, Stock Movement |
| References | [BR-08](../10_Business_Rules/README.md) |

### FR-41: View Notifications (All Users)

| Attribute | Detail |
|-----------|--------|
| ID | FR-41 |
| Description | Users can view their notifications |
| REQ-INPUT | Page, page_size, `is_read` filter |
| REQ-OUTPUT | Paginated notifications with `id`, `title`, `message`, `type`, `is_read`, `created_at` |
| REQ-VALIDATION | None |
| REQ-DEPENDENCY | RBAC |
| References | — |

### FR-42: Mark Notification Read

| Attribute | Detail |
|-----------|--------|
| ID | FR-42 |
| Description | Mark a notification as read |
| REQ-INPUT | `notification_id` (path) |
| REQ-OUTPUT | Notification `is_read = true` |
| REQ-VALIDATION | Notification must belong to the user |
| REQ-DEPENDENCY | RB-41 |
| References | — |

---

## Settings

### FR-43: View Settings (Admin)

| Attribute | Detail |
|-----------|--------|
| ID | FR-43 |
| Description | View all system settings |
| REQ-INPUT | None |
| REQ-OUTPUT | List of key-value pairs |
| REQ-VALIDATION | RBAC — Admin only |
| REQ-DEPENDENCY | RBAC |
| References | — |

### FR-44: Update Setting (Admin)

| Attribute | Detail |
|-----------|--------|
| ID | FR-44 |
| Description | Update a setting value |
| REQ-INPUT | `key`, `value`, `type` (string, integer, boolean, json) |
| REQ-OUTPUT | Updated setting |
| REQ-VALIDATION | Key must exist; type must match value |
| REQ-DEPENDENCY | FR-43 |
| References | — |

### FR-45: Define Low Stock Threshold (System Setting)

| Attribute | Detail |
|-----------|--------|
| ID | FR-45 |
| Description | A per-product `low_stock_threshold` controls when BR-08 triggers |
| REQ-INPUT | Set during product creation/update or via system default |
| REQ-OUTPUT | — |
| REQ-VALIDATION | Threshold ≥ 0 |
| REQ-DEPENDENCY | FR-40, BR-08 |
| References | [BR-08](../10_Business_Rules/README.md) |

---

## Authentication

### FR-46: Login

| Attribute | Detail |
|-----------|--------|
| ID | FR-46 |
| Description | Authenticate user and issue JWT access + refresh tokens |
| REQ-INPUT | `username`, `password` |
| REQ-OUTPUT | `access_token`, `refresh_token`, `expires_in`, user profile |
| REQ-VALIDATION | Credentials verified; account must be active; rate limiting applied |
| REQ-DEPENDENCY | BR-05, RBAC |
| References | [18_Security_Architecture — §2](../18_Security_Architecture/README.md#2-authentication) |

### FR-47: Refresh Token

| Attribute | Detail |
|-----------|--------|
| ID | FR-47 |
| Description | Issue a new access token using a valid refresh token |
| REQ-INPUT | `refresh_token` |
| REQ-OUTPUT | New `access_token`, `expires_in` |
| REQ-VALIDATION | Refresh token must be valid and not revoked |
| REQ-DEPENDENCY | FR-46 |
| References | — |

### FR-48: Logout

| Attribute | Detail |
|-----------|--------|
| ID | FR-48 |
| Description | Invalidate both access and refresh tokens |
| REQ-INPUT | `refresh_token` (or token header) |
| REQ-OUTPUT | Success confirmation |
| REQ-VALIDATION | Token must be valid |
| REQ-DEPENDENCY | FR-46 |
| References | — |

---

## Audit Trail

### FR-49: Log Action (System)

| Attribute | Detail |
|-----------|--------|
| ID | FR-49 |
| Description | Every significant action is logged to the `audit_logs` table |
| REQ-INPUT | `user_id`, `action_type` (create/update/delete/login/logout/etc.), `resource_type`, `resource_id`, `timestamp`, `ip_address` |
| REQ-OUTPUT | Audit log entry |
| REQ-VALIDATION | All fields required |
| REQ-DEPENDENCY | BR-10 |
| References | [BR-10](../10_Business_Rules/README.md) |

### FR-50: View Audit Logs (Admin)

| Attribute | Detail |
|-----------|--------|
| ID | FR-50 |
| Description | Admin can query audit logs |
| REQ-INPUT | Filters: date range, user, action_type, resource_type |
| REQ-OUTPUT | Paginated audit log entries |
| REQ-VALIDATION | RBAC — Admin only |
| REQ-DEPENDENCY | FR-49 |
| References | — |

---

## References

- [SMARTPOS_PROJECT_BIBLE.md](../AI/SMARTPOS_PROJECT_BIBLE.md)
- [08_User_Stories](../08_User_Stories/README.md)
- [09_Use_Cases](../09_Use_Cases/README.md)
- [10_Business_Rules](../10_Business_Rules/README.md)
- [07_User_Roles_and_Permissions](../07_User_Roles_and_Permissions/README.md)
- [18_Security_Architecture](../18_Security_Architecture/README.md)

---

## Revision History

| Version | Date | Author | Description |
|---------|------|--------|-------------|
| 1.0 | 2026-08-07 | SmartPOS Documentation Team | Initial release |
