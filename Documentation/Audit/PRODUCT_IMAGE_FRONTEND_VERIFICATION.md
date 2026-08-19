# Frontend Verification Report — Product Image Support (Phase 04A)

Date: 2026-08-10

## 1. Automated checks (all green)

Run from `Frontend/` (Node 22, Windows binary via WSL):

| Check | Command | Result |
|---|---|---|
| TypeScript | `tsc -b` | **pass** (0 errors) |
| ESLint | `eslint . --report-unused-disable-directives --max-warnings 0` | **pass** (0 errors, 0 warnings) |
| Tests | `vitest run` | **52 passed** (38 baseline + 14 new) |
| Build | `tsc -b && vite build` | **pass** (`dist/` emitted) |

New tests:

- `src/tests/utils/image.test.ts` — `resolveImageUrl` (null/absolute/data/blob/
  relative-path resolution) and `validateProductImage` (allowed types, invalid
  type, unknown type, size cap, boundary size).
- `src/tests/components/ProductImage.test.tsx` — image renders with resolved
  URL + alt text, absolute URL passthrough, placeholder when `image_url` is
  null/undefined.

## 2. Requirement coverage

| Requirement | Where | Verified |
|---|---|---|
| Upload image on create | `ProductModal` — multipart `image` field | FormData built in `mutationFn`; tsc/build/test green |
| Preview before submit | `ProductModal` — `URL.createObjectURL` preview + `ProductImage` | component test covers image/placeholder rendering |
| View current image when editing | `ProductModal` — preview initialised from `product.image_url` | code path reviewed |
| Replace existing image | `PUT` multipart `image` replaces (backend cleans old file) | FormData path |
| Remove existing image | `PUT` multipart `remove_image=true` | FormData path; UI shows "Remove Image" button |
| Preserve image on unrelated edits | plain JSON diff, no `image_url` key | backend test `test_update_preserves_image_when_not_changed` |
| Product list images + placeholder | `ProductsPage` table `ProductImage` thumbnail | component test |
| POS card images + placeholder | `POSPage` grid `ProductImage` | component test |
| Larger image on detail | edit `ProductModal` preview (20x20 box); no separate detail page exists | documented |
| No hardcoded origin | `resolveImageUrl` derives origin from `VITE_API_URL`; absolute URLs (S3/CDN) pass through | util test |
| Validation UI (type/size) | `validateProductImage` + inline error messages | util test |
| Accessibility | labelled file input (`label htmlFor` + `sr-only` input + `peer-focus` ring), alt text on every image | code review |
| Responsive | no layout change; thumbnails use existing Tailwind grid/table classes | build/test |
| Query invalidation | create/update invalidates `["products"]` and `["pos-products"]` | code review |

## 3. Backend compatibility

- Multipart body shape matches Phase 03A: `data` (JSON string) + `image` file +
  optional `remove_image` flag.
- Create/update payloads now map to the real backend schema
  (`low_stock_threshold`, no `product_code`/`tax_rate_id`) — previously these
  would have been rejected with 422 (`extra="forbid"`).
- `image_url` is treated as an opaque URL/path: relative paths get the API
  origin prefix; S3/CDN absolute URLs work unchanged.

## 4. Manual steps to re-run locally

1. Start backend (SQL Server seeded, `.env` configured):
   ```bat
   cd Backend
   .venv\Scripts\activate.bat
   uvicorn app.main:app --reload --port 8000
   ```
2. Start frontend:
   ```bat
   cd Frontend
   npm install
   npm run dev
   ```
3. Open `http://localhost:5173`, log in as an administrator, go to **Products**:
   - Add a product without an image → placeholder icon shows in table.
   - Add a product with a JPEG/PNG/WebP (< 2 MB) image → preview before
     submit, thumbnail after save.
   - Edit the product → current image shows; replace it; save → new image.
   - Edit again → "Remove Image"; save → placeholder shows.
   - Edit a product's price/name without touching the image → image preserved.
   - Open **POS** → cards show product images (or placeholder).
   - Try a `.txt`/>2 MB file → inline error, nothing submitted.
