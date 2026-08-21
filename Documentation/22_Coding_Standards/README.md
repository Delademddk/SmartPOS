# SmartPOS — Coding Standards

**Document ID:** DOC-CS-022  
**Version** 1.0  
**Status:** Approved  
**Author:** SmartPOS Documentation Team  
**Date:** August 7, 2026  

---

## 1. Purpose

This document defines the **coding standards** for SmartPOS. It covers naming
conventions, formatting rules, architectural principles (Clean Architecture and
SOLID), documentation standards, and the Git workflow.

> **Reference:** [Project Bible — Coding Standards](../AI/SMARTPOS_PROJECT_BIBLE.md#coding-standards)

---

## 2. Naming Conventions

### 2.1 Python (Backend)

| Element | Convention | Example |
|---------|------------|---------|
| Module / package | `snake_case` | `auth.py`, `products.py` |
| Class | `PascalCase` | `ProductService`, `OAuth2Scheme` |
| Function / method | `snake_case` | `create_sale()`, `validate_stock()` |
| Variable | `snake_case` | `total_amount`, `is_active` |
| Constant | `UPPER_SNAKE_CASE` | `MAX_LOGIN_ATTEMPTS` |
| Enum members | `UPPER_SNAKE_CASE` | `UserRole.ADMIN` |
| Private method | `_snake_case` | `_verify_password()` |
| Abstract base class | `PascalCase` with `Base` suffix | `BaseRepository` |
| Exception | `PascalCase` with `Error` suffix | `InsufficientStockError` |

### 2.2 TypeScript / React (Frontend)

| Element | Convention | Example |
|---------|------------|---------|
| File / directory | `kebab-case` | `products-list.tsx`, `use-sales.ts` |
| Component (React) | `PascalCase` | `ProductList`, `ButtonPrimary` |
| Function component | `PascalCase` | `export function ProductList()` |
| Custom hook | `camelCase` + `use` prefix | `useProducts`, `useAuth` |
| Type / interface | `PascalCase` | `Product`, `SaleItem` |
| Interface (prefixed) | `I` + PascalCase or `PascalCase` | `Product` (preferred, no `I` prefix) |
| Enum | `PascalCase` | `PaymentType`, `UserRole` |
| Variable / prop | `camelCase` | `totalAmount`, `isOpen` |
| Constant | `UPPER_SNAKE_CASE` | `DEFAULT_PAGE_SIZE` |
| Boolean prop | `is` / `has` / `can` prefix | `isLoading`, `hasError`, `canDelete` |

### 2.3 SQL (Database)

| Element | Convention | Example |
|---------|------------|---------|
| Table name | Plural, `snake_case` | `products`, `sale_items` |
| Column name | `snake_case` | `product_id`, `created_at` |
| Primary key | `singular + _id` | `product_id`, `sale_id` |
| Foreign key | `referenced_table + _id` | `product_id` |
| Index | `IX_<table>_<cols>` | `IX_products_category_id` |
| Unique constraint | `UQ_<table>_<cols>` | `UQ_products_sku` |
| Check constraint | `CK_<table>_<condition>` | `CK_products_price_non_negative` |
| Stored procedure | `SP_<Verb><Entity>` | `SP_CreateSale` |
| View | `VW_<Purpose>` | `VW_SalesSummary` |
| Trigger | `TRG_<table>_<event>` | `TRG_products_audit` |

---

## 3. Formatting

### 3.1 Linting & Formatting Tools

| Layer | Tool | Configuration |
|-------|------|---------------|
| Backend (Python) | **ruff** (lint) + **black** (format) | `pyproject.toml` |
| Frontend (TypeScript) | **ESLint** + **Prettier** | `.eslintrc`, `.prettierrc` |
| SQL | Manual review + `sqlfluff` (optional) | `.sqlfluff` |

### 3.2 Indentation

| Layer | Indentation |
|-------|-------------|
| Python | 4 spaces |
| TypeScript | 2 spaces |
| SQL | 4 spaces |
| JSON/YAML | 2 spaces |

### 3.3 Line Length

| Layer | Max Length |
|-------|------------|
| Python | 88 characters (black default) |
| TypeScript | 100 characters |
| SQL | 120 characters |

### 3.4 Import Ordering (Python)

```python
# Standard library
import os
from datetime import datetime

# Third-party
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select

# Local first-party
from app.core.security import hash_password
from app.models.user import User
from app.schemas.user import UserCreate
```

### 3.5 Import Ordering (TypeScript)

```typescript
// External packages (alphabetical)
import { useState, useEffect } from "react";
import axios from "axios";

// Internal imports (by path)
import { apiClient } from "@/api/client";
import { Product } from "@/types";
import { Button } from "@/components/ui/button";
```

---

## 4. Architectural Principles

### 4.1 Clean Architecture

SmartPOS follows Clean Architecture with the following constraints:

1. **Entities** never depend on anything except the language itself.
2. **Use Cases** depend only on entities.
3. **Interface Adapters** depend on use cases.
4. **Frameworks & Drivers** depend on the above layers.

In SmartPOS:
- **Entities** → SQLAlchemy ORM models (`models/`)
- **Use Cases** → Application services (`services/`)
- **Interface Adapters** → Repositories (`repositories/`), Schemas (`schemas/`),
  Routers (`routers/`)
- **Frameworks & Drivers** → Database, FastAPI framework

### 4.2 SOLID Principles

| Principle | Application in SmartPOS |
|-----------|------------------------|
| **Single Responsibility** | Each class has one reason to change (e.g., `ProductService` only handles product business logic). |
| **Open/Closed** | Services are open for extension but closed for modification (via strategy pattern for future discount rules, etc.). |
| **Liskov Substitution** | Repository interfaces ensure any implementation can substitute. |
| **Interface Segregation** | Thin repository interfaces per module. |
| **Dependency Inversion** | High-level services depend on abstract repositories (interfaces), not concrete implementations. |

### 4.3 No Duplicated Code

- Shared logic lives in `utils/` or `core/`.
- Reusable UI components live in `components/ui/`.
- Common API request/response structures use shared types.
- Database operations share repository base classes.

### 4.4 No Dead Code

- No commented-out code.
- No unused imports.
- No unreachable code paths.
- No unused variables.

---

## 5. Documentation Standards

### 5.1 Docstrings (Python)

Every module, class, and public function must have a docstring:

```python
"""Service layer for product management."""

class ProductService:
    """Handle product business logic: CRUD and stock adjustments."""

    def create_product(self, product_in: ProductCreate) -> Product:
        """Create a new product after validation and uniqueness check.

        Args:
            product_in: Validated product data (Pydantic schema).

        Returns:
            The created Product ORM instance.

        Raises:
            DuplicateSKUError: If the SKU already exists.
            CategoryNotFoundError: If the category does not exist.
        """
        ...
```

### 5.2 JSDoc / TSDoc (TypeScript)

```typescript
/**
 * Fetches a paginated list of products.
 *
 * @param params - Pagination and filter parameters.
 * @returns Promise resolving to paginated product data.
 * @throws {ApiError} If the request fails.
 */
export async function fetchProducts(params: ProductListParams): Promise<PaginatedResponse<Product>> {
  ...
}
```

### 5.3 README Files

Every major directory should have a `README.md`:
- `Backend/README.md` — Backend setup and run instructions.
- `Frontend/README.md` — Frontend setup and run instructions.
- `Database/README.md` — Database setup instructions.
- Each module directory should have a brief README or the parent README must
  explain it.

---

## 6. Error Handling

### 6.1 Python Errors

- Raise `HTTPException` from FastAPI routers for API errors.
- Raise custom domain exceptions (`InsufficientStockError`, etc.) from services.
- Use a global exception handler to format all errors consistently.
- Never swallow exceptions silently — always log and re-raise or handle explicitly.

```python
# services/sales.py
if not product:
    raise ProductNotFoundError(f"Product with id={product_id} not found")
```

### 6.2 TypeScript Errors

- Use a typed `ApiError` class with `status`, `code`, `message`, and `details`.
- Catch errors at the component level and display user-friendly messages.
- Never expose internal error details to end users.

```typescript
// api/client.ts
axios.interceptors.response.use(
  (response) => response,
  (error: AxiosError) => {
    if (error.response) {
      return Promise.reject(new ApiError(error.response.data));
    }
    return Promise.reject(error);
  }
);
```

---

## 7. Testing Conventions

### 7.1 Naming

Test files must match the file they test, with `.test.` inserted:

| Source File | Test File |
|-------------|-----------|
| `services/sales.py` | `services/test_sales.py` or `tests/unit/test_sales_service.py` |
| `api/client.ts` | `api/client.test.ts` |
| `components/Button.tsx` | `components/__tests__/Button.test.tsx` |

Test function names follow `test_<behavior>_when_<scenario>_then_<outcome>`:

```python
def test_create_sale_decrements_stock_when_valid_quantity_provided_then_stock_reduced():
    ...
```

### 7.2 Coverage

All new code must include tests:
- Business logic (services): 100% coverage for edge cases.
- API endpoints: At least happy path + error case.
- UI components: At least render + key interaction.

---

## 8. Git Workflow

### 8.1 Branch Strategy

**GitHub Flow** (simplified):

```
main (production-ready)
  ├── feature/create-product-page
  ├── feature/pos-sales-workflow
  └── hotfix/login-rate-limit
```

### 8.2 Commit Messages

Follow [Conventional Commits](https://www.conventionalcommits.org/):

```
feat(products): add create product endpoint
fix(sales): resolve negative stock edge case
docs(api): update auth endpoint documentation
refactor(inventory): extract stock calculation to service
test(users): add unit tests for deactivate flow
```

| Prefix | Meaning |
|--------|---------|
| `feat` | New feature |
| `fix` | Bug fix |
| `docs` | Documentation change |
| `style` | Formatting, whitespace (no logic change) |
| `refactor` | Code refactor (no behavior change) |
| `perf` | Performance improvement |
| `test` | Add or fix tests |
| `chore` | Tooling, config, maintenance |
| `ci` | CI/CD changes |
| `build` | Build system changes |
| `revert` | Revert a previous commit |

### 8.3 Pull Requests

- All code changes go through a Pull Request.
- Minimum 1 reviewer (Admin role or senior dev).
- CI must pass (lint, test, security scan) before merge.
- No merging on untested code.

### 8.4 Release Tags

- Releases tagged with SemVer: `v1.2.0`.
- Tag pushed after merge to `main`.
- CI auto-deploys tagged releases to staging.

---

## 9. Security Coding Practices

| Practice | Implementation |
|----------|----------------|
| No hardcoded secrets | Use environment variables (`os.environ`, `pydantic-settings`) |
| No SQL injection | SQLAlchemy ORM with bound parameters; no raw SQL string concatenation |
| No XSS | React escaping + CSP headers |
| No CSRF | JWT in Authorization header (+ SameSite cookies for refresh) |
| Input validation | Pydantic on backend; Zod on frontend |
| Logging hygiene | Never log passwords, tokens, or PII |
| Dependency safety | `pip-audit`, `npm audit` in CI |

---

## 10. Code Quality Gates

| Check | Tool | Fail Build? |
|-------|------|-------------|
| Python linting | ruff | Yes |
| Python formatting | black (check mode) | Yes |
| Python type checking | mypy | Yes (errors) |
| TS linting | ESLint | Yes |
| TS formatting | Prettier (check) | Yes |
| Test coverage | pytest-cov (backend) | Yes (< 80%) |
| Security scan | pip-audit, npm audit | Yes (high/critical) |

---

## 11. References

- [SMARTPOS_PROJECT_BIBLE.md](..//../AI/SMARTPOS_PROJECT_BIBLE.md#coding-standards)
- [15_Backend_Architecture](../15_Backend_Architecture/README.md)
- [16_Frontend_Architecture](../16_Frontend_Architecture/README.md)
- [19_Testing_Strategy](../19_Testing_Strategy/README.md#12-cicd-integration)
- [20_Deployment_Strategy](../20_Deployment_Strategy/README.md#11-release-process)

---

## 12. Revision History

| Version | Date | Author | Description |
|---------|------|--------|-------------|
| 1.0 | 2026-08-07 | SmartPOS Documentation Team | Initial release |
