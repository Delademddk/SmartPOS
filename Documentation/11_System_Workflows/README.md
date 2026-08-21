# SmartPOS — System Workflows

**Document ID:** DOC-SW-011  
**Version:** 1.0  
**Status:** Approved  
**Author:** SmartPOS Documentation Team  
**Date:** August 7, 2026  

---

## 1. Purpose

This document describes the **step-by-step system workflows** for key
business processes in SmartPOS. Each workflow is traceable to
[Use Cases](../09_Use_Cases/README.md), [Functional Requirements](../05_Functional_Requirements/README.md),
and [Business Rules](../10_Business_Rules/README.md).

---

## 2. Login Workflow

```
┌──────────────┐     ┌────────────────┐     ┌─────────────────┐
│   Cashier    │     │    Backend     │     │   Database      │
└──────────────┘     └────────────────┘     └─────────────────┘
      │                     │                        │
      │ 1. Enter creds      │                        │
      ├────────────────────>│                        │
      │                     │ 2. Validate credentials│
      │                     ├────────────────────────>│
      │                     │ 3. Check is_active      │
      │                     │<────────────────────────┤
      │                     │ 4. Hash verify bcrypt   │
      │                     ├────────────────────────>│
      │                     │ 5. Generate JWT tokens  │
      │                     │ 6. Log login (audit)    │
      │                     ├────────────────────────>│
      │    7. Return tokens │                        │
      │<────────────────────┤                        │
      │ 8. Redirect to      │                        │
      │    role dashboard   │                        │
      │<────────────────────┤                        │
      │                     │ 9. Log notification   │
      │                     ├────────────────────────>│
      │                     │ (optional welcome)      │
      │                     │<────────────────────────┤
```

**Decision Points:**
- Invalid credentials → return 401.
- Account deactivated → return 403.
- Too many attempts → return 429.

**Related:** [UC-01](../09_Use_Cases/README.md#3-use-case-login-uc-01), [FR-46](../05_Functional_Requirements/README.md#fr-46-login)

---

## 3. Create Product Workflow

```
User (Admin) → UI Form → Frontend Validation (Zod) → API POST /products
  → Backend Validation (Pydantic) → Service Layer
  → Repository Layer → DB Transaction (SQL Server)
  → Insert product → Log audit → Return created product
  → UI shows success → Redirect to product list
```

**Decision Points:**
- SKU duplicate → 400 error with message.
- Category/supplier not found → 404 error.
- Price/cost < 0 → 422 validation error.

**Related:** [UC-06](../09_Use_Cases/README.md#8-use-case-product-crud-uc-06-09), [FR-03](../05_Functional_Requirements/README.md#fr-03-create-product-admin)

---

## 4. Edit Product Workflow

```
User (Admin) → UI Form (pre-filled) → Frontend Validation → API PUT /products/{id}
  → Backend Validation → Service Layer → Repository → DB Transaction
  → Update product → Log audit → Return updated product
  → UI shows success → Redirect to product list
```

**Decision Points:**
- Product not found → 404.
- SKU conflicts with another product → 400.
- Referenced by open sales → may restrict certain field changes (configurable).

**Related:** [UC-08](../09_Use_Cases/README.md#8-use-case-product-crud-uc-06-09), [FR-05](../05_Functional_Requirements/README.md#fr-05-update-product-admin)

---

## 5. Create Category Workflow

```
User (Admin) → UI Form → API POST /categories
  → Backend Validation → Service → Repository → DB
  → Check name uniqueness at level → Prevent circular hierarchy
  → Insert → Log audit → Return created category
```

**Related:** [UC-10](../09_Use_Cases/README.md#9-use-case-category-crud-uc-10-12), [FR-09](../05_Functional_Requirements/README.md#fr-09-create-category-admin)

---

## 6. Create Supplier Workflow

```
User (Admin) → UI Form → API POST /suppliers
  → Backend Validation → Service → Repository → DB
  → Check name uniqueness → Validate email format
  → Insert → Log audit → Return created supplier
```

**Related:** [UC-13](../09_Use_Cases/README.md#10-use-case-supplier-crud-uc-13-15), [FR-13](../05_Functional_Requirements/README.md#fr-13-create-supplier-admin)

---

## 7. Restock Workflow

```
Admin → Inventory Page → Click "Restock" → Modal Form (qty, ref, notes)
  → Submit → API POST /inventory/restock
  → Service → Begin Transaction:
    1. Get product
    2. Check product exists (404 if not)
    3. Validate quantity > 0 (422 if not)
    4. Update stock_quantity += quantity
    5. Insert stock_movement (type=restock)
    6. Check low_stock_threshold: if now above threshold, mark notifications read
    7. Log audit entry
  → Commit Transaction → Return updated stock
  → UI refreshes inventory → Shows success toast
```

**Decision Points:**
- Quantity ≤ 0 → reject.
- Product not found → 404.

**Related:** [UC-17](../09_Use_Cases/README.md#12-use-case-restock-uc-17), [FR-17](../05_Functional_Requirements/README.md#fr-17-restock-product-admin)

---

## 8. Create Sale Workflow

```
Cashier → New Sale Page → Search Products → Add to Cart → Apply Discount
  → Select Payment (cash/card/credit) → Enter Amount Tendered
  → Click "Complete Sale" → API POST /sales
  → Service → Begin Transaction:
    1. Validate all products exist and have sufficient stock
    2. Create sale header (sale_id, receipt_number, cashier_id, timestamp, totals)
    3. Create sale_items for each cart item
    4. Decrement stock_quantity for each product
    5. Insert stock_movement entries (type=sale)
    6. If credit: create/update credit_balance
    7. Log audit entry
  → Commit Transaction
  → Generate receipt number (already done in step 2)
  → Return sale + receipt URL
  → Frontend prints receipt or shows confirmation
```

**Decision Points:**
- Insufficient stock → 409 with list of out-of-stock products.
- Payment < total and not credit → 422.
- Product removed between add and submit → 409.

**Related:** [UC-18](../09_Use_Cases/README.md#13-use-case-create-sale-uc-18), [FR-19](../05_Functional_Requirements/README.md#fr-19-create-sale-cashier), [BR-SALE-01](../10_Business_Rules/README.md#br-sale-01-inventory-decreases-after-sales)

---

## 9. Return Sale Workflow

```
User → Returns Page → Search Past Sale by Receipt #
  → Select Sale → UI Shows Items
  → Select Items to Return + Quantities
  → Enter Reason + Refund Method
  → Click "Process Return" → API POST /returns
  → Service → Begin Transaction:
    1. Validate sale exists and not voided
    2. Validate return quantities ≤ available-to-return quantities
    3. Create return record (return_id, original_sale_id, reason, cashier_id)
    4. Create return_items for each returned item
    5. Restore stock_quantity for each product
    6. Insert stock_movement entries (type=return)
    7. Log audit entry
  → Commit Transaction
  → Generate return receipt
  → UI shows success
```

**Decision Points:**
- Return quantity > available-to-return → 400.
- Sale not found → 404.
- Sale voided → 422.

**Related:** [UC-22](../09_Use_Cases/README.md#17-use-case-process-return-uc-22), [FR-23](../05_Functional_Requirements/README.md#fr-23-process-return-admin), [BR-RET-01](../10_Business_Rules/README.md)

---

## 10. Generate Report Workflow

```
Admin → Reports Page → Select Report Type → Set Filters → Click "Generate"
  → API POST /reports/generate
  → Service → Query Database (Views/Stored Procs)
  → Aggregate Data → Format Response
  → Return Report Data
  → UI Renders Report Table / Chart
  → Admin Clicks "Export" → API GET /reports/export?format=xlsx
  → Service → Generate Excel/PDF → Return File
```

**Related:** [UC-25](../09_Use_Cases/README.md#20-use-case-generate-report-uc-25), [FR-35](../05_Functional_Requirements/README.md#fr-35-sales-summary-report)

---

## 11. Manage Users Workflow

```
Admin → Users Page → Click "Create User" → Modal Form
  → Fill (username, name, email, phone, role) → Submit
  → API POST /users → Validate → Hash temp password → Create
  → Log audit → Return user + temp password
  → UI shows temp password (copy to clipboard)
  → User receives temp password → Must change on first login
```

Deactivate flow:
```
Admin → Click user's "Deactivate" → Confirmation Modal → Confirm
  → API DELETE /users/{id} (soft) → Log audit → UI refreshes
```

Reset password flow:
```
Admin → Click user's "Reset Password" → System generates new temp password
  → Hash → Update → Log audit → Show to admin
```

**Related:** [UC-04](../09_Use_Cases/README.md#6-use-case-create-user-uc-04), [FR-28](../05_Functional_Requirements/README.md#fr-28-create-user-admin)

---

## 12. Change Password Workflow

```
User (any) → Profile / Settings → "Change Password"
  → Enter current password, new password, confirm
  → API PUT /users/me/password
  → Service: Validate current → Validate new (complexity) → Hash → Update
  → Log audit → Return success
  → UI shows success toast
```

**Related:** [UC-03](../09_Use_Cases/README.md#5-use-case-change-password-uc-03), [FR-31](../05_Functional_Requirements/README.md#fr-31-change-own-password-cashier--admin)

---

## 13. Notifications Workflow

```
Trigger (Stock Movement) → DB Trigger AFTER INSERT/UPDATE
  → Check stock_quantity <= low_stock_threshold
  → Check no existing unread notification for this product
  → Insert notification record for each Admin user
  → Log audit entry

User → Clicks Notification Bell → API GET /notifications
  → Service → Query notifications for user (unread first)
  → Return paginated list
  → User clicks → Mark as read (API PUT /notifications/{id}/read)
  → Log audit
```

**Related:** [UC-27](../09_Use_Cases/README.md#21-use-case-view-notifications-uc-27), [FR-40](../05_Functional_Requirements/README.md#fr-40-low-stock-notification-system), [BR-NOT-01](../10_Business_Rules/README.md)

---

## 14. Dashboard Workflow

```
Login → Redirect to role-specific dashboard
  → API GET /dashboard/admin (Admin) or /dashboard/cashier (Cashier)
  → Service → Query KPIs from database views
  → Aggregate → Return data
  → UI renders charts/cards
  → Auto-refresh every 60 seconds (polling)
  → Click KPI → Navigate to detail page
```

Admin Dashboard KPIs:
- Today's total sales
- Today's revenue
- Low-stock product count
- Active user count

Cashier Dashboard KPIs:
- Today's personal sales count
- Today's personal revenue
- Items sold today

**Related:** [UC-26](../09_Use_Cases/README.md#22-use-case-view-dashboard-uc-26-for-admin--uc-15-for-cashier), [FR-38](../05_Functional_Requirements/README.md#fr-38-admin-dashboard), [FR-39](../05_Functional_Requirements/README.md#fr-39-cashier-dashboard)

---

## 15. Settings Workflow

```
Admin → Settings Page → API GET /settings
  → Service → Query settings table → Return all key-values
  → UI renders editable table

Admin edits a setting → Click Save
  → API PUT /settings/{key}
  → Service → Validate type → Update → Log audit → Return updated
  → UI shows success
```

**Related:** [UC-28](../09_Use_Cases/README.md#23-use-case-manage-settings-uc-28), [FR-43](../05_Functional_Requirements/README.md#fr-43-view-settings-admin), [FR-44](../05_Functional_Requirements/README.md#fr-44-update-setting-admin)

---

## 16. References

- [08_User_Stories](../08_User_Stories/README.md)
- [09_Use_Cases](../09_Use_Cases/README.md)
- [05_Functional_Requirements](../05_Functional_Requirements/README.md)
- [10_Business_Rules](../10_Business_Rules/README.md)
- [13_Database_Overview](../13_Database_Overview/README.md)
- [Diagrams/application-flow.mmd](../Diagrams/application-flow.mmd)
- [Diagrams/sales-flow.mmd](../Diagrams/sales-flow.mmd)
- [Diagrams/inventory-flow.mmd](../Diagrams/inventory-flow.mmd)

---

## 17. Revision History

| Version | Date | Author | Description |
|---------|------|--------|-------------|
| 1.0 | 2026-08-07 | SmartPOS Documentation Team | Initial release |
