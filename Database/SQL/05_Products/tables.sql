/* ==========================================================================
   SmartPOS Database - MODULE 05: PRODUCTS
   --------------------------------------------------------------------------
   Objects: products, product_images.
   Depends on: 04 Categories (category_id), 06 Suppliers (supplier_id), 02 Users.
   ========================================================================== */

-- --------------------------------------------------------------------------
-- PRODUCTS
-- --------------------------------------------------------------------------
IF OBJECT_ID(N'dbo.products', N'U') IS NULL
BEGIN
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
        image_url          NVARCHAR(500)   NULL,
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

    ALTER TABLE dbo.products ADD CONSTRAINT UQ_products_sku UNIQUE (sku);
    ALTER TABLE dbo.products ADD CONSTRAINT UQ_products_barcode UNIQUE (barcode);
    ALTER TABLE dbo.products ADD CONSTRAINT FK_products_categories
        FOREIGN KEY (category_id) REFERENCES dbo.categories (category_id);
    ALTER TABLE dbo.products ADD CONSTRAINT FK_products_suppliers
        FOREIGN KEY (supplier_id) REFERENCES dbo.suppliers (supplier_id);
    ALTER TABLE dbo.products ADD CONSTRAINT FK_products_created_by
        FOREIGN KEY (created_by) REFERENCES dbo.users (user_id);
    ALTER TABLE dbo.products ADD CONSTRAINT FK_products_deleted_by
        FOREIGN KEY (deleted_by) REFERENCES dbo.users (user_id);
    ALTER TABLE dbo.products ADD CONSTRAINT CK_products_unit_price_non_negative CHECK (unit_price >= 0);
    ALTER TABLE dbo.products ADD CONSTRAINT CK_products_cost_price_non_negative CHECK (cost_price >= 0);
    ALTER TABLE dbo.products ADD CONSTRAINT CK_products_low_stock_non_negative CHECK (low_stock_threshold >= 0);
END
GO

-- --------------------------------------------------------------------------
-- PRODUCT IMAGES
-- --------------------------------------------------------------------------
IF OBJECT_ID(N'dbo.product_images', N'U') IS NULL
BEGIN
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

    ALTER TABLE dbo.product_images ADD CONSTRAINT FK_product_images_products
        FOREIGN KEY (product_id) REFERENCES dbo.products (product_id);
END
GO

-- ----------------------------------------------------------------------------
-- INDEXES (search optimization + FK support)
-- ----------------------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_products_category_id')
    CREATE NONCLUSTERED INDEX IX_products_category_id ON dbo.products (category_id);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_products_supplier_id')
    CREATE NONCLUSTERED INDEX IX_products_supplier_id ON dbo.products (supplier_id);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_products_name')
    CREATE NONCLUSTERED INDEX IX_products_name ON dbo.products (product_name) INCLUDE (sku, unit_price);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_products_is_active_deleted')
    CREATE NONCLUSTERED INDEX IX_products_is_active_deleted
        ON dbo.products (is_active, is_deleted) INCLUDE (product_name, unit_price, low_stock_threshold);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_product_images_product_id')
    CREATE NONCLUSTERED INDEX IX_product_images_product_id ON dbo.product_images (product_id) INCLUDE (image_url, is_primary);
GO