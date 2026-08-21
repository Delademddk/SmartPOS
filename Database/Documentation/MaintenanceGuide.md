# SmartPOS Database — Maintenance Guide

**Document ID:** DOC-DB-MAINT
**Version:** 1.0
**Status:** Approved
**Date:** August 7, 2026

Routine and preventive maintenance for the **SmartPOS** database. A small,
well-maintained POS database stays fast and predictable; neglect shows up as
fragmented indexes, growing logs, bloated audit tables, and slow POS screens.

---

## 1. Maintenance Windows

| Frequency | Activity | Notes |
|-----------|----------|-------|
| Nightly (02:00, after full backup) | `DBCC CHECKDB` + index maintenance | Quiet hours; see §2, §3 |
| Weekly | Statistics refresh, log-size review | §3.2, §6 |
| Monthly | Audit-log archival, alert cleanup, retention review | §4, §5 |
| Quarterly | Full index consolidation, review `dm_db_index_usage_stats` | §2, [`PerformanceGuide.md`](PerformanceGuide.md) §5 |

Never run maintenance simultaneously with the backup job. Coordinate
schedules in Windows Task Scheduler / SQL Agent.

---

## 2. Index Maintenance

### 2.1 Fragmentation thresholds

| `avg_fragmentation_in_percent` | Action |
|-------------------------------|--------|
| 0 – 5 | Nothing |
| 5 – 30 | `ALTER INDEX ... REORGANIZE` |
| > 30 | `ALTER INDEX ... REBUILD` |

Measure first (this query is also in
[`PerformanceGuide.md`](PerformanceGuide.md) §5):

```sql
SELECT OBJECT_NAME(ps.object_id) AS [table],
       i.name                    AS [index],
       ps.avg_fragmentation_in_percent,
       ps.page_count
FROM sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL, 'LIMITED') AS ps
JOIN sys.indexes AS i
    ON i.object_id = ps.object_id AND i.index_id = ps.index_id
WHERE ps.index_id > 0
ORDER BY ps.avg_fragmentation_in_percent DESC;
```

### 2.2 Rebuild (heavily fragmented)

```sql
ALTER INDEX ALL ON dbo.sale_items REBUILD WITH (SORT_IN_TEMPDB = ON);
-- Or online (Edition-dependent):
ALTER INDEX ALL ON dbo.sale_items REBUILD WITH (ONLINE = ON);
```

Rebuild `sales`, `sale_items`, `inventory_transactions`, `payments`, and
`audit_logs` most frequently — they receive the heaviest writes.

### 2.3 Reorganize (moderately fragmented)

```sql
ALTER INDEX ALL ON dbo.inventory_transactions REORGANIZE;
```

### 2.4 Maintenance statement (single pass, 5–30% → reorganize, >30% → rebuild)

```sql
DECLARE @cmd NVARCHAR(MAX) = N'';
SELECT @cmd += N'
ALTER INDEX ' + QUOTENAME(i.name) + ' ON '
    + QUOTENAME(SCHEMA_NAME(t.schema_id)) + '.' + QUOTENAME(t.name)
    + CASE WHEN ps.avg_fragmentation_in_percent > 30 THEN ' REBUILD'
           ELSE ' REORGANIZE' END + ';' + CHAR(10)
FROM sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL, 'LIMITED') AS ps
JOIN sys.tables AS t ON t.object_id = ps.object_id
JOIN sys.indexes  AS i ON i.object_id = ps.object_id AND i.index_id = ps.index_id
WHERE ps.index_id > 0
  AND ps.avg_fragmentation_in_percent > 5
  AND ps.page_count > 1000
  AND i.name IS NOT NULL;
EXEC sp_executesql @cmd;
```

> For small tables (< 1000 pages) fragmentation is irrelevant; the page-count
> filter avoids wasted rebuilds.

---

## 3. Integrity & Statistics

### 3.1 `DBCC CHECKDB` (nightly)

```sql
DBCC CHECKDB (SmartPOS) WITH NO_INFOMSGS, PHYSICAL_ONLY;
```

- Run at least weekly; `PHYSICAL_ONLY` is fast for the nightly run.
- A **full** `DBCC CHECKDB (SmartPOS)` (no `PHYSICAL_ONLY`) should run
  monthly or whenever a `CHECKSUM`-verified restore is performed.
- If corruption is reported, **do not** write to the database; restore from
  the last verified backup (see [`RestoreGuide.md`](RestoreGuide.md)).

### 3.2 Statistics update

```sql
EXEC sp_updatestats;                       -- all statistics, may lock briefly
-- or targeted:
UPDATE STATISTICS dbo.sales;               -- heavy-table targeted refresh
UPDATE STATISTICS dbo.sale_items;
UPDATE STATISTICS dbo.inventory_transactions;
```

Refresh statistics for the transactional tables weekly, and immediately after
any large bulk load (e.g. restored dataset, large sample data import).

---

## 4. Audit Log Archival

`audit_logs` and `inventory_transactions` grow without bound unless archived.

### 4.1 `SP_ArchiveAuditLogs`

The procedure moves audit rows older than a cutoff into
`audit_logs_archive` (a separate, structurally identical table) and removes
them from the active table. Run monthly:

```sql
EXEC dbo.SP_ArchiveAuditLogs @OlderThan = N'2026-07-07T00:00:00';
```

### 4.2 Manual (if archival must be run outside the procedure)

```sql
BEGIN TRAN;
  INSERT INTO dbo.audit_logs_archive
  SELECT * FROM dbo.audit_logs
  WHERE created_at < @Cutoff;

  DELETE FROM dbo.audit_logs
  WHERE created_at < @Cutoff;
COMMIT;
```

- Always `BACKUP LOG` **after** a large delete to truncate the log space.
- Keep the **monthly** archived copy available for audit/legal retention.

### 4.3 Low-stock alert cleanup

`low_stock_alerts` rows become historical once resolved/dismissed. Keep
`RESOLVED`/`DISMISSED` rows for 30–90 days, then purge:

```sql
DELETE FROM dbo.low_stock_alerts
WHERE status IN ('RESOLVED', 'DISMISSED')
  AND updated_at < DATEADD(DAY, -90, SYSUTCDATETIME());
```

Also archive/retain `notification_history` per the notification policy, and
retire expired `user_sessions` and `password_resets` periodically:

```sql
DELETE FROM dbo.user_sessions   WHERE expires_at < SYSUTCDATETIME() AND is_revoked = 1;
DELETE FROM dbo.password_resets WHERE expires_at < SYSUTCDATETIME() OR used_at IS NOT NULL;
```

---

## 5. Transaction Log & File Growth

### 5.1 Monitor log size

```sql
DBCC SQLPERF(LOGSPACE);
```

Under FULL recovery, an oversized log is almost always a **backup problem** —
log backups not running. If the log grows unexpectedly:

1. Confirm the log-backup job is running (see [`BackupGuide.md`](BackupGuide.md) §6).
2. Run `BACKUP LOG SmartPOS TO DISK = ...` to truncate.
3. Shrink **only after** a successful log backup, and never on a schedule —
   shrink causes fragmentation:
   ```sql
   DBCC SHRINKFILE (N'SmartPOS_log', 0, TRUNCATEONLY);
   ```
4. Set **fixed-increment auto-growth** (e.g. 512 MB) instead of percentage:

```sql
ALTER DATABASE SmartPOS MODIFY FILE
    (NAME = SmartPOS, SIZE = 4GB, FILEGROWTH = 512MB);
ALTER DATABASE SmartPOS MODIFY FILE
    (NAME = SmartPOS_log, SIZE = 2GB, FILEGROWTH = 512MB);
```

### 5.2 Pre-size for peak load

Pre-size data/log files to expected peak before a busy season; pre-growing
files during trading causes I/O stalls.

---

## 6. Retention Policy Summary

| Data | Retention | Disposition |
|------|-----------|-------------|
| `audit_logs` | 30–90 days in active table | Archive to `audit_logs_archive` via `SP_ArchiveAuditLogs` |
| `audit_logs_archive` | Statutory / business retention | Retain on archived media |
| `inventory_transactions` | 12+ months | Report needs; archive if storage is tight |
| `sales`, `sale_items` | Indefinite (financial records) | Never delete; backup & archive |
| `low_stock_alerts` | 90 days after resolution | Purge |
| `user_sessions` | Past expiry + revoked | Purge |
| `password_resets` | Past expiry or used | Purge |
| `password_history` | 5 per user | Trigger-enforced |
| `error_logs` / `security_logs` | 6–12 months | Archive; keep security events longer for forensics |

---

## 7. Maintenance Health Checks

- Daily: backup success + `RESTORE VERIFYONLY` (see BackupGuide).
- Weekly: `DBCC CHECKDB ... PHYSICAL_ONLY`, log-space check, fragmentation
  report, top-10 slow statements (PerformanceGuide §5).
- Monthly: full `DBCC CHECKDB`, `SP_ArchiveAuditLogs`, statistics refresh,
  alert/notification cleanup, off-site backup copy test.
- On demand: `sp_updatestats` after big loads; `DBCC SHRINKFILE` only after
  log backup and only when genuinely oversized.

---

## 8. Maintenance Checklist

- [ ] Nightly CHECKDB + index maintenance scheduled off-peak.
- [ ] Weekly statistics refresh; log-size review.
- [ ] Monthly audit archival via `SP_ArchiveAuditLogs`.
- [ ] Retention purges scheduled (alerts, sessions, resets).
- [ ] Log auto-growth set to fixed increments; files pre-sized.
- [ ] `run_tests.sh` passes after any schema or script change.

---

## 9. Revision History

| Version | Date | Description |
|---------|------|-------------|
| 1.0 | 2026-08-07 | Initial maintenance guide |
