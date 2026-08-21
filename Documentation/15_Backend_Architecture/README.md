# SmartPOS — Backend Architecture

**Document ID:** DOC-BE-015  
**Version:** 1.0  
**Status:** Approved  
**Author:** SmartPOS Documentation Team  
**Date:** August 7, 2026  

---

## 1. Purpose

This document describes the **backend architecture** for SmartPOS — the
FastAPI application layer that sits between the React frontend and the SQL
Server database. It covers folder structure, layer responsibilities,
dependency injection, validation, authentication, authorization, logging, and
configuration.

---

## 2. Folder Structure

The backend follows the structure defined in the
[Project Bible](../AI/SMARTPOS_PROJECT_BIBLE.md#project-structure):

```
Backend/
├── app/
│   ├── api/
│   │   ├── routers/          # One router per module (products, sales, etc.)
│   │   ├── schemas/            # Pydantic request/response models
│   │   └── dependencies/       # Shared deps (auth, database session)
│   ├── services/               # Business logic (one service per module)
│   ├── repositories/           # Data access (SQLAlchemy queries, one per module)
│   ├── models/                 # SQLAlchemy ORM models
│   ├── database/               # Connection, base model, session management
│   ├── middleware/             # Auth, CORS, logging, error handling
│   ├── core/                   # Configuration, security, constants
│   ├── utils/                  # Helper functions (hashing, tokens)
│   └── tests/                  # Unit, integration, and API tests
├── requirements.txt
├── .env.example
├── .env                        # (git-ignored)
└── README.md
```

### 2.1 Directory Purpose

| Directory | Purpose |
|-----------|---------|
| `api/routers/` | FastAPI `APIRouter` instances — one per domain module. Each defines route methods, query params, and delegates to services. |
| `api/schemas/` | Pydantic models (`BaseModel`) for input validation and output serialization. Includes `Create`, `Update`, `Read`, and `Base` variants per resource. |
| `api/dependencies/` | Reusable dependencies for route functions — e.g., `get_current_user`, `get_db_session`, `require_admin`, `require_cashier`. |
| `services/` | Pure business logic. Stateless. Calls repositories and implements rules from [10_Business_Rules](../10_Business_Rules/README.md). |
| `repositories/` | Data access layer. Wraps SQLAlchemy queries. No business logic — only persistence operations. |
| `models/` | SQLAlchemy declarative ORM models — one per database table. |
| `database/` | `engine.py` (connection), `base.py` (declarative base), `session.py` (session factory), `init_db.py`. |
| `middleware/` | ASGI middleware classes for auth, CORS, request logging, and global exception handling. |
| `core/` | `config.py` (env-based settings via Pydantic Settings), `security.py` (password hashing, JWT), `constants.py`. |
| `utils/` | Reusable helpers — `hashing.py`, `token.py`, `pagination.py`, `csv_export.py`, `pdf_generator.py`. |
| `tests/` | `unit/`, `integration/`, `api/` test directories. Uses `pytest` and `httpx` for testing. |

---

## 3. Layer Responsibilities

### 3.1 Presentation Layer (API Routers)

The routers are the **interface adapters** of Clean Architecture. They:

- Define HTTP routes using FastAPI's `APIRouter`.
- Receive HTTP requests and extract parameters.
- Validate input via Pydantic schemas.
- Delegate to the appropriate service.
- Format and return the HTTP response.
- Apply dependency-based authentication and authorization.

**Example** (`api/routers/sales.py`):

```python
@router.post("/", response_model=SaleResponse)
async def create_sale(
    sale_in: SaleCreate,
    current_user=Depends(require_cashier),
    db=Depends(get_db_session)
):
    # Input validated by SaleCreate schema
    sale = await sales_service.create_sale(sale_in, current_user, db)
    return sale
```

### 3.2 Business Logic Layer (Services)

The services contain **all business logic**. They:

- Implement the business rules from [10_Business_Rules](../10_Business_Rules/README.md).
- Call repositories for data access.
- Enforce transactional boundaries (`@transactional` decorator or explicit
  session commit/rollback).
- Raise domain-specific exceptions (e.g., `InsufficientStockError`).

**Example** (`services/sales_service.py`):

```python
async def create_sale(sale_in: SaleCreate, user: User, session):
    async with session.begin():
        # Validate stock sufficiency (BR-SALE-03)
        # Create sale header (BR-SALE-02)
        # Create sale items
        # Decrement stock (BR-INV-01)
        # Log stock movements (BR-INV-04)
        # If credit: create credit balance (BR-CR-01)
        # Log audit (BR-AUD-01)
        return sale
```

### 3.3 Data Access Layer (Repositories)

The repositories handle **all database operations**:

- Encapsulate SQLAlchemy queries.
- No business logic — only persistence.
- Each module has its own repository class.
- Return ORM model instances or primitive values.

**Example** (`repositories/products_repo.py`):

```python
class ProductsRepository:
    def __init__(self, session):
        self.session = session

    async def get_by_sku(self, sku: str) -> Product | None:
        return await self.session.execute(
            select(Product).where(Product.sku == sku)
        )

    async def update_stock(self, product_id: int, new_quantity: int):
        # Row-level lock to prevent race conditions
        ...
```

### 3.4 Database Layer (ORM Models + SQL Server)

SQLAlchemy ORM models map to SQL Server tables. Alembic manages migrations.
Stored procedures and triggers enforce additional database-level business rules
(see [13_Database_Overview](../13_Database_Overview/README.md)).

---

## 4. Dependency Injection

FastAPI's built-in dependency injection system is used throughout:

| Dependency | Location | Purpose |
|------------|----------|---------|
| `get_db_session` | `api/dependencies/database.py` | Provides SQLAlchemy session per request |
| `get_current_user` | `api/dependencies/auth.py` | Decodes JWT, loads user |
| `require_admin` | `api/dependencies/auth.py` | Asserts `user.role == 'admin'` |
| `require_cashier` | `api/dependencies/auth.py` | Asserts `user.role == 'cashier'` |
| `get_pagination` | `api/dependencies/pagination.py` | Extracts page/page_size from query |
| `require_setting` | `api/dependencies/settings.py` | Loads a setting value |

This makes components loosely coupled and easily testable.

---

## 5. Validation

### 5.1 Input Validation Layer Stack

1. **Frontend (Zod + React Hook Form)** — immediate user feedback.
2. **Backend (Pydantic schemas)** — authoritative validation.
   - `Create` schemas use `model_config = ConfigDict(extra="forbid")` to
     reject unknown fields.
   - `Update` schemas use `Optional` fields for partial updates.
3. **Database (constraints)** — last line of defense.

### 5.2 Validation Examples

```python
class ProductCreate(BaseModel):
    sku: str = Field(..., min_length=1, max_length=50, pattern=r"^[A-Za-z0-9\-_]+$")
    name: str = Field(..., min_length=1, max_length=255)
    price: Decimal = Field(..., ge=0)
    cost: Decimal = Field(..., ge=0)
    stock_quantity: int = Field(default=0, ge=0)
    category_id: int | None = None
    supplier_id: int | None = None
    low_stock_threshold: int = Field(default=0, ge=0)
```

> Every endpoint includes validation — per [Project Bible](AI/SMARTPOS_PROJECT_BIBLE.md#api-conventions).

---

## 6. Authentication

### 6.1 Components

| Component | File | Responsibility |
|-----------|------|----------------|
| Password hashing | `core/security.py` | `hash_password()`, `verify_password()` using bcrypt |
| JWT creation | `utils/token.py` | `create_access_token()`, `create_refresh_token()` |
| JWT verification | `middleware/auth.py` | Decode, verify signature, check expiry |
| Refresh token storage | `models/refresh_token.py` + DB | Store hashed refresh token, revocable |
| Login rate limiting | `middleware/rate_limit.py` | Max 5 attempts per 15 min per IP |

### 6.2 Login Flow

```
1. POST /api/v1/auth/login { username, password }
2. Rate limit middleware (5 attempts limit)
3. Auth service: fetch user → verify password (bcrypt) → check is_active
4. Token util: create access_token (15 min) + refresh_token (7 days)
5. Store hashed refresh_token in DB
6. Log audit entry
7. Return tokens + user profile
```

> See [18_Security_Architecture](../18_Security_Architecture/README.md#2-authentication)
> for full security details.

---

## 7. Authorization (RBAC)

Authorization is enforced via FastAPI dependencies:

```python
def require_admin(user: User = Depends(get_current_user)):
    if user.role != "admin":
        raise HTTPException(403, "Admin access required")
    return user

def require_cashier(user: User = Depends(get_current_user)):
    if user.role != "cashier":
        raise HTTPException(403, "Cashier access required")
    return user
```

Routes are decorated:

```python
@router.get("/admin/users")
async def list_users(current_user=Depends(require_admin)): ...

@router.post("/sales")
async def create_sale(current_user=Depends(require_cashier)): ...
```

---

## 8. Logging

### 8.1 Types of Logging

| Type | What | Where |
|------|------|-------|
| **Application logs** | Request/response, errors, warnings | `app.log` (JSON format) |
| **Audit logs** | User actions (create/update/delete/login) | `audit_logs` database table |
| **Security logs** | Login attempts, auth failures | `audit_logs` + application log |
| **Business event logs** | Sales created, returns processed | `audit_logs` table |

### 8.2 Logging Structure

```python
import structlog

log = structlog.get_logger()

# In service:
log.info("sale_created", sale_id=sale.id, user_id=user.id, items=len(items))
```

All log entries include: timestamp, log level, correlation ID, user_id
(if authenticated), and structured key-value pairs.

---

## 9. Configuration

### 9.1 Environment Variables

All configuration comes from environment variables. A `.env.example` file is
provided with placeholders.

```env
# Backend
APP_ENV=development
APP_HOST=0.0.0.0
APP_PORT=8000
DEBUG=false

# Database
DATABASE_URL=postgresql+pyodbc://user:password@localhost/SmartPOS?driver=ODBC+Driver+17+for+SQL+Server

# Security
JWT_SECRET_KEY=replace-with-a-secure-random-string
JWT_ALGORITHM=HS256
JWT_ACCESS_TOKEN_EXPIRE_MINUTES=15
JWT_REFRESH_TOKEN_EXPIRE_DAYS=7
BCRYPT_ROUNDS=12
ENCRYPTION_KEY=replace-with-32-byte-key

# CORS
FRONTEND_URL=http://localhost:5173

# Logging
LOG_LEVEL=INFO

# Features
ENABLE_AUDIT_LOG=true
ENABLE_NOTIFICATIONS=true
```

> **Never hardcode secrets** — per [Project Bible](AI/SMARTPOS_PROJECT_BIBLE.md#security-requirements).

### 9.2 Configuration Loading

Pydantic's `BaseSettings` loads and validates all environment variables at
startup:

```python
class Settings(BaseSettings):
    app_env: str = "development"
    database_url: str
    jwt_secret_key: str
    jwt_algorithm: str = "HS256"
    # ...
    model_config = SettingsConfigDict(env_file=".env")
```

---

## 10. Error Handling

### 10.1 Global Exception Handler

```python
@app.exception_handler(HTTPException)
async def http_exception_handler(request, exc):
    log.warning("http_error", status_code=exc.status_code, detail=exc.detail)
    return JSONResponse(
        status_code=exc.status_code,
        content={"success": False, "error": {"code": "...", "message": exc.detail}},
    )
```

### 10.2 Custom Exceptions

| Exception | When Raised | HTTP Code |
|-----------|-------------|-----------|
| `InsufficientStockError` | Sale requested more stock than available | 409 |
| `DuplicateSKUError` | SKU already exists | 409 |
| `DuplicateUsernameError` | Username already exists | 409 |
| `InvalidCredentialsError` | Login with wrong password | 401 |
| `AccountLockedError` | Too many failed login attempts | 423 |
| `ValidationErrorDetail` | Input validation failure | 422 |

---

## 11. Cross-Cutting Concerns

### 11.1 Audit Trail

Every significant action calls `audit_service.log_action()`:

```python
await audit_service.create_log(
    user_id=user.id,
    action_type="SALE_CREATED",
    resource_type="sale",
    resource_id=sale.id,
    details={"items_count": len(items), "total": sale.total_amount},
)
```

### 11.2 Notifications

Triggered by database triggers or application logic. See
[18_Security_Architecture — §5](../18_Security_Architecture/README.md#5-notifications).

### 11.3 Transactions

All multi-step write operations use explicit database transactions:

```python
async with db.begin():
    sale = await sales_repo.create(sale_data)
    for item in items:
        await sale_items_repo.create(item)
        await products_repo.decrement_stock(item.product_id, item.quantity)
        await stock_movements_repo.create(...)
    await audit_repo.create(...)
```

---

## 12. Testing

Backend tests are organized under `app/tests/`:

| Category | Location | Framework |
|----------|----------|-----------|
| Unit tests | `tests/unit/` | pytest |
| Integration tests | `tests/integration/` | pytest + httpx |
| API tests | `tests/api/` | pytest + FastAPI TestClient |

> See [19_Testing_Strategy](../19_Testing_Strategy/README.md) for full details.

---

## 13. Related Documents

- [12_System_Architecture](../12_System_Architecture/README.md)
- [14_API_Architecture](../14_API_Architecture/README.md)
- [18_Security_Architecture](../18_Security_Architecture/README.md)
- [19_Testing_Strategy](../19_Testing_Strategy/README.md)
- [21_Project_Structure](../21_Project_Structure/README.md)
- [SMARTPOS_PROJECT_BIBLE.md](..//../AI/SMARTPOS_PROJECT_BIBLE.md)

---

## 14. Revision History

| Version | Date | Author | Description |
|---------|------|--------|-------------|
| 1.0 | 2026-08-07 | SmartPOS Documentation Team | Initial release |
