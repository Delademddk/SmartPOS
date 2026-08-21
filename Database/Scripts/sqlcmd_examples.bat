@echo off
rem ============================================================================
rem  SmartPOS Database - sqlcmd Examples (reference file, executes nothing)
rem ----------------------------------------------------------------------------
rem  This file is documentation only. Every line below is a comment; running
rem  this batch file does nothing except print a pointer.
rem
rem  All examples read credentials from the same environment file used by the
rem  operational scripts. See Database\Configuration\database.env.example.
rem ============================================================================

echo This file contains only examples and performs no actions. Open it with
echo a text editor to review the sqlcmd usage patterns below.
exit /b 0

rem ----------------------------------------------------------------------------
rem 1. Load the environment (works from any batch script)
rem ----------------------------------------------------------------------------
rem     for /f "usebackq eol=# delims=" %%A in ("Configuration\.env") do set "%%A"
rem
rem     set "SERVER=%DB_HOST%,%DB_PORT%"
rem     if not "%DB_INSTANCE%"=="" set "SERVER=%DB_HOST%\%DB_INSTANCE%"
rem     set "AUTH_ARGS=-U "%DB_USERNAME%" -P "%DB_PASSWORD%""

rem ----------------------------------------------------------------------------
rem 2. Basic connectivity check (SELECT 1)
rem ----------------------------------------------------------------------------
rem     sqlcmd -S "%SERVER%" -U "%DB_USERNAME%" -P "%DB_PASSWORD%" -d master -Q "SELECT 1 AS ok;"
rem
rem     Trusted connection variant:
rem     sqlcmd -S "%SERVER%" -E -d master -Q "SELECT 1 AS ok;"

rem ----------------------------------------------------------------------------
rem 3. List databases
rem ----------------------------------------------------------------------------
rem     sqlcmd -S "%SERVER%" -U "%DB_USERNAME%" -P "%DB_PASSWORD%" -d master -Q "SELECT name FROM sys.databases ORDER BY name;"

rem ----------------------------------------------------------------------------
rem 4. Run a SQL file, stop on the first error (-b), enable QUOTED_IDENTIFIER (-I)
rem ----------------------------------------------------------------------------
rem     sqlcmd -S "%SERVER%" -U "%DB_USERNAME%" -P "%DB_PASSWORD%" -d SmartPOS -b -I -i "Database\SQL\17_Shared\functions.sql"

rem ----------------------------------------------------------------------------
rem 5. Run every SQL module in build order (loop)
rem ----------------------------------------------------------------------------
rem     for %%F in (17_Shared\functions.sql 01_Authentication\tables.sql 02_Users\tables.sql) do sqlcmd -S "%SERVER%" -U "%DB_USERNAME%" -P "%DB_PASSWORD%" -d SmartPOS -b -I -i "Database\SQL\%%F"
rem
rem     (The production setup loops over the full ordered list - see setup_database.bat.)

rem ----------------------------------------------------------------------------
rem 6. Create the database if it does not exist
rem ----------------------------------------------------------------------------
rem     sqlcmd -S "%SERVER%" -U "%DB_USERNAME%" -P "%DB_PASSWORD%" -d master -b -I -Q "IF DB_ID(N'SmartPOS') IS NULL CREATE DATABASE [SmartPOS] COLLATE SQL_Latin1_General_CP1_CI_AS;"

rem ----------------------------------------------------------------------------
rem 7. Full backup with compression (timestamped name)
rem ----------------------------------------------------------------------------
rem     sqlcmd -S "%SERVER%" -U "%DB_USERNAME%" -P "%DB_PASSWORD%" -d master -b -I -Q "BACKUP DATABASE [SmartPOS] TO DISK = N'Database\Backup\SmartPOS_20260807_143000.bak' WITH INIT, COMPRESSION, STATS = 10;"

rem ----------------------------------------------------------------------------
rem 8. Verify a backup file without restoring it
rem ----------------------------------------------------------------------------
rem     sqlcmd -S "%SERVER%" -U "%DB_USERNAME%" -P "%DB_PASSWORD%" -d master -b -Q "RESTORE VERIFYONLY FROM DISK = N'Database\Backup\SmartPOS_20260807_143000.bak';"

rem ----------------------------------------------------------------------------
rem 9. Restore a full backup (REPLACE required when the database already exists)
rem ----------------------------------------------------------------------------
rem     sqlcmd -S "%SERVER%" -U "%DB_USERNAME%" -P "%DB_PASSWORD%" -d master -b -Q "RESTORE DATABASE [SmartPOS] FROM DISK = N'Database\Backup\SmartPOS_20260807_143000.bak' WITH REPLACE, RECOVERY;"

rem ----------------------------------------------------------------------------
rem 10. Drop the database (dangerous)
rem ----------------------------------------------------------------------------
rem     sqlcmd -S "%SERVER%" -U "%DB_USERNAME%" -P "%DB_PASSWORD%" -d master -b -Q "ALTER DATABASE [SmartPOS] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE [SmartPOS];"

rem ----------------------------------------------------------------------------
rem 11. Export query output to a file
rem ----------------------------------------------------------------------------
rem     sqlcmd -S "%SERVER%" -U "%DB_USERNAME%" -P "%DB_PASSWORD%" -d SmartPOS -Q "SELECT * FROM dbo.products;" -o "C:\temp\products.txt"

rem ----------------------------------------------------------------------------
rem 12. Useful switches
rem     -S server        : target server ("host,port" or "host\instance")
rem     -U / -P          : SQL login credentials (omit both and use -E for trusted auth)
rem     -E               : use Windows / Active Directory authentication
rem     -d database      : default database context
rem     -i file.sql      : run a script file
rem     -Q "query"       : run a query and exit
rem     -b               : quit with error level 1 if a SQL error occurs
rem     -I               : enable SET QUOTED_IDENTIFIER ON (required for most DDL)
rem     -l seconds       : login timeout
rem     -t seconds       : query timeout
rem     -h -1            : suppress column headers
rem     -W               : remove trailing spaces
rem     -o file          : redirect output to a file
rem     -v var=value     : define a scripting variable (use $(var) in the script)
rem ----------------------------------------------------------------------------
