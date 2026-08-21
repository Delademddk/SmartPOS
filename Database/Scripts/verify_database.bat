@echo off
setlocal EnableExtensions
rem ============================================================================
rem  SmartPOS Database - Test Suite Runner (Windows batch)
rem ----------------------------------------------------------------------------
rem  Runs every Testing\NN_*.sql suite (00..12) in order using sqlcmd -b and
rem  prints a PASS/FAIL summary. Exits non-zero if any suite fails.
rem
rem  Connection settings come EXCLUSIVELY from Configuration\.env (or
rem  Configuration\database.env as a fallback).
rem
rem  Usage:
rem      verify_database.bat
rem
rem  Exit codes: 0 = all suites passed, 1 = one or more suites failed.
rem ============================================================================

rem ---- resolve paths relative to this script (repo path contains spaces) ----
set "SCRIPT_DIR=%~dp0"
for %%I in ("%~dp0..") do set "SRC=%%~fI"

set "TEST_DIR=%SRC%\Testing"
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

set "PASS_COUNT=0"
set "FAIL_COUNT=0"

echo.
echo ============================================================================
echo  SmartPOS Test Suite  (target: %SERVER% / %DB_NAME%)
echo ============================================================================
for /f "delims=" %%F in ('dir /b "%TEST_DIR%\0*.sql" "%TEST_DIR%\1*.sql" 2^>nul') do (
    call :RunTest "%TEST_DIR%\%%F"
)

if not defined TESTS_RAN (
    echo [ERROR] No test suites found under "%TEST_DIR%" (expected Testing\00_*.sql .. 12_*.sql).
    exit /b 1
)

echo.
echo ============================================================================
echo  SUMMARY : PASS=%PASS_COUNT%  FAIL=%FAIL_COUNT%
echo ============================================================================
if %FAIL_COUNT% GTR 0 (
    echo [ERROR] One or more test suites FAILED. Review the output above.
    exit /b 1
)
echo [OK]  All test suites passed.
exit /b 0

rem ============================================================================
rem  Subroutines
rem ============================================================================
:SetSqlAuthArgs
set "AUTH_ARGS=-U "%DB_USERNAME%" -P "%DB_PASSWORD%""
exit /b 0

:RunTest
set "_file=%~1"
set "_name=%~nx1"
set "TESTS_RAN=1"
echo [..] Running %_name% ...
"%SQLCMD%" -S "%SERVER%" %AUTH_ARGS% -d "%DB_NAME%" -b -l "%SQLCMD_TIMEOUT%" -I -i "%_file%" >"%TEMP%\smartpos_test_%_name%.log" 2>&1
if errorlevel 1 (
    echo   FAIL  %_name%
    echo     --- sqlcmd output ---
    type "%TEMP%\smartpos_test_%_name%.log"
    set /a FAIL_COUNT+=1
) else (
    echo   PASS  %_name%
    set /a PASS_COUNT+=1
)
del "%TEMP%\smartpos_test_%_name%.log" 2>nul
exit /b 0

:ParseEnvLine
set "_line=%~1"
:env_trim
if "%_line:~-1%"==" " set "_line=%_line:~0,-1%" & goto :env_trim
if "%_line%"=="" exit /b 0
if not "%_line:==%"=="%_line%" set "%_line%"
exit /b 0
