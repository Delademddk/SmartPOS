/* ==========================================================================
   SmartPOS Database - SP_CreateSale
   --------------------------------------------------------------------------
   Atomically creates a sale with its line items, decrements inventory,
   records stock movements, creates the credit balance when the sale is a
   credit sale, and registers the payment.

   The line items are passed as a single JSON array string which is parsed
   with OPENJSON (SQL Server 2016+). JSON schema for each element:
     {
       "productId": 1,
       "quantity": 2,
       "unitPrice": 12.50,
       "discountRate": 0.10,
       "taxAmount": 1.25
     }

   Behaviour:
     - Validates the sale type, customer presence for credit sales, and that
       each product exists, is active, and has sufficient stock.
     - Computes line totals, subtotal, and total in a single transaction.
     - Decrements dbo.inventory.quantity_on_hand per line.
     - Inserts one dbo.inventory_transactions row per line (SALE).
     - Marks sale_type and creates dbo.credit_sales balance for credit sales.
     - Optionally creates a payment when amount_received > 0.
   ========================================================================== */
IF OBJECT_ID(N'dbo.SP_CreateSale', N'P') IS NOT NULL DROP PROCEDURE dbo.SP_CreateSale;
GO
CREATE PROCEDURE dbo.SP_CreateSale
    @ReceiptNumber   NVARCHAR(50),
    @UserID          INT,
    @SaleDate        DATETIME2(0) = NULL,
    @CustomerID      INT = NULL,
    @TaxRateID       INT = NULL,
    @SaleType        NVARCHAR(20) = N'CASH',
    @DiscountAmount  DECIMAL(19,4) = 0,
    @LinesJSON       NVARCHAR(MAX),
    @AmountReceived  DECIMAL(19,4) = 0,
    @PaymentMethodID INT = NULL,
    @Notes           NVARCHAR(MAX) = NULL,
    @SaleID          INT = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @Now DATETIME2(0) = SYSUTCDATETIME();
    DECLARE @Subtotal DECIMAL(19,4) = 0;
    DECLARE @TaxTotal DECIMAL(19,4) = 0;
    DECLARE @Total DECIMAL(19,4) = 0;
    DECLARE @Err NVARCHAR(4000);

    BEGIN TRY
        -- ------------------------------------------------------------------
        -- Validation
        -- ------------------------------------------------------------------
        IF @SaleDate IS NULL SET @SaleDate = @Now;

        IF @SaleType NOT IN (N'CASH', N'CREDIT', N'CREDIT_PARTIAL')
            THROW 50001, N'Invalid sale type.', 1;

        IF @SaleType IN (N'CREDIT', N'CREDIT_PARTIAL') AND @CustomerID IS NULL
            THROW 50002, N'A customer is required for credit sales.', 1;

        IF NULLIF(LTRIM(RTRIM(@ReceiptNumber)), N'') IS NULL
            THROW 50003, N'A receipt number is required.', 1;

        IF NOT EXISTS (SELECT 1 FROM dbo.users WHERE user_id = @UserID AND is_active = 1 AND is_deleted = 0)
            THROW 50004, N'Unknown or inactive user.', 1;

        IF ISJSON(@LinesJSON) = 0
            THROW 50005, N'Lines must be a valid JSON array.', 1;

        -- Validate that every product exists and has enough stock.
        SELECT TOP (1) @Err = N'Product ' + CAST(p.product_id AS NVARCHAR(20)) +
                                N' does not exist or is inactive.'
        FROM OPENJSON(@LinesJSON)
        WITH (ProductId INT '$.productId', Quantity DECIMAL(12,3) '$.quantity') AS j
        LEFT JOIN dbo.products p
            ON p.product_id = j.ProductId
           AND p.is_active = 1
           AND p.is_deleted = 0
        WHERE p.product_id IS NULL OR j.Quantity <= 0;

        IF @Err IS NOT NULL THROW 50006, @Err, 1;

        BEGIN TRANSACTION;

        -- ------------------------------------------------------------------
        -- Parse lines into a temporary staging table for consistent math
        -- ------------------------------------------------------------------
        SELECT
            j.ProductId,
            j.Quantity,
            j.UnitPrice,
            j.DiscountRate,
            j.TaxAmount,
            p.low_stock_threshold,
            ROUND(j.UnitPrice * j.Quantity * (1 - ISNULL(j.DiscountRate, 0)), 4) AS LineTotal
        INTO #sale_lines
        FROM OPENJSON(@LinesJSON)
        WITH (
            ProductId    INT            '$.productId',
            Quantity     DECIMAL(12,3)  '$.quantity',
            UnitPrice    DECIMAL(19,4)  '$.unitPrice',
            DiscountRate DECIMAL(5,4)   '$.discountRate',
            TaxAmount    DECIMAL(19,4)  '$.taxAmount'
        ) AS j
        JOIN dbo.products p
            ON p.product_id = j.ProductId
           AND p.is_active = 1
           AND p.is_deleted = 0;

        -- Stock sufficiency (with row locks to prevent overselling)
        SELECT TOP (1) @Err = N'Insufficient stock for product ' + CAST(sl.ProductId AS NVARCHAR(20)) + N'.'
        FROM #sale_lines sl
        JOIN dbo.inventory i WITH (UPDLOCK, ROWLOCK)
            ON i.product_id = sl.ProductId
        WHERE i.quantity_on_hand < sl.Quantity;

        IF @Err IS NOT NULL THROW 50007, @Err, 1;

        -- ------------------------------------------------------------------
        -- Totals
        -- ------------------------------------------------------------------
        SELECT @Subtotal = SUM(LineTotal),
               @TaxTotal  = SUM(ISNULL(TaxAmount, 0))
        FROM #sale_lines;

        SET @Subtotal = ISNULL(@Subtotal, 0);
        SET @TaxTotal = ISNULL(@TaxTotal, 0);
        SET @DiscountAmount = ISNULL(@DiscountAmount, 0);
        SET @Total = ROUND(@Subtotal - @DiscountAmount + @TaxTotal, 4);

        IF @Total < 0 THROW 50008, N'Sale total cannot be negative.', 1;

        -- ------------------------------------------------------------------
        -- Insert header
        -- ------------------------------------------------------------------
        INSERT INTO dbo.sales
            (receipt_number, sale_date, user_id, customer_id, tax_rate_id,
             sale_type, subtotal, discount_amount, tax_amount, total_amount,
             amount_received, status, notes, created_at, updated_at)
        VALUES
            (@ReceiptNumber, @SaleDate, @UserID, @CustomerID, @TaxRateID,
             @SaleType, @Subtotal, @DiscountAmount, @TaxTotal, @Total,
             @AmountReceived, N'COMPLETED', @Notes, @Now, @Now);

        SET @SaleID = SCOPE_IDENTITY();

        -- ------------------------------------------------------------------
        -- Insert items + decrement stock + movements
        -- ------------------------------------------------------------------
        INSERT INTO dbo.sale_items
            (sale_id, product_id, quantity, unit_price, discount_rate,
             tax_amount, line_total, created_at)
        SELECT @SaleID, sl.ProductId, sl.Quantity, sl.UnitPrice,
               ISNULL(sl.DiscountRate, 0), ISNULL(sl.TaxAmount, 0), sl.LineTotal, @Now
        FROM #sale_lines sl;

        -- Decrement stock per line
        UPDATE inv
        SET inv.quantity_on_hand = inv.quantity_on_hand - sl.Quantity,
            inv.last_sold_at     = @Now,
            inv.updated_at       = @Now
        FROM dbo.inventory inv
        JOIN #sale_lines sl ON sl.ProductId = inv.product_id;

        -- Log movements
        INSERT INTO dbo.inventory_transactions
            (product_id, movement_type, quantity, quantity_before, quantity_after,
             unit_cost, reference_type, reference_id, reason, user_id, created_at)
        SELECT
            sl.ProductId, N'SALE', -sl.Quantity,
            inv.quantity_on_hand + sl.Quantity,       -- before = current + sold
            inv.quantity_on_hand,                      -- after = current
            sl.UnitPrice, N'Sale', @ReceiptNumber,
            N'Sale receipt ' + @ReceiptNumber, @UserID, @Now
        FROM #sale_lines sl
        JOIN dbo.inventory inv ON inv.product_id = sl.ProductId;

        -- ------------------------------------------------------------------
        -- Credit sale: create balance
        -- ------------------------------------------------------------------
        IF @SaleType IN (N'CREDIT', N'CREDIT_PARTIAL')
        BEGIN
            INSERT INTO dbo.credit_sales
                (sale_id, customer_id, total_amount, amount_paid,
                 outstanding_balance, status, created_at, updated_at)
            VALUES
                (@SaleID, @CustomerID, @Total,
                 CASE WHEN @SaleType = N'CREDIT_PARTIAL' THEN @AmountReceived ELSE 0 END,
                 CASE WHEN @SaleType = N'CREDIT_PARTIAL' THEN @Total - @AmountReceived ELSE @Total END,
                 N'OPEN', @Now, @Now);
        END

        -- ------------------------------------------------------------------
        -- Payment (cash / partial)
        -- ------------------------------------------------------------------
        IF @AmountReceived > 0
        BEGIN
            DECLARE @MethodID INT = @PaymentMethodID;
            IF @MethodID IS NULL
                SELECT @MethodID = payment_method_id
                FROM dbo.payment_methods
                WHERE method_code = N'CASH' AND is_active = 1;

            IF @MethodID IS NULL
                THROW 50009, N'No valid payment method.', 1;

            INSERT INTO dbo.payments
                (sale_id, payment_method_id, amount, received_at, received_by,
                 pay_status, notes, created_at)
            VALUES
                (@SaleID, @MethodID, @AmountReceived, @Now, @UserID,
                 N'COMPLETED', NULL, @Now);

            IF @SaleType = N'CASH'
                UPDATE dbo.sales
                SET amount_received = @AmountReceived
                WHERE sale_id = @SaleID;
        END

        COMMIT TRANSACTION;

        SELECT @SaleID AS SaleId, @Total AS TotalAmount;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;

        INSERT INTO dbo.error_logs (user_id, error_code, message, stack_trace, source)
        VALUES (@UserID, N'SP_CreateSale', ERROR_MESSAGE(), ERROR_PROCEDURE(), N'SP_CreateSale');

        THROW;
    END CATCH
END
GO