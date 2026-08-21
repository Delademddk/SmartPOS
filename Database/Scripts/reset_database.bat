@echo off
setlocal EnableExtensions
rem ============================================================================
rem  SmartPOS Database - Reset (drop + recreate + full setup)
rem ----------------------------------------------------------------------------
rem  DANGER: Drops the entire SmartPOS database (ALL DATA IS LOST) after an
rem  interactive confirmation, then re-runs the full setup (setup_database.bat).
rem
rem  Connection settings come EXCLUSIVELY from Configuration\.env (or
rem  Configuration\database.env as a fallback).
rem
rem  Usage:
rem      reset_database.bat
rem
rem  Exit codes: 0 = success, 1 = cancelled or any failure.
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
echo   WARNING - THIS WILL DESTROY ALL DATA
echo   The database "%DB_NAME%" on %SERVER% will be DROPPED and recreated.
echo ============================================================================
echo.
set "CONFIRM="
set /p "CONFIRM=Type RESET to continue: "
if /i not "%CONFIRM%"=="RESET" (
    echo [..] Confirmation did not match. Aborting - nothing was changed.
    exit /b 1
)

echo.
echo [..] Dropping database "%DB_NAME%" ...
"%SQLCMD%" -S "%SERVER%" %AUTH_ARGS% -d master -b -l "%SQLCMD_TIMEOUT%" -I -Q "IF DB_ID(N'%DB_NAME%') IS NOT NULL BEGIN ALTER DATABASE [%DB_NAME%] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE [%DB_NAME%]; END;"
if errorlevel 1 (
    echo [ERROR] Failed to drop database "%DB_NAME%".
    exit /b 1
)
echo [OK]  Database "%DB_NAME%" dropped.

echo.
echo [..] Re-running full setup ...
call "%~dp0setup_database.bat"
exit /b %errorlevel%

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
