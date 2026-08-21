/* ==========================================================================
   SmartPOS Database - TEST SUITE 12: FULL SMOKE
   --------------------------------------------------------------------------
   One linear happy-path walk through the whole system: user lifecycle,
   authentication, RBAC, catalogue, inventory, POS sales, payments, receipts,
   credit sales, returns, notifications and reporting views.

   HARNESS: single transaction rolled back at the end (non-destructive).
   Success -> PRINT N'Test PASSED: <name>'
   Failure -> THROW <code>, N'Test FAILED: <name>: <detail>', 1
   ========================================================================== */

SET NOCOUNT ON;

DECLARE @AdminID INT = (SELECT TOP (1) user_id FROM dbo.users WHERE username = N'admin');
DECLARE @RoleCash INT = (SELECT TOP (1) role_id FROM dbo.roles WHERE role_code = N'CASHIER');
DECLARE @CashID INT = (SELECT TOP (1) payment_method_id FROM dbo.payment_methods WHERE method_code = N'CASH');
DECLARE @VatID INT = (SELECT TOP (1) tax_rate_id FROM dbo.tax_rates WHERE code = N'VAT_STANDARD');

DECLARE @CashierID INT, @Lid INT, @Sid INT, @CatID INT, @SupID INT, @ProdID INT;
DECLARE @CustID INT, @SaleCash INT, @SaleCredit INT, @RetID INT, @PayID INT;
DECLARE @Tok NVARCHAR(255) = N'smoke-token-' + CAST(CHECKSUM(NEWID()) AS NVARCHAR(20));

CREATE TABLE #cat (CategoryID INT);
CREATE TABLE #vs_valid (
    is_valid BIT, user_id INT, username NVARCHAR(50), email NVARCHAR(255), full_name NVARCHAR(150),
    role_id INT, role_code NVARCHAR(50), role_name NVARCHAR(100), must_change_password BIT,
    session_id INT, session_expires_at DATETIME2(0), [message] NVARCHAR(200)
);
CREATE TABLE #rcpt (
    receipt_id INT, receipt_number NVARCHAR(50), sale_id INT,
    gross_total DECIMAL(19,4), discount_amount DECIMAL(19,4), tax_amount DECIMAL(19,4),
    net_total DECIMAL(19,4), amount_paid DECIMAL(19,4), change_due DECIMAL(19,4),
    generated_by INT, generated_at DATETIME2(0)
);

BEGIN TRANSACTION;

BEGIN TRY

    /* ----------------------------------------------------------------------
       12.01 - User lifecycle: create a cashier
    ---------------------------------------------------------------------- */
    EXEC dbo.SP_CreateUser @Username = N'smokecash', @Email = N'smoke@test.local',
        @PasswordHash = N'HASH_PW', @FullName = N'Smoke Cashier', @Phone = NULL,
        @RoleID = @RoleCash, @CreatedByID = @AdminID, @MustChangePassword = 0, @UserID = @CashierID OUTPUT;

    IF @CashierID IS NULL
        THROW 61201, N'SP_CreateUser returned no UserID.', 1;
    IF NOT EXISTS (SELECT 1 FROM dbo.users WHERE user_id = @CashierID AND is_active = 1)
        THROW 61201, N'Created cashier is not active.', 1;

    /* ----------------------------------------------------------------------
       12.02 - Authentication: login then validate the issued session
    ---------------------------------------------------------------------- */
    EXEC dbo.SP_Login @UsernameOrEmail = N'smokecash', @PasswordHash = N'HASH_PW',
        @IPAddress = N'127.0.0.1', @UserAgent = N'smoke', @HashedSessionToken = @Tok,
        @UserID = @Lid OUTPUT, @SessionID = @Sid OUTPUT;

    IF @Lid <> @CashierID OR @Sid IS NULL
        THROW 61202, N'SP_Login did not issue a session for the cashier.', 1;

    DELETE FROM #vs_valid;
    INSERT INTO #vs_valid EXEC dbo.SP_ValidateSession @SessionTokenHash = @Tok;

    IF (SELECT COUNT(*) FROM #vs_valid) <> 1
        THROW 61202, N'SP_ValidateSession did not confirm the session.', 1;
    IF (SELECT TOP (1) is_valid FROM #vs_valid) <> 1
        THROW 61202, N'SP_ValidateSession reported is_valid = 0.', 1;

    /* ----------------------------------------------------------------------
       12.03 - RBAC: the cashier has products/sales permissions but no
              admin-only permission
    ---------------------------------------------------------------------- */
    IF dbo.FN_HasPermission(@CashierID, N'products.view') = 0
        THROW 61203, N'Cashier lacks products.view.', 1;
    IF dbo.FN_HasPermission(@CashierID, N'users.create') = 1
        THROW 61203, N'Cashier unexpectedly has users.create.', 1;

    /* ----------------------------------------------------------------------
       12.04 - Catalogue: category, supplier, product
    ---------------------------------------------------------------------- */
    DELETE FROM #cat;
    INSERT INTO #cat EXEC dbo.SP_CreateCategory @Name = N'Smoke Cat', @ParentID = NULL,
        @Description = NULL, @SortOrder = 0, @CreatedByID = @AdminID;
    SELECT TOP (1) @CatID = CategoryID FROM #cat;

    EXEC dbo.SP_CreateSupplier @Code = N'SMK-SUP', @Name = N'Smoke Supplier',
        @ContactPerson = NULL, @Email = NULL, @Phone = NULL,
        @AddressLine1 = N'1 Smoke St', @City = N'Testville', @Country = N'GH',
        @Notes = NULL, @CreatedByID = @AdminID, @SupplierID = @SupID OUTPUT;

    EXEC dbo.SP_CreateProduct @SKU = N'SMK-100', @Name = N'Smoke Product', @UnitPrice = 25.00,
        @CategoryID = @CatID, @Description = NULL, @Barcode = N'SMK-BAR-100', @LowStockThreshold = 5,
        @PrimaryImageURL = NULL, @CostPrice = 12.00, @SupplierID = @SupID,
        @CreatedByID = @AdminID, @ProductID = @ProdID OUTPUT;

    /* ----------------------------------------------------------------------
       12.05 - Inventory: restock, then verify the ledger
    ---------------------------------------------------------------------- */
    DECLARE @Qty INT;
    EXEC dbo.SP_RestockProduct @ProductID = @ProdID, @Quantity = 40, @UserID = @AdminID,
        @Reason = N'initial';
    SELECT @Qty = quantity_on_hand FROM dbo.inventory WHERE product_id = @ProdID;
    IF @Qty <> 40 THROW 61205, N'Restock did not set quantity to 40.', 1;

    IF (SELECT COUNT(*) FROM dbo.inventory_transactions WHERE product_id = @ProdID) <> 1
        THROW 61205, N'RESTOCK movement not recorded.', 1;

    /* ----------------------------------------------------------------------
       12.06 - POS: cash sale with full payment + receipt
    ---------------------------------------------------------------------- */
    EXEC dbo.SP_CreateSale @ReceiptNumber = N'SMK-R1', @UserID = @CashierID, @SaleDate = NULL,
        @CustomerID = NULL, @TaxRateID = NULL, @SaleType = N'CASH', @DiscountAmount = 5.00,
        @LinesJSON = N'[{"productId": ' + CAST(@ProdID AS NVARCHAR(10)) + N', "quantity": 4, "unitPrice": 25.00}]',
        @AmountReceived = 100, @PaymentMethodID = @CashID, @Notes = NULL, @SaleID = @SaleCash OUTPUT;

    INSERT INTO #rcpt EXEC dbo.SP_GenerateReceipt @SaleID = @SaleCash, @GeneratedBy = @CashierID;

    IF NOT EXISTS (SELECT 1 FROM dbo.receipts WHERE sale_id = @SaleCash)
        THROW 61206, N'Receipt not generated.', 1;

    /* subtotal = 4*25 = 100; header discount 5 -> subtotal 95; no tax -> total 95 */
    IF (SELECT total_amount FROM dbo.sales WHERE sale_id = @SaleCash) <> 95.0000
        THROW 61206, N'Cash sale total is not 95.0000.', 1;

    SELECT @Qty = quantity_on_hand FROM dbo.inventory WHERE product_id = @ProdID;
    IF @Qty <> 36 THROW 61206, N'Stock after cash sale is not 36.', 1;

    /* ----------------------------------------------------------------------
       12.07 - POS: credit sale for a customer + partial payment
    ---------------------------------------------------------------------- */
    INSERT INTO dbo.customers (customer_code, full_name, phone, credit_limit, is_active, is_deleted, created_by)
    VALUES (N'SMK-C1', N'Smoke Customer', N'123', 200.0000, 1, 0, @AdminID);
    SET @CustID = SCOPE_IDENTITY();

    EXEC dbo.SP_CreateSale @ReceiptNumber = N'SMK-R2', @UserID = @CashierID, @SaleDate = NULL,
        @CustomerID = @CustID, @TaxRateID = @VatID, @SaleType = N'CREDIT', @DiscountAmount = 0,
        @LinesJSON = N'[{"productId": ' + CAST(@ProdID AS NVARCHAR(10)) + N', "quantity": 6, "unitPrice": 25.00, "taxAmount": 11.25}]',
        @AmountReceived = 0, @PaymentMethodID = NULL, @Notes = NULL, @SaleID = @SaleCredit OUTPUT;

    IF NOT EXISTS (SELECT 1 FROM dbo.credit_sales WHERE sale_id = @SaleCredit AND [status] = N'OPEN')
        THROW 61207, N'Credit sale not recorded as OPEN.', 1;

    DECLARE @Bal DECIMAL(19,4);
    SELECT @Bal = outstanding_balance FROM dbo.credit_sales WHERE sale_id = @SaleCredit;
    /* line_total = 150 (no tax on lines); tax = 7.5% of 150 = 11.25; total = 161.25 */
    IF @Bal <> 161.2500
        THROW 61207, N'Credit sale outstanding balance is not 161.2500.', 1;

    EXEC dbo.SP_RecordPayment @SaleID = @SaleCredit, @MethodID = @CashID, @Amount = 61.25,
        @ReceivedBy = @CashierID, @PaymentID = @PayID OUTPUT;

    SELECT @Bal = outstanding_balance FROM dbo.credit_sales WHERE sale_id = @SaleCredit;
    IF @Bal <> 100.0000
        THROW 61207, N'Outstanding after 61.25 payment is not 100.0000.', 1;
    IF (SELECT [status] FROM dbo.credit_sales WHERE sale_id = @SaleCredit) <> N'PARTIAL'
        THROW 61207, N'Credit sale status is not PARTIAL after partial payment.', 1;

    /* ----------------------------------------------------------------------
       12.08 - Returns: refund one unit of the cash sale
    ---------------------------------------------------------------------- */
    DECLARE @SoldItem INT = (SELECT TOP (1) sale_item_id FROM dbo.sale_items WHERE sale_id = @SaleCash);

    EXEC dbo.SP_ProcessReturn @ReturnNumber = N'SMK-RTN', @SaleID = @SaleCash, @UserID = @CashierID,
        @ReturnReasonID = NULL, @CustomerID = NULL,
        @LinesJSON = N'[{"saleItemId": ' + CAST(@SoldItem AS NVARCHAR(10)) + N', "productId": ' + CAST(@ProdID AS NVARCHAR(10)) + N', "quantity": 1}]',
        @Notes = NULL, @ReturnID = @RetID OUTPUT;

    IF (SELECT total_refund_amount FROM dbo.returns WHERE return_id = @RetID) <> 25.0000
        THROW 61208, N'Return refund is not 25.0000.', 1;

    SELECT @Qty = quantity_on_hand FROM dbo.inventory WHERE product_id = @ProdID;
    IF @Qty <> 37 THROW 61208, N'Stock after return is not 37.', 1;

    /* ----------------------------------------------------------------------
       12.09 - Views / notifications / ledger agree with the smoke data
    ---------------------------------------------------------------------- */
    IF (SELECT quantity_on_hand FROM dbo.inventory WHERE product_id = @ProdID) <> 37
        THROW 61209, N'inventory.quantity_on_hand is not 37.', 1;
    IF NOT EXISTS (SELECT 1 FROM dbo.VW_ProductStock WHERE product_id = @ProdID AND quantity_on_hand = 37)
        THROW 61209, N'VW_ProductStock disagrees with inventory.', 1;
    IF (SELECT COUNT(*) FROM dbo.VW_SalesWithLines WHERE sale_id = @SaleCash) <> 1
        THROW 61209, N'VW_SalesWithLines missing the cash sale.', 1;
    IF (SELECT COUNT(*) FROM dbo.VW_CustomerBalances WHERE customer_id = @CustID AND balance_due = 100.0000) = 0
        THROW 61209, N'VW_CustomerBalances missing the outstanding credit.', 1;

    IF (SELECT COUNT(*) FROM dbo.VW_SalesSummary) = 0
        THROW 61209, N'VW_SalesSummary returned no rows.', 1;

    IF NOT EXISTS (SELECT 1 FROM dbo.audit_logs WHERE entity_type = N'Product' AND entity_id = @ProdID)
        THROW 61209, N'Product audit trail missing.', 1;

END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    THROW 61299, N'Test FAILED: 12_smoke_full - ' + ERROR_MESSAGE(), 1;
END CATCH;

IF XACT_STATE() <> 0
    ROLLBACK TRANSACTION;

PRINT N'Test PASSED: 12_smoke_full_all';
