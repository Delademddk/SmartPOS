# SmartPOS Database — Operational Scripts

All operational tooling for the SmartPOS SQL Server database. Every script
reads connection settings **exclusively from environment variables** loaded
from `Configuration/.env` (falling back to `Configuration/database.env`).
No credentials are hardcoded anywhere.

## Script index

| File | Purpose |
|------|---------|
| `setup_database.bat` / `.ps1` | Full build: creates the DB if missing, applies all SQL modules in FK order, seeds, verifies. |
| `verify_database.bat` / `.ps1` | Runs the `Testing\00..12` suites; prints PASS/FAIL; exits non-zero on failure. |
| `backup_database.bat` / `.ps1` | Full compressed backup to `%BACKUP_DIR%` with a timestamped name + retention purge. |
| `restore_database.bat` / `.ps1` | Restores from a `.bak` file; `/REPLACE` (`-Replace`) required to overwrite an existing DB. |
| `reset_database.bat` / `.ps1` | Drops (after a typed confirmation) and re-creates the DB, then re-runs the full setup. |
| `sqlcmd_examples.bat` | Reference file of common sqlcmd invocations (executes nothing). |

## Common requirements

- Windows 7+ with SQL Server Command Line Utilities (`sqlcmd`) on `PATH`.
- PowerShell 5.1+ (or 7) for the `.ps1` scripts; the `SqlServer` module is
  optional — the scripts fall back to `sqlcmd.exe` automatically.
- SQL Server 2016+ (uses `OPENJSON`, `FOR JSON`, `STRING_SPLIT`).

### Environment file precedence

1. `Database/Configuration/.env` (live config — keep out of version control)
2. `Database/Configuration/database.env` (committed template fallback)

Copy `database.env.example` → `.env` and set real values before running.

---

## Usage — Windows Command Prompt (`.bat`)

```cmd
cd /d "C:\Users\Darlington Kegu\React\POS\SmartPOS\Database\Scripts"

rem Full setup (create + build + seed + verify)
setup_database.bat

rem Skip sample data during setup
set RUN_SAMPLE_DATA=0 && setup_database.bat

rem Verify with the full test suite
verify_database.bat

rem Backup
backup_database.bat

rem Restore (REPLACE required when the database exists)
restore_database.bat "Database\Backup\SmartPOS_20260807_143000.bak"
restore_database.bat "Database\Backup\SmartPOS_20260807_143000.bak" /REPLACE

rem Reset (type RESET at the prompt)
reset_database.bat
```

## Usage — PowerShell (`.ps1`)

```powershell
cd "C:\Users\Darlington Kegu\React\POS\SmartPOS\Database\Scripts"
powershell -ExecutionPolicy Bypass -File .\setup_database.ps1

.\verify_database.ps1
.\backup_database.ps1
.\restore_database.ps1 -BackupFile "Database\Backup\SmartPOS_20260807_143000.bak"
.\restore_database.ps1 -BackupFile "Database\Backup\SmartPOS_20260807_143000.bak" -Replace
.\reset_database.ps1
```

Every `.ps1` also accepts an explicit `-EnvFile` parameter:

```powershell
.\setup_database.ps1 -EnvFile "Configuration\database.env"
```

## Windows vs PowerShell

| Concern | `.bat` | `.ps1` |
|---------|--------|--------|
| Runtime | cmd.exe (any Windows) | PowerShell 5.1+ / 7 |
| Default SQL driver | `sqlcmd` (required) | `Invoke-Sqlcmd` if the `SqlServer` module is loaded, else `sqlcmd.exe` |
| Stop-on-error | `if errorlevel 1` per step | `$ErrorActionPreference = 'Stop'` + `exit 1` |
| Timestamps | via `powershell -Command Get-Date` | native `Get-Date` |
| Interactive confirm (reset) | `set /p` | `Read-Host` |

Use the `.bat` scripts for simple, dependency-free automation (scheduled
tasks, CI on Windows agents). Use the `.ps1` scripts when you want richer
error output and module-based SQL execution.

## Build order reference

The setup scripts apply SQL modules in strict FK dependency order — see
`../SQL/README.md` and the `$sqlFiles` / `SQL_FILES` list inside the setup
scripts:

`17_Shared/functions.sql` → module `tables.sql` (01→16) → module `SP_*.sql`
→ `Views/Core_Operational_Views.sql` → reports/dashboard views+SPs →
`Triggers/All_Triggers.sql` → `SeedData/SeedData.sql` →
`SampleData/SampleData.sql` (optional).

Do not re-order these lists; a failed run can be retried safely because every
SQL module is idempotent.

## Exit codes

- `0` — success.
- `1` — any failure (setup/verify/backup/restore abort at the first error).

## Related: repo-root project scripts (Project Bible)

The **Project Bible** requirement specifies repo-root drivers that orchestrate
the full stack:

- `setup_backend.bat` — installs backend dependencies and starts the API.
- `setup_frontend.bat` — installs frontend dependencies.
- `start_project.bat` — starts backend + frontend together.
- `setup_database.bat` — delegates to `Database\Scripts\setup_database.bat`
  in this folder (the database half of the Project Bible).

Those batch files live at the **repository root**
(`C:\Users\Darlington Kegu\React\POS\SmartPOS\`), not under `Database/Scripts/`.
The database scripts documented here are the back-end those drivers invoke.
