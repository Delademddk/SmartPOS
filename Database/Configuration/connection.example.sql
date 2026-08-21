-- ============================================================================
-- SmartPOS Database - Connection Example
--
-- Shows how to connect to the SmartPOS database using sqlcmd and SQL Server
-- Management Studio. REPLACE the placeholder values before running.
-- This file contains NO real credentials.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Connecting with SQL Server Authentication (recommended for setup scripts)
-- ----------------------------------------------------------------------------

--    sqlcmd -S localhost -U sa -P "ChangeMe_StrongPassword_2026" -d SmartPOS

-- ----------------------------------------------------------------------------
-- 2. Connecting with Windows Authentication (Trusted Connection)
-- ----------------------------------------------------------------------------

--    sqlcmd -S .\MSSQLSERVER -E -d SmartPOS

-- ----------------------------------------------------------------------------
-- 3. From inside a batch file (no echo of the password)
-- ----------------------------------------------------------------------------

--    @echo off
--    set "DB_HOST=localhost"
--    set "DB_PASSWORD=ChangeMe_StrongPassword_2026"
--    sqlcmd -S %DB_HOST% -U sa -P "%DB_PASSWORD%" -d SmartPOS -Q "SELECT 1;"

-- ----------------------------------------------------------------------------
-- 4. Quick sanity check that the database exists
-- ----------------------------------------------------------------------------

SELECT DB_NAME() AS CurrentDatabase;
SELECT name, database_id, state_desc
FROM sys.databases
WHERE name = 'SmartPOS';

-- ----------------------------------------------------------------------------
-- 5. Checking the active schema version (set by migrations)
-- ----------------------------------------------------------------------------

IF OBJECT_ID(N'dbo.SchemaVersion', N'U') IS NOT NULL
BEGIN
    SELECT TOP (1) Version, AppliedOn
    FROM dbo.SchemaVersion
    ORDER BY SchemaVersionId DESC;
END

-- ----------------------------------------------------------------------------
-- NOTE: All values above are PLACEHOLDERS.
-- Never commit real credentials.
-- ----------------------------------------------------------------------------