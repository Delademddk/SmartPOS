/* ==========================================================================
   SmartPOS Database - CORE OPERATIONAL VIEWS
   --------------------------------------------------------------------------
   Views consumed by the API and by the Reports/Dashboard modules.
     VW_UserPermissions     - effective permissions per active user
     VW_ProductStock        - current stock snapshot with status
     VW_SalesWithLines      - denormalized sales header + items
     VW_CustomerBalances    - outstanding credit per customer
     VW_LowStock            - products at or below threshold
   ========================================================================== */

-- ---------------------------------------------------------------------------
-- VW_UserPermissions
-- ---------------------------------------------------------------------------
IF OBJECT_ID(N'dbo.VW_UserPermissions', N'V') IS NOT NULL DROP VIEW dbo.VW_UserPermissions;
GO
CREATE VIEW dbo.VW_UserPermissions
AS
    SELECT
        u.user_id,
        u.username,
        u.full_name,
        r.role_id,
        r.role_code,
        r.role_name,
        p.permission_id,
        p.permission_code,
        p.module_name
    FROM dbo.users u
    JOIN dbo.roles r            ON r.role_id = u.role_id
    JOIN dbo.role_permissions rp ON rp.role_id = r.role_id
    JOIN dbo.permissions p       ON p.permission_id = rp.permission_id
    WHERE u.is_active = 1
      AND u.is_deleted = 0
      AND r.is_active = 1
      AND p.is_active = 1;
GO

-- ---------------------------------------------------------------------------
-- VW_ProductStock
-- ---------------------------------------------------------------------------
IF OBJECT_ID(N'dbo.VW_ProductStock', N'V') IS NOT NULL DROP VIEW dbo.VW_ProductStock;
GO
CREATE VIEW dbo.VW_ProductStock
AS
    SELECT
        p.product_id,
        p.sku,
        p.barcode,
        p.product_name,
        p.category_id,
        c.category_name,
        p.supplier_id,
        s.supplier_name,
        p.unit_price,
        p.cost_price,
        i.quantity_on_hand,
        i.quantity_reserved,
        p.low_stock_threshold,
        dbo.FN_StockStatus(i.quantity_on_hand, p.low_stock_threshold) AS stock_status,
        p.is_active,
        p.is_deleted
    FROM dbo.products p
    LEFT JOIN dbo.categories c ON c.category_id = p.category_id
    LEFT JOIN dbo.suppliers  s ON s.supplier_id = p.supplier_id
    LEFT JOIN dbo.inventory  i ON i.product_id = p.product_id
    WHERE p.is_deleted = 0;
GO

-- ---------------------------------------------------------------------------
-- VW_SalesWithLines
-- ---------------------------------------------------------------------------
IF OBJECT_ID(N'dbo.VW_SalesWithLines', N'V') IS NOT NULL DROP VIEW dbo.VW_SalesWithLines;
GO
CREATE VIEW dbo.VW_SalesWithLines
AS
    SELECT
        s.sale_id,
        s.receipt_number,
        s.sale_date,
        s.user_id,
        u.full_name AS cashier_name,
        s.customer_id,
        cu.full_name AS customer_name,
        s.sale_type,
        s.subtotal,
        s.discount_amount,
        s.tax_amount,
        s.total_amount,
        s.amount_received,
        s.status,
        si.sale_item_id,
        si.product_id,
        p.product_name,
        p.sku,
        si.quantity,
        si.unit_price,
        si.discount_rate,
        si.tax_amount AS line_tax,
        si.line_total
    FROM dbo.sales s
    JOIN dbo.users u        ON u.user_id = s.user_id
    LEFT JOIN dbo.customers cu ON cu.customer_id = s.customer_id
    LEFT JOIN dbo.sale_items si ON si.sale_id = s.sale_id
    LEFT JOIN dbo.products p    ON p.product_id = si.product_id;
GO

-- ---------------------------------------------------------------------------
-- VW_CustomerBalances
-- ---------------------------------------------------------------------------
IF OBJECT_ID(N'dbo.VW_CustomerBalances', N'V') IS NOT NULL DROP VIEW dbo.VW_CustomerBalances;
GO
CREATE VIEW dbo.VW_CustomerBalances
AS
    SELECT
        cs.credit_sale_id,
        cs.sale_id,
        cs.customer_id,
        c.full_name AS customer_name,
        c.phone     AS customer_phone,
        cs.total_amount,
        cs.amount_paid,
        cs.outstanding_balance,
        cs.due_date,
        cs.status,
        cs.created_at
    FROM dbo.credit_sales cs
    JOIN dbo.customers c ON c.customer_id = cs.customer_id;
GO

-- ---------------------------------------------------------------------------
-- VW_LowStock
-- ---------------------------------------------------------------------------
IF OBJECT_ID(N'dbo.VW_LowStock', N'V') IS NOT NULL DROP VIEW dbo.VW_LowStock;
GO
CREATE VIEW dbo.VW_LowStock
AS
    SELECT
        p.product_id,
        p.sku,
        p.product_name,
        i.quantity_on_hand,
        p.low_stock_threshold,
        dbo.FN_StockStatus(i.quantity_on_hand, p.low_stock_threshold) AS stock_status
    FROM dbo.products p
    LEFT JOIN dbo.inventory i ON i.product_id = p.product_id
    WHERE p.is_deleted = 0
      AND i.quantity_on_hand <= p.low_stock_threshold;
GO