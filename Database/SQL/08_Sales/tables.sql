/* ==========================================================================
   SmartPOS Database - MODULE 08: SALES
   --------------------------------------------------------------------------
   Objects: sales, sale_items.
   Depends on: 02 Users, 03 Business (tax_rates), 05 Products, 09 Payments
               (payment_methods), 10 CreditSales (customers).

   Sales can be cash, card, or credit. Discount and tax applied at header and
   line level. Every sale decrements inventory (see SP_CreateSale).
   ========================================================================== */

-- --------------------------------------------------------------------------
-- SALES (header)
-- --------------------------------------------------------------------------
IF OBJECT_ID(N'dbo.sales', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.sales
    (
        sale_id          INT            NOT NULL IDENTITY(1,1) CONSTRAINT PK_sales PRIMARY KEY,
        receipt_number   NVARCHAR(50)   NOT NULL,
        sale_date        DATETIME2(0)   NOT NULL CONSTRAINT DF_sales_sale_date DEFAULT (SYSUTCDATETIME()),
        user_id          INT            NOT NULL,                -- cashier
        customer_id      INT            NULL,                    -- credit/customer sales
        tax_rate_id      INT            NULL,
        sale_type        NVARCHAR(20)   NOT NULL CONSTRAINT DF_sales_sale_type DEFAULT (N'CASH'), -- CASH / CREDIT / CREDIT_PARTIAL
        subtotal         DECIMAL(19,4)  NOT NULL CONSTRAINT DF_sales_subtotal DEFAULT (0),
        discount_amount  DECIMAL(19,4)  NOT NULL CONSTRAINT DF_sales_discount DEFAULT (0),
        tax_amount       DECIMAL(19,4)  NOT NULL CONSTRAINT DF_sales_tax_amount DEFAULT (0),
        total_amount     DECIMAL(19,4)  NOT NULL CONSTRAINT DF_sales_total DEFAULT (0),
        amount_received  DECIMAL(19,4)  NOT NULL CONSTRAINT DF_sales_amount_received DEFAULT (0),
        [status]         NVARCHAR(20)   NOT NULL CONSTRAINT DF_sales_status DEFAULT (N'COMPLETED'), -- COMPLETED / VOIDED / REFUNDED
        [notes]          NVARCHAR(MAX)  NULL,
        created_at       DATETIME2(0)   NOT NULL CONSTRAINT DF_sales_created_at DEFAULT (SYSUTCDATETIME()),
        updated_at       DATETIME2(0)   NOT NULL CONSTRAINT DF_sales_updated_at DEFAULT (SYSUTCDATETIME())
    );

    ALTER TABLE dbo.sales ADD CONSTRAINT UQ_sales_receipt_number UNIQUE (receipt_number);
    ALTER TABLE dbo.sales ADD CONSTRAINT FK_sales_users
        FOREIGN KEY (user_id) REFERENCES dbo.users (user_id);
    ALTER TABLE dbo.sales ADD CONSTRAINT FK_sales_tax_rates
        FOREIGN KEY (tax_rate_id) REFERENCES dbo.tax_rates (tax_rate_id);
    ALTER TABLE dbo.sales ADD CONSTRAINT CK_sales_status
        CHECK ([status] IN (N'COMPLETED', N'VOIDED', N'REFUNDED'));
    ALTER TABLE dbo.sales ADD CONSTRAINT CK_sales_type
        CHECK (sale_type IN (N'CASH', N'CREDIT', N'CREDIT_PARTIAL'));
    ALTER TABLE dbo.sales ADD CONSTRAINT CK_sales_total_non_negative CHECK (total_amount >= 0);
    ALTER TABLE dbo.sales ADD CONSTRAINT CK_sales_discount_non_negative CHECK (discount_amount >= 0);
END
GO

-- --------------------------------------------------------------------------
-- SALE ITEMS (lines)
-- --------------------------------------------------------------------------
IF OBJECT_ID(N'dbo.sale_items', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.sale_items
    (
        sale_item_id  INT            NOT NULL IDENTITY(1,1) CONSTRAINT PK_sale_items PRIMARY KEY,
        sale_id       INT            NOT NULL,
        product_id    INT            NOT NULL,
        quantity      DECIMAL(12,3)  NOT NULL,
        unit_price    DECIMAL(19,4)  NOT NULL,
        discount_rate DECIMAL(5,4)   NOT NULL CONSTRAINT DF_sale_items_discount_rate DEFAULT (0),
        tax_amount    DECIMAL(19,4)  NOT NULL CONSTRAINT DF_sale_items_tax_amount DEFAULT (0),
        line_total    DECIMAL(19,4)  NOT NULL,          -- net line value
        is_returned   BIT            NOT NULL CONSTRAINT DF_sale_items_is_returned DEFAULT (0),
        returned_qty  DECIMAL(12,3)  NOT NULL CONSTRAINT DF_sale_items_returned_qty DEFAULT (0),
        created_at    DATETIME2(0)   NOT NULL CONSTRAINT DF_sale_items_created_at DEFAULT (SYSUTCDATETIME())
    );

    ALTER TABLE dbo.sale_items ADD CONSTRAINT FK_sale_items_sales
        FOREIGN KEY (sale_id) REFERENCES dbo.sales (sale_id);
    ALTER TABLE dbo.sale_items ADD CONSTRAINT FK_sale_items_products
        FOREIGN KEY (product_id) REFERENCES dbo.products (product_id);
    ALTER TABLE dbo.sale_items ADD CONSTRAINT CK_sale_items_qty_positive CHECK (quantity > 0);
    ALTER TABLE dbo.sale_items ADD CONSTRAINT CK_sale_items_unit_price_non_negative CHECK (unit_price >= 0);
    ALTER TABLE dbo.sale_items ADD CONSTRAINT CK_sale_items_discount_rate
        CHECK (discount_rate BETWEEN 0 AND 1);
    ALTER TABLE dbo.sale_items ADD CONSTRAINT CK_sale_items_returned_not_exceed
        CHECK (returned_qty <= quantity);
END
GO

-- ----------------------------------------------------------------------------
-- INDEXES
-- ----------------------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_sales_user_date')
    CREATE NONCLUSTERED INDEX IX_sales_user_date ON dbo.sales (user_id, sale_date);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_sales_sale_date')
    CREATE NONCLUSTERED INDEX IX_sales_sale_date ON dbo.sales (sale_date) INCLUDE (total_amount, status);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_sales_customer_id')
    CREATE NONCLUSTERED INDEX IX_sales_customer_id ON dbo.sales (customer_id);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_sale_items_sale_id')
    CREATE NONCLUSTERED INDEX IX_sale_items_sale_id ON dbo.sale_items (sale_id) INCLUDE (product_id, quantity, line_total);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_sale_items_product_id')
    CREATE NONCLUSTERED INDEX IX_sale_items_product_id ON dbo.sale_items (product_id) INCLUDE (quantity, line_total);
GO