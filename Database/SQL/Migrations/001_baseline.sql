/* ==========================================================================
   SmartPOS Database - MIGRATION 001: BASELINE
   --------------------------------------------------------------------------
   Baseline migration marker. The complete schema is applied by the setup
   scripts from the module folders in FK dependency order (see
   `Scripts/setup_database.bat` and `SQL/README.md`).

   This migration exists so that:
     1. Schema versioning can be tracked going forward.
     2. Environments that apply `Migrations/` in sequence have a known v001.
     3. Future migrations (002, 003, ...) build on top of this baseline.

   Migration approach (follow for future migrations):
     - Each migration is a numbered .sql file.
     - Migrations are idempotent where practical (IF OBJECT_ID guards).
     - New objects follow the NamingStandards.md conventions.
     - Destructive changes are never silent: add a comment and require a
       manual approval step before DROP operations on production data.
   ========================================================================== */

-- ---------------------------------------------------------------------------
-- Track schema version
-- ---------------------------------------------------------------------------
IF OBJECT_ID(N'dbo.SchemaVersion', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.SchemaVersion
    (
        SchemaVersionId INT            NOT NULL IDENTITY(1,1) CONSTRAINT PK_SchemaVersion PRIMARY KEY,
        Version         NVARCHAR(20)   NOT NULL CONSTRAINT UQ_SchemaVersion_Version UNIQUE,
        AppliedOn       DATETIME2(0)   NOT NULL CONSTRAINT DF_SchemaVersion_AppliedOn DEFAULT (SYSUTCDATETIME()),
        Description     NVARCHAR(500)  NULL,
        AppliedBy       NVARCHAR(100)  NULL
    );
END
GO

IF NOT EXISTS (SELECT 1 FROM dbo.SchemaVersion WHERE Version = N'001')
    INSERT INTO dbo.SchemaVersion (Version, Description, AppliedBy)
    VALUES (N'001', N'Baseline: full SmartPOS schema (modules 01-17), views, triggers, seed data.', SUSER_SNAME());
GO