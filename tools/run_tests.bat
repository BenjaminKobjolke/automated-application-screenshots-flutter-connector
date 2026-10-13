@echo off
echo ========================================
echo  Flutter Project - Run Tests
echo ========================================
echo.

:: Check if fvm is installed
where fvm >nul 2>nul
if %ERRORLEVEL% neq 0 (
    echo ERROR: FVM is not installed or not in PATH
    echo Please install FVM first: https://fvm.app/documentation/getting-started/installation
    exit /b 1
)

echo Running tests...
echo.

:: The runner writes straight to the console so every test shows up as its
:: own line while the run is still going (expanded reporter = one line per
:: test). No redirect: it hides all progress until the runner exits. No pipe
:: into findstr/grep either: %ERRORLEVEL% would then be the FILTER's exit
:: code, not flutter test's, so a real failure could read as a pass.
fvm flutter test --reporter expanded
set TESTRESULT=%ERRORLEVEL%

if %TESTRESULT% neq 0 (
    echo.
    echo ========================================
    echo  Some tests failed!
    echo ========================================
) else (
    echo.
    echo ========================================
    echo  All tests passed!
    echo ========================================
)
echo.
exit /b %TESTRESULT%
