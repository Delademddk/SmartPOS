/* ==========================================================================
   SmartPOS Database - SEED DATA (REQUIRED RUNTIME RECORDS)
   --------------------------------------------------------------------------
   File:    SeedData/SeedData.sql
   Scope:   Required runtime records without which the application cannot
            function: roles, permissions, role grants, bootstrap users,
            business profile, currencies, tax rates, base categories,
            suppliers, payment methods, return reasons, notification types
            and default application settings.

   Build order:
     01 Authentication (roles, permissions, role_permissions)
     02 Users          (users, password_history)
     03 Business       (business_information, currencies, tax_rates)
     04 Categories
     06 Suppliers
     09 Payments       (payment_methods)
     11 Returns        (return_reasons)
     12 Notifications  (notification_types)
     15 Settings

   IMPORTANT:
     - Every statement is idempotent (guarded with IF NOT EXISTS) so this
       file can be re-run safely at any time.
     - Users reference dbo.roles by role_code via a JOIN, and role grants are
       built with INSERT ... SELECT joins against dbo.permissions by
       permission_code, so the script NEVER depends on identity values.
     - The seeded password_hash values are clearly-marked PLACEHOLDERS. The
       backend / installer MUST replace them with real bcrypt hashes before
       first login (see also: users.must_change_password = 1).
     - users.is_system does NOT exist; only dbo.roles carries is_system.
   ========================================================================== */

SET NOCOUNT ON;
GO

/* --------------------------------------------------------------------------
   1. PERMISSIONS (50 system permissions)
   --------------------------------------------------------------------------
   Full CRUD (view/create/update/delete) for every operational module plus a
   read-only view permission for the dashboard and reports modules. All rows
   are flagged is_system = 1.
   -------------------------------------------------------------------------- */
INSERT INTO dbo.permissions
    (permission_code, permission_name, [description], module_name, is_system, is_active, created_by, updated_by)
SELECT v.permission_code, v.permission_name, v.[description], v.module_name, 1, 1, NULL, NULL
FROM (VALUES
    -- dashboard (view only)
    (N'dashboard.view',        N'View Dashboard',        N'View the dashboard and its KPIs',                    N'dashboard'),

    -- products
    (N'products.view',         N'View Products',         N'View the product catalogue and details',             N'products'),
    (N'products.create',       N'Create Product',        N'Create new products',                                N'products'),
    (N'products.update',       N'Update Product',        N'Update existing products',                           N'products'),
    (N'products.delete',       N'Delete Product',        N'Delete products',                                    N'products'),

    -- categories
    (N'categories.view',       N'View Categories',       N'View product categories',                            N'categories'),
    (N'categories.create',     N'Create Category',       N'Create new categories',                              N'categories'),
    (N'categories.update',     N'Update Category',       N'Update existing categories',                         N'categories'),
    (N'categories.delete',     N'Delete Category',       N'Delete categories',                                  N'categories'),

    -- suppliers
    (N'suppliers.view',        N'View Suppliers',        N'View suppliers and their contacts',                  N'suppliers'),
    (N'suppliers.create',      N'Create Supplier',       N'Create new suppliers',                               N'suppliers'),
    (N'suppliers.update',      N'Update Supplier',       N'Update existing suppliers',                          N'suppliers'),
    (N'suppliers.delete',      N'Delete Supplier',       N'Delete suppliers',                                   N'suppliers'),

    -- inventory
    (N'inventory.view',        N'View Inventory',        N'View stock levels and movements',                    N'inventory'),
    (N'inventory.create',      N'Create Inventory',      N'Record stock increases / adjustments',               N'inventory'),
    (N'inventory.update',      N'Update Inventory',      N'Adjust stock levels',                                N'inventory'),
    (N'inventory.delete',      N'Delete Inventory',      N'Delete inventory records',                           N'inventory'),

    -- sales
    (N'sales.view',            N'View Sales',            N'View sales and receipts',                            N'sales'),
    (N'sales.create',          N'Create Sale',           N'Create new sales',                                   N'sales'),
    (N'sales.update',          N'Update Sale',           N'Update / void sales',                                N'sales'),
    (N'sales.delete',          N'Delete Sale',           N'Delete sales',                                       N'sales'),

    -- returns
    (N'returns.view',          N'View Returns',          N'View returns and refunds',                           N'returns'),
    (N'returns.create',        N'Create Return',         N'Process product returns',                            N'returns'),
    (N'returns.update',        N'Update Return',         N'Update returns',                                     N'returns'),
    (N'returns.delete',        N'Delete Return',         N'Delete returns',                                     N'returns'),

    -- credit sales
    (N'credit_sales.view',     N'View Credit Sales',     N'View credit sales and customer balances',            N'credit_sales'),
    (N'credit_sales.create',   N'Create Credit Sale',    N'Create credit sales',                                N'credit_sales'),
    (N'credit_sales.update',   N'Update Credit Sale',    N'Update credit sales and balances',                   N'credit_sales'),
    (N'credit_sales.delete',   N'Delete Credit Sale',    N'Delete credit sales',                                N'credit_sales'),

    -- reports (view only)
    (N'reports.view',          N'View Reports',          N'View reports and exports',                           N'reports'),

    -- users
    (N'users.view',            N'View Users',            N'View user accounts',                                 N'users'),
    (N'users.create',          N'Create User',           N'Create user accounts',                               N'users'),
    (N'users.update',          N'Update User',           N'Update user accounts',                               N'users'),
    (N'users.delete',          N'Delete User',           N'Delete user accounts',                               N'users'),

    -- settings
    (N'settings.view',         N'View Settings',         N'View application settings',                          N'settings'),
    (N'settings.create',       N'Create Setting',        N'Create application settings',                        N'settings'),
    (N'settings.update',       N'Update Setting',        N'Update application settings',                        N'settings'),
    (N'settings.delete',       N'Delete Setting',        N'Delete application settings',                        N'settings'),

    -- notifications
    (N'notifications.view',    N'View Notifications',    N'View notifications',                                 N'notifications'),
    (N'notifications.create',  N'Create Notification',   N'Create notifications',                               N'notifications'),
    (N'notifications.update',  N'Update Notification',   N'Update notifications',                               N'notifications'),
    (N'notifications.delete',  N'Delete Notification',   N'Delete notifications',                               N'notifications'),

    -- audit
    (N'audit.view',            N'View Audit Logs',       N'View audit and security logs',                       N'audit'),
    (N'audit.create',          N'Create Audit Log',      N'Write audit log entries',                            N'audit'),
    (N'audit.update',          N'Update Audit Log',      N'Update audit log entries',                           N'audit'),
    (N'audit.delete',          N'Delete Audit Log',      N'Delete audit log entries',                           N'audit'),

    -- payments
    (N'payments.view',         N'View Payments',         N'View payments and receipts',                         N'payments'),
    (N'payments.create',       N'Create Payment',        N'Record payments',                                    N'payments'),
    (N'payments.update',       N'Update Payment',        N'Update / refund payments',                           N'payments'),
    (N'payments.delete',       N'Delete Payment',        N'Delete payments',                                    N'payments')
) AS v(permission_code, permission_name, [description], module_name)
WHERE NOT EXISTS (
    SELECT 1 FROM dbo.permissions p
    WHERE p.permission_code = v.permission_code
);
GO

/* --------------------------------------------------------------------------
   2. ROLES
   --------------------------------------------------------------------------
   ADMIN  - full system access (system-protected).
   MANAGER- operational management; no user / settings / audit administration.
   CASHIER- front-of-house operator (system-protected).
   -------------------------------------------------------------------------- */
INSERT INTO dbo.roles
    (role_code, role_name, [description], is_system, is_active, created_by, updated_by)
SELECT v.role_code, v.role_name, v.[description], v.is_system, 1, NULL, NULL
FROM (VALUES
    (N'ADMIN',   N'Administrator', N'Full system access. System-protected role.',       1),
    (N'MANAGER', N'Store Manager', N'Operational management; cannot manage users, settings or audit.', 0),
    (N'CASHIER', N'Cashier',       N'Front-of-house sales operator. System-protected.', 1)
) AS v(role_code, role_name, [description], is_system)
WHERE NOT EXISTS (
    SELECT 1 FROM dbo.roles r
    WHERE r.role_code = v.role_code
);
GO

/* --------------------------------------------------------------------------
   3. ROLE PERMISSIONS
   --------------------------------------------------------------------------
   Grants are built with INSERT ... SELECT joins keyed on permission_code /
   role_code so the script works regardless of identity values and can be
   re-run safely.
   -------------------------------------------------------------------------- */

-- ADMIN: every permission
INSERT INTO dbo.role_permissions (role_id, permission_id, granted_by, granted_at)
SELECT r.role_id, p.permission_id, NULL, SYSUTCDATETIME()
FROM dbo.roles r
CROSS JOIN dbo.permissions p
WHERE r.role_code = N'ADMIN'
  AND NOT EXISTS (
      SELECT 1 FROM dbo.role_permissions rp
      WHERE rp.role_id = r.role_id AND rp.permission_id = p.permission_id
  );

-- MANAGER: products, categories, suppliers, inventory, sales, returns,
--          payments, notifications + dashboard.view + reports.view.
--          NOT users / settings / audit / credit_sales.
INSERT INTO dbo.role_permissions (role_id, permission_id, granted_by, granted_at)
SELECT r.role_id, p.permission_id, NULL, SYSUTCDATETIME()
FROM dbo.roles r
CROSS JOIN dbo.permissions p
WHERE r.role_code = N'MANAGER'
  AND (
      p.module_name IN (N'products', N'categories', N'suppliers', N'inventory',
                        N'sales', N'returns', N'payments', N'notifications')
      OR p.permission_code IN (N'dashboard.view', N'reports.view')
  )
  AND NOT EXISTS (
      SELECT 1 FROM dbo.role_permissions rp
      WHERE rp.role_id = r.role_id AND rp.permission_id = p.permission_id
  );

-- CASHIER: read-mostly sales permissions (update allowed for voiding own sales).
INSERT INTO dbo.role_permissions (role_id, permission_id, granted_by, granted_at)
SELECT r.role_id, p.permission_id, NULL, SYSUTCDATETIME()
FROM dbo.roles r
CROSS JOIN dbo.permissions p
WHERE r.role_code = N'CASHIER'
  AND p.permission_code IN (
      N'dashboard.view', N'products.view', N'sales.view', N'sales.create',
      N'sales.update', N'payments.view', N'notifications.view', N'returns.create',
      N'returns.view', N'inventory.view', N'credit_sales.view'
  )
  AND NOT EXISTS (
      SELECT 1 FROM dbo.role_permissions rp
      WHERE rp.role_id = r.role_id AND rp.permission_id = p.permission_id
  );
GO

/* --------------------------------------------------------------------------
   4. USERS + PASSWORD HISTORY
   --------------------------------------------------------------------------
   Bootstrap users. All have must_change_password = 1 so the first login
   forces a password change. The password_hash values are PLACEHOLDERS the
   installer/backend must replace with real bcrypt hashes before first login.
   -------------------------------------------------------------------------- */
INSERT INTO dbo.users
    (username, email, password_hash, full_name, phone, role_id, is_active, is_locked,
     failed_login_attempts, must_change_password, created_at, updated_at, created_by, updated_by)
SELECT v.username, v.email, v.password_hash, v.full_name, v.phone, r.role_id,
       1, 0, 0, 1, SYSUTCDATETIME(), SYSUTCDATETIME(), NULL, NULL
FROM (VALUES
    (N'admin',   N'admin@smartpos.local',
     N'$2b$12$CHANGE_ME_ADMIN_PASSWORD_HASH_ON_INSTALL',   N'System Administrator', N'+1-555-0100', N'ADMIN'),
    (N'cashier', N'cashier@smartpos.local',
     N'$2b$12$CHANGE_ME_CASHIER_PASSWORD_HASH_ON_INSTALL', N'Cashier User',         N'+1-555-0101', N'CASHIER'),
    (N'manager', N'manager@smartpos.local',
     N'$2b$12$CHANGE_ME_MANAGER_PASSWORD_HASH_ON_INSTALL', N'Store Manager',        N'+1-555-0102', N'MANAGER')
) AS v(username, email, password_hash, full_name, phone, role_code)
JOIN dbo.roles r ON r.role_code = v.role_code
WHERE NOT EXISTS (
    SELECT 1 FROM dbo.users u
    WHERE u.username = v.username OR u.email = v.email
);

-- First password-history entry for each bootstrap user (mirrors SP_CreateUser).
INSERT INTO dbo.password_history (user_id, password_hash, changed_at, changed_by)
SELECT u.user_id, u.password_hash, u.created_at, u.user_id
FROM dbo.users u
WHERE u.username IN (N'admin', N'cashier', N'manager')
  AND NOT EXISTS (
      SELECT 1 FROM dbo.password_history ph
      WHERE ph.user_id = u.user_id
  );
GO

/* --------------------------------------------------------------------------
   5. BUSINESS INFORMATION (single-row profile)
   -------------------------------------------------------------------------- */
INSERT INTO dbo.business_information
    (business_name, legal_name, tax_id, city, country, phone, email, website,
     currency_code, timezone, is_active, created_at, updated_at, created_by, updated_by)
SELECT N'SmartPOS Store', N'SmartPOS Inc.', N'CHANGE_ME_TAX_ID', N'Springfield',
       N'USA', N'+1-555-0100', N'hello@smartpos.local', N'https://www.smartpos.local',
       N'USD', N'UTC', 1, SYSUTCDATETIME(), SYSUTCDATETIME(), NULL, NULL
WHERE NOT EXISTS (SELECT 1 FROM dbo.business_information);
GO

/* --------------------------------------------------------------------------
   6. CURRENCIES
   -------------------------------------------------------------------------- */
INSERT INTO dbo.currencies
    (currency_code, currency_name, symbol, decimal_places, is_base, is_active, created_at, updated_at)
SELECT v.currency_code, v.currency_name, v.symbol, 2, v.is_base, 1, SYSUTCDATETIME(), SYSUTCDATETIME()
FROM (VALUES
    (N'USD', N'US Dollar',       N'$',   1),
    (N'GHS', N'Ghana Cedi',      N'GH₵', 0),
    (N'EUR', N'Euro',            N'€',   0),
    (N'GBP', N'British Pound',   N'£',   0),
    (N'NGN', N'Nigerian Naira',  N'₦',   0)
) AS v(currency_code, currency_name, symbol, is_base)
WHERE NOT EXISTS (
    SELECT 1 FROM dbo.currencies c
    WHERE c.currency_code = v.currency_code
);
GO

/* --------------------------------------------------------------------------
   7. TAX RATES
   -------------------------------------------------------------------------- */
INSERT INTO dbo.tax_rates
    (tax_name, tax_code, rate_percent, is_default, is_active, created_at, updated_at)
SELECT v.tax_name, v.tax_code, v.rate_percent, v.is_default, 1, SYSUTCDATETIME(), SYSUTCDATETIME()
FROM (VALUES
    (N'No Tax',         N'NONE',          0.0000, 1),
    (N'Standard VAT',   N'VAT_STANDARD',  7.5000, 0),
    (N'Zero Rated VAT', N'VAT_ZERO',      0.0000, 0)
) AS v(tax_name, tax_code, rate_percent, is_default)
WHERE NOT EXISTS (
    SELECT 1 FROM dbo.tax_rates t
    WHERE t.tax_code = v.tax_code
);
GO

/* --------------------------------------------------------------------------
   8. CATEGORIES (top-level only; child categories are sample data)
   -------------------------------------------------------------------------- */
INSERT INTO dbo.categories
    (category_name, parent_id, [description], sort_order, is_active, is_deleted,
     created_at, updated_at, created_by, updated_by)
SELECT v.category_name, NULL, v.[description], v.sort_order, 1, 0,
       SYSUTCDATETIME(), SYSUTCDATETIME(),
       (SELECT TOP (1) u.user_id FROM dbo.users u WHERE u.username = N'admin'), NULL
FROM (VALUES
    (N'Beverages',         N'Drinks and beverages',          1),
    (N'Food',              N'Perishable and packaged food',  2),
    (N'Electronics',       N'Electronic devices and cables', 3),
    (N'Office Supplies',   N'Office stationery and supplies',4),
    (N'Cleaning Supplies', N'Household cleaning products',   5)
) AS v(category_name, [description], sort_order)
WHERE NOT EXISTS (
    SELECT 1 FROM dbo.categories c
    WHERE c.category_name = v.category_name AND c.parent_id IS NULL
);
GO

/* --------------------------------------------------------------------------
   9. SUPPLIERS
   -------------------------------------------------------------------------- */
INSERT INTO dbo.suppliers
    (supplier_code, supplier_name, contact_person, email, phone, city, [state], country,
     is_active, is_deleted, created_at, updated_at, created_by, updated_by)
SELECT v.supplier_code, v.supplier_name, v.contact_person, v.email, v.phone, v.city, v.[state], v.country,
       1, 0, SYSUTCDATETIME(), SYSUTCDATETIME(),
       (SELECT TOP (1) u.user_id FROM dbo.users u WHERE u.username = N'admin'), NULL
FROM (VALUES
    (N'SUP-001', N'Global Distributors', N'Alice Johnson',  N'sales@globaldistributors.com', N'+1-555-0200', N'Chicago',  N'IL', N'USA'),
    (N'SUP-002', N'Local Market',        N'Carlos Mendez',  N'orders@localmarket.com',       N'+1-555-0201', N'Denver',   N'CO', N'USA'),
    (N'SUP-003', N'Tech Wholesale',      N'Sarah Chen',     N'contact@techwholesale.com',    N'+1-555-0202', N'San Jose', N'CA', N'USA')
) AS v(supplier_code, supplier_name, contact_person, email, phone, city, [state], country)
WHERE NOT EXISTS (
    SELECT 1 FROM dbo.suppliers s
    WHERE s.supplier_code = v.supplier_code
);
GO

/* --------------------------------------------------------------------------
   10. PAYMENT METHODS
   -------------------------------------------------------------------------- */
INSERT INTO dbo.payment_methods
    (method_code, method_name, is_cash, is_active, sort_order, created_at, updated_at)
SELECT v.method_code, v.method_name, v.is_cash, 1, v.sort_order, SYSUTCDATETIME(), SYSUTCDATETIME()
FROM (VALUES
    (N'CASH',          N'Cash',          1, 1),
    (N'CARD',          N'Card',          0, 2),
    (N'MOBILE',        N'Mobile Money',  0, 3),
    (N'BANK_TRANSFER', N'Bank Transfer', 0, 4)
) AS v(method_code, method_name, is_cash, sort_order)
WHERE NOT EXISTS (
    SELECT 1 FROM dbo.payment_methods pm
    WHERE pm.method_code = v.method_code
);
GO

/* --------------------------------------------------------------------------
   11. RETURN REASONS
   -------------------------------------------------------------------------- */
INSERT INTO dbo.return_reasons (reason_code, reason_name, is_active, created_at)
SELECT v.reason_code, v.reason_name, 1, SYSUTCDATETIME()
FROM (VALUES
    (N'DEFECTIVE',               N'Defective / faulty product'),
    (N'WRONG_ITEM',              N'Wrong item delivered'),
    (N'NOT_AS_DESCRIBED',        N'Product not as described'),
    (N'CUSTOMER_CHANGE_OF_MIND', N'Customer changed their mind'),
    (N'DAMAGED',                 N'Product damaged in transit')
) AS v(reason_code, reason_name)
WHERE NOT EXISTS (
    SELECT 1 FROM dbo.return_reasons rr
    WHERE rr.reason_code = v.reason_code
);
GO

/* --------------------------------------------------------------------------
   12. NOTIFICATION TYPES
   -------------------------------------------------------------------------- */
INSERT INTO dbo.notification_types (type_code, type_name, [description], is_active)
SELECT v.type_code, v.type_name, v.[description], 1
FROM (VALUES
    (N'LOW_STOCK', N'Low Stock', N'Alerts raised when stock drops to or below the reorder threshold'),
    (N'SALE',      N'Sale',      N'Sale-related notifications'),
    (N'RETURN',    N'Return',    N'Return-related notifications'),
    (N'CREDIT',    N'Credit',    N'Credit sale and credit payment notifications'),
    (N'SYSTEM',    N'System',    N'System and maintenance notifications'),
    (N'SECURITY',  N'Security',  N'Security and authentication notifications')
) AS v(type_code, type_name, [description])
WHERE NOT EXISTS (
    SELECT 1 FROM dbo.notification_types nt
    WHERE nt.type_code = v.type_code
);
GO

/* --------------------------------------------------------------------------
   13. APPLICATION SETTINGS
   --------------------------------------------------------------------------
   data_type is restricted by CK_settings_data_type to:
     string / int / decimal / bool / json
   default_tax_rate_id is resolved from the tax_rates table by code so it is
   correct regardless of identity values (VAT_STANDARD).
   -------------------------------------------------------------------------- */
INSERT INTO dbo.settings
    (setting_key, setting_value, data_type, category, [description], is_active,
     created_at, updated_at, created_by, updated_by)
SELECT v.setting_key, v.setting_value, v.data_type, v.category, v.[description], 1,
       SYSUTCDATETIME(), SYSUTCDATETIME(), NULL, NULL
FROM (VALUES
    (N'currency_symbol',                N'$',                                                N'string', N'general',       N'Symbol displayed next to amounts across the UI and receipts'),
    (N'currency_code',                  N'USD',                                              N'string', N'general',       N'ISO currency code used across the entire application'),
    (N'currency_locale',                N'en-US',                                            N'string', N'general',       N'Locale used for currency formatting'),
    (N'business_name',                  N'SmartPOS Store',                                   N'string', N'general',       N'Display name of the business'),
    (N'timezone',                       N'UTC',                                              N'string', N'general',       N'Timezone used for timestamps and reports'),
    (N'receipt_footer',                 N'Thank you for your business!',                     N'string', N'general',       N'Text printed at the bottom of every receipt'),
    (N'default_tax_rate_id',            (SELECT CAST(tax_rate_id AS NVARCHAR(20)) FROM dbo.tax_rates WHERE tax_code = N'VAT_STANDARD'), N'int', N'tax', N'Default tax rate applied to new sales'),
    (N'low_stock_threshold_default',    N'10',                                               N'int',    N'notifications', N'Default low-stock threshold for newly created products'),
    (N'low_stock_notification_enabled', N'true',                                             N'bool',   N'notifications', N'Master switch for low-stock alert notifications'),
    (N'receipt_show_tax',               N'true',                                             N'bool',   N'receipt',       N'Show tax breakdown on receipts'),
    (N'receipt_show_discount',          N'true',                                             N'bool',   N'receipt',       N'Show discount lines on receipts'),
    (N'session_timeout_minutes',        N'60',                                               N'int',    N'system',        N'Idle session timeout in minutes'),
    (N'lockout_threshold',              N'5',                                                N'int',    N'system',        N'Failed login attempts before account lockout'),
    (N'password_history_count',         N'5',                                                N'int',    N'system',        N'Number of previous password hashes retained to prevent reuse')
) AS v(setting_key, setting_value, data_type, category, [description])
WHERE NOT EXISTS (
    SELECT 1 FROM dbo.settings s
    WHERE s.setting_key = v.setting_key
);
GO

/* ==========================================================================
   END OF SEED DATA

   Expected row counts (fresh install):
     permissions         50        role_permissions  95 (ADMIN 50 / MANAGER 34 / CASHIER 11)
     roles                3        users             3
     password_history     3        business_information  1
     currencies           5        tax_rates         3
     categories           5        suppliers         3
     payment_methods      4        return_reasons    5
     notification_types   6        settings         14
   ========================================================================== */
