/* ==========================================================================
   SmartPOS Database - TEST SUITE 08: CROSS-MODULE INTEGRATION
   --------------------------------------------------------------------------
   One end-to-end scenario through the operational modules:
     create supplier/category/product -> restock -> CASH sale (with payment)
     -> CREDIT sale -> partial credit payment -> return -> receipt
   and then verifies that the shared views, movement logs and audit trail all
   agree with the ledger.

   HARNESS: single outer transaction, rolled back at the end (non-destructive).
   Success -> PRINT N'Test PASSED: <name>'
   Failure -> THROW <code>, N'Test FAILED: <name>: <detail>', 1
   ========================================================================== */

SET NOCOUNT ON;

DECLARE @AdminID INT = (SELECT TOP (1) user_id FROM dbo.users WHERE username = N'admin');
DECLARE @CashierID INT = (SELECT TOP (1) user_id FROM dbo.users WHERE username = N'cashier');
DECLARE @CashID INT = (SELECT TOP (1) payment_method_id FROM dbo.payment_methods WHERE method_code = N'CASH');

DECLARE @CatID INT, @SupID INT, @ProdID INT, @CustID INT;
DECLARE @SaleCash INT, @SaleCredit INT, @PayID INT, @RetID INT, @RcptID INT;

BEGIN TRANSACTION;

BEGIN TRY

    /* ------------------------------------------------------------------ */
    /* Fixture: master data                                               */
    /* ------------------------------------------------------------------ */
    CREATE TABLE #intg_cat (CategoryID INT);
    CREATE TABLE #q (QuantityOnHand INT);

    INSERT INTO #intg_cat EXEC dbo.SP_CreateCategory @Name = N'Integration Cat', @CreatedByID = @AdminID;
    SELECT TOP (1) @CatID = CategoryID FROM #intg_cat;
    IF @CatID IS NULL THROW 68001, N'Category was not created.', 1;

    EXEC dbo.SP_CreateSupplier
        @Code = N'INTG-SUP', @Name = N'Integration Supplier', @Email = N'sup@test.local',
        @Phone = N'555-0200', @City = N'Denver', @State = N'CO', @Country = N'USA',
        @CreatedByID = @AdminID, @SupplierID = @SupID OUTPUT;
    IF @SupID IS NULL THROW 68001, N'Supplier was not created.', 1;

    EXEC dbo.SP_CreateProduct
        @SKU = N'INTG-SKU', @Barcode = N'INTG-BAR', @Name = N'Integration Widget',
        @CategoryID = @CatID, @SupplierID = @SupID, @UnitPrice = 50.0000, @CostPrice = 25.0000,
        @LowStockThreshold = 5, @CreatedByID = @AdminID, @ProductID = @ProdID OUTPUT;
    IF @ProdID IS NULL THROW 68001, N'Product was not created.', 1;

    INSERT INTO dbo.customers (customer_code, full_name, phone, credit_limit, is_active, is_deleted, created_by)
    VALUES (N'INTG-CUST', N'Integration Customer', N'555-0300', 2000.0000, 1, 0, @AdminID);
    SET @CustID = SCOPE_IDENTITY();

    -- Stock: restock 30 -> then 3 + 2 sold, 1 returned. Expected final: 26.
    INSERT INTO #q EXEC dbo.SP_RestockProduct @ProductID = @ProdID, @Quantity = 30, @UserID = @AdminID, @Reason = N'Integration initial stock';

    /* ------------------------------------------------------------------ */
    /* Cash sale: 3 x 50.00, paid 150 cash                                */
    /* ------------------------------------------------------------------ */
    DECLARE @CashLines NVARCHAR(MAX) = N'[{"productId":' + CAST(@ProdID AS NVARCHAR(20)) + N',"quantity":3,"unitPrice":50.00}]';
    EXEC dbo.SP_CreateSale
        @ReceiptNumber = N'INTG-RCP-001', @UserID = @CashierID, @SaleType = N'CASH',
        @LinesJSON = @CashLines, @AmountReceived = 150.00, @PaymentMethodID = @CashID,
        @SaleID = @SaleCash OUTPUT;

    IF @SaleCash IS NULL THROW 68002, N'Cash sale failed.', 1;
    IF NOT EXISTS (SELECT 1 FROM dbo.sales WHERE sale_id = @SaleCash AND total_amount = 150.0000 AND amount_received = 150.0000)
        THROW 68002, N'Cash sale totals are wrong.', 1;

    /* ------------------------------------------------------------------ */
    /* Credit sale: 2 x 50.00 -> balance 100, then pay 40 -> 60 outstanding */
    /* ------------------------------------------------------------------ */
    DECLARE @CreditLines NVARCHAR(MAX) = N'[{"productId":' + CAST(@ProdID AS NVARCHAR(20)) + N',"quantity":2,"unitPrice":50.00}]';
    EXEC dbo.SP_CreateSale
        @ReceiptNumber = N'INTG-RCP-002', @UserID = @CashierID, @SaleType = N'CREDIT',
        @CustomerID = @CustID, @LinesJSON = @CreditLines,
        @SaleID = @SaleCredit OUTPUT;

    IF NOT EXISTS (SELECT 1 FROM dbo.credit_sales WHERE sale_id = @SaleCredit AND total_amount = 100.0000 AND outstanding_balance = 100.0000 AND status = N'OPEN')
        THROW 68003, N'Credit balance row is wrong.', 1;

    EXEC dbo.SP_RecordPayment @SaleID = @SaleCredit, @MethodID = @CashID, @Amount = 40.00, @ReceivedBy = @AdminID, @PaymentID = @PayID OUTPUT;
    IF NOT EXISTS (SELECT 1 FROM dbo.credit_sales WHERE sale_id = @SaleCredit AND outstanding_balance = 60.0000 AND amount_paid = 40.0000 AND status = N'PARTIAL')
        THROW 68003, N'Credit payment did not update the ledger.', 1;

    /* ------------------------------------------------------------------ */
    /* Return 1 unit of the CASH sale line -> refund 50, stock +1          */
    /* ------------------------------------------------------------------ */
    DECLARE @SaleItemID INT = (SELECT TOP (1) sale_item_id FROM dbo.sale_items WHERE sale_id = @SaleCash);
    DECLARE @RLines NVARCHAR(MAX) = N'[{"saleItemId":' + CAST(@SaleItemID AS NVARCHAR(20)) +
        N',"productId":' + CAST(@ProdID AS NVARCHAR(20)) + N',"quantity":1}]';
    EXEC dbo.SP_ProcessReturn @ReturnNumber = N'INTG-RET-001', @SaleID = @SaleCash, @UserID = @AdminID, @LinesJSON = @RLines, @ReturnID = @RetID OUTPUT;

    IF NOT EXISTS (SELECT 1 FROM dbo.returns WHERE return_id = @RetID AND total_refund_amount = 50.0000 AND status = N'COMPLETED')
        THROW 68004, N'Return header is wrong.', 1;

    /* ------------------------------------------------------------------ */
    /* Receipt for the cash sale                                           */
    /* ------------------------------------------------------------------ */
    EXEC dbo.SP_GenerateReceipt @SaleID = @SaleCash, @GeneratedBy = @AdminID;
    IF NOT EXISTS (SELECT 1 FROM dbo.receipts WHERE sale_id = @SaleCash AND net_total = 150.0000 AND change_due = 0.0000)
        THROW 68005, N'Receipt totals are wrong.', 1;

    /* ------------------------------------------------------------------ */
    /* Cross-module assertions                                             */
    /* ------------------------------------------------------------------ */

    -- 08.06 - Inventory ledger agrees: 30 - 3 - 2 + 1 = 26
    IF (SELECT quantity_on_hand FROM dbo.inventory WHERE product_id = @ProdID) <> 26
        THROW 68006, N'Final stock is not 26.', 1;
    IF NOT EXISTS (SELECT 1 FROM dbo.inventory_transactions WHERE product_id = @ProdID AND movement_type = N'RESTOCK' AND quantity = 30)
        THROW 68006, N'RESTOCK movement missing.', 1;
    IF (SELECT COUNT(*) FROM dbo.inventory_transactions WHERE product_id = @ProdID AND movement_type = N'SALE') <> 2
        THROW 68006, N'Expected 2 SALE movements.', 1;
    IF NOT EXISTS (SELECT 1 FROM dbo.inventory_transactions WHERE product_id = @ProdID AND movement_type = N'RETURN' AND quantity = 1)
        THROW 68006, N'RETURN movement missing.', 1;

    -- 08.07 - Views agree with the transactional state
    IF (SELECT quantity_on_hand FROM dbo.VW_ProductStock WHERE product_id = @ProdID) <> 26
        THROW 68007, N'VW_ProductStock disagrees with inventory.', 1;
    IF (SELECT COUNT(*) FROM dbo.VW_SalesWithLines WHERE sale_id = @SaleCash) <> 1
        THROW 68007, N'VW_SalesWithLines row count wrong for cash sale.', 1;
    IF (SELECT outstanding_balance FROM dbo.VW_CustomerBalances WHERE sale_id = @SaleCredit) <> 60.0000
        THROW 68007, N'VW_CustomerBalances disagrees with ledger.', 1;

    -- 08.08 - Audit trail captured master-data writes
    IF NOT EXISTS (SELECT 1 FROM dbo.audit_logs WHERE resource_type = N'Product' AND resource_id = CAST(@ProdID AS NVARCHAR(20)) AND action_type = N'INSERT')
        THROW 68008, N'Product audit row missing.', 1;
    IF NOT EXISTS (SELECT 1 FROM dbo.audit_logs WHERE resource_type = N'Category' AND resource_id = CAST(@CatID AS NVARCHAR(20)) AND action_type = N'INSERT')
        THROW 68008, N'Category audit row missing.', 1;
    IF NOT EXISTS (SELECT 1 FROM dbo.audit_logs WHERE resource_type = N'Supplier' AND resource_id = CAST(@SupID AS NVARCHAR(20)) AND action_type = N'INSERT')
        THROW 68008, N'Supplier audit row missing.', 1;

    -- 08.09 - Payments / credit ledger rows match the flow
    IF (SELECT COUNT(*) FROM dbo.payments WHERE sale_id IN (@SaleCash, @SaleCredit)) <> 2
        THROW 68009, N'Expected 2 payment rows.', 1;
    IF NOT EXISTS (SELECT 1 FROM dbo.credit_payments WHERE payment_id = @PayID AND amount = 40.0000)
        THROW 68009, N'credit_payments row missing.', 1;

END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    THROW 68099, N'Test FAILED: 08_integration - ' + ERROR_MESSAGE(), 1;
END CATCH;

/* ---------------------------------------------------------------------------
   FILE CLEANUP: roll back the entire run
--------------------------------------------------------------------------- */
IF XACT_STATE() <> 0
    ROLLBACK TRANSACTION;

PRINT N'Test PASSED: 08_integration_all';
