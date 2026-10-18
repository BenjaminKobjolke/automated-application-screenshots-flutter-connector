@echo off
setlocal
pushd "%~dp0..\example"
if errorlevel 1 exit /b 1

fvm flutter test --reporter expanded integration_test -d windows
set TESTRESULT=%ERRORLEVEL%

popd
exit /b %TESTRESULT%
