/* ==========================================================================
   SmartPOS Database - MODULE 13: REPORTING PROCEDURES
   --------------------------------------------------------------------------
   Stored procedures powering the Reports module. Read-only procedures: no
   writes occur, so no error_logs entries are made; each is wrapped in
   TRY...CATCH and rethrows so the API receives a clean error.

   Conventions:
     - Procedure names: SP_<Purpose>.
     - @FromDate / @ToDate are optional, inclusive DATETIME2(0) UTC bounds.
     - Pagination (@Page, @PageSize) where sensible; TotalCount always returned.
     - Aggregated views cannot be date-filtered after the fact, so procs that
       accept date ranges recompute from line-level tables with identical
       business rules to the VW_Report_Views.sql aggregations.

   Depends on: VW_Report_Views.sql, dbo.tables from modules 02-11.
   ========================================================================== */

/* ---------------------------------------------------------------------------
   SP_SalesReport
   Two result sets from VW_SalesSummary: (1) daily grouped summary and
   (2) per-sale detail. Optional filters: date range, cashier/user, sale type,
   status.
--------------------------------------------------------------------------- */
IF OBJECT_ID(N'dbo.SP_SalesReport', N'P') IS NOT NULL DROP PROCEDURE dbo.SP_SalesReport;
GO
CREATE PROCEDURE dbo.SP_SalesReport
    @FromDate DATETIME2(0) = NULL,
    @ToDate   DATETIME2(0) = NULL,
    @UserID   INT = NULL,
    @SaleType NVARCHAR(20) = NULL,
    @Status   NVARCHAR(20) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        IF @SaleType IS NOT NULL
            AND @SaleType NOT IN (N'CASH', N'CREDIT', N'CREDIT_PARTIAL')
            THROW 50061, N'Invalid sale type. Allowed: CASH, CREDIT, CREDIT_PARTIAL.', 1;

        IF @Status IS NOT NULL
            AND @Status NOT IN (N'COMPLETED', N'VOIDED', N'REFUNDED')
            THROW 50062, N'Invalid sale status. Allowed: COMPLETED, VOIDED, REFUNDED.', 1;

        -- Result set 1: grouped daily summary
        SELECT
            CAST(sale_date AS DATE) AS sale_date,
            COUNT(*)                AS sale_count,
            ROUND(SUM(total_amount), 4)   AS total_sales,
            ROUND(SUM(tax_amount), 4)     AS total_tax,
            ROUND(SUM(discount_amount), 4) AS total_discount,
            ROUND(AVG(total_amount), 4)   AS avg_sale_value
        FROM dbo.VW_SalesSummary
        WHERE (@FromDate IS NULL OR sale_date >= @FromDate)
          AND (@ToDate   IS NULL OR sale_date <= @ToDate)
          AND (@UserID   IS NULL OR user_id   = @UserID)
          AND (@SaleType IS NULL OR sale_type = @SaleType)
          AND (@Status   IS NULL OR status    = @Status)
        GROUP BY CAST(sale_date AS DATE)
        ORDER BY sale_date;

        -- Result set 2: per-sale detail
        SELECT
            sale_id,
            receipt_number,
            sale_date,
            cashier_name,
            customer_name,
            sale_type,
            subtotal,
            discount_amount,
            tax_amount,
            total_amount,
            amount_received,
            status,
            payment_methods
        FROM dbo.VW_SalesSummary
        WHERE (@FromDate IS NULL OR sale_date >= @FromDate)
          AND (@ToDate   IS NULL OR sale_date <= @ToDate)
          AND (@UserID   IS NULL OR user_id   = @UserID)
          AND (@SaleType IS NULL OR sale_type = @SaleType)
          AND (@Status   IS NULL OR status    = @Status)
        ORDER BY sale_date DESC;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

/* ---------------------------------------------------------------------------
   SP_InventoryReport
   Paginated current stock snapshot from VW_InventoryReport with optional
   category, supplier and stock-status filters.
--------------------------------------------------------------------------- */
IF OBJECT_ID(N'dbo.SP_InventoryReport', N'P') IS NOT NULL DROP PROCEDURE dbo.SP_InventoryReport;
GO
CREATE PROCEDURE dbo.SP_InventoryReport
    @CategoryID  INT = NULL,
    @SupplierID  INT = NULL,
    @StockStatus NVARCHAR(20) = NULL,
    @Page        INT = 1,
    @PageSize    INT = 50
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @Offset INT;

    BEGIN TRY
        IF @StockStatus IS NOT NULL
            AND @StockStatus NOT IN (N'IN_STOCK', N'LOW_STOCK', N'OUT_OF_STOCK')
            THROW 50063, N'Invalid stock status. Allowed: IN_STOCK, LOW_STOCK, OUT_OF_STOCK.', 1;

        IF @Page < 1 SET @Page = 1;
        IF @PageSize < 1 SET @PageSize = 50;
        IF @PageSize > 500 SET @PageSize = 500;
        SET @Offset = (@Page - 1) * @PageSize;

        SELECT
            product_id,
            product_name,
            sku,
            category_name,
            supplier_name,
            quantity_on_hand,
            quantity_reserved,
            low_stock_threshold,
            stock_status,
            unit_cost,
            stock_value
        INTO #inv
        FROM dbo.VW_InventoryReport
        WHERE (@CategoryID  IS NULL OR category_id  = @CategoryID)
          AND (@SupplierID  IS NULL OR supplier_id  = @SupplierID)
          AND (@StockStatus IS NULL OR stock_status = @StockStatus);

        SELECT COUNT(*) AS total_count FROM #inv;

        SELECT
            product_id,
            product_name,
            sku,
            category_name,
            supplier_name,
            quantity_on_hand,
            quantity_reserved,
            low_stock_threshold,
            stock_status,
            unit_cost,
            stock_value
        FROM #inv
        ORDER BY product_name
        OFFSET @Offset ROWS FETCH NEXT @PageSize ROWS ONLY;

        DROP TABLE #inv;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

/* ---------------------------------------------------------------------------
   SP_InventoryMovementsReport
   Paginated stock-movement audit trail from VW_InventoryMovementsReport with
   optional product, date-range and movement-type filters.
--------------------------------------------------------------------------- */
IF OBJECT_ID(N'dbo.SP_InventoryMovementsReport', N'P') IS NOT NULL DROP PROCEDURE dbo.SP_InventoryMovementsReport;
GO
CREATE PROCEDURE dbo.SP_InventoryMovementsReport
    @ProductID    INT = NULL,
    @FromDate     DATETIME2(0) = NULL,
    @ToDate       DATETIME2(0) = NULL,
    @MovementType NVARCHAR(30) = NULL,
    @Page         INT = 1,
    @PageSize     INT = 50
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @Offset INT;

    BEGIN TRY
        IF @MovementType IS NOT NULL
            AND @MovementType NOT IN (N'SALE', N'RESTOCK', N'RETURN', N'ADJUSTMENT', N'VOID', N'TRANSFER')
            THROW 50064, N'Invalid movement type. Allowed: SALE, RESTOCK, RETURN, ADJUSTMENT, VOID, TRANSFER.', 1;

        IF @Page < 1 SET @Page = 1;
        IF @PageSize < 1 SET @PageSize = 50;
        IF @PageSize > 500 SET @PageSize = 500;
        SET @Offset = (@Page - 1) * @PageSize;

        SELECT
            transaction_id,
            product_id,
            product_name,
            sku,
            movement_type,
            quantity,
            quantity_before,
            quantity_after,
            unit_cost,
            reference_type,
            reference_id,
            reason,
            username,
            created_at
        INTO #mov
        FROM dbo.VW_InventoryMovementsReport
        WHERE (@ProductID    IS NULL OR product_id    = @ProductID)
          AND (@FromDate     IS NULL OR created_at   >= @FromDate)
          AND (@ToDate       IS NULL OR created_at   <= @ToDate)
          AND (@MovementType IS NULL OR movement_type = @MovementType);

        SELECT COUNT(*) AS total_count FROM #mov;

        SELECT
            transaction_id,
            product_id,
            product_name,
            sku,
            movement_type,
            quantity,
            quantity_before,
            quantity_after,
            unit_cost,
            reference_type,
            reference_id,
            reason,
            username,
            created_at
        FROM #mov
        ORDER BY created_at DESC
        OFFSET @Offset ROWS FETCH NEXT @PageSize ROWS ONLY;

        DROP TABLE #mov;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

/* ---------------------------------------------------------------------------
   SP_SupplierReport
   Paginated supplier summary from VW_SupplierReport, optionally for one
   supplier.
--------------------------------------------------------------------------- */
IF OBJECT_ID(N'dbo.SP_SupplierReport', N'P') IS NOT NULL DROP PROCEDURE dbo.SP_SupplierReport;
GO
CREATE PROCEDURE dbo.SP_SupplierReport
    @SupplierID INT = NULL,
    @Page       INT = 1,
    @PageSize   INT = 50
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @Offset INT;

    BEGIN TRY
        IF @Page < 1 SET @Page = 1;
        IF @PageSize < 1 SET @PageSize = 50;
        IF @PageSize > 500 SET @PageSize = 500;
        SET @Offset = (@Page - 1) * @PageSize;

        SELECT
            supplier_id,
            supplier_code,
            supplier_name,
            contact_person,
            email,
            phone,
            product_count,
            total_stock_value
        INTO #sup
        FROM dbo.VW_SupplierReport
        WHERE (@SupplierID IS NULL OR supplier_id = @SupplierID);

        SELECT COUNT(*) AS total_count FROM #sup;

        SELECT
            supplier_id,
            supplier_code,
            supplier_name,
            contact_person,
            email,
            phone,
            product_count,
            total_stock_value
        FROM #sup
        ORDER BY supplier_name
        OFFSET @Offset ROWS FETCH NEXT @PageSize ROWS ONLY;

        DROP TABLE #sup;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

/* ---------------------------------------------------------------------------
   SP_CreditReport
   Paginated credit ledger from VW_CreditReport with optional date-range and
   status filters.
--------------------------------------------------------------------------- */
IF OBJECT_ID(N'dbo.SP_CreditReport', N'P') IS NOT NULL DROP PROCEDURE dbo.SP_CreditReport;
GO
CREATE PROCEDURE dbo.SP_CreditReport
    @FromDate DATETIME2(0) = NULL,
    @ToDate   DATETIME2(0) = NULL,
    @Status   NVARCHAR(20) = NULL,
    @Page     INT = 1,
    @PageSize INT = 50
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @Offset INT;

    BEGIN TRY
        IF @Status IS NOT NULL
            AND @Status NOT IN (N'OPEN', N'PARTIAL', N'SETTLED', N'OVERDUE', N'WRITTEN_OFF')
            THROW 50065, N'Invalid credit status. Allowed: OPEN, PARTIAL, SETTLED, OVERDUE, WRITTEN_OFF.', 1;

        IF @Page < 1 SET @Page = 1;
        IF @PageSize < 1 SET @PageSize = 50;
        IF @PageSize > 500 SET @PageSize = 500;
        SET @Offset = (@Page - 1) * @PageSize;

        SELECT
            credit_sale_id,
            sale_id,
            receipt_number,
            customer_name,
            customer_phone,
            total_amount,
            amount_paid,
            outstanding_balance,
            status,
            due_date,
            days_overdue,
            created_at
        INTO #cred
        FROM dbo.VW_CreditReport
        WHERE (@FromDate IS NULL OR created_at >= @FromDate)
          AND (@ToDate   IS NULL OR created_at <= @ToDate)
          AND (@Status   IS NULL OR status     = @Status);

        SELECT COUNT(*) AS total_count FROM #cred;

        SELECT
            credit_sale_id,
            sale_id,
            receipt_number,
            customer_name,
            customer_phone,
            total_amount,
            amount_paid,
            outstanding_balance,
            status,
            due_date,
            days_overdue,
            created_at
        FROM #cred
        ORDER BY created_at DESC
        OFFSET @Offset ROWS FETCH NEXT @PageSize ROWS ONLY;

        DROP TABLE #cred;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

/* ---------------------------------------------------------------------------
   SP_ReturnsReport
   Paginated returns from VW_ReturnsReport with optional date-range and status
   filters.
--------------------------------------------------------------------------- */
IF OBJECT_ID(N'dbo.SP_ReturnsReport', N'P') IS NOT NULL DROP PROCEDURE dbo.SP_ReturnsReport;
GO
CREATE PROCEDURE dbo.SP_ReturnsReport
    @FromDate DATETIME2(0) = NULL,
    @ToDate   DATETIME2(0) = NULL,
    @Status   NVARCHAR(20) = NULL,
    @Page     INT = 1,
    @PageSize INT = 50
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @Offset INT;

    BEGIN TRY
        IF @Status IS NOT NULL
            AND @Status NOT IN (N'PENDING', N'COMPLETED', N'REJECTED')
            THROW 50066, N'Invalid return status. Allowed: PENDING, COMPLETED, REJECTED.', 1;

        IF @Page < 1 SET @Page = 1;
        IF @PageSize < 1 SET @PageSize = 50;
        IF @PageSize > 500 SET @PageSize = 500;
        SET @Offset = (@Page - 1) * @PageSize;

        SELECT
            return_id,
            return_number,
            sale_id,
            sale_receipt_number,
            customer_name,
            processor_name,
            total_refund_amount,
            status,
            return_reason_name,
            created_at
        INTO #ret
        FROM dbo.VW_ReturnsReport
        WHERE (@FromDate IS NULL OR created_at >= @FromDate)
          AND (@ToDate   IS NULL OR created_at <= @ToDate)
          AND (@Status   IS NULL OR status     = @Status);

        SELECT COUNT(*) AS total_count FROM #ret;

        SELECT
            return_id,
            return_number,
            sale_id,
            sale_receipt_number,
            customer_name,
            processor_name,
            total_refund_amount,
            status,
            return_reason_name,
            created_at
        FROM #ret
        ORDER BY created_at DESC
        OFFSET @Offset ROWS FETCH NEXT @PageSize ROWS ONLY;

        DROP TABLE #ret;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

/* ---------------------------------------------------------------------------
   SP_ProfitReport
   Gross profit per product. VW_ProfitReport is an all-time aggregation and
   cannot be date-filtered after the fact, so this proc recomputes from
   line-level data (identical business rules) to honour @FromDate/@ToDate.
--------------------------------------------------------------------------- */
IF OBJECT_ID(N'dbo.SP_ProfitReport', N'P') IS NOT NULL DROP PROCEDURE dbo.SP_ProfitReport;
GO
CREATE PROCEDURE dbo.SP_ProfitReport
    @FromDate   DATETIME2(0) = NULL,
    @ToDate     DATETIME2(0) = NULL,
    @CategoryID INT = NULL,
    @Page       INT = 1,
    @PageSize   INT = 50
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @Offset INT;

    BEGIN TRY
        IF @Page < 1 SET @Page = 1;
        IF @PageSize < 1 SET @PageSize = 50;
        IF @PageSize > 500 SET @PageSize = 500;
        SET @Offset = (@Page - 1) * @PageSize;

        SELECT
            p.product_id,
            p.product_name,
            p.sku,
            p.category_id,
            c.category_name,
            SUM(si.quantity) AS qty_sold,
            ROUND(SUM(si.line_total), 4) AS revenue,
            ROUND(SUM(si.quantity) * ISNULL(p.cost_price, 0), 4) AS cost_of_goods,
            ROUND(SUM(si.line_total) - SUM(si.quantity) * ISNULL(p.cost_price, 0), 4) AS gross_profit,
            CASE
                WHEN SUM(si.line_total) = 0 THEN 0
                ELSE ROUND((SUM(si.line_total) - SUM(si.quantity) * ISNULL(p.cost_price, 0))
                           / SUM(si.line_total) * 100, 2)
            END AS gross_margin_pct
        INTO #profit
        FROM dbo.sale_items si
        JOIN dbo.sales s      ON s.sale_id = si.sale_id
        JOIN dbo.products p   ON p.product_id = si.product_id
        LEFT JOIN dbo.categories c ON c.category_id = p.category_id
        WHERE s.status = N'COMPLETED'
          AND (@FromDate   IS NULL OR s.sale_date   >= @FromDate)
          AND (@ToDate     IS NULL OR s.sale_date   <= @ToDate)
          AND (@CategoryID IS NULL OR p.category_id  = @CategoryID)
        GROUP BY p.product_id, p.product_name, p.sku, p.cost_price,
                 p.category_id, c.category_name;

        SELECT COUNT(*) AS total_count FROM #profit;

        SELECT
            product_id,
            product_name,
            sku,
            category_name,
            qty_sold,
            revenue,
            cost_of_goods,
            gross_profit,
            gross_margin_pct
        FROM #profit
        ORDER BY gross_profit DESC
        OFFSET @Offset ROWS FETCH NEXT @PageSize ROWS ONLY;

        DROP TABLE #profit;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

/* ---------------------------------------------------------------------------
   SP_TaxReport
   Collected tax per tax rate. VW_TaxReport is all-time; recompute here so
   @FromDate/@ToDate are honoured.
--------------------------------------------------------------------------- */
IF OBJECT_ID(N'dbo.SP_TaxReport', N'P') IS NOT NULL DROP PROCEDURE dbo.SP_TaxReport;
GO
CREATE PROCEDURE dbo.SP_TaxReport
    @FromDate DATETIME2(0) = NULL,
    @ToDate   DATETIME2(0) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        SELECT
            tr.tax_rate_id,
            tr.tax_name,
            tr.rate_percent,
            COUNT(s.sale_id) AS taxable_sales_count,
            ROUND(SUM(s.tax_amount), 4) AS total_tax_amount
        FROM dbo.tax_rates tr
        LEFT JOIN dbo.sales s
            ON s.tax_rate_id = tr.tax_rate_id
           AND s.status = N'COMPLETED'
           AND (@FromDate IS NULL OR s.sale_date >= @FromDate)
           AND (@ToDate   IS NULL OR s.sale_date <= @ToDate)
        GROUP BY tr.tax_rate_id, tr.tax_name, tr.rate_percent
        ORDER BY tr.tax_name;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

/* ---------------------------------------------------------------------------
   SP_PaymentMethodsReport
   Payment volume per method. VW_PaymentMethodsReport is all-time; recompute
   here so @FromDate/@ToDate are honoured (on payments.received_at).
--------------------------------------------------------------------------- */
IF OBJECT_ID(N'dbo.SP_PaymentMethodsReport', N'P') IS NOT NULL DROP PROCEDURE dbo.SP_PaymentMethodsReport;
GO
CREATE PROCEDURE dbo.SP_PaymentMethodsReport
    @FromDate DATETIME2(0) = NULL,
    @ToDate   DATETIME2(0) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        SELECT
            pm.payment_method_id,
            pm.method_name,
            COUNT(p.payment_id) AS payment_count,
            ROUND(SUM(p.amount), 4) AS total_amount,
            ROUND(SUM(p.amount) / NULLIF(SUM(SUM(p.amount)) OVER (), 0) * 100, 2) AS share_pct
        FROM dbo.payment_methods pm
        JOIN dbo.payments p ON p.payment_method_id = pm.payment_method_id
        JOIN dbo.sales s    ON s.sale_id = p.sale_id AND s.status = N'COMPLETED'
        WHERE p.pay_status IN (N'COMPLETED', N'PARTIAL')
          AND (@FromDate IS NULL OR p.received_at >= @FromDate)
          AND (@ToDate   IS NULL OR p.received_at <= @ToDate)
        GROUP BY pm.payment_method_id, pm.method_name
        ORDER BY total_amount DESC;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

/* ---------------------------------------------------------------------------
   SP_ProductSalesReport
   Sales per product. VW_ProductSalesReport is all-time; recompute here so
   @ProductID and @FromDate/@ToDate are honoured.
--------------------------------------------------------------------------- */
IF OBJECT_ID(N'dbo.SP_ProductSalesReport', N'P') IS NOT NULL DROP PROCEDURE dbo.SP_ProductSalesReport;
GO
CREATE PROCEDURE dbo.SP_ProductSalesReport
    @ProductID INT = NULL,
    @FromDate  DATETIME2(0) = NULL,
    @ToDate    DATETIME2(0) = NULL,
    @Page      INT = 1,
    @PageSize  INT = 50
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @Offset INT;

    BEGIN TRY
        IF @Page < 1 SET @Page = 1;
        IF @PageSize < 1 SET @PageSize = 50;
        IF @PageSize > 500 SET @PageSize = 500;
        SET @Offset = (@Page - 1) * @PageSize;

        SELECT
            p.product_id,
            p.product_name,
            p.sku,
            p.category_id,
            c.category_name,
            SUM(si.quantity)   AS total_qty_sold,
            ROUND(SUM(si.line_total), 4) AS total_revenue,
            ROUND(SUM(si.tax_amount), 4) AS total_tax
        INTO #psr
        FROM dbo.sale_items si
        JOIN dbo.sales s     ON s.sale_id = si.sale_id
        JOIN dbo.products p  ON p.product_id = si.product_id
        LEFT JOIN dbo.categories c ON c.category_id = p.category_id
        WHERE s.status = N'COMPLETED'
          AND (@ProductID IS NULL OR p.product_id  = @ProductID)
          AND (@FromDate  IS NULL OR s.sale_date  >= @FromDate)
          AND (@ToDate    IS NULL OR s.sale_date  <= @ToDate)
        GROUP BY p.product_id, p.product_name, p.sku, p.category_id, c.category_name;

        SELECT COUNT(*) AS total_count FROM #psr;

        SELECT
            product_id,
            product_name,
            sku,
            category_name,
            total_qty_sold,
            total_revenue,
            total_tax
        FROM #psr
        ORDER BY total_revenue DESC
        OFFSET @Offset ROWS FETCH NEXT @PageSize ROWS ONLY;

        DROP TABLE #psr;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

/* ---------------------------------------------------------------------------
   SP_ExportReport
   Generic report dispatcher. @ReportName selects the report procedure;
   @FiltersJSON may carry { ProductID, CategoryID, SupplierID, UserID,
   SaleType, Status, MovementType, Page, PageSize }. Unknown names raise
   error 50060.
--------------------------------------------------------------------------- */
IF OBJECT_ID(N'dbo.SP_ExportReport', N'P') IS NOT NULL DROP PROCEDURE dbo.SP_ExportReport;
GO
CREATE PROCEDURE dbo.SP_ExportReport
    @ReportName  NVARCHAR(100),
    @FromDate    DATETIME2(0) = NULL,
    @ToDate      DATETIME2(0) = NULL,
    @FiltersJSON NVARCHAR(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @ProductID    INT;
    DECLARE @CategoryID   INT;
    DECLARE @SupplierID   INT;
    DECLARE @UserID       INT;
    DECLARE @SaleType     NVARCHAR(20);
    DECLARE @Status       NVARCHAR(20);
    DECLARE @MovementType NVARCHAR(30);
    DECLARE @Page         INT = 1;
    DECLARE @PageSize     INT = 500;

    BEGIN TRY
        IF @FiltersJSON IS NOT NULL AND ISJSON(@FiltersJSON) = 1
        BEGIN
            SET @ProductID    = TRY_CAST(JSON_VALUE(@FiltersJSON, N'$.ProductID')    AS INT);
            SET @CategoryID   = TRY_CAST(JSON_VALUE(@FiltersJSON, N'$.CategoryID')   AS INT);
            SET @SupplierID   = TRY_CAST(JSON_VALUE(@FiltersJSON, N'$.SupplierID')   AS INT);
            SET @UserID       = TRY_CAST(JSON_VALUE(@FiltersJSON, N'$.UserID')       AS INT);
            SET @SaleType     = JSON_VALUE(@FiltersJSON, N'$.SaleType');
            SET @Status       = JSON_VALUE(@FiltersJSON, N'$.Status');
            SET @MovementType = JSON_VALUE(@FiltersJSON, N'$.MovementType');
            SET @Page         = ISNULL(TRY_CAST(JSON_VALUE(@FiltersJSON, N'$.Page')     AS INT), 1);
            SET @PageSize     = ISNULL(TRY_CAST(JSON_VALUE(@FiltersJSON, N'$.PageSize') AS INT), 500);
        END

        IF @ReportName IS NULL OR LTRIM(RTRIM(@ReportName)) = N''
            THROW 50060, N'Unknown report.', 1;

        IF @ReportName = N'SalesReport'
        BEGIN
            EXEC dbo.SP_SalesReport @FromDate, @ToDate, @UserID, @SaleType, @Status;
        END
        ELSE IF @ReportName = N'InventoryReport'
        BEGIN
            EXEC dbo.SP_InventoryReport @CategoryID, @SupplierID, @Status, @Page, @PageSize;
        END
        ELSE IF @ReportName = N'InventoryMovementsReport'
        BEGIN
            EXEC dbo.SP_InventoryMovementsReport @ProductID, @FromDate, @ToDate, @MovementType, @Page, @PageSize;
        END
        ELSE IF @ReportName = N'SupplierReport'
        BEGIN
            EXEC dbo.SP_SupplierReport @SupplierID, @Page, @PageSize;
        END
        ELSE IF @ReportName = N'CreditReport'
        BEGIN
            EXEC dbo.SP_CreditReport @FromDate, @ToDate, @Status, @Page, @PageSize;
        END
        ELSE IF @ReportName = N'ReturnsReport'
        BEGIN
            EXEC dbo.SP_ReturnsReport @FromDate, @ToDate, @Status, @Page, @PageSize;
        END
        ELSE IF @ReportName = N'ProfitReport'
        BEGIN
            EXEC dbo.SP_ProfitReport @FromDate, @ToDate, @CategoryID, @Page, @PageSize;
        END
        ELSE IF @ReportName = N'TaxReport'
        BEGIN
            EXEC dbo.SP_TaxReport @FromDate, @ToDate;
        END
        ELSE IF @ReportName = N'PaymentMethodsReport'
        BEGIN
            EXEC dbo.SP_PaymentMethodsReport @FromDate, @ToDate;
        END
        ELSE IF @ReportName = N'ProductSalesReport'
        BEGIN
            EXEC dbo.SP_ProductSalesReport @ProductID, @FromDate, @ToDate, @Page, @PageSize;
        END
        ELSE
        BEGIN
            THROW 50060, N'Unknown report.', 1;
        END
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO
