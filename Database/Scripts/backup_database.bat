@echo off
setlocal EnableExtensions
rem ============================================================================
rem  SmartPOS Database - Full Backup (Windows batch)
rem ----------------------------------------------------------------------------
rem  Takes a full, compressed BACKUP DATABASE of %DB_NAME% to %BACKUP_DIR% with a
rem  timestamped filename, then purges backups older than BACKUP_KEEP_DAYS.
rem
rem  Connection settings come EXCLUSIVELY from Configuration\.env (or
rem  Configuration\database.env as a fallback).
rem
rem  Usage:
rem      backup_database.bat
rem
rem  Exit codes: 0 = success, 1 = any failure.
rem ============================================================================

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
if "%BACKUP_KEEP_DAYS%"=="" set "BACKUP_KEEP_DAYS=14"

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

rem ---- resolve backup directory (relative values are anchored to the Database root) ----
if "%BACKUP_DIR%"=="" set "BACKUP_DIR=%SRC%\Backup"
set "_BD=%BACKUP_DIR%"
if "%_BD:~0,2%"=="\\" goto :bd_abs
if "%_BD:~1,1%"==":" goto :bd_abs
set "_BD=%SRC%\%_BD%"
:bd_abs
if "%_BD:~-1%"=="\" set "_BD=%_BD:~0,-1%"
if not exist "%_BD%" mkdir "%_BD%" 2>nul
if not exist "%_BD%" (
    echo [ERROR] Cannot create backup directory "%_BD%".
    exit /b 1
)

rem ---- generate timestamp (yyyyMMdd_HHmmss) ---------------------------------
set "TS="
for /f %%T in ('powershell -NoProfile -Command "Get-Date -Format yyyyMMdd_HHmmss"') do set "TS=%%T"
if "%TS%"=="" (
    echo [ERROR] Could not generate a backup timestamp.
    exit /b 1
)

set "BACKUP_FILE=%_BD%\%DB_NAME%_%TS%.bak"

echo.
echo ============================================================================
echo  SmartPOS Database Backup
echo  Target : %SERVER% / %DB_NAME%
echo  Output : %BACKUP_FILE%
echo ============================================================================
echo.

echo [..] Running BACKUP DATABASE ... (this may take a moment)
"%SQLCMD%" -S "%SERVER%" %AUTH_ARGS% -d master -b -l "%SQLCMD_TIMEOUT%" -I -Q "BACKUP DATABASE [%DB_NAME%] TO DISK = N'%BACKUP_FILE%' WITH INIT, NAME = N'%DB_NAME%-Full-%TS%', COMPRESSION, STATS = 10;"
if errorlevel 1 (
    echo [ERROR] BACKUP DATABASE failed.
    exit /b 1
)

rem ---- report the resulting file --------------------------------------------
for %%A in ("%BACKUP_FILE%") do echo [OK]  Backup created: %BACKUP_FILE%  (%%~zA bytes)

rem ---- retention: purge backups older than BACKUP_KEEP_DAYS days ------------
echo [..] Purging backups older than %BACKUP_KEEP_DAYS% days ...
forfiles /P "%_BD%" /M "*.bak" /D -%BACKUP_KEEP_DAYS% /C "cmd /c del /q @path" >nul 2>&1
if errorlevel 1 echo [..] No old backups to purge.

echo [OK]  Backup completed successfully.
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
