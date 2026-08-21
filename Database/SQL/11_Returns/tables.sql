/* ==========================================================================
   SmartPOS Database - MODULE 11: RETURNS
   --------------------------------------------------------------------------
   Objects: return_reasons, returns, return_items.
   Depends on: 02 Users, 05 Products, 08 Sales (sales, sale_items).

   Business rule: returns restore inventory and are logged in
   inventory_transactions (see SP_ProcessReturn).
   ========================================================================== */

-- --------------------------------------------------------------------------
-- RETURN REASONS
-- --------------------------------------------------------------------------
IF OBJECT_ID(N'dbo.return_reasons', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.return_reasons
    (
        return_reason_id INT           NOT NULL IDENTITY(1,1) CONSTRAINT PK_return_reasons PRIMARY KEY,
        reason_code      NVARCHAR(30)  NOT NULL,
        reason_name      NVARCHAR(100) NOT NULL,
        is_active        BIT           NOT NULL CONSTRAINT DF_return_reasons_is_active DEFAULT (1),
        created_at       DATETIME2(0)  NOT NULL CONSTRAINT DF_return_reasons_created_at DEFAULT (SYSUTCDATETIME())
    );

    ALTER TABLE dbo.return_reasons ADD CONSTRAINT UQ_return_reasons_code UNIQUE (reason_code);
END
GO

-- --------------------------------------------------------------------------
-- RETURNS (header)
-- --------------------------------------------------------------------------
IF OBJECT_ID(N'dbo.returns', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.returns
    (
        return_id        INT            NOT NULL IDENTITY(1,1) CONSTRAINT PK_returns PRIMARY KEY,
        return_number    NVARCHAR(50)   NOT NULL,
        sale_id          INT            NOT NULL,
        customer_id      INT            NULL,
        user_id          INT            NOT NULL,               -- processed by
        return_reason_id INT            NULL,
        [status]         NVARCHAR(20)   NOT NULL CONSTRAINT DF_returns_status DEFAULT (N'COMPLETED'), -- PENDING / COMPLETED / REJECTED
        total_refund_amount DECIMAL(19,4) NOT NULL CONSTRAINT DF_returns_total_refund_amount DEFAULT (0),
        [notes]          NVARCHAR(MAX)  NULL,
        created_at       DATETIME2(0)   NOT NULL CONSTRAINT DF_returns_created_at DEFAULT (SYSUTCDATETIME()),
        updated_at       DATETIME2(0)   NOT NULL CONSTRAINT DF_returns_updated_at DEFAULT (SYSUTCDATETIME())
    );

    ALTER TABLE dbo.returns ADD CONSTRAINT UQ_returns_return_number UNIQUE (return_number);
    ALTER TABLE dbo.returns ADD CONSTRAINT FK_returns_sales
        FOREIGN KEY (sale_id) REFERENCES dbo.sales (sale_id);
    ALTER TABLE dbo.returns ADD CONSTRAINT FK_returns_customers
        FOREIGN KEY (customer_id) REFERENCES dbo.customers (customer_id);
    ALTER TABLE dbo.returns ADD CONSTRAINT FK_returns_users
        FOREIGN KEY (user_id) REFERENCES dbo.users (user_id);
    ALTER TABLE dbo.returns ADD CONSTRAINT FK_returns_reasons
        FOREIGN KEY (return_reason_id) REFERENCES dbo.return_reasons (return_reason_id);
    ALTER TABLE dbo.returns ADD CONSTRAINT CK_returns_status
        CHECK ([status] IN (N'PENDING', N'COMPLETED', N'REJECTED'));
    ALTER TABLE dbo.returns ADD CONSTRAINT CK_returns_refund_non_negative
        CHECK (total_refund_amount >= 0);
END
GO

-- --------------------------------------------------------------------------
-- RETURN ITEMS (lines)
-- --------------------------------------------------------------------------
IF OBJECT_ID(N'dbo.return_items', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.return_items
    (
        return_item_id  INT           NOT NULL IDENTITY(1,1) CONSTRAINT PK_return_items PRIMARY KEY,
        return_id      INT           NOT NULL,
        sale_item_id   INT           NOT NULL,
        product_id     INT           NOT NULL,                  -- denormalized for reporting
        quantity       DECIMAL(12,3) NOT NULL,
        unit_price     DECIMAL(19,4) NOT NULL,
        refund_amount  DECIMAL(19,4) NOT NULL,
        created_at     DATETIME2(0)  NOT NULL CONSTRAINT DF_return_items_created_at DEFAULT (SYSUTCDATETIME())
    );

    ALTER TABLE dbo.return_items ADD CONSTRAINT FK_return_items_returns
        FOREIGN KEY (return_id) REFERENCES dbo.returns (return_id);
    ALTER TABLE dbo.return_items ADD CONSTRAINT FK_return_items_sale_items
        FOREIGN KEY (sale_item_id) REFERENCES dbo.sale_items (sale_item_id);
    ALTER TABLE dbo.return_items ADD CONSTRAINT FK_return_items_products
        FOREIGN KEY (product_id) REFERENCES dbo.products (product_id);
    ALTER TABLE dbo.return_items ADD CONSTRAINT CK_return_items_qty_positive CHECK (quantity > 0);
    ALTER TABLE dbo.return_items ADD CONSTRAINT CK_return_items_refund_non_negative
        CHECK (refund_amount >= 0);
END
GO

-- ----------------------------------------------------------------------------
-- INDEXES
-- ----------------------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_returns_sale_id')
    CREATE NONCLUSTERED INDEX IX_returns_sale_id ON dbo.returns (sale_id);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_returns_created_at')
    CREATE NONCLUSTERED INDEX IX_returns_created_at ON dbo.returns (created_at);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_return_items_return_id')
    CREATE NONCLUSTERED INDEX IX_return_items_return_id ON dbo.return_items (return_id);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_return_items_sale_item_id')
    CREATE NONCLUSTERED INDEX IX_return_items_sale_item_id ON dbo.return_items (sale_item_id);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_return_items_product_id')
    CREATE NONCLUSTERED INDEX IX_return_items_product_id ON dbo.return_items (product_id);
GO