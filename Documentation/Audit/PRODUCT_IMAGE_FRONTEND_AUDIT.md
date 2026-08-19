# Frontend Audit — Product Image Support (Phase 04A)

Date: 2026-08-10
Scope: SmartPOS `Frontend/` only. Backend (Phase 03A) is complete and is the
source of truth for the API contract.

## 1. Current state before changes

The frontend has full product CRUD but **no product-image support**:

- The `Product` type (`src/types/models.ts`) has no `image_url` field.
- The create/edit product form (`src/pages/products/ProductsPage.tsx`,
  `ProductModal`) has no file input, preview, replace or remove capability.
- The product table renders a text-only "Product" cell — no thumbnail, no
  placeholder.
- The POS product grid (`src/pages/pos/POSPage.tsx`) renders a small box with
  the category initials — no image, no placeholder.
- There is no dedicated product-detail page; the edit `ProductModal` is the
  closest detail surface.

## 2. Backend API contract (source of truth — Phase 03A)

Inspected `Backend/app/api/routers/products.py`,
`Backend/app/api/schemas/products.py`, `Backend/app/services/products_service.py`
and `Backend/app/tests/api/test_product_images_api.py`.

| Endpoint | Content-Type | Body | Returns |
|---|---|---|---|
| `POST /api/v1/products` | JSON | `ProductCreate` (may set `image_url` string) | `201`, `ProductRead` |
| `POST /api/v1/products` | `multipart/form-data` | `data` field = JSON payload, optional `image` file | `201`, `ProductRead` |
| `PUT /api/v1/products/{id}` | JSON | `ProductUpdate` (`image_url: null` removes image) | `200`, `ProductRead` |
| `PUT /api/v1/products/{id}` | `multipart/form-data` | `data` = JSON, optional `image` file, optional `remove_image=true` | `200`, `ProductRead` |

Key facts:

- `image_url` is `string | null` in `ProductRead`.
- `image_url` returned by the local provider is a **relative path**
  (`/uploads/products/<uuid>.<ext>`) served by FastAPI at
  `http://localhost:8000/uploads/products/...` (origin, not `/api/v1`).
  A future S3/CDN deployment returns an **absolute HTTPS URL**. The frontend
  must therefore treat `image_url` as an opaque URL/path.
- Multipart parsing requires a `data` field containing the JSON payload string;
  the file is uploaded as `image`; remove is a `remove_image` flag.
- Supplying both `image` and `remove_image` is rejected with 400.
- `ProductCreate`/`ProductUpdate` schemas use `extra="forbid"` (see
  `Backend/app/api/schemas/common.py`). Backend fields are: `sku`, `barcode`,
  `product_name`, `description`, `category_id`, `supplier_id`, `unit`,
  `unit_price`, `cost_price`, `image_url`, `low_stock_threshold`, `is_service`,
  `initial_quantity` (create only), `is_active` (update only).
- Backend limits: max 2 MB, MIME allow-list `image/jpeg,image/png,image/webp`,
  resized to max 1600 px longest side. Errors are HTTP 400 `INVALID_IMAGE`.

## 3. Frontend infrastructure (existing, reused unchanged)

- Axios client `src/api/client.ts` — baseURL from `VITE_API_URL`
  (`http://localhost:8000/api/v1`), JWT auth header + refresh interceptors.
  **The instance default `Content-Type: application/json` makes it mandatory to
  pass `Content-Type: multipart/form-data` for `FormData` bodies** — otherwise
  axios 1.x `transformRequest` serialises `FormData` to JSON and the upload
  silently becomes a JSON request.
- API helpers `apiGet/apiPost/apiPut/apiDelete` accept an optional
  `AxiosRequestConfig`, so a per-call header override is supported without
  touching the client.
- TanStack Query is used inline in the page components (there is **no dedicated
  products service file** — `src/services/` contains only `auth.service.ts`, so
  no service to update or duplicate; the inline pattern is preserved).
- React Hook Form + Zod (`zodResolver`) drive the `ProductModal` form.
- UI kit: Tailwind utility classes defined in `src/styles/globals.css`
  (`.label`, `.input`, `.input-error`, `.btn-*`, `.badge-*`, `.table`, `.card`),
  Lucide icons, `cn()` merge helper.
- Existing query key conventions: `["products", ...]` for the admin list,
  `["pos-products", ...]` for the POS grid. Both are invalidated after
  mutations via `queryClient.invalidateQueries({ queryKey: ["products"] })`
  (prefix matching) — POS additionally has its own invalidation on sale.

## 4. Findings / discrepancies

1. **Form payload mismatch (pre-existing).** The current `ProductModal` submits
   `product_code`, `tax_rate_id` and `reorder_level`, which do not exist in the
   backend `ProductCreate`/`ProductUpdate` schemas; the schemas forbid extra
   fields. The real backend maps this to `low_stock_threshold` and has no
   product-level `tax_rate_id`/`product_code`. Create/edit would fail with 422.
   Fix: map the form to the real backend schema (`reorder_level →
   low_stock_threshold`, drop `product_code`/`tax_rate_id`). This is required
   for the image feature's create/edit flows to work at all.
2. **tsconfig build blocker (pre-existing).** `tsconfig.json` had
   `"ignoreDeprecations": "6.0"`, which is not a valid value for the installed
   TypeScript (5.9.3) — `tsc -b` errored out, blocking the build script. Fixed
   to `"5.0"` to enable type-checking/verification.
3. **No product detail route/page exists.** The edit modal doubles as the
   product detail display; it now shows the current image (Step 9 satisfied
   there).

## 5. Design decisions for this phase

- `image_url` is resolved by a single helper `resolveImageUrl()` in
  `src/utils/image.ts`: absolute URLs (https/S3/CDN, `data:`, `blob:`) are used
  as-is; relative paths are prefixed with the API origin derived from
  `VITE_API_URL`. No host is hardcoded — fully S3-compatible with no frontend
  changes later.
- A single reusable `ProductImage` component
  (`src/components/ui/ProductImage.tsx`) renders the image or a clean neutral
  placeholder (Lucide `Package` on `bg-gray-100`), consistent with the
  existing visual style. Used in the table, the POS grid and the form preview.
- Client-side validation mirrors the backend limits (JPEG/PNG/WebP, 2 MB).
  Backend validation remains authoritative.
- Multipart submission is used only when a file is selected or an image is
  being removed; otherwise the plain JSON path is preserved.
