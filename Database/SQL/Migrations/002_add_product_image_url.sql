/* ==========================================================================
   SmartPOS Database - MIGRATION 002: ADD PRODUCT IMAGE URL
   --------------------------------------------------------------------------
   Adds an optional image reference column to dbo.products so that a product
   row can directly reference its primary image URL/path.

     image_url   NVARCHAR(500)   NULL

   - Stores a URL or relative path ONLY (no binary data).
   - NULL for existing and image-less products; fully backward compatible.
   - No data migration required.
   - No index added (display/read field only, not used in filters).

   Idempotent (safe to re-run). Rolls the schema version to 002.
   Downgrade is provided as a commented-out block for manual approval, in
   keeping with the baseline migration convention that destructive changes
   require a manual step on production data.
   ========================================================================== */

-- ---------------------------------------------------------------------------
-- 1. Add the nullable column (idempotent guard)
-- ---------------------------------------------------------------------------
IF NOT EXISTS (
    SELECT 1 FROM sys.columns
    WHERE object_id = OBJECT_ID(N'dbo.products')
      AND name = N'image_url'
)
BEGIN
    ALTER TABLE dbo.products
        ADD image_url NVARCHAR(500) NULL;
END
GO

-- ---------------------------------------------------------------------------
-- 2. Track schema version 002
-- ---------------------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM dbo.SchemaVersion WHERE Version = N'002')
    INSERT INTO dbo.SchemaVersion (Version, Description, AppliedBy)
    VALUES (N'002', N'Add nullable image_url to dbo.products (URL/path image reference).', SUSER_SNAME());
GO

-- ---------------------------------------------------------------------------
-- DOWNGRADE (roll back to 001) - requires manual approval on production.
-- Remove the column only after confirming no code reads products.image_url.
-- ---------------------------------------------------------------------------
-- IF EXISTS (
--     SELECT 1 FROM sys.columns
--     WHERE object_id = OBJECT_ID(N'dbo.products')
--       AND name = N'image_url'
-- )
-- BEGIN
--     ALTER TABLE dbo.products DROP COLUMN image_url;
-- END
-- GO
--
-- DELETE FROM dbo.SchemaVersion WHERE Version = N'002';
-- GO
