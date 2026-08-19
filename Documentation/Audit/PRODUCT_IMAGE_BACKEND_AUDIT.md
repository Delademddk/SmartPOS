# Backend Audit — Product Image Support (Phase 03A)

Date: 2026-08-10
Scope: SmartPOS `Backend/` only (feature is backend-complete; frontend wiring
is a separate task).

## 1. Current state before changes

The backend had full product CRUD but **no image upload support**:

- `ProductCreate`/`ProductUpdate` accepted an optional `image_url` string; it
  was stored verbatim. Nothing served the URL, so any value was a dangling
  link.
- There was no way to upload, replace, or delete an actual image file.
- No static file serving existed (`app.main` had no `StaticFiles` mount) and no
  local upload directory.
- Config (`app/core/config.py`) had no storage settings.
- No file validation, size caps, resize/optimisation, or unique-naming logic.

## 2. Constraints from the codebase

- SQL Server in production, SQLite in tests → no DB-side binary blobs.
- RBAC: `PermissionCode.PRODUCTS_CREATE`, `PRODUCTS_VIEW`, `PRODUCTS_UPDATE`,
  `PRODUCTS_DELETE`.
- Multipart form support in FastAPI requires raw `Request` parsing (the app
  does not use custom `Form`-based request models elsewhere).
- Backward compatibility: existing JSON consumers must keep working.

## 3. Design decision: JSON and multipart on the same endpoint

Rather than forking into two routes, `_parse_product_request()` in
`app/api/routers/products.py` inspects the `Content-Type`:

| Content-Type | Body | Behaviour |
|---|---|---|
| `application/json` | JSON payload | `image_url` may be set directly (legacy) |
| `multipart/form-data` | `data` field (JSON) + optional `image` file | file is validated/stored, wins over any `image_url` |

This keeps the documented JSON contract intact while adding uploads.

## 4. Storage abstraction

The product service depends only on the `ImageStorageService` interface
(`app/services/image_storage.py`), so the backend can move from local disk
storage (development) to Amazon S3 (future production) without touching product
business logic:

```
Product Router
  -> Product Service
      -> Image Storage Service (ABC)
          -> LocalImageStorageService   (STORAGE_PROVIDER=local, implemented)
          -> S3ImageStorageService      (STORAGE_PROVIDER=s3, planned)
```

Only the public, web-accessible URL/path is ever returned; filesystem paths are
never exposed to callers or stored in the database.

## 5. Files touched

New:

- `app/services/image_storage.py` — `ImageStorageService` ABC,
  `LocalImageStorageService`, `_validate_and_optimize()` (MIME + size +
  decodability checks, resize, re-encode), `ensure_local_upload_directory()`,
  `get_image_storage_service()` (cached factory; raises if `s3` is configured
  but unimplemented).
- `app/tests/api/test_product_images_api.py` — dedicated test suite.
- `app/tests/conftest.py` — `TEST_UPLOAD_DIR` + `_clean_upload_dir()` fixture
  that resets the upload directory before each test.

Modified:

- `app/core/config.py` — `storage_provider`, `local_upload_dir`,
  `max_product_image_size`, `allowed_product_image_types`,
  `product_image_max_dimension` (+ `allowed_image_types_list` property).
- `app/exceptions/__init__.py` — `ImageValidationError(BadRequestError)`
  with code `INVALID_IMAGE`.
- `app/main.py` — for `storage_provider == "local"`: create the upload
  directory on startup and mount `StaticFiles` at `/uploads/products`.
- `app/services/products_service.py` — persists `image_url` on create; handles
  replace (`image`) / remove (`remove_image`) on update; deletes the stored
  file on product delete; errors when both `image` and `remove_image` are
  supplied.
- `app/api/routers/products.py` — multipart parsing for create/update.
- `.env.example` / `.env` — storage settings.
- `.gitignore` — ignore `Backend/uploads/`.
- `Backend/README.md` — product-image section.

Unchanged behaviour: JSON product create/update, RBAC, response envelopes,
pagination, error handling.

## 6. Validation & safety rails

`_validate_and_optimize()`:

- Rejects empty uploads.
- Enforces `MAX_PRODUCT_IMAGE_SIZE` (default 2 MB).
- Enforces the MIME allow-list (`ALLOWED_PRODUCT_IMAGE_TYPES`, default
  `image/jpeg,image/png,image/webp`).
- Decodes the file with Pillow — magic bytes are checked, not just the
  client-supplied content type; refuses non-decodable files.
- Resizes to `PRODUCT_IMAGE_MAX_DIMENSION` (default 1600px, longest side,
  aspect-ratio preserving).
- Re-encodes (JPEG quality 85 optimize, PNG optimize, WebP quality 85).
- All violations raise `ImageValidationError` → HTTP **400** code
  `INVALID_IMAGE`.

Storage safety:

- Filenames are server-generated `uuid4().hex` — no collisions, no traversal.
- `delete_product_image()` resolves the target and verifies it stays inside the
  upload root before unlinking.

## 7. Behaviour contract

- `POST /api/v1/products` (multipart): stores image, returns `201` +
  `image_url`.
- `PUT /api/v1/products/{id}` (multipart): new `image` replaces the old one
  (old file removed); `remove_image=true` clears the image (file removed);
  supplying both is a 400.
- `DELETE /api/v1/products/{id}`: product + image file removed.
- `GET /uploads/products/<uuid>.<ext>`: static file serving.
- RBAC enforced exactly as before (upload requires `PRODUCTS_CREATE` etc.).
