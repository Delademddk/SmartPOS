/* ==========================================================================
   SmartPOS Database - TEST SUITE 07: SEED DATA
   --------------------------------------------------------------------------
   Verifies the required runtime records seeded by SeedData/SeedData.sql.
   All checks are read-only (no transactions, no writes).

   Expected counts (fresh install):
     permissions       50        role_permissions  95
     roles              3        users             3
     password_history   3        business_information  1
     currencies         4        tax_rates         3
     categories         5        suppliers         3
     payment_methods    4        return_reasons    5
     notification_types 6        settings         12

   Success -> PRINT N'Test PASSED: <name>'
   Failure -> THROW <code>, N'Test FAILED: <name>: <detail>', 1
   ========================================================================== */

SET NOCOUNT ON;

BEGIN TRY

    /* ------------------------------------------------------------------ */
    /* 07.01 - Permissions                                                 */
    /* ------------------------------------------------------------------ */
    IF (SELECT COUNT(*) FROM dbo.permissions) <> 50
        THROW 67001, N'Test FAILED: 07.01 permissions - expected 50 rows.', 1;
    IF (SELECT COUNT(*) FROM (SELECT permission_code FROM dbo.permissions GROUP BY permission_code) x) <> 50
        THROW 67001, N'Test FAILED: 07.01 permissions - duplicate codes.', 1;
    IF EXISTS (SELECT 1 FROM dbo.permissions WHERE permission_code IS NULL OR is_system = 0)
        THROW 67001, N'Test FAILED: 07.01 permissions - a seed permission is not marked is_system = 1.', 1;
    -- Every module that must exist.
    IF NOT EXISTS (SELECT 1 FROM dbo.permissions WHERE permission_code = N'dashboard.view')
        THROW 67001, N'Test FAILED: 07.01 permissions - dashboard.view missing.', 1;
    IF NOT EXISTS (SELECT 1 FROM dbo.permissions WHERE permission_code = N'products.view')
        THROW 67001, N'Test FAILED: 07.01 permissions - products.view missing.', 1;
    IF NOT EXISTS (SELECT 1 FROM dbo.permissions WHERE permission_code = N'reports.view')
        THROW 67001, N'Test FAILED: 07.01 permissions - reports.view missing.', 1;

    /* ------------------------------------------------------------------ */
    /* 07.02 - Roles + role_permissions                                    */
    /* ------------------------------------------------------------------ */
    IF (SELECT COUNT(*) FROM dbo.roles) <> 3
        THROW 67002, N'Test FAILED: 07.02 roles - expected 3 rows.', 1;
    IF NOT EXISTS (SELECT 1 FROM dbo.roles WHERE role_code = N'ADMIN'   AND is_system = 1 AND is_active = 1)
        THROW 67002, N'Test FAILED: 07.02 roles - ADMIN role invalid.', 1;
    IF NOT EXISTS (SELECT 1 FROM dbo.roles WHERE role_code = N'MANAGER' AND is_active = 1)
        THROW 67002, N'Test FAILED: 07.02 roles - MANAGER role invalid.', 1;
    IF NOT EXISTS (SELECT 1 FROM dbo.roles WHERE role_code = N'CASHIER' AND is_system = 1 AND is_active = 1)
        THROW 67002, N'Test FAILED: 07.02 roles - CASHIER role invalid.', 1;

    IF (SELECT COUNT(*) FROM dbo.role_permissions) <> 95
        THROW 67002, N'Test FAILED: 07.02 role_permissions - expected 95 rows.', 1;
    IF (SELECT COUNT(*) FROM dbo.role_permissions rp JOIN dbo.roles r ON r.role_id = rp.role_id WHERE r.role_code = N'ADMIN') <> 50
        THROW 67002, N'Test FAILED: 07.02 role_permissions - ADMIN grant count <> 50.', 1;
    IF (SELECT COUNT(*) FROM dbo.role_permissions rp JOIN dbo.roles r ON r.role_id = rp.role_id WHERE r.role_code = N'MANAGER') <> 34
        THROW 67002, N'Test FAILED: 07.02 role_permissions - MANAGER grant count <> 34.', 1;
    IF (SELECT COUNT(*) FROM dbo.role_permissions rp JOIN dbo.roles r ON r.role_id = rp.role_id WHERE r.role_code = N'CASHIER') <> 11
        THROW 67002, N'Test FAILED: 07.02 role_permissions - CASHIER grant count <> 11.', 1;

    /* ------------------------------------------------------------------ */
    /* 07.03 - Bootstrap users + password history                          */
    /* ------------------------------------------------------------------ */
    IF (SELECT COUNT(*) FROM dbo.users WHERE username IN (N'admin', N'manager', N'cashier')) <> 3
        THROW 67003, N'Test FAILED: 07.03 users - bootstrap accounts missing.', 1;
    IF EXISTS (SELECT 1 FROM dbo.users u JOIN dbo.roles r ON r.role_id = u.role_id
               WHERE u.username IN (N'admin', N'manager', N'cashier')
                 AND (u.is_active <> 1 OR u.is_locked <> 0 OR u.must_change_password <> 1))
        THROW 67003, N'Test FAILED: 07.03 users - bootstrap account flags are wrong.', 1;
    IF (SELECT COUNT(*) FROM dbo.password_history ph JOIN dbo.users u ON u.user_id = ph.user_id
        WHERE u.username IN (N'admin', N'manager', N'cashier')) <> 3
        THROW 67003, N'Test FAILED: 07.03 password_history - expected one row per bootstrap user.', 1;

    /* ------------------------------------------------------------------ */
    /* 07.04 - Business information + currencies + tax rates               */
    /* ------------------------------------------------------------------ */
    IF (SELECT COUNT(*) FROM dbo.business_information) <> 1
        THROW 67004, N'Test FAILED: 07.04 business_information - expected exactly 1 row.', 1;
    IF (SELECT TOP (1) currency_code FROM dbo.business_information) <> N'USD'
        THROW 67004, N'Test FAILED: 07.04 business_information - default currency should be USD.', 1;

    IF (SELECT COUNT(*) FROM dbo.currencies) <> 4
        THROW 67004, N'Test FAILED: 07.04 currencies - expected 4 rows.', 1;
    IF NOT EXISTS (SELECT 1 FROM dbo.currencies WHERE currency_code = N'USD' AND is_base = 1)
        THROW 67004, N'Test FAILED: 07.04 currencies - USD base currency missing.', 1;

    IF (SELECT COUNT(*) FROM dbo.tax_rates) <> 3
        THROW 67004, N'Test FAILED: 07.04 tax_rates - expected 3 rows.', 1;
    IF NOT EXISTS (SELECT 1 FROM dbo.tax_rates WHERE tax_code = N'VAT_STANDARD' AND rate_percent = 7.5000)
        THROW 67004, N'Test FAILED: 07.04 tax_rates - VAT_STANDARD missing or wrong rate.', 1;
    IF (SELECT COUNT(*) FROM dbo.tax_rates WHERE is_default = 1) <> 1
        THROW 67004, N'Test FAILED: 07.04 tax_rates - expected exactly one default.', 1;

    /* ------------------------------------------------------------------ */
    /* 07.05 - Categories + suppliers                                      */
    /* ------------------------------------------------------------------ */
    IF (SELECT COUNT(*) FROM dbo.categories WHERE is_deleted = 0 AND parent_id IS NULL) <> 5
        THROW 67005, N'Test FAILED: 07.05 categories - expected 5 top-level rows.', 1;
    IF EXISTS (SELECT 1 FROM dbo.categories WHERE category_name IS NULL)
        THROW 67005, N'Test FAILED: 07.05 categories - NULL category name.', 1;

    IF (SELECT COUNT(*) FROM dbo.suppliers WHERE is_deleted = 0) <> 3
        THROW 67005, N'Test FAILED: 07.05 suppliers - expected 3 rows.', 1;

    /* ------------------------------------------------------------------ */
    /* 07.06 - Payment methods + return reasons + notification types       */
    /* ------------------------------------------------------------------ */
    IF (SELECT COUNT(*) FROM dbo.payment_methods WHERE is_active = 1) <> 4
        THROW 67006, N'Test FAILED: 07.06 payment_methods - expected 4 rows.', 1;
    IF NOT EXISTS (SELECT 1 FROM dbo.payment_methods WHERE method_code = N'CASH' AND is_cash = 1)
        THROW 67006, N'Test FAILED: 07.06 payment_methods - CASH method invalid.', 1;

    IF (SELECT COUNT(*) FROM dbo.return_reasons WHERE is_active = 1) <> 5
        THROW 67006, N'Test FAILED: 07.06 return_reasons - expected 5 rows.', 1;

    IF (SELECT COUNT(*) FROM dbo.notification_types WHERE is_active = 1) <> 6
        THROW 67006, N'Test FAILED: 07.06 notification_types - expected 6 rows.', 1;
    IF NOT EXISTS (SELECT 1 FROM dbo.notification_types WHERE type_code = N'LOW_STOCK')
        THROW 67006, N'Test FAILED: 07.06 notification_types - LOW_STOCK missing.', 1;

    /* ------------------------------------------------------------------ */
    /* 07.07 - Settings                                                    */
    /* ------------------------------------------------------------------ */
    IF (SELECT COUNT(*) FROM dbo.settings WHERE is_active = 1) <> 12
        THROW 67007, N'Test FAILED: 07.07 settings - expected 12 rows.', 1;
    IF (SELECT setting_value FROM dbo.settings WHERE setting_key = N'currency_symbol') <> N'$'
        THROW 67007, N'Test FAILED: 07.07 settings - currency_symbol is not $.', 1;
    IF (SELECT setting_value FROM dbo.settings WHERE setting_key = N'password_history_count') <> N'5'
        THROW 67007, N'Test FAILED: 07.07 settings - password_history_count is not 5.', 1;
    IF EXISTS (SELECT 1 FROM dbo.settings WHERE data_type NOT IN (N'string', N'int', N'decimal', N'bool', N'json'))
        THROW 67007, N'Test FAILED: 07.07 settings - invalid data_type value.', 1;

END TRY
BEGIN CATCH
    THROW 67099, N'Test FAILED: 07_seed_data - ' + ERROR_MESSAGE(), 1;
END CATCH;

PRINT N'Test PASSED: 07_seed_data_all';
