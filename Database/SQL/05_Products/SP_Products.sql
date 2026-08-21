/* ==========================================================================
   SmartPOS Database - MODULE 05: PRODUCTS PROCEDURES
   --------------------------------------------------------------------------
   SP_GetProducts         - paginated product search incl. category, supplier, stock
   SP_GetProduct          - single product with names + primary image
   SP_CreateProduct       - create product, optional initial inventory + primary image
   SP_UpdateProduct       - update product fields / reorder level
   SP_DeleteProduct       - soft delete a product
   SP_RestoreProduct      - undo soft delete
   SP_GetProductByBarcode + SP_GetProductBySKU - POS lookups
   SP_SearchProducts      - fast light-weight search
   SP_GetProductImages     - images for a product
   SP_AddProductImage     - add an image (optional primary)
   SP_DeleteProductImage  - remove an image

   Depends on: dbo.products, dbo.product_images, dbo.inventory,
               dbo.categories, dbo.suppliers, dbo.users, dbo.error_logs.
   Conventions: SP_<Purpose>, snake_case, transactions, TRY...CATCH + THROW,
                soft deletes, pagination with TotalCount.
   ========================================================================== */

/* ---------------------------------------------------------------------------
   SP_GetProducts
   Paginated product list. Filters: free-text search on name/sku/barcode,
   category, supplier, and stock status (via dbo.FN_StockStatus). SortBy:
   name / sku / price / price_desc / created. Returns a TotalCount column.
--------------------------------------------------------------------------- */
IF OBJECT_ID(N'dbo.SP_GetProducts', N'P') IS NOT NULL DROP PROCEDURE dbo.SP_GetProducts;
GO
CREATE PROCEDURE dbo.SP_GetProducts
    @Page         INT = 1,
    @PageSize     INT = 50,
    @Search       NVARCHAR(200) = NULL,
    @CategoryID   INT = NULL,
    @SupplierID   INT = NULL,
    @StockStatus  NVARCHAR(20) = NULL,
    @SortBy       NVARCHAR(50) = N'name'
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Offset INT;
    DECLARE @Total  INT;

    IF @Page < 1 SET @Page = 1;
    IF @PageSize < 1 SET @PageSize = 50;
    IF @PageSize > 500 SET @PageSize = 500;
    SET @Offset = (@Page - 1) * @PageSize;

    -- Materialise the pre-filtered candidate set once (temp table) so the
    -- TotalCount and the paged result always use identical predicates.
    SELECT
        p.product_id,
        p.product_name,
        p.sku,
        p.barcode,
        p.unit_price,
        p.low_stock_threshold,
        p.category_id,
        c.category_name,
        p.supplier_id,
        s.supplier_name,
        ISNULL(i.quantity_on_hand, 0) AS quantity_on_hand,
        dbo.FN_StockStatus(ISNULL(i.quantity_on_hand, 0), p.low_stock_threshold) AS stock_status,
        p.created_at
    INTO #product_search
    FROM dbo.products p
    LEFT JOIN dbo.categories c ON c.category_id = p.category_id
    LEFT JOIN dbo.suppliers    s ON s.supplier_id = p.supplier_id
    LEFT JOIN dbo.inventory    i ON i.product_id   = p.product_id
    WHERE p.is_deleted = 0
      AND (@Search IS NULL OR
           p.product_name  LIKE N'%' + @Search + N'%' OR
           p.sku           LIKE N'%' + @Search + N'%' OR
           p.barcode       LIKE N'%' + @Search + N'%')
      AND (@CategoryID IS NULL OR p.category_id = @CategoryID)
      AND (@SupplierID IS NULL OR p.supplier_id = @SupplierID)
      AND (@StockStatus IS NULL OR
           dbo.FN_StockStatus(ISNULL(i.quantity_on_hand, 0), p.low_stock_threshold) = @StockStatus);

    SELECT @Total = COUNT(*) FROM #product_search;

    SELECT
        product_id,
        product_name,
        sku,
        barcode,
        unit_price,
        low_stock_threshold,
        category_id,
        category_name,
        supplier_id,
        supplier_name,
        quantity_on_hand,
        stock_status,
        @Total AS total_count
    FROM #product_search
    ORDER BY
        CASE WHEN @SortBy = N'name'       THEN product_name END,
        CASE WHEN @SortBy = N'sku'        THEN sku                          END,
        CASE WHEN @SortBy = N'price'      THEN CONVERT(DECIMAL(19,4), unit_price) END,
        CASE WHEN @SortBy = N'price_desc' THEN CONVERT(DECIMAL(19,4), unit_price) * -1 END,
        CASE WHEN @SortBy = N'created'    THEN created_at                    END DESC
    OFFSET @Offset ROWS FETCH NEXT @PageSize ROWS ONLY;
END
GO

/* ---------------------------------------------------------------------------
   SP_GetProduct
   Returns one product (active / non-deleted) plus category, supplier names,
   current stock and the primary image (when one is set).
--------------------------------------------------------------------------- */
IF OBJECT_ID(N'dbo.SP_GetProduct', N'P') IS NOT NULL DROP PROCEDURE dbo.SP_GetProduct;
GO
CREATE PROCEDURE dbo.SP_GetProduct
    @ProductID INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        p.product_id,
        p.sku,
        p.barcode,
        p.product_name,
        p.[description],
        p.category_id,
        c.category_name,
        p.supplier_id,
        s.supplier_name,
        p.unit,
        p.unit_price,
        p.cost_price,
        p.low_stock_threshold,
        p.is_service,
        p.is_active,
        p.is_deleted,
        p.deleted_at,
        p.deleted_by,
        p.created_at,
        p.updated_at,
        p.created_by,
        p.updated_by,
        ISNULL(i.quantity_on_hand, 0)                                   AS quantity_on_hand,
        ISNULL(i.quantity_reserved, 0)                                  AS quantity_reserved,
        ISNULL(i.reorder_level, p.low_stock_threshold)                  AS reorder_level,
        dbo.FN_StockStatus(ISNULL(i.quantity_on_hand, 0), p.low_stock_threshold) AS stock_status,
        img.image_url                                                   AS primary_image_url,
        img.image_alt                                                   AS primary_image_alt,
        (SELECT TOP (1) image_id FROM dbo.product_images pi WHERE pi.product_id = p.product_id ORDER BY pi.is_primary DESC, pi.sort_order, pi.image_id) AS primary_image_id
    FROM dbo.products p
    LEFT JOIN dbo.categories     c ON c.category_id = p.category_id
    LEFT JOIN dbo.suppliers      s ON s.supplier_id = p.supplier_id
    LEFT JOIN dbo.inventory      i ON i.product_id  = p.product_id
    LEFT JOIN dbo.product_images pi
        ON pi.product_id = p.product_id AND pi.is_primary = 1
    WHERE p.product_id = @ProductID
      AND p.is_deleted = 0;
END
GO

/* ---------------------------------------------------------------------------
   SP_CreateProduct
   Creates a product. Validates unique SKU (and optional barcode), non-negative
   price, and that category/supplier exist when supplied. When the product is
   a stock item (IsService = 0) an initial inventory row with 0 on-hand is
   created. An optional primary image URL creates a product_images row.
--------------------------------------------------------------------------- */
IF OBJECT_ID(N'dbo.SP_CreateProduct', N'P') IS NOT NULL DROP PROCEDURE dbo.SP_CreateProduct;
GO
CREATE PROCEDURE dbo.SP_CreateProduct
    @SKU               NVARCHAR(50),
    @Barcode           NVARCHAR(50) = NULL,
    @Name              NVARCHAR(200),
    @Description       NVARCHAR(MAX) = NULL,
    @CategoryID        INT = NULL,
    @SupplierID        INT = NULL,
    @Unit              NVARCHAR(20) = N'pcs',
    @UnitPrice         DECIMAL(19,4) = 0,
    @CostPrice         DECIMAL(19,4) = NULL,
    @LowStockThreshold INT = 10,
    @IsService         BIT = 0,
    @CreatedByID       INT = NULL,
    @PrimaryImageURL   NVARCHAR(500) = NULL,
    @ProductID         INT = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @Now DATETIME2(0) = SYSUTCDATETIME();

    BEGIN TRY
        IF NULLIF(LTRIM(RTRIM(@SKU)), N'') IS NULL
            THROW 50051, N'A SKU is required.', 1;
        IF NULLIF(LTRIM(RTRIM(@Name)), N'') IS NULL
            THROW 50052, N'A product name is required.', 1;

        IF EXISTS (SELECT 1 FROM dbo.products WHERE sku = @SKU)
            THROW 50053, N'This SKU is already in use.', 1;

        IF @Barcode IS NOT NULL AND LEN(LTRIM(RTRIM(@Barcode))) > 0
        BEGIN
            IF EXISTS (SELECT 1 FROM dbo.products WHERE barcode = @Barcode)
                THROW 50054, N'This barcode is already in use.', 1;
        END

        IF @UnitPrice IS NULL OR @UnitPrice < 0
            THROW 50055, N'Unit price cannot be negative.', 1;

        IF @CategoryID IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.categories c WHERE c.category_id = @CategoryID AND c.is_deleted = 0)
            THROW 50056, N'Category does not exist or is deleted.', 1;

        IF @SupplierID IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.suppliers s WHERE s.supplier_id = @SupplierID AND s.is_deleted = 0)
            THROW 50057, N'Supplier does not exist or is deleted.', 1;

        BEGIN TRANSACTION;

        INSERT INTO dbo.products
            (sku, barcode, product_name, [description], category_id, supplier_id,
             unit, unit_price, cost_price, image_url, low_stock_threshold, is_service,
             is_active, is_deleted, created_at, updated_at, created_by, updated_by)
        VALUES
            (@SKU, NULLIF(LTRIM(RTRIM(@Barcode)), N''), @Name, @Description, @CategoryID, @SupplierID,
             @Unit, @UnitPrice, @CostPrice, NULLIF(LTRIM(RTRIM(@PrimaryImageURL)), N''), ISNULL(@LowStockThreshold, 10), ISNULL(@IsService, 0),
             1, 0, @Now, @Now, @CreatedByID, @CreatedByID);

        SET @ProductID = SCOPE_IDENTITY();

        -- Inventory snapshot is only maintained for stock (non-service) items
        IF ISNULL(@IsService, 0) = 0
        BEGIN
            INSERT INTO dbo.inventory (product_id, quantity_on_hand, quantity_reserved, updated_at)
            VALUES (@ProductID, 0, 0, @Now);
        END

        -- Optional primary image
        IF @PrimaryImageURL IS NOT NULL AND LEN(LTRIM(RTRIM(@PrimaryImageURL))) > 0
        BEGIN
            INSERT INTO dbo.product_images (product_id, image_url, image_alt, is_primary, sort_order, created_at)
            VALUES (@ProductID, @PrimaryImageURL, NULL, 1, 0, @Now);
        END

        COMMIT TRANSACTION;

        SELECT @ProductID AS ProductID;
        RETURN @ProductID;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        INSERT INTO dbo.error_logs (user_id, error_code, message, stack_trace, source)
        VALUES (@CreatedByID, N'SP_CreateProduct', ERROR_MESSAGE(), ERROR_PROCEDURE(), N'SP_CreateProduct');
        THROW;
    END CATCH
END
GO

/* ---------------------------------------------------------------------------
   SP_UpdateProduct
   Updates product fields. Validates unique SKU/barcode excluding this row, and
   that category/supplier exist. When @ReorderLevel is supplied the existing
   inventory.reorder_level is updated. If @PrimaryImageURL is supplied it is
   applied to the current primary image (or promoted from a new row).
--------------------------------------------------------------------------- */
IF OBJECT_ID(N'dbo.SP_UpdateProduct', N'P') IS NOT NULL DROP PROCEDURE dbo.SP_UpdateProduct;
GO
CREATE PROCEDURE dbo.SP_UpdateProduct
    @ProductID         INT,
    @SKU               NVARCHAR(50),
    @Barcode           NVARCHAR(50) = NULL,
    @Name              NVARCHAR(200),
    @Description       NVARCHAR(MAX) = NULL,
    @CategoryID        INT = NULL,
    @SupplierID        INT = NULL,
    @Unit              NVARCHAR(20) = N'pcs',
    @UnitPrice         DECIMAL(19,4) = 0,
    @CostPrice         DECIMAL(19,4) = NULL,
    @LowStockThreshold INT = 10,
    @IsService         BIT = 0,
    @ReorderLevel      INT = NULL,
    @UpdatedByID       INT = NULL,
    @PrimaryImageURL   NVARCHAR(500) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @Now DATETIME2(0) = SYSUTCDATETIME();

    BEGIN TRY
        IF NOT EXISTS (SELECT 1 FROM dbo.products WHERE product_id = @ProductID AND is_deleted = 0)
            THROW 50058, N'Product does not exist or is deleted.', 1;
        IF NULLIF(LTRIM(RTRIM(@Name)), N'') IS NULL
            THROW 50052, N'A product name is required.', 1;

        IF EXISTS (SELECT 1 FROM dbo.products WHERE sku = @SKU AND product_id <> @ProductID)
            THROW 50053, N'This SKU is already in use.', 1;

        IF @Barcode IS NOT NULL AND LEN(LTRIM(RTRIM(@Barcode))) > 0
        BEGIN
            IF EXISTS (SELECT 1 FROM dbo.products WHERE barcode = @Barcode AND product_id <> @ProductID)
                THROW 50054, N'This barcode is already in use.', 1;
        END

        IF @UnitPrice IS NULL OR @UnitPrice < 0
            THROW 50055, N'Unit price cannot be negative.', 1;

        IF @CategoryID IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.categories c WHERE c.category_id = @CategoryID AND c.is_deleted = 0)
            THROW 50056, N'Category does not exist or is deleted.', 1;

        IF @SupplierID IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.suppliers s WHERE s.supplier_id = @SupplierID AND s.is_deleted = 0)
            THROW 50057, N'Supplier does not exist or is deleted.', 1;

        BEGIN TRANSACTION;

        UPDATE dbo.products
        SET sku                = @SKU,
            barcode            = NULLIF(LTRIM(RTRIM(@Barcode)), N''),
            product_name       = @Name,
            [description]      = @Description,
            category_id        = @CategoryID,
            supplier_id        = @SupplierID,
            unit               = @Unit,
            unit_price         = @UnitPrice,
            cost_price         = @CostPrice,
            low_stock_threshold = ISNULL(@LowStockThreshold, 10),
            is_service         = ISNULL(@IsService, 0),
            updated_at         = @Now,
            updated_by         = @UpdatedByID
        WHERE product_id = @ProductID;

        -- Update inventory reorder level when explicitly supplied
        IF @ReorderLevel IS NOT NULL
        BEGIN
            UPDATE i
            SET i.reorder_level = @ReorderLevel,
                i.updated_at    = @Now
            FROM dbo.inventory i
            WHERE i.product_id = @ProductID;
        END

        -- Apply optional primary image
        IF @PrimaryImageURL IS NOT NULL AND LEN(LTRIM(RTRIM(@PrimaryImageURL))) > 0
        BEGIN
            -- Mirror the primary URL onto the product row (URL reference only)
            UPDATE dbo.products
            SET image_url = NULLIF(LTRIM(RTRIM(@PrimaryImageURL)), N'')
            WHERE product_id = @ProductID;

            IF EXISTS (SELECT 1 FROM dbo.product_images WHERE product_id = @ProductID AND is_primary = 1)
            BEGIN
                UPDATE dbo.product_images
                SET image_url = @PrimaryImageURL
                WHERE product_id = @ProductID AND is_primary = 1;
            END
            ELSE
            BEGIN
                -- Demote any existing images so exactly one primary is kept
                UPDATE dbo.product_images SET is_primary = 0 WHERE product_id = @ProductID;
                INSERT INTO dbo.product_images (product_id, image_url, image_alt, is_primary, sort_order, created_at)
                VALUES (@ProductID, @PrimaryImageURL, NULL, 1, 0, @Now);
            END
        END

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        INSERT INTO dbo.error_logs (user_id, error_code, message, stack_trace, source)
        VALUES (@UpdatedByID, N'SP_UpdateProduct', ERROR_MESSAGE(), ERROR_PROCEDURE(), N'SP_UpdateProduct');
        THROW;
    END CATCH
END
GO

/* ---------------------------------------------------------------------------
   SP_DeleteProduct / SP_RestoreProduct
   Soft-delete toggle a single product.
--------------------------------------------------------------------------- */
IF OBJECT_ID(N'dbo.SP_DeleteProduct', N'P') IS NOT NULL DROP PROCEDURE dbo.SP_DeleteProduct;
GO
CREATE PROCEDURE dbo.SP_DeleteProduct
    @ProductID    INT,
    @DeletedByID  INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @Now DATETIME2(0) = SYSUTCDATETIME();

    BEGIN TRY
        IF NOT EXISTS (SELECT 1 FROM dbo.products WHERE product_id = @ProductID AND is_deleted = 0)
            THROW 50059, N'Product not found or already deleted.', 1;

        BEGIN TRANSACTION;
        UPDATE dbo.products
        SET is_deleted = 1,
            deleted_at = @Now,
            deleted_by = @DeletedByID,
            updated_at = @Now,
            updated_by = @DeletedByID
        WHERE product_id = @ProductID;
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        INSERT INTO dbo.error_logs (user_id, error_code, message, stack_trace, source)
        VALUES (@DeletedByID, N'SP_DeleteProduct', ERROR_MESSAGE(), ERROR_PROCEDURE(), N'SP_DeleteProduct');
        THROW;
    END CATCH
END
GO

IF OBJECT_ID(N'dbo.SP_RestoreProduct', N'P') IS NOT NULL DROP PROCEDURE dbo.SP_RestoreProduct;
GO
CREATE PROCEDURE dbo.SP_RestoreProduct
    @ProductID INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        IF NOT EXISTS (SELECT 1 FROM dbo.products WHERE product_id = @ProductID AND is_deleted = 1)
            THROW 50060, N'Product not found or not deleted.', 1;

        UPDATE dbo.products
        SET is_deleted = 0,
            deleted_at = NULL,
            deleted_by = NULL,
            updated_at = SYSUTCDATETIME()
        WHERE product_id = @ProductID;
    END TRY
    BEGIN CATCH
        INSERT INTO dbo.error_logs (user_id, error_code, message, source)
        VALUES (NULL, N'SP_RestoreProduct', ERROR_MESSAGE(), N'SP_RestoreProduct');
        THROW;
    END CATCH
END
GO

/* ---------------------------------------------------------------------------
   POS lookups: SP_GetProductByBarcode, SP_GetProductBySKU
   Returns the active, non-deleted product by exact identifier.
--------------------------------------------------------------------------- */
IF OBJECT_ID(N'dbo.SP_GetProductByBarcode', N'P') IS NOT NULL DROP PROCEDURE dbo.SP_GetProductByBarcode;
GO
CREATE PROCEDURE dbo.SP_GetProductByBarcode
    @Barcode NVARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        p.product_id,
        p.sku,
        p.barcode,
        p.product_name,
        p.unit_price,
        p.cost_price,
        p.low_stock_threshold,
        p.is_service,
        c.category_id,
        c.category_name,
        p.supplier_id,
        s.supplier_name,
        ISNULL(i.quantity_on_hand, 0) AS quantity_on_hand,
        dbo.FN_StockStatus(ISNULL(i.quantity_on_hand, 0), p.low_stock_threshold) AS stock_status
    FROM dbo.products p
    LEFT JOIN dbo.categories c ON c.category_id = p.category_id
    LEFT JOIN dbo.suppliers    s ON s.supplier_id = p.supplier_id
    LEFT JOIN dbo.inventory    i ON i.product_id   = p.product_id
    WHERE p.barcode = @Barcode AND p.is_active = 1 AND p.is_deleted = 0;
END
GO

IF OBJECT_ID(N'dbo.SP_GetProductBySKU', N'P') IS NOT NULL DROP PROCEDURE dbo.SP_GetProductBySKU;
GO
CREATE PROCEDURE dbo.SP_GetProductBySKU
    @SKU NVARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        p.product_id,
        p.sku,
        p.barcode,
        p.product_name,
        p.unit_price,
        p.cost_price,
        p.low_stock_threshold,
        p.is_service,
        c.category_id,
        c.category_name,
        p.supplier_id,
        s.supplier_name,
        ISNULL(i.quantity_on_hand, 0) AS quantity_on_hand,
        dbo.FN_StockStatus(ISNULL(i.quantity_on_hand, 0), p.low_stock_threshold) AS stock_status
    FROM dbo.products p
    LEFT JOIN dbo.categories c ON c.category_id = p.category_id
    LEFT JOIN dbo.suppliers    s ON s.supplier_id = p.supplier_id
    LEFT JOIN dbo.inventory    i ON i.product_id   = p.product_id
    WHERE p.sku = @SKU AND p.is_active = 1 AND p.is_deleted = 0;
END
GO

/* ---------------------------------------------------------------------------
   SP_SearchProducts
   Fast text search over name / SKU / barcode for the POS autocomplete.
   Returns only active, non-deleted products ordered by name, capped at @Limit.
--------------------------------------------------------------------------- */
IF OBJECT_ID(N'dbo.SP_SearchProducts', N'P') IS NOT NULL DROP PROCEDURE dbo.SP_SearchProducts;
GO
CREATE PROCEDURE dbo.SP_SearchProducts
    @Query NVARCHAR(200) = NULL,
    @Limit INT = 20
AS
BEGIN
    SET NOCOUNT ON;

    IF @Limit < 1 SET @Limit = 20;
    IF @Limit > 200 SET @Limit = 200;

    SELECT TOP (@Limit)
        p.product_id,
        p.product_name,
        p.sku,
        p.barcode,
        p.unit_price,
        p.low_stock_threshold,
        ISNULL(i.quantity_on_hand, 0) AS quantity_on_hand,
        dbo.FN_StockStatus(ISNULL(i.quantity_on_hand, 0), p.low_stock_threshold) AS stock_status
    FROM dbo.products p
    LEFT JOIN dbo.inventory i ON i.product_id = p.product_id
    WHERE p.is_active = 1
      AND p.is_deleted = 0
      AND (
          @Query IS NULL OR NULLIF(@Query, N'') IS NULL OR
          p.product_name LIKE @Query + N'%' OR
          p.product_name LIKE N'%' + @Query + N'%' OR
          p.sku          LIKE N'%' + @Query + N'%' OR
          p.barcode      LIKE N'%' + @Query + N'%'
      )
    ORDER BY p.product_name;
END
GO

/* ---------------------------------------------------------------------------
   Product images: SP_GetProductImages, SP_AddProductImage, SP_DeleteProductImage
--------------------------------------------------------------------------- */
IF OBJECT_ID(N'dbo.SP_GetProductImages', N'P') IS NOT NULL DROP PROCEDURE dbo.SP_GetProductImages;
GO
CREATE PROCEDURE dbo.SP_GetProductImages
    @ProductID INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        image_id,
        product_id,
        image_url,
        image_alt,
        is_primary,
        sort_order,
        created_at
    FROM dbo.product_images
    WHERE product_id = @ProductID
    ORDER BY is_primary DESC, sort_order, image_id;
END
GO

IF OBJECT_ID(N'dbo.SP_AddProductImage', N'P') IS NOT NULL DROP PROCEDURE dbo.SP_AddProductImage;
GO
CREATE PROCEDURE dbo.SP_AddProductImage
    @ProductID INT,
    @ImageURL  NVARCHAR(500),
    @Alt       NVARCHAR(200) = NULL,
    @IsPrimary BIT = 0,
    @ImageID   INT = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @Now DATETIME2(0) = SYSUTCDATETIME();

    BEGIN TRY
        IF NOT EXISTS (SELECT 1 FROM dbo.products WHERE product_id = @ProductID AND is_deleted = 0)
            THROW 50061, N'Product does not exist.', 1;
        IF NULLIF(LTRIM(RTRIM(@ImageURL)), N'') IS NULL
            THROW 50062, N'An image URL is required.', 1;

        BEGIN TRANSACTION;

        -- Exactly one primary per product
        IF ISNULL(@IsPrimary, 0) = 1
            UPDATE dbo.product_images SET is_primary = 0 WHERE product_id = @ProductID;

        INSERT INTO dbo.product_images (product_id, image_url, image_alt, is_primary, sort_order, created_at)
        VALUES (@ProductID, @ImageURL, @Alt, ISNULL(@IsPrimary, 0), 0, @Now);

        SET @ImageID = SCOPE_IDENTITY();
        COMMIT TRANSACTION;

        SELECT @ImageID AS ImageID;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        INSERT INTO dbo.error_logs (user_id, error_code, message, source)
        VALUES (NULL, N'SP_AddProductImage', ERROR_MESSAGE(), N'SP_AddProductImage');
        THROW;
    END CATCH
END
GO

IF OBJECT_ID(N'dbo.SP_DeleteProductImage', N'P') IS NOT NULL DROP PROCEDURE dbo.SP_DeleteProductImage;
GO
CREATE PROCEDURE dbo.SP_DeleteProductImage
    @ImageID INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        IF NOT EXISTS (SELECT 1 FROM dbo.product_images WHERE image_id = @ImageID)
            THROW 50063, N'Image not found.', 1;

        BEGIN TRANSACTION;
        DELETE FROM dbo.product_images WHERE image_id = @ImageID;
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        INSERT INTO dbo.error_logs (user_id, error_code, message, source)
        VALUES (NULL, N'SP_DeleteProductImage', ERROR_MESSAGE(), N'SP_DeleteProductImage');
        THROW;
    END CATCH
END
GO