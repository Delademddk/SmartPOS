/* ==========================================================================
   SmartPOS Database - INVENTORY PROCEDURES
   --------------------------------------------------------------------------
     SP_RestockProduct   - increases stock, logs movement, may raise low-stock
                           notification if still below threshold
     SP_AdjustStock      - manual reconciliation with signed quantity
     SP_GetStockLevel    - current stock snapshot for a product
   ========================================================================== */

/* ---------------------------------------------------------------------------
   SP_RestockProduct
   Increases quantity_on_hand. Logs a RESTOCK movement. Raises a notification
   if the product remains at or below its low-stock threshold.
---------------------------------------------------------------------------*/
IF OBJECT_ID(N'dbo.SP_RestockProduct', N'P') IS NOT NULL DROP PROCEDURE dbo.SP_RestockProduct;
GO
CREATE PROCEDURE dbo.SP_RestockProduct
    @ProductID INT,
    @Quantity  INT,
    @UserID    INT = NULL,
    @ReferenceType NVARCHAR(50) = NULL,
    @ReferenceID   NVARCHAR(100) = NULL,
    @Reason        NVARCHAR(255) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @Now DATETIME2(0) = SYSUTCDATETIME();
    DECLARE @Before INT, @After INT, @Threshold INT, @ProductName NVARCHAR(200);

    BEGIN TRY
        IF @ProductID IS NULL OR @Quantity <= 0
            THROW 50010, N'Product and a positive quantity are required.', 1;

        IF NOT EXISTS (SELECT 1 FROM dbo.products WHERE product_id = @ProductID AND is_deleted = 0)
            THROW 50011, N'Product does not exist.', 1;

        BEGIN TRANSACTION;

        SELECT @Before = quantity_on_hand
        FROM dbo.inventory WITH (UPDLOCK, ROWLOCK)
        WHERE product_id = @ProductID;

        -- Insert inventory row if it does not exist yet
        IF @Before IS NULL
        BEGIN
            INSERT INTO dbo.inventory (product_id, quantity_on_hand, updated_at)
            VALUES (@ProductID, 0, @Now);
            SET @Before = 0;
        END

        SET @After = @Before + @Quantity;

        UPDATE dbo.inventory
        SET quantity_on_hand = @After,
            last_restocked_at = @Now,
            updated_at = @Now
        WHERE product_id = @ProductID;

        INSERT INTO dbo.inventory_transactions
            (product_id, movement_type, quantity, quantity_before, quantity_after,
             unit_cost, reference_type, reference_id, reason, user_id, created_at)
        SELECT @ProductID, N'RESTOCK', @Quantity, @Before, @After,
               p.cost_price, @ReferenceType, @ReferenceID, @Reason, @UserID, @Now
        FROM dbo.products p
        WHERE p.product_id = @ProductID;

        -- Low-stock notification if still below threshold
        SELECT @Threshold = low_stock_threshold, @ProductName = product_name
        FROM dbo.products WHERE product_id = @ProductID;

        IF @After <= ISNULL(@Threshold, 0)
        BEGIN
            INSERT INTO dbo.notifications
                (user_id, notification_type_id, title, message, severity,
                 entity_type, entity_id, is_read, created_at)
            SELECT u.user_id, nt.notification_type_id,
                   N'Low stock: ' + @ProductName,
                   N'Product ' + @ProductName + N' has only ' + CAST(@After AS NVARCHAR(20)) +
                   N' units remaining (threshold ' + CAST(ISNULL(@Threshold,0) AS NVARCHAR(20)) + N').',
                   N'WARNING', N'Product', CAST(@ProductID AS NVARCHAR(20)), 0, @Now
            FROM dbo.users u
            CROSS JOIN dbo.notification_types nt
            WHERE nt.type_code = N'LOW_STOCK'
              AND u.is_active = 1
              AND u.is_deleted = 0
              AND u.role_id IN (SELECT role_id FROM dbo.roles WHERE role_code IN (N'ADMIN', N'MANAGER'));
        END

        COMMIT TRANSACTION;

        SELECT @After AS QuantityOnHand;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        INSERT INTO dbo.error_logs (user_id, error_code, message, source)
        VALUES (@UserID, N'SP_RestockProduct', ERROR_MESSAGE(), N'SP_RestockProduct');
        THROW;
    END CATCH
END
GO

/* ---------------------------------------------------------------------------
   SP_AdjustStock
   Performs a manual signed adjustment: @Quantity positive adds stock,
   negative removes stock. Logs an ADJUSTMENT movement and a reconciliation
   record.
---------------------------------------------------------------------------*/
IF OBJECT_ID(N'dbo.SP_AdjustStock', N'P') IS NOT NULL DROP PROCEDURE dbo.SP_AdjustStock;
GO
CREATE PROCEDURE dbo.SP_AdjustStock
    @ProductID INT,
    @Quantity  INT,
    @AdjustmentType NVARCHAR(30) = N'CORRECTION',
    @UserID     INT = NULL,
    @Reason     NVARCHAR(255) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @Now DATETIME2(0) = SYSUTCDATETIME();
    DECLARE @Before INT, @After INT;

    BEGIN TRY
        IF @ProductID IS NULL OR @Quantity = 0
            THROW 50012, N'Product and a non-zero quantity are required.', 1;

        IF @AdjustmentType NOT IN (N'COUNT', N'DAMAGE', N'THEFT', N'EXPIRY', N'CORRECTION')
            THROW 50013, N'Invalid adjustment type.', 1;

        BEGIN TRANSACTION;

        SELECT @Before = quantity_on_hand
        FROM dbo.inventory WITH (UPDLOCK, ROWLOCK)
        WHERE product_id = @ProductID;

        IF @Before IS NULL
            THROW 50014, N'Product has no inventory row; restock first.', 1;

        SET @After = @Before + @Quantity;
        IF @After < 0
            THROW 50015, N'Adjustment would make stock negative.', 1;

        UPDATE dbo.inventory
        SET quantity_on_hand = @After, updated_at = @Now
        WHERE product_id = @ProductID;

        INSERT INTO dbo.inventory_transactions
            (product_id, movement_type, quantity, quantity_before, quantity_after,
             reference_type, reason, user_id, created_at)
        VALUES
            (@ProductID, N'ADJUSTMENT', @Quantity, @Before, @After,
             N'Adjustment', @Reason, @UserID, @Now);

        DECLARE @TxnID INT = SCOPE_IDENTITY();

        INSERT INTO dbo.stock_reconciliations
            (product_id, system_quantity, counted_quantity, difference,
             adjustment_type, reason, user_id, transaction_id, reconciled_at)
        VALUES
            (@ProductID, @Before, @After, @Quantity,
             @AdjustmentType, @Reason, @UserID, @TxnID, @Now);

        COMMIT TRANSACTION;

        SELECT @After AS QuantityOnHand;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        INSERT INTO dbo.error_logs (user_id, error_code, message, source)
        VALUES (@UserID, N'SP_AdjustStock', ERROR_MESSAGE(), N'SP_AdjustStock');
        THROW;
    END CATCH
END
GO

/* ---------------------------------------------------------------------------
   SP_GetStockLevel
   Returns the current stock snapshot for one product.
---------------------------------------------------------------------------*/
IF OBJECT_ID(N'dbo.SP_GetStockLevel', N'P') IS NOT NULL DROP PROCEDURE dbo.SP_GetStockLevel;
GO
CREATE PROCEDURE dbo.SP_GetStockLevel
    @ProductID INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        p.product_id,
        p.sku,
        p.product_name,
        i.quantity_on_hand,
        i.quantity_reserved,
        p.low_stock_threshold,
        dbo.FN_StockStatus(i.quantity_on_hand, p.low_stock_threshold) AS stock_status
    FROM dbo.products p
    LEFT JOIN dbo.inventory i ON i.product_id = p.product_id
    WHERE p.product_id = @ProductID AND p.is_deleted = 0;
END
GO