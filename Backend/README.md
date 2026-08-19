# SmartPOS Backend

FastAPI backend for the SmartPOS Point of Sale and Inventory Management
system. Mirrors the SQL Server schema in `Database/SQL`, follows the API
architecture in `Documentation/14_API_Architecture`, and implements every
feature F01-F20 from `AI/SMARTPOS_PROJECT_BIBLE.md`.

## Tech stack

- FastAPI + Uvicorn
- SQLAlchemy 2.0 ORM (SQL Server production / SQLite for tests)
- Pydantic v2 (request validation + ORM serialisation)
- PyJWT access/refresh tokens with persistent sessions
- Alembic for migrations
- structlog for structured JSON logging

## Project layout

```
Backend/
  app/
    api/
      dependencies/   FastAPI dependencies (DB session, auth, RBAC)
      routers/        One router per feature
      schemas/        Pydantic request/response models
    core/             Settings, security, constants, logging
    database/         Engine, session, Base, init helpers
    exceptions/       Domain exceptions + error envelope mapping
    middleware/       Request ID, access log, rate limit, error handlers
    models/           SQLAlchemy ORM models mirroring Database/SQL
    repositories/     Data access layer (one repo per aggregate)
    services/         Business logic layer (one service per feature)
    utils/            Response envelope, pagination, number generation
    validators/       Password policy, email/username checks
  alembic/            Migration environment + baseline
  scripts/            setup_venv.bat, setup_database.bat, run_server.bat
```

## Quick start

1. **Create the database** using the SQL scripts:

   ```bat
   scripts\setup_database.bat
   ```

2. **Configure environment**: copy `.env.example` to `.env` and fill in
   `DB_USERNAME`, `DB_PASSWORD`, `JWT_SECRET_KEY`.

3. **Create a virtual environment and install dependencies**:

   ```bat
   scripts\setup_venv.bat
   ```

4. **Run the API**:

   ```bat
   scripts\run_server.bat
   ```

5. Open interactive docs at `http://127.0.0.1:8000/docs`.

## Environment variables

All configuration is read from environment variables / `.env` — see
`.env.example` for the full list. A full SQLAlchemy URL in `DATABASE_URL`
overrides the individual `DB_*` settings.

## API conventions

- All endpoints live under `/api/v1`.
- Successful responses: `{"success": true, "data": ..., "meta": {...}}`
- Errors: `{"success": false, "error": {code, message, details, timestamp, request_id}}`
- Authentication: `Authorization: Bearer <access_token>`
- Pagination: `?page=1&page_size=50` (max 200)

## Features

| # | Feature | Router |
|---|---------|--------|
| F01 | RBAC roles & permissions | `roles.py` |
| F02 | Authentication & sessions | `auth.py` |
| F03 | Role management | `roles.py` |
| F04 | User management | `users.py` |
| F05 | Business info, tax rates | `business.py` |
| F06 | Categories | `categories.py` |
| F07 | Products | `products.py` |
| F08 | Suppliers | `suppliers.py` |
| F09 | Inventory | `inventory.py` |
| F10 | Sales | `sales.py` |
| F11 | Payments | `payments.py` |
| F12 | Credit sales | `credits.py` |
| F13 | Returns | `returns.py` |
| F14 | Notifications | `notifications.py` |
| F15 | Reports & settings | `reports.py`, `settings.py` |
| F16 | Dashboard | `dashboard.py` |
| F17 | Audit logs | `audit.py` |

## Database migrations

The schema is installed from the `Database/SQL` scripts. After creating the
database, stamp the Alembic baseline so future migrations track cleanly:

```bat
alembic stamp 0001
```

Generate future migrations with:

```bat
alembic revision --autogenerate -m "describe change"
alembic upgrade head
```

## Tests

Run with pytest (SQLite in-memory; no external DB required):

```bat
.venv\Scripts\activate.bat
pytest
```

Covered areas: password policy, inventory stock operations, sale creation and
voiding, returns, credit ledger and settlement, plus the health and auth API
flows.

## Product images (Phase 03A)

Products support one optional image per product, uploaded as
`multipart/form-data` alongside the JSON payload in the `data` field.

- `POST /api/v1/products` — `data` (JSON) + optional `image` file
- `PUT /api/v1/products/{id}` — `data` (JSON) + optional `image` to replace, or
  `remove_image=true` to remove the current image
- `DELETE /api/v1/products/{id}` — removes the product and its stored image
- Image URLs are returned as `image_url` and served statically under
  `/uploads/products/...`

Storage is pluggable via `app/services/image_storage.py`:

- `LocalImageStorageService` (default) saves files under `LOCAL_UPLOAD_DIR`
  (`uploads/products`), cleaned up on replace/remove/delete.
- `ImageStorageService` is the interface; an S3 implementation is planned —
  set `STORAGE_PROVIDER=s3` (currently raises until it is implemented).

Safety rails:

- Allowed content types: JPEG, PNG, WebP.
- `MAX_PRODUCT_IMAGE_SIZE` (default 2 MB) caps uploads (HTTP 400
  `INVALID_IMAGE`).
- Images are re-encoded/resized to a max 1600px dimension before saving.
- Filenames are UUID-based to avoid collisions / path traversal.

See `Documentation/Audit/PRODUCT_IMAGE_BACKEND_*.md` for the audit,
verification report, and change log.

