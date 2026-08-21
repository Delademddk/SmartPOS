# Product Image Database Audit — SmartPOS Phase 02A

**Date:** 2026-08-10
**Scope:** Database-only audit of the existing `products` table, ORM model,
API schemas, stored procedures and migration tooling prior to adding optional
product-image support.
**Status:** Completed before any database or code change.

---

## 1. Summary

SmartPOS already supports product images through a normalised child table
(`product_images`), which stores image **URLs only** (never binaries). The
`products` table itself does **not** currently carry an `image_url` reference.

This phase adds a single nullable `image_url` column to the `products` table so
that a product row can directly reference its primary image, while leaving the
existing `product_images` table and every other database object untouched.

---

## 2. Current `products` Table Structure

**Source of truth:** `Database/SQL/05_Products/tables.sql`

```sql
CREATE TABLE dbo.products
(
    product_id         INT             NOT NULL IDENTITY(1,1) CONSTRAINT PK_products PRIMARY KEY,
    sku                NVARCHAR(50)    NOT NULL,
    barcode            NVARCHAR(50)    NULL,
    product_name       NVARCHAR(200)   NOT NULL,
    [description]      NVARCHAR(MAX)   NULL,
    category_id        INT             NULL,
    supplier_id        INT             NULL,
    unit               NVARCHAR(20)    NOT NULL CONSTRAINT DF_products_unit DEFAULT (N'pcs'),
    unit_price         DECIMAL(19,4)   NOT NULL,
    cost_price         DECIMAL(19,4)   NULL,
    low_stock_threshold INT            NOT NULL CONSTRAINT DF_products_low_stock_threshold DEFAULT (10),
    is_service         BIT             NOT NULL CONSTRAINT DF_products_is_service DEFAULT (0),
    is_active          BIT             NOT NULL CONSTRAINT DF_products_is_active DEFAULT (1),
    is_deleted         BIT             NOT NULL CONSTRAINT DF_products_is_deleted DEFAULT (0),
    deleted_at         DATETIME2(0)    NULL,
    deleted_by         INT             NULL,
    created_at         DATETIME2(0)    NOT NULL CONSTRAINT DF_products_created_at DEFAULT (SYSUTCDATETIME()),
    updated_at         DATETIME2(0)    NOT NULL CONSTRAINT DF_products_updated_at DEFAULT (SYSUTCDATETIME()),
    created_by         INT             NULL,
    updated_by         INT             NULL
);
```

### 2.1 Primary key

- `product_id INT IDENTITY(1,1)` — constraint `PK_products`.

### 2.2 Existing columns (19)

`product_id`, `sku`, `barcode`, `product_name`, `description`, `category_id`,
`supplier_id`, `unit`, `unit_price`, `cost_price`, `low_stock_threshold`,
`is_service`, `is_active`, `is_deleted`, `deleted_at`, `deleted_by`,
`created_at`, `updated_at`, `created_by`, `updated_by`.

### 2.3 Existing constraints

| Constraint | Type | Rule |
|---|---|---|
| `PK_products` | PRIMARY KEY | `product_id` |
| `UQ_products_sku` | UNIQUE | `sku` |
| `UQ_products_barcode` | UNIQUE | `barcode` |
| `FK_products_categories` | FOREIGN KEY | `category_id` → `categories.category_id` |
| `FK_products_suppliers` | FOREIGN KEY | `supplier_id` → `suppliers.supplier_id` |
| `FK_products_created_by` | FOREIGN KEY | `created_by` → `users.user_id` |
| `FK_products_deleted_by` | FOREIGN KEY | `deleted_by` → `users.user_id` |
| `CK_products_unit_price_non_negative` | CHECK | `unit_price >= 0` |
| `CK_products_cost_price_non_negative` | CHECK | `cost_price >= 0` |
| `CK_products_low_stock_non_negative` | CHECK | `low_stock_threshold >= 0` |
| `DF_products_unit` | DEFAULT | `'pcs'` |
| `DF_products_low_stock_threshold` | DEFAULT | `10` |
| `DF_products_is_service` | DEFAULT | `0` |
| `DF_products_is_active` | DEFAULT | `1` |
| `DF_products_is_deleted` | DEFAULT | `0` |
| `DF_products_created_at` / `DF_products_updated_at` | DEFAULT | `SYSUTCDATETIME()` |

### 2.4 Existing indexes

| Index | Columns | Include |
|---|---|---|
| `IX_products_category_id` | `category_id` | — |
| `IX_products_supplier_id` | `supplier_id` | — |
| `IX_products_name` | `product_name` | `sku`, `unit_price` |
| `IX_products_is_active_deleted` | `is_active`, `is_deleted` | `product_name`, `unit_price`, `low_stock_threshold` |

Plus supporting indexes on `product_images` (`IX_product_images_product_id`).

### 2.5 Existing triggers

- `TRG_products_audit` (defined in `Database/SQL/Triggers/All_Triggers.sql`)
  writes `audit_logs` on product changes (incl. `SOFT_DELETE` events). It is
  column-agnostic and does not enumerate product columns, so adding a column
  does **not** require trigger changes.

### 2.6 Related table: `product_images` (already image-capable)

```sql
CREATE TABLE dbo.product_images
(
    image_id     INT           NOT NULL IDENTITY(1,1) CONSTRAINT PK_product_images PRIMARY KEY,
    product_id   INT           NOT NULL,
    image_url    NVARCHAR(500) NOT NULL,
    image_alt    NVARCHAR(200) NULL,
    is_primary   BIT           NOT NULL CONSTRAINT DF_product_images_is_primary DEFAULT (0),
    sort_order   INT           NOT NULL CONSTRAINT DF_product_images_sort_order DEFAULT (0),
    created_at   DATETIME2(0)  NOT NULL CONSTRAINT DF_product_images_created_at DEFAULT (SYSUTCDATETIME())
);
```

This table stores only URL/path references — no binary storage — and is already
wired into the stored procedures and the ORM. It is **not** modified by this
phase.

---

## 3. Current Product Model / Entity (ORM)

**File:** `Backend/app/models/catalog.py`

The `Product` model (SQLAlchemy 2.0, `Mapped`/`mapped_column`) maps to
`products` with:

- `product_id` (PK, autoincrement)
- `sku` (unique), `barcode` (unique, nullable)
- `product_name`, `description`
- `category_id`, `supplier_id` (FKs, nullable)
- `unit`, `unit_price`, `cost_price`, `low_stock_threshold`
- `is_service`, `is_active` (plus soft-delete/audit fields from mixins)

There is currently **no** `image_url` attribute on `Product`.

A separate `ProductImage` model maps `product_images`.

---

## 4. Existing Create / Update Product Procedures

**File:** `Database/SQL/05_Products/SP_Products.sql`

| Procedure | Role | Image behaviour today |
|---|---|---|
| `SP_CreateProduct` | Insert product (+ optional inventory row) | Accepts `@PrimaryImageURL`, writes a `product_images` row |
| `SP_UpdateProduct` | Update product fields | Accepts `@PrimaryImageURL`, updates/creates the primary `product_images` row |
| `SP_GetProduct` | Single product read | Returns `primary_image_url` from `product_images` |
| `SP_GetProducts` | Paginated list | Does not return images |
| `SP_GetProductByBarcode` / `SP_GetProductBySKU` | POS lookups | Do not return images |
| `SP_SearchProducts` | POS autocomplete | Does not return images |
| `SP_GetProductImages` / `SP_AddProductImage` / `SP_DeleteProductImage` | Image lifecycle | Operate on `product_images` |

No procedure currently writes or reads a URL on the `products` row itself.

---

## 5. Existing Migration Approach

The project uses **two** complementary mechanisms:

1. **SQL Server scripted migrations** — `Database/SQL/Migrations/001_baseline.sql`
   is the numbered baseline (schema version tracked in `dbo.SchemaVersion`;
   version `001`). Per `Database/SQL/Migrations/001_baseline.sql`, future
   migrations are numbered `.sql` files (`002`, `003`, …), idempotent where
   practical, applied after the module build scripts.
2. **Alembic** — `Backend/alembic/versions/0001_baseline.py` is a no-op baseline
   that records the state created by the SQL scripts. The authoritative schema
   is `Database/SQL`; Alembic tracks subsequent deltas.

Both mechanisms must gain one new migration each for this change.

---

## 6. Does an Image Field Already Exist?

| Location | Field | Status |
|---|---|---|
| `products` table | `image_url` | **Does NOT exist** |
| `product_images` table | `image_url` | Exists (NVARCHAR(500), NOT NULL) |
| ORM `Product` model | `image_url` | **Does NOT exist** |
| ORM `ProductImage` model | `image_url` | Exists |
| API `ProductRead` schema | `image_url` | **Does NOT exist** |
| API `ProductImageRead` schema | `image_url` | Exists |

**Conclusion:** Product images are fully supported via `product_images`, but the
`products` table itself has no direct image reference. The requested field does
not exist and must be added.

---

## 7. Recommended Database Change

Add **one nullable column** to `products`, following the project's existing
naming conventions and reusing the exact type already used by
`product_images.image_url`:

```
image_url   NVARCHAR(500)   NULL
```

- Stores a URL or relative path only (e.g. `/uploads/products/abc123.webp`,
  `https://your-bucket.s3.amazonaws.com/products/abc123.webp`).
- `NULL` for existing and image-less products — fully backward compatible.
- **No** `VARBINARY`, `IMAGE`, `FILESTREAM`, or any binary storage.
- **No** index on `image_url` — it is a display/read field, not a filter key.
  Adding an index would add write overhead with no query benefit for a POS
  system (see §8).
- No data migration required — every existing row is valid with `NULL`.
- No change to the primary key, existing columns, keys, relationships,
  inventory logic, or sales logic.

### 7.1 Consistency strategy

To keep the new column consistent with the existing primary-image workflow:

- `SP_CreateProduct` writes `products.image_url` when `@PrimaryImageURL` is set.
- `SP_UpdateProduct` mirrors the updated primary URL to `products.image_url`.
- The ORM service path persists `image_url` on create/update.
- `product_images` remains the full image library; `products.image_url` is a
  convenient denormalised primary-image reference.

### 7.2 Files to be changed (planned)

| File | Change |
|---|---|
| `Database/SQL/05_Products/tables.sql` | Add `image_url NVARCHAR(500) NULL` to `products` |
| `Database/SQL/05_Products/SP_Products.sql` | Mirror primary URL into `products.image_url` in `SP_CreateProduct` / `SP_UpdateProduct` |
| `Database/SQL/Migrations/002_add_product_image_url.sql` | **New** SQL migration (add column + downgrade + `SchemaVersion` 002) |
| `Backend/alembic/versions/0002_add_product_image_url.py` | **New** Alembic migration |
| `Backend/app/models/catalog.py` | Add `image_url` to `Product` |
| `Backend/app/api/schemas/products.py` | Add `image_url` to `ProductRead`, `ProductCreate`, `ProductUpdate` |
| `Backend/app/services/products_service.py` | Persist `image_url` on create/update |
| `Database/Documentation/DataDictionary/DataDictionary.md` | Document new column |
| `Database/Documentation/Module_Guides/Module_05_Products.md` | Document new column |
| ERD diagrams (Mermaid + PlantUML) | Add `image_url` to `products` entity |

---

## 8. Index Decision

**No index will be added on `image_url`.**

Rationale:
- `image_url` is never used in `WHERE`, `JOIN`, `ORDER BY`, or `GROUP BY`.
- Product lists are filtered by name/SKU/barcode/category/supplier/stock — all
  already indexed.
- An index would add write overhead on product inserts/updates with zero read
  benefit.
- Project convention (`SQL/README.md`) only adds indexes for search/FK support.

---

## 9. Backward Compatibility

Verified by design (and re-verified after implementation in
`PRODUCT_IMAGE_DATABASE_VERIFICATION.md`):

- Products with `image_url IS NULL` can be created, retrieved, updated, sold,
  listed in reports and counted in inventory — all existing code paths ignore
  the column.
- `ProductRead.image_url` is typed `str | None` so `NULL` serialises as `null`
  without errors.
- The new column is optional in `ProductCreate` / `ProductUpdate`, so existing
  API payloads remain valid (no breaking changes).

---

## 10. Change Request Reference

- Phase: **02A — Product Image Database Audit & Migration**
- Objective: nullable `image_url` on `products`, URL-only storage, no binary,
  no S3 logic in this phase.
- Rule: smallest safe change; preserve data; do not rename/change keys,
  relationships, inventory or sales logic.
