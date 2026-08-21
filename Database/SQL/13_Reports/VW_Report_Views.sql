/* ==========================================================================
   SmartPOS Database - MODULE 13: REPORTING VIEWS
   --------------------------------------------------------------------------
   Reporting views consumed by the Reports module (SP_Reports.sql,
   SP_ExportReport) and by the API Reports screens.

   Conventions:
     - View names: VW_<Purpose>.
     - Money columns are DECIMAL(19,4); dates DATETIME2(0) stored UTC.
     - Sales aggregations count status = 'COMPLETED' only.
     - Stock status is computed with dbo.FN_StockStatus.

   Depends on: dbo.sales, dbo.sale_items, dbo.payments, dbo.payment_methods,
               dbo.credit_sales, dbo.customers, dbo.returns, dbo.return_reasons,
               dbo.products, dbo.categories, dbo.suppliers, dbo.inventory,
               dbo.inventory_transactions, dbo.users, dbo.tax_rates,
               dbo.FN_StockStatus.
   ========================================================================== */

-- ---------------------------------------------------------------------------
-- VW_SalesSummary
-- One row per sale header with cashier, customer, aggregated payment method
-- names (FOR XML, SQL Server 2016 compatible) and money columns.
-- ---------------------------------------------------------------------------
IF OBJECT_ID(N'dbo.VW_SalesSummary', N'V') IS NOT NULL DROP VIEW dbo.VW_SalesSummary;
GO
CREATE VIEW dbo.VW_SalesSummary
AS
    SELECT
        s.sale_id,
        s.receipt_number,
        s.sale_date,
        s.user_id,
        u.full_name AS cashier_name,
        s.customer_id,
        cu.full_name AS customer_name,
        s.tax_rate_id,
        s.sale_type,
        s.subtotal,
        s.discount_amount,
        s.tax_amount,
        s.total_amount,
        s.amount_received,
        s.status,
        ISNULL(STUFF((
            SELECT N', ' + pm.method_name
            FROM dbo.payments p
            JOIN dbo.payment_methods pm ON pm.payment_method_id = p.payment_method_id
            WHERE p.sale_id = s.sale_id
              AND p.pay_status IN (N'COMPLETED', N'PARTIAL')
            ORDER BY pm.method_name
            FOR XML PATH(N''), TYPE
        ).value(N'.', N'NVARCHAR(MAX)'), 1, 2, N''), N'') AS payment_methods
    FROM dbo.sales s
    JOIN dbo.users u       ON u.user_id = s.user_id
    LEFT JOIN dbo.customers cu ON cu.customer_id = s.customer_id;
GO

-- ---------------------------------------------------------------------------
-- VW_DailySales
-- One row per calendar date with daily sales totals (COMPLETED sales only).
-- ---------------------------------------------------------------------------
IF OBJECT_ID(N'dbo.VW_DailySales', N'V') IS NOT NULL DROP VIEW dbo.VW_DailySales;
GO
CREATE VIEW dbo.VW_DailySales
AS
    SELECT
        CAST(s.sale_date AS DATE) AS sale_date,
        ROUND(SUM(s.total_amount), 4)   AS total_sales,
        COUNT(*)                        AS sale_count,
        ROUND(SUM(s.tax_amount), 4)     AS total_tax,
        ROUND(SUM(s.discount_amount), 4) AS total_discount,
        ROUND(AVG(s.total_amount), 4)   AS avg_sale_value
    FROM dbo.sales s
    WHERE s.status = N'COMPLETED'
    GROUP BY CAST(s.sale_date AS DATE);
GO

-- ---------------------------------------------------------------------------
-- VW_ProductSalesReport
-- Lifetime sales quantity / revenue / tax per product (COMPLETED sales only).
-- ---------------------------------------------------------------------------
IF OBJECT_ID(N'dbo.VW_ProductSalesReport', N'V') IS NOT NULL DROP VIEW dbo.VW_ProductSalesReport;
GO
CREATE VIEW dbo.VW_ProductSalesReport
AS
    SELECT
        p.product_id,
        p.product_name,
        p.sku,
        p.category_id,
        c.category_name,
        SUM(si.quantity)    AS total_qty_sold,
        ROUND(SUM(si.line_total), 4)  AS total_revenue,
        ROUND(SUM(si.tax_amount), 4)  AS total_tax
    FROM dbo.sale_items si
    JOIN dbo.sales s   ON s.sale_id = si.sale_id
    JOIN dbo.products p ON p.product_id = si.product_id
    LEFT JOIN dbo.categories c ON c.category_id = p.category_id
    WHERE s.status = N'COMPLETED'
    GROUP BY p.product_id, p.product_name, p.sku, p.category_id, c.category_name;
GO

-- ---------------------------------------------------------------------------
-- VW_InventoryReport
-- Current stock snapshot per product with stock status and stock value.
-- ---------------------------------------------------------------------------
IF OBJECT_ID(N'dbo.VW_InventoryReport', N'V') IS NOT NULL DROP VIEW dbo.VW_InventoryReport;
GO
CREATE VIEW dbo.VW_InventoryReport
AS
    SELECT
        p.product_id,
        p.product_name,
        p.sku,
        p.category_id,
        c.category_name,
        p.supplier_id,
        s.supplier_name,
        ISNULL(i.quantity_on_hand, 0)  AS quantity_on_hand,
        ISNULL(i.quantity_reserved, 0) AS quantity_reserved,
        p.low_stock_threshold,
        dbo.FN_StockStatus(ISNULL(i.quantity_on_hand, 0), p.low_stock_threshold) AS stock_status,
        p.cost_price AS unit_cost,
        ROUND(ISNULL(i.quantity_on_hand, 0) * ISNULL(p.cost_price, 0), 4) AS stock_value
    FROM dbo.products p
    LEFT JOIN dbo.categories c ON c.category_id = p.category_id
    LEFT JOIN dbo.suppliers  s ON s.supplier_id  = p.supplier_id
    LEFT JOIN dbo.inventory  i ON i.product_id    = p.product_id
    WHERE p.is_deleted = 0;
GO

-- ---------------------------------------------------------------------------
-- VW_InventoryMovementsReport
-- Audit trail of every stock movement with product + actor details.
-- ---------------------------------------------------------------------------
IF OBJECT_ID(N'dbo.VW_InventoryMovementsReport', N'V') IS NOT NULL DROP VIEW dbo.VW_InventoryMovementsReport;
GO
CREATE VIEW dbo.VW_InventoryMovementsReport
AS
    SELECT
        t.transaction_id,
        t.product_id,
        p.product_name,
        p.sku,
        t.movement_type,
        t.quantity,
        t.quantity_before,
        t.quantity_after,
        t.unit_cost,
        t.reference_type,
        t.reference_id,
        t.reason,
        u.username,
        t.created_at
    FROM dbo.inventory_transactions t
    JOIN dbo.products p ON p.product_id = t.product_id
    LEFT JOIN dbo.users u ON u.user_id = t.user_id;
GO

-- ---------------------------------------------------------------------------
-- VW_SupplierReport
-- Supplier summary: product count and total inventory value (cost basis).
-- ---------------------------------------------------------------------------
IF OBJECT_ID(N'dbo.VW_SupplierReport', N'V') IS NOT NULL DROP VIEW dbo.VW_SupplierReport;
GO
CREATE VIEW dbo.VW_SupplierReport
AS
    SELECT
        s.supplier_id,
        s.supplier_code,
        s.supplier_name,
        s.contact_person,
        s.email,
        s.phone,
        COUNT(p.product_id) AS product_count,
        ROUND(SUM(ISNULL(i.quantity_on_hand, 0) * ISNULL(p.cost_price, 0)), 4) AS total_stock_value
    FROM dbo.suppliers s
    LEFT JOIN dbo.products p ON p.supplier_id = s.supplier_id AND p.is_deleted = 0
    LEFT JOIN dbo.inventory i ON i.product_id = p.product_id
    WHERE s.is_deleted = 0
    GROUP BY s.supplier_id, s.supplier_code, s.supplier_name,
             s.contact_person, s.email, s.phone;
GO

-- ---------------------------------------------------------------------------
-- VW_CreditReport
-- Credit ledger per credit sale with overdue days computed in UTC.
-- ---------------------------------------------------------------------------
IF OBJECT_ID(N'dbo.VW_CreditReport', N'V') IS NOT NULL DROP VIEW dbo.VW_CreditReport;
GO
CREATE VIEW dbo.VW_CreditReport
AS
    SELECT
        cs.credit_sale_id,
        cs.sale_id,
        s.receipt_number,
        c.full_name AS customer_name,
        c.phone     AS customer_phone,
        cs.total_amount,
        cs.amount_paid,
        cs.outstanding_balance,
        cs.status,
        cs.due_date,
        CASE
            WHEN cs.status IN (N'OPEN', N'PARTIAL', N'OVERDUE') AND cs.due_date IS NOT NULL
                THEN DATEDIFF(DAY, cs.due_date, CAST(SYSUTCDATETIME() AS DATE))
            ELSE 0
        END AS days_overdue,
        cs.created_at
    FROM dbo.credit_sales cs
    JOIN dbo.sales      s ON s.sale_id = cs.sale_id
    JOIN dbo.customers  c ON c.customer_id = cs.customer_id;
GO

-- ---------------------------------------------------------------------------
-- VW_ReturnsReport
-- Return headers with original sale, customer, processor and reason.
-- ---------------------------------------------------------------------------
IF OBJECT_ID(N'dbo.VW_ReturnsReport', N'V') IS NOT NULL DROP VIEW dbo.VW_ReturnsReport;
GO
CREATE VIEW dbo.VW_ReturnsReport
AS
    SELECT
        r.return_id,
        r.return_number,
        r.sale_id,
        s.receipt_number AS sale_receipt_number,
        cu.full_name AS customer_name,
        u.full_name AS processor_name,
        r.total_refund_amount,
        r.status,
        rr.reason_name AS return_reason_name,
        r.notes,
        r.created_at
    FROM dbo.returns r
    JOIN dbo.sales s            ON s.sale_id = r.sale_id
    LEFT JOIN dbo.customers cu   ON cu.customer_id = r.customer_id
    JOIN dbo.users u            ON u.user_id = r.user_id
    LEFT JOIN dbo.return_reasons rr ON rr.return_reason_id = r.return_reason_id;
GO

-- ---------------------------------------------------------------------------
-- VW_ProfitReport
-- Gross profit per product using current cost_price (COMPLETED sales only).
-- ---------------------------------------------------------------------------
IF OBJECT_ID(N'dbo.VW_ProfitReport', N'V') IS NOT NULL DROP VIEW dbo.VW_ProfitReport;
GO
CREATE VIEW dbo.VW_ProfitReport
AS
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
    FROM dbo.sale_items si
    JOIN dbo.sales s    ON s.sale_id = si.sale_id
    JOIN dbo.products p ON p.product_id = si.product_id
    LEFT JOIN dbo.categories c ON c.category_id = p.category_id
    WHERE s.status = N'COMPLETED'
    GROUP BY p.product_id, p.product_name, p.sku, p.cost_price,
             p.category_id, c.category_name;
GO

-- ---------------------------------------------------------------------------
-- VW_PaymentMethodsReport
-- Payments volume per payment method (COMPLETED sales only).
-- ---------------------------------------------------------------------------
IF OBJECT_ID(N'dbo.VW_PaymentMethodsReport', N'V') IS NOT NULL DROP VIEW dbo.VW_PaymentMethodsReport;
GO
CREATE VIEW dbo.VW_PaymentMethodsReport
AS
    SELECT
        pm.payment_method_id,
        pm.method_name,
        COUNT(p.payment_id) AS payment_count,
        ROUND(SUM(p.amount), 4) AS total_amount
    FROM dbo.payment_methods pm
    JOIN dbo.payments p ON p.payment_method_id = pm.payment_method_id
    JOIN dbo.sales s    ON s.sale_id = p.sale_id AND s.status = N'COMPLETED'
    WHERE p.pay_status IN (N'COMPLETED', N'PARTIAL')
    GROUP BY pm.payment_method_id, pm.method_name;
GO

-- ---------------------------------------------------------------------------
-- VW_TaxReport
-- Collected tax per configured tax rate (COMPLETED sales only).
-- ---------------------------------------------------------------------------
IF OBJECT_ID(N'dbo.VW_TaxReport', N'V') IS NOT NULL DROP VIEW dbo.VW_TaxReport;
GO
CREATE VIEW dbo.VW_TaxReport
AS
    SELECT
        tr.tax_rate_id,
        tr.tax_name,
        tr.rate_percent,
        COUNT(s.sale_id) AS taxable_sales_count,
        ROUND(SUM(s.tax_amount), 4) AS total_tax_amount
    FROM dbo.tax_rates tr
    LEFT JOIN dbo.sales s ON s.tax_rate_id = tr.tax_rate_id AND s.status = N'COMPLETED'
    GROUP BY tr.tax_rate_id, tr.tax_name, tr.rate_percent;
GO
