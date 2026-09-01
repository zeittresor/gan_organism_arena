@echo off
setlocal EnableExtensions
cd /d "%~dp0"
echo ============================================================
echo   GAN Organism Arena 1.0.0-alpha9 Diagnostics
echo ============================================================
echo.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%CD%\tools\verify_package.ps1"
if errorlevel 1 goto :fail
call "%CD%\run_parse_test.bat"
if errorlevel 1 goto :fail
call "%CD%\run_selftest.bat"
if errorlevel 1 goto :fail
call "%CD%\run_smoketest.bat"
if errorlevel 1 goto :fail
echo.
echo Diagnostics completed successfully.
echo Runtime logs: logs\latest_runtime.log
exit /b 0
:fail
echo.
echo Diagnostics failed. Please send logs\install\ and logs\latest_runtime.log if present.
pause
exit /b 1
