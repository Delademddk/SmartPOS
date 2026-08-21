# Module 13 — Reports

**SQL source:** `Database/SQL/13_Reports/`
**Purpose:** Read-only reporting views and procedures over transactional data.

## Report Views

| View | Content |
|------|---------|
| `VW_SalesSummary` | Aggregated sales summary (per sale/period). |
| `VW_DailySales` | Sales aggregated by day. |
| `VW_ProductSalesReport` | Sales by product (units, revenue). |
| `VW_InventoryReport` | Stock levels, values and status. |
| `VW_InventoryMovementsReport` | Inventory movement journal aggregated. |
| `VW_SupplierReport` | Purchases/stock per supplier. |
| `VW_CreditReport` | Credit sales and outstanding balances. |
| `VW_ReturnsReport` | Returns and refund totals. |
| `VW_ProfitReport` | Revenue vs cost, profit per product/period. |
| `VW_PaymentMethodsReport` | Payments grouped by tender type. |
| `VW_TaxReport` | Tax collected by rate/period. |

## Stored Procedures

| Procedure | Purpose |
|-----------|---------|
| `SP_SalesReport` | Sales report over a date range. |
| `SP_InventoryReport` | Inventory report. |
| `SP_InventoryMovementsReport` | Movement journal report. |
| `SP_SupplierReport` | Supplier report. |
| `SP_CreditReport` | Credit ledger report. |
| `SP_ReturnsReport` | Returns report. |
| `SP_ProfitReport` | Profit report. |
| `SP_TaxReport` | Tax report. |
| `SP_PaymentMethodsReport` | Payment methods report. |
| `SP_ProductSalesReport` | Product sales report. |
| `SP_ExportReport` | Export a report result set (validated parameters; `sp_executesql` with parameters, never concatenated user input). |

## Dependencies

- Modules 02, 05, 06, 07, 08, 09, 10, 11 (transactional data).
- Performance guidance in [`PerformanceGuide.md`](../PerformanceGuide.md) §4 applies (always filter by time, aggregate on views, parameterize).

## Notes

- All reports accept `@StartDate`/`@EndDate` (UTC) and exclude `VOIDED` sales where relevant.
- These views are read-only; the application role has `SELECT` only.
