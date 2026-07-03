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
echo Starting GAN Organism Arena in windowed mode...
echo Runtime logs will be written to: %CD%\logs\
"%CD%\.venv\Scripts\python.exe" -m pandalife_gan.main --windowed --log-dir logs
set "ERR=%ERRORLEVEL%"
if not "%ERR%"=="0" (
    echo.
    echo GAN Organism Arena exited with error code %ERR%.
    echo Please send logs\latest_runtime.log and logs\panda3d_notify.log for debugging.
    pause
)
exit /b %ERR%
