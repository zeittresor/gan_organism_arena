@echo off
setlocal EnableExtensions
cd /d "%~dp0"
set "GODOT=%CD%\runtime\godot\Godot_v4.7.2-stable_win64_console.exe"
if not exist "%GODOT%" (
    echo Local Godot runtime missing. Run install_windows.bat first.
    pause
    exit /b 2
)
set "RENDER=forward_plus"
if exist "settings\config.json" (
    for /f "usebackq delims=" %%R in (`powershell.exe -NoProfile -Command "try{(Get-Content -Raw 'settings/config.json'|ConvertFrom-Json).renderer}catch{'forward_plus'}"`) do set "RENDER=%%R"
)
if /I "%RENDER%"=="compatibility" set "METHOD=gl_compatibility"
if /I "%RENDER%"=="mobile" set "METHOD=mobile"
if not defined METHOD set "METHOD=forward_plus"
echo Starting GAN Organism Arena 1.0.0-alpha9 in console mode.
echo Renderer: %RENDER% ^(%METHOD%^)
echo Runtime log: logs\latest_runtime.log
echo.
"%GODOT%" --path "%CD%" --rendering-method %METHOD%
set "ERR=%ERRORLEVEL%"
echo.
echo Godot exited with code %ERR%.
if not "%ERR%"=="0" (
    echo Please send logs\latest_runtime.log and this console output.
    pause
)
exit /b %ERR%
