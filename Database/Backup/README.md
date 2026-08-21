# SmartPOS Database — Backup & Restore

This folder is the **local backup destination** for the SmartPOS database.

## Where backups live

- Default location: `Database/Backup/`
- Configured by `BACKUP_DIR` in `Database/Configuration/.env`
  (a relative value is resolved against the `Database` root).
- Naming: `<DB_NAME>_<yyyyMMdd_HHmmss>.bak`
  e.g. `SmartPOS_20260807_143000.bak`

## Creating a backup

```cmd
cd /d "Database\Scripts"
backup_database.bat
```

```powershell
cd "Database\Scripts"
.\backup_database.ps1
```

The backup is a **full, compressed** backup (`BACKUP DATABASE ... WITH
COMPRESSION, STATS = 10`), written to `BACKUP_DIR` with a timestamped
filename. Progress is printed by `STATS` (10% steps).

## Retention

Old backups are purged automatically by the backup script.

- `BACKUP_KEEP_DAYS` in `Database/Configuration/.env` (default `14`).
- Any `*.bak` older than that number of days is deleted after a new backup
  is created.

## Restoring

```cmd
cd /d "Database\Scripts"
restore_database.bat "Database\Backup\SmartPOS_20260807_143000.bak"
restore_database.bat "Database\Backup\SmartPOS_20260807_143000.bak" /REPLACE
```

```powershell
.\restore_database.ps1 -BackupFile "Database\Backup\SmartPOS_20260807_143000.bak"
.\restore_database.ps1 -BackupFile "Database\Backup\SmartPOS_20260807_143000.bak" -Replace
```

- `/REPLACE` (or `-Replace`) is **required** if the `SmartPOS` database
  already exists — the scripts refuse to overwrite without it.
- The restore forces `SINGLE_USER WITH ROLLBACK IMMEDIATE` so open
  connections do not block the restore, then returns the database to
  `MULTI_USER`.

## Verifying a backup file without restoring

```cmd
sqlcmd -S "localhost,1433" -U sa -P "***" -d master -b -Q "RESTORE VERIFYONLY FROM DISK = N'Database\Backup\SmartPOS_20260807_143000.bak';"
```

## Recommended workflow

1. Take a full backup after every successful setup/migration.
2. Verify each new backup with `RESTORE VERIFYONLY`.
3. Copy critical `.bak` files off the machine periodically (the local
   `Backup/` folder is not a DR strategy on its own).
4. Keep `BACKUP_KEEP_DAYS` set so disk usage stays bounded.

## IMPORTANT — do not commit this folder

Backup files are large, binary, and machine-specific. This folder **must
never be committed** to version control.

- A `.gitignore` in this folder ignores `*.bak` files.
- Treat every `.bak` here as sensitive data: it contains the entire
  SmartPOS data store.
