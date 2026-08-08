@echo off
REM ==========================================================================
REM SmartPOS Backend - Database setup
REM --------------------------------------------------------------------------
REM The authoritative schema, seed data, views and stored procedures are the
REM SQL scripts in the repository root Database\SQL. Run them in order against
REM SQL Server (SQLCMD or SSMS), then stamp Alembic so migrations stay in sync.
REM ==========================================================================
setlocal

cd /d "%~dp0.."

set SQLCMD="sqlcmd"
set DB=SmartPOS

echo [1/3] Creating database (if missing)...
%SQLCMD% -S %DB_SERVER% -U %DB_USERNAME% -P %DB_PASSWORD% -Q "IF DB_ID(N'%DB%') IS NULL CREATE DATABASE [%DB%]"
if errorlevel 1 (
    echo Could not connect to SQL Server. Check DB_SERVER / DB_USERNAME / DB_PASSWORD in .env
    exit /b 1
)

echo [2/3] Executing schema scripts in order...
for %%f in (
    "..\Database\SQL\Tables\*.sql"
    "..\Database\SQL\Views\*.sql"
    "..\Database\SQL\StoredProcedures\*.sql"
    "..\Database\SQL\SeedData\*.sql"
) do (
    if exist %%f (
        echo   Applying %%f
        %SQLCMD% -S %DB_SERVER% -U %DB_USERNAME% -P %DB_PASSWORD% -d %DB% -i "%%f"
        if errorlevel 1 goto :error
    )
)

echo [3/3] Stamping Alembic baseline...
call .venv\Scripts\activate.bat
alembic stamp 0001

echo.
echo Database setup complete.
exit /b 0

:error
echo.
echo Database setup failed.
exit /b 1
