/* ==========================================================================
   SmartPOS Database - TEST SUITE 11: EDGE CASES
   --------------------------------------------------------------------------
   Boundary / hostile-input behaviour of the stored procedures:
     - NULL and blank inputs on the login path
     - negative / zero quantities, prices and stock levels
     - malformed JSON, self-referencing category, over-return
     - overpayment on a credit sale clamps the balance (documented behaviour)

   HARNESS: single transaction rolled back at the end. Procs set XACT_ABORT,
   so after every expected failure the transaction is reopened when the
   proc's rollback has destroyed it.
   Success -> PRINT N'Test PASSED: <name>'
   Failure -> THROW <code>, N'Test FAILED: <name>: <detail>', 1
   ========================================================================== */

SET NOCOUNT ON;

DECLARE @AdminID INT = (SELECT TOP (1) user_id FROM dbo.users WHERE username = N'admin');
DECLARE @CatID INT, @SelfCat INT, @ProdID INT, @ProdID2 INT, @CustID INT, @SaleID INT;
DECLARE @out INT;

CREATE TABLE #ecat (CategoryID INT);

BEGIN TRANSACTION;

BEGIN TRY

    /* --- fixture: category + two products + customer -------------------- */
    INSERT INTO #ecat EXEC dbo.SP_CreateCategory @Name = N'Edge Cat', @ParentID = NULL,
        @Description = NULL, @SortOrder = 0, @CreatedByID = @AdminID;
    SELECT TOP (1) @CatID = CategoryID FROM #ecat;

    EXEC dbo.SP_CreateProduct @SKU = N'EDGE-01', @Name = N'Edge Product', @UnitPrice = 50.00,
        @CategoryID = @CatID, @Description = NULL, @Barcode = NULL, @LowStockThreshold = 5,
        @PrimaryImageURL = NULL, @CostPrice = 20.00, @SupplierID = NULL,
        @CreatedByID = @AdminID, @ProductID = @ProdID OUTPUT;
    INSERT INTO dbo.inventory (product_id, quantity_on_hand) VALUES (@ProdID, 10);

    EXEC dbo.SP_CreateProduct @SKU = N'EDGE-02', @Name = N'Edge Product 2', @UnitPrice = 10.00,
        @CategoryID = @CatID, @Description = NULL, @Barcode = NULL, @LowStockThreshold = 2,
        @PrimaryImageURL = NULL, @CostPrice = 4.00, @SupplierID = NULL,
        @CreatedByID = @AdminID, @ProductID = @ProdID2 OUTPUT;
    INSERT INTO dbo.inventory (product_id, quantity_on_hand) VALUES (@ProdID2, 100);

    INSERT INTO dbo.customers (customer_code, full_name, phone, credit_limit, is_active, is_deleted, created_by)
    VALUES (N'EDGE-C1', N'Edge Customer', N'000', 100.0000, 1, 0, @AdminID);
    SET @CustID = SCOPE_IDENTITY();

    /* ----------------------------------------------------------------------
       11.01 - SP_Login with missing credentials -> 40100
    ---------------------------------------------------------------------- */
    BEGIN TRY
        DECLARE @U INT, @S INT;
        EXEC dbo.SP_Login @UsernameOrEmail = N'', @PasswordHash = NULL, @IPAddress = N'127.0.0.1',
            @UserAgent = N'test', @HashedSessionToken = NULL, @UserID = @U OUTPUT, @SessionID = @S OUTPUT;
        THROW 61101, N'Login with missing credentials accepted.', 1;
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() NOT IN (40100, 35100) THROW;
    END CATCH;
    IF XACT_STATE() = 0 BEGIN TRANSACTION;

    /* ----------------------------------------------------------------------
       11.02 - SP_CreateProduct with negative price -> 50055
    ---------------------------------------------------------------------- */
    BEGIN TRY
        EXEC dbo.SP_CreateProduct @SKU = N'EDGE-BAD', @Name = N'Bad Price', @UnitPrice = -1.00,
            @CategoryID = @CatID, @Description = NULL, @Barcode = NULL, @LowStockThreshold = 1,
            @PrimaryImageURL = NULL, @CostPrice = NULL, @SupplierID = NULL,
            @CreatedByID = @AdminID, @ProductID = @out OUTPUT;
        THROW 61102, N'Negative unit price accepted.', 1;
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() NOT IN (50055, 35100) THROW;
    END CATCH;
    IF XACT_STATE() = 0 BEGIN TRANSACTION;

    /* ----------------------------------------------------------------------
       11.03 - SP_CreateSale with quantity <= 0 -> 50007
    ---------------------------------------------------------------------- */
    BEGIN TRY
        EXEC dbo.SP_CreateSale @ReceiptNumber = N'EDGE-R1', @UserID = @AdminID, @SaleDate = NULL,
            @CustomerID = NULL, @TaxRateID = NULL, @SaleType = N'CASH', @DiscountAmount = 0,
            @LinesJSON = N'[{"productId": ' + CAST(@ProdID AS NVARCHAR(10)) + N', "quantity": 0, "unitPrice": 50.00}]',
            @AmountReceived = 50, @PaymentMethodID = NULL, @Notes = NULL, @SaleID = @SaleID OUTPUT;
        THROW 61103, N'Zero-quantity sale accepted.', 1;
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() NOT IN (50007, 35100) THROW;
    END CATCH;
    IF XACT_STATE() = 0 BEGIN TRANSACTION;

    /* ----------------------------------------------------------------------
       11.04 - SP_CreateSale with quantity above stock -> 50007
    ---------------------------------------------------------------------- */
    BEGIN TRY
        EXEC dbo.SP_CreateSale @ReceiptNumber = N'EDGE-R2', @UserID = @AdminID, @SaleDate = NULL,
            @CustomerID = NULL, @TaxRateID = NULL, @SaleType = N'CASH', @DiscountAmount = 0,
            @LinesJSON = N'[{"productId": ' + CAST(@ProdID AS NVARCHAR(10)) + N', "quantity": 11, "unitPrice": 50.00}]',
            @AmountReceived = 550, @PaymentMethodID = NULL, @Notes = NULL, @SaleID = @SaleID OUTPUT;
        THROW 61104, N'Over-stock sale accepted.', 1;
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() NOT IN (50007, 35100) THROW;
    END CATCH;
    IF XACT_STATE() = 0 BEGIN TRANSACTION;

    /* ----------------------------------------------------------------------
       11.05 - SP_CreateSale with malformed JSON -> 50005
    ---------------------------------------------------------------------- */
    BEGIN TRY
        EXEC dbo.SP_CreateSale @ReceiptNumber = N'EDGE-R3', @UserID = @AdminID, @SaleDate = NULL,
            @CustomerID = NULL, @TaxRateID = NULL, @SaleType = N'CASH', @DiscountAmount = 0,
            @LinesJSON = N'not json', @AmountReceived = 0, @PaymentMethodID = NULL, @Notes = NULL,
            @SaleID = @SaleID OUTPUT;
        THROW 61105, N'Malformed JSON accepted.', 1;
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() NOT IN (50005, 35100) THROW;
    END CATCH;
    IF XACT_STATE() = 0 BEGIN TRANSACTION;

    /* ----------------------------------------------------------------------
       11.06 - SP_AdjustStock that would drive stock negative -> 50015
    ---------------------------------------------------------------------- */
    BEGIN TRY
        EXEC dbo.SP_AdjustStock @ProductID = @ProdID, @Quantity = -50, @AdjustmentType = N'CORRECTION',
            @UserID = @AdminID, @Reason = N'Edge';
        THROW 61106, N'Negative stock result accepted.', 1;
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() NOT IN (50015, 35100) THROW;
    END CATCH;
    IF XACT_STATE() = 0 BEGIN TRANSACTION;

    /* ----------------------------------------------------------------------
       11.07 - SP_CreateCategory with itself as parent -> 50040
    ---------------------------------------------------------------------- */
    BEGIN TRY
        CREATE TABLE #selfcat (CategoryID INT);
        INSERT INTO #selfcat EXEC dbo.SP_CreateCategory @Name = N'Self Cat', @ParentID = @CatID,
            @Description = NULL, @SortOrder = 0, @CreatedByID = @AdminID;
        SELECT TOP (1) @SelfCat = CategoryID FROM #selfcat;
        EXEC dbo.SP_UpdateCategory @CategoryID = @SelfCat, @Name = N'Self Cat', @ParentID = @SelfCat,
            @Description = NULL, @SortOrder = 0, @UpdatedByID = @AdminID;
        THROW 61107, N'Self-parent category accepted.', 1;
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() NOT IN (50040, 35100) THROW;
    END CATCH;
    IF XACT_STATE() = 0 BEGIN TRANSACTION;

    /* ----------------------------------------------------------------------
       11.08 - SP_ProcessReturn returning more than was sold -> 50025
    ---------------------------------------------------------------------- */
    EXEC dbo.SP_CreateSale @ReceiptNumber = N'EDGE-R4', @UserID = @AdminID, @SaleDate = NULL,
        @CustomerID = NULL, @TaxRateID = NULL, @SaleType = N'CASH', @DiscountAmount = 0,
        @LinesJSON = N'[{"productId": ' + CAST(@ProdID AS NVARCHAR(10)) + N', "quantity": 1, "unitPrice": 50.00}]',
        @AmountReceived = 50, @PaymentMethodID = NULL, @Notes = NULL, @SaleID = @SaleID OUTPUT;
    IF XACT_STATE() = 0 BEGIN TRANSACTION;

    BEGIN TRY
        EXEC dbo.SP_ProcessReturn @ReturnNumber = N'EDGE-RTN', @SaleID = @SaleID, @UserID = @AdminID,
            @ReturnReasonID = NULL, @CustomerID = NULL,
            @LinesJSON = N'[{"saleItemId": 999999, "productId": ' + CAST(@ProdID AS NVARCHAR(10)) + N', "quantity": 1}]',
            @Notes = NULL, @ReturnID = @out OUTPUT;
        THROW 61108, N'Return for a line that was never sold accepted.', 1;
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() NOT IN (50024, 35100) THROW;
    END CATCH;
    IF XACT_STATE() = 0 BEGIN TRANSACTION;

    DECLARE @SoldItemID INT = (SELECT TOP (1) sale_item_id FROM dbo.sale_items WHERE sale_id = @SaleID);

    BEGIN TRY
        EXEC dbo.SP_ProcessReturn @ReturnNumber = N'EDGE-RTN2', @SaleID = @SaleID, @UserID = @AdminID,
            @ReturnReasonID = NULL, @CustomerID = NULL,
            @LinesJSON = N'[{"saleItemId": ' + CAST(@SoldItemID AS NVARCHAR(10)) + N', "productId": ' + CAST(@ProdID AS NVARCHAR(10)) + N', "quantity": 2}]',
            @Notes = NULL, @ReturnID = @out OUTPUT;
        THROW 61108, N'Over-return accepted.', 1;
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() NOT IN (50025, 35100) THROW;
    END CATCH;
    IF XACT_STATE() = 0 BEGIN TRANSACTION;

    /* ----------------------------------------------------------------------
       11.09 - SP_ChangePassword with wrong current password -> 52014
    ---------------------------------------------------------------------- */
    BEGIN TRY
        EXEC dbo.SP_ChangePassword @UserID = @AdminID, @CurrentPasswordHash = N'wrong-hash',
            @NewPasswordHash = N'some-new-hash', @CurrentSessionTokenHash = NULL;
        THROW 61109, N'Wrong current password accepted.', 1;
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() NOT IN (52014, 35100) THROW;
    END CATCH;
    IF XACT_STATE() = 0 BEGIN TRANSACTION;

    /* ----------------------------------------------------------------------
       11.10 - SP_RecordPayment overpays a credit sale -> balance clamps to 0
       Documented behaviour: outstanding never goes negative; status = SETTLED.
    ---------------------------------------------------------------------- */
    EXEC dbo.SP_CreateSale @ReceiptNumber = N'EDGE-R5', @UserID = @AdminID, @SaleDate = NULL,
        @CustomerID = @CustID, @TaxRateID = NULL, @SaleType = N'CREDIT', @DiscountAmount = 0,
        @LinesJSON = N'[{"productId": ' + CAST(@ProdID AS NVARCHAR(10)) + N', "quantity": 1, "unitPrice": 50.00}]',
        @AmountReceived = 0, @PaymentMethodID = NULL, @Notes = NULL, @SaleID = @SaleID OUTPUT;
    IF XACT_STATE() = 0 BEGIN TRANSACTION;

    DECLARE @CashID INT = (SELECT TOP (1) payment_method_id FROM dbo.payment_methods WHERE method_code = N'CASH');

    EXEC dbo.SP_RecordPayment @SaleID = @SaleID, @MethodID = @CashID, @Amount = 60.00,
        @ReceivedBy = @AdminID, @PaymentID = @out OUTPUT;
    IF XACT_STATE() = 0 BEGIN TRANSACTION;

    IF (SELECT outstanding_balance FROM dbo.credit_sales WHERE sale_id = @SaleID) <> 0.0000
        THROW 61110, N'Overpaid credit sale balance did not clamp to 0.', 1;
    IF (SELECT [status] FROM dbo.credit_sales WHERE sale_id = @SaleID) <> N'SETTLED'
        THROW 61110, N'Overpaid credit sale status is not SETTLED.', 1;
    IF (SELECT amount_paid FROM dbo.credit_sales WHERE sale_id = @SaleID) <> 60.0000
        THROW 61110, N'Overpaid credit sale amount_paid is not 60.', 1;

END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    THROW 61199, N'Test FAILED: 11_edge_cases - ' + ERROR_MESSAGE(), 1;
END CATCH;

IF XACT_STATE() <> 0
    ROLLBACK TRANSACTION;

PRINT N'Test PASSED: 11_edge_cases_all';
