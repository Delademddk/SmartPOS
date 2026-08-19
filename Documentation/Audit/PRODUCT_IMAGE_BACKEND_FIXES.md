# Change Log — Product Image Support (Phase 03A)

Date: 2026-08-10

## New features

1. **Image upload on product create/update** via `multipart/form-data`
   (`data` field carries the JSON payload). JSON-only requests keep working.
2. **Replace / remove**: `PUT /api/v1/products/{id}` accepts a new `image`
   (replaces and cleans up the old file) or `remove_image=true` (clears the
   image and removes the file). Supplying both is rejected with 400.
3. **Static serving**: for `STORAGE_PROVIDER=local`, FastAPI mounts
   `/uploads/products` → `LOCAL_UPLOAD_DIR` (default `uploads/products`).
4. **Pluggable storage**: `ImageStorageService` interface +
   `get_image_storage_service()` factory in `app/services/image_storage.py`;
   `LocalImageStorageService` implemented, `S3ImageStorageService` planned.
   Enabling `STORAGE_PROVIDER=s3` now raises a clear error until the S3 service
   is implemented (prevents silent misconfiguration).

## Fixes / improvements

- Client-supplied `image_url` is no longer trusted blindly when a file is
  uploaded — the uploaded file wins, preventing URL/image divergence.
- Upload directory is created automatically on startup and by the storage
  service, so a fresh checkout does not need a manual `mkdir`.
- Image deletion is confined to the upload root (`resolve()` +
  `is_relative_to`), so a crafted URL cannot unlink arbitrary files.
- Added `.gitignore` rule so `Backend/uploads/` (user content) is never
  committed.

## Safety rails added

- MIME allow-list (JPEG, PNG, WebP) + Pillow decodability check → `400
  INVALID_IMAGE` for wrong/empty/non-image uploads.
- `MAX_PRODUCT_IMAGE_SIZE` (default 2 MB) cap → `400 INVALID_IMAGE`.
- UUID server-generated filenames → no collisions, no traversal.
- Pillow re-encode + resize (max 1600px, aspect-ratio preserving).
- RBAC unchanged: uploads require `PRODUCTS_CREATE` / `PRODUCTS_UPDATE`.

## Configuration added (`app/core/config.py`)

| Variable | Default | Purpose |
|---|---|---|
| `STORAGE_PROVIDER` | `local` | `local` or `s3` |
| `LOCAL_UPLOAD_DIR` | `uploads/products` | local storage root |
| `MAX_PRODUCT_IMAGE_SIZE` | `2097152` | max upload bytes |
| `ALLOWED_PRODUCT_IMAGE_TYPES` | `image/jpeg,image/png,image/webp` | MIME allow-list |
| `PRODUCT_IMAGE_MAX_DIMENSION` | `1600` | max image side (px) |

## Errors

- `ImageValidationError(BadRequestError)` — code `INVALID_IMAGE`, HTTP 400,
  for empty/oversized/unsupported/undecodable uploads.

## Tests added

`app/tests/api/test_product_images_api.py` — covers create/replace/remove/delete
with file lifecycle assertions, invalid type, size cap, static serving, legacy
JSON `image_url`, and RBAC. Parameterised over JSON and multipart payloads.
`app/tests/conftest.py` gained an upload-dir reset fixture.

## Known follow-ups (out of scope for this phase)

- Frontend upload UI.
- `S3ImageStorageService.save_product_image()` implementation (requires
  provisioning AWS infrastructure + `boto3` dependency).
- CDN / signed-URL serving for production object storage.
- EXIF orientation stripping on upload.
