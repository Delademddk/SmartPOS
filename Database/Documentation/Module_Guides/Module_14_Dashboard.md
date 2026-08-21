# Module 14 — Dashboard

**SQL source:** `Database/SQL/14_Dashboard/`
**Purpose:** KPI and summary data for the POS dashboard.

## Dashboard Views

| View | Content |
|------|---------|
| `VW_DashboardKPIs` | Top-level KPIs (sales today, transactions, average ticket, low stock count). |
| `VW_RecentSales` | Latest sales (for the "recent activity" panel). |
| `VW_TopProducts` | Best-selling products by revenue. |
| `VW_SalesTrend7d` | Sales trend over the last 7 days. |
| `VW_SalesByCategory` | Revenue grouped by category. |
| `VW_SalesByPaymentMethod` | Revenue grouped by tender type. |
| `VW_RecentNotifications` | Recent notifications for the bell panel. |
| `VW_OutstandingCredit` | Customers with outstanding credit. |

## Stored Procedures

| Procedure | Purpose |
|-----------|---------|
| `SP_GetDashboardMetrics` | KPI snapshot for the top bar. |
| `SP_GetDashboardData` | Combined dashboard payload (metrics + recent sales + top products + trend). |
| `SP_GetSalesByCategory` | Revenue by category for charts. |
| `SP_GetTopProducts` | Top-N products by revenue. |
| `SP_GetSalesTrend` | Time-series trend (hourly/daily) for a window. |

## Dependencies

- Modules 02, 05, 07, 08, 09, 10, 12 (data sources).
- `VW_RecentNotifications` reads Module 12 notifications.

## Notes

- Dashboard queries are lightweight and time-windowed; see [`PerformanceGuide.md`](../PerformanceGuide.md) §4 for tuning.
- `SP_GetDashboardData` aggregates the dashboard views into a single result for one round-trip.
