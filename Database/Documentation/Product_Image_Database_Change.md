# Product Image Database Change

**Phase:** 02A — Product Image Database Audit & Migration
**Date:** 2026-08-10
**Type:** Non-destructive schema addition (additive only)

---

## Summary

Adds a single nullable column to the `products` table so a product row can
directly reference its primary image URL/path. The column stores a URL or
relative path **only** — never image binary data.

```
image_url   NVARCHAR(500)   NULL
```

| Column | Type | Nullable | Description |
|---|---|---|---|
| image_url | NVARCHAR(500) | YES | URL or relative path to the product image |

## Why

Phase 02A requires the database to support product images by storing an image
reference on the existing `products` table. Existing products must remain
valid with no data migration, and image storage must stay URL-only.

## What changes

1. **`products` table** — new nullable column `image_url NVARCHAR(500) NULL`.
   - No change to the primary key, existing columns, constraints or indexes.
   - No index on `image_url` (display field only; not used in filters).
2. **Stored procedures** — `SP_CreateProduct` and `SP_UpdateProduct` now mirror
   the primary image URL onto `products.image_url`, keeping it consistent with
   the existing `product_images` workflow.
3. **ORM** — `Product.image_url` (nullable, `Unicode(500)`).
4. **API schemas** — `image_url` added to `ProductRead` (output),
   `ProductCreate` (optional) and `ProductUpdate` (optional). No breaking
   changes to existing payloads.
5. **Migrations** — two new migrations (SQL + Alembic), both fully
   upgrade/downgrade capable.

## Impact on existing data

- **None.** The column is added as `NULL`; every existing product row is
  already valid. No backfill or data migration is required.

## Migrations

| System | File | Upgrade | Downgrade |
|---|---|---|---|
| SQL scripts | `Database/SQL/Migrations/002_add_product_image_url.sql` | Add column + record `SchemaVersion` 002 | Drop column (commented, manual approval) |
| Alembic | `Backend/alembic/versions/0002_add_product_image_url.py` | `op.add_column` | `op.drop_column` |

## Out of scope

- No binary storage (`VARBINARY`, `IMAGE`, `FILESTREAM`).
- No S3 / object-storage logic in this phase.
- No frontend changes.
- No changes to inventory, sales, returns, payments or reporting logic.
- No changes to `product_images` or any other table.

## Applying

**SQL Server (scripted path):**
```
sqlcmd -S <server> -d <database> -i Database/SQL/Migrations/002_add_product_image_url.sql
```
or re-run the normal setup flow which applies migrations after the schema.

**Alembic (backend path):**
```
cd Backend
alembic upgrade head
alembic downgrade 0001   # roll back only this migration
```

## Verification

See `Documentation/Audit/PRODUCT_IMAGE_DATABASE_VERIFICATION.md`.
