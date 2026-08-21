@echo off
setlocal EnableExtensions
rem ============================================================================
rem  SmartPOS Database - Full Setup (Windows batch)
rem ----------------------------------------------------------------------------
rem  Creates the database if it does not exist, applies every SQL module in FK
rem  dependency order via sqlcmd -b (stop on first error), seeds runtime data,
rem  then runs a final object-count verification.
rem
rem  Connection settings come EXCLUSIVELY from Configuration\.env (or
rem  Configuration\database.env as a fallback). Never edit credentials here.
rem
rem  Usage:
rem      setup_database.bat
rem
rem  Optional behaviour (set the variable before running, e.g.):
rem      set RUN_SAMPLE_DATA=0 && setup_database.bat    (skip SampleData)
rem
rem  Exit codes: 0 = success, 1 = any failure (build aborted on first error).
rem ============================================================================

rem ---- resolve paths relative to this script (repo path contains spaces) ----
set "SCRIPT_DIR=%~dp0"
for %%I in ("%~dp0..") do set "SRC=%%~fI"

set "SQL_DIR=%SRC%\SQL"
set "CONF_DIR=%SRC%\Configuration"
set "TEST_DIR=%SRC%\Testing"

rem ---- locate the environment file (.env is the live one; database.env is a fallback) ----
set "ENV_FILE=%CONF_DIR%\.env"
if not exist "%ENV_FILE%" set "ENV_FILE=%CONF_DIR%\database.env"
if not exist "%ENV_FILE%" (
    echo [ERROR] Environment file not found.
    echo         Expected Configuration\.env or Configuration\database.env
    echo         Copy Configuration\database.env.example to Configuration\.env
    echo         and fill in real values before running.
    exit /b 1
)

echo [..] Loading environment from "%ENV_FILE%"
for /f "usebackq eol=# delims=#" %%A in ("%ENV_FILE%") do call :ParseEnvLine "%%A"

rem ---- apply sane defaults -----------------------------------------------
if "%SQLCMD_BINARY%"=="" set "SQLCMD_BINARY=sqlcmd"
if "%SQLCMD_TIMEOUT%"=="" set "SQLCMD_TIMEOUT=60"
if "%DB_PORT%"=="" set "DB_PORT=1433"
if "%DB_DEFAULT_COLLATION%"=="" set "DB_DEFAULT_COLLATION=SQL_Latin1_General_CP1_CI_AS"
if "%RUN_SAMPLE_DATA%"=="" set "RUN_SAMPLE_DATA=1"

rem ---- build server string (named instance vs host,port) ------------------
set "SERVER=%DB_HOST%,%DB_PORT%"
if not "%DB_INSTANCE%"=="" set "SERVER=%DB_HOST%\%DB_INSTANCE%"

rem ---- auth args: trusted (-E) or SQL login (-U/-P) ------------------------
set "AUTH_ARGS=-E"
if /i not "%DB_TRUSTED_CONNECTION%"=="true" call :SetSqlAuthArgs

rem ---- validate required values -------------------------------------------
if "%DB_HOST%"=="" ( echo [ERROR] DB_HOST is not set in the environment file. & exit /b 1 )
if "%DB_NAME%"==""  ( echo [ERROR] DB_NAME is not set in the environment file.  & exit /b 1 )
if /i not "%DB_TRUSTED_CONNECTION%"=="true" (
    if "%DB_USERNAME%"=="" ( echo [ERROR] DB_USERNAME is not set in the environment file. & exit /b 1 )
    if "%DB_PASSWORD%"=="" ( echo [ERROR] DB_PASSWORD is not set in the environment file. & exit /b 1 )
)

where "%SQLCMD_BINARY%" >nul 2>nul
if errorlevel 1 (
    if not exist "%SQLCMD_BINARY%" (
        echo [ERROR] sqlcmd ("%SQLCMD_BINARY%") was not found on PATH.
        echo         Install "SQL Server Command Line Utilities" and re-run.
        exit /b 1
    )
)

echo.
echo ============================================================================
echo  SmartPOS Database Setup
echo  Target : %SERVER% / %DB_NAME%
echo  SQLCMD : %SQLCMD_BINARY%
echo ============================================================================
echo.

rem ============================================================================
rem  STEP 1 - Create the database if it does not exist (checked via sqlcmd)
rem ============================================================================
echo [..] Checking whether database "%DB_NAME%" exists ...
set "DB_EXISTS="
"%SQLCMD%" -S "%SERVER%" %AUTH_ARGS% -d master -b -I -h -1 -W -Q "SET NOCOUNT ON; SELECT COUNT(*) FROM sys.databases WHERE name = N'%DB_NAME%';" >"%TEMP%\smartpos_dbcheck.txt" 2>&1
if errorlevel 1 (
    echo [ERROR] Could not query the SQL Server instance.
    type "%TEMP%\smartpos_dbcheck.txt"
    del "%TEMP%\smartpos_dbcheck.txt" 2>nul
    exit /b 1
)
for /f "usebackq delims=" %%R in ("%TEMP%\smartpos_dbcheck.txt") do if not defined DB_EXISTS set "DB_EXISTS=%%R"
del "%TEMP%\smartpos_dbcheck.txt" 2>nul

if "%DB_EXISTS%"=="0" (
    echo [..] Database "%DB_NAME%" does not exist - creating it ...
    "%SQLCMD%" -S "%SERVER%" %AUTH_ARGS% -d master -b -I -Q "IF DB_ID(N'%DB_NAME%') IS NULL CREATE DATABASE [%DB_NAME%] COLLATE %DB_DEFAULT_COLLATION%;"
    if errorlevel 1 (
        echo [ERROR] Failed to create database "%DB_NAME%".
        exit /b 1
    )
    echo [OK]  Database "%DB_NAME%" created.

    echo [..] Configuring recovery FULL + snapshot isolation ...
    "%SQLCMD%" -S "%SERVER%" %AUTH_ARGS% -d master -b -I -Q "ALTER DATABASE [%DB_NAME%] SET RECOVERY FULL; ALTER DATABASE [%DB_NAME%] SET ALLOW_SNAPSHOT_ISOLATION ON; ALTER DATABASE [%DB_NAME%] SET READ_COMMITTED_SNAPSHOT ON;"
    if errorlevel 1 (
        echo [WARN] Could not apply recovery/snapshot settings - continuing anyway.
    )
) else (
    echo [OK]  Database "%DB_NAME%" already exists - creation skipped.
)

rem ============================================================================
rem  STEP 2 - Apply SQL modules in FK dependency order (see Database\SQL\README.md)
rem ============================================================================
echo.
echo [..] Applying SQL modules in dependency order ...

set "SQL_FILES=17_Shared\functions.sql"
set "SQL_FILES=%SQL_FILES% 01_Authentication\tables.sql"
set "SQL_FILES=%SQL_FILES% 02_Users\tables.sql"
set "SQL_FILES=%SQL_FILES% 03_Business\tables.sql"
set "SQL_FILES=%SQL_FILES% 04_Categories\tables.sql"
set "SQL_FILES=%SQL_FILES% 06_Suppliers\tables.sql"
set "SQL_FILES=%SQL_FILES% 05_Products\tables.sql"
set "SQL_FILES=%SQL_FILES% 07_Inventory\tables.sql"
set "SQL_FILES=%SQL_FILES% 07_Inventory\SP_Inventory.sql"
set "SQL_FILES=%SQL_FILES% 08_Sales\tables.sql"
set "SQL_FILES=%SQL_FILES% 08_Sales\SP_CreateSale.sql"
set "SQL_FILES=%SQL_FILES% 09_Payments\tables.sql"
set "SQL_FILES=%SQL_FILES% 09_Payments\SP_Payments.sql"
set "SQL_FILES=%SQL_FILES% 10_CreditSales\tables.sql"
set "SQL_FILES=%SQL_FILES% 11_Returns\tables.sql"
set "SQL_FILES=%SQL_FILES% 11_Returns\SP_ProcessReturn.sql"
set "SQL_FILES=%SQL_FILES% 12_Notifications\tables.sql"
set "SQL_FILES=%SQL_FILES% 12_Notifications\SP_Notifications.sql"
set "SQL_FILES=%SQL_FILES% 15_Settings\tables.sql"
set "SQL_FILES=%SQL_FILES% 15_Settings\SP_Settings.sql"
set "SQL_FILES=%SQL_FILES% 16_Audit\tables.sql"
set "SQL_FILES=%SQL_FILES% 16_Audit\SP_Audit.sql"
set "SQL_FILES=%SQL_FILES% 01_Authentication\SP_Roles.sql"
set "SQL_FILES=%SQL_FILES% 01_Authentication\SP_Login.sql"
set "SQL_FILES=%SQL_FILES% 02_Users\SP_Users.sql"
set "SQL_FILES=%SQL_FILES% 03_Business\SP_Business.sql"
set "SQL_FILES=%SQL_FILES% 04_Categories\SP_Categories.sql"
set "SQL_FILES=%SQL_FILES% 05_Products\SP_Products.sql"
set "SQL_FILES=%SQL_FILES% 06_Suppliers\SP_Suppliers.sql"
set "SQL_FILES=%SQL_FILES% Views\Core_Operational_Views.sql"
set "SQL_FILES=%SQL_FILES% 13_Reports\VW_Report_Views.sql"
set "SQL_FILES=%SQL_FILES% 13_Reports\SP_Reports.sql"
set "SQL_FILES=%SQL_FILES% 14_Dashboard\VW_Dashboard_Views.sql"
set "SQL_FILES=%SQL_FILES% 14_Dashboard\SP_Dashboard.sql"
set "SQL_FILES=%SQL_FILES% Triggers\All_Triggers.sql"

for %%F in (%SQL_FILES%) do (
    call :RunSql "%SQL_DIR%\%%F"
    if errorlevel 1 goto :failed
)

rem ============================================================================
rem  STEP 3 - Record schema version, seed runtime data (required), then optional
rem           sample data
rem ============================================================================
call :RunSql "%SQL_DIR%\Migrations\001_baseline.sql"
if errorlevel 1 goto :failed

call :RunSql "%SQL_DIR%\SeedData\SeedData.sql"
if errorlevel 1 goto :failed

if /i "%RUN_SAMPLE_DATA%"=="1" (
    call :RunSql "%SQL_DIR%\SampleData\SampleData.sql"
    if errorlevel 1 goto :failed
) else (
    echo [..] RUN_SAMPLE_DATA=%RUN_SAMPLE_DATA% - skipping SampleData.
)

rem ============================================================================
rem  STEP 4 - Final verification of key objects
rem ============================================================================
echo.
echo [..] Verifying database objects ...
call :Verify
if errorlevel 1 goto :failed

goto :done

rem ============================================================================
rem  Subroutines
rem ============================================================================
:SetSqlAuthArgs
set "AUTH_ARGS=-U "%DB_USERNAME%" -P "%DB_PASSWORD%""
exit /b 0

:RunSql
set "_file=%~1"
if not exist "%_file%" (
    echo [ERROR] SQL file not found: "%_file%"
    exit /b 1
)
echo [RUN] %_file%
"%SQLCMD%" -S "%SERVER%" %AUTH_ARGS% -d "%DB_NAME%" -b -l "%SQLCMD_TIMEOUT%" -I -i "%_file%"
if errorlevel 1 (
    echo [ERROR] sqlcmd failed on: %_file%
    exit /b 1
)
echo [OK]  %_file%
exit /b 0

:Verify
"%SQLCMD%" -S "%SERVER%" %AUTH_ARGS% -d "%DB_NAME%" -b -l "%SQLCMD_TIMEOUT%" -I -h -1 -W -Q "SET NOCOUNT ON; SELECT 'tables' AS [object], COUNT(*) AS [count] FROM sys.tables UNION ALL SELECT 'views', COUNT(*) FROM sys.views UNION ALL SELECT 'procedures', COUNT(*) FROM sys.procedures UNION ALL SELECT 'functions', COUNT(*) FROM sys.objects WHERE type IN ('FN','IF','TF'); SELECT 'users' AS [object], COUNT(*) AS [count] FROM dbo.users;"
if errorlevel 1 (
    echo [ERROR] Verification query failed - database may be incomplete.
    exit /b 1
)
echo [OK]  Object verification completed.
exit /b 0

:failed
echo.
echo ============================================================================
echo  [ERROR] SmartPOS database setup FAILED. Review the messages above.
echo ============================================================================
exit /b 1

:done
echo.
echo ============================================================================
echo  [OK] SmartPOS database setup completed successfully.
echo  Target: %SERVER% / %DB_NAME%
echo ============================================================================
exit /b 0

:ParseEnvLine
set "_line=%~1"
:env_trim
if "%_line:~-1%"==" " set "_line=%_line:~0,-1%" & goto :env_trim
if "%_line%"=="" exit /b 0
if not "%_line:==%"=="%_line%" set "%_line%"
exit /b 0
