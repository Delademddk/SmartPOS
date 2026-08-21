# SmartPOS SQL Build Scripts

This folder contains all SQL Server scripts for the SmartPOS database,
organized by object type. All scripts are production-ready and functional.

## Build Order

Because of foreign-key dependencies, run the scripts in this order. Each step
is idempotent (safe to re-run) and drops/recreates its own objects.

1. **Resources**
   - [`Functions/00_resource_lookup.sql`](Functions/00_resource_lookup.sql)
     - `AppResourceType`, `AppPermissionCode`, `AppRoleCode` type-helper scalars
   - **Build order note:** Tables are created via the master build file below.

2. **Tables** — see [`SQL/Tables/README.md`](Tables/README.md) for the module index
   (auth → users → business → categories → suppliers → products → inventory →
   sales → payments → credit → returns → notifications → audit → settings).

3. **Constraints & Indexes** — applied per table via separate files so they can
   be tuned independently.

4. **Functions** — common scalar/TVF helpers (module 17).

5. **Views** — reporting and operational views.

6. **Stored Procedures** — business logic and CRUD procedures.

7. **Triggers** — audit, stock, low-stock, notification triggers.

8. **Seed data** — required runtime records (roles, permissions, payment
   methods, default settings, admin user).

9. **Sample data** — illustrative, non-required records.

## Master Build Scripts

For convenience, combined build scripts exist at the repository root under
[`Scripts/`](../Scripts/README.md). They call the files in this folder in the
correct order:

- `Scripts/setup_database.bat` / `setup_database.ps1` → runs the full build.
- `Scripts/verify_database.bat` / `verify_database.ps1` → runs `Testing/`.

When you want the **full schema in dependency order**, use the
[`Scripts/build_database.sql`](../Scripts/build_database.sql) driver that
`:r`-includes every part in the correct order.

## Conventions (must be respected everywhere)

- Tables: plural snake_case (e.g., `products`, `stock_movements`).
- Primary keys: `<singular>_id`.
- Foreign keys: `<singular>_id` of the referenced table.
- Indexes: `IX_<table>_<columns>`.
- Unique: `UQ_<table>_<columns>`.
- Check: `CK_<table>_<condition>`.
- Default: `DF_<table>_<column>`.
- Trigger: `TRG_<table>_<event>`.
- Stored procedure: `SP_<purpose>`.
- View: `VW_<purpose>`.
- Function: `FN_<purpose>`.
- All configurable values (hosts, names, credentials) come from environment
  variables; SQL never embeds real credentials.

See [`Documentation/NamingStandards.md`](../Documentation/NamingStandards.md).

## Files

- `Tables/README.md` — table inventory grouped by module.
- `000_schema_tables.sql` → module part files under `Tables/`.
- `README.md` — this file.

---

## Revision History

| Version | Date | Description |
|---------|------|-------------|
| 1.0 | 2026-08-07 | Initial SQL build for the SmartPOS database |