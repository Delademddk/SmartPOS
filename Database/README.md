# SmartPOS Database Directory

Enterprise Microsoft SQL Server database for the SmartPOS Point of Sale and
Inventory Management System.

> **Source of truth:** [`../AI/SMARTPOS_PROJECT_BIBLE.md`](../AI/SMARTPOS_PROJECT_BIBLE.md).
> **Design documentation:** [`../Documentation/`](../Documentation/) (Phase 01).

---

## Overview

The database is fully normalized (3NF+), production-ready, and implemented on
Microsoft SQL Server. Every schema object is real, complete, and functional:

- Tables, views, stored procedures, functions, triggers, indexes, constraints.
- Seed data (required runtime records) and sample data (illustrative records).
- Migration, installation, backup, restore, and verification scripts.
- A data dictionary and full reference documentation.

## Directory Layout

```
Database/
├── README.md                  <- This file
├── Configuration/             <- .env placeholders, connection examples, install guide
├── Dictionary/                <- Data dictionary (CSV / Markdown)
├── Documentation/             <- Full reference documentation
│   ├── DataDictionary/
│   ├── Diagrams/
│   └── ERD/
├── ERD/
│   ├── Mermaid/
│   └── PlantUML/
├── SQL/
│   ├── Tables/
│   ├── Constraints/
│   ├── Indexes/
│   ├── Views/
│   ├── StoredProcedures/
│   ├── Functions/
│   ├── Triggers/
│   ├── SeedData/
│   ├── SampleData/
│   └── Migrations/
├── Testing/                   <- Integrity, constraint, procedure, trigger, validation
├── Scripts/                   <- setup / verify / backup / restore / reset scripts
└── Backup/                    <- Backup notes and automated backup config
```

## Module Inventory

The database is built as the following independent, integrated modules:

| # | Module | Core Objects |
|---|--------|--------------|
| 01 | Authentication | `Roles`, `Permissions`, `RolePermissions`, login/logout procedures |
| 02 | Users | `Users`, `UserSessions`, `PasswordHistory`, `PasswordResets` |
| 03 | Business | `BusinessInformation`, company/app settings, Locale, Currency, Tax |
| 04 | Categories | `Categories` (self-referencing hierarchy) |
| 05 | Products | `Products`, `ProductImages` |
| 06 | Suppliers | `Suppliers`, `SupplierContacts`, `SupplierHistory` |
| 07 | Inventory | `Inventory`, `InventoryTransactions`, `StockAdjustments`, `LowStockAlerts` |
| 08 | Sales | `Sales`, `SaleItems`, discount/tax support |
| 09 | Payments | `PaymentMethods`, `Payments`, `Receipts` |
| 10 | Credit Sales | `CreditSales`, `CreditPayments`, balances |
| 11 | Returns | `Returns`, `ReturnItems`, `ReturnReasons` |
| 12 | Notifications | `NotificationTypes`, `Notifications`, `NotificationHistory` |
| 13 | Reports | Reporting views and stored procedures |
| 14 | Dashboard | Dashboard views, procedures, KPI queries |
| 15 | Settings | Application/User/System/Business configuration |
| 16 | Audit | `AuditLogs`, `ActivityLogs`, `ErrorLogs`, `SecurityLogs` |
| 17 | Shared | Common functions, views, procedures, utilities |

## Getting Started

1. Copy `Configuration/database.env.example` to `Configuration/.env` (or the
   referenced `.env`) and replace placeholder values.
2. Review `Configuration/connection.example.sql` and `Configuration/install_guide.md`.
3. Review and run the master build scripts in
   [`Database/SQL/`](SQL/README.md)
   (resources, schema, then objects) — or use the automation in `Scripts/`.
4. Seed the database (`SQL/SeedData/`), then optionally load sample data
   (`SQL/SampleData/`).
5. Verify the install with `Scripts/verify_database.bat` /
   `verify_database.ps1`.

> The SQL scripts do **not** hardcode server/credentials. All connection values
> come from environment variables or the `Configuration` files.

## Support

- See [`SQL/README.md`](SQL/README.md) for build order and object inventory.
- See [`Documentation/`](Documentation/) for the full reference documentation.
- See [`Scripts/README.md`](Scripts/README.md) for operational automation.

---

## Revision History

| Version | Date | Description |
|---------|------|-------------|
| 1.0 | 2026-08-07 | Initial database module for the SmartPOS project |