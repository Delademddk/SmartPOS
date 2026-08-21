# SmartPOS — API Architecture

**Document ID:** DOC-API-014  
**Version:** 1.0  
**Status:** Approved  
**Author:** SmartPOS Documentation Team  
**Date:** August 7, 2026  

---

## 1. Purpose

This document defines the **API architecture** for the SmartPOS backend. It
specifies REST conventions, authentication, versioning, response/error formats,
pagination, filtering, sorting, validation, and security practices. The API is
implemented with **FastAPI** and served to the React frontend via HTTPS/REST
over JSON.

---

## 2. API Conventions

### 2.1 REST Principles

| Convention | Rule |
|------------|------|
| Resource naming | Plural, snake_case (e.g., `/products`, `/sale_items`) |
| HTTP methods | `GET` (read), `POST` (create), `PUT` (full update), `PATCH` (partial update), `DELETE` (soft delete) |
| Status codes | 200 OK, 201 Created, 204 No Content, 400 Bad Request, 401 Unauthorized, 403 Forbidden, 404 Not Found, 409 Conflict, 422 Unprocessable Entity, 429 Too Many Requests, 500 Internal Server Error |
| Content type | `application/json` for request and response bodies |
| Idempotency | `GET`, `PUT`, `DELETE` are idempotent; `POST` for creation is not |

### 2.2 Resource Naming

| Resource | Endpoint |
|----------|----------|
| Auth | `/auth/login`, `/auth/refresh`, `/auth/logout` |
| Users | `/users`, `/users/{id}` |
| Products | `/products`, `/products/{id}` |
| Categories | `/categories`, `/categories/{id}` |
| Suppliers | `/suppliers`, `/suppliers/{id}` |
| Inventory | `/inventory`, `/inventory/restock`, `/inventory/movements` |
| Sales | `/sales`, `/sales/{id}`, `/sales/receipt/{receipt_number}` |
| Returns | `/returns`, `/returns/{id}` |
| Credit Sales | `/credit-balances`, `/credit-balances/{id}/settle` |
| Reports | `/reports/generate`, `/reports/export` |
| Dashboards | `/dashboard/admin`, `/dashboard/cashier` |
| Notifications | `/notifications`, `/notifications/{id}/read` |
| Settings | `/settings`, `/settings/{key}` |
| Audit Logs | `/audit-logs` |

### 2.3 Versioning

- The API version is embedded in the base path: `/api/v1/`.
- All endpoints are prefixed with `/api/v1/`.
- Version increments follow SemVer: major versions may break backward
  compatibility; minor and patch versions are backward-compatible.

Example: `POST /api/v1/auth/login`

---

## 3. Authentication

### 3.1 JWT-Based Authentication

- **Access Token:** JWT with 15-minute TTL. Sent in `Authorization: Bearer <token>`
  header.
- **Refresh Token:** Long-lived token (7-day TTL) stored in HttpOnly cookie or
  localStorage. Sent to `/auth/refresh` to obtain a new access token.
- **Token Format:** Standard JWT (HS256) signed with a secret from environment
  variable.
- **Password Hashing:** bcrypt (or Argon2) — passwords are never stored in
  plaintext. See [18_Security_Architecture](../18_Security_Architecture/README.md).

### 3.2 Login Flow

```
POST /api/v1/auth/login
Headers: Content-Type: application/json
Body: { "username": "admin", "password": "securepassword123" }

Response 200:
{
  "access_token": "<jwt>",
  "refresh_token": "<jwt>",
  "expires_in": 900,
  "user": { "user_id": 1, "username": "admin", "role": "admin", "full_name": "..." }
}
```

### 3.3 Refresh Token Flow

```
POST /api/v1/auth/refresh
Body: { "refresh_token": "<jwt>" }

Response 200:
{ "access_token": "<new_jwt>", "expires_in": 900 }
```

---

## 4. Authorization (RBAC)

- Roles are embedded in the JWT payload as a `role` claim.
- Route-level decorators enforce roles: `@require_role("admin")` or
  `@require_role("cashier")`.
- Admin has access to all endpoints.
- Cashier has access only to: login, create sale, view own sales, search
  products, view own notifications, view cashier dashboard, change own password.
- Unauthorized access returns **403 Forbidden**.
- No valid/expired token returns **401 Unauthorized**.

> **Related:** [07_User_Roles_and_Permissions](../07_User_Roles_and_Permissions/README.md)

---

## 5. Response Format

### 5.1 Standard Response Envelope

All successful responses follow this structure:

```json
{
  "success": true,
  "data": { /* resource or array of resources */ },
  "meta": { /* optional metadata */ }
}
```

For paginated collections:

```json
{
  "success": true,
  "data": [ /* array of items */ ],
  "meta": {
    "page": 1,
    "page_size": 50,
    "total_items": 250,
    "total_pages": 5
  }
}
```

### 5.2 Error Response Format

All errors follow this structure:

```json
{
  "success": false,
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Invalid input provided.",
    "details": [
      { "field": "price", "message": "must be a positive number" }
    ],
    "timestamp": "2026-08-07T10:00:00Z",
    "request_id": "abc-123-def"
  }
}
```

### 5.3 HTTP Status Code Mapping

| Code | Meaning | When Used |
|------|---------|-----------|
| 200 | OK | Successful GET, PUT, PATCH, DELETE |
| 201 | Created | Successful resource creation (POST) |
| 204 | No Content | Successful deletion with no body |
| 400 | Bad Request | Malformed request body |
| 401 | Unauthorized | Missing or invalid token |
| 403 | Forbidden | Valid token but insufficient permissions |
| 404 | Not Found | Resource does not exist |
| 409 | Conflict | Business rule violation (e.g., duplicate SKU, insufficient stock) |
| 422 | Unprocessable Entity | Validation error |
| 429 | Too Many Requests | Rate limit exceeded |
| 500 | Internal Server Error | Unexpected server error |

---

## 6. Pagination, Filtering, and Sorting

### 6.1 Pagination

All collection endpoints accept:

| Parameter | Type | Default | Max |
|-----------|------|---------|-----|
| `page` | integer | 1 | 1000 |
| `page_size` | integer | 50 | 100 |

Response includes `meta` block with pagination info.

### 6.2 Filtering

Filtering is done via query parameters:

```
GET /api/v1/products?category_id=3&min_price=10&max_price=100&search=laptop
GET /api/v1/sales?date_from=2026-01-01&date_to=2026-01-31&payment_method=card
GET /api/v1/users?is_active=true&role=cashier
```

Standard filter parameters:

| Parameter | Applies To |
|-----------|------------|
| `search` | Text search on name/SKU/description |
| `is_active` | Boolean filter (users, products) |
| `date_from`, `date_to` | Date range filter |
| `min_price`, `max_price` | Numeric range |
| `category_id`, `supplier_id` | Foreign key filter |
| `role` | User role filter |
| `payment_method` | Sale payment method filter |
| `status` | Sale/return status filter |
| `movement_type` | Stock movement type filter |
| `is_read` | Notification read status |

### 6.3 Sorting

Sorting is done via `sort_by` and `sort_dir`:

```
GET /api/v1/products?sort_by=price&sort_dir=desc
```

| Parameter | Type | Default |
|-----------|------|---------|
| `sort_by` | string | `created_at` |
| `sort_dir` | string | `desc` |

Allowed `sort_by` values are endpoint-specific (whitelisted in backend).

---

## 7. Validation

### 7.1 Input Validation

- **Frontend:** Zod schemas validate before sending requests.
- **Backend:** Pydantic models validate all incoming data.
- **Database:** Constraints enforce data integrity as the last line of defense.

### 7.2 Validation Rules Examples

| Field | Rule |
|-------|------|
| `username` | 3–50 chars, alphanumeric + underscore, unique |
| `email` | Valid email format |
| `password` | ≥ 8 chars, ≥ 1 uppercase, ≥ 1 lowercase, ≥ 1 digit, ≥ 1 special |
| `product.sku` | 1–50 chars, unique |
| `product.price` | Decimal, ≥ 0 |
| `sale.quantity` | Integer, > 0 |
| `sale.amount_tendered` | Decimal, ≥ total_amount (or credit) |
| `category.parent_id` | Must not create circular reference |
| `stock_movement.quantity` | Non-zero integer |
| `setting.value` | Must match declared `data_type` |

> **Every endpoint must include validation** — per the [Project Bible](AI/SMARTPOS_PROJECT_BIBLE.md#api-conventions).

---

## 8. Security

### 8.1 CORS

- CORS is configured to allow only the frontend origin (from environment
  variable `FRONTEND_URL`).
- Credentials are allowed (`withCredentials`).

### 8.2 Rate Limiting

| Endpoint | Limit |
|----------|-------|
| `/auth/login` | 5 attempts / 15 min / IP |
| `/auth/refresh` | 10 requests / 15 min / IP |
| General API | 1000 requests / minute / IP |
| Password reset | 3 requests / hour / IP |

### 8.3 Sensitive Data Protection

- Passwords, refresh tokens, and secrets are never returned in API responses.
- Audit logs exclude sensitive data (passwords, full tokens).
- Error messages do not reveal internal structure.

> See [18_Security_Architecture](../18_Security_Architecture/README.md) for
> full security measures.

---

## 9. API Endpoint Catalog

### 9.1 Authentication

| Method | Endpoint | Role | Description |
|:------:|:---------|:-----|:------------|
| POST | `/api/v1/auth/login` | Public | Authenticate and receive tokens |
| POST | `/api/v1/auth/refresh` | Public | Refresh access token |
| POST | `/api/v1/auth/logout` | Auth | Invalidate tokens |

### 9.2 Users

| Method | Endpoint | Role | Description |
|:------:|:---------|:-----|:------------|
| GET | `/api/v1/users` | Admin | List all users |
| POST | `/api/v1/users` | Admin | Create a user |
| GET | `/api/v1/users/me` | Auth | Get current user profile |
| GET | `/api/v1/users/{id}` | Admin | Get a user |
| PUT | `/api/v1/users/{id}` | Admin | Update a user (activate) |
| DELETE | `/api/v1/users/{id}/deactivate` | Admin | Deactivate a user |
| POST | `/api/v1/users/{id}/reset-password` | Admin | Reset user password |
| PUT | `/api/v1/users/me/password` | Auth | Change own password |

### 9.3 Products

| Method | Endpoint | Role | Description |
|:------:|:---------|:-----|:------------|
| GET | `/api/v1/products` | Admin, Cashier | List products |
| POST | `/api/v1/products` | Admin | Create product |
| GET | `/api/v1/products/{id}` | Admin, Cashier | Get product |
| PUT | `/api/v1/products/{id}` | Admin | Update product |
| DELETE | `/api/v1/products/{id}` | Admin | Soft-delete product |
| POST | `/api/v1/products/{id}/adjust-stock` | Admin | Adjust stock |

### 9.4 Categories

| Method | Endpoint | Role | Description |
|:------:|:---------|:-----|:------------|
| GET | `/api/v1/categories` | Admin, Cashier | List categories |
| POST | `/api/v1/categories` | Admin | Create category |
| GET | `/api/v1/categories/{id}` | Admin, Cashier | Get category |
| PUT | `/api/v1/categories/{id}` | Admin | Update category |
| DELETE | `/api/v1/categories/{id}` | Admin | Delete category |

### 9.5 Suppliers

| Method | Endpoint | Role | Description |
|:------:|:---------|:-----|:------------|
| GET | `/api/v1/suppliers` | Admin | List suppliers |
| POST | `/api/v1/suppliers` | Admin | Create supplier |
| GET | `/api/v1/suppliers/{id}` | Admin | Get supplier |
| PUT | `/api/v1/suppliers/{id}` | Admin | Update supplier |
| DELETE | `/api/v1/suppliers/{id}` | Admin | Delete supplier |

### 9.6 Inventory

| Method | Endpoint | Role | Description |
|:------:|:---------|:-----|:------------|
| GET | `/api/v1/inventory` | Admin | View inventory |
| POST | `/api/v1/inventory/restock` | Admin | Restock product |
| GET | `/api/v1/inventory/movements` | Admin | View stock movements |

### 9.7 Sales

| Method | Endpoint | Role | Description |
|:------:|:---------|:-----|:------------|
| GET | `/api/v1/sales` | Admin | List all sales |
| POST | `/api/v1/sales` | Cashier | Create a sale |
| GET | `/api/v1/sales/{id}` | Admin | Get a sale |
| GET | `/api/v1/sales/my-sales` | Cashier | View own sales |
| POST | `/api/v1/sales/{id}/void` | Admin | Void a sale |

### 9.8 Returns

| Method | Endpoint | Role | Description |
|:------:|:---------|:-----|:------------|
| GET | `/api/v1/returns` | Admin | List returns |
| POST | `/api/v1/returns` | Admin, Cashier | Process a return |
| GET | `/api/v1/returns/{id}` | Admin | Get return details |

### 9.9 Credit Sales

| Method | Endpoint | Role | Description |
|:------:|:---------|:-----|:------------|
| GET | `/api/v1/credit-balances` | Admin | List credit balances |
| POST | `/api/v1/credit-balances/{id}/settle` | Admin | Settle a credit balance |

### 9.10 Reports

| Method | Endpoint | Role | Description |
|:------:|:---------|:-----|:------------|
| POST | `/api/v1/reports/generate` | Admin | Generate a report |
| POST | `/api/v1/reports/export` | Admin | Export report (Excel/PDF) |

### 9.11 Dashboards

| Method | Endpoint | Role | Description |
|:------:|:---------|:-----|:------------|
| GET | `/api/v1/dashboard/admin` | Admin | Admin dashboard data |
| GET | `/api/v1/dashboard/cashier` | Cashier | Cashier dashboard data |

### 9.12 Notifications

| Method | Endpoint | Role | Description |
|:------:|:---------|:-----|:------------|
| GET | `/api/v1/notifications` | Auth | List user's notifications |
| PUT | `/api/v1/notifications/{id}/read` | Auth | Mark notification as read |

### 9.13 Settings

| Method | Endpoint | Role | Description |
|:------:|:---------|:-----|:------------|
| GET | `/api/v1/settings` | Admin | List all settings |
| PUT | `/api/v1/settings/{key}` | Admin | Update a setting |

### 9.14 Audit Logs

| Method | Endpoint | Role | Description |
|:------:|:---------|:-----|:------------|
| GET | `/api/v1/audit-logs` | Admin | List audit logs |

---

## 10. API Documentation

- **Swagger UI** is auto-generated by FastAPI at `/docs`.
- **OpenAPI 3.x** spec is available at `/openapi.json`.
- All endpoints require authentication unless explicitly marked Public.

---

## 11. Related Documents

- [12_System_Architecture](../12_System_Architecture/README.md)
- [15_Backend_Architecture](../15_Backend_Architecture/README.md)
- [18_Security_Architecture](../18_Security_Architecture/README.md)
- [19_Testing_Strategy](../19_Testing_Strategy/README.md#api-testing)

---

## 12. Revision History

| Version | Date | Author | Description |
|---------|------|--------|-------------|
| 1.0 | 2026-08-07 | SmartPOS Documentation Team | Initial release |
