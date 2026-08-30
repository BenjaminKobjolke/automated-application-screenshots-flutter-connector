@echo off
echo ========================================
echo  Flutter Project - Update Dependencies
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

echo [1/3] Upgrading all dependencies...
fvm flutter pub upgrade
if %ERRORLEVEL% neq 0 (
    echo ERROR: Failed to upgrade dependencies
    pause
    exit /b 1
)

echo.
echo [2/3] Running analyzer...
fvm flutter analyze
if %ERRORLEVEL% neq 0 (
    echo WARNING: Analyzer found issues
)

echo.
echo [3/3] Running tests...
fvm flutter test
if %ERRORLEVEL% neq 0 (
    echo WARNING: Some tests failed after update
    echo You may need to fix compatibility issues
)

echo.
echo ========================================
echo  Update complete!
echo ========================================
echo.
echo Updated packages are now in pubspec.lock
echo Remember to commit pubspec.lock if everything works correctly
echo.
pause
