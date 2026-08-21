/* ==========================================================================
   SmartPOS Database - TEST SUITE 01: CONSTRAINT ENFORCEMENT
   --------------------------------------------------------------------------
   Verifies that the database enforces its declarative integrity rules:
     - required CHECK / UNIQUE / FK constraints are present
     - violating writes are rejected (CHECK -> 547, UNIQUE -> 2601/2627,
       FK -> 547)

   HARNESS
     - Every test runs inside ONE outer transaction; per-test SAVEPOINTs
       (SAVE TRANSACTION) undo only the violating statement, and the whole
       file rolls back at the end -> fully non-destructive.
     - XACT_ABORT is OFF so a 547/2601/2627 statement error leaves the outer
       transaction committable and rollback-to-savepoint works.
     - Success  -> PRINT N'Test PASSED: <name>'
     - Failure  -> THROW <code>, N'Test FAILED: <name>: <detail>', 1
     - Run with sqlcmd ... -b so a failure yields a non-zero exit code.
   ========================================================================== */

SET NOCOUNT ON;
SET XACT_ABORT OFF;

BEGIN TRANSACTION;

DECLARE @Msg NVARCHAR(4000);

/* ---------------------------------------------------------------------------
   TEST 01.01 - Required CHECK constraints exist
--------------------------------------------------------------------------- */
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_users_email_format'        AND OBJECT_SCHEMA_NAME(parent_object_id) = N'dbo')
    THROW 61001, N'Test FAILED: 01.01 check_constraints_present - CK_users_email_format missing.', 1;
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_users_username_min_length' AND OBJECT_SCHEMA_NAME(parent_object_id) = N'dbo')
    THROW 61002, N'Test FAILED: 01.01 check_constraints_present - CK_users_username_min_length missing.', 1;
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_products_unit_price_non_negative' AND OBJECT_SCHEMA_NAME(parent_object_id) = N'dbo')
    THROW 61003, N'Test FAILED: 01.01 check_constraints_present - CK_products_unit_price_non_negative missing.', 1;
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_sale_items_qty_positive'    AND OBJECT_SCHEMA_NAME(parent_object_id) = N'dbo')
    THROW 61004, N'Test FAILED: 01.01 check_constraints_present - CK_sale_items_qty_positive missing.', 1;
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_sale_items_discount_rate'   AND OBJECT_SCHEMA_NAME(parent_object_id) = N'dbo')
    THROW 61005, N'Test FAILED: 01.01 check_constraints_present - CK_sale_items_discount_rate missing.', 1;
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_sales_status'               AND OBJECT_SCHEMA_NAME(parent_object_id) = N'dbo')
    THROW 61006, N'Test FAILED: 01.01 check_constraints_present - CK_sales_status missing.', 1;
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_categories_not_self_parent' AND OBJECT_SCHEMA_NAME(parent_object_id) = N'dbo')
    THROW 61007, N'Test FAILED: 01.01 check_constraints_present - CK_categories_not_self_parent missing.', 1;
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_inventory_quantity_non_negative' AND OBJECT_SCHEMA_NAME(parent_object_id) = N'dbo')
    THROW 61008, N'Test FAILED: 01.01 check_constraints_present - CK_inventory_quantity_non_negative missing.', 1;
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_settings_data_type'        AND OBJECT_SCHEMA_NAME(parent_object_id) = N'dbo')
    THROW 61009, N'Test FAILED: 01.01 check_constraints_present - CK_settings_data_type missing.', 1;
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_notifications_severity'    AND OBJECT_SCHEMA_NAME(parent_object_id) = N'dbo')
    THROW 61010, N'Test FAILED: 01.01 check_constraints_present - CK_notifications_severity missing.', 1;
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_credit_sales_balance_non_negative' AND OBJECT_SCHEMA_NAME(parent_object_id) = N'dbo')
    THROW 61011, N'Test FAILED: 01.01 check_constraints_present - CK_credit_sales_balance_non_negative missing.', 1;

PRINT N'Test PASSED: 01.01 check_constraints_present';

/* ---------------------------------------------------------------------------
   TEST 01.02 - Required UNIQUE constraints exist
--------------------------------------------------------------------------- */
IF NOT EXISTS (SELECT 1 FROM sys.key_constraints WHERE name = N'UQ_users_username'           AND OBJECT_SCHEMA_NAME(parent_object_id) = N'dbo')
    THROW 61012, N'Test FAILED: 01.02 unique_constraints_present - UQ_users_username missing.', 1;
IF NOT EXISTS (SELECT 1 FROM sys.key_constraints WHERE name = N'UQ_users_email'              AND OBJECT_SCHEMA_NAME(parent_object_id) = N'dbo')
    THROW 61013, N'Test FAILED: 01.02 unique_constraints_present - UQ_users_email missing.', 1;
IF NOT EXISTS (SELECT 1 FROM sys.key_constraints WHERE name = N'UQ_roles_role_code'          AND OBJECT_SCHEMA_NAME(parent_object_id) = N'dbo')
    THROW 61014, N'Test FAILED: 01.02 unique_constraints_present - UQ_roles_role_code missing.', 1;
IF NOT EXISTS (SELECT 1 FROM sys.key_constraints WHERE name = N'UQ_categories_parent_name'   AND OBJECT_SCHEMA_NAME(parent_object_id) = N'dbo')
    THROW 61015, N'Test FAILED: 01.02 unique_constraints_present - UQ_categories_parent_name missing.', 1;
IF NOT EXISTS (SELECT 1 FROM sys.key_constraints WHERE name = N'UQ_payment_methods_code'     AND OBJECT_SCHEMA_NAME(parent_object_id) = N'dbo')
    THROW 61016, N'Test FAILED: 01.02 unique_constraints_present - UQ_payment_methods_code missing.', 1;
IF NOT EXISTS (SELECT 1 FROM sys.key_constraints WHERE name = N'UQ_sales_receipt_number'     AND OBJECT_SCHEMA_NAME(parent_object_id) = N'dbo')
    THROW 61017, N'Test FAILED: 01.02 unique_constraints_present - UQ_sales_receipt_number missing.', 1;

PRINT N'Test PASSED: 01.02 unique_constraints_present';

/* ---------------------------------------------------------------------------
   TEST 01.03 - users.email format CHECK (bad email -> 547)
--------------------------------------------------------------------------- */
SAVE TRANSACTION t01_03;
BEGIN TRY
    INSERT INTO dbo.users (username, email, password_hash, full_name, role_id)
    VALUES (N'test_bad_email', N'not-an-email', N'hash', N'Bad Email', 1);
    ROLLBACK TRANSACTION t01_03;
    THROW 61020, N'Test FAILED: 01.03 users_email_format - invalid email was accepted.', 1;
END TRY
BEGIN CATCH
    DECLARE @e0103 INT = ERROR_NUMBER();
    ROLLBACK TRANSACTION t01_03;
    IF @e0103 <> 547
        THROW 61021, N'Test FAILED: 01.03 users_email_format - expected 547, got ' + CAST(@e0103 AS NVARCHAR(10)) + N'.', 1;
END CATCH
PRINT N'Test PASSED: 01.03 users_email_format';

/* ---------------------------------------------------------------------------
   TEST 01.04 - users.username minimum length (short -> 547)
--------------------------------------------------------------------------- */
SAVE TRANSACTION t01_04;
BEGIN TRY
    INSERT INTO dbo.users (username, email, password_hash, full_name, role_id)
    VALUES (N'ab', N'ab@example.com', N'hash', N'Short Name', 1);
    ROLLBACK TRANSACTION t01_04;
    THROW 61022, N'Test FAILED: 01.04 users_username_length - short username was accepted.', 1;
END TRY
BEGIN CATCH
    DECLARE @e0104 INT = ERROR_NUMBER();
    ROLLBACK TRANSACTION t01_04;
    IF @e0104 <> 547
        THROW 61023, N'Test FAILED: 01.04 users_username_length - expected 547, got ' + CAST(@e0104 AS NVARCHAR(10)) + N'.', 1;
END CATCH
PRINT N'Test PASSED: 01.04 users_username_length';

/* ---------------------------------------------------------------------------
   TEST 01.05 - users.username UNIQUE (duplicate -> 2601/2627)
--------------------------------------------------------------------------- */
IF NOT EXISTS (SELECT 1 FROM dbo.users WHERE username = N'admin')
    THROW 61024, N'Test FAILED: 01.05 users_username_unique - prerequisite admin user missing.', 1;

SAVE TRANSACTION t01_05;
BEGIN TRY
    INSERT INTO dbo.users (username, email, password_hash, full_name, role_id)
    SELECT N'admin', N'dupe-admin@example.com', N'hash', N'Dupe Admin', role_id
    FROM dbo.users WHERE username = N'admin';
    ROLLBACK TRANSACTION t01_05;
    THROW 61025, N'Test FAILED: 01.05 users_username_unique - duplicate username was accepted.', 1;
END TRY
BEGIN CATCH
    DECLARE @e0105 INT = ERROR_NUMBER();
    ROLLBACK TRANSACTION t01_05;
    IF @e0105 NOT IN (2601, 2627)
        THROW 61026, N'Test FAILED: 01.05 users_username_unique - expected 2601/2627, got ' + CAST(@e0105 AS NVARCHAR(10)) + N'.', 1;
END CATCH
PRINT N'Test PASSED: 01.05 users_username_unique';

/* ---------------------------------------------------------------------------
   TEST 01.06 - roles.role_code UNIQUE (duplicate -> 2601/2627)
--------------------------------------------------------------------------- */
SAVE TRANSACTION t01_06;
BEGIN TRY
    INSERT INTO dbo.roles (role_code, role_name, is_system, is_active)
    SELECT role_code, N'Dupe ' + role_name, 0, 1 FROM dbo.roles WHERE role_code = N'ADMIN';
    ROLLBACK TRANSACTION t01_06;
    THROW 61027, N'Test FAILED: 01.06 roles_code_unique - duplicate role code was accepted.', 1;
END TRY
BEGIN CATCH
    DECLARE @e0106 INT = ERROR_NUMBER();
    ROLLBACK TRANSACTION t01_06;
    IF @e0106 NOT IN (2601, 2627)
        THROW 61028, N'Test FAILED: 01.06 roles_code_unique - expected 2601/2627, got ' + CAST(@e0106 AS NVARCHAR(10)) + N'.', 1;
END CATCH
PRINT N'Test PASSED: 01.06 roles_code_unique';

/* ---------------------------------------------------------------------------
   TEST 01.07 - products.unit_price non-negative (negative -> 547)
--------------------------------------------------------------------------- */
SAVE TRANSACTION t01_07;
BEGIN TRY
    INSERT INTO dbo.products (sku, product_name, unit_price, is_active, is_deleted)
    VALUES (N'TEST-NEG-PRICE', N'Negative Price Item', -5.00, 1, 0);
    ROLLBACK TRANSACTION t01_07;
    THROW 61029, N'Test FAILED: 01.07 products_price_non_negative - negative price was accepted.', 1;
END TRY
BEGIN CATCH
    DECLARE @e0107 INT = ERROR_NUMBER();
    ROLLBACK TRANSACTION t01_07;
    IF @e0107 <> 547
        THROW 61030, N'Test FAILED: 01.07 products_price_non_negative - expected 547, got ' + CAST(@e0107 AS NVARCHAR(10)) + N'.', 1;
END CATCH
PRINT N'Test PASSED: 01.07 products_price_non_negative';

/* ---------------------------------------------------------------------------
   TEST 01.08 - sale_items.quantity positive (zero -> 547)
--------------------------------------------------------------------------- */
SAVE TRANSACTION t01_08;
BEGIN TRY
    INSERT INTO dbo.sale_items (sale_id, product_id, quantity, unit_price, line_total)
    VALUES (1, 1, 0, 1.00, 0.00);
    ROLLBACK TRANSACTION t01_08;
    THROW 61031, N'Test FAILED: 01.08 sale_items_qty_positive - zero quantity was accepted.', 1;
END TRY
BEGIN CATCH
    DECLARE @e0108 INT = ERROR_NUMBER();
    ROLLBACK TRANSACTION t01_08;
    IF @e0108 NOT IN (547, 515)
        THROW 61032, N'Test FAILED: 01.08 sale_items_qty_positive - expected 547/515, got ' + CAST(@e0108 AS NVARCHAR(10)) + N'.', 1;
END CATCH
PRINT N'Test PASSED: 01.08 sale_items_qty_positive';

/* ---------------------------------------------------------------------------
   TEST 01.09 - sale_items.discount_rate range (out-of-range -> 547)
--------------------------------------------------------------------------- */
SAVE TRANSACTION t01_09;
BEGIN TRY
    INSERT INTO dbo.sale_items (sale_id, product_id, quantity, unit_price, discount_rate, line_total)
    VALUES (1, 1, 1, 1.00, 1.5, 0.00);
    ROLLBACK TRANSACTION t01_09;
    THROW 61033, N'Test FAILED: 01.09 sale_items_discount_rate - out-of-range discount was accepted.', 1;
END TRY
BEGIN CATCH
    DECLARE @e0109 INT = ERROR_NUMBER();
    ROLLBACK TRANSACTION t01_09;
    IF @e0109 NOT IN (547, 515)
        THROW 61034, N'Test FAILED: 01.09 sale_items_discount_rate - expected 547/515, got ' + CAST(@e0109 AS NVARCHAR(10)) + N'.', 1;
END CATCH
PRINT N'Test PASSED: 01.09 sale_items_discount_rate';

/* ---------------------------------------------------------------------------
   TEST 01.10 - sale_items.sale_id FK (orphan -> 547)
--------------------------------------------------------------------------- */
SAVE TRANSACTION t01_10;
BEGIN TRY
    INSERT INTO dbo.sale_items (sale_id, product_id, quantity, unit_price, line_total)
    VALUES (2147483647, 1, 1, 1.00, 1.00);
    ROLLBACK TRANSACTION t01_10;
    THROW 61035, N'Test FAILED: 01.10 sale_items_sale_fk - orphan sale_id was accepted.', 1;
END TRY
BEGIN CATCH
    DECLARE @e0110 INT = ERROR_NUMBER();
    ROLLBACK TRANSACTION t01_10;
    IF @e0110 <> 547
        THROW 61036, N'Test FAILED: 01.10 sale_items_sale_fk - expected 547, got ' + CAST(@e0110 AS NVARCHAR(10)) + N'.', 1;
END CATCH
PRINT N'Test PASSED: 01.10 sale_items_sale_fk';

/* ---------------------------------------------------------------------------
   TEST 01.11 - categories self-parent (CK -> 547)
--------------------------------------------------------------------------- */
DECLARE @CatID INT;
SAVE TRANSACTION t01_11;
BEGIN TRY
    INSERT INTO dbo.categories (category_name, is_active, is_deleted)
    VALUES (N'Test Self Parent', 1, 0);
    SET @CatID = SCOPE_IDENTITY();
    UPDATE dbo.categories SET parent_id = @CatID WHERE category_id = @CatID;
    ROLLBACK TRANSACTION t01_11;
    THROW 61037, N'Test FAILED: 01.11 categories_no_self_parent - self-parent was accepted.', 1;
END TRY
BEGIN CATCH
    DECLARE @e0111 INT = ERROR_NUMBER();
    ROLLBACK TRANSACTION t01_11;
    IF @e0111 <> 547
        THROW 61038, N'Test FAILED: 01.11 categories_no_self_parent - expected 547, got ' + CAST(@e0111 AS NVARCHAR(10)) + N'.', 1;
END CATCH
PRINT N'Test PASSED: 01.11 categories_no_self_parent';

/* ---------------------------------------------------------------------------
   TEST 01.12 - categories per-parent name UNIQUE (duplicate -> 2601/2627)
--------------------------------------------------------------------------- */
DECLARE @CatParent INT = (SELECT TOP (1) category_id FROM dbo.categories WHERE parent_id IS NULL AND is_deleted = 0);
SAVE TRANSACTION t01_12;
BEGIN TRY
    INSERT INTO dbo.categories (category_name, parent_id, is_active, is_deleted)
    VALUES (N'Test Dupe Cat', @CatParent, 1, 0);
    INSERT INTO dbo.categories (category_name, parent_id, is_active, is_deleted)
    VALUES (N'Test Dupe Cat', @CatParent, 1, 0);
    ROLLBACK TRANSACTION t01_12;
    THROW 61039, N'Test FAILED: 01.12 categories_name_unique - duplicate sibling name was accepted.', 1;
END TRY
BEGIN CATCH
    DECLARE @e0112 INT = ERROR_NUMBER();
    ROLLBACK TRANSACTION t01_12;
    IF @e0112 NOT IN (2601, 2627)
        THROW 61040, N'Test FAILED: 01.12 categories_name_unique - expected 2601/2627, got ' + CAST(@e0112 AS NVARCHAR(10)) + N'.', 1;
END CATCH
PRINT N'Test PASSED: 01.12 categories_name_unique';

/* ---------------------------------------------------------------------------
   TEST 01.13 - inventory.quantity_on_hand non-negative (negative -> 547)
--------------------------------------------------------------------------- */
SAVE TRANSACTION t01_13;
BEGIN TRY
    INSERT INTO dbo.inventory (product_id, quantity_on_hand, quantity_reserved)
    VALUES (1, -1, 0);
    ROLLBACK TRANSACTION t01_13;
    THROW 61041, N'Test FAILED: 01.13 inventory_qty_non_negative - negative stock was accepted.', 1;
END TRY
BEGIN CATCH
    DECLARE @e0113 INT = ERROR_NUMBER();
    ROLLBACK TRANSACTION t01_13;
    IF @e0113 NOT IN (547, 515)
        THROW 61042, N'Test FAILED: 01.13 inventory_qty_non_negative - expected 547/515, got ' + CAST(@e0113 AS NVARCHAR(10)) + N'.', 1;
END CATCH
PRINT N'Test PASSED: 01.13 inventory_qty_non_negative';

/* ---------------------------------------------------------------------------
   TEST 01.14 - tax_rates.rate_percent max (rate > 100 -> 547)
--------------------------------------------------------------------------- */
SAVE TRANSACTION t01_14;
BEGIN TRY
    INSERT INTO dbo.tax_rates (tax_name, tax_code, rate_percent, is_active)
    VALUES (N'Test Bad Tax', N'TEST_TAX_OVER', 150.0000, 1);
    ROLLBACK TRANSACTION t01_14;
    THROW 61043, N'Test FAILED: 01.14 tax_rates_rate_max - rate > 100 was accepted.', 1;
END TRY
BEGIN CATCH
    DECLARE @e0114 INT = ERROR_NUMBER();
    ROLLBACK TRANSACTION t01_14;
    IF @e0114 NOT IN (547, 515)
        THROW 61044, N'Test FAILED: 01.14 tax_rates_rate_max - expected 547/515, got ' + CAST(@e0114 AS NVARCHAR(10)) + N'.', 1;
END CATCH
PRINT N'Test PASSED: 01.14 tax_rates_rate_max';

/* ---------------------------------------------------------------------------
   TEST 01.15 - settings.data_type CHECK (invalid -> 547)
--------------------------------------------------------------------------- */
SAVE TRANSACTION t01_15;
BEGIN TRY
    INSERT INTO dbo.settings (setting_key, setting_value, data_type, is_active)
    VALUES (N'test_bad_type', N'x', N'blob', 1);
    ROLLBACK TRANSACTION t01_15;
    THROW 61045, N'Test FAILED: 01.15 settings_data_type - invalid data_type was accepted.', 1;
END TRY
BEGIN CATCH
    DECLARE @e0115 INT = ERROR_NUMBER();
    ROLLBACK TRANSACTION t01_15;
    IF @e0115 NOT IN (547, 515)
        THROW 61046, N'Test FAILED: 01.15 settings_data_type - expected 547/515, got ' + CAST(@e0115 AS NVARCHAR(10)) + N'.', 1;
END CATCH
PRINT N'Test PASSED: 01.15 settings_data_type';

/* ---------------------------------------------------------------------------
   TEST 01.16 - notifications.severity CHECK (invalid -> 547)
--------------------------------------------------------------------------- */
SAVE TRANSACTION t01_16;
BEGIN TRY
    INSERT INTO dbo.notifications (user_id, notification_type_id, title, severity, created_at)
    SELECT 1, notification_type_id, N'Test', N'URGENT', SYSUTCDATETIME()
    FROM dbo.notification_types WHERE type_code = N'SYSTEM';
    ROLLBACK TRANSACTION t01_16;
    THROW 61047, N'Test FAILED: 01.16 notifications_severity - invalid severity was accepted.', 1;
END TRY
BEGIN CATCH
    DECLARE @e0116 INT = ERROR_NUMBER();
    ROLLBACK TRANSACTION t01_16;
    IF @e0116 NOT IN (547, 515)
        THROW 61048, N'Test FAILED: 01.16 notifications_severity - expected 547/515, got ' + CAST(@e0116 AS NVARCHAR(10)) + N'.', 1;
END CATCH
PRINT N'Test PASSED: 01.16 notifications_severity';

/* ---------------------------------------------------------------------------
   TEST 01.17 - credit_sales.outstanding_balance non-negative (negative -> 547)
--------------------------------------------------------------------------- */
SAVE TRANSACTION t01_17;
BEGIN TRY
    INSERT INTO dbo.credit_sales
        (sale_id, customer_id, total_amount, amount_paid, outstanding_balance, status)
    VALUES (1, 1, 10.00, 0.00, -5.00, N'OPEN');
    ROLLBACK TRANSACTION t01_17;
    THROW 61049, N'Test FAILED: 01.17 credit_balance_non_negative - negative balance was accepted.', 1;
END TRY
BEGIN CATCH
    DECLARE @e0117 INT = ERROR_NUMBER();
    ROLLBACK TRANSACTION t01_17;
    IF @e0117 NOT IN (547, 515)
        THROW 61050, N'Test FAILED: 01.17 credit_balance_non_negative - expected 547/515, got ' + CAST(@e0117 AS NVARCHAR(10)) + N'.', 1;
END CATCH
PRINT N'Test PASSED: 01.17 credit_balance_non_negative';

/* ---------------------------------------------------------------------------
   TEST 01.18 - payment_methods.method_code UNIQUE (duplicate -> 2601/2627)
--------------------------------------------------------------------------- */
SAVE TRANSACTION t01_18;
BEGIN TRY
    INSERT INTO dbo.payment_methods (method_code, method_name, is_cash, is_active, sort_order)
    SELECT method_code, method_name + N' Dupe', 0, 1, 99 FROM dbo.payment_methods WHERE method_code = N'CASH';
    ROLLBACK TRANSACTION t01_18;
    THROW 61051, N'Test FAILED: 01.18 payment_methods_code_unique - duplicate method code was accepted.', 1;
END TRY
BEGIN CATCH
    DECLARE @e0118 INT = ERROR_NUMBER();
    ROLLBACK TRANSACTION t01_18;
    IF @e0118 NOT IN (2601, 2627)
        THROW 61052, N'Test FAILED: 01.18 payment_methods_code_unique - expected 2601/2627, got ' + CAST(@e0118 AS NVARCHAR(10)) + N'.', 1;
END CATCH
PRINT N'Test PASSED: 01.18 payment_methods_code_unique';

/* ---------------------------------------------------------------------------
   TEST 01.19 - FK enforcement on users.role_id (orphan role -> 547)
--------------------------------------------------------------------------- */
SAVE TRANSACTION t01_19;
BEGIN TRY
    INSERT INTO dbo.users (username, email, password_hash, full_name, role_id)
    VALUES (N'fk_orphan_user', N'fk_orphan@example.com', N'hash', N'FK Orphan', 2147483647);
    ROLLBACK TRANSACTION t01_19;
    THROW 61053, N'Test FAILED: 01.19 users_role_fk - orphan role_id was accepted.', 1;
END TRY
BEGIN CATCH
    DECLARE @e0119 INT = ERROR_NUMBER();
    ROLLBACK TRANSACTION t01_19;
    IF @e0119 <> 547
        THROW 61054, N'Test FAILED: 01.19 users_role_fk - expected 547, got ' + CAST(@e0119 AS NVARCHAR(10)) + N'.', 1;
END CATCH
PRINT N'Test PASSED: 01.19 users_role_fk';

/* ---------------------------------------------------------------------------
   TEST 01.20 - UNIQUE composite: role_permissions (role_id, permission_id)
--------------------------------------------------------------------------- */
IF NOT EXISTS (SELECT 1 FROM sys.key_constraints WHERE name = N'UQ_role_permissions_role_permission' AND OBJECT_SCHEMA_NAME(parent_object_id) = N'dbo')
    THROW 61055, N'Test FAILED: 01.20 role_permissions_unique - UQ_role_permissions_role_permission missing.', 1;

SAVE TRANSACTION t01_20;
BEGIN TRY
    INSERT INTO dbo.role_permissions (role_id, permission_id, granted_at)
    SELECT role_id, permission_id, SYSUTCDATETIME()
    FROM dbo.role_permissions
    WHERE role_permission_id = (SELECT MIN(role_permission_id) FROM dbo.role_permissions);
    ROLLBACK TRANSACTION t01_20;
    THROW 61056, N'Test FAILED: 01.20 role_permissions_unique - duplicate grant was accepted.', 1;
END TRY
BEGIN CATCH
    DECLARE @e0120 INT = ERROR_NUMBER();
    ROLLBACK TRANSACTION t01_20;
    IF @e0120 NOT IN (2601, 2627)
        THROW 61057, N'Test FAILED: 01.20 role_permissions_unique - expected 2601/2627, got ' + CAST(@e0120 AS NVARCHAR(10)) + N'.', 1;
END CATCH
PRINT N'Test PASSED: 01.20 role_permissions_unique';

/* ---------------------------------------------------------------------------
   FILE CLEANUP: roll back the entire run (non-destructive guarantee)
--------------------------------------------------------------------------- */
IF XACT_STATE() <> 0
    ROLLBACK TRANSACTION;

PRINT N'Test PASSED: 01_constraints_all';
