/* ==========================================================================
   SmartPOS Database - MODULE 14: DASHBOARD PROCEDURES
   --------------------------------------------------------------------------
   Stored procedures powering the Dashboard module. Read-only procedures: no
   writes occur, so no error_logs entries are made; each is wrapped in
   TRY...CATCH and rethrows so the API receives a clean error.

   Conventions:
     - Procedure names: SP_<Purpose>.
     - @UserID is validated (must be an existing, non-deleted user) where the
       API passes it; it is optional so system-level calls still work.
     - Date windows are computed in UTC via SYSUTCDATETIME().

   Depends on: VW_Dashboard_Views.sql, dbo.users, dbo.VW_LowStock.
   ========================================================================== */

/* ---------------------------------------------------------------------------
   SP_GetDashboardMetrics
   Returns the single KPI row from VW_DashboardKPIs.
--------------------------------------------------------------------------- */
IF OBJECT_ID(N'dbo.SP_GetDashboardMetrics', N'P') IS NOT NULL DROP PROCEDURE dbo.SP_GetDashboardMetrics;
GO
CREATE PROCEDURE dbo.SP_GetDashboardMetrics
    @UserID INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        IF @UserID IS NOT NULL
            AND NOT EXISTS (SELECT 1 FROM dbo.users WHERE user_id = @UserID AND is_deleted = 0)
            THROW 50070, N'User does not exist.', 1;

        SELECT
            today_sales_total,
            today_sales_count,
            today_returns_total,
            today_refunds,
            low_stock_count,
            out_of_stock_count,
            pending_credit_balance,
            active_users_count,
            total_products_active
        FROM dbo.VW_DashboardKPIs;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

/* ---------------------------------------------------------------------------
   SP_GetDashboardData
   Single call returning five result sets for the dashboard home screen:
    1. KPIs           - VW_DashboardKPIs
    2. RecentSales    - VW_RecentSales
    3. TopProducts    - VW_TopProducts
    4. SalesTrend7d   - VW_SalesTrend7d
    5. LowStock       - top 10 rows of VW_LowStock
--------------------------------------------------------------------------- */
IF OBJECT_ID(N'dbo.SP_GetDashboardData', N'P') IS NOT NULL DROP PROCEDURE dbo.SP_GetDashboardData;
GO
CREATE PROCEDURE dbo.SP_GetDashboardData
    @UserID INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        IF @UserID IS NOT NULL
            AND NOT EXISTS (SELECT 1 FROM dbo.users WHERE user_id = @UserID AND is_deleted = 0)
            THROW 50071, N'User does not exist.', 1;

        SELECT
            today_sales_total,
            today_sales_count,
            today_returns_total,
            today_refunds,
            low_stock_count,
            out_of_stock_count,
            pending_credit_balance,
            active_users_count,
            total_products_active
        FROM dbo.VW_DashboardKPIs;

        SELECT
            sale_id,
            receipt_number,
            sale_date,
            cashier_name,
            customer_name,
            sale_type,
            total_amount,
            status
        FROM dbo.VW_RecentSales;

        SELECT
            product_id,
            product_name,
            sku,
            qty_sold,
            revenue,
            share_pct
        FROM dbo.VW_TopProducts;

        SELECT
            sale_date,
            weekday_label,
            total_sales,
            sale_count
        FROM dbo.VW_SalesTrend7d
        ORDER BY sale_date;

        SELECT TOP (10)
            product_id,
            sku,
            product_name,
            quantity_on_hand,
            low_stock_threshold,
            stock_status
        FROM dbo.VW_LowStock
        ORDER BY quantity_on_hand ASC;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

/* ---------------------------------------------------------------------------
   SP_GetSalesByCategory
   Revenue by category for an arbitrary (inclusive) date range. Recomputed from
   line-level data because VW_SalesByCategory is fixed to the last 30 days.
--------------------------------------------------------------------------- */
IF OBJECT_ID(N'dbo.SP_GetSalesByCategory', N'P') IS NOT NULL DROP PROCEDURE dbo.SP_GetSalesByCategory;
GO
CREATE PROCEDURE dbo.SP_GetSalesByCategory
    @FromDate DATETIME2(0) = NULL,
    @ToDate   DATETIME2(0) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
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
        WHERE (@FromDate IS NULL OR s.sale_date >= @FromDate)
          AND (@ToDate   IS NULL OR s.sale_date <= @ToDate)
        GROUP BY c.category_id, c.category_name
        ORDER BY revenue DESC;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

/* ---------------------------------------------------------------------------
   SP_GetTopProducts
   Top products by revenue over the last @Days days (UTC). share_pct is the
   share of total revenue across all products in the window.
--------------------------------------------------------------------------- */
IF OBJECT_ID(N'dbo.SP_GetTopProducts', N'P') IS NOT NULL DROP PROCEDURE dbo.SP_GetTopProducts;
GO
CREATE PROCEDURE dbo.SP_GetTopProducts
    @Days  INT = 30,
    @Limit INT = 10
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        IF @Days < 1 SET @Days = 1;
        IF @Days > 365 SET @Days = 365;
        IF @Limit < 1 SET @Limit = 10;
        IF @Limit > 100 SET @Limit = 100;

        DECLARE @FromDate DATETIME2(0) = CAST(DATEADD(DAY, -@Days, CAST(SYSUTCDATETIME() AS DATE)) AS DATETIME2(0));

        SELECT TOP (@Limit)
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
          AND s.sale_date >= @FromDate
        GROUP BY p.product_id, p.product_name, p.sku
        ORDER BY revenue DESC;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

/* ---------------------------------------------------------------------------
   SP_GetSalesTrend
   Daily sales totals for the last @Days days (UTC); every day is present even
   with no sales. @Days is capped at 90 (safe under the 100 recursion limit).
--------------------------------------------------------------------------- */
IF OBJECT_ID(N'dbo.SP_GetSalesTrend', N'P') IS NOT NULL DROP PROCEDURE dbo.SP_GetSalesTrend;
GO
CREATE PROCEDURE dbo.SP_GetSalesTrend
    @Days INT = 7
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        IF @Days < 1 SET @Days = 1;
        IF @Days > 90 SET @Days = 90;

        DECLARE @Today DATE = CAST(SYSUTCDATETIME() AS DATE);

        WITH Days(n, sale_date) AS
        (
            SELECT 1 AS n, @Today
            UNION ALL
            SELECT n + 1, DATEADD(DAY, -1, sale_date)
            FROM Days
            WHERE n < @Days
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
        GROUP BY d.n, d.sale_date, DATENAME(WEEKDAY, d.sale_date)
        ORDER BY d.n
        OPTION (MAXRECURSION 120);
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO
