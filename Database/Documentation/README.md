# SmartPOS Database — Documentation Index

**Scope:** Complete reference documentation for the SmartPOS Microsoft SQL
Server database. Every object documented here exists in the real schema under
[`Database/SQL/`](../SQL/) and is verified by the
[`Database/Testing/`](../Testing/) test suites.

**Source of truth:** [`../AI/SMARTPOS_PROJECT_BIBLE.md`](../../AI/SMARTPOS_PROJECT_BIBLE.md)
**Conventions:** [`NamingStandards.md`](NamingStandards.md)
**Phase 01 overview:** [`Documentation/13_Database_Overview`](../../Documentation/13_Database_Overview/README.md)

---

## 1. Document Map

| Document | What it covers | Primary readers |
|----------|----------------|-----------------|
| [`NamingStandards.md`](NamingStandards.md) | Object, column, index and constraint naming; audit fields; soft-delete and transaction conventions | Everyone writing SQL |
| [`DatabaseDesign.md`](DatabaseDesign.md) | Design goals, 3NF strategy, schema overview (41 tables in 14 modules), table purposes, key relationships, ERD reference | Architects, DBAs, new team members |
| [`RelationshipDocumentation.md`](RelationshipDocumentation.md) | Every foreign-key relationship: child → parent, columns, cardinality, delete behavior, purpose | DBAs, developers joining tables |
| [`PerformanceGuide.md`](PerformanceGuide.md) | Indexing strategy, FK index coverage, missing-index discovery, report query tuning, maintenance, SNAPSHOT isolation | DBAs, performance engineers |
| [`SecurityGuide.md`](SecurityGuide.md) | Least-privilege roles, password hashing, audit triggers, connection-string and SQL-injection defense, `sa` hardening, backup encryption | DBAs, security team, backend developers |
| [`BackupGuide.md`](BackupGuide.md) | Full / differential / log backup strategies, schedule and retention, backup scripts, `RESTORE VERIFYONLY`, test restores | DBAs, ops |
| [`RestoreGuide.md`](RestoreGuide.md) | Restore procedures, point-in-time recovery, restore scripts, cross-server restores | DBAs, ops, incident responders |
| [`MaintenanceGuide.md`](MaintenanceGuide.md) | Index rebuild/reorganize, statistics, `DBCC CHECKDB`, `SP_ArchiveAuditLogs`, low-stock alert cleanup, log growth, fragmentation thresholds | DBAs, ops |
| [`DeploymentGuide.md`](DeploymentGuide.md) | Prerequisites, install/build order (schema → seed → sample), verification, migrations, rollback | DBAs, DevOps, deployment engineers |
| [`ConfigurationGuide.md`](ConfigurationGuide.md) | The `Configuration/` folder (`.env`, `.env.example`, `connection.example.sql`), env-var flow into scripts, SQL vs Windows auth | Everyone installing the database |
| [`Module_Guides/`](Module_Guides/) | 20 per-module guides: purpose, objects, stored procedures, dependencies, notes | Developers working module-by-module |

---

## 2. How Documentation Maps to the SQL Modules

The database is built as integrated modules under
[`Database/SQL/`](../SQL/). The table below maps each SQL folder to its
documentation. Module guides live in [`Module_Guides/`](Module_Guides/).

| # | Module | SQL folder / file | Module guide | Documentation reference |
|---|--------|-------------------|--------------|--------------------------|
| 01 | Authentication | `01_Authentication/` (`SP_Login.sql`, `SP_Roles.sql`) | [`Module_01_Authentication.md`](Module_Guides/Module_01_Authentication.md) | DatabaseDesign §4.1, SecurityGuide §3 |
| 02 | Users | `02_Users/` (`SP_Users.sql`) | [`Module_02_Users.md`](Module_Guides/Module_02_Users.md) | DatabaseDesign §4.2, SecurityGuide §4 |
| 03 | Business | `03_Business/` (`SP_Business.sql`) | [`Module_03_Business.md`](Module_Guides/Module_03_Business.md) | DatabaseDesign §4.3 |
| 04 | Categories | `04_Categories/` (`SP_Categories.sql`) | [`Module_04_Categories.md`](Module_Guides/Module_04_Categories.md) | DatabaseDesign §4.4 |
| 05 | Products | `05_Products/` (`SP_Products.sql`) | [`Module_05_Products.md`](Module_Guides/Module_05_Products.md) | DatabaseDesign §4.5 |
| 06 | Suppliers | `06_Suppliers/` (`SP_Suppliers.sql`) | [`Module_06_Suppliers.md`](Module_Guides/Module_06_Suppliers.md) | DatabaseDesign §4.6 |
| 07 | Inventory | `07_Inventory/` (`SP_Inventory.sql`) | [`Module_07_Inventory.md`](Module_Guides/Module_07_Inventory.md) | DatabaseDesign §4.7 |
| 08 | Sales | `08_Sales/` (`SP_CreateSale.sql`) | [`Module_08_Sales.md`](Module_Guides/Module_08_Sales.md) | DatabaseDesign §4.8 |
| 09 | Payments | `09_Payments/` (`SP_Payments.sql`) | [`Module_09_Payments.md`](Module_Guides/Module_09_Payments.md) | DatabaseDesign §4.9 |
| 10 | Credit Sales | `10_CreditSales/` (`tables.sql`) | [`Module_10_CreditSales.md`](Module_Guides/Module_10_CreditSales.md) | DatabaseDesign §4.10 |
| 11 | Returns | `11_Returns/` (`SP_ProcessReturn.sql`) | [`Module_11_Returns.md`](Module_Guides/Module_11_Returns.md) | DatabaseDesign §4.11 |
| 12 | Notifications | `12_Notifications/` (`SP_Notifications.sql`) | [`Module_12_Notifications.md`](Module_Guides/Module_12_Notifications.md) | DatabaseDesign §4.12 |
| 13 | Reports | `13_Reports/` (`VW_Report_Views.sql`, `SP_Reports.sql`) | [`Module_13_Reports.md`](Module_Guides/Module_13_Reports.md) | DatabaseDesign §4.13, PerformanceGuide §4 |
| 14 | Dashboard | `14_Dashboard/` (`VW_Dashboard_Views.sql`, `SP_Dashboard.sql`) | [`Module_14_Dashboard.md`](Module_Guides/Module_14_Dashboard.md) | DatabaseDesign §4.14, PerformanceGuide §4 |
| 15 | Settings | `15_Settings/` (`SP_Settings.sql`) | [`Module_15_Settings.md`](Module_Guides/Module_15_Settings.md) | DatabaseDesign §4.15 |
| 16 | Audit | `16_Audit/` (`SP_Audit.sql`) | [`Module_16_Audit.md`](Module_Guides/Module_16_Audit.md) | DatabaseDesign §4.16, SecurityGuide §5, MaintenanceGuide §4 |
| 17 | Shared | `17_Shared/` (`functions.sql`) | [`Module_17_Shared.md`](Module_Guides/Module_17_Shared.md) | DatabaseDesign §5.1 |
| 18 | Operational Views | `Views/` (`Core_Operational_Views.sql`) | [`Module_18_Views.md`](Module_Guides/Module_18_Views.md) | DatabaseDesign §5.2 |
| 19 | Triggers | `Triggers/` (`All_Triggers.sql`) | [`Module_19_Triggers.md`](Module_Guides/Module_19_Triggers.md) | DatabaseDesign §5.3, SecurityGuide §5 |
| 20 | Setup | `Scripts/`, `SeedData/`, `SampleData/`, `Configuration/` | [`Module_20_Setup.md`](Module_Guides/Module_20_Setup.md) | DeploymentGuide, ConfigurationGuide, BackupGuide, RestoreGuide |

---

## 3. How to Navigate

1. **New to the database?** Read `DatabaseDesign.md`, then browse the module
   guides in `Module_Guides/`.
2. **Building or deploying?** Read `DeploymentGuide.md` and
   `ConfigurationGuide.md` first, then `Database/SQL/README.md`.
3. **Tuning or investigating performance?** Start with `PerformanceGuide.md`.
4. **Planning operations?** Read `BackupGuide.md`, `RestoreGuide.md` and
   `MaintenanceGuide.md`.
5. **Reviewing security?** Read `SecurityGuide.md`.
6. **Need the exact FK wiring for a join?** Use `RelationshipDocumentation.md`.

The official diagram assets (ERD/Mermaid/PlantUML, diagrams) are collected in
the `Documentation/ERD/` and `Documentation/Diagrams/` folders; see
[`DatabaseDesign.md`](DatabaseDesign.md) §7.

---

## 4. Quick Reference

| Item | Value |
|------|-------|
| Database name | `SmartPOS` |
| Schema | `dbo` |
| Default collation | `SQL_Latin1_General_CP1_CI_AS` |
| Minimum SQL Server | 2016 (uses `OPENJSON`, `FOR JSON`, `STRING_SPLIT`, `DROP IF` patterns) |
| Tables | 41 across 14 modules |
| Views | 22 (5 operational + 8 dashboard + 9 report) + `VW_LowStock` |
| Stored procedures | 60+ |
| Scalar functions | 7 |
| Triggers | 7 |
| Timestamps | `DATETIME2(0)` stored as UTC (`SYSUTCDATETIME()`) |
| Money columns | `DECIMAL(19,4)` |

---

## 5. Related Documents

- [`Database/README.md`](../README.md) — directory overview and module inventory
- [`Database/SQL/README.md`](../SQL/README.md) — build order and object inventory
- [`Database/Testing/`](../Testing/) — verification suites and `run_tests.sh`
- [`Documentation/13_Database_Overview/README.md`](../../Documentation/13_Database_Overview/README.md) — Phase 01 high-level overview
- [`SMARTPOS_PROJECT_BIBLE.md`](../../AI/SMARTPOS_PROJECT_BIBLE.md) — master specification

---

## 6. Revision History

| Version | Date | Description |
|---------|------|-------------|
| 1.0 | 2026-08-07 | Initial database documentation index |
