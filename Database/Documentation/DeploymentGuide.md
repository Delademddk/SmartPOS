# SmartPOS Database — Deployment Guide

**Document ID:** DOC-DB-DEPLOY
**Version:** 1.0
**Status:** Approved
**Date:** August 7, 2026

End-to-end procedure for installing the **SmartPOS** database on a fresh SQL
Server instance, plus migration and rollback guidance. Every artifact is
idempotent and verified by the test suite in `Database/Testing/`.

---

## 1. Prerequisites

| Requirement | Value |
|-------------|-------|
| SQL Server | 2016 or newer (uses `OPENJSON`, `FOR JSON`, `STRING_SPLIT`) |
| Collation | `SQL_Latin1_General_CP1_CI_AS` (configurable via `DB_DEFAULT_COLLATION`) |
| Tools | `sqlcmd` on PATH (used by scripts and tests) |
| Permissions | A login with `CREATE DATABASE` + `db_owner` on the target for install |
| Client network | Firewall rule for 1433 (or configured port) between POS clients and server |

Confirm `sqlcmd` availability:

```bash
sqlcmd -?
```

---

## 2. Before You Start

1. Copy `Database/Configuration/database.env.example` to
   `Database/Configuration/.env` and set the real values
   (host, port, credentials, database name, paths). See
   [`ConfigurationGuide.md`](ConfigurationGuide.md).
2. Generate a **strong password** for the application login (not the `sa`
   placeholder from the example file).
3. Ensure the seed placeholder password hashes will be replaced at install
   (see [`SecurityGuide.md`](SecurityGuide.md) §7).

---

## 3. Build Order

The database builds in dependency order. The canonical sequence is:

```
1.  Create database + enable FULL recovery + snapshot isolation (if desired)
2.  Schema — tables for each module, in FK order:
    01 Authentication → 02 Users → 03 Business → 04 Categories → 06 Suppliers
    → 05 Products → 07 Inventory → 08 Sales → 09 Payments → 10 Credit Sales
    → 11 Returns → 12 Notifications → 15 Settings → 16 Audit
3.  Shared functions (Module 17)
4.  Views (Module 18 core views; then 13 Reports, 14 Dashboard)
5.  Stored procedures (SP_* per module)
6.  Triggers (Module 19)
7.  Seed data  — Database/SQL/SeedData/SeedData.sql
8.  Sample data — Database/SQL/SampleData/SampleData.sql
9.  Application login + least-privilege role + grants
10. Verification — Database/Testing/run_tests.sh
```

> The exact file list and per-module folder names are in
> [`Database/SQL/README.md`](../SQL/README.md).

### 3.1 Step 1 — Create the database

```sql
IF DB_ID(N'SmartPOS') IS NULL
    CREATE DATABASE SmartPOS
    COLLATE SQL_Latin1_General_CP1_CI_AS;
GO
USE SmartPOS;
GO
ALTER DATABASE SmartPOS SET RECOVERY FULL;
ALTER DATABASE SmartPOS SET ALLOW_SNAPSHOT_ISOLATION ON;
ALTER DATABASE SmartPOS SET READ_COMMITTED_SNAPSHOT ON;
GO
```

### 3.2 Steps 2–8 — Run the SQL files

Execute every `.sql` file under `Database/SQL/` in the order in §3. All DDL
uses `IF OBJECT_ID(...) IS NULL` / `DROP IF EXISTS` guards, so the scripts are
**safe to re-run** and the build is idempotent.

Recommended driver:

```bash
for f in \
  01_Authentication/tables.sql \
  ... \
  SeedData/SeedData.sql \
  SampleData/SampleData.sql; do
  sqlcmd -S "$DB_HOST,$DB_PORT" -U "$DB_USERNAME" -P "$DB_PASSWORD" \
         -d SmartPOS -i "$f" -b -e
done
```

Equivalent `setup_database.bat` / `setup_database.ps1` drivers are provided
in `Database/Scripts/`; both read `Database/Configuration/.env`.

> Note: at the time of writing `Database/Scripts/` is an empty scaffold
> folder; create/import the setup drivers there or use the loop above.

### 3.3 Step 9 — Application login & grants

Follow [`SecurityGuide.md`](SecurityGuide.md) §3 exactly:

```sql
CREATE LOGIN pos_app WITH PASSWORD = N'<generated-strong-password>',
    CHECK_POLICY = ON, CHECK_EXPIRATION = ON;
USE SmartPOS;
CREATE USER pos_app FOR LOGIN pos_app;
CREATE ROLE pos_app_role;
ALTER ROLE pos_app_role ADD MEMBER pos_app;
GRANT EXECUTE ON SCHEMA::dbo TO pos_app_role;
GRANT SELECT  ON SCHEMA::dbo TO pos_app_role;   -- views only
```

### 3.4 Replace seed password hashes

Immediately after seed, set real hashes for the seed accounts
(`must_change_password = 1` keeps them locked until rotated):

```sql
EXEC dbo.SP_ChangePassword @UserId = 1, @CurrentPassword = '<seed-hash>', @NewPasswordHash = N'<real-hash>';
```

---

## 4. Verification

Run the full test suite (reads `Database/Configuration/.env`):

```bash
bash Database/Testing/run_tests.sh
```

The suite (`00_schema_integrity.sql` … `12_smoke_full.sql`) verifies:

- Every table/view/SP/function/trigger in the documentation exists.
- FK wiring and `NO ACTION` behavior (relationship integrity).
- Unique constraints (`sku`, `barcode`, `receipt_number`, `email`, ...).
- RBAC wiring (users → roles → permissions).
- Smoke test: a full sale → payment → return cycle works end-to-end.

Additionally run:

```sql
SELECT COUNT(*) AS users FROM dbo.users;
SELECT COUNT(*) AS products FROM dbo.products;
SELECT COUNT(*) AS sales FROM dbo.sales;
SELECT COUNT(*) AS sales_summary_rows FROM dbo.VW_SalesSummary;
```

Expected: seeded counts from `SampleData.sql` (15 products, 3 sales,
1 return) and a populated `VW_SalesSummary`.

---

## 5. Migrations & Versioning

### 5.1 Migration storage

Incremental changes ship as numbered migration scripts in
`Database/SQL/Migrations/` (e.g. `20260807_001_<description>.sql`). Keep each
migration **additive and re-runnable**:

```sql
IF NOT EXISTS (SELECT 1 FROM sys.columns
               WHERE object_id = OBJECT_ID(N'dbo.sales')
                 AND name = N'new_column')
    ALTER TABLE dbo.sales ADD new_column INT NULL;
```

### 5.2 Applying a migration

1. Back up the database (see [`BackupGuide.md`](BackupGuide.md)).
2. Apply the migration with `sqlcmd -b` so any error stops the run.
3. Re-run the affected tests.
4. Update the documentation that references the changed objects.

### 5.3 Schema version tracking

Track the applied schema version in `dbo.settings`:

```sql
EXEC dbo.SP_UpsertSetting @SettingKey = N'schema_version',
                          @SettingValue = N'1.2.3',
                          @DataType = N'string';
```

The deployment tooling and `run_tests.sh` can assert the expected version
before proceeding.

---

## 6. Rollback

- **DDL rollback:** schema changes are guarded by existence checks, so
  re-running the previous full build restores the last known-good state.
  For a failed migration, restore the pre-migration backup
  (see [`RestoreGuide.md`](RestoreGuide.md)).
- **Data rollback:** never `DELETE` transactions; to undo an erroneous
  change, restore to a `STOPAT` point (RestoreGuide §3.3) or correct forward
  (e.g. a `SP_AdjustStock` reversal) rather than physically removing rows.
- **Code rollback:** roll back the application to the previous release whose
  procedures match the current schema version.

The golden rule: **schema changes are forward-only and additive; data
recovery is done by restore, not by destructive SQL.**

---

## 7. Deployment Checklist

- [ ] `.env` created from `database.env.example` with real values.
- [ ] SQL files executed in FK build order without errors (`sqlcmd -b`).
- [ ] Seed + sample data applied (idempotent re-run verified).
- [ ] `pos_app` login + `pos_app_role` created; **no** table grants.
- [ ] Seed password hashes replaced.
- [ ] `run_tests.sh` passes end-to-end.
- [ ] First full backup taken; `RESTORE VERIFYONLY` OK.
- [ ] Client connection strings point at the new server (ConfigurationGuide).
- [ ] Instance hardened per SecurityGuide §6.

---

## 8. Revision History

| Version | Date | Description |
|---------|------|-------------|
| 1.0 | 2026-08-07 | Initial deployment guide |
