# SmartPOS Database — Install Guide

End-to-end instructions for installing the SmartPOS database on a fresh SQL
Server instance using the operational scripts in `Database/Scripts/`.

---

## 1. Prerequisites

| Requirement | Value |
|-------------|-------|
| SQL Server | 2016 or newer (uses `OPENJSON`, `FOR JSON`, `STRING_SPLIT`) |
| Collation | `SQL_Latin1_General_CP1_CI_AS` (configurable via `DB_DEFAULT_COLLATION`) |
| Tools | `sqlcmd` on PATH (see §2) |
| Permissions | A login with `CREATE DATABASE` + `db_owner` on the target |
| Client network | Firewall rule for TCP 1433 (or your configured port) |

Confirm `sqlcmd` is available:

```bash
sqlcmd -?
```

---

## 2. SQL Server Configuration

### 2.1 Enable SQL Server Authentication (mixed mode)

1. Open **SQL Server Management Studio** and connect to the instance.
2. Right-click the server → **Properties** → **Security**.
3. Under **Server authentication**, select **SQL Server and Windows
   Authentication mode**.
4. Restart the SQL Server service (`services.msc` → SQL Server (MSSQLSERVER) →
   Restart, or `net stop MSSQLSERVER && net start MSSQLSERVER`).

### 2.2 Set / verify the `sa` password

```sql
ALTER LOGIN sa WITH PASSWORD = N'Your_Strong_Password_2026',
    CHECK_POLICY = ON, CHECK_EXPIRATION = OFF;
```

> Use a strong password and store it ONLY in `Configuration/.env`.
> Never commit it.

### 2.3 Enable TCP/IP and set the port

1. Open **SQL Server Configuration Manager**.
2. **SQL Server Network Configuration** → **Protocols for MSSQLSERVER** →
   enable **TCP/IP**.
3. Under **IP Addresses** → **IPAll**, set **TCP Port** to `1433`.
4. Restart the SQL Server service.

### 2.4 Open the firewall (server side)

```powershell
# From an elevated PowerShell on the SQL Server:
New-NetFirewallRule -DisplayName "SQL Server 1433" `
    -Direction Inbound -Protocol TCP -LocalPort 1433 -Action Allow
```

### 2.5 Using a named instance instead of a port

If the instance is named (e.g. `MSSQLSERVER`), set `DB_INSTANCE=MSSQLSERVER`
in `.env` and leave `DB_PORT` alone. The scripts build the server string as
`host\instance`; otherwise they use `host,port`.

---

## 3. Create the environment file

The scripts read `Configuration/.env` first, then fall back to
`Configuration/database.env`.

1. Copy the example to a real file:

   ```cmd
   copy Database\Configuration\database.env.example Database\Configuration\.env
   ```

2. Edit `Database\Configuration\.env` and set real values:

   | Variable | Example | Notes |
   |----------|---------|-------|
   | `DB_HOST` | `localhost` or server IP | |
   | `DB_PORT` | `1433` | Ignored when `DB_INSTANCE` is set |
   | `DB_INSTANCE` | *(empty)* | e.g. `MSSQLSERVER` for a named instance |
   | `DB_USERNAME` | `sa` | SQL auth login |
   | `DB_PASSWORD` | `Your_Strong_Password_2026` | never commit |
   | `DB_NAME` | `SmartPOS` | database to create |
   | `DB_TRUSTED_CONNECTION` | `false` | `true` = Windows/AD auth (uses `-E`) |
   | `BACKUP_DIR` | `./Backup` | where `.bak` files are written |
   | `BACKUP_KEEP_DAYS` | `14` | retention for old backups |

> Keep `Configuration/.env` out of version control.
> `Configuration/database.env` is the committed template (placeholders only).

---

## 4. Run the setup

### Windows (Command Prompt / PowerShell)

```cmd
cd /d "C:\Users\Darlington Kegu\React\POS\SmartPOS\Database\Scripts"
setup_database.bat
```

or with PowerShell:

```powershell
cd "C:\Users\Darlington Kegu\React\POS\SmartPOS\Database\Scripts"
powershell -ExecutionPolicy Bypass -File .\setup_database.ps1
```

The setup script:
1. Checks whether `SmartPOS` exists (via a `sys.databases` query) and creates it
   if needed, applying `DB_DEFAULT_COLLATION`.
2. Applies every SQL module in FK build order (see `SQL/README.md`) with
   `sqlcmd -b` — the build stops at the first error.
3. Runs `SeedData/SeedData.sql` (required runtime data) and then
   `SampleData/SampleData.sql` (optional — set `RUN_SAMPLE_DATA=0` to skip).
4. Verifies key object counts and reports success.

The scripts resolve all paths relative to `Database/Scripts`, so the
space-containing repo path (`...\Darlington Kegu\...`) is handled automatically.

---

## 5. Seed & sample data

Seed data is applied automatically by the setup scripts. Notes:

- `SeedData/SeedData.sql` — roles, permissions, payment methods, default
  settings, admin user. **Required**.
- `SampleData/SampleData.sql` — illustrative records (15 products, 3 sales,
  1 return). **Optional**; disable with `set RUN_SAMPLE_DATA=0` (cmd) or
  `$env:RUN_SAMPLE_DATA = "0"` (PowerShell) before running setup.

After seeding, replace the placeholder password hashes for seed accounts with
real hashes before allowing logins (see `Documentation/SecurityGuide.md`).

---

## 6. Verification

Run the full test suite (00..12):

```cmd
verify_database.bat
```

or:

```powershell
.\verify_database.ps1
```

Each suite runs with `sqlcmd -b`; a `PASS/FAIL` summary is printed and the
script exits non-zero if any suite fails.

Quick manual sanity check:

```sql
SELECT COUNT(*) AS users    FROM dbo.users;
SELECT COUNT(*) AS products FROM dbo.products;
SELECT COUNT(*) AS sales    FROM dbo.sales;
SELECT COUNT(*) AS rows     FROM dbo.VW_SalesSummary;
```

---

## 7. Backup & restore

```cmd
rem Full backup to Database\Backup\SmartPOS_YYYYMMDD_HHMMSS.bak
backup_database.bat

rem Restore (overwrites only with /REPLACE)
restore_database.bat "Database\Backup\SmartPOS_20260807_143000.bak" /REPLACE
```

PowerShell equivalents: `.\backup_database.ps1` and
`.\restore_database.ps1 -BackupFile ... -Replace`.

See `Database/Backup/README.md` for the full backup/restore workflow.

---

## 8. Resetting the database

```cmd
reset_database.bat
```

Type `RESET` when prompted. The database is dropped (single-user mode first,
so open connections are rolled back) and the full setup runs again.

---

## 9. Troubleshooting

| Symptom | Cause / Fix |
|---------|-------------|
| `sqlcmd: command not found` | Install **SQL Server Command Line Utilities** (from the SQL Server install media / feature pack) and add its `Binn` folder to `PATH`, or set `SQLCMD_BINARY` to the full path in `.env`. |
| `Sqlcmd: Error: Locale ID not supported by the server` | Caused by encoding/locale mismatches; re-run with a `-u` flag or check the console code page. |
| `Login failed for user 'sa'` | SQL auth is not enabled (see §2.1) or wrong `DB_PASSWORD`/`DB_USERNAME`. |
| `Login failed ... password validation` / policy errors | `sa` password fails the instance policy — use a longer password with mixed case/digits. |
| `Cannot open database "SmartPOS"` | Database not created yet — run `setup_database.bat`. |
| `A connection was successfully established ... but then an error occurred` (TLS) | Server/client TLS mismatch; enable TLS 1.2 or use `Encrypt=Optional` in newer sqlcmd / connection strings. |
| `TCP/IP connection refused` | TCP/IP protocol disabled (§2.3) or firewall blocking 1433 (§2.4). |
| `The instance name is not valid` | You supplied a port and instance together, or the instance name is wrong. Use `host\instance` **or** `host,port`, never both. |
| `Database is in use / restore fails over existing DB` | Pass `/REPLACE` (bat) or `-Replace` (ps1); the scripts also force `SINGLE_USER WITH ROLLBACK IMMEDIATE`. |
| PowerShell will not run the script | Execution policy — run `powershell -ExecutionPolicy Bypass -File .\setup_database.ps1` or set the policy for the machine. |
| `SQLCMD_BINARY` default is `sqlcmd` but nothing happens | Confirm the path has no typo; set the full path to `sqlcmd.exe` in `.env`. |
| Build fails on a specific module | Modules are applied in FK order — never re-order the list inside `setup_database.*`. Each module is idempotent, so a failed run can be retried as-is. |

---

## 10. Post-install checklist

- [ ] `.env` created with real values; `database.env` untouched (template).
- [ ] `setup_database.bat` / `.ps1` completed with `[OK]`.
- [ ] `verify_database.bat` / `.ps1` reports `All test suites passed`.
- [ ] First full backup taken (`backup_database.bat`).
- [ ] Seed password hashes replaced (see DeploymentGuide §3.4).
- [ ] `pos_app` login + `pos_app_role` created with least privilege
      (see DeploymentGuide §3.3).
