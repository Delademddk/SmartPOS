/* ==========================================================================
   SmartPOS Database - SP_ProcessReturn
   --------------------------------------------------------------------------
   Atomically processes a return: restores inventory for returned quantities,
   flags sale items as returned, updates refund totals, and logs RETURN stock
   movements. Prevents returning more than originally sold.

   Passed-in JSON array of lines:
     {
       "saleItemId": 1,
       "productId": 1,
       "quantity": 2
     }
   ========================================================================== */
IF OBJECT_ID(N'dbo.SP_ProcessReturn', N'P') IS NOT NULL DROP PROCEDURE dbo.SP_ProcessReturn;
GO
CREATE PROCEDURE dbo.SP_ProcessReturn
    @ReturnNumber NVARCHAR(50),
    @SaleID       INT,
    @UserID       INT,
    @ReturnReasonID INT = NULL,
    @CustomerID   INT = NULL,
    @LinesJSON    NVARCHAR(MAX),
    @Notes        NVARCHAR(MAX) = NULL,
    @ReturnID     INT = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @Now DATETIME2(0) = SYSUTCDATETIME();
    DECLARE @TotalRefund DECIMAL(19,4) = 0;
    DECLARE @Err NVARCHAR(4000);

    BEGIN TRY
        IF NULLIF(LTRIM(RTRIM(@ReturnNumber)), N'') IS NULL
            THROW 50020, N'A return number is required.', 1;
        IF ISJSON(@LinesJSON) = 0
            THROW 50021, N'Lines must be a valid JSON array.', 1;
        IF NOT EXISTS (SELECT 1 FROM dbo.sales WHERE sale_id = @SaleID)
            THROW 50022, N'Sale does not exist.', 1;
        IF NOT EXISTS (SELECT 1 FROM dbo.users WHERE user_id = @UserID)
            THROW 50023, N'Unknown user.', 1;

        BEGIN TRANSACTION;

        -- Expand lines and validate that each belongs to the sale and that the
        -- requested returned quantity does not exceed the sold & not yet returned.
        SELECT
            j.SaleItemId,
            j.ProductId,
            j.Quantity,
            si.unit_price,
            si.discount_rate,
            si.quantity - si.returned_qty AS returnable_qty,
            si.line_total AS sale_line_total
        INTO #ret_lines
        FROM OPENJSON(@LinesJSON)
        WITH (SaleItemId INT '$.saleItemId', ProductId INT '$.productId', Quantity DECIMAL(12,3) '$.quantity') AS j
        JOIN dbo.sale_items si
            ON si.sale_item_id = j.SaleItemId
           AND si.sale_id = @SaleID
           AND si.product_id = j.ProductId;

        -- Any row missing means invalid sale line reference
        SELECT TOP (1) @Err = N'Invalid sale item reference in return lines.'
        FROM OPENJSON(@LinesJSON)
        WITH (SaleItemId INT '$.saleItemId') AS j
        WHERE NOT EXISTS (SELECT 1 FROM #ret_lines rl WHERE rl.SaleItemId = j.SaleItemId);
        IF @Err IS NOT NULL THROW 50024, @Err, 1;

        -- Cannot return more than sold minus already returned
        SELECT TOP (1) @Err = N'Return quantity exceeds sale quantity for item ' + CAST(SaleItemId AS NVARCHAR(20)) + N'.'
        FROM #ret_lines WHERE Quantity > returnable_qty;
        IF @Err IS NOT NULL THROW 50025, @Err, 1;

        -- ------------------------------------------------------------------
        -- Header
        -- ------------------------------------------------------------------
        INSERT INTO dbo.returns
            (return_number, sale_id, customer_id, user_id, return_reason_id,
             status, total_refund_amount, notes, created_at, updated_at)
        VALUES
            (@ReturnNumber, @SaleID, @CustomerID, @UserID, @ReturnReasonID,
             N'COMPLETED', 0, @Notes, @Now, @Now);

        SET @ReturnID = SCOPE_IDENTITY();

        -- ------------------------------------------------------------------
        -- Items + refund totals + restore stock + movements
        -- ------------------------------------------------------------------
        DECLARE @ItemId INT, @ProductId INT, @Qty DECIMAL(12,3), @UnitPrice DECIMAL(19,4),
                @DiscRate DECIMAL(5,4), @Refund DECIMAL(19,4), @OldStock INT;
        DECLARE line_cursor CURSOR FAST_FORWARD READ_ONLY FOR
            SELECT SaleItemId, ProductId, Quantity, unit_price, discount_rate
            FROM #ret_lines;

        OPEN line_cursor;
        FETCH NEXT FROM line_cursor INTO @ItemId, @ProductId, @Qty, @UnitPrice, @DiscRate;
        WHILE @@FETCH_STATUS = 0
        BEGIN
            SET @Refund = ROUND(@UnitPrice * @Qty * (1 - ISNULL(@DiscRate, 0)), 4);

            INSERT INTO dbo.return_items
                (return_id, sale_item_id, product_id, quantity, unit_price, refund_amount, created_at)
            VALUES
                (@ReturnID, @ItemId, @ProductId, @Qty, @UnitPrice, @Refund, @Now);

            -- Update the sale item returned state
            UPDATE dbo.sale_items
            SET returned_qty = returned_qty + @Qty,
                is_returned  = CASE WHEN returned_qty + @Qty >= quantity THEN 1 ELSE is_returned END
            WHERE sale_item_id = @ItemId;

            -- Restore stock
            UPDATE inv
            SET inv.quantity_on_hand = inv.quantity_on_hand + @Qty,
                inv.updated_at = @Now
            FROM dbo.inventory inv
            WHERE inv.product_id = @ProductId;

            SELECT @OldStock = quantity_on_hand - @Qty
            FROM dbo.inventory WHERE product_id = @ProductId;

            INSERT INTO dbo.inventory_transactions
                (product_id, movement_type, quantity, quantity_before, quantity_after,
                 reference_type, reference_id, reason, user_id, created_at)
            VALUES
                (@ProductId, N'RETURN', @Qty, @OldStock, @OldStock + @Qty,
                 N'Return', @ReturnNumber, NULL, @UserID, @Now);

            SET @TotalRefund = @TotalRefund + @Refund;
            FETCH NEXT FROM line_cursor INTO @ItemId, @ProductId, @Qty, @UnitPrice, @DiscRate;
        END
        CLOSE line_cursor;
        DEALLOCATE line_cursor;

        UPDATE dbo.returns
        SET total_refund_amount = @TotalRefund
        WHERE return_id = @ReturnID;

        COMMIT TRANSACTION;

        SELECT @ReturnID AS ReturnId, @TotalRefund AS TotalRefund;
    END TRY
    BEGIN CATCH
        IF CURSOR_STATUS('global','line_cursor') >= 0
        BEGIN
            CLOSE line_cursor;
            DEALLOCATE line_cursor;
        END
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        INSERT INTO dbo.error_logs (user_id, error_code, message, source)
        VALUES (@UserID, N'SP_ProcessReturn', ERROR_MESSAGE(), N'SP_ProcessReturn');
        THROW;
    END CATCH
END
GO