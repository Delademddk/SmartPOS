# Module 20 — Setup, Seed, Sample & Scripts

**SQL sources:** `Database/SQL/SeedData/`, `Database/SQL/SampleData/`,
`Database/Scripts/`, `Database/Configuration/`
**Purpose:** Install tooling, seed and sample data.

## Components

| Path | Purpose |
|------|---------|
| `Scripts/setup_database.bat` / `setup_database.ps1` | Build driver: create DB, run all SQL in FK order, verify. |
| `Scripts/verify_database.bat` / `verify_database.ps1` | Re-run the integrity checks against an installed DB. |
| `Scripts/backup_database.bat` / `backup_database.ps1` | Full/diff/log backups (see [`BackupGuide.md`](../BackupGuide.md)). |
| `Scripts/restore_database.bat` / `restore_database.ps1` | Restore / point-in-time restore (see [`RestoreGuide.md`](../RestoreGuide.md)). |
| `SQL/SeedData/SeedData.sql` | Idempotent seed: roles (ADMIN/MANAGER/CASHIER), permissions, role grants (95), system settings, default tax/currency/payment methods. |
| `SQL/SampleData/SampleData.sql` | Idempotent demo data: 15 products, 3 sales via `SP_CreateSale`, 1 return. |
| `Configuration/database.env.example` + `.env` | Runtime configuration (see [`ConfigurationGuide.md`](../ConfigurationGuide.md)). |
| `Configuration/connection.example.sql` | Sample connectivity check. |

> Note: at the time of writing `Database/Scripts/` and `Database/Backup/`
> are empty scaffold folders. Create/import the drivers listed above before
> relying on them; the canonical T-SQL they execute is fully documented in
> the Backup/Restore/Deployment guides and can be run directly with `sqlcmd`.

## Seed Details

- **Roles:** ADMIN (50 grants), MANAGER (34), CASHIER (11) — total 95 role-permission grants.
- **Seed password hashes are placeholders.** The installer must replace them
  and rely on `must_change_password = 1` until the user rotates (see
  [`SecurityGuide.md`](../SecurityGuide.md) §7).
- All seed statements are idempotent (`IF NOT EXISTS` / `MERGE`-style guards).

## Sample Data

- 15 products (some flagged `is_service`), exercises inventory movements.
- 3 sales created by calling `SP_CreateSale`; 1 return via `SP_ProcessReturn`.
- Safe to re-run — duplicates are guarded.

## Build Order

See [`DeploymentGuide.md`](../DeploymentGuide.md) §3:

```
Schema (01→16) → Shared functions (17) → Views (18, 13, 14) → SPs →
Triggers (19) → SeedData → SampleData → App role/grants → run_tests.sh
```

## Verification

Run `bash Database/Testing/run_tests.sh` after setup; the suite
(`00_schema_integrity.sql` … `12_smoke_full.sql`) validates the install
end-to-end.
