@echo off
setlocal EnableExtensions
cd /d "%~dp0"

if not exist "logs" mkdir "logs"

if not exist ".venv\Scripts\python.exe" (
    echo Virtual environment not found. Running installer first...
    call install_windows.bat
    exit /b %ERRORLEVEL%
)

set "PYTHONPATH=%CD%\src"
set "PYTHONUNBUFFERED=1"
echo Running non-graphical self-test...
"%CD%\.venv\Scripts\python.exe" -m pandalife_gan.main --self-test --log-dir logs
set "ERR=%ERRORLEVEL%"
if not "%ERR%"=="0" (
    echo.
    echo Self-test failed with error code %ERR%.
    echo Please send logs\latest_runtime.log.
    pause
)
exit /b %ERR%
