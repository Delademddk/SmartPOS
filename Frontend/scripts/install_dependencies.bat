@echo off
echo ============================================
echo    SmartPOS Frontend - Install Dependencies
echo ============================================
echo.

echo Installing npm packages...
call npm install
if %errorlevel% neq 0 (
    echo ERROR: Failed to install dependencies.
    pause
    exit /b 1
)

echo.
echo Dependencies installed successfully.
pause
