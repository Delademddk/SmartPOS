# Module 05 — Products

**SQL source:** `Database/SQL/05_Products/`
**Purpose:** Product catalogue with pricing, stock metadata and images.

## Tables

| Table | Purpose |
|-------|---------|
| `products` | `sku` + `barcode` unique; `unit_price`, `cost_price`, `low_stock_threshold`, `is_service`. Optional `image_url` (URL/path of the primary image, nullable). Soft-deletable. |
| `product_images` | Multiple images per product; exactly one `is_primary`. |

## Stored Procedures

| Procedure | Purpose |
|-----------|---------|
| `SP_GetProducts` | List products (filterable, includes stock/status). |
| `SP_GetProduct` / `SP_GetProductByBarcode` / `SP_GetProductBySKU` | Point lookups — POS scanner paths. |
| `SP_CreateProduct` | Insert product (+ optional images); validates SKU/barcode uniqueness and category/supplier refs. |
| `SP_UpdateProduct` | Update fields; blocks duplicate SKU/barcode. |
| `SP_DeleteProduct` / `SP_RestoreProduct` | Soft delete / undo. `SP_DeleteProduct` refuses when the product has sales or stock. |
| `SP_SearchProducts` | Full-text/`LIKE` search for the POS picker. |
| `SP_GetProductImages` / `SP_AddProductImage` / `SP_DeleteProductImage` | Image lifecycle; `SP_AddProductImage` manages `is_primary`. |

## Dependencies

- Module 04 (`categories`), Module 06 (`suppliers`), Module 07 (`inventory`).
- `TRG_products_audit` writes `audit_logs` (incl. `SOFT_DELETE` events).

## Notes

- `is_service = 1` products have no inventory rows and skip stock checks in sales.
- `products.image_url` is a nullable URL/path reference to the primary image
  (no binary storage). The `product_images` table remains the full image
  library and stays in sync with `products.image_url` via the create/update
  procedures.
- Price changes never retroactively change `sale_items` (snapshotted at sale time).
- The test suite verifies `sku`/`barcode` uniqueness.
