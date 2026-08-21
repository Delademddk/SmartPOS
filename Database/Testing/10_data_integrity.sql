/* ==========================================================================
   SmartPOS Database - TEST SUITE 10: DATA INTEGRITY
   --------------------------------------------------------------------------
   Verifies the referential and check-constraint layer:
     1) catalog-level: expected FOREIGN KEY and CHECK constraints exist
     2) behavioural:   inserting violating rows is rejected at the engine

   HARNESS: a small fixture is created and rolled back at the end.
   Success -> PRINT N'Test PASSED: <name>'
   Failure -> THROW <code>, N'Test FAILED: <name>: <detail>', 1
   ========================================================================== */

SET NOCOUNT ON;

/* ---------------------------------------------------------------------------
   10.01 - Every expected FOREIGN KEY constraint exists
--------------------------------------------------------------------------- */
CREATE TABLE #fks (name NVARCHAR(200));
INSERT INTO #fks VALUES
    (N'FK_users_roles'), (N'FK_user_sessions_users'), (N'FK_password_history_users'),
    (N'FK_role_permissions_roles'), (N'FK_role_permissions_permissions'),
    (N'FK_categories_parent'), (N'FK_categories_created_by'), (N'FK_categories_deleted_by'),
    (N'FK_products_categories'), (N'FK_products_suppliers'), (N'FK_products_created_by'), (N'FK_products_deleted_by'),
    (N'FK_product_images_products'),
    (N'FK_suppliers_created_by'), (N'FK_suppliers_deleted_by'),
    (N'FK_supplier_contacts_suppliers'), (N'FK_supplier_history_suppliers'), (N'FK_supplier_history_users'),
    (N'FK_inventory_products'), (N'FK_inventory_transactions_products'), (N'FK_inventory_transactions_users'),
    (N'FK_stock_reconciliations_products'), (N'FK_stock_reconciliations_users'), (N'FK_stock_reconciliations_txn'),
    (N'FK_low_stock_alerts_products'),
    (N'FK_sales_users'), (N'FK_sales_tax_rates'), (N'FK_sale_items_sales'), (N'FK_sale_items_products'),
    (N'FK_payments_sales'), (N'FK_payments_payment_methods'), (N'FK_payments_users'),
    (N'FK_receipts_sales'), (N'FK_receipts_users'),
    (N'FK_customers_created_by'), (N'FK_credit_sales_sales'), (N'FK_credit_sales_customers'),
    (N'FK_credit_payments_credit_sales'), (N'FK_credit_payments_payments'), (N'FK_credit_payments_users'),
    (N'FK_returns_sales'), (N'FK_returns_customers'), (N'FK_returns_users'), (N'FK_returns_reasons'),
    (N'FK_return_items_returns'), (N'FK_return_items_sale_items'), (N'FK_return_items_products'),
    (N'FK_notifications_users'), (N'FK_notifications_types'),
    (N'FK_notification_history_users'), (N'FK_notification_history_types'),
    (N'FK_user_settings_users'),
    (N'FK_audit_logs_users'), (N'FK_activity_logs_users'), (N'FK_error_logs_users'), (N'FK_security_logs_users');

DECLARE @MissingFK INT = (
    SELECT COUNT(*) FROM #fks f
    LEFT JOIN sys.foreign_keys k ON k.name = f.name
    WHERE k.object_id IS NULL
);
IF @MissingFK <> 0
    THROW 61001, N'Test FAILED: 10.01 fk - one or more expected foreign keys are missing.', 1;

/* ---------------------------------------------------------------------------
   10.02 - Every expected CHECK constraint exists
--------------------------------------------------------------------------- */
CREATE TABLE #cks (name NVARCHAR(200));
INSERT INTO #cks VALUES
    (N'CK_users_username_min_length'), (N'CK_users_email_format'),
    (N'CK_user_sessions_expiry_after_issue'),
    (N'CK_roles_role_code_format'),
    (N'CK_products_unit_price_non_negative'), (N'CK_products_cost_price_non_negative'),
    (N'CK_products_low_stock_non_negative'),
    (N'CK_categories_not_self_parent'),
    (N'CK_inventory_quantity_non_negative'), (N'CK_inventory_reserved_non_negative'),
    (N'CK_inventory_transactions_movement_type_upper'), (N'CK_low_stock_alerts_status'),
    (N'CK_sales_status'), (N'CK_sales_type'), (N'CK_sales_total_non_negative'), (N'CK_sales_discount_non_negative'),
    (N'CK_sale_items_qty_positive'), (N'CK_sale_items_unit_price_non_negative'),
    (N'CK_sale_items_discount_rate'), (N'CK_sale_items_returned_not_exceed'),
    (N'CK_payments_amount_positive'), (N'CK_payments_status'),
    (N'CK_credit_sales_balance_non_negative'), (N'CK_credit_sales_paid_non_negative'), (N'CK_credit_sales_status'),
    (N'CK_customers_credit_limit_non_negative'), (N'CK_credit_payments_amount_positive'),
    (N'CK_returns_status'), (N'CK_returns_refund_non_negative'),
    (N'CK_return_items_qty_positive'), (N'CK_return_items_refund_non_negative'),
    (N'CK_notifications_severity'), (N'CK_notification_types_code_upper'),
    (N'CK_settings_data_type');

DECLARE @MissingCK INT = (
    SELECT COUNT(*) FROM #cks c
    LEFT JOIN sys.check_constraints cc ON cc.name = c.name
    WHERE cc.object_id IS NULL
);
IF @MissingCK <> 0
    THROW 61002, N'Test FAILED: 10.02 ck - one or more expected check constraints are missing.', 1;

/* ---------------------------------------------------------------------------
   10.03 - Behavioural enforcement (constraint violations are rejected)
--------------------------------------------------------------------------- */
DECLARE @AdminID INT = (SELECT TOP (1) user_id FROM dbo.users WHERE username = N'admin');
DECLARE @RoleCash INT = (SELECT TOP (1) role_id FROM dbo.roles WHERE role_code = N'CASHIER');
DECLARE @CatID INT, @ProdID INT;

BEGIN TRANSACTION;

BEGIN TRY

    INSERT INTO dbo.categories (category_name, is_active, is_deleted, created_by)
    VALUES (N'Integrity Cat', 1, 0, @AdminID);
    SET @CatID = SCOPE_IDENTITY();

    INSERT INTO dbo.products (sku, product_name, unit_price, category_id, low_stock_threshold, created_by)
    VALUES (N'INT-SKU', N'Integrity Product', 10.0000, @CatID, 5, @AdminID);
    SET @ProdID = SCOPE_IDENTITY();

    /* --- 10.03.1 FK_sale_items_products rejects unknown product --------- */
    BEGIN TRY
        INSERT INTO dbo.sale_items (sale_id, product_id, quantity, unit_price, line_total)
        VALUES (2147483647, 2147483647, 1, 1.00, 1.00);
        THROW 61003, N'FK violation (unknown product) accepted.', 1;
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() NOT IN (547, 35100) THROW;
    END CATCH;

    /* --- 10.03.2 CK_sales_status rejects an invalid status --------------- */
    BEGIN TRY
        INSERT INTO dbo.sales (receipt_number, user_id, [status])
        VALUES (N'INT-BAD-STATUS', @AdminID, N'CANCELLED');
        THROW 61003, N'Invalid sale status accepted.', 1;
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() NOT IN (547, 35100) THROW;
    END CATCH;

    /* --- 10.03.3 UQ_products_sku rejects duplicate SKUs ------------------ */
    BEGIN TRY
        INSERT INTO dbo.products (sku, product_name, unit_price, low_stock_threshold)
        VALUES (N'INT-SKU', N'Duplicate', 1.00, 5);
        THROW 61003, N'Duplicate SKU accepted.', 1;
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() NOT IN (2627, 2601, 35100) THROW;
    END CATCH;

    /* --- 10.03.4 CK_inventory_quantity_non_negative --------------------- */
    BEGIN TRY
        INSERT INTO dbo.inventory (product_id, quantity_on_hand)
        VALUES (@ProdID, -1);
        THROW 61003, N'Negative stock accepted.', 1;
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() NOT IN (547, 35100) THROW;
    END CATCH;

    /* --- 10.03.5 CK_credit_sales_balance_non_negative ------------------- */
    BEGIN TRY
        INSERT INTO dbo.sales (receipt_number, user_id, sale_type, total_amount, [status])
        VALUES (N'INT-CR-1', @AdminID, N'CREDIT', 10.00, N'COMPLETED');
        DECLARE @SaleCr INT = SCOPE_IDENTITY();
        INSERT INTO dbo.customers (customer_code, full_name, credit_limit, created_by)
        VALUES (N'INT-CUST', N'Integrity Customer', 100.00, @AdminID);
        DECLARE @Cust INT = SCOPE_IDENTITY();
        INSERT INTO dbo.credit_sales (sale_id, customer_id, total_amount, amount_paid, outstanding_balance, [status])
        VALUES (@SaleCr, @Cust, 10.00, 0, -1.00, N'OPEN');
        THROW 61003, N'Negative credit balance accepted.', 1;
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() NOT IN (547, 35100) THROW;
    END CATCH;

    /* --- 10.03.6 CK_payments_amount_positive ---------------------------- */
    BEGIN TRY
        INSERT INTO dbo.sales (receipt_number, user_id, total_amount, [status])
        VALUES (N'INT-PAY-1', @AdminID, 10.00, N'COMPLETED');
        DECLARE @SaleP INT = SCOPE_IDENTITY();
        DECLARE @Cash INT = (SELECT TOP (1) payment_method_id FROM dbo.payment_methods WHERE method_code = N'CASH');
        INSERT INTO dbo.payments (sale_id, payment_method_id, amount)
        VALUES (@SaleP, @Cash, 0);
        THROW 61003, N'Zero-amount payment accepted.', 1;
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() NOT IN (547, 35100) THROW;
    END CATCH;

    /* --- 10.03.7 UQ_user_sessions_token rejects duplicate tokens --------- */
    BEGIN TRY
        INSERT INTO dbo.user_sessions (user_id, session_token, issued_at, expires_at)
        VALUES (@AdminID, N'DUP-TOKEN', SYSUTCDATETIME(), DATEADD(minute, 60, SYSUTCDATETIME()));
        INSERT INTO dbo.user_sessions (user_id, session_token, issued_at, expires_at)
        VALUES (@AdminID, N'DUP-TOKEN', SYSUTCDATETIME(), DATEADD(minute, 60, SYSUTCDATETIME()));
        THROW 61003, N'Duplicate session token accepted.', 1;
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() NOT IN (2627, 2601, 35100) THROW;
    END CATCH;

    /* --- 10.03.8 CK_returns_status rejects an invalid status ------------- */
    BEGIN TRY
        INSERT INTO dbo.sales (receipt_number, user_id, total_amount, [status])
        VALUES (N'INT-RET-1', @AdminID, 10.00, N'COMPLETED');
        DECLARE @SaleR INT = SCOPE_IDENTITY();
        INSERT INTO dbo.returns (return_number, sale_id, user_id, [status], total_refund_amount)
        VALUES (N'INT-RET-BAD', @SaleR, @AdminID, N'DELETED', 0);
        THROW 61003, N'Invalid return status accepted.', 1;
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() NOT IN (547, 35100) THROW;
    END CATCH;

END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    THROW 61099, N'Test FAILED: 10_data_integrity - ' + ERROR_MESSAGE(), 1;
END CATCH;

/* ---------------------------------------------------------------------------
   FILE CLEANUP: roll back the entire run
--------------------------------------------------------------------------- */
IF XACT_STATE() <> 0
    ROLLBACK TRANSACTION;

PRINT N'Test PASSED: 10_data_integrity_all';
