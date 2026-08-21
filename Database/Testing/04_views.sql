/* ==========================================================================
   SmartPOS Database - TEST SUITE 04: VIEWS
   --------------------------------------------------------------------------
   Smoke + semantic checks over the operational and reporting views:
     Core        VW_UserPermissions, VW_ProductStock, VW_SalesWithLines,
                 VW_CustomerBalances, VW_LowStock
     Reports     VW_SalesSummary, VW_DailySales, VW_ProductSalesReport,
                 VW_InventoryReport, VW_InventoryMovementsReport, VW_SupplierReport,
                 VW_CreditReport, VW_ReturnsReport, VW_ProfitReport,
                 VW_PaymentMethodsReport, VW_TaxReport
     Dashboard   VW_DashboardKPIs, VW_RecentSales, VW_TopProducts, VW_SalesTrend7d,
                 VW_SalesByCategory, VW_SalesByPaymentMethod, VW_RecentNotifications,
                 VW_OutstandingCredit

   HARNESS
     - Seeds a small fixture inside ONE transaction, asserts view behaviour,
       then rolls everything back -> non-destructive.
     - Success  -> PRINT N'Test PASSED: <name>'
     - Failure  -> THROW <code>, N'Test FAILED: <name>: <detail>', 1
   ========================================================================== */

SET NOCOUNT ON;

DECLARE @AdminID  INT = (SELECT TOP (1) user_id FROM dbo.users WHERE username = N'admin');
DECLARE @CatID    INT, @SupID INT, @CustID INT, @P1 INT, @P2 INT, @SaleID INT, @Rc INT;

BEGIN TRANSACTION;

BEGIN TRY

    -- ======================================================================
    -- FIXTURE
    -- ======================================================================
    INSERT INTO dbo.categories (category_name, is_active, is_deleted, created_by)
    VALUES (N'ViewTest Category', 1, 0, @AdminID);
    SET @CatID = SCOPE_IDENTITY();

    INSERT INTO dbo.suppliers (supplier_code, supplier_name, is_active, is_deleted, created_by)
    VALUES (N'VWSUP', N'ViewTest Supplier', 1, 0, @AdminID);
    SET @SupID = SCOPE_IDENTITY();

    -- P1: low stock (5 units, threshold 10) ; P2: healthy (50 units, threshold 10)
    INSERT INTO dbo.products (sku, product_name, unit_price, cost_price, category_id, supplier_id, low_stock_threshold, created_by)
    VALUES (N'VWSKU-LOW', N'View Test Low', 10.0000, 5.0000, @CatID, @SupID, 10, @AdminID);
    SET @P1 = SCOPE_IDENTITY();
    INSERT INTO dbo.products (sku, product_name, unit_price, cost_price, category_id, supplier_id, low_stock_threshold, created_by)
    VALUES (N'VWSKU-OK', N'View Test OK', 20.0000, 10.0000, @CatID, @SupID, 10, @AdminID);
    SET @P2 = SCOPE_IDENTITY();

    INSERT INTO dbo.inventory (product_id, quantity_on_hand, quantity_reserved, reorder_level, updated_at)
    VALUES (@P1, 5, 0, 10, SYSUTCDATETIME());
    INSERT INTO dbo.inventory (product_id, quantity_on_hand, quantity_reserved, reorder_level, updated_at)
    VALUES (@P2, 50, 0, 10, SYSUTCDATETIME());

    INSERT INTO dbo.customers (customer_code, full_name, phone, credit_limit, is_active, is_deleted, created_by)
    VALUES (N'VWCUST', N'View Test Customer', N'555-0100', 1000.0000, 1, 0, @AdminID);
    SET @CustID = SCOPE_IDENTITY();

    INSERT INTO dbo.sales (receipt_number, sale_date, user_id, customer_id, sale_type, subtotal, discount_amount, tax_amount, total_amount, amount_received, [status])
    VALUES (N'VW-SALE-0001', SYSUTCDATETIME(), @AdminID, @CustID, N'CREDIT', 190.0000, 10.0000, 5.0000, 200.0000, 50.0000, N'COMPLETED');
    SET @SaleID = SCOPE_IDENTITY();

    INSERT INTO dbo.sale_items (sale_id, product_id, quantity, unit_price, discount_rate, tax_amount, line_total, is_returned, returned_qty)
    VALUES (@SaleID, @P1, 2, 100.0000, 0.1000, 5.0000, 185.0000, 0, 0);
    INSERT INTO dbo.sale_items (sale_id, product_id, quantity, unit_price, discount_rate, tax_amount, line_total, is_returned, returned_qty)
    VALUES (@SaleID, @P2, 1, 25.0000, 0.0000, 0.0000, 25.0000, 0, 0);

    INSERT INTO dbo.credit_sales (sale_id, customer_id, total_amount, amount_paid, outstanding_balance, due_date, [status])
    VALUES (@SaleID, @CustID, 200.0000, 50.0000, 150.0000, DATEADD(day, 30, CAST(SYSUTCDATETIME() AS DATE)), N'PARTIAL');

    -- Supporting ledger rows so the report/dashboard views return data:
    -- (a) inventory movement for P1
    INSERT INTO dbo.inventory_transactions (product_id, movement_type, quantity, quantity_before, quantity_after, unit_cost, reference_type, user_id)
    VALUES (@P1, N'RESTOCK', 5, 0, 5, 5.0000, N'PurchaseOrder', @AdminID);
    -- (b) a return + return item against the fixture sale
    DECLARE @Rid INT;
    INSERT INTO dbo.returns (return_number, sale_id, customer_id, user_id, [status], total_refund_amount)
    VALUES (N'VW-RET-0001', @SaleID, @CustID, @AdminID, N'COMPLETED', 100.0000);
    SET @Rid = SCOPE_IDENTITY();
    DECLARE @Sitem INT = (SELECT TOP (1) sale_item_id FROM dbo.sale_items WHERE sale_id = @SaleID AND product_id = @P1);
    INSERT INTO dbo.return_items (return_id, sale_item_id, product_id, quantity, unit_price, refund_amount)
    VALUES (@Rid, @Sitem, @P1, 1, 100.0000, 100.0000);
    -- (c) a low-stock notification for the admin
    DECLARE @NotifType INT = (SELECT TOP (1) notification_type_id FROM dbo.notification_types WHERE type_code = N'LOW_STOCK');
    INSERT INTO dbo.notifications (user_id, notification_type_id, title, [message], severity)
    VALUES (@AdminID, @NotifType, N'Low Stock Alert', N'Fixture notification for view test', N'WARNING');
    -- (d) a completed payment for the fixture sale
    INSERT INTO dbo.payments (sale_id, payment_method_id, amount, received_by, pay_status)
    SELECT @SaleID, pm.payment_method_id, 50.0000, @AdminID, N'COMPLETED'
    FROM dbo.payment_methods pm
    WHERE pm.method_code = N'CASH';

    -- ======================================================================
    -- 04.01 VW_UserPermissions - effective permission rows for admin
    -- ======================================================================
    IF NOT EXISTS (SELECT 1 FROM dbo.VW_UserPermissions WHERE user_id = @AdminID)
        THROW 64001, N'Test FAILED: 04.01 VW_UserPermissions - admin has no permission rows.', 1;
    IF NOT EXISTS (SELECT 1 FROM dbo.VW_UserPermissions WHERE user_id = @AdminID AND permission_code = N'products.view')
        THROW 64001, N'Test FAILED: 04.01 VW_UserPermissions - admin missing products.view.', 1;
    IF EXISTS (SELECT 1 FROM dbo.VW_UserPermissions WHERE permission_code IS NULL OR user_id IS NULL)
        THROW 64001, N'Test FAILED: 04.01 VW_UserPermissions - NULL key columns present.', 1;

    -- ======================================================================
    -- 04.02 VW_ProductStock - stock snapshot + status classification
    -- ======================================================================
    IF (SELECT quantity_on_hand FROM dbo.VW_ProductStock WHERE product_id = @P1) <> 5
        THROW 64002, N'Test FAILED: 04.02 VW_ProductStock - P1 quantity mismatch.', 1;
    IF (SELECT stock_status FROM dbo.VW_ProductStock WHERE product_id = @P1) <> N'LOW_STOCK'
        THROW 64002, N'Test FAILED: 04.02 VW_ProductStock - P1 expected LOW_STOCK.', 1;
    IF (SELECT stock_status FROM dbo.VW_ProductStock WHERE product_id = @P2) <> N'IN_STOCK'
        THROW 64002, N'Test FAILED: 04.02 VW_ProductStock - P2 expected IN_STOCK.', 1;
    IF (SELECT category_name FROM dbo.VW_ProductStock WHERE product_id = @P1) <> N'ViewTest Category'
        THROW 64002, N'Test FAILED: 04.02 VW_ProductStock - category join broken.', 1;
    IF (SELECT supplier_name FROM dbo.VW_ProductStock WHERE product_id = @P1) <> N'ViewTest Supplier'
        THROW 64002, N'Test FAILED: 04.02 VW_ProductStock - supplier join broken.', 1;

    -- ======================================================================
    -- 04.03 VW_LowStock - only products at/below threshold
    -- ======================================================================
    IF NOT EXISTS (SELECT 1 FROM dbo.VW_LowStock WHERE product_id = @P1)
        THROW 64003, N'Test FAILED: 04.03 VW_LowStock - P1 (5<=10) missing.', 1;
    IF EXISTS (SELECT 1 FROM dbo.VW_LowStock WHERE product_id = @P2)
        THROW 64003, N'Test FAILED: 04.03 VW_LowStock - P2 (50>10) should not appear.', 1;
    IF (SELECT stock_status FROM dbo.VW_LowStock WHERE product_id = @P1) <> N'LOW_STOCK'
        THROW 64003, N'Test FAILED: 04.03 VW_LowStock - status column wrong.', 1;

    -- ======================================================================
    -- 04.04 VW_SalesWithLines - denormalized header + items
    -- ======================================================================
    SELECT @Rc = COUNT(*) FROM dbo.VW_SalesWithLines WHERE sale_id = @SaleID;
    IF @Rc <> 2
        THROW 64004, N'Test FAILED: 04.04 VW_SalesWithLines - expected 2 line rows.', 1;
    IF (SELECT TOP (1) cashier_name FROM dbo.VW_SalesWithLines WHERE sale_id = @SaleID) IS NULL
        THROW 64004, N'Test FAILED: 04.04 VW_SalesWithLines - cashier join broken.', 1;
    IF (SELECT TOP (1) customer_name FROM dbo.VW_SalesWithLines WHERE sale_id = @SaleID) <> N'View Test Customer'
        THROW 64004, N'Test FAILED: 04.04 VW_SalesWithLines - customer join broken.', 1;
    IF NOT EXISTS (SELECT 1 FROM dbo.VW_SalesWithLines WHERE sale_id = @SaleID AND sku = N'VWSKU-LOW' AND quantity = 2)
        THROW 64004, N'Test FAILED: 04.04 VW_SalesWithLines - item data wrong.', 1;

    -- ======================================================================
    -- 04.05 VW_CustomerBalances - outstanding credit ledger
    -- ======================================================================
    IF NOT EXISTS (SELECT 1 FROM dbo.VW_CustomerBalances WHERE sale_id = @SaleID AND outstanding_balance = 150.0000)
        THROW 64005, N'Test FAILED: 04.05 VW_CustomerBalances - outstanding balance wrong.', 1;
    IF (SELECT customer_name FROM dbo.VW_CustomerBalances WHERE sale_id = @SaleID) <> N'View Test Customer'
        THROW 64005, N'Test FAILED: 04.05 VW_CustomerBalances - customer join broken.', 1;
    IF (SELECT [status] FROM dbo.VW_CustomerBalances WHERE sale_id = @SaleID) <> N'PARTIAL'
        THROW 64005, N'Test FAILED: 04.05 VW_CustomerBalances - status wrong.', 1;

    -- ======================================================================
    -- 04.06-04.12 Report + dashboard views - existence + smoke query
    -- ======================================================================
    IF OBJECT_ID(N'dbo.VW_SalesSummary', N'V') IS NULL
        THROW 64010, N'Test FAILED: 04.06 VW_SalesSummary does not exist.', 1;
    IF OBJECT_ID(N'dbo.VW_DailySales', N'V') IS NULL
        THROW 64010, N'Test FAILED: 04.07 VW_DailySales does not exist.', 1;
    IF OBJECT_ID(N'dbo.VW_ProductSalesReport', N'V') IS NULL
        THROW 64010, N'Test FAILED: 04.08 VW_ProductSalesReport does not exist.', 1;
    IF OBJECT_ID(N'dbo.VW_InventoryReport', N'V') IS NULL
        THROW 64010, N'Test FAILED: 04.09 VW_InventoryReport does not exist.', 1;
    IF OBJECT_ID(N'dbo.VW_InventoryMovementsReport', N'V') IS NULL
        THROW 64010, N'Test FAILED: 04.10 VW_InventoryMovementsReport does not exist.', 1;
    IF OBJECT_ID(N'dbo.VW_SupplierReport', N'V') IS NULL
        THROW 64010, N'Test FAILED: 04.11 VW_SupplierReport does not exist.', 1;
    IF OBJECT_ID(N'dbo.VW_CreditReport', N'V') IS NULL
        THROW 64010, N'Test FAILED: 04.12 VW_CreditReport does not exist.', 1;
    IF OBJECT_ID(N'dbo.VW_ReturnsReport', N'V') IS NULL
        THROW 64010, N'Test FAILED: 04.13 VW_ReturnsReport does not exist.', 1;
    IF OBJECT_ID(N'dbo.VW_ProfitReport', N'V') IS NULL
        THROW 64010, N'Test FAILED: 04.14 VW_ProfitReport does not exist.', 1;
    IF OBJECT_ID(N'dbo.VW_PaymentMethodsReport', N'V') IS NULL
        THROW 64010, N'Test FAILED: 04.15 VW_PaymentMethodsReport does not exist.', 1;
    IF OBJECT_ID(N'dbo.VW_TaxReport', N'V') IS NULL
        THROW 64010, N'Test FAILED: 04.16 VW_TaxReport does not exist.', 1;
    IF OBJECT_ID(N'dbo.VW_DashboardKPIs', N'V') IS NULL
        THROW 64010, N'Test FAILED: 04.17 VW_DashboardKPIs does not exist.', 1;
    IF OBJECT_ID(N'dbo.VW_RecentSales', N'V') IS NULL
        THROW 64010, N'Test FAILED: 04.18 VW_RecentSales does not exist.', 1;
    IF OBJECT_ID(N'dbo.VW_TopProducts', N'V') IS NULL
        THROW 64010, N'Test FAILED: 04.19 VW_TopProducts does not exist.', 1;
    IF OBJECT_ID(N'dbo.VW_SalesTrend7d', N'V') IS NULL
        THROW 64010, N'Test FAILED: 04.20 VW_SalesTrend7d does not exist.', 1;
    IF OBJECT_ID(N'dbo.VW_SalesByCategory', N'V') IS NULL
        THROW 64010, N'Test FAILED: 04.21 VW_SalesByCategory does not exist.', 1;
    IF OBJECT_ID(N'dbo.VW_SalesByPaymentMethod', N'V') IS NULL
        THROW 64010, N'Test FAILED: 04.22 VW_SalesByPaymentMethod does not exist.', 1;
    IF OBJECT_ID(N'dbo.VW_RecentNotifications', N'V') IS NULL
        THROW 64010, N'Test FAILED: 04.23 VW_RecentNotifications does not exist.', 1;
    IF OBJECT_ID(N'dbo.VW_OutstandingCredit', N'V') IS NULL
        THROW 64010, N'Test FAILED: 04.24 VW_OutstandingCredit does not exist.', 1;

    -- Every view must execute without error and expose at least a key column.
    IF NOT EXISTS (SELECT TOP (1) 1 FROM dbo.VW_SalesSummary)
        THROW 64011, N'Test FAILED: 04.06 VW_SalesSummary smoke - no rows (check seed data).', 1;
    IF NOT EXISTS (SELECT TOP (1) 1 FROM dbo.VW_DailySales)
        THROW 64011, N'Test FAILED: 04.07 VW_DailySales smoke - no rows.', 1;
    IF NOT EXISTS (SELECT TOP (1) 1 FROM dbo.VW_ProductSalesReport)
        THROW 64011, N'Test FAILED: 04.08 VW_ProductSalesReport smoke - no rows.', 1;
    IF NOT EXISTS (SELECT TOP (1) 1 FROM dbo.VW_InventoryReport)
        THROW 64011, N'Test FAILED: 04.09 VW_InventoryReport smoke - no rows.', 1;
    IF NOT EXISTS (SELECT TOP (1) 1 FROM dbo.VW_InventoryMovementsReport)
        THROW 64011, N'Test FAILED: 04.10 VW_InventoryMovementsReport smoke - no rows.', 1;
    IF NOT EXISTS (SELECT TOP (1) 1 FROM dbo.VW_SupplierReport)
        THROW 64011, N'Test FAILED: 04.11 VW_SupplierReport smoke - no rows.', 1;
    IF NOT EXISTS (SELECT TOP (1) 1 FROM dbo.VW_CreditReport)
        THROW 64011, N'Test FAILED: 04.12 VW_CreditReport smoke - no rows.', 1;
    IF NOT EXISTS (SELECT TOP (1) 1 FROM dbo.VW_ReturnsReport)
        THROW 64011, N'Test FAILED: 04.13 VW_ReturnsReport smoke - no rows.', 1;
    IF NOT EXISTS (SELECT TOP (1) 1 FROM dbo.VW_ProfitReport)
        THROW 64011, N'Test FAILED: 04.14 VW_ProfitReport smoke - no rows.', 1;
    IF NOT EXISTS (SELECT TOP (1) 1 FROM dbo.VW_PaymentMethodsReport)
        THROW 64011, N'Test FAILED: 04.15 VW_PaymentMethodsReport smoke - no rows.', 1;
    IF NOT EXISTS (SELECT TOP (1) 1 FROM dbo.VW_TaxReport)
        THROW 64011, N'Test FAILED: 04.16 VW_TaxReport smoke - no rows.', 1;
    IF NOT EXISTS (SELECT TOP (1) 1 FROM dbo.VW_DashboardKPIs)
        THROW 64011, N'Test FAILED: 04.17 VW_DashboardKPIs smoke - no rows.', 1;
    IF NOT EXISTS (SELECT TOP (1) 1 FROM dbo.VW_RecentSales)
        THROW 64011, N'Test FAILED: 04.18 VW_RecentSales smoke - no rows.', 1;
    IF NOT EXISTS (SELECT TOP (1) 1 FROM dbo.VW_RecentNotifications)
        THROW 64011, N'Test FAILED: 04.23 VW_RecentNotifications smoke - no rows.', 1;
    IF NOT EXISTS (SELECT TOP (1) 1 FROM dbo.VW_OutstandingCredit)
        THROW 64011, N'Test FAILED: 04.24 VW_OutstandingCredit smoke - no rows.', 1;

    -- Views without guaranteed rows must still execute without error:
    SELECT COUNT(*) FROM dbo.VW_TopProducts;
    SELECT COUNT(*) FROM dbo.VW_SalesTrend7d;
    SELECT COUNT(*) FROM dbo.VW_SalesByCategory;
    SELECT COUNT(*) FROM dbo.VW_SalesByPaymentMethod;

END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    THROW 64099, N'Test FAILED: 04_views - ' + ERROR_MESSAGE(), 1;
END CATCH;

/* ---------------------------------------------------------------------------
   FILE CLEANUP: roll back the entire run (non-destructive guarantee)
--------------------------------------------------------------------------- */
IF XACT_STATE() <> 0
    ROLLBACK TRANSACTION;

PRINT N'Test PASSED: 04_views_all';
