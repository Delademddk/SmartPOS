# Change Log — Product Image Support (Phase 04A)

Date: 2026-08-10
Scope: SmartPOS `Frontend/` only.

## New features

1. **Product image on create/edit** — the `ProductModal`
   (`src/pages/products/ProductsPage.tsx`) gained an image picker:
   - preview before submit (`URL.createObjectURL`),
   - shows the current image when editing,
   - replace image (new file wins, old file cleaned up by backend),
   - remove image (`remove_image=true`) with a "Keep Current Image" escape
     hatch,
   - image is optional; unrelated edits never clear it.
2. **Multipart submission** — create/update now send `multipart/form-data`
   (`data` field = JSON payload, optional `image` file, optional
   `remove_image=true`) exactly as the Phase 03A backend expects. The
   `Content-Type: multipart/form-data` header is set per-call because the Axios
   instance default (`application/json`) would otherwise make axios 1.x
   serialise the `FormData` into JSON. Plain JSON is still used when no file or
   removal is involved.
3. **Reusable image display** — `src/components/ui/ProductImage.tsx` renders
   the image or a neutral `Package` placeholder on `bg-gray-100`, used in the
   products table, the POS grid and the form preview.
4. **S3-ready URL handling** — `resolveImageUrl()` in
   `src/utils/image.ts` treats `image_url` as opaque: absolute URLs
   (`https://…` S3/CDN, `data:`, `blob:`) pass through; relative paths are
   prefixed with the API origin derived from `VITE_API_URL`. No host is
   hardcoded.
5. **Client-side validation** — `validateProductImage()` mirrors the backend
   limits (JPEG/PNG/WebP, 2 MB) with inline, clearing error messages. The
   backend remains authoritative.

## Files changed

- `src/types/models.ts` — added `image_url: string | null` to `Product`.
- `src/pages/products/ProductsPage.tsx` — table thumbnails; `ProductModal`
  image state/handlers/UI; create/update payload mapping; multipart FormData
  submission; POS product invalidation on save.
- `src/pages/pos/POSPage.tsx` — product cards now show the image (or
  placeholder) instead of category initials.
- `Frontend/tsconfig.json` — fixed `ignoreDeprecations` (see below).

## Files created

- `src/utils/image.ts` — `resolveImageUrl`, `validateProductImage`,
  `ACCEPTED_IMAGE_TYPES`, `MAX_IMAGE_FILE_SIZE`, `ACCEPTED_IMAGE_INPUT`.
- `src/components/ui/ProductImage.tsx` — reusable image/placeholder component.
- `src/tests/utils/image.test.ts` (10 tests).
- `src/tests/components/ProductImage.test.tsx` (4 tests).

## Fixes

1. **Real-backend payload mapping (pre-existing bug, unblocked the feature).**
   The old form submitted `product_code`, `tax_rate_id` and `reorder_level`,
   which do not exist in the backend `ProductCreate`/`ProductUpdate` schemas
   (`extra="forbid"` → 422). The form now maps to the real schema:
   `reorder_level → low_stock_threshold`, and drops `product_code`/`tax_rate_id`
   from the request. The form layout/fields are unchanged.
2. **tsconfig build blocker (pre-existing).** `"ignoreDeprecations": "6.0"`
   is not a valid value for the installed TypeScript 5.9.3 and made `tsc -b`
   (and therefore `npm run build`) fail immediately. Changed to `"5.0"`.
3. **Axios FormData pitfall.** The shared client sets `Content-Type:
   application/json` by default; passing a `FormData` body without overriding
   it causes axios 1.x to JSON-serialise the form, silently turning uploads into
   JSON requests. The multipart header is now passed per-call.

## Tests added

- `image.test.ts` — URL resolution + file validation.
- `ProductImage.test.tsx` — image/placeholder rendering.

## Out of scope (unchanged)

- JSON-only create/update, price modal, archive/delete/activate flows, auth,
  RBAC, routing and all other pages.
- Backend S3 provider (Phase 03A follow-up) — no frontend change needed when it
  ships because absolute URLs pass through `resolveImageUrl`.
