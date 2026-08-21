# SmartPOS — Testing Strategy

**Document ID:** DOC-TEST-019  
**Version:** 1.0  
**Status:** Approved  
**Author:** SmartPOS Documentation Team  
**Date:** August 7, 2026  

---

## 1. Purpose

This document defines the complete **testing strategy** for SmartPOS. It
covers unit testing, integration testing, API testing, UI/component testing,
user acceptance testing, regression testing, performance testing, and security
testing. Tools, frameworks, coverage targets, and CI/CD integration are
specified.

> **Reference:** [Project Bible — Testing Expectations](../AI/SMARTPOS_PROJECT_BIBLE.md#testing-expectations)

---

## 2. Test Organization

| Layer | Location | Framework | Purpose |
|-------|----------|-----------|---------|
| Backend Unit | `Backend/app/tests/unit/` | pytest | Test individual functions/methods in isolation |
| Backend Integration | `Backend/app/tests/integration/` | pytest | Test services with real or test database |
| API Tests | `Backend/app/tests/api/` | pytest + httpx | Test HTTP endpoints end-to-end |
| Frontend Unit | `Frontend/src/components/__tests__/` | vitest | Test React components |
| Frontend Services | `Frontend/src/services/__tests__/` | vitest | Test business logic hooks |
| End-to-End | `Testing/e2e/` | Playwright | Full application flow tests |

---

## 3. Test Environment

| Environment | Configuration |
|-------------|---------------|
| **Development** | Local dev DB; hot-reload; verbose logging |
| **Testing** | In-memory or throwaway test database; `.env.test` |
| **Staging** | Mirror of production; used for UAT |
| **Production** | Live system |

### 3.1 Test Database

- A **separate SQL Server test database** is created during test runs.
- All test data is seeded and truncated per-test or per-test-session.
- Migrations run automatically at test initialization (Alembic).

---

## 4. Unit Testing

### 4.1 Scope

Unit tests verify individual functions, methods, or classes in isolation using
mocks for external dependencies (database, HTTP, file system).

### 4.2 Backend Coverage Targets

| Module | Target Coverage |
|--------|-----------------|
| `services/` | ≥ 80% |
| `repositories/` | ≥ 80% |
| `utils/` | ≥ 90% |
| `core/security.py` | 100% |
| `core/config.py` | 100% |
| Total (backend) | ≥ 80% |

### 4.3 Test Examples

**Service test (sales):**

```python
def test_create_sale_decrements_stock():
    # Arrange
    product = create_test_product(stock_quantity=10)
    sale_data = SaleCreate(items=[SaleItemCreate(product_id=product.id, quantity=3)])
    # Act
    sale = sales_service.create_sale(sale_data, test_user, db_session)
    # Assert
    assert sale.sale_items[0].quantity == 3
    assert db_session.query(Product).get(product.id).stock_quantity == 7
```

**Repository test:**

```python
def test_get_by_sku_returns_product():
    repo = ProductsRepository(db_session)
    product = create_test_product(sku="TEST-001")
    result = repo.get_by_sku("TEST-001")
    assert result is not None
    assert result.sku == "TEST-001"
```

### 4.4 Frontend Unit Testing

| Component Type | Framework | Target |
|----------------|-----------|--------|
| Utility functions | vitest | ≥ 90% |
| Custom hooks | vitest + @testing-library/react-hooks | ≥ 80% |
| UI components | vitest + @testing-library/react | ≥ 75% |
| API client functions | vitest + msw (mock service worker) | ≥ 80% |

---

## 5. Integration Testing

### 5.1 Scope

Integration tests verify interactions between two or more components:
service + repository, API + database, or external API + service.

### 5.2 Backend Integration Test Examples

| Test | Components Tested |
|------|-------------------|
| Create sale with insufficient stock | Service + Repository + DB constraint |
| Product CRUD with audit logging | Service + Repository + Audit service |
| Login with correct/incorrect credentials | Auth service + User repository + hashing |
| Restock that triggers low-stock notification | Service + DB trigger + Notification service |

### 5.3 Test Data

- Tests use a **factory pattern** (`factories.py`) to create predictable test
  data.
- Each test starts with a clean, seeded database.
- Tests clean up after themselves (rollback or truncate).

---

## 6. API Testing

### 6.1 Scope

API tests verify the HTTP interface end-to-end: request → middleware →
router → service → repository → database → response.

### 6.2 Tools

- **pytest** with **FastAPI's TestClient** (in-process) or **httpx** (out-of-process).
- Request/response assertions on status codes, body, and headers.

### 6.3 Test Coverage

Every endpoint must have at least one "happy path" test and one error-case
test.

| Method | Endpoint | Tests |
|:------:|:---------|:------|
| POST | `/api/v1/auth/login` | Valid login, invalid credentials, locked account |
| POST | `/api/v1/auth/refresh` | Valid refresh, invalid token, expired token |
| GET | `/api/v1/products` | Paginated list, filtered list, unauthorized |
| POST | `/api/v1/products` | Admin create, cashier denied, validation errors |
| PUT | `/api/v1/products/{id}` | Admin update, not found, validation |
| DELETE | `/api/v1/products/{id}` | Admin delete, not found, referenced by sale |

### 6.4 Response Validation

Tests assert:
- HTTP status code
- Response body structure (`success`, `data`, `meta`)
- Field types and values
- Pagination metadata correctness
- Error message format

---

## 7. UI / Component Testing

### 7.1 Framework
- **Vitest** — unit and component tests.
- **@testing-library/react** — testing utilities for React.

### 7.2 Scope

Tests cover:
- Component rendering (props → output).
- User interaction (click, type, submit).
- Form validation (error messages, disabled states).
- Loading and error states.

### 7.3 Example

```tsx
test("Login form validates required fields", async () => {
  render(<LoginPage />);
  await user.click(screen.getByRole("button", { name: /login/i }));
  expect(screen.getByText(/username is required/i)).toBeInTheDocument();
  expect(screen.getByText(/password is required/i)).toBeInTheDocument();
});
```

### 7.4 Scope Coverage Targets

| Page | Key Tests |
|------|-----------|
| Login | Validation, successful login, error display |
| Products | Rendering, search, create modal, edit, delete |
| Sales | Add to cart, quantity validation, complete sale, insufficient stock |
| Users | Create, deactivate, reset password |
| Settings | Inline edit, save, validation |
| Notifications | Mark as read, mark all read |

---

## 8. End-to-End (E2E) Testing

### 8.1 Framework

- **Playwright** (browser automation).
- Runs against a staging or local environment.

### 8.2 Test Scenarios

| Test | Description |
|------|-------------|
| E2E-01 | Login as Admin → Navigate to Products → Create product → Verify in list |
| E2E-02 | Login as Cashier → Search product → Add to cart → Complete sale → Verify inventory decreased |
| E2E-03 | Login as Admin → Restock product → Verify stock movement logged |
| E2E-04 | Login as Admin → Create user → Log in as new user → Change password |
| E2E-05 | Login as Cashier → Process return → Verify inventory restored |
| E2E-06 | Login as Admin → View low stock → Verify notification shown |

### 8.3 CI Integration

- E2E tests run on the `staging` branch after deployment.
- Tests use a fresh staging database seeded with test data.

---

## 9. Security Testing

| Test Type | Tools | Frequency |
|-----------|-------|-----------|
| SAST (Static Analysis) | Bandit (Python), ESLint security plugin, Semgrep | Every commit (CI) |
| Dependency Scanning | pip-audit, `npm audit` | Every commit (CI) |
| DAST (Dynamic Analysis) | OWASP ZAP, Burp Suite | Weekly / Release |
| Penetration Testing | Manual + OWASP ZAP | Quarterly |
| Container Scanning | Trivy | Before release |
| JWT Token Review | Manual + automated scripts | Quarterly |

### 9.1 Security Test Scenarios

| Test | Description |
|------|-------------|
| SEC-01 | Login with correct/wrong credentials |
| SEC-02 | Access admin endpoint as cashier → 403 |
| SEC-03 | Access cashier endpoint as admin → 403 |
| SEC-04 | SQL injection attempt in search → 400 or safe response |
| SEC-05 | XSS payload in product name → escaped in UI |
| SEC-06 | Expired JWT → 401 |
| SEC-07 | Refresh token reuse → token revoked |
| SEC-08 | Rate limit on login endpoint |

---

## 10. Performance Testing

### 10.1 Tools

- **Locust** or **k6** for load testing.
- **pytest** with timing assertions for micro-benchmarks.

### 10.2 Scenarios

| Test | Load | Target Metric |
|------|------|---------------|
| PERF-01 | 100 concurrent users browsing products | API p95 ≤ 200 ms |
| PERF-02 | 50 concurrent cashiers creating sales | Sale creation ≤ 300 ms |
| PERF-03 | Dashboard load with 10k sales | Dashboard data ≤ 3 s |
| PERF-04 | Report generation (30-day range) | Report ≤ 5 s |

### 10.3 Acceptance Criteria

- API p95 response time ≤ 200 ms (NFR-PERF-01).
- Sales creation throughput ≥ 50 concurrent.
- No memory leaks or connection pool exhaustion under sustained load.

---

## 11. User Acceptance Testing (UAT)

### 11.1 Scope

UAT validates that the system meets business requirements from
[04_Business_Requirements](../04_Business_Requirements/README.md). It is
performed by business stakeholders (Admin + Cashier roles) in a staging
environment.

### 11.2 UAT Test Cases

| Test Case | Expected Result |
|-----------|-----------------|
| UAT-01 | Admin can create a product and see it in the list |
| UAT-02 | Cashier can process a sale and see correct receipt |
| UAT-03 | Cashier searches a product and adds to cart |
| UAT-04 | Admin restocks and sees stock updated |
| UAT-05 | Return restores inventory |
| UAT-06 | Admin creates a user and new user can log in |
| UAT-07 | Low stock generates a notification |
| UAT-08 | Reports export correctly |
| UAT-09 | Settings changes persist |
| UAT-10 | Dashboard shows correct KPIs |

### 11.3 Exit Criteria

- All critical and high-priority test cases pass.
- All security scan issues resolved or mitigated.
- Performance benchmarks met.
- No open defects rated critical or high.

---

## 12. Regression Testing

### 12.1 Scope

Regression tests are the combined unit + integration + API test suite. They
run on every commit and must complete within 10 minutes.

### 12.2 Automation

- All backend unit, integration, and API tests run in CI on every PR.
- Frontend unit tests run in CI on every PR.
- E2E tests run on staging deployment.

---

## 13. Test Data Management

### 13.1 Seed Data

- `Database/SeedData/` contains seed SQL for default admin/cashier, base
  categories, and default settings.

### 13.2 Test Data

- `Testing/` contains sample data SQL files for report testing, stock
  scenarios, and historical data.

---

## 14. CI/CD Integration

### 14.1 Pipeline Stages

| Stage | Actions |
|-------|---------|
| **Lint** | ESLint + Prettier (frontend); ruff/flake8 (backend) |
| **Unit Test** | Run all unit + integration tests |
| **API Test** | Run all API tests |
| **Security Scan** | Bandit, pip-audit, npm audit, Trivy |
| **Build** | Build frontend bundle; build Docker images |
| **Deploy** | Deploy to staging; run E2E tests |
| **Release** | Deploy to production |

### 14.2 Coverage Reporting

- Coverage reports generated by `pytest-cov`.
- Threshold: failure if total coverage < 80%.
- Reports uploaded to CI dashboard.

---

## 15. Test Reporting

| Report | Audience | Frequency |
|--------|----------|-----------|
| Unit test coverage | Dev team | Every build |
| API test results | Dev/QA | Every build |
| E2E test results | QA/Product | After staging deploy |
| Security scan report | Security team | Every build + quarterly deep scans |
| Performance report | Dev/QA | Weekly + before releases |
| UAT report | Product/QA | Before each release |

---

## 16. Related Documents

- [15_Backend_Architecture](../15_Backend_Architecture/README.md#12-testing)
- [16_Frontend_Architecture](../16_Frontend_Architecture/README.md#13-tooling)
- [18_Security_Architecture — §15](../18_Security_Architecture/README.md#15-security-testing)
- [06_Non_Functional_Requirements](../06_Non_Functional_Requirements/README.md)
- [SMARTPOS_PROJECT_BIBLE.md](..//../AI/SMARTPOS_PROJECT_BIBLE.md#testing-expectations)

---

## 17. Revision History

| Version | Date | Author | Description |
|---------|------|--------|-------------|
| 1.0 | 2026-08-07 | SmartPOS Documentation Team | Initial release |
