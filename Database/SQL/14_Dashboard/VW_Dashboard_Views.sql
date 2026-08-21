/* ==========================================================================
   SmartPOS Database - MODULE 14: DASHBOARD VIEWS
   --------------------------------------------------------------------------
   Dashboard views consumed by the Dashboard module (SP_Dashboard.sql) and by
   the API dashboard screens.

   Conventions:
     - View names: VW_<Purpose>.
     - Money columns are DECIMAL(19,4); dates DATETIME2(0) stored UTC.
     - "Today" / date windows are computed in UTC via SYSUTCDATETIME().
     - share_pct is computed against the full period total (not just the
       returned TOP rows) so charts reconcile to 100%.

   Depends on: dbo.sales, dbo.sale_items, dbo.payments, dbo.payment_methods,
               dbo.returns, dbo.credit_sales, dbo.customers, dbo.products,
               dbo.categories, dbo.users, dbo.notifications,
               dbo.notification_types, dbo.VW_LowStock.
   ========================================================================== */

-- ---------------------------------------------------------------------------
-- VW_DashboardKPIs
-- Single-row "today" KPI snapshot.
-- ---------------------------------------------------------------------------
IF OBJECT_ID(N'dbo.VW_DashboardKPIs', N'V') IS NOT NULL DROP VIEW dbo.VW_DashboardKPIs;
GO
CREATE VIEW dbo.VW_DashboardKPIs
AS
    SELECT
        (SELECT ISNULL(SUM(total_amount), 0)
         FROM dbo.sales
         WHERE status = N'COMPLETED'
           AND CAST(sale_date AS DATE) = CAST(SYSUTCDATETIME() AS DATE)) AS today_sales_total,

        (SELECT COUNT(*)
         FROM dbo.sales
         WHERE status = N'COMPLETED'
           AND CAST(sale_date AS DATE) = CAST(SYSUTCDATETIME() AS DATE)) AS today_sales_count,

        (SELECT ISNULL(SUM(total_refund_amount), 0)
         FROM dbo.returns
         WHERE status = N'COMPLETED'
           AND CAST(created_at AS DATE) = CAST(SYSUTCDATETIME() AS DATE)) AS today_returns_total,

        (SELECT COUNT(*)
         FROM dbo.returns
         WHERE status = N'COMPLETED'
           AND CAST(created_at AS DATE) = CAST(SYSUTCDATETIME() AS DATE)) AS today_refunds,

        (SELECT COUNT(*) FROM dbo.VW_LowStock) AS low_stock_count,

        (SELECT COUNT(*) FROM dbo.VW_LowStock WHERE stock_status = N'OUT_OF_STOCK') AS out_of_stock_count,

        (SELECT ISNULL(SUM(outstanding_balance), 0)
         FROM dbo.credit_sales
         WHERE status IN (N'OPEN', N'PARTIAL', N'OVERDUE')) AS pending_credit_balance,

        (SELECT COUNT(*)
         FROM dbo.users
         WHERE is_active = 1 AND is_deleted = 0) AS active_users_count,

        (SELECT COUNT(*)
         FROM dbo.products
         WHERE is_active = 1 AND is_deleted = 0) AS total_products_active;
GO

-- ---------------------------------------------------------------------------
-- VW_RecentSales
-- The 20 most recent COMPLETED sales with cashier, customer, total, status.
-- ---------------------------------------------------------------------------
IF OBJECT_ID(N'dbo.VW_RecentSales', N'V') IS NOT NULL DROP VIEW dbo.VW_RecentSales;
GO
CREATE VIEW dbo.VW_RecentSales
AS
    SELECT TOP (20)
        s.sale_id,
        s.receipt_number,
        s.sale_date,
        s.user_id,
        u.full_name AS cashier_name,
        s.customer_id,
        cu.full_name AS customer_name,
        s.sale_type,
        s.total_amount,
        s.status
    FROM dbo.sales s
    JOIN dbo.users u ON u.user_id = s.user_id
    LEFT JOIN dbo.customers cu ON cu.customer_id = s.customer_id
    WHERE s.status = N'COMPLETED'
    ORDER BY s.sale_date DESC;
GO

-- ---------------------------------------------------------------------------
-- VW_TopProducts
-- Top 10 products by revenue over the last 30 days (UTC). share_pct is the
-- product's share of total revenue across all products in the period.
-- ---------------------------------------------------------------------------
IF OBJECT_ID(N'dbo.VW_TopProducts', N'V') IS NOT NULL DROP VIEW dbo.VW_TopProducts;
GO
CREATE VIEW dbo.VW_TopProducts
AS
    SELECT TOP (10)
        p.product_id,
        p.product_name,
        p.sku,
        SUM(si.quantity) AS qty_sold,
        ROUND(SUM(si.line_total), 4) AS revenue,
        ROUND(SUM(si.line_total) / NULLIF(SUM(SUM(si.line_total)) OVER (), 0) * 100, 2) AS share_pct
    FROM dbo.sale_items si
    JOIN dbo.sales s    ON s.sale_id = si.sale_id
    JOIN dbo.products p ON p.product_id = si.product_id
    WHERE s.status = N'COMPLETED'
      AND s.sale_date >= CAST(DATEADD(DAY, -30, CAST(SYSUTCDATETIME() AS DATE)) AS DATETIME2(0))
    GROUP BY p.product_id, p.product_name, p.sku
    ORDER BY revenue DESC;
GO

-- ---------------------------------------------------------------------------
-- VW_SalesTrend7d
-- Last 7 calendar days (UTC) of daily totals; every day is present even with
-- no sales.
-- ---------------------------------------------------------------------------
IF OBJECT_ID(N'dbo.VW_SalesTrend7d', N'V') IS NOT NULL DROP VIEW dbo.VW_SalesTrend7d;
GO
CREATE VIEW dbo.VW_SalesTrend7d
AS
    WITH Numbers AS
    (
        SELECT n FROM (VALUES (1), (2), (3), (4), (5), (6), (7)) AS N(n)
    ),
    Days AS
    (
        SELECT
            n,
            CAST(DATEADD(DAY, 1 - n, CAST(SYSUTCDATETIME() AS DATE)) AS DATE) AS sale_date
        FROM Numbers
    )
    SELECT
        d.sale_date,
        DATENAME(WEEKDAY, d.sale_date) AS weekday_label,
        ISNULL(SUM(s.total_amount), 0) AS total_sales,
        COUNT(s.sale_id)               AS sale_count
    FROM Days d
    LEFT JOIN dbo.sales s
        ON CAST(s.sale_date AS DATE) = d.sale_date
       AND s.status = N'COMPLETED'
    GROUP BY d.n, d.sale_date, DATENAME(WEEKDAY, d.sale_date);
GO

-- ---------------------------------------------------------------------------
-- VW_SalesByCategory
-- Revenue by category over the last 30 days (UTC).
-- ---------------------------------------------------------------------------
IF OBJECT_ID(N'dbo.VW_SalesByCategory', N'V') IS NOT NULL DROP VIEW dbo.VW_SalesByCategory;
GO
CREATE VIEW dbo.VW_SalesByCategory
AS
    SELECT
        c.category_id,
        ISNULL(c.category_name, N'Uncategorized') AS category_name,
        ROUND(SUM(si.line_total), 4) AS revenue,
        SUM(si.quantity) AS qty_sold,
        COUNT(DISTINCT s.sale_id) AS sale_count
    FROM dbo.sale_items si
    JOIN dbo.sales s    ON s.sale_id = si.sale_id AND s.status = N'COMPLETED'
    JOIN dbo.products p ON p.product_id = si.product_id
    LEFT JOIN dbo.categories c ON c.category_id = p.category_id
    WHERE s.sale_date >= CAST(DATEADD(DAY, -30, CAST(SYSUTCDATETIME() AS DATE)) AS DATETIME2(0))
    GROUP BY c.category_id, c.category_name;
GO

-- ---------------------------------------------------------------------------
-- VW_SalesByPaymentMethod
-- Payment volume and revenue share per method (COMPLETED sales only).
-- ---------------------------------------------------------------------------
IF OBJECT_ID(N'dbo.VW_SalesByPaymentMethod', N'V') IS NOT NULL DROP VIEW dbo.VW_SalesByPaymentMethod;
GO
CREATE VIEW dbo.VW_SalesByPaymentMethod
AS
    SELECT
        pm.payment_method_id,
        pm.method_name,
        ROUND(SUM(p.amount), 4) AS total_amount,
        COUNT(p.payment_id)     AS payment_count,
        ROUND(SUM(p.amount) / NULLIF(SUM(SUM(p.amount)) OVER (), 0) * 100, 2) AS share_pct
    FROM dbo.payments p
    JOIN dbo.sales s          ON s.sale_id = p.sale_id AND s.status = N'COMPLETED'
    JOIN dbo.payment_methods pm ON pm.payment_method_id = p.payment_method_id
    WHERE p.pay_status IN (N'COMPLETED', N'PARTIAL')
    GROUP BY pm.payment_method_id, pm.method_name;
GO

-- ---------------------------------------------------------------------------
-- VW_RecentNotifications
-- The 10 latest notifications with recipient and type details.
-- ---------------------------------------------------------------------------
IF OBJECT_ID(N'dbo.VW_RecentNotifications', N'V') IS NOT NULL DROP VIEW dbo.VW_RecentNotifications;
GO
CREATE VIEW dbo.VW_RecentNotifications
AS
    SELECT TOP (10)
        n.notification_id,
        n.user_id,
        u.username,
        u.full_name,
        n.notification_type_id,
        nt.type_code,
        nt.type_name,
        n.title,
        n.message,
        n.severity,
        n.is_read,
        n.is_dismissed,
        n.created_at
    FROM dbo.notifications n
    JOIN dbo.users u             ON u.user_id = n.user_id
    JOIN dbo.notification_types nt ON nt.notification_type_id = n.notification_type_id
    ORDER BY n.created_at DESC;
GO

-- ---------------------------------------------------------------------------
-- VW_OutstandingCredit
-- Top credit customers ranked by outstanding balance (OPEN/PARTIAL/OVERDUE).
-- ---------------------------------------------------------------------------
IF OBJECT_ID(N'dbo.VW_OutstandingCredit', N'V') IS NOT NULL DROP VIEW dbo.VW_OutstandingCredit;
GO
CREATE VIEW dbo.VW_OutstandingCredit
AS
    SELECT TOP (20)
        c.customer_id,
        c.customer_code,
        c.full_name AS customer_name,
        c.phone,
        ISNULL(SUM(cs.outstanding_balance), 0) AS outstanding_balance,
        COUNT(cs.credit_sale_id) AS open_credit_count
    FROM dbo.customers c
    JOIN dbo.credit_sales cs ON cs.customer_id = c.customer_id
    WHERE cs.status IN (N'OPEN', N'PARTIAL', N'OVERDUE')
      AND c.is_deleted = 0
    GROUP BY c.customer_id, c.customer_code, c.full_name, c.phone
    HAVING ISNULL(SUM(cs.outstanding_balance), 0) > 0
    ORDER BY outstanding_balance DESC;
GO
