# SmartPOS — Business Rules

**Document ID:** DOC-BR-010  
**Version:** 1.0  
**Status:** Approved  
**Author:** SmartPOS Documentation Team  
**Date:** August 7, 2026  

---

## 1. Purpose

This document defines all **business rules** for the SmartPOS system. Business
rules are constraints or definitions that must hold true for the system to
operate correctly. They are the invariant rules of the business domain,
implemented at both the application layer (services) and the database layer
(constraints, triggers, stored procedures).

All rules are derived from the
[Project Bible](../AI/SMARTPOS_PROJECT_BIBLE.md#business-rules).

---

## 2. Rule Organization

Business rules are organized by the module where they are primarily enforced:

| Category | Rules |
|----------|-------|
| Sales | BR-SALE-01 through BR-SALE-05 |
| Inventory | BR-INV-01 through BR-INV-06 |
| Returns | BR-RET-01 through BR-RET-05 |
| Credit Sales | BR-CR-01 through BR-CR-04 |
| Authentication | BR-AUTH-01 through BR-AUTH-04 |
| Users | BR-USR-01 through BR-USR-03 |
| Notifications | BR-NOT-01 through BR-NOT-03 |
| Reports | BR-REP-01 through BR-REP-02 |
| Settings | BR-SET-01 |
| Suppliers | BR-SUP-01 through BR-SUP-03 |
| Products | BR-PROD-01 through BR-PROD-04 |
| Categories | BR-CAT-01 through BR-CAT-02 |
| Audit | BR-AUD-01 through BR-AUD-02 |

---

## 3. Sales Rules

### BR-SALE-01: Inventory Decreases After Sales
| Attribute | Value |
|-----------|-------|
| ID | BR-SALE-01 |
| Description | Every completed sale permanently decreases the `stock_quantity` of each sold product by the sold quantity. |
| Rationale | Prevent overselling; maintain accurate stock levels. |
| Enforcement | Database transaction + stored procedure; also enforced in API service layer. |

### BR-SALE-02: Every Sale Creates Transaction Records
| Attribute | Value |
|-----------|-------|
| ID | BR-SALE-02 |
| Description | Each sale creates one `sales` header record and one `sale_items` detail record per product sold. |
| Rationale | Full auditability and accurate financial reporting. |
| Enforcement | Backend service transaction; database foreign keys. |

### BR-SALE-03: Stock Sufficiency Check Before Sale Completion
| Attribute | Value |
|-----------|-------|
| ID | BR-SALE-03 |
| Description | A sale cannot be completed if any item's `stock_quantity` is less than the requested `quantity`. |
| Rationale | Prevent negative inventory. |
| Enforcement | API-level validation with SELECT before INSERT; database constraint prevents negative stock. |

### BR-SALE-04: Receipt Numbers Are Sequential
| Attribute | Value |
|-----------|-------|
| ID | BR-SALE-04 |
| Description | Each sale receives a unique, sequentially generated receipt number. |
| Rationale | Auditable, traceable financial documents. |
| Enforcement | Database sequence or auto-increment column. |

### BR-SALE-05: Sales Are Immutable After Creation
| Attribute | Value |
|-----------|-------|
| ID | BR-SALE-05 |
| Description | Once a sale is completed, its line items cannot be modified. Returns and voids are recorded as separate records. |
| Rationale | Preserve financial integrity and audit trail. |
| Enforcement | No UPDATE on `sale_items` after creation; only INSERT (returns) allowed. |

---

## 4. Inventory Rules

### BR-INV-01: Inventory Decreases After Sales
| Attribute | Value |
|-----------|-------|
| ID | BR-INV-01 |
| Description | (Same as BR-SALE-01 — cross-module rule.) |
| Rationale | Consistent stock accounting. |
| Enforcement | `AFTER INSERT` trigger on `sales` table. |

### BR-INV-02: Inventory Increases After Restocking
| Attribute | Value |
|-----------|-------|
| ID | BR-INV-02 |
| Description | Every restock operation increases the `stock_quantity` of the product by the restocked quantity. |
| Rationale | Maintain accurate stock levels. |
| Enforcement | Stored procedure or API service. |

### BR-INV-03: Returns Restore Inventory
| Attribute | Value |
|-----------|-------|
| ID | BR-INV-03 |
| Description | Every returned item restores stock by the returned quantity. |
| Rationale | Customer returns should return items to stock. |
| Enforcement | API service transaction. |

### BR-INV-04: Every Inventory Movement Is Logged
| Attribute | Value |
|-----------|-------|
| ID | BR-INV-04 |
| Description | Every stock quantity change (sale, restock, return, adjustment, void) is recorded in the `stock_movements` table with `product_id`, `quantity`, `movement_type`, `reference_id`, `user_id`, `timestamp`, and `reason`. |
| Rationale | Auditability of all stock changes. |
| Enforcement | Database trigger + application-level logging. |

### BR-INV-05: Stock Quantity Cannot Go Negative
| Attribute | Value |
|-----------|-------|
| ID | BR-INV-05 |
| Description | The `stock_quantity` column has a check constraint ensuring it is always ≥ 0. |
| Rationale | Prevent data corruption. |
| Enforcement | Database check constraint `CHECK (stock_quantity >= 0)`. |

### BR-INV-06: Low Stock Threshold Triggers Notification
| Attribute | Value |
|-----------|-------|
| ID | BR-INV-06 |
| Description | When a stock movement causes a product's `stock_quantity` to fall at or below its `low_stock_threshold`, a notification is created for all Admin users. |
| Rationale | Enable proactive restocking. |
| Enforcement | AFTER UPDATE trigger on `products` table. |

---

## 5. Returns Rules

### BR-RET-01: Returns Must Reference a Valid Sale
| Description | A return record must reference an existing, non-voided `sale_id`. |
### BR-RET-02: Return Quantity ≤ Sold Quantity
| Description | The total returned quantity for a product cannot exceed the quantity sold in the original sale (minus prior returns). |
### BR-RET-03: Returns Restore Inventory
| Description | Returned items are added back to `stock_quantity`. |
### BR-RET-04: Return Creates a New Record
| Description | Returns are recorded in `returns` and `return_items` tables; original sale is not modified. |
### BR-RET-05: Refund Amount Is Calculated
| Description | The refund amount equals the sum of returned items' `price × quantity`. |

---

## 6. Credit Sales Rules

### BR-CR-01: Credit Sales Create Customer Balances
| Description | When `is_credit = true`, a `credit_balance` is created/credited for the customer (identified by name). |
### BR-CR-02: Credit Sales Still Decrement Inventory
| Description | Credit sales are full sales — inventory is decremented immediately. Only payment is deferred. |
### BR-CR-03: Balance Cannot Go Negative
| Description | Settlement payments cannot exceed the outstanding balance. |
### BR-CR-04: Credit Sales Track Outstanding Amount
| Description | Each credit sale links to a `credit_balances` record; settlements reduce the balance until zero. |

---

## 7. Authentication Rules

### BR-AUTH-01: Passwords Must Always Be Hashed
| Description | Passwords are hashed using bcrypt (or Argon2) before storage. Plaintext passwords are never stored. |
### BR-AUTH-02: JWT Tokens Have Two TTLs
| Description | Access tokens expire in 15 minutes; refresh tokens expire in 7 days. |
### BR-AUTH-03: Refresh Token Rotation
| Description | Each refresh token use generates a new refresh token and invalidates the previous one. |
### BR-AUTH-04: Login Rate Limiting
| Description | Max 5 failed login attempts per IP within 15 minutes; account locks after 5 consecutive failures. |

---

## 8. User Rules

### BR-USR-01: Username Must Be Unique
| Description | No two users (active or inactive) may share the same `username`. |
### BR-USR-02: Cannot Deactivate Self
| Description | A user cannot deactivate their own account. |
### BR-USR-03: Password Complexity
| Description | Passwords must be ≥ 8 characters, including at least one uppercase, one lowercase, one digit, and one special character. |

---

## 9. Notifications Rules

### BR-NOT-01: Low-Stock Notifications Are Created Automatically
| Description | Triggered by BR-INV-06; one notification per Admin user per low-stock event. |
### BR-NOT-02: Notifications Are User-Specific
| Description | Each notification is associated with a specific `user_id`. |
### BR-NOT-03: Duplicate Notifications Are Avoided
| Description | If a product is already below threshold and another sale occurs, no new notification is created until stock goes above threshold and drops again. |

---

## 10. Reports Rules

### BR-REP-01: Reports Reflect Committed Data Only
| Description | Reports never include uncommitted (in-flight) transactions. |
### BR-REP-02: Report Filters Must Be Honored
| Description | All report filters (date range, user, product) must be applied at the database level for performance. |

---

## 11. Settings Rules

### BR-SET-01: Settings Are Key-Value Pairs
| Description | The `settings` table stores `key` (unique), `value` (string), `type`, and `description`. Types constrain allowed values. |

---

## 12. Supplier Rules

### BR-SUP-01: Supplier Name Must Be Unique
| Description | No two suppliers may share the same `name`. |
### BR-SUP-02: Email Format Validated
| Description | If provided, supplier email must match a valid email regex. |
### BR-SUP-03: Cannot Hard-Delete Suppliers With Products
| Description | Soft delete only; suppliers referenced by products cannot be hard-deleted. |

---

## 13. Product Rules

### BR-PROD-01: SKU Must Be Unique
| Description | Product `sku` column has a unique constraint. |
### BR-PROD-02: Price Must Be Non-Negative
| Description | `price` and `cost` must be ≥ 0. |
### BR-PROD-03: Stock Quantity Must Be Non-Negative
| Description | `stock_quantity` must be ≥ 0 (check constraint). |
### BR-PROD-04: Deleted Products Remain Searchable
| Description | Soft-deleted products (is_deleted = true) are excluded from general sales search but visible in admin product management with a "deleted" filter. |

---

## 14. Category Rules

### BR-CAT-01: Category Name Unique at Each Level
| Description | Two categories with the same `parent_id` cannot share the same `name`. |
### BR-CAT-02: No Circular Hierarchies
| Description | A category cannot be its own ancestor (enforced by recursive CTE check or trigger). |

---

## 15. Audit Rules

### BR-AUD-01: Every Important Action Is Auditable
| Description | All create, update, delete, login, logout, sale, return, and setting-change actions are logged in the `audit_logs` table. |
### BR-AUD-02: Audit Logs Are Immutable
| Description | Audit log records can be inserted but never updated or deleted. |

---

## 16. Cross-Cutting Rules

### BR-CROSS-01: Soft Deletes Are Default
| Description | Deleted business records use soft delete (`is_deleted = true`) unless hard deletion is explicitly required (e.g., for cleanup). |
### BR-CROSS-02: Environment Variables for Configuration
| Description | All configurable values come from environment variables; no hardcoded secrets. |
### BR-CROSS-03: All Communication Over HTTPS
| Description | In production, all API traffic must be encrypted with TLS 1.2+. |

---

## 17. References

- [SMARTPOS_PROJECT_BIBLE.md](../AI/SMARTPOS_PROJECT_BIBLE.md#business-rules)
- [05_Functional_Requirements](../05_Functional_Requirements/README.md)
- [13_Database_Overview](../13_Database_Overview/README.md)
- [18_Security_Architecture](../18_Security_Architecture/README.md)
- [19_Testing_Strategy](../19_Testing_Strategy/README.md)

---

## 18. Revision History

| Version | Date | Author | Description |
|---------|------|--------|-------------|
| 1.0 | 2026-08-07 | SmartPOS Documentation Team | Initial release |
