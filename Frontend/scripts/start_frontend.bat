@echo off
echo ============================================
echo    SmartPOS Frontend - Start Dev Server
echo ============================================
echo.

echo Checking dependencies...
if not exist node_modules (
    echo node_modules not found. Running setup first...
    call scripts\setup_frontend.bat
)

echo.
echo Starting development server...
echo The app will be available at http://localhost:5173
echo.
call npm run dev
