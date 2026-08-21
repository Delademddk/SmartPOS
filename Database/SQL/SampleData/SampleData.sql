/* ==========================================================================
   SmartPOS Database - SAMPLE DATA (OPTIONAL / ILLUSTRATIVE)
   --------------------------------------------------------------------------
   File:    SampleData/SampleData.sql
   Scope:   Optional development / testing data. This file is NOT required at
            runtime. It should be run AFTER SeedData.sql and after the stored
            procedures (SP_CreateSale, SP_ProcessReturn) are deployed, because
            sales and returns are created through those procedures to keep
            inventory and stock movements consistent.

   Contains:
     - Child categories (Soft Drinks, Snacks, Peripherals)
     - 15 products with realistic SKUs, prices and low-stock thresholds
     - Matching inventory rows (quantity_on_hand / reorder_level)
     - Supplier contacts, customers
     - 3 sample sales via dbo.SP_CreateSale (CASH, CARD, CREDIT)
     - 1 sample return via dbo.SP_ProcessReturn (on the credit sale)
     - Sample settings overrides, notifications, and audit/activity/security
       log entries

   Idempotency: every section is guarded with NOT EXISTS so re-running the
   file (or running it against a database that already has sample data) will
   not create duplicates. SP_CreateSale / SP_ProcessReturn calls are skipped
   when their receipt / return number already exists.
   ========================================================================== */

SET NOCOUNT ON;
GO

/* --------------------------------------------------------------------------
   A. ADDITIONAL CATEGORIES (children)
   -------------------------------------------------------------------------- */
INSERT INTO dbo.categories
    (category_name, parent_id, [description], sort_order, is_active, is_deleted,
     created_at, updated_at, created_by, updated_by)
SELECT v.category_name, parent.category_id, v.[description], v.sort_order, 1, 0,
       SYSUTCDATETIME(), SYSUTCDATETIME(),
       (SELECT TOP (1) u.user_id FROM dbo.users u WHERE u.username = N'admin'), NULL
FROM (VALUES
    (N'Soft Drinks', N'Beverages',   N'Carbonated and non-carbonated soft drinks',  1),
    (N'Snacks',      N'Food',        N'Snacks and confectionery',                   2),
    (N'Peripherals', N'Electronics', N'Computer and device peripherals',            3)
) AS v(category_name, parent_category_name, [description], sort_order)
JOIN dbo.categories parent ON parent.category_name = v.parent_category_name AND parent.parent_id IS NULL
WHERE NOT EXISTS (
    SELECT 1
    FROM dbo.categories c
    JOIN dbo.categories parent2 ON parent2.category_id = c.parent_id
    WHERE c.category_name = v.category_name AND parent2.category_name = v.parent_category_name
);
GO

/* --------------------------------------------------------------------------
   B. PRODUCTS (15)
   -------------------------------------------------------------------------- */
INSERT INTO dbo.products
    (sku, barcode, product_name, [description], category_id, supplier_id, unit,
     unit_price, cost_price, low_stock_threshold, is_service, is_active, is_deleted,
     created_at, updated_at, created_by, updated_by)
SELECT v.sku, v.barcode, v.product_name, v.[description],
       cat.category_id, sup.supplier_id, v.unit, v.unit_price, v.cost_price,
       v.low_stock_threshold, 0, 1, 0, SYSUTCDATETIME(), SYSUTCDATETIME(),
       (SELECT TOP (1) u.user_id FROM dbo.users u WHERE u.username = N'admin'), NULL
FROM (VALUES
    (N'BEV-001', N'1000000000001', N'Cola 330ml',              N'Classic cola soft drink, 330ml can',                N'Soft Drinks',      N'SUP-001', N'can',   1.5000, 0.9000, 50),
    (N'BEV-002', N'1000000000002', N'Spring Water 500ml',      N'Still spring water, 500ml bottle',                  N'Soft Drinks',      N'SUP-001', N'bottle',1.0000, 0.4000, 50),
    (N'BEV-003', N'1000000000003', N'Orange Juice 1L',         N'Pasteurised orange juice, 1L carton',                N'Soft Drinks',      N'SUP-002', N'carton',3.0000, 1.8000, 30),
    (N'FOD-001', N'1000000000004', N'White Bread Loaf',        N'Fresh white bread loaf, 600g',                      N'Food',             N'SUP-002', N'loaf',  2.5000, 1.5000, 20),
    (N'FOD-002', N'1000000000005', N'Milk Chocolate Bar',      N'Milk chocolate bar, 100g',                          N'Snacks',           N'SUP-001', N'bar',   1.2500, 0.7000, 30),
    (N'FOD-003', N'1000000000006', N'Potato Chips 150g',       N'Salted potato chips, 150g bag',                     N'Snacks',           N'SUP-002', N'bag',   2.0000, 1.1000, 30),
    (N'ELC-001', N'1000000000007', N'HDMI Cable 2m',           N'High-speed HDMI cable, 2m',                         N'Peripherals',      N'SUP-003', N'pcs',   9.9900, 5.5000, 10),
    (N'ELC-002', N'1000000000008', N'USB-C Fast Charger',      N'USB-C 20W wall charger',                            N'Electronics',      N'SUP-003', N'pcs',   15.0000, 8.0000, 10),
    (N'ELC-003', N'1000000000009', N'Wireless Mouse',          N'2.4GHz wireless optical mouse',                     N'Peripherals',      N'SUP-003', N'pcs',   12.5000, 7.2500, 10),
    (N'OFC-001', N'1000000000010', N'A4 Copy Paper Ream',      N'A4 80gsm copy paper, 500 sheets',                   N'Office Supplies',  N'SUP-001', N'ream',  5.0000, 3.2000, 20),
    (N'OFC-002', N'1000000000011', N'Ballpoint Pens (Box 12)', N'Blue ballpoint pens, box of 12',                    N'Office Supplies',  N'SUP-001', N'box',   4.5000, 2.6000, 15),
    (N'OFC-003', N'1000000000012', N'Sticky Notes (3-Pack)',   N'Yellow sticky notes, 3 x 100 sheets',               N'Office Supplies',  N'SUP-002', N'pack',  2.2500, 1.2000, 20),
    (N'CLN-001', N'1000000000013', N'Dish Soap 500ml',         N'Lemon-scented dish soap, 500ml bottle',              N'Cleaning Supplies',N'SUP-002', N'bottle',3.5000, 2.0000, 15),
    (N'CLN-002', N'1000000000014', N'All-Purpose Cleaner 750ml', N'Multi-surface cleaner, 750ml spray bottle',        N'Cleaning Supplies',N'SUP-002', N'bottle',4.7500, 2.8000, 15),
    (N'CLN-003', N'1000000000015', N'Paper Towels (6-Pack)',   N'Paper towel rolls, pack of 6',                      N'Cleaning Supplies',N'SUP-001', N'pack',  6.5000, 3.9000, 10)
) AS v(sku, barcode, product_name, [description], category_name, supplier_code, unit,
       unit_price, cost_price, low_stock_threshold)
JOIN dbo.categories cat ON cat.category_name = v.category_name
JOIN dbo.suppliers sup ON sup.supplier_code = v.supplier_code
WHERE NOT EXISTS (
    SELECT 1 FROM dbo.products p WHERE p.sku = v.sku
);
GO

/* --------------------------------------------------------------------------
   C. INVENTORY (one row per product)
   -------------------------------------------------------------------------- */
INSERT INTO dbo.inventory
    (product_id, quantity_on_hand, quantity_reserved, reorder_level,
     last_restocked_at, last_sold_at, updated_at)
SELECT p.product_id, v.quantity_on_hand, 0, v.reorder_level,
       CAST(N'2026-08-01T08:00:00' AS DATETIME2(0)), NULL, SYSUTCDATETIME()
FROM (VALUES
    (N'BEV-001', 120, 50),
    (N'BEV-002',  80, 50),
    (N'BEV-003',  45, 30),
    (N'FOD-001',  30, 20),
    (N'FOD-002',  60, 30),
    (N'FOD-003',  25, 30),
    (N'ELC-001',   8, 10),
    (N'ELC-002',  15, 10),
    (N'ELC-003',   6, 10),
    (N'OFC-001',  40, 20),
    (N'OFC-002',  20, 15),
    (N'OFC-003',  12, 20),
    (N'CLN-001',  18, 15),
    (N'CLN-002',  10, 15),
    (N'CLN-003',  14, 10)
) AS v(sku, quantity_on_hand, reorder_level)
JOIN dbo.products p ON p.sku = v.sku
WHERE NOT EXISTS (
    SELECT 1 FROM dbo.inventory i WHERE i.product_id = p.product_id
);
GO

/* --------------------------------------------------------------------------
   D. SUPPLIER CONTACTS
   -------------------------------------------------------------------------- */
INSERT INTO dbo.supplier_contacts
    (supplier_id, full_name, job_title, email, phone, is_primary, is_active, created_at, updated_at)
SELECT s.supplier_id, v.full_name, v.job_title, v.email, v.phone, v.is_primary, 1,
       SYSUTCDATETIME(), SYSUTCDATETIME()
FROM (VALUES
    (N'SUP-001', N'Alice Johnson',  N'Account Manager',       N'alice.johnson@globaldistributors.com', N'+1-555-0200', 1),
    (N'SUP-001', N'Mark Roberts',   N'Dispatch Coordinator',  N'mark.roberts@globaldistributors.com',  N'+1-555-0203', 0),
    (N'SUP-002', N'Carlos Mendez',  N'Owner',                 N'carlos@localmarket.com',               N'+1-555-0201', 1),
    (N'SUP-003', N'Sarah Chen',     N'Technical Sales',       N'sarah.chen@techwholesale.com',        N'+1-555-0202', 1)
) AS v(supplier_code, full_name, job_title, email, phone, is_primary)
JOIN dbo.suppliers s ON s.supplier_code = v.supplier_code
WHERE NOT EXISTS (
    SELECT 1 FROM dbo.supplier_contacts sc
    WHERE sc.supplier_id = s.supplier_id AND sc.full_name = v.full_name
);
GO

/* --------------------------------------------------------------------------
   E. CUSTOMERS (credit customers)
   -------------------------------------------------------------------------- */
INSERT INTO dbo.customers
    (customer_code, full_name, phone, email, address, credit_limit, is_active, is_deleted,
     created_at, updated_at, created_by, updated_by)
SELECT v.customer_code, v.full_name, v.phone, v.email, v.address, v.credit_limit, 1, 0,
       SYSUTCDATETIME(), SYSUTCDATETIME(),
       (SELECT TOP (1) u.user_id FROM dbo.users u WHERE u.username = N'admin'), NULL
FROM (VALUES
    (N'CUST-001', N'Jane Cooper',  N'+1-555-0300', N'jane.cooper@example.com',  N'45 Maple Street, Springfield', 500.0000),
    (N'CUST-002', N'John Smith',   N'+1-555-0301', N'john.smith@example.com',   N'12 Oak Avenue, Riverside',     250.0000),
    (N'CUST-003', N'Maria Garcia', N'+1-555-0302', N'maria.garcia@example.com', N'88 Cedar Lane, Brookfield',   1000.0000)
) AS v(customer_code, full_name, phone, email, address, credit_limit)
WHERE NOT EXISTS (
    SELECT 1 FROM dbo.customers cu WHERE cu.customer_code = v.customer_code
);
GO

/* --------------------------------------------------------------------------
   F. SAMPLE SALES (via dbo.SP_CreateSale)
   --------------------------------------------------------------------------
   Product ids are resolved from the products table by SKU and injected into
   the JSON lines so the calls always reference valid products. Each call is
   skipped when its receipt number already exists.
   -------------------------------------------------------------------------- */

-- Sale 1: CASH - RCP-1001 (2 x Cola, 1 x White Bread)
IF NOT EXISTS (SELECT 1 FROM dbo.sales WHERE receipt_number = N'RCP-1001')
BEGIN
    DECLARE @Lines1 NVARCHAR(MAX) = N'[' +
        N'{"productId":' + CAST((SELECT product_id FROM dbo.products WHERE sku = N'BEV-001') AS NVARCHAR(20)) +
            N',"quantity":2,"unitPrice":1.50,"discountRate":0.00,"taxAmount":0.2250},' +
        N'{"productId":' + CAST((SELECT product_id FROM dbo.products WHERE sku = N'FOD-001') AS NVARCHAR(20)) +
            N',"quantity":1,"unitPrice":2.50,"discountRate":0.00,"taxAmount":0.1875}]';

    EXEC dbo.SP_CreateSale
        @ReceiptNumber   = N'RCP-1001',
        @UserID          = (SELECT user_id FROM dbo.users WHERE username = N'cashier'),
        @SaleDate        = N'2026-08-05T09:15:00',
        @TaxRateID       = (SELECT tax_rate_id FROM dbo.tax_rates WHERE tax_code = N'VAT_STANDARD'),
        @SaleType        = N'CASH',
        @LinesJSON       = @Lines1,
        @AmountReceived  = 5.9100,
        @PaymentMethodID = (SELECT payment_method_id FROM dbo.payment_methods WHERE method_code = N'CASH'),
        @Notes           = N'Sample cash sale seeded from SampleData.sql';
END
GO

-- Sale 2: CARD (CASH sale paid by card) - RCP-1002 (1 x HDMI Cable, 2 x Dish Soap)
IF NOT EXISTS (SELECT 1 FROM dbo.sales WHERE receipt_number = N'RCP-1002')
BEGIN
    DECLARE @Lines2 NVARCHAR(MAX) = N'[' +
        N'{"productId":' + CAST((SELECT product_id FROM dbo.products WHERE sku = N'ELC-001') AS NVARCHAR(20)) +
            N',"quantity":1,"unitPrice":9.99,"discountRate":0.00,"taxAmount":0.7493},' +
        N'{"productId":' + CAST((SELECT product_id FROM dbo.products WHERE sku = N'CLN-001') AS NVARCHAR(20)) +
            N',"quantity":2,"unitPrice":3.50,"discountRate":0.00,"taxAmount":0.5250}]';

    EXEC dbo.SP_CreateSale
        @ReceiptNumber   = N'RCP-1002',
        @UserID          = (SELECT user_id FROM dbo.users WHERE username = N'cashier'),
        @SaleDate        = N'2026-08-05T11:40:00',
        @TaxRateID       = (SELECT tax_rate_id FROM dbo.tax_rates WHERE tax_code = N'VAT_STANDARD'),
        @SaleType        = N'CASH',
        @LinesJSON       = @Lines2,
        @AmountReceived  = 18.2700,
        @PaymentMethodID = (SELECT payment_method_id FROM dbo.payment_methods WHERE method_code = N'CARD'),
        @Notes           = N'Sample card sale seeded from SampleData.sql';
END
GO

-- Sale 3: CREDIT - RCP-1003, customer CUST-001 (5 x Chocolate Bar, 2 x A4 Paper Ream)
IF NOT EXISTS (SELECT 1 FROM dbo.sales WHERE receipt_number = N'RCP-1003')
BEGIN
    DECLARE @Lines3 NVARCHAR(MAX) = N'[' +
        N'{"productId":' + CAST((SELECT product_id FROM dbo.products WHERE sku = N'FOD-002') AS NVARCHAR(20)) +
            N',"quantity":5,"unitPrice":1.25,"discountRate":0.00,"taxAmount":0.4688},' +
        N'{"productId":' + CAST((SELECT product_id FROM dbo.products WHERE sku = N'OFC-001') AS NVARCHAR(20)) +
            N',"quantity":2,"unitPrice":5.00,"discountRate":0.00,"taxAmount":0.7500}]';

    EXEC dbo.SP_CreateSale
        @ReceiptNumber  = N'RCP-1003',
        @UserID         = (SELECT user_id FROM dbo.users WHERE username = N'manager'),
        @SaleDate       = N'2026-08-06T14:05:00',
        @CustomerID     = (SELECT customer_id FROM dbo.customers WHERE customer_code = N'CUST-001'),
        @TaxRateID      = (SELECT tax_rate_id FROM dbo.tax_rates WHERE tax_code = N'VAT_STANDARD'),
        @SaleType       = N'CREDIT',
        @LinesJSON      = @Lines3,
        @AmountReceived = 0,
        @Notes          = N'Sample credit sale for Jane Cooper seeded from SampleData.sql';
END
GO

/* --------------------------------------------------------------------------
   G. SAMPLE RETURN (via dbo.SP_ProcessReturn)
   --------------------------------------------------------------------------
   Returns 2 of the 5 chocolate bars (FOD-002) sold on credit receipt
   RCP-1003. The sale_item_id is resolved from the sale so the reference is
   always valid. Skipped when the return number already exists.
   -------------------------------------------------------------------------- */
IF NOT EXISTS (SELECT 1 FROM dbo.returns WHERE return_number = N'RTR-2001')
BEGIN
    DECLARE @ReturnSaleID    INT = (SELECT sale_id FROM dbo.sales WHERE receipt_number = N'RCP-1003');
    DECLARE @ReturnProductID INT = (SELECT product_id FROM dbo.products WHERE sku = N'FOD-002');
    DECLARE @ReturnItemID    INT = (SELECT TOP (1) si.sale_item_id
                                    FROM dbo.sale_items si
                                    WHERE si.sale_id = @ReturnSaleID AND si.product_id = @ReturnProductID);
    DECLARE @ReturnLines     NVARCHAR(MAX) = N'[' +
        N'{"saleItemId":' + CAST(@ReturnItemID AS NVARCHAR(20)) +
        N',"productId":' + CAST(@ReturnProductID AS NVARCHAR(20)) +
        N',"quantity":2}]';

    EXEC dbo.SP_ProcessReturn
        @ReturnNumber    = N'RTR-2001',
        @SaleID          = @ReturnSaleID,
        @UserID          = (SELECT user_id FROM dbo.users WHERE username = N'manager'),
        @ReturnReasonID  = (SELECT return_reason_id FROM dbo.return_reasons WHERE reason_code = N'DEFECTIVE'),
        @CustomerID      = (SELECT customer_id FROM dbo.customers WHERE customer_code = N'CUST-001'),
        @LinesJSON       = @ReturnLines,
        @Notes           = N'Sample return of two defective chocolate bars (SampleData.sql)';
END
GO

/* --------------------------------------------------------------------------
   H. SAMPLE SETTINGS OVERRIDES (additional illustrative settings)
   -------------------------------------------------------------------------- */
INSERT INTO dbo.settings
    (setting_key, setting_value, data_type, category, [description], is_active,
     created_at, updated_at, created_by, updated_by)
SELECT v.setting_key, v.setting_value, v.data_type, v.category, v.[description], 1,
       SYSUTCDATETIME(), SYSUTCDATETIME(), NULL, NULL
FROM (VALUES
    (N'receipt_show_customer_details', N'false', N'bool',   N'receipt', N'Sample override: hide customer details on receipts'),
    (N'general_receipt_header',        N'SmartPOS Store', N'string', N'general', N'Sample override: custom receipt header text')
) AS v(setting_key, setting_value, data_type, category, [description])
WHERE NOT EXISTS (
    SELECT 1 FROM dbo.settings s WHERE s.setting_key = v.setting_key
);
GO

/* --------------------------------------------------------------------------
   I. SAMPLE NOTIFICATIONS
   -------------------------------------------------------------------------- */
INSERT INTO dbo.notifications
    (user_id, notification_type_id, title, [message], severity, entity_type,
     entity_id, is_read, is_dismissed, created_at)
SELECT u.user_id, nt.notification_type_id, v.title, v.[message], v.severity, v.entity_type,
       v.entity_id, 0, 0, CAST(v.created_at AS DATETIME2(0))
FROM (VALUES
    (N'admin',   N'LOW_STOCK', N'Low stock alert: HDMI Cable 2m',
     N'Product "HDMI Cable 2m" has 8 unit(s) on hand, at or below the restock threshold of 10. Please restock soon.',
     N'WARNING', N'Product',   NULL,            N'2026-08-05T12:00:00'),
    (N'cashier', N'SALE',      N'Sale completed: RCP-1002',
     N'Card sale receipt RCP-1002 totalled 18.2643.',
     N'INFO',    N'Sale',      N'RCP-1002',     N'2026-08-05T11:40:00'),
    (N'manager', N'CREDIT',    N'Credit sale opened: RCP-1003',
     N'Jane Cooper (CUST-001) opened a credit balance of 17.4688 against receipt RCP-1003.',
     N'INFO',    N'CreditSale', N'RCP-1003',    N'2026-08-06T14:05:00')
) AS v(username, type_code, title, [message], severity, entity_type, entity_id, created_at)
JOIN dbo.users u ON u.username = v.username
JOIN dbo.notification_types nt ON nt.type_code = v.type_code
WHERE NOT EXISTS (
    SELECT 1 FROM dbo.notifications n
    WHERE n.title = v.title AND n.created_at = CAST(v.created_at AS DATETIME2(0))
);
GO

/* --------------------------------------------------------------------------
   J. SAMPLE AUDIT / ACTIVITY / SECURITY / ERROR LOGS
   -------------------------------------------------------------------------- */

-- Audit logs
INSERT INTO dbo.audit_logs
    (user_id, action_type, resource_type, resource_id, old_values, new_values,
     ip_address, user_agent, details, created_at)
SELECT u.user_id, v.action_type, v.resource_type, v.resource_id, NULL, v.new_values,
       v.ip_address, NULL, v.details, CAST(v.created_at AS DATETIME2(0))
FROM (VALUES
    (N'admin',   N'INSERT', N'Supplier', N'SUP-001', N'{"supplier_code":"SUP-001","supplier_name":"Global Distributors"}',
     N'192.168.1.10', N'Supplier Global Distributors created via sample seed.',        N'2026-08-01T09:00:00'),
    (N'admin',   N'INSERT', N'Product',  N'BEV-001', N'{"sku":"BEV-001","product_name":"Cola 330ml"}',
     N'192.168.1.10', N'Product Cola 330ml created via sample seed.',                  N'2026-08-01T09:05:00'),
    (N'manager', N'UPDATE', N'Product',  N'ELC-001', N'{"sku":"ELC-001","unit_price":9.9900}',
     N'192.168.1.22', N'Updated unit price of HDMI Cable 2m.',                         N'2026-08-04T15:30:00')
) AS v(username, action_type, resource_type, resource_id, new_values, ip_address, details, created_at)
JOIN dbo.users u ON u.username = v.username
WHERE NOT EXISTS (
    SELECT 1 FROM dbo.audit_logs al
    WHERE al.action_type = v.action_type
      AND al.resource_type = v.resource_type
      AND al.resource_id = v.resource_id
      AND al.created_at = CAST(v.created_at AS DATETIME2(0))
);

-- Activity logs
INSERT INTO dbo.activity_logs
    (user_id, activity_type, activity_desc, entity_type, entity_id, [metadata], ip_address, created_at)
SELECT u.user_id, v.activity_type, v.activity_desc, v.entity_type, v.entity_id, v.[metadata], v.ip_address, CAST(v.created_at AS DATETIME2(0))
FROM (VALUES
    (N'admin',   N'USER_LOGIN',            N'User logged in',               N'User', N'admin',     N'{"result":"success"}', N'192.168.1.10', N'2026-08-05T08:00:00'),
    (N'cashier', N'SALE_CREATED',          N'Created sale RCP-1001',        N'Sale', N'RCP-1001',  N'{"sale_type":"CASH"}', N'192.168.1.21', N'2026-08-05T09:15:00'),
    (N'manager', N'CREDIT_SALE_CREATED',   N'Created credit sale RCP-1003', N'Sale', N'RCP-1003',  N'{"customer":"CUST-001"}', N'192.168.1.22', N'2026-08-06T14:05:00')
) AS v(username, activity_type, activity_desc, entity_type, entity_id, [metadata], ip_address, created_at)
JOIN dbo.users u ON u.username = v.username
WHERE NOT EXISTS (
    SELECT 1 FROM dbo.activity_logs al
    WHERE al.activity_type = v.activity_type
      AND al.entity_id = v.entity_id
      AND al.created_at = CAST(v.created_at AS DATETIME2(0))
);

-- Security logs
INSERT INTO dbo.security_logs
    (user_id, event_type, username, ip_address, user_agent, [message], created_at)
SELECT u.user_id, v.event_type, v.log_username, v.ip_address, NULL, v.[message], CAST(v.created_at AS DATETIME2(0))
FROM (VALUES
    (N'admin',   N'LOGIN_SUCCESS', N'admin',   N'192.168.1.10', N'Admin login succeeded.',   N'2026-08-05T08:00:00'),
    (N'cashier', N'LOGIN_SUCCESS', N'cashier', N'192.168.1.21', N'Cashier login succeeded.', N'2026-08-05T09:10:00'),
    (N'manager', N'LOGIN_FAILED',  N'manager', N'192.168.1.22', N'Invalid password attempt.', N'2026-08-06T13:59:00')
) AS v(username, event_type, log_username, ip_address, [message], created_at)
JOIN dbo.users u ON u.username = v.username
WHERE NOT EXISTS (
    SELECT 1 FROM dbo.security_logs sl
    WHERE sl.event_type = v.event_type
      AND sl.username = v.log_username
      AND sl.created_at = CAST(v.created_at AS DATETIME2(0))
);

-- Error logs
INSERT INTO dbo.error_logs
    (user_id, error_code, [message], stack_trace, [source], http_status, ip_address, occurred_at)
SELECT u.user_id, v.error_code, v.[message], v.stack_trace, v.[source], v.http_status, v.ip_address, CAST(v.occurred_at AS DATETIME2(0))
FROM (VALUES
    (N'cashier', N'SP_CreateSale', N'Insufficient stock for product 8.', NULL, N'SP_CreateSale', 400, N'192.168.1.21', N'2026-08-05T10:02:00')
) AS v(username, error_code, [message], stack_trace, [source], http_status, ip_address, occurred_at)
JOIN dbo.users u ON u.username = v.username
WHERE NOT EXISTS (
    SELECT 1 FROM dbo.error_logs el
    WHERE el.error_code = v.error_code
      AND el.occurred_at = CAST(v.occurred_at AS DATETIME2(0))
);
GO

/* ==========================================================================
   END OF SAMPLE DATA

   Expected row counts (fresh run over a freshly seeded database):
     categories             +3 (Soft Drinks, Snacks, Peripherals)
     products               15
     inventory              15
     supplier_contacts       4
     customers               3
     sales                   3 (via SP_CreateSale)
     returns                 1 (via SP_ProcessReturn)
     settings                +2
     notifications           3
     audit_logs              3
     activity_logs           3
     security_logs           3
     error_logs              1

   Plus side effects produced by the stored procedures:
     payments               2 (CASH for RCP-1001, CARD for RCP-1002)
     inventory_transactions 7 (6 SALE movements: 2 lines x RCP-1001, 2 lines x RCP-1002,
                               2 lines x RCP-1003; plus 1 RETURN movement for RTR-2001)
     credit_sales           1 (RCP-1003 / CUST-001)
     return_items           1 (2 x FOD-002)
   ========================================================================== */
