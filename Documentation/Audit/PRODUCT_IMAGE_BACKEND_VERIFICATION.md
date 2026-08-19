# Backend Verification Report — Product Image Support (Phase 03A)

Date: 2026-08-10

## 1. Test suite (pytest, SQLite)

Full backend suite result: **65 passed** (previous baseline 27). The
product-image tests in `app/tests/api/test_product_images_api.py` are
parameterised over JSON/multipart payloads and cover:

- Create with multipart `image` → 201, `image_url` set, file saved.
- Create with JSON + `image_url` → stored verbatim (legacy path).
- Create with invalid content type → 400 `INVALID_IMAGE`.
- Create with size limit exceeded → 400 `INVALID_IMAGE`.
- Replace image on update → 200, new URL, old file cleaned up.
- `remove_image=true` → `image_url=None`, file cleaned up.
- Both `image` and `remove_image` supplied → 400.
- JSON update with `image_url` → stored verbatim (legacy path).
- Delete product → image file cleaned up.
- Static serving: `GET /uploads/products/<name>` → 200 image/*.
- Authorization: user without `PRODUCTS_CREATE` → 403.

The `conftest.py` fixture resets the upload directory before each test, so file
lifecycle assertions (created → cleaned up) are deterministic.

## 2. Live end-to-end check (real uvicorn + HTTP)

A script booted uvicorn against a seeded SQLite DB and exercised the running
API over HTTP (login → multipart upload → static GET → resize → replace →
remove → RBAC). All checks passed:

```
[seed] database ready
[server] up
[auth] login ok
[create] image_url=/uploads/products/<uuid>.png
[static] GET /uploads/products/<uuid>.png -> 200 content-type=image/png
[resize] served image dimensions=(1600, 1600)      # 4000x4000 source resized
[replace] old=<uuid1>.png new=<uuid2>.webp         # old file removed
[remove] image removed + file cleaned
[security] cashier create status=403
ALL_E2E_CHECKS_PASSED
```

## 3. How to re-run

From `Backend/`:

```bat
.venv\Scripts\activate.bat
pytest -q
```

## 4. Storage behaviour verified

- File saved under `LOCAL_UPLOAD_DIR` with a UUID filename + validated
  extension (no path traversal possible — name is generated server-side).
- Old file removed on replace; file removed on `remove_image` and on product
  delete.
- Image re-encoded and resized to max 1600px on the longest side preserving
  aspect ratio.
- Static mount serves `/uploads/products/...` with correct `Content-Type`.
- Size and MIME limits reject oversized / wrong-type uploads with HTTP 400.
