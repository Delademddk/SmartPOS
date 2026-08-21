# SmartPOS — User Stories

**Document ID:** DOC-US-008  
**Version:** 1.0  
**Status:** Approved  
**Author:** SmartPOS Documentation Team  
**Date:** August 7, 2026  

---

## 1. Purpose

This document contains the complete set of **Agile user stories** for the
SmartPOS system. Each story includes:

- **ID** — Unique identifier
- **Title** — Brief description
- **As a** — Role
- **I want to** — Feature
- **So that** — Benefit
- **Acceptance Criteria** — Conditions that must be met
- **Priority** — Must / Should / Could
- **Related FR** — Traceability to [Functional Requirements](../05_Functional_Requirements/README.md)

---

## 2. Authentication Stories

### US-001: Login to the System
| Attribute | Detail |
|-----------|--------|
| As a | Cashier or Administrator |
| I want to | Enter my username and password |
| So that | I can access the system |
| Acceptance Criteria | 1. Valid credentials grant access. 2. Invalid credentials show an error. 3. After 3 failed attempts, CAPTCHA appears. 4. JWT tokens issued on success. |
| Priority | Must |
| Related FR | FR-46 |

### US-002: Refresh My Session
| Attribute | Detail |
|-----------|--------|
| As a | Logged-in user |
| I want to | Have my session auto-refresh |
| So that | I don't get logged out after short inactivity |
| Acceptance Criteria | 1. Access token refreshed before expiry. 2. New access token valid for another 15 minutes. |
| Priority | Must |
| Related FR | FR-47 |

### US-003: Logout
| Attribute | Detail |
|-----------|--------|
| As a | Logged-in user |
| I want to | Log out of the system |
| So that | My session is securely terminated |
| Acceptance Criteria | 1. Refresh token invalidated. 2. Redirected to login page. |
| Priority | Must |
| Related FR | FR-48 |

### US-004: Change My Password (Cashier)
| Attribute | Detail |
|-----------|--------|
| As a | Cashier |
| I want to | Change my own password |
| So that | I can maintain account security |
| Acceptance Criteria | 1. Current password verified. 2. New password ≥ 8 chars with complexity rules. 3. Password hashed before storage. |
| Priority | Must |
| Related FR | FR-31 |

### US-005: Change My Password (Admin)
| Attribute | Detail |
|-----------|--------|
| As a | Administrator |
| I want to | Change my own password |
| So that | I can maintain account security |
| Acceptance Criteria | Same as US-004. |
| Priority | Must |
| Related FR | FR-31 |

---

## 3. User Management Stories

### US-006: Create a New User (Admin)
| Attribute | Detail |
|-----------|--------|
| As a | Administrator |
| I want to | Create new cashier or admin accounts |
| So that | New staff can access the system |
| Acceptance Criteria | 1. Form validates username uniqueness. 2. Email format validated. 3. Role must be admin or cashier. 4. Temporary password generated. 5. User must change password on first login. |
| Priority | Must |
| Related FR | FR-28 |

### US-007: Deactivate a User (Admin)
| Attribute | Detail |
|-----------|--------|
| As a | Administrator |
| I want to | Deactivate a user account |
| So that | They can no longer access the system |
| Acceptance Criteria | 1. Confirmed before action. 2. Cannot deactivate self. 3. User immediately blocked from login. |
| Priority | Must |
| Related FR | FR-29 |

### US-008: Reset Password for a User (Admin)
| Attribute | Detail |
|-----------|--------|
| As a | Administrator |
| I want to | Reset another user's password |
| So that | They can regain access if forgotten |
| Acceptance Criteria | 1. Cannot reset own password. 2. New temporary password generated. 3. User must change on next login. |
| Priority | Should |
| Related FR | FR-30 |

### US-009: View All Users (Admin)
| Attribute | Detail |
|-----------|--------|
| As a | Administrator |
| I want to | See a list of all users |
| So that | I can manage them |
| Acceptance Criteria | 1. List shows username, full name, role, status, created date. 2. Active and inactive users shown. 3. Pagination supported. |
| Priority | Must |
| Related FR | FR-32 |

---

## 4. Product Management Stories

### US-010: Create a Product (Admin)
| Attribute | Detail |
|-----------|--------|
| As a | Administrator |
| I want to | Add a new product with SKU, price, and stock |
| So that | It appears in the catalog and POS |
| Acceptance Criteria | 1. SKU uniqueness validated. 2. Price and cost must be ≥ 0. 3. Category and supplier must exist. 4. Stock quantity defaults to 0. 5. Low-stock threshold settable. |
| Priority | Must |
| Related FR | FR-03 |

### US-011: Search for Products (Cashier)
| Attribute | Detail |
|-----------|--------|
| As a | Cashier |
| I want to | Search products by name, SKU, or barcode |
| So that | I can find items quickly during a sale |
| Acceptance Criteria | 1. Results update as I type (debounced). 2. Minimum 2 characters. 3. Results show SKU, name, price, stock. |
| Priority | Must |
| Related FR | FR-02 |

### US-012: View a Product's Details (Admin & Cashier)
| Attribute | Detail |
|-----------|--------|
| As a | Admin or Cashier |
| I want to | See full details of a product |
| So that | I know its price, SKU, and stock level |
| Acceptance Criteria | 1. Shows all fields. 2. Shows related category and supplier names. 3. 404 if product not found. |
| Priority | Must |
| Related FR | FR-04 |

### US-013: Edit a Product (Admin)
| Attribute | Detail |
|-----------|--------|
| As a | Administrator |
| I want to | Edit product details |
| So that | I can keep information current |
| Acceptance Criteria | 1. Pre-filled form with current values. 2. All validations applied. 3. Change tracked in audit log. |
| Priority | Must |
| Related FR | FR-05 |

### US-014: Delete a Product (Admin)
| Attribute | Detail |
|-----------|--------|
| As a | Administrator |
| I want to | Soft-delete a product |
| So that | It is hidden but recoverable |
| Acceptance Criteria | 1. Confirmed before action. 2. Product marked `is_deleted`. 3. Cannot delete if referenced by open sales. 4. Change tracked in audit log. |
| Priority | Should |
| Related FR | FR-06 |

### US-015: Adjust Product Stock (Admin)
| Attribute | Detail |
|-----------|--------|
| As a | Administrator |
| I want to | Manually adjust a product's stock quantity |
| So that | I can account for damaged or lost items |
| Acceptance Criteria | 1. Requires a reason. 2. Resulting stock ≥ 0. 3. Stock movement logged. 4. Change tracked in audit log. |
| Priority | Must |
| Related FR | FR-07 |

---

## 5. Category Management Stories

### US-016: Create a Category (Admin)
| Attribute | Detail |
|-----------|--------|
| As a | Administrator |
| I want to | Add a new category |
| So that | Products can be organized |
| Acceptance Criteria | 1. Name required and unique. 2. Optional parent category (no circular refs). 3. Change tracked in audit log. |
| Priority | Must |
| Related FR | FR-09 |

### US-017: Edit a Category (Admin)
| Acceptance Criteria | 1. Pre-filled. 2. All validations applied. |
| Priority | Must |
| Related FR | FR-10 |

### US-018: Delete a Category (Admin)
| Acceptance Criteria | 1. Confirmed. 2. Soft delete. 3. Cannot delete if children exist. |
| Priority | Should |
| Related FR | FR-11 |

---

## 6. Supplier Management Stories

### US-019: Create a Supplier (Admin)
| Acceptance Criteria | 1. Name required and unique. 2. Email format validated. 3. Change tracked. |
| Priority | Must |
| Related FR | FR-13 |

### US-020: Edit a Supplier (Admin)
| Priority | Must |
| Related FR | FR-14 |

### US-021: Delete a Supplier (Admin)
| Acceptance Criteria | 1. Soft delete. 2. Cannot delete if products reference it. |
| Priority | Should |
| Related FR | FR-15 |

---

## 7. Inventory Stories

### US-022: View Inventory (Admin)
| Acceptance Criteria | 1. Shows product, SKU, stock level, threshold, status. 2. Color-coded status. |
| Priority | Must |
| Related FR | FR-16 |

### US-023: Restock a Product (Admin)
| Acceptance Criteria | 1. Quantity > 0. 2. Stock movement logged. 3. Notification cleared if above threshold. |
| Priority | Must |
| Related FR | FR-17 |

### US-024: View Stock Movement History (Admin)
| Acceptance Criteria | 1. Chronological list. 2. Filterable by product, date, type. |
| Priority | Must |
| Related FR | FR-18 |

---

## 8. Sales Stories

### US-025: Create a Sale (Cashier)
| Acceptance Criteria | 1. Add items via search. 2. Cart totals calculated. 3. Payment method selectable. 4. Inventory decremented atomically. 5. Transaction record created. 6. Receipt number generated. |
| Priority | Must |
| Related FR | FR-19 |

### US-026: Handle Insufficient Stock During Sale
| Acceptance Criteria | 1. Item flagged as out of stock in cart. 2. Sale cannot be completed until resolved. |
| Priority | Must |
| Related FR | FR-19 |

### US-027: View All Sales (Admin)
| Acceptance Criteria | 1. Filterable by date, cashier, method. 2. Paginated. 3. Exportable. |
| Priority | Must |
| Related FR | FR-20 |

### US-028: View Own Sales (Cashier)
| Acceptance Criteria | 1. Only shows sales created by this user. 2. Filterable by date. |
| Priority | Must |
| Related FR | FR-21 |

### US-029: Void a Sale (Admin)
| Acceptance Criteria | 1. Only same-day sales voidable. 2. Inventory restored. 3. Transaction logged. |
| Priority | Should |
| Related FR | FR-22 |

---

## 9. Returns Stories

### US-030: Process a Return (Cashier)
| Acceptance Criteria | 1. Select from own sales. 2. Quantity ≤ sold quantity. 3. Inventory restored. 4. Refund amount calculated. 5. Return record logged. |
| Priority | Must |
| Related FR | FR-23 |

### US-031: View All Returns (Admin)
| Acceptance Criteria | 1. Filterable. 2. Paginated. |
| Priority | Must |
| Related FR | FR-24 |

---

## 10. Credit Sales Stories

### US-032: Process a Credit Sale (Cashier)
| Acceptance Criteria | 1. Credit flag set. 2. Customer balance created. 3. Inventory still decrements. |
| Priority | Must |
| Related FR | FR-25 |

### US-033: View Outstanding Credit Balances (Admin)
| Acceptance Criteria | 1. List of customers with outstanding amounts. |
| Priority | Should |
| Related FR | FR-26 |

### US-034: Settle a Credit Balance (Admin)
| Acceptance Criteria | 1. Amount ≤ balance. 2. Balance updated. 3. Payment recorded. |
| Priority | Should |
| Related FR | FR-27 |

---

## 11. Reporting Stories

### US-035: Generate a Sales Summary Report
| Acceptance Criteria | 1. Select date range. 2. Report shows totals, breakdown by payment. 3. Export to Excel/PDF. |
| Priority | Must |
| Related FR | FR-35 |

### US-036: Generate an Inventory Health Report
| Acceptance Criteria | 1. Shows all products with stock and threshold. |
| Priority | Must |
| Related FR | FR-36 |

---

## 12. Dashboard Stories

### US-037: View the Admin Dashboard
| Acceptance Criteria | 1. Shows KPIs. 2. Auto-refreshes. 3. Links to detailed reports. |
| Priority | Must |
| Related FR | FR-38 |

### US-038: View the Cashier Dashboard
| Acceptance Criteria | 1. Shows today's personal stats. 2. Auto-refreshes. |
| Priority | Must |
| Related FR | FR-39 |

---

## 13. Notification Stories

### US-039: Receive Low-Stock Notification
| Acceptance Criteria | 1. Notification appears when stock ≤ threshold. 2. Notification includes product name and SKU. 3. Click navigates to inventory page. |
| Priority | Must |
| Related FR | FR-40 |

### US-040: View My Notifications
| Acceptance Criteria | 1. List of user's notifications. 2. Read/unread status. 3. Mark as read. 4. Paginated. |
| Priority | Must |
| Related FR | FR-41 |

---

## 14. Settings Stories

### US-041: View Settings (Admin)
| Acceptance Criteria | 1. Shows all key-value pairs. 2. Editable inline. |
| Priority | Must |
| Related FR | FR-43 |

### US-042: Update a Setting (Admin)
| Acceptance Criteria | 1. Type validation applied. 2. Change tracked in audit log. |
| Priority | Should |
| Related FR | FR-44 |

---

## 15. Story Mapping (Prioritized Backlog)

| Epic | Stories | Sprint |
|------|---------|--------|
| Authentication & RBAC | US-001–US-005 | 1 |
| User Management | US-006–US-009 | 1 |
| Product Management | US-010–US-015 | 2 |
| Category & Supplier Mgmt | US-016–US-021 | 2 |
| Inventory | US-022–US-024 | 2 |
| Sales | US-025–US-029 | 3 |
| Returns | US-030–US-031 | 3 |
| Credit Sales | US-032–US-034 | 4 |
| Reporting & Dashboards | US-035–US-038 | 4 |
| Notifications & Settings | US-039–US-042 | 4 |

---

## 16. References

- [05_Functional_Requirements](../05_Functional_Requirements/README.md)
- [09_Use_Cases](../09_Use_Cases/README.md)
- [11_System_Workflows](../11_System_Workflows/README.md)
- [12_System_Architecture](../12_System_Architecture/README.md)

---

## 17. Revision History

| Version | Date | Author | Description |
|---------|------|--------|-------------|
| 1.0 | 2026-08-07 | SmartPOS Documentation Team | Initial release |
