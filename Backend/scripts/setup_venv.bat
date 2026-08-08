@echo off
REM ==========================================================================
REM SmartPOS Backend - Create virtual environment and install dependencies
REM ==========================================================================
setlocal

cd /d "%~dp0.."

echo [1/3] Creating virtual environment...
python -m venv .venv
if errorlevel 1 goto :error

echo [2/3] Activating environment and upgrading pip...
call .venv\Scripts\activate.bat
python -m pip install --upgrade pip
if errorlevel 1 goto :error

echo [3/3] Installing requirements...
pip install -r requirements.txt
if errorlevel 1 goto :error

echo.
echo Setup complete. Activate with:  .venv\Scripts\activate.bat
echo Start the server with:         scripts\run_server.bat
exit /b 0

:error
echo.
echo Setup failed. See messages above.
exit /b 1
