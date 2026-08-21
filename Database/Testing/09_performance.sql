/* ==========================================================================
   SmartPOS Database - TEST SUITE 09: PERFORMANCE / INDEX USAGE
   --------------------------------------------------------------------------
   Verifies that the physical schema supports the application's hot queries:
     - key supporting indexes exist on the expected table + leading column
     - unique constraints back the lookups used by authentication and POS
     - representative "hot path" queries execute without error inside the
       test transaction (they exercise the same predicates as the SPs)

   HARNESS: read-mostly; a small fixture is created and rolled back at the end.
   Success -> PRINT N'Test PASSED: <name>'
   Failure -> THROW <code>, N'Test FAILED: <name>: <detail>', 1
   ========================================================================== */

SET NOCOUNT ON;

/* ---------------------------------------------------------------------------
   09.01 - Expected supporting indexes exist with the correct leading column
--------------------------------------------------------------------------- */
CREATE TABLE #idx (index_name NVARCHAR(200), table_name NVARCHAR(200), leading_col NVARCHAR(200));

INSERT INTO #idx VALUES
    (N'IX_sales_sale_date',                    N'sales',              N'sale_date'),
    (N'IX_sales_user_date',                    N'sales',              N'user_id'),
    (N'IX_sales_customer_id',                  N'sales',              N'customer_id'),
    (N'IX_sale_items_sale_id',                 N'sale_items',         N'sale_id'),
    (N'IX_sale_items_product_id',              N'sale_items',         N'product_id'),
    (N'IX_products_name',                      N'products',           N'product_name'),
    (N'IX_products_category_id',               N'products',           N'category_id'),
    (N'IX_products_supplier_id',               N'products',           N'supplier_id'),
    (N'IX_users_role_id',                      N'users',              N'role_id'),
    (N'IX_users_is_active',                    N'users',              N'is_active'),
    (N'IX_user_sessions_user_id',              N'user_sessions',      N'user_id'),
    (N'IX_password_history_user_id',           N'password_history',   N'user_id'),
    (N'IX_categories_parent_id',               N'categories',         N'parent_id'),
    (N'IX_suppliers_is_active',                N'suppliers',          N'is_active'),
    (N'IX_inventory_transactions_product_created', N'inventory_transactions', N'product_id'),
    (N'IX_inventory_transactions_type_created',     N'inventory_transactions', N'movement_type'),
    (N'IX_low_stock_alerts_status',            N'low_stock_alerts',   N'status'),
    (N'IX_payments_sale_id',                   N'payments',           N'sale_id'),
    (N'IX_payments_method_id',                 N'payments',           N'payment_method_id'),
    (N'IX_receipts_sale_id',                   N'receipts',           N'sale_id'),
    (N'IX_credit_sales_customer_id',           N'credit_sales',       N'customer_id'),
    (N'IX_credit_sales_status',                N'credit_sales',       N'status'),
    (N'IX_credit_payments_credit_sale_id',     N'credit_payments',    N'credit_sale_id'),
    (N'IX_customers_name',                     N'customers',          N'full_name'),
    (N'IX_returns_sale_id',                    N'returns',            N'sale_id'),
    (N'IX_return_items_sale_item_id',          N'return_items',       N'sale_item_id'),
    (N'IX_return_items_product_id',            N'return_items',       N'product_id'),
    (N'IX_notifications_user_read',            N'notifications',      N'user_id'),
    (N'IX_notifications_created_at',           N'notifications',      N'created_at'),
    (N'IX_settings_category',                  N'settings',           N'category'),
    (N'IX_audit_logs_resource',                N'audit_logs',         N'resource_type'),
    (N'IX_audit_logs_created_at',              N'audit_logs',         N'created_at'),
    (N'IX_security_logs_created_at',           N'security_logs',      N'created_at'),
    (N'IX_error_logs_occurred_at',             N'error_logs',         N'occurred_at'),
    (N'IX_activity_logs_created_at',           N'activity_logs',      N'created_at');

DECLARE @MissingIndexes INT = (
    SELECT COUNT(*)
    FROM #idx i
    LEFT JOIN sys.indexes ix
        ON ix.name = i.index_name AND OBJECT_NAME(ix.object_id) = i.table_name
    LEFT JOIN sys.index_columns ic
        ON ic.object_id = ix.object_id AND ic.index_id = ix.index_id AND ic.key_ordinal = 1
    LEFT JOIN sys.columns c
        ON c.object_id = ic.object_id AND c.column_id = ic.column_id
    WHERE ix.index_id IS NULL OR c.name <> i.leading_col
);

IF @MissingIndexes <> 0
    THROW 69001, N'Test FAILED: 09.01 indexes - one or more expected indexes are missing or mis-keyed.', 1;

/* ---------------------------------------------------------------------------
   09.02 - Unique constraints back the authentication / POS lookups
--------------------------------------------------------------------------- */
IF NOT EXISTS (SELECT 1 FROM sys.key_constraints WHERE name = N'UQ_user_sessions_token' AND parent_object_id = OBJECT_ID(N'dbo.user_sessions'))
    THROW 69002, N'Test FAILED: 09.02 uq - user_sessions.session_token is not unique.', 1;
IF NOT EXISTS (SELECT 1 FROM sys.key_constraints WHERE name = N'UQ_users_username' AND parent_object_id = OBJECT_ID(N'dbo.users'))
    THROW 69002, N'Test FAILED: 09.02 uq - users.username is not unique.', 1;
IF NOT EXISTS (SELECT 1 FROM sys.key_constraints WHERE name = N'UQ_users_email' AND parent_object_id = OBJECT_ID(N'dbo.users'))
    THROW 69002, N'Test FAILED: 09.02 uq - users.email is not unique.', 1;
IF NOT EXISTS (SELECT 1 FROM sys.key_constraints WHERE name = N'UQ_products_sku' AND parent_object_id = OBJECT_ID(N'dbo.products'))
    THROW 69002, N'Test FAILED: 09.02 uq - products.sku is not unique.', 1;
IF NOT EXISTS (SELECT 1 FROM sys.key_constraints WHERE name = N'UQ_products_barcode' AND parent_object_id = OBJECT_ID(N'dbo.products'))
    THROW 69002, N'Test FAILED: 09.02 uq - products.barcode is not unique.', 1;
IF NOT EXISTS (SELECT 1 FROM sys.key_constraints WHERE name = N'UQ_sales_receipt_number' AND parent_object_id = OBJECT_ID(N'dbo.sales'))
    THROW 69002, N'Test FAILED: 09.02 uq - sales.receipt_number is not unique.', 1;
IF NOT EXISTS (SELECT 1 FROM sys.key_constraints WHERE name = N'UQ_settings_key' AND parent_object_id = OBJECT_ID(N'dbo.settings'))
    THROW 69002, N'Test FAILED: 09.02 uq - settings.setting_key is not unique.', 1;
IF NOT EXISTS (SELECT 1 FROM sys.key_constraints WHERE name = N'UQ_credit_sales_sale_id' AND parent_object_id = OBJECT_ID(N'dbo.credit_sales'))
    THROW 69002, N'Test FAILED: 09.02 uq - credit_sales.sale_id is not unique.', 1;

/* ---------------------------------------------------------------------------
   09.03 - Hot-path queries execute against the live schema
   The patterns mirror SP_Login / SP_ValidateSession / SP_CreateSale / reports.
--------------------------------------------------------------------------- */
DECLARE @AdminID INT = (SELECT TOP (1) user_id FROM dbo.users WHERE username = N'admin');
DECLARE @dummy INT;

SELECT @dummy = COUNT(*) FROM dbo.users WHERE username = N'admin' OR email = N'admin@smartpos.local';
SELECT @dummy = COUNT(*) FROM dbo.user_sessions s JOIN dbo.users u ON u.user_id = s.user_id WHERE s.session_token = N'x';
SELECT @dummy = COUNT(*) FROM dbo.products p LEFT JOIN dbo.inventory i ON i.product_id = p.product_id WHERE p.is_deleted = 0;
SELECT @dummy = COUNT(*) FROM dbo.sales s JOIN dbo.users u ON u.user_id = s.user_id LEFT JOIN dbo.sale_items si ON si.sale_id = s.sale_id;
SELECT @dummy = COUNT(*) FROM dbo.credit_sales cs JOIN dbo.customers c ON c.customer_id = cs.customer_id WHERE cs.status = N'OPEN';
SELECT @dummy = COUNT(*) FROM dbo.inventory_transactions it WHERE it.product_id IN (SELECT product_id FROM dbo.products);
SELECT @dummy = COUNT(*) FROM dbo.audit_logs WHERE resource_type = N'Product';
SELECT @dummy = COUNT(*) FROM dbo.notifications WHERE user_id = @AdminID AND is_read = 0;
SELECT @dummy = COUNT(*) FROM dbo.role_permissions rp JOIN dbo.permissions p ON p.permission_id = rp.permission_id WHERE p.permission_code = N'products.view';

PRINT N'Test PASSED: 09_performance_all';
