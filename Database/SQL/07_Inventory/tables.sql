/* ==========================================================================
   SmartPOS Database - MODULE 07: INVENTORY
   --------------------------------------------------------------------------
   Objects: inventory, inventory_transactions (stock_movements), stock_adjustments,
            low_stock_alerts.
   Depends on: 05 Products, 02 Users.

   Business rules:
     - Inventory decreases after sales (handled by SP_CreateSale / triggers).
     - Inventory increases after restocking (SP_RestockProduct).
     - Returns restore inventory (SP_ProcessReturn).
     - Every movement is logged in inventory_transactions. Never deleted.
   ========================================================================== */

-- --------------------------------------------------------------------------
-- INVENTORY (current snapshot per product)
-- --------------------------------------------------------------------------
IF OBJECT_ID(N'dbo.inventory', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.inventory
    (
        inventory_id        INT   NOT NULL IDENTITY(1,1) CONSTRAINT PK_inventory PRIMARY KEY,
        product_id          INT   NOT NULL,
        quantity_on_hand    INT   NOT NULL CONSTRAINT DF_inventory_quantity_on_hand DEFAULT (0),
        quantity_reserved   INT   NOT NULL CONSTRAINT DF_inventory_quantity_reserved DEFAULT (0),
        reorder_level       INT   NULL,
        last_restocked_at   DATETIME2(0) NULL,
        last_sold_at        DATETIME2(0) NULL,
        updated_at          DATETIME2(0) NOT NULL CONSTRAINT DF_inventory_updated_at DEFAULT (SYSUTCDATETIME())
    );

    ALTER TABLE dbo.inventory ADD CONSTRAINT UQ_inventory_product_id UNIQUE (product_id);
    ALTER TABLE dbo.inventory ADD CONSTRAINT FK_inventory_products
        FOREIGN KEY (product_id) REFERENCES dbo.products (product_id);
    ALTER TABLE dbo.inventory ADD CONSTRAINT CK_inventory_quantity_non_negative
        CHECK (quantity_on_hand >= 0);
    ALTER TABLE dbo.inventory ADD CONSTRAINT CK_inventory_reserved_non_negative
        CHECK (quantity_reserved >= 0);
END
GO

-- --------------------------------------------------------------------------
-- INVENTORY TRANSACTIONS (stock movements - audit trail)
-- --------------------------------------------------------------------------
IF OBJECT_ID(N'dbo.inventory_transactions', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.inventory_transactions
    (
        transaction_id    INT           NOT NULL IDENTITY(1,1) CONSTRAINT PK_inventory_transactions PRIMARY KEY,
        product_id        INT           NOT NULL,
        movement_type     NVARCHAR(30)  NOT NULL,   -- SALE / RESTOCK / RETURN / ADJUSTMENT / VOID / TRANSFER
        quantity          INT           NOT NULL,   -- signed: negative out, positive in
        quantity_before   INT           NOT NULL,
        quantity_after    INT           NOT NULL,
        unit_cost         DECIMAL(19,4) NULL,
        reference_type    NVARCHAR(50)  NULL,       -- 'Sale', 'Return', 'PurchaseOrder' ...
        reference_id      NVARCHAR(100) NULL,       -- related record id
        [reason]          NVARCHAR(255) NULL,
        user_id           INT           NULL,       -- actor
        created_at        DATETIME2(0)  NOT NULL CONSTRAINT DF_inventory_transactions_created_at DEFAULT (SYSUTCDATETIME())
    );

    ALTER TABLE dbo.inventory_transactions ADD CONSTRAINT FK_inventory_transactions_products
        FOREIGN KEY (product_id) REFERENCES dbo.products (product_id);
    ALTER TABLE dbo.inventory_transactions ADD CONSTRAINT FK_inventory_transactions_users
        FOREIGN KEY (user_id) REFERENCES dbo.users (user_id);
    ALTER TABLE dbo.inventory_transactions ADD CONSTRAINT CK_inventory_transactions_movement_type_upper
        CHECK (movement_type = UPPER(LTRIM(RTRIM(movement_type))));
END
GO

-- --------------------------------------------------------------------------
-- STOCK ADJUSTMENTS (counted/physical adjustments)
-- --------------------------------------------------------------------------
IF OBJECT_ID(N'dbo.stock_reconciliations', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.stock_reconciliations
    (
        reconciliation_id INT            NOT NULL IDENTITY(1,1) CONSTRAINT PK_stock_reconciliations PRIMARY KEY,
        product_id        INT            NOT NULL,
        system_quantity   INT            NOT NULL,
        counted_quantity  INT            NOT NULL,
        difference        INT            NOT NULL,
        adjustment_type   NVARCHAR(30)   NOT NULL, -- COUNT / DAMAGE / THEFT / EXPIRY / CORRECTION
        [reason]          NVARCHAR(255)  NULL,
        user_id           INT            NULL,
        transaction_id    INT            NULL,       -- links the resulting inventory movement
        reconciled_at     DATETIME2(0)   NOT NULL CONSTRAINT DF_stock_reconciliations_reconciled_at DEFAULT (SYSUTCDATETIME())
    );

    ALTER TABLE dbo.stock_reconciliations ADD CONSTRAINT FK_stock_reconciliations_products
        FOREIGN KEY (product_id) REFERENCES dbo.products (product_id);
    ALTER TABLE dbo.stock_reconciliations ADD CONSTRAINT FK_stock_reconciliations_users
        FOREIGN KEY (user_id) REFERENCES dbo.users (user_id);
    ALTER TABLE dbo.stock_reconciliations ADD CONSTRAINT FK_stock_reconciliations_txn
        FOREIGN KEY (transaction_id) REFERENCES dbo.inventory_transactions (transaction_id);
END
GO

-- --------------------------------------------------------------------------
-- LOW STOCK ALERTS
-- --------------------------------------------------------------------------
IF OBJECT_ID(N'dbo.low_stock_alerts', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.low_stock_alerts
    (
        alert_id        INT           NOT NULL IDENTITY(1,1) CONSTRAINT PK_low_stock_alerts PRIMARY KEY,
        product_id      INT           NOT NULL,
        quantity_on_hand INT          NOT NULL,
        low_stock_threshold INT       NOT NULL,
        status          NVARCHAR(20)  NOT NULL CONSTRAINT DF_low_stock_alerts_status DEFAULT (N'OPEN'),
        raised_at       DATETIME2(0)  NOT NULL CONSTRAINT DF_low_stock_alerts_raised_at DEFAULT (SYSUTCDATETIME()),
        resolved_at     DATETIME2(0)  NULL
    );

    ALTER TABLE dbo.low_stock_alerts ADD CONSTRAINT FK_low_stock_alerts_products
        FOREIGN KEY (product_id) REFERENCES dbo.products (product_id);
    ALTER TABLE dbo.low_stock_alerts ADD CONSTRAINT CK_low_stock_alerts_status
        CHECK (status IN (N'OPEN', N'RESOLVED', N'DISMISSED'));
END
GO

-- ----------------------------------------------------------------------------
-- INDEXES
-- ----------------------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_inventory_transactions_product_created')
    CREATE NONCLUSTERED INDEX IX_inventory_transactions_product_created
        ON dbo.inventory_transactions (product_id, created_at) INCLUDE (movement_type, quantity);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_inventory_transactions_type_created')
    CREATE NONCLUSTERED INDEX IX_inventory_transactions_type_created
        ON dbo.inventory_transactions (movement_type, created_at);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_low_stock_alerts_status')
    CREATE NONCLUSTERED INDEX IX_low_stock_alerts_status ON dbo.low_stock_alerts (status) INCLUDE (product_id, quantity_on_hand);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_stock_reconciliations_product')
    CREATE NONCLUSTERED INDEX IX_stock_reconciliations_product ON dbo.stock_reconciliations (product_id);
GO