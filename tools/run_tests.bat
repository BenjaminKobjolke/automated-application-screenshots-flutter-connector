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
    pause
    exit /b 1
)

echo Running tests...
echo.

:: Output goes to a temp file first so the script captures flutter test's OWN
:: exit code below. Never pipe `fvm flutter test` straight into findstr/grep
:: for noise filtering - the pipe's exit code becomes the FILTER's exit code,
:: not flutter test's, silently corrupting pass/fail detection either way
:: (a real failure can read as pass, or vice versa). findstr also has a
:: ~8191-char line-length limit and errors on long compact-reporter lines
:: ("Line X is too long"), which trips this same bug even harder.
set TESTLOG=%TEMP%\_flutter_tests_output.log
fvm flutter test > "%TESTLOG%" 2>&1
set TESTRESULT=%ERRORLEVEL%

:: To filter benign third-party log noise for display, filter the temp file
:: with PowerShell Select-String (no line-length limit, runs in its own
:: process so it cannot affect %TESTRESULT%) instead of findstr, e.g.:
::   powershell -NoProfile -Command "Get-Content -LiteralPath '%TESTLOG%' | Select-String -NotMatch 'pattern1|pattern2'"
type "%TESTLOG%"

del "%TESTLOG%" >nul 2>&1

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
pause
exit /b %TESTRESULT%
