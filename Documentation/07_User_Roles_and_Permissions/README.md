# SmartPOS — User Roles and Permissions

**Document ID:** DOC-URP-007  
**Version:** 1.0  
**Status:** Approved  
**Author:** SmartPOS Documentation Team  
**Date:** August 7, 2026  

---

## 1. Purpose

This document defines the **user roles**, **permissions**, and **restrictions**
for the SmartPOS system. It is derived directly from the
[Project Bible](../AI/SMARTPOS_PROJECT_BIBLE.md#user-roles) and cross-references
the [Functional Requirements](../05_Functional_Requirements/README.md) and
[Security Architecture](../18_Security_Architecture/README.md).

---

## 2. Role Overview

SmartPOS defines two primary user roles. Each role has a distinct set of
permissions that determine what parts of the system they can access and what
actions they can perform.

| Role | Description |
|------|-------------|
| **Administrator** | Full system access. Can manage all modules, view all reports, configure settings, and manage users. |
| **Cashier** | Limited access. Can process sales and returns, search products, view own sales, and change own password. Cannot access administrative functions. |

---

## 3. Administrator Permissions

| Permission Group | Actions | Functional Requirement Reference |
|------------------|---------|----------------------------------|
| **Authentication** | Login, logout, refresh token, change password | FR-46, FR-48, FR-31 |
| **Users** | Create users, deactivate users, reset passwords, list all users | FR-28, FR-29, FR-30, FR-32 |
| **Products** | Full CRUD: create, read, update, delete, stock adjustment, search | FR-01–FR-07 |
| **Categories** | Full CRUD: create, read, update, delete | FR-08–FR-11 |
| **Suppliers** | Full CRUD: create, read, update, delete | FR-12–FR-15 |
| **Inventory** | View inventory, restock, adjustment, movement history | FR-16–FR-18, FR-07 |
| **Sales** | View all sales, void sales | FR-20, FR-22 |
| **Returns** | Process returns, view all returns | FR-23, FR-24 |
| **Credit Sales** | View all credit balances, settle balances | FR-25, FR-26, FR-27 |
| **Reports** | Generate and export all reports | FR-35–FR-37 |
| **Dashboards** | View admin dashboard | FR-38 |
| **Notifications** | View all notifications, mark as read | FR-41, FR-42 |
| **Settings** | View and update settings | FR-43, FR-44 |
| **Audit Logs** | View audit logs | FR-50 |

---

## 4. Cashier Permissions

| Permission Group | Actions | Functional Requirement Reference |
|------------------|---------|----------------------------------|
| **Authentication** | Login, logout, refresh token, change password | FR-46, FR-48, FR-31 |
| **Products** | Search products, view product details | FR-01, FR-02, FR-04 |
| **Sales** | Create sales, view own sales | FR-19, FR-21 |
| **Returns** | Process returns (for own sales — configurable) | FR-23 |
| **Notifications** | View own notifications, mark as read | FR-41, FR-42 |
| **Dashboards** | View cashier dashboard | FR-39 |
| **Settings** | View settings (read-only) | FR-43 |

---

## 5. Permissions Matrix

The following table defines the complete permissions matrix. Each cell indicates
whether the role has **Full**, **Read/Write**, **Read**, or **No Access** to a
given resource and action.

| Module / Action | Administrator | Cashier |
|-----------------|---------------|---------|
| **Login** | Full | Full |
| **Logout** | Full | Full |
| **Change Password** | Full | Full |
| **Create User** | Full | No Access |
| **Deactivate User** | Full | No Access |
| **Reset Password (others)** | Full | No Access |
| **List Users** | Full | No Access |
| **Create Product** | Full | No Access |
| **Read Product** | Full | Read |
| **Update Product** | Full | No Access |
| **Delete Product** | Full | No Access |
| **Search Products** | Full | Read |
| **Stock Adjustment** | Full | No Access |
| **List Categories** | Full | Read |
| **Create Category** | Full | No Access |
| **Update Category** | Full | No Access |
| **Delete Category** | Full | No Access |
| **List Suppliers** | Full | No Access |
| **Create Supplier** | Full | No Access |
| **Update Supplier** | Full | No Access |
| **Delete Supplier** | Full | No Access |
| **View Inventory** | Full | No Access |
| **Restock Product** | Full | No Access |
| **View Stock Movements** | Full | No Access |
| **Create Sale** | Full | Full |
| **View All Sales** | Full | No Access |
| **View Own Sales** | Full | Read |
| **Void Sale** | Full | No Access |
| **Process Return** | Full | Read/Write (own sales) |
| **View All Returns** | Full | No Access |
| **Credit Sales — View Balances** | Full | No Access |
| **Credit Sales — Settle** | Full | No Access |
| **Generate Reports** | Full | No Access |
| **Export Reports** | Full | No Access |
| **View Admin Dashboard** | Full | No Access |
| **View Cashier Dashboard** | Full | Read |
| **View All Notifications** | Full | Read (own) |
| **Mark Notification Read** | Full | Full |
| **View Settings** | Full | Read |
| **Update Settings** | Full | No Access |
| **View Audit Logs** | Full | No Access |

---

## 6. Role Responsibilities

### 6.1 Administrator

- **Primary Responsibility:** System integrity, configuration, and oversight.
- **Daily Tasks:**
  - Configure products, categories, and suppliers.
  - Monitor inventory levels and restock as needed.
  - Generate and review reports.
  - Manage user accounts (create, deactivate, reset passwords).
  - Review audit logs and notifications.
  - Update business settings.

### 6.2 Cashier

- **Primary Responsibility:** Processing customer transactions efficiently.
- **Daily Tasks:**
  - Process sales using the fast POS interface.
  - Process returns for their own sales.
  - Search for products by SKU, name, or barcode.
  - View personal sales history.
  - Review personal notifications.
  - Change own password.

---

## 7. Role Restrictions

### Administrator Restrictions

- Cannot be deactivated by another Admin (a user cannot deactivate themselves).
- Cannot reset their own password (must use the change-password flow).
- Cannot delete products that are referenced by open (non-voided) sales.
- Cannot create duplicate usernames or SKUs.

### Cashier Restrictions

- Cannot log in if account is deactivated.
- Cannot access any administrative endpoint — enforced by RBAC middleware.
- Cannot view other cashiers' sales.
- Cannot create, update, or delete products.
- Cannot access reports or dashboards beyond their own.
- Cannot modify system settings.
- Password must meet complexity requirements (see [FR-31](../05_Functional_Requirements/README.md#fr-31-change-own-password-cashier--admin)).

> **Enforcement:** All role-based restrictions are enforced at the API layer via
> role-decoding middleware. See [18_Security_Architecture — §4](../18_Security_Architecture/README.md#4-authorization-role-based-access-control-rbac).

---

## 8. Permission Enforcement Mechanism

| Layer | Mechanism |
|-------|-----------|
| **API Gateway / Middleware** | JWT token decoded; `role` claim extracted; route-level `@require_role("admin")` or `@require_role("cashier")` decorators applied. |
| **Frontend** | Navigation menu dynamically built based on role; API calls include JWT. |
| **Database** | Stored procedures and triggers enforce business rules regardless of role (e.g., stock constraints). |
| **Audit Trail** | All role-restricted actions logged with user_id and role. |

---

## 9. References

- [SMARTPOS_PROJECT_BIBLE.md](../AI/SMARTPOS_PROJECT_BIBLE.md#user-roles)
- [05_Functional_Requirements](../05_Functional_Requirements/README.md)
- [08_User_Stories](../08_User_Stories/README.md)
- [18_Security_Architecture](../18_Security_Architecture/README.md)
- [10_Business_Rules](../10_Business_Rules/README.md)

---

## 10. Revision History

| Version | Date | Author | Description |
|---------|------|--------|-------------|
| 1.0 | 2026-08-07 | SmartPOS Documentation Team | Initial release |
