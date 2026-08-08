@echo off
echo ============================================
echo    SmartPOS Frontend - Setup
echo ============================================
echo.

echo [1/3] Checking Node.js installation...
node --version >nul 2>&1
if %errorlevel% neq 0 (
    echo ERROR: Node.js is not installed.
    echo Please install Node.js 18+ from https://nodejs.org
    pause
    exit /b 1
)
echo Node.js found: 
node --version

echo.
echo [2/3] Installing dependencies...
call npm install
if %errorlevel% neq 0 (
    echo ERROR: Failed to install dependencies.
    pause
    exit /b 1
)

echo.
echo [3/3] Setting up environment...
if not exist .env (
    copy .env.example .env
    echo Created .env from .env.example
    echo Please edit .env to configure your backend URL.
) else (
    echo .env already exists.
)

echo.
echo ============================================
echo    Setup Complete!
echo ============================================
echo.
echo Next steps:
echo   1. Edit .env if needed
echo   2. Run: start_frontend.bat
echo.
pause
