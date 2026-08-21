# SmartPOS Database — Restore Guide

**Document ID:** DOC-DB-RESTORE
**Version:** 1.0
**Status:** Approved
**Date:** August 7, 2026

Operational procedure for restoring the **SmartPOS** database from backups,
including point-in-time recovery and cross-server restores. Always restore to
the point that loses the **least** data consistent with the incident.

---

## 1. Restore Prerequisites

Before any restore:

1. Confirm you have the **latest** full + subsequent differentials + all log
   backups in the chain (check `msdb.dbo.backupset`).
2. Confirm you have the **backup encryption certificate + password** (see
   [`SecurityGuide.md`](SecurityGuide.md) §6.2 and
   [`BackupGuide.md`](BackupGuide.md) §8). Without it the backup is
   unrecoverable.
3. Confirm enough disk for the data + log files.
4. Notify the store(s): a restore locks the application.

### 1.1 Restore decision tree

| Situation | Restore to |
|-----------|------------|
| Logical corruption found late, no recent critical sales | Latest **full + latest differential** |
| Small data loss unacceptable (recent sales, payments, credit) | Latest full + diff + **all logs**, recovery at `STOPAT` (point in time) |
| File/folder loss on server | Restore full + logs to the same server |
| Full server loss / new hardware | Cross-server restore (see §5) |

### 1.2 Logical file names

The default file layout for `SmartPOS`:

| Logical name | Purpose |
|--------------|---------|
| `SmartPOS` | Primary data file (`.mdf`) |
| `SmartPOS_log` | Transaction log (`.ldf`) |

Use `RESTORE FILELISTONLY` if names differ on your instance:

```sql
RESTORE FILELISTONLY FROM DISK = N'D:\Backup\SmartPOS_FULL_20260807_020000.bak';
```

---

## 2. Restore Scripts

Two equivalent drivers are provided in `Database/Scripts/`:

- `restore_database.bat` — Windows batch wrapper
- `restore_database.ps1` — PowerShell script (recommended)

Both read `Database/Configuration/.env` (see
[`ConfigurationGuide.md`](ConfigurationGuide.md)) and use `sqlcmd` to execute
the T-SQL in §3, then run the verification steps in §4. They accept the backup
file to restore and an optional `STOPAT` time for point-in-time recovery.

> Note: at the time of writing `Database/Scripts/` is an empty scaffold
> folder; create/import these scripts before you need them. The T-SQL below
> is the canonical procedure they wrap and can be run directly with `sqlcmd`.

---

## 3. Canonical T-SQL

### 3.1 Restore full only (latest point of the full backup)

```sql
RESTORE DATABASE SmartPOS
FROM DISK = N'D:\Backup\SmartPOS_FULL_20260807_020000.bak'
WITH REPLACE,
     CHECKSUM,
     MOVE 'SmartPOS'     TO N'D:\Data\SmartPOS.mdf',
     MOVE 'SmartPOS_log' TO N'D:\Data\SmartPOS_log.ldf',
     RECOVERY;
```

### 3.2 Full + differential + logs (most recent backup point)

```sql
-- Step 1: full, left in NORECOVERY so the chain can continue
RESTORE DATABASE SmartPOS
FROM DISK = N'D:\Backup\SmartPOS_FULL_20260807_020000.bak'
WITH REPLACE, CHECKSUM,
     MOVE 'SmartPOS'     TO N'D:\Data\SmartPOS.mdf',
     MOVE 'SmartPOS_log' TO N'D:\Data\SmartPOS_log.ldf',
     NORECOVERY;

-- Step 2: the latest differential (optional but faster than replaying logs)
RESTORE DATABASE SmartPOS
FROM DISK = N'D:\Backup\SmartPOS_DIFF_20260807_080000.dif'
WITH NORECOVERY, CHECKSUM;

-- Step 3: every log backup taken AFTER the differential, in order
RESTORE LOG SmartPOS
FROM DISK = N'D:\Backup\SmartPOS_LOG_20260807_081500.trn'
WITH NORECOVERY, CHECKSUM;
RESTORE LOG SmartPOS
FROM DISK = N'D:\Backup\SmartPOS_LOG_20260807_083000.trn'
WITH NORECOVERY, CHECKSUM;
-- ... repeat for each subsequent log ...

-- Step 4: bring the database online
RESTORE DATABASE SmartPOS WITH RECOVERY;
```

> `NORECOVERY` on every step except the last keeps the database in
> "Restoring" state so further logs can be applied. Applying the final
> `RECOVERY` makes it available to the application.

### 3.3 Point-in-time recovery (STOPAT)

To restore to a specific moment (e.g. just before an erroneous `DELETE`):

```sql
-- Steps 1 and 2 exactly as above (full + diff, NORECOVERY), then:
RESTORE LOG SmartPOS
FROM DISK = N'D:\Backup\SmartPOS_LOG_20260807_083000.trn'
WITH STOPAT = N'2026-08-07T08:27:12', RECOVERY, CHECKSUM;
```

- Set `STOPAT` on the **last** log in the chain only.
- Do **not** apply any log backup whose backup time is after the STOPAT.
- `STOPAT` uses **server-local time by default**; because SmartPOS stores
  timestamps as UTC (`SYSUTCDATETIME()`), use `STOPAT` with the UTC instant
  of the incident (`STOPAT = N'...' AT TIME ZONE 'UTC'` where supported).

### 3.4 Restore to an alternative database (safety/sandbox)

```sql
RESTORE DATABASE SmartPOS_RestoreTest
FROM DISK = N'D:\Backup\SmartPOS_FULL_20260807_020000.bak'
WITH MOVE 'SmartPOS'     TO N'D:\Data\RestoreTest.mdf',
     MOVE 'SmartPOS_log' TO N'D:\Data\RestoreTest_log.ldf',
     RECOVERY, CHECKSUM;
```

Use this for test restores and for investigating incidents without touching
the production database.

---

## 4. Post-Restore Verification

Never declare an incident closed without verifying data quality:

1. **Run the integrity suite** against the restored database:
   - `Testing/00_schema_integrity.sql` (objects present)
   - `Testing/02_relationship_integrity.sql` (FK wiring intact)
   - `Testing/12_smoke_full.sql` (end-to-end smoke)
   (Execute via `run_tests.sh` or `sqlcmd` pointing at the restored DB.)
2. **Sanity queries**:
   ```sql
   SELECT COUNT(*) FROM sales;
   SELECT MAX(created_at), MIN(created_at) FROM sales;
   SELECT TOP 5 * FROM security_logs ORDER BY created_at DESC;
   SELECT SUM(outstanding_balance) FROM credit_sales WHERE status IN ('OPEN','PARTIAL');
   ```
   Confirm the last sale timestamp matches the expected recovery point.
3. **Run the smoke test scripts** if the suite includes one
   (`Testing/12_smoke_full.sql`).
4. Verify the application can log in (`SP_Login`) and open a test sale.
5. Re-establish a **fresh full backup** as soon as the restore is accepted —
   the restored chain is now the baseline.

---

## 5. Cross-Server Restores (New Hardware / DR)

1. Install SQL Server with the same version/collation (`SQL_Latin1_General_CP1_CI_AS`).
2. If the backups are encrypted, install the **backup certificate** on the new
   instance first:
   ```sql
   CREATE CERTIFICATE BackupCert
   FROM FILE = N'D:\Certs\BackupCert.cer'
   WITH PRIVATE KEY (FILE = N'D:\Certs\BackupCert.pfx',
                     DECRYPTION BY PASSWORD = N'<cert-password>');
   ```
3. Restore using §3.2/§3.3 with the same `MOVE` paths (or the new server's paths).
4. Recreate the application login + user mapping:
   ```sql
   CREATE LOGIN pos_app WITH PASSWORD = N'<generated-strong-password>',
       CHECK_POLICY = ON, CHECK_EXPIRATION = ON;
   ALTER SERVER ROLE sysadmin DROP MEMBER pos_app;   -- if accidentally present
   USE SmartPOS;
   CREATE USER pos_app FOR LOGIN pos_app;
   ALTER ROLE pos_app_role ADD MEMBER pos_app;
   ```
   The database role membership inside `SmartPOS` is restored with the
   database; only the login needs re-creating on the new instance.
5. Update the client connection strings (host/IP) in
   `Database/Configuration/.env` (see [`ConfigurationGuide.md`](ConfigurationGuide.md)).
6. Re-run `run_tests.sh` against the new instance before cutting over.

---

## 6. Restore Security

- Only DBA/operations accounts may perform restores; grant `RESTORE` to a
  dedicated ops role, never to the `pos_app` application login.
- Log every restore (who, when, from which backup, recovery point).
- Test restores run against **separate staging databases**, never over the
  production database.

---

## 7. Common Restore Failures

| Error | Cause | Fix |
|-------|-------|-----|
| `Cannot open backup device` | Wrong path / access | Verify file exists and share permissions |
| `The backup set holds a backup of a database other than ...` | Wrong file selected | `RESTORE FILELISTONLY`; use the correct chain |
| `RESTORE cannot process database ... in use` | Open connections | Kill sessions / set single-user: `ALTER DATABASE SmartPOS SET SINGLE_USER WITH ROLLBACK IMMEDIATE;` before restore |
| `LSN not in the chain` | Skipped log / wrong order | Re-apply in exact order; or restart from a fresh full |
| Checksum error / `DATABASE IS CORRUPT` | Bad backup or source corruption | Use previous good backup; run `DBCC CHECKDB` on the source |

---

## 8. Revision History

| Version | Date | Description |
|---------|------|-------------|
| 1.0 | 2026-08-07 | Initial restore guide |
