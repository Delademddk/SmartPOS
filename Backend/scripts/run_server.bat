@echo off
REM ==========================================================================
REM SmartPOS Backend - Start the API with uvicorn
REM ==========================================================================
setlocal

cd /d "%~dp0.."

if not exist .venv\Scripts\activate.bat (
    echo Virtual environment not found. Run scripts\setup_venv.bat first.
    exit /b 1
)

call .venv\Scripts\activate.bat
python -m uvicorn app.main:app --host %APP_HOST% --port %APP_PORT% --reload
