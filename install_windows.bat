@echo off
setlocal EnableExtensions
cd /d "%~dp0"
set "APP_VERSION=1.0.0-alpha12"
set "RELEASE_DATE=2026-09-01"

echo ============================================================
echo   GAN Organism Arena v%APP_VERSION% ^(%RELEASE_DATE%^)
echo   Portable Godot 4.7.2 3D Alpha Installer
echo ============================================================
echo.
echo This installer keeps Godot inside this project folder.
echo No separate Godot installation is required.
echo The installer first searches for a checksum-valid cached Godot runtime archive.
echo Internet is only required if no reusable local copy can be found.
echo.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%CD%\tools\install_godot.ps1"
if errorlevel 1 (
    echo.
    echo Installation failed. Check logs\install\ for the detailed log.
    pause
    exit /b 1
)
echo.
echo Press N within 10 seconds to cancel automatic start.
choice /C YN /N /T 10 /D Y /M "Start GAN Organism Arena now? [Y/N] "
if errorlevel 2 exit /b 0
call "%CD%\run_windows.bat"
exit /b %ERRORLEVEL%
