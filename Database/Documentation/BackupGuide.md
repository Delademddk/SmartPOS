# SmartPOS Database — Backup Guide

**Document ID:** DOC-DB-BACKUP
**Version:** 1.0
**Status:** Approved
**Date:** August 7, 2026

Operational procedure for backing up the **SmartPOS** database. A POS system
is a point-of-sale **financial system** — a lost day of sales or credit
balances is a business-impacting incident. Backups must be scheduled,
verified, encrypted, and stored off-site.

---

## 1. Backup Strategy

The database ships with utility scripts in `Database/Scripts/` and
configuration in `Database/Configuration/`. The recommended scheme is a
standard **Full + Differential + Transaction Log** rotation:

| Frequency | Type | Retention | Purpose |
|-----------|------|-----------|---------|
| Daily (off-peak, e.g. 02:00) | **Full** | 30 days (`BACKUP_KEEP_DAYS` configurable, default 14) | Restorable restore point |
| Every 6 hours | **Differential** | 7 days | Faster restores between fulls |
| Every 15–30 min (or per transaction activity) | **Transaction log** | 24–48 h | Point-in-time recovery, minimal data loss |

> Tuning: the backup frequency should reflect the amount of sale data the
> business can afford to lose. For a busy POS, 15-minute log backups are a
> sensible default; for low-traffic stores, hourly is acceptable.

### 1.1 Recovery model

The database must run in **FULL recovery model** for the log-backup scheme
above:

```sql
ALTER DATABASE SmartPOS SET RECOVERY FULL;
BACKUP DATABASE SmartPOS TO DISK = 'NUL';   -- establishes the log backup chain
```

Backup `SET` options that matter:

| Option | Value | Why |
|--------|-------|-----|
| `COPY_ONLY` | off for scheduled jobs | Preserves the normal differential/log chain |
| `INIT` / `FORMAT` | `INIT` on the daily full | Overwrites the daily file rather than appending |
| `COMPRESSION` | on | Smaller files, faster transfer |
| `ENCRYPTION` | on (AES 256) | Backups contain live financial data; see [`SecurityGuide.md`](SecurityGuide.md) §6.2 |

---

## 2. Backup Scripts

Two equivalent drivers are provided in `Database/Scripts/`:

- `backup_database.bat` — Windows batch wrapper
- `backup_database.ps1` — PowerShell script (recommended; same logic)

Both read `Database/Configuration/.env` (see
[`ConfigurationGuide.md`](ConfigurationGuide.md)) for `DB_HOST`, `DB_PORT`,
`DB_NAME`, `DB_USERNAME`, `DB_PASSWORD`, `BACKUP_DIR`, `BACKUP_KEEP_DAYS`,
`SQLCMD_BINARY`, and `DB_TRUSTED_CONNECTION`, then execute the equivalent of
the T-SQL in §3 against `sqlcmd`.

The backup file naming convention is:

```
SmartPOS_{dbname}_FULL_{yyyyMMdd_HHmmss}.bak
SmartPOS_{dbname}_DIFF_{yyyyMMdd_HHmmss}.dif
SmartPOS_{dbname}_LOG_{yyyyMMdd_HHmmss}.trn
```

> Note: at the time of writing, `Database/Scripts/` and `Database/Backup/`
> are empty placeholders created by the project scaffold. Create/import the
> scripts, and make `BACKUP_DIR` point to the live backup share, before
> scheduling. The T-SQL below is the canonical procedure the scripts wrap.

---

## 3. Canonical T-SQL

### 3.1 Full backup

```sql
BACKUP DATABASE SmartPOS
TO DISK = N'D:\Backup\SmartPOS_FULL_20260807_020000.bak'
WITH INIT,
     COMPRESSION,
     STATS = 10,
     CHECKSUM,                                   -- detect corrupt pages at restore
     ENCRYPTION (ALGORITHM = AES_256,
                 SERVER CERTIFICATE = BackupCert);
```

### 3.2 Differential backup

```sql
BACKUP DATABASE SmartPOS
TO DISK = N'D:\Backup\SmartPOS_DIFF_20260807_080000.dif'
WITH INIT,
     COMPRESSION,
     CHECKSUM;
```

### 3.3 Transaction log backup

```sql
BACKUP LOG SmartPOS
TO DISK = N'D:\Backup\SmartPOS_LOG_20260807_081500.trn'
WITH INIT,
     COMPRESSION,
     CHECKSUM;
```

### 3.4 Verify a backup immediately

```sql
RESTORE VERIFYONLY FROM DISK = N'D:\Backup\SmartPOS_FULL_20260807_020000.bak'
WITH CHECKSUM;
```

`RESTORE VERIFYONLY` validates that the file is readable and, with
`CHECKSUM`, that pages are intact. **Run it on every backup** — an unverified
backup is a rumor, not a backup.

---

## 4. Scheduling & Retention

### 4.1 Windows Task Scheduler example

| Task | Trigger | Action |
|------|---------|--------|
| Full | Daily 02:00 | `powershell -File D:\SmartPOS\Scripts\backup_database.ps1 -Type Full` |
| Diff | Daily 08:00 / 14:00 / 20:00 | same script, `-Type Diff` |
| Log | Every 15 min | same script, `-Type Log` |

### 4.2 Retention

- The scripts prune backups older than `BACKUP_KEEP_DAYS` (default **14**) in
  `BACKUP_DIR` based on file names. Adjust the value in
  `Database/Configuration/.env`; never set it to 0 in production.
- Keep at least the **last 30 days** of fulls off-site regardless of local
  retention.
- Keep a **monthly** archive full that is copied to cold/off-site storage.

### 4.3 Off-site copies

1. Copy the daily full + the day's logs to a separate server / object storage
   (Azure Blob, S3, or an encrypted NAS) after each successful backup.
2. Use a short retention there too (e.g. 14–30 days) plus the monthly archive.
3. Never store backups in the same physical location/rack as the live server.

---

## 5. Verification & Test Restores

1. **Verify immediately** after every backup (`RESTORE VERIFYONLY WITH CHECKSUM`).
2. **Test restore daily/weekly.** Restore the latest full + logs to a
   **staging instance** (`SmartPOS_RestoreTest`) and run the verification
   suite:
   ```sql
   RESTORE DATABASE SmartPOS_RestoreTest FROM DISK = N'...full.bak'
   WITH MOVE 'SmartPOS' TO N'D:\Data\RestoreTest.mdf',
        MOVE 'SmartPOS_log' TO N'D:\Data\RestoreTest_log.ldf',
        REPLACE, CHECKSUM;
   RESTORE DATABASE SmartPOS_RestoreTest FROM DISK = N'...log.trn'
   WITH RECOVERY;
   ```
   then execute `Testing/00_schema_integrity.sql` and a smoke query
   (`SELECT TOP 1 * FROM sales ORDER BY sale_id DESC;`) against the staging DB.
3. **Document restore times.** Measure full + log apply duration so recovery
   time is known in advance (RTO).

---

## 6. Monitoring & Alerts

- Treat "backup failed" as **P0**. Configure alerts on the scheduled tasks.
- Add a health check that asserts `backup_finish_date` is fresh:

```sql
SELECT TOP 1 database_name, type, backup_finish_date, backup_size
FROM msdb.dbo.backupset
WHERE database_name = 'SmartPOS'
ORDER BY backup_finish_date DESC;
```

- Alarm if `DATEDIFF(MINUTE, backup_finish_date, GETUTCDATE())` exceeds the
  expected interval (e.g. > 25 h for the daily full).
- Monitor free space in `BACKUP_DIR`; an unwritable backup target silently
  kills the chain.

---

## 7. Common Failures & Recovery

| Symptom | Cause | Fix |
|---------|-------|-----|
| `BACKUP failed to complete` / disk full | Target full | Free space, resize `BACKUP_DIR`, then retry full backup |
| Verify fails with checksum error | Corrupted page/backup | Restore previous good backup; run `DBCC CHECKDB` on source |
| Log chain broken | Non-log backup or COPY_ONLY misuse | Take a fresh full backup to re-establish the chain |
| Encryption key lost | Certificate missing | Store backup certificate + password off-site; see RestoreGuide |

---

## 8. Backup Security

- Encrypt all backups (AES 256, `SERVER CERTIFICATE`). **Store the backup
  certificate and its password off-site** — without it the backup cannot be
  restored.
- Restrict `Database/Backup/` and the off-site target ACLs to DBA/service
  accounts only.
- Never ship backups over unencrypted channels; use SFTP/FTPS/TLS.

---

## 9. Revision History

| Version | Date | Description |
|---------|------|-------------|
| 1.0 | 2026-08-07 | Initial backup guide |
