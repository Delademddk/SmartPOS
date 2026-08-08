@echo off
echo ============================================
echo    SmartPOS Frontend - Verify Setup
echo ============================================
echo.

echo [1/4] Checking Node.js...
node --version
if %errorlevel% neq 0 (
    echo FAIL: Node.js not found
    pause
    exit /b 1
)
echo OK

echo.
echo [2/4] Checking npm...
npm --version
if %errorlevel% neq 0 (
    echo FAIL: npm not found
    pause
    exit /b 1
)
echo OK

echo.
echo [3/4] Checking node_modules...
if not exist node_modules (
    echo FAIL: node_modules not found. Run setup_frontend.bat first.
    pause
    exit /b 1
)
echo OK

echo.
echo [4/4] Checking .env...
if not exist .env (
    echo FAIL: .env not found. Copy .env.example to .env.
    pause
    exit /b 1
)
echo OK

echo.
echo ============================================
echo    All checks passed!
echo ============================================
echo.
echo You can now run: start_frontend.bat
echo.
pause
