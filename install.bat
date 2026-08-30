@echo off
echo ========================================
echo  Flutter Project - Initial Setup
echo ========================================
echo.

:: Check if fvm is installed
where fvm >nul 2>nul
if %ERRORLEVEL% neq 0 (
    echo ERROR: FVM is not installed or not in PATH
    echo Please install FVM first: https://fvm.app/documentation/getting-started/installation
    pause
    exit /b 1
)

echo [1/3] Installing Flutter version from .fvmrc...
fvm install
if %ERRORLEVEL% neq 0 (
    echo ERROR: Failed to install Flutter version
    pause
    exit /b 1
)

echo.
echo [2/3] Getting dependencies...
fvm flutter pub get
if %ERRORLEVEL% neq 0 (
    echo ERROR: Failed to get dependencies
    pause
    exit /b 1
)

echo.
echo [3/3] Running tests...
fvm flutter test
if %ERRORLEVEL% neq 0 (
    echo WARNING: Some tests failed
)

echo.
echo ========================================
echo  Setup complete!
echo ========================================
echo.
pause
