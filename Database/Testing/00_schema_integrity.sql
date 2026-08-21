/* ==========================================================================
   SmartPOS Database - TEST SUITE 00: SCHEMA INTEGRITY
   --------------------------------------------------------------------------
   Verifies that the physical schema matches the design contract:
     - every expected object exists (tables, procedures, views, functions,
       triggers)
     - seed data contains the required runtime records
     - key column data types match the spec
     - foreign keys reference real tables
     - every foreign key has a supporting index (INFORMATIONAL: the current
       schema deliberately leaves some FKs unindexed - see README.md)

   HARNESS
     - Pure metadata / read-only queries. No writes, no transactions.
     - Success  -> PRINT N'Test PASSED: <name>'
     - Failure  -> THROW <code>, N'Test FAILED: <name>: <detail>', 1
     - Run with sqlcmd -S <server> -U <user> -P <pass> -d SmartPOS -b -i 00_...
       so a failure yields a non-zero exit code.
   ========================================================================== */

SET NOCOUNT ON;

/* ---------------------------------------------------------------------------
   TEST 00.01 - Expected tables exist
--------------------------------------------------------------------------- */
IF EXISTS (
    SELECT 1
    FROM (VALUES
        (N'roles'), (N'permissions'), (N'role_permissions'),
        (N'users'), (N'user_sessions'), (N'password_history'), (N'password_resets'),
        (N'business_information'), (N'currencies'), (N'tax_rates'),
        (N'categories'), (N'products'), (N'product_images'),
        (N'suppliers'), (N'supplier_contacts'), (N'supplier_history'),
        (N'inventory'), (N'inventory_transactions'), (N'stock_reconciliations'), (N'low_stock_alerts'),
        (N'sales'), (N'sale_items'),
        (N'payment_methods'), (N'payments'), (N'receipts'),
        (N'customers'), (N'credit_sales'), (N'credit_payments'),
        (N'return_reasons'), (N'returns'), (N'return_items'),
        (N'notification_types'), (N'notifications'), (N'notification_history'),
        (N'settings'), (N'user_settings'),
        (N'audit_logs'), (N'activity_logs'), (N'error_logs'), (N'security_logs'),
        (N'audit_logs_archive')
    ) AS t(tbl)
    LEFT JOIN sys.tables x
        ON x.name = t.tbl AND SCHEMA_NAME(x.schema_id) = N'dbo'
    WHERE x.object_id IS NULL
)
    THROW 60001, N'Test FAILED: 00.01 tables_present - one or more expected tables are missing (see sys.tables).', 1;

IF (SELECT COUNT(*) FROM sys.tables WHERE SCHEMA_NAME(schema_id) = N'dbo') <> 41
    THROW 60002, N'Test FAILED: 00.01 tables_present - table count is not 41.', 1;

PRINT N'Test PASSED: 00.01 tables_present';

/* ---------------------------------------------------------------------------
   TEST 00.02 - Expected stored procedures exist
--------------------------------------------------------------------------- */
IF EXISTS (
    SELECT 1
    FROM (VALUES
        (N'SP_Login'), (N'SP_Logout'), (N'SP_ValidateSession'),
        (N'SP_GetRoles'), (N'SP_GetRole'), (N'SP_CreateRole'), (N'SP_UpdateRole'),
        (N'SP_DeleteRole'), (N'SP_GetPermissions'),
        (N'SP_GetUsers'), (N'SP_GetUser'), (N'SP_CreateUser'), (N'SP_UpdateUser'),
        (N'SP_DeactivateUser'), (N'SP_ResetPassword'), (N'SP_ChangePassword'),
        (N'SP_RequestPasswordReset'), (N'SP_CompletePasswordReset'),
        (N'SP_GetBusinessInformation'), (N'SP_UpsertBusinessInformation'),
        (N'SP_GetCurrencies'), (N'SP_CreateCurrency'), (N'SP_UpdateCurrency'), (N'SP_SetBaseCurrency'),
        (N'SP_GetTaxRates'), (N'SP_CreateTaxRate'), (N'SP_UpdateTaxRate'), (N'SP_DeactivateTaxRate'),
        (N'SP_GetCategories'), (N'SP_GetCategoryTree'), (N'SP_CreateCategory'),
        (N'SP_UpdateCategory'), (N'SP_DeleteCategory'), (N'SP_GetCategory'),
        (N'SP_GetProducts'), (N'SP_GetProduct'), (N'SP_CreateProduct'), (N'SP_UpdateProduct'),
        (N'SP_DeleteProduct'), (N'SP_RestoreProduct'),
        (N'SP_GetProductByBarcode'), (N'SP_GetProductBySKU'), (N'SP_SearchProducts'),
        (N'SP_GetProductImages'), (N'SP_AddProductImage'), (N'SP_DeleteProductImage'),
        (N'SP_GetSuppliers'), (N'SP_GetSupplier'), (N'SP_CreateSupplier'), (N'SP_UpdateSupplier'),
        (N'SP_DeleteSupplier'), (N'SP_GetSupplierContacts'), (N'SP_AddSupplierContact'),
        (N'SP_UpdateSupplierContact'), (N'SP_DeleteSupplierContact'), (N'SP_LogSupplierHistory'),
        (N'SP_RestockProduct'), (N'SP_AdjustStock'), (N'SP_GetStockLevel'),
        (N'SP_CreateSale'),
        (N'SP_GetPaymentMethods'), (N'SP_CreatePaymentMethod'), (N'SP_UpdatePaymentMethod'),
        (N'SP_GetSalePayments'), (N'SP_GetPayment'), (N'SP_RecordPayment'),
        (N'SP_GetReceipt'), (N'SP_GetReceiptBySale'), (N'SP_GenerateReceipt'),
        (N'SP_ProcessReturn'),
        (N'SP_GetNotifications'), (N'SP_GetUnreadCount'), (N'SP_MarkNotificationRead'),
        (N'SP_DismissNotification'), (N'SP_CreateNotification'), (N'SP_GetNotificationTypes'),
        (N'SP_ResetNotifications'),
        (N'SP_SalesReport'), (N'SP_InventoryReport'), (N'SP_InventoryMovementsReport'),
        (N'SP_SupplierReport'), (N'SP_CreditReport'), (N'SP_ReturnsReport'),
        (N'SP_ProfitReport'), (N'SP_TaxReport'), (N'SP_PaymentMethodsReport'),
        (N'SP_ProductSalesReport'), (N'SP_ExportReport'),
        (N'SP_GetDashboardMetrics'), (N'SP_GetDashboardData'),
        (N'SP_GetSalesByCategory'), (N'SP_GetTopProducts'), (N'SP_GetSalesTrend'),
        (N'SP_GetSettings'), (N'SP_GetSetting'), (N'SP_UpsertSetting'), (N'SP_DeleteSetting'),
        (N'SP_GetUserSettings'), (N'SP_UpsertUserSetting'),
        (N'SP_GetAuditLogs'), (N'SP_GetSecurityLogs'), (N'SP_GetErrorLogs'), (N'SP_ArchiveAuditLogs')
    ) AS p(sp)
    LEFT JOIN sys.procedures x
        ON x.name = p.sp AND SCHEMA_NAME(x.schema_id) = N'dbo'
    WHERE x.object_id IS NULL
)
    THROW 60003, N'Test FAILED: 00.02 procedures_present - one or more expected procedures are missing.', 1;

PRINT N'Test PASSED: 00.02 procedures_present';

/* ---------------------------------------------------------------------------
   TEST 00.03 - Expected views exist
--------------------------------------------------------------------------- */
IF EXISTS (
    SELECT 1
    FROM (VALUES
        (N'VW_UserPermissions'), (N'VW_ProductStock'), (N'VW_SalesWithLines'),
        (N'VW_CustomerBalances'), (N'VW_LowStock'),
        (N'VW_SalesSummary'), (N'VW_DailySales'), (N'VW_ProductSalesReport'),
        (N'VW_InventoryReport'), (N'VW_InventoryMovementsReport'), (N'VW_SupplierReport'),
        (N'VW_CreditReport'), (N'VW_ReturnsReport'), (N'VW_ProfitReport'),
        (N'VW_PaymentMethodsReport'), (N'VW_TaxReport'),
        (N'VW_DashboardKPIs'), (N'VW_RecentSales'), (N'VW_TopProducts'),
        (N'VW_SalesTrend7d'), (N'VW_SalesByCategory'), (N'VW_SalesByPaymentMethod'),
        (N'VW_RecentNotifications'), (N'VW_OutstandingCredit')
    ) AS v(vw)
    LEFT JOIN sys.views x
        ON x.name = v.vw AND SCHEMA_NAME(x.schema_id) = N'dbo'
    WHERE x.object_id IS NULL
)
    THROW 60004, N'Test FAILED: 00.03 views_present - one or more expected views are missing.', 1;

PRINT N'Test PASSED: 00.03 views_present';

/* ---------------------------------------------------------------------------
   TEST 00.04 - Expected scalar functions exist
--------------------------------------------------------------------------- */
IF EXISTS (
    SELECT 1
    FROM (VALUES
        (N'FN_SmartPOS_Setting', N'FN'), (N'FN_StockStatus', N'FN'),
        (N'FN_HasPermission', N'FN'), (N'FN_HashToken', N'FN'),
        (N'FN_CalculateLineTotal', N'FN'), (N'FN_GetUserDisplayName', N'FN'),
        (N'FN_CurrencySymbol', N'FN')
    ) AS f(fn, ty)
    LEFT JOIN sys.objects x
        ON x.name = f.fn AND SCHEMA_NAME(x.schema_id) = N'dbo' AND x.type = f.ty
    WHERE x.object_id IS NULL
)
    THROW 60005, N'Test FAILED: 00.04 functions_present - one or more expected functions are missing.', 1;

PRINT N'Test PASSED: 00.04 functions_present';

/* ---------------------------------------------------------------------------
   TEST 00.05 - Expected triggers exist
--------------------------------------------------------------------------- */
IF EXISTS (
    SELECT 1
    FROM (VALUES
        (N'TRG_products_audit'), (N'TRG_categories_audit'), (N'TRG_suppliers_audit'),
        (N'TRG_users_audit'), (N'TRG_settings_audit'),
        (N'TRG_inventory_low_stock'), (N'TRG_password_history_retention')
    ) AS t(tr)
    LEFT JOIN sys.triggers x
        ON x.name = t.tr AND SCHEMA_NAME(x.schema_id) = N'dbo'
    WHERE x.object_id IS NULL
)
    THROW 60006, N'Test FAILED: 00.05 triggers_present - one or more expected triggers are missing.', 1;

PRINT N'Test PASSED: 00.05 triggers_present';

/* ---------------------------------------------------------------------------
   TEST 00.06 - Seed data: roles
--------------------------------------------------------------------------- */
IF NOT EXISTS (SELECT 1 FROM dbo.roles WHERE role_code = N'ADMIN' AND is_system = 1 AND is_active = 1)
    THROW 60010, N'Test FAILED: 00.06 seed_roles - ADMIN system role missing.', 1;
IF NOT EXISTS (SELECT 1 FROM dbo.roles WHERE role_code = N'MANAGER' AND is_active = 1)
    THROW 60011, N'Test FAILED: 00.06 seed_roles - MANAGER role missing.', 1;
IF NOT EXISTS (SELECT 1 FROM dbo.roles WHERE role_code = N'CASHIER' AND is_system = 1 AND is_active = 1)
    THROW 60012, N'Test FAILED: 00.06 seed_roles - CASHIER system role missing.', 1;

PRINT N'Test PASSED: 00.06 seed_roles';

/* ---------------------------------------------------------------------------
   TEST 00.07 - Seed data: permissions and role grants
--------------------------------------------------------------------------- */
IF (SELECT COUNT(*) FROM dbo.permissions WHERE is_active = 1) < 50
    THROW 60013, N'Test FAILED: 00.07 seed_permissions - expected 50 active permissions.', 1;

IF NOT EXISTS (
    SELECT 1 FROM dbo.permissions
    WHERE permission_code IN (N'dashboard.view', N'products.create', N'sales.create', N'reports.view')
)
    THROW 60014, N'Test FAILED: 00.07 seed_permissions - key permission codes missing.', 1;

IF NOT EXISTS (
    SELECT 1
    FROM dbo.roles r
    JOIN dbo.role_permissions rp ON rp.role_id = r.role_id
    JOIN dbo.permissions p       ON p.permission_id = rp.permission_id
    WHERE r.role_code = N'ADMIN' AND p.permission_code = N'products.create'
)
    THROW 60015, N'Test FAILED: 00.07 seed_permissions - ADMIN is not granted products.create.', 1;

PRINT N'Test PASSED: 00.07 seed_permissions';

/* ---------------------------------------------------------------------------
   TEST 00.08 - Seed data: bootstrap users + business + references
--------------------------------------------------------------------------- */
IF NOT EXISTS (SELECT 1 FROM dbo.users WHERE username = N'admin' AND is_active = 1 AND is_deleted = 0)
    THROW 60016, N'Test FAILED: 00.08 seed_users - admin user missing.', 1;
IF NOT EXISTS (SELECT 1 FROM dbo.users WHERE username = N'cashier' AND is_active = 1 AND is_deleted = 0)
    THROW 60017, N'Test FAILED: 00.08 seed_users - cashier user missing.', 1;
IF NOT EXISTS (SELECT 1 FROM dbo.users WHERE username = N'manager' AND is_active = 1 AND is_deleted = 0)
    THROW 60018, N'Test FAILED: 00.08 seed_users - manager user missing.', 1;

IF NOT EXISTS (SELECT 1 FROM dbo.business_information WHERE is_active = 1)
    THROW 60019, N'Test FAILED: 00.08 seed_business - no active business profile.', 1;

IF (SELECT COUNT(*) FROM dbo.payment_methods WHERE is_active = 1) < 4
    THROW 60020, N'Test FAILED: 00.08 seed_payment_methods - expected >= 4 active payment methods.', 1;
IF NOT EXISTS (SELECT 1 FROM dbo.payment_methods WHERE method_code = N'CASH' AND is_cash = 1 AND is_active = 1)
    THROW 60021, N'Test FAILED: 00.08 seed_payment_methods - CASH method missing.', 1;

IF NOT EXISTS (SELECT 1 FROM dbo.notification_types WHERE type_code = N'LOW_STOCK' AND is_active = 1)
    THROW 60022, N'Test FAILED: 00.08 seed_notification_types - LOW_STOCK type missing.', 1;

IF (SELECT COUNT(*) FROM dbo.settings WHERE is_active = 1) < 12
    THROW 60023, N'Test FAILED: 00.08 seed_settings - expected >= 12 active settings.', 1;

IF (SELECT COUNT(*) FROM dbo.tax_rates WHERE is_active = 1) < 1
    THROW 60024, N'Test FAILED: 00.08 seed_tax_rates - no active tax rates.', 1;

PRINT N'Test PASSED: 00.08 seed_users_references';

/* ---------------------------------------------------------------------------
   TEST 00.09 - Key column data types
--------------------------------------------------------------------------- */
IF NOT EXISTS (
    SELECT 1
    FROM sys.columns c
    JOIN sys.tables t ON t.object_id = c.object_id
    WHERE t.name = N'users' AND c.name = N'email'
      AND c.user_type_id = TYPE_ID(N'nvarchar') AND c.max_length = 510   -- nvarchar(255)
)
    THROW 60030, N'Test FAILED: 00.09 column_types - users.email must be NVARCHAR(255).', 1;

IF NOT EXISTS (
    SELECT 1
    FROM sys.columns c
    JOIN sys.tables t ON t.object_id = c.object_id
    WHERE t.name = N'users' AND c.name = N'username' AND c.user_type_id = TYPE_ID(N'nvarchar') AND c.max_length = 100
)
    THROW 60031, N'Test FAILED: 00.09 column_types - users.username must be NVARCHAR(50).', 1;

IF NOT EXISTS (
    SELECT 1
    FROM sys.columns c
    JOIN sys.tables t ON t.object_id = c.object_id
    WHERE t.name = N'products' AND c.name = N'unit_price'
      AND c.user_type_id = TYPE_ID(N'decimal') AND c.precision = 19 AND c.scale = 4
)
    THROW 60032, N'Test FAILED: 00.09 column_types - products.unit_price must be DECIMAL(19,4).', 1;

IF NOT EXISTS (
    SELECT 1
    FROM sys.columns c
    JOIN sys.tables t ON t.object_id = c.object_id
    WHERE t.name = N'sale_items' AND c.name = N'line_total'
      AND c.user_type_id = TYPE_ID(N'decimal') AND c.precision = 19 AND c.scale = 4
)
    THROW 60033, N'Test FAILED: 00.09 column_types - sale_items.line_total must be DECIMAL(19,4).', 1;

IF NOT EXISTS (
    SELECT 1
    FROM sys.columns c
    JOIN sys.tables t ON t.object_id = c.object_id
    WHERE t.name = N'sales' AND c.name = N'total_amount'
      AND c.user_type_id = TYPE_ID(N'decimal') AND c.precision = 19 AND c.scale = 4
)
    THROW 60034, N'Test FAILED: 00.09 column_types - sales.total_amount must be DECIMAL(19,4).', 1;

PRINT N'Test PASSED: 00.09 column_types';

/* ---------------------------------------------------------------------------
   TEST 00.10 - Foreign keys reference existing parent tables (no orphans)
--------------------------------------------------------------------------- */
IF EXISTS (
    SELECT 1
    FROM sys.foreign_keys fk
    LEFT JOIN sys.tables parent_t
        ON parent_t.object_id = fk.referenced_object_id
    LEFT JOIN sys.tables child_t
        ON child_t.object_id = fk.parent_object_id
    WHERE parent_t.object_id IS NULL OR child_t.object_id IS NULL
)
    THROW 60040, N'Test FAILED: 00.10 fk_references - a foreign key references a missing table.', 1;

PRINT N'Test PASSED: 00.10 fk_references';

/* ---------------------------------------------------------------------------
   TEST 00.11 - Foreign keys with supporting indexes
   --------------------------------------------------------------------------
   A foreign key column should be the LEADING column of an index on the child
   table so FK enforcement lookups and parent-side cascades stay efficient.

   NOTE: the current schema intentionally ships with several FKs that lack a
   supporting index. This test FAILS by design until those indexes are added -
   the missing list is reported and the README documents the remediation.
--------------------------------------------------------------------------- */
DECLARE @MissingFks NVARCHAR(MAX);

SELECT @MissingFks = STUFF((
    SELECT NCHAR(10) + N'  ' + fk.name + N'  (dbo.' + OBJECT_NAME(fk.parent_object_id) + N'.' + c.name + N')'
    FROM sys.foreign_keys fk
    JOIN sys.foreign_key_columns fkc
        ON fkc.constraint_object_id = fk.object_id AND fkc.constraint_column_id = 1
    JOIN sys.columns c
        ON c.object_id = fkc.parent_object_id AND c.column_id = fkc.parent_column_id
    WHERE NOT EXISTS (
        SELECT 1
        FROM sys.indexes i
        JOIN sys.index_columns ic
            ON ic.object_id = i.object_id AND ic.index_id = i.index_id
        WHERE i.object_id = fkc.parent_object_id
          AND ic.column_id = fkc.parent_column_id
          AND ic.key_ordinal = 1
          AND i.is_hypothetical = 0
          AND i.type > 0
    )
    ORDER BY fk.name
    FOR XML PATH(N''), TYPE
).value(N'.', N'NVARCHAR(MAX)'), 1, 1, N'');

IF @MissingFks IS NOT NULL
    THROW 60050, N'Test FAILED: 00.11 fk_indexes - the following foreign keys lack a supporting index (leading key column):' + @MissingFks, 1;

PRINT N'Test PASSED: 00.11 fk_indexes';

/* ---------------------------------------------------------------------------
   TEST 00.12 - Referential integrity of operational children (no orphan rows)
--------------------------------------------------------------------------- */
IF EXISTS (SELECT 1 FROM dbo.sale_items si LEFT JOIN dbo.sales s ON s.sale_id = si.sale_id WHERE s.sale_id IS NULL)
    THROW 60060, N'Test FAILED: 00.12 fk_orphans - sale_items referencing a missing sale.', 1;
IF EXISTS (SELECT 1 FROM dbo.payments p LEFT JOIN dbo.sales s ON s.sale_id = p.sale_id WHERE s.sale_id IS NULL)
    THROW 60061, N'Test FAILED: 00.12 fk_orphans - payments referencing a missing sale.', 1;
IF EXISTS (SELECT 1 FROM dbo.inventory_transactions it LEFT JOIN dbo.products p ON p.product_id = it.product_id WHERE p.product_id IS NULL)
    THROW 60062, N'Test FAILED: 00.12 fk_orphans - inventory_transactions referencing a missing product.', 1;

PRINT N'Test PASSED: 00.12 fk_orphans';

/* ==========================================================================
   END OF TEST SUITE 00
   ========================================================================== */

PRINT N'Test PASSED: 00_schema_integrity_all';
