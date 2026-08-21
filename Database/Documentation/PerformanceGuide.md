# SmartPOS Database — Performance Guide

**Document ID:** DOC-DB-PERF
**Version:** 1.0
**Status:** Approved
**Date:** August 7, 2026

Guidance for keeping the SmartPOS database fast at POS throughput (OLTP) and
for reporting workloads (OLAP-style queries over the report and dashboard
views).

---

## 1. Workload Profile

| Workload | Pattern | Example objects |
|----------|---------|-----------------|
| Point-of-sale (OLTP) | Short, high-frequency, single-row transactions | `SP_CreateSale`, `SP_RecordPayment`, `SP_ProcessReturn`, `SP_Login` |
| Master-data maintenance | Point lookups + small range scans | `SP_CreateProduct`, `SP_UpdateProduct`, `SP_GetProducts` |
| Reporting | Large range scans, grouped aggregations over time windows | `VW_SalesSummary`, `SP_SalesReport`, dashboard views |
| Audit | Append-mostly inserts + periodic archival | `audit_logs`, `SP_ArchiveAuditLogs` |

The same schema serves both. Keep OLTP paths point-indexed and push heavy
aggregation onto the reporting views (which are plain indexed views backed by
tables, not materialized aggregations) rather than scanning base tables from
the app.

---

## 2. Indexing Strategy

### 2.1 Naming convention

| Object | Pattern | Example |
|--------|---------|---------|
| Clustered index | `PK_<table>` (clustered PK) | `PK_products` |
| Nonclustered index | `IX_<table>_<columns>` | `IX_products_category_id` |
| Composite index | `IX_<table>_<col1>_<col2>` | `IX_inventory_transactions_product_id_movement_type` |
| Unique index | `UX_<table>_<columns>` | `UX_products_sku` |

### 2.2 Rules of thumb applied in the schema

1. **PKs are clustered INT `IDENTITY`** — sequential inserts avoid page
   splits and fragmentation.
2. **Every FK column is indexed.** This is the single highest-value rule:
   it accelerates joins and enforces child-delete checks quickly.
3. **Hot lookup columns get dedicated indexes:** `sku`, `barcode`,
   `receipt_number`, `customer_code`, `supplier_code`, `role_code`,
   `permission_code`, `setting_key`, `email`, `username`.
4. **Filtered/seeded columns:** status columns such as `sales.status`,
   `credit_sales.status`, `notifications.is_read` are best served by
   **filtered indexes** for the small, active subset.
5. **Composite indexes follow column selectivity:** most-selective column
   first; date-range filters pair well as the second key.
6. **Soft-delete tables** index `is_deleted` to keep active-row scans cheap.

### 2.3 Representative indexes

| Table | Index | Keys | Serves |
|-------|-------|------|--------|
| `products` | `UX_products_sku` / `UX_products_barcode` | `sku` / `barcode` | POS barcode/SKU scans |
| `sale_items` | `IX_sale_items_sale_id` | `sale_id` | Receipt and sale-detail lookups |
| `sale_items` | `IX_sale_items_product_id` | `product_id` | Product sales reporting |
| `sales` | `IX_sales_receipt_number` | `receipt_number` | Receipt by number |
| `sales` | `IX_sales_status_created_at` | `status, created_at` | Status + time-window reports |
| `inventory_transactions` | `IX_inventory_transactions_product_id_movement_type` | `product_id, movement_type` | Movement journals & inventory report |
| `payments` | `IX_payments_sale_id` | `sale_id` | Payment list per sale |
| `audit_logs` | `IX_audit_logs_resource_type_resource_id` | `resource_type, resource_id` | History per record |
| `notifications` | `IX_notifications_user_id_is_read` | `user_id, is_read` | Unread badge queries |
| `role_permissions` | `UX_role_permissions_role_permission` | `role_id, permission_id` | RBAC lookups |

### 2.4 Avoiding over-indexing

Every extra index slows `INSERT`/`UPDATE`/`DELETE` and grows storage. The
worst offenders are indexes that are never used by the optimizer. Audit the
index usage after deployment (see §5) and drop indexes that report zero seeks
or scans over a representative production window. Do **not** add indexes on
append-only log tables beyond the join/archival keys — they only slow the
writer.

---

## 3. Finding Missing Indexes

Run this over a representative production period (not right after
deployment, when the plan cache is cold):

```sql
SELECT TOP 50
    dm_mid.database_id,
    dm_mid.object_id,
    dm_mid.statement AS table_referenced,
    dm_migs.avg_user_impact,
    dm_migs.user_seeks,
    dm_migs.user_scans,
    'CREATE INDEX IX_'
        + REPLACE(REPLACE(REPLACE(OBJECT_NAME(dm_mid.object_id), 'dbo.', ''), ' ', '_'), '.', '_')
        + '_' + REPLACE(dm_mid.equality_columns, ', ', '_')
        + ISNULL('_' + REPLACE(dm_mid.inequality_columns, ', ', '_'), '')
        + ' ON ' + dm_mid.statement
        + ' (' + ISNULL(dm_mid.equality_columns, '')
        + ISNULL(', ' + dm_mid.inequality_columns, '') + ')'
        + ISNULL(' INCLUDE (' + dm_mid.included_columns + ')', '')
        + ';' AS proposed_index
FROM sys.dm_db_missing_index_group_stats AS dm_migs
JOIN sys.dm_db_missing_index_groups AS dm_mig
    ON dm_migs.group_handle = dm_mig.index_group_handle
JOIN sys.dm_db_missing_index_details AS dm_mid
    ON dm_mig.index_handle = dm_mid.index_handle
WHERE dm_mid.database_id = DB_ID()
ORDER BY dm_migs.avg_user_impact DESC;
```

Apply suggested indexes one at a time, re-test the affected procedures, and
watch for regression elsewhere before committing.

---

## 4. Report & Dashboard Query Tuning

The Reports (13) and Dashboard (14) modules read through dedicated views:
`VW_SalesSummary`, `VW_DailySales`, `VW_ProductSalesReport`,
`VW_InventoryReport`, `VW_InventoryMovementsReport`, `VW_SupplierReport`,
`VW_CreditReport`, `VW_ReturnsReport`, `VW_ProfitReport`,
`VW_PaymentMethodsReport`, `VW_TaxReport`, `VW_DashboardKPIs`,
`VW_RecentSales`, `VW_TopProducts`, `VW_SalesTrend7d`,
`VW_SalesByCategory`, `VW_SalesByPaymentMethod`, `VW_RecentNotifications`,
`VW_OutstandingCredit`, plus the core operational views (`VW_UserPermissions`,
`VW_ProductStock`, `VW_SalesWithLines`, `VW_CustomerBalances`,
`VW_LowStock`).

### 4.1 Tuning rules

1. **Always filter by time** on `created_at`/`transaction_date`. Reporting
   procedures accept `@StartDate`/`@EndDate` parameters; never scan the full
   history from the application.
2. **Push filters to the source.** The optimizer can often push predicates
   through views, but composite indexes like
   `IX_sales_status_created_at` only help when the predicate is in the
   `WHERE` clause the optimizer can match. Avoid wrapping view columns in
   functions inside `WHERE` (e.g. use
   `created_at >= @Start AND created_at < DATEADD(DAY, 1, @End)` instead of
   `CONVERT(DATE, created_at) BETWEEN ...`).
3. **Prefer parameterized procedures** (`SP_SalesReport`, ...) over ad-hoc
   SQL so the plan cache is reused.
4. **Use `NOCOUNT ON` and `SET XACT_ABORT ON`** at the top of every
   procedure to reduce round-trips and guarantee atomic error handling.
5. **Aggregate on the views, not base tables.** The dashboard procedures
   (`SP_GetDashboardMetrics`, `SP_GetDashboardData`, `SP_GetSalesByCategory`,
   `SP_GetTopProducts`, `SP_GetSalesTrend`) read from the dashboard views —
   keep it that way.
6. **Watch row-goals.** Tiny `TOP` on unindexed sorts (e.g. `ORDER BY
   created_at DESC`) causes sorts; ensure the composite index covers the
   ordering columns.

### 4.2 Common anti-patterns to avoid

- `SELECT *` from wide tables in reporting — list the columns you need.
- Correlated subqueries that re-scan `sale_items` per row — rewrite as joins
  or window functions (`SUM() OVER (PARTITION BY ...)`).
- `DISTINCT` on large result sets where a `GROUP BY` on an indexed column
  would do.
- Functions on indexed columns inside predicates (kills index seeks).

### 4.3 Example: tuned daily sales report

```sql
SELECT p.category_id,
       SUM(si.line_total)      AS revenue,
       SUM(si.tax_amount)      AS tax,
       COUNT(DISTINCT s.sale_id) AS sale_count
FROM sales AS s
JOIN sale_items AS si
    ON si.sale_id = s.sale_id
LEFT JOIN products AS p
    ON p.product_id = si.product_id
WHERE s.status <> 'VOIDED'
  AND s.created_at >= @Start
  AND s.created_at <  DATEADD(DAY, 1, @End)
GROUP BY p.category_id
ORDER BY revenue DESC;
```

---

## 5. Query & Index Health Checks

Run these periodically (production, quiet hours):

```sql
-- 1) Index usage: seeks vs scans vs updates
SELECT OBJECT_NAME(i.object_id) AS [table],
       i.name                  AS [index],
       i.type_desc,
       us.user_seeks, us.user_scans, us.user_lookups,
       us.user_updates
FROM sys.dm_db_index_usage_stats AS us
JOIN sys.indexes AS i
    ON i.object_id = us.object_id AND i.index_id = us.index_id
WHERE us.database_id = DB_ID()
ORDER BY us.user_seeks DESC;

-- 2) Fragmentation
SELECT OBJECT_NAME(ps.object_id) AS [table],
       i.name                    AS [index],
       ps.avg_fragmentation_in_percent
FROM sys.dm_db_index_physical_stats(
        DB_ID(), NULL, NULL, NULL, 'LIMITED') AS ps
JOIN sys.indexes AS i
    ON i.object_id = ps.object_id AND i.index_id = ps.index_id
WHERE ps.avg_fragmentation_in_percent > 5
ORDER BY ps.avg_fragmentation_in_percent DESC;

-- 3) Compile-heavy statements (plan cache)
SELECT TOP 20
    OBJECT_NAME(qs.object_id)              AS [object],
    qs.execution_count,
    qs.total_worker_time / qs.execution_count AS avg_worker_us,
    qs.total_logical_reads / qs.execution_count AS avg_reads,
    SUBSTRING(st.text,
        (qs.statement_start_offset / 2) + 1,
        ((CASE qs.statement_end_offset
            WHEN -1 THEN DATALENGTH(st.text)
            ELSE qs.statement_end_offset END
          - qs.statement_start_offset) / 2) + 1) AS statement_text
FROM sys.dm_exec_query_stats AS qs
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) AS st
WHERE qs.execution_count > 100
ORDER BY avg_reads DESC;
```

---

## 6. Concurrency & Isolation

### 6.1 Default isolation

The database runs under **READ COMMITTED**. For consistent, non-blocking
report reads, use **SNAPSHOT isolation**:

```sql
ALTER DATABASE SmartPOS SET ALLOW_SNAPSHOT_ISOLATION ON;
ALTER DATABASE SmartPOS SET READ_COMMITTED_SNAPSHOT ON;
```

With `READ_COMMITTED_SNAPSHOT ON`, regular read-committed statements get
row-version-based reads, so reports do not block POS writes and POS writes
do not block reports. **Requires** adequate `tempdb` space (version store
lives in tempdb).

### 6.2 Transaction boundaries in procedures

- `SP_CreateSale`, `SP_RecordPayment`, `SP_ProcessReturn`,
  `SP_RestockProduct`, `SP_AdjustStock` run inside explicit
  `BEGIN TRAN ... COMMIT/ROLLBACK` blocks with `XACT_ABORT ON`.
- Keep the transaction window as short as possible: validate first, mutate
  last, and never call external services inside the transaction.
- Use **lock hints sparingly** — the procedures use standard locking;
  add hints only after profiling shows deadlocks.

### 6.3 Deadlock avoidance

- Access tables in a consistent order across procedures (master data before
  transaction data; always `products` before `inventory_transactions`).
- Keep UPDATE statements keyed by clustered-index values.
- If deadlocks occur, capture the graph with `SET DEADLOCK_PRIORITY LOW` +
  `TRACEON 1204`/`1222` and review object access order.

---

## 7. Data Growth & Retention

| Table | Growth rate | Mitigation |
|-------|-------------|------------|
| `inventory_transactions` | High (every movement) | Index the movement; treat as append-only; archive per retention policy. |
| `audit_logs` | High | Partition by month; `SP_ArchiveAuditLogs` moves old rows to `audit_logs_archive`; see [`MaintenanceGuide.md`](MaintenanceGuide.md) §4. |
| `sale_items` / `sales` | Medium | Immutable history — retain per statutory retention; do not physically delete. |
| `low_stock_alerts` | Low-Medium | Resolve/dismiss alerts; prune resolved rows per policy. |
| `password_history` | Low | Capped at 5 per user by `TRG_password_history_retention`. |

Set the data files to **auto-growth** with a fixed increment (e.g. 512 MB,
not percentage), and pre-size the transaction log for expected peak
throughput (see [`MaintenanceGuide.md`](MaintenanceGuide.md) §6).

---

## 8. Performance Checklist Before Go-Live

- [ ] Every FK has a matching nonclustered index.
- [ ] Unique indexes exist on `sku`, `barcode`, `receipt_number`, `email`, `username`.
- [ ] `ALLOW_SNAPSHOT_ISOLATION` / `READ_COMMITTED_SNAPSHOT` enabled.
- [ ] tempdb sized for version store; data/log files use fixed auto-growth.
- [ ] Baseline captured for the 10 hottest procedures (`SP_CreateSale`,
      `SP_Login`, `SP_GetProducts`, `SP_GetStockLevel`, dashboard procs).
- [ ] Index-fragmentation script scheduled (see MaintenanceGuide).
- [ ] `run_tests.sh` passes on a production-sized data copy.

---

## 9. Revision History

| Version | Date | Description |
|---------|------|-------------|
| 1.0 | 2026-08-07 | Initial performance guide |
