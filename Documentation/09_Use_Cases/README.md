# SmartPOS — Use Cases

**Document ID:** DOC-UC-009  
**Version:** 1.0  
**Status:** Approved  
**Author:** SmartPOS Documentation Team  
**Date:** August 7, 2026  

---

## 1. Purpose

This document describes the **detailed use cases** for the SmartPOS system.
Each use case specifies the actors, preconditions, main success flow,
alternative flows, exceptions, and postconditions. Use cases are traceable to
[user stories](../08_User_Stories/README.md) and
[functional requirements](../05_Functional_Requirements/README.md).

**Notation:** This document uses a textual use-case description format aligned
with IEEE 834 and UML use-case concepts.

---

## 2. Use Case Diagram (Textual)

```
Actors: Administrator, Cashier

Administrator -- Login (UC-01)
Administrator -- Create User (UC-04)
Administrator -- Deactivate User (UC-05)
Administrator -- Product CRUD (UC-06, UC-07, UC-08, UC-09)
Administrator -- Category CRUD (UC-10, UC-11, UC-12)
Administrator -- Supplier CRUD (UC-13, UC-14, UC-15)
Administrator -- View Inventory (UC-16)
Administrator -- Restock (UC-17)
Administrator -- View All Sales (UC-19)
Administrator -- Void Sale (UC-20)
Administrator -- Process Return (UC-21, UC-22)
Administrator -- View Credit Balances (UC-23)
Administrator -- Settle Credit (UC-24)
Administrator -- Generate Reports (UC-25)
Administrator -- View Admin Dashboard (UC-26)
Administrator -- View Notifications (UC-27)
Administrator -- Manage Settings (UC-28)
Administrator -- View Audit Logs (UC-29)
Administrator -- Adjust Stock (UC-30)

Cashier -- Login (UC-01)
Cashier -- Create Sale (UC-10)
Cashier -- View Own Sales (UC-11)
Cashier -- Search Products (UC-02a)
Cashier -- Process Return (UC-12)
Cashier -- Change Password (UC-03)
Cashier -- View Cashier Dashboard (UC-15)
Cashier -- View Notifications (UC-13)
```

---

## 3. Use Case: Login (UC-01)

### 3.1 Scope
System-wide authentication.

### 3.2 Level
User goal (subfunction).

### 3.3 Actors
Administrator, Cashier.

### 3.4 Preconditions
1. User is on the login page.
2. User has a valid account (active status).

### 3.5 Main Success Flow (Happy Path)
1. User enters username and password.
2. System validates credentials against hashed password in database.
3. System checks account status (active).
4. System generates JWT access token (15-min TTL) and refresh token (7-day TTL).
5. System returns user profile and tokens.
6. System redirects to appropriate dashboard based on role.

### 3.6 Alternative Flows
- **A1:** User selects "Remember me" → System extends refresh token TTL.
- **A2:** Password complexity warning shown during login (if password flagged weak).

### 3.7 Exception Flows
- **E1:** Invalid credentials → System returns 401, "Invalid username or password."
- **E2:** Account deactivated → System returns 403, "Account disabled."
- **E3:** Too many failed attempts → System returns 429, "Too many attempts. Try again later."
- **E4:** Network error → System shows retry option.

### 3.8 Postconditions
1. User is authenticated and has valid JWT tokens.
2. User session established in browser local storage.

### 3.9 Related Requirements
- FR-46, FR-50 (audit logging)
- NFR-SEC-01, NFR-SEC-02, NFR-SEC-08, NFR-SEC-14

---

## 4. Use Case: Search Products (UC-02a)

### 4.1 Scope
Product search during a sale.

### 4.2 Actors
Cashier.

### 4.3 Preconditions
1. User is logged in as Cashier.
2. User is on the "Create Sale" screen.

### 4.4 Main Success Flow
1. User types ≥ 2 characters into search field.
2. System queries products matching SKU, name, or barcode.
3. System displays matching products with SKU, name, price, stock.
4. User selects a product from results.
5. System adds product to cart.

### 4.5 Exception Flows
- **E1:** No results found → System displays "No products found."
- **E2:** Product out of stock → System highlights with "Out of stock" badge.

### 4.6 Postconditions
1. Product added to cart.
2. Search results cleared.

### 4.7 Related Requirements
- FR-02, FR-19

---

## 5. Use Case: Change Password (UC-03)

### 5.1 Scope
User self-service password change.

### 5.2 Actors
Administrator, Cashier.

### 5.3 Preconditions
1. User is authenticated.
2. User is on the "Change Password" page.

### 5.4 Main Success Flow
1. User enters current password.
2. User enters new password and confirmation.
3. System validates current password.
4. System validates new password complexity (≥ 8 chars, upper, lower, digit, special).
5. System hashes new password with bcrypt.
6. System updates password hash in database.
7. System logs the action.

### 5.5 Exception Flows
- **E1:** Current password incorrect → 401 error.
- **E2:** New password doesn't meet complexity → Validation error.
- **E3:** Passwords don't match → Validation error.

### 5.6 Postconditions
1. Password updated and hashed.
2. Audit log entry created.
3. All existing sessions invalidated (optional — refresh token rotation).

### 5.7 Related Requirements
- FR-31, BR-05

---

## 6. Use Case: Create User (UC-04)

### 6.1 Scope
User creation.

### 6.2 Actors
Administrator.

### 6.3 Preconditions
1. User is authenticated as Administrator.
2. User is on the "Users" page → "Create User" form.

### 6.4 Main Success Flow
1. Admin fills in username, full name, email, phone, role.
2. System validates all fields (uniqueness, email format).
3. System generates a temporary password.
4. System hashes the password.
5. System creates the user record with `is_active = true`.
6. System logs the action in audit trail.
7. System displays the temporary password to admin (to communicate to user).

### 6.5 Exception Flows
- **E1:** Username already exists → Validation error.
- **E2:** Email already exists → Validation error.
- **E3:** Invalid email format → Validation error.

### 6.6 Postconditions
1. New user record created.
2. Audit log entry created.

### 6.7 Related Requirements
- FR-28, BR-05, NFR-SEC-01

---

## 7. Use Case: Deactivate User (UC-05)

### 7.1 Actors
Administrator.

### 7.2 Preconditions
1. User is authenticated as Administrator.
2. User is on the "Users" page.

### 7.3 Main Success Flow
1. Admin selects a user and clicks "Deactivate."
2. System confirms the action (modal dialog).
3. Admin confirms.
4. System marks user `is_active = false`.
5. System logs the action.
6. User immediately cannot create new sessions.

### 7.4 Exception Flows
- **E1:** Admin tries to deactivate self → Error: "Cannot deactivate your own account."
- **E2:** User already deactivated → Error: "User is already inactive."

### 7.5 Postconditions
1. User cannot log in.
2. Audit log entry created.

### 7.6 Related Requirements
- FR-29

---

## 8. Use Case: Product CRUD (UC-06–09)

### UC-06: Create Product (Admin)

| Attribute | Detail |
|-----------|--------|
| Actors | Administrator |
| Precondition | Admin on "Create Product" page |
| Main Flow | 1. Fill form (SKU, name, price, cost, stock, category, supplier, threshold). 2. Submit. 3. System validates. 4. System saves. 5. System logs. |
| Exceptions | SKU duplicate, invalid price, category/supplier not found |
| Postcondition | Product created. |
| Related FR | FR-03 |

### UC-07: Read Product (Admin & Cashier)

| Attribute | Detail |
|-----------|--------|
| Actors | Administrator, Cashier |
| Main Flow | 1. Navigate to product detail page. 2. System fetches and displays all fields. |
| Exceptions | 404 if not found |
| Related FR | FR-04 |

### UC-08: Edit Product (Admin)

| Attribute | Detail |
|-----------|--------|
| Actors | Administrator |
| Main Flow | 1. Navigate to edit form. 2. Form pre-filled. 3. Admin edits. 4. Submit. 5. System validates and saves. 6. System logs. |
| Exceptions | SKU duplicate, invalid values |
| Related FR | FR-05 |

### UC-09: Delete Product (Admin)

| Attribute | Detail |
|-----------|--------|
| Actors | Administrator |
| Main Flow | 1. Admin clicks delete. 2. Confirmation modal. 3. Admin confirms. 4. System soft-deletes. 5. System logs. |
| Exceptions | 409 if referenced by open sales |
| Related FR | FR-06, BR-09 |

---

## 9. Use Case: Category CRUD (UC-10–12)

### UC-10: Create Category (Admin)

| Attribute | Detail |
|-----------|--------|
| Actors | Administrator |
| Main Flow | 1. Fill form (name, parent, description). 2. System validates uniqueness at level. 3. Save. 4. Log. |
| Exceptions | Name duplicate at same level, circular hierarchy |
| Related FR | FR-09 |

### UC-11: Edit Category (Admin)

| Related FR | FR-10 |

### UC-12: Delete Category (Admin)

| Attribute | Detail |
|-----------|--------|
| Main Flow | 1. Confirmation. 2. Soft delete. 3. Log. |
| Exceptions | Children exist |
| Related FR | FR-11 |

---

## 10. Use Case: Supplier CRUD (UC-13–15)

### UC-13: Create Supplier (Admin)

| Related FR | FR-13 |

### UC-14: Edit Supplier (Admin)

| Related FR | FR-14 |

### UC-15: Delete Supplier (Admin)

| Exceptions | Products reference supplier |
| Related FR | FR-15 |

---

## 11. Use Case: View Inventory (UC-16)

### 11.1 Actors
Administrator.

### 11.2 Main Success Flow
1. Admin navigates to Inventory page.
2. System loads all products with stock, threshold, and status.
3. Admin can filter by category or search.
4. Admin can see color-coded status (green=in stock, yellow=low, red=out).

### 11.3 Related Requirements
- FR-16, BR-01

---

## 12. Use Case: Restock (UC-17)

### 12.1 Actors
Administrator.

### 12.2 Preconditions
1. Admin authenticated.
2. Admin on Inventory page.

### 12.3 Main Success Flow
1. Admin clicks "Restock" for a product.
2. System opens restock form (quantity, reference, notes).
3. Admin fills form.
4. Submit. System validates quantity > 0.
5. System increments `stock_quantity`.
6. System logs stock movement (type=restock).
7. System checks low-stock threshold and clears notification if above.
8. System logs audit entry.

### 12.4 Exceptions
- Quantity ≤ 0 → Validation error.

### 12.5 Related Requirements
- FR-17, BR-02, FR-33

---

## 13. Use Case: Create Sale (UC-18)

### 13.1 Actors
Cashier.

### 13.2 Preconditions
1. Cashier authenticated.
2. Cashier on "New Sale" page.
3. Cashier has selected at least one product.

### 13.3 Main Success Flow
1. Cashier adds products to cart via search or barcode.
2. System calculates subtotal, applies discounts if any.
3. Cashier selects payment method (cash/card) or marks as credit.
4. System validates sufficient stock for all items.
5. Cashier confirms sale.
6. System starts a database transaction.
7. System creates sale record.
8. System creates transaction records for each item.
9. System decrements `stock_quantity` for each product.
10. System logs stock movement entries.
11. System generates receipt number (sequential).
12. System commits transaction.
13. System prints or emails receipt.
14. System shows success message with receipt number.

### 13.4 Alternative Flows
- **A1:** Credit sale → System creates/credits customer balance (FR-25).
- **A2:** Payment amount > total → System calculates and displays change.

### 13.5 Exception Flows
- **E1:** Insufficient stock → System rejects sale, 409, identifies problematic products.
- **E2:** Product out of stock between add and submit → 409.
- **E3:** Payment amount < total (non-credit) → Validation error.

### 13.6 Postconditions
1. Sale record exists.
2. Inventory decremented.
3. Stock movement logged.
4. Receipt number generated.
5. Audit log entry created.

### 13.7 Related Requirements
- FR-19, BR-01, BR-06, FR-33

---

## 14. Use Case: View All Sales (UC-19)

### 14.1 Actors
Administrator.

### 14.2 Main Success Flow
1. Admin navigates to Sales page.
2. System loads sales with filters (date, cashier, payment method).
3. Admin can paginate, sort, export.

### 14.4 Related Requirements
- FR-20

---

## 15. Use Case: View Own Sales (UC-20)

### 15.1 Actors
Cashier.

### 15.2 Main Success Flow
1. Cashier navigates to "My Sales."
2. System loads sales filtered by cashier's user_id.
3. Cashier can filter by date and export.

### 15.4 Related Requirements
- FR-21

---

## 16. Use Case: Void Sale (UC-21)

### 16.1 Actors
Administrator.

### 16.2 Main Flow
1. Admin selects a sale (same-day only).
2. Admin clicks "Void."
3. Confirmation modal.
4. Admin provides reason, confirms.
5. System starts transaction.
6. System marks sale as voided.
7. System restores stock for each item.
8. System logs stock movements (type=void).
9. System commits.
10. System logs audit entry.

### 16.3 Exceptions
- Sale from previous day → 403.
- Already voided → 409.

### 16.4 Related Requirements
- FR-22, BR-03

---

## 17. Use Case: Process Return (UC-22)

### 17.1 Actors
Cashier, Administrator.

### 17.2 Preconditions
1. User authenticated.
2. Original sale exists and is not voided.

### 17.3 Main Success Flow
1. User selects "New Return."
2. System displays searchable list of past sales.
3. User selects a sale.
4. System shows items in that sale.
5. User selects items and quantities to return.
6. System validates quantities ≤ originally sold (minus already returned).
7. System calculates refund amount.
8. User confirms.
9. System starts transaction.
10. System creates return record.
11. System restores stock for returned items.
12. System logs stock movements (type=return).
13. System commits.
14. System generates return receipt.

### 17.4 Exceptions
- Return quantity > available → 400.

### 17.5 Related Requirements
- FR-23, BR-03

---

## 18. Use Case: Generate Report (UC-25)

### 18.1 Actors
Administrator.

### 18.2 Main Success Flow
1. Admin navigates to Reports page.
2. Admin selects report type (sales summary, inventory health, etc.).
3. Admin sets filters (date range, etc.).
4. System generates report.
5. Admin reviews or exports (Excel/PDF).

### 18.4 Related Requirements
- FR-35, FR-36, FR-37

---

## 19. Use Case: View Dashboard (UC-26 for Admin / UC-15 for Cashier)

### 19.1 Actors
Administrator / Cashier.

### 19.2 Main Success Flow
1. User logs in.
2. System redirects to role-specific dashboard.
3. System loads KPIs (auto-refresh every 60 s).
4. User clicks a KPI to navigate to related detail page.

### 19.4 Related Requirements
- FR-38, FR-39

---

## 20. Use Case: View Notifications (UC-27)

### 20.1 Actors
All users.

### 20.2 Main Flow
1. User clicks Notifications icon.
2. System loads user's notifications (paginated, unread first).
3. User can mark as read individually or bulk.

### 20.4 Related Requirements
- FR-40, FR-41, FR-42

---

## 21. Use Case: Manage Settings (UC-28)

### 21.1 Actors
Administrator.

### 21.2 Main Flow
1. Admin navigates to Settings page.
2. System loads all key-value pairs.
3. Admin edits a value inline.
4. System validates type.
5. System saves and logs.

### 21.4 Related Requirements
- FR-43, FR-44

---

## 22. Use Case: View Audit Logs (UC-29)

### 22.1 Actors
Administrator.

### 22.2 Main Flow
1. Admin navigates to Audit Logs page.
2. System loads logs (filtered by date, user, action).
3. Admin reviews immutable log entries.

### 22.4 Related Requirements
- FR-49, FR-50, BR-10

---

## 23. References

- [05_Functional_Requirements](../05_Functional_Requirements/README.md)
- [08_User_Stories](../08_User_Stories/README.md)
- [10_Business_Rules](../10_Business_Rules/README.md)
- [11_System_Workflows](../11_System_Workflows/README.md)
- [18_Security_Architecture](../18_Security_Architecture/README.md)
- [19_Testing_Strategy](../19_Testing_Strategy/README.md)

---

## 24. Revision History

| Version | Date | Author | Description |
|---------|------|--------|-------------|
| 1.0 | 2026-08-07 | SmartPOS Documentation Team | Initial release |
