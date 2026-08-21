@echo off
setlocal EnableExtensions
rem ============================================================================
rem  SmartPOS Database - Restore from Full Backup (Windows batch)
rem ----------------------------------------------------------------------------
rem  Restores the SmartPOS database from a .bak file. If the database already
rem  exists you MUST pass /REPLACE, otherwise the restore is refused.
rem
rem  Connection settings come EXCLUSIVELY from Configuration\.env (or
rem  Configuration\database.env as a fallback).
rem
rem  Usage:
rem      restore_database.bat "<path-to-.bak>" [/REPLACE]
rem
rem  Examples:
rem      restore_database.bat "Database\Backup\SmartPOS_20260807_143000.bak"
rem      restore_database.bat "C:\backups\SmartPOS_prod.bak" /REPLACE
rem
rem  Relative paths are resolved against the Database root folder.
rem  Exit codes: 0 = success, 1 = any failure.
rem ============================================================================

rem ---- argument checks --------------------------------------------------------
if "%~1"=="" (
    echo Usage: restore_database.bat ^<path-to-.bak^> [/REPLACE]
    echo.
    echo   ^<path-to-.bak^>  Path to the backup file to restore.
    echo   /REPLACE          Overwrite an existing SmartPOS database.
    echo.
    exit /b 1
)
set "BAK_FILE=%~1"
set "REPLACE_MODE=%~2"

rem ---- resolve paths relative to this script (repo path contains spaces) ----
set "SCRIPT_DIR=%~dp0"
for %%I in ("%~dp0..") do set "SRC=%%~fI"

set "CONF_DIR=%SRC%\Configuration"

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

rem ---- resolve the backup file path (relative to Database root) -------------
set "_BAK=%BAK_FILE%"
if "%_BAK:~0,2%"=="\\" goto :bak_abs
if "%_BAK:~1,1%"==":" goto :bak_abs
set "_BAK=%SRC%\%_BAK%"
:bak_abs
if not exist "%_BAK%" (
    echo [ERROR] Backup file not found: "%_BAK%"
    exit /b 1
)

echo.
echo ============================================================================
echo  SmartPOS Database Restore
echo  Target  : %SERVER% / %DB_NAME%
echo  Backup  : %_BAK%
echo ============================================================================
echo.

rem ---- refuse to overwrite an existing database without /REPLACE ------------
set "DB_EXISTS="
"%SQLCMD%" -S "%SERVER%" %AUTH_ARGS% -d master -b -I -h -1 -W -Q "SET NOCOUNT ON; SELECT COUNT(*) FROM sys.databases WHERE name = N'%DB_NAME%';" >"%TEMP%\smartpos_dbchk.txt" 2>&1
if errorlevel 1 (
    echo [ERROR] Could not query the SQL Server instance.
    type "%TEMP%\smartpos_dbchk.txt"
    del "%TEMP%\smartpos_dbchk.txt" 2>nul
    exit /b 1
)
for /f "usebackq delims=" %%R in ("%TEMP%\smartpos_dbchk.txt") do if not defined DB_EXISTS set "DB_EXISTS=%%R"
del "%TEMP%\smartpos_dbchk.txt" 2>nul

if "%DB_EXISTS%"=="1" (
    if /i not "%REPLACE_MODE%"=="/REPLACE" (
        echo [ERROR] Database "%DB_NAME%" already exists.
        echo         Re-run with /REPLACE to overwrite it:
        echo         restore_database.bat "%~1" /REPLACE
        exit /b 1
    )
    echo [..] Database "%DB_NAME%" exists - restoring with REPLACE.
)

rem ---- run the restore --------------------------------------------------------
set "REPLACE_CLAUSE="
if /i "%REPLACE_MODE%"=="/REPLACE" set "REPLACE_CLAUSE=REPLACE "

echo [..] Running RESTORE DATABASE ... (this may take a moment)
"%SQLCMD%" -S "%SERVER%" %AUTH_ARGS% -d master -b -l "%SQLCMD_TIMEOUT%" -I -Q "IF DB_ID(N'%DB_NAME%') IS NOT NULL ALTER DATABASE [%DB_NAME%] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; RESTORE DATABASE [%DB_NAME%] FROM DISK = N'%_BAK%' WITH %REPLACE_CLAUSE%RECOVERY; ALTER DATABASE [%DB_NAME%] SET MULTI_USER;"
if errorlevel 1 (
    echo [ERROR] RESTORE DATABASE failed.
    exit /b 1
)

echo [OK]  Database "%DB_NAME%" restored from "%_BAK%".
exit /b 0

rem ============================================================================
rem  Subroutines
rem ============================================================================
:SetSqlAuthArgs
set "AUTH_ARGS=-U "%DB_USERNAME%" -P "%DB_PASSWORD%""
exit /b 0

:ParseEnvLine
set "_line=%~1"
:env_trim
if "%_line:~-1%"==" " set "_line=%_line:~0,-1%" & goto :env_trim
if "%_line%"=="" exit /b 0
if not "%_line:==%"=="%_line%" set "%_line%"
exit /b 0
