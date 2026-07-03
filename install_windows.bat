@echo off
setlocal EnableExtensions EnableDelayedExpansion
cd /d "%~dp0"

set "APP_NAME=GAN Organism Arena"
set "APP_VERSION=0.2.8"
set "APP_RELEASE_DATE=2026-07-03"
set "PY_EXE=python"
set "VENV_DIR=.venv"
set "WHEELHOUSE_DIR=wheelhouse"
set "LOG_ROOT=logs"
set "INSTALL_LOG_DIR=%LOG_ROOT%\install"
for /f %%i in ('powershell -NoProfile -Command "Get-Date -Format yyyyMMdd_HHmmss"') do set "STAMP=%%i"
if "%STAMP%"=="" set "STAMP=install"
set "LOG_FILE=%INSTALL_LOG_DIR%\install_%STAMP%.log"

if not exist "%LOG_ROOT%" mkdir "%LOG_ROOT%"
if not exist "%INSTALL_LOG_DIR%" mkdir "%INSTALL_LOG_DIR%"
if not exist "%WHEELHOUSE_DIR%" mkdir "%WHEELHOUSE_DIR%"
if not exist "settings" mkdir "settings"
if not exist "exports" mkdir "exports"
if not exist "exports\obj" mkdir "exports\obj"

(
    echo ============================================================
    echo   %APP_NAME% v%APP_VERSION% ^(%APP_RELEASE_DATE%^) - Windows Installer
    echo ============================================================
    echo Version: %APP_VERSION%
    echo Release date: %APP_RELEASE_DATE%
    echo Started: %DATE% %TIME%
    echo Root: %CD%
    echo Venv: %CD%\%VENV_DIR%
    echo Wheelhouse: %CD%\%WHEELHOUSE_DIR%
    echo Log: %CD%\%LOG_FILE%
    echo.
) > "%LOG_FILE%"

echo ============================================================
echo   %APP_NAME% v%APP_VERSION% ^(%APP_RELEASE_DATE%^) - Windows Installer
echo ============================================================
echo Log: %LOG_FILE%
echo Local venv: %VENV_DIR%
echo Local wheelhouse: %WHEELHOUSE_DIR%
echo.

echo [1/7] Checking Python...
%PY_EXE% --version >> "%LOG_FILE%" 2>&1
if errorlevel 1 (
    echo ERROR: Python was not found.
    echo Please install Python 3.10 or newer from https://www.python.org/downloads/windows/
    echo Make sure "Add python.exe to PATH" is enabled.
    pause
    exit /b 1
)
%PY_EXE% --version
%PY_EXE% -c "import sys; raise SystemExit(0 if sys.version_info >= (3,10) else 1)" >> "%LOG_FILE%" 2>&1
if errorlevel 1 (
    echo ERROR: Python 3.10 or newer is required.
    pause
    exit /b 1
)

echo.
echo [2/7] Creating or reusing local virtual environment...
if not exist "%VENV_DIR%\Scripts\python.exe" (
    %PY_EXE% -m venv "%VENV_DIR%" >> "%LOG_FILE%" 2>&1
    if errorlevel 1 (
        echo ERROR: Could not create virtual environment. See log.
        pause
        exit /b 1
    )
) else (
    echo Existing virtual environment found. Reusing it.
    echo Existing virtual environment found. Reusing it. >> "%LOG_FILE%"
)

set "VPY=%CD%\%VENV_DIR%\Scripts\python.exe"

echo.
echo [3/7] Upgrading pip/setuptools/wheel...
"%VPY%" -m pip install --upgrade pip setuptools wheel >> "%LOG_FILE%" 2>&1
if errorlevel 1 (
    echo WARNING: pip upgrade failed. Continuing with existing pip. See log.
    echo WARNING: pip upgrade failed. Continuing with existing pip. >> "%LOG_FILE%"
)

echo.
echo [4/7] Preparing local wheelhouse...
echo Wheelhouse population attempt started. >> "%LOG_FILE%"
"%VPY%" -m pip wheel --prefer-binary -r requirements.txt -w "%WHEELHOUSE_DIR%" >> "%LOG_FILE%" 2>&1
if errorlevel 1 (
    echo WARNING: Could not fully populate wheelhouse. Online install fallback remains available.
    echo WARNING: Could not fully populate wheelhouse. Online install fallback remains available. >> "%LOG_FILE%"
) else (
    echo Wheelhouse prepared.
    echo Wheelhouse prepared. >> "%LOG_FILE%"
)

echo.
echo [5/7] Installing requirements...
dir /b "%WHEELHOUSE_DIR%\*.whl" >nul 2>&1
if not errorlevel 1 (
    echo Installing from local wheelhouse first...
    echo Installing from local wheelhouse first... >> "%LOG_FILE%"
    "%VPY%" -m pip install --no-index --find-links "%CD%\%WHEELHOUSE_DIR%" -r requirements.txt >> "%LOG_FILE%" 2>&1
    if errorlevel 1 (
        echo WARNING: Wheelhouse install failed or incomplete. Falling back to online pip install.
        echo WARNING: Wheelhouse install failed or incomplete. Falling back to online pip install. >> "%LOG_FILE%"
        "%VPY%" -m pip install -r requirements.txt >> "%LOG_FILE%" 2>&1
        if errorlevel 1 (
            echo ERROR: Dependency installation failed. See log.
            pause
            exit /b 1
        )
    )
) else (
    echo No wheels found yet. Installing requirements online...
    echo No wheels found yet. Installing requirements online... >> "%LOG_FILE%"
    "%VPY%" -m pip install -r requirements.txt >> "%LOG_FILE%" 2>&1
    if errorlevel 1 (
        echo ERROR: Dependency installation failed. See log.
        pause
        exit /b 1
    )
)

echo.
echo [6/7] Preparing assets...
"%VPY%" tools\download_assets.py >> "%LOG_FILE%" 2>&1
if errorlevel 1 (
    echo ERROR: Asset preparation failed. See log.
    pause
    exit /b 1
)

echo.
echo [7/7] Verifying project imports and self-test...
"%VPY%" tools\verify_project.py >> "%LOG_FILE%" 2>&1
if errorlevel 1 (
    echo ERROR: Project verification failed. See log.
    pause
    exit /b 1
)

echo.
echo ============================================================
echo   Installation complete.
echo ============================================================
echo Logs: %LOG_ROOT%\ and %INSTALL_LOG_DIR%\
echo Wheelhouse: %WHEELHOUSE_DIR%\
echo.
echo Press any key within 10 seconds to cancel automatic start.
timeout /t 10 >nul
if errorlevel 1 (
    echo Automatic start cancelled.
    exit /b 0
)
call run_windows.bat
exit /b %ERRORLEVEL%
