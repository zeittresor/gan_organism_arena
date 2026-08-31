@echo off
setlocal EnableExtensions
cd /d "%~dp0"
set "GODOT=%CD%\runtime\godot\Godot_v4.7.2-stable_win64_console.exe"
if not exist "%GODOT%" (
    echo Local Godot runtime missing. Run install_windows.bat first.
    pause
    exit /b 2
)
"%GODOT%" --headless --path "%CD%" --script res://game/parse_test.gd --rendering-method gl_compatibility
set "ERR=%ERRORLEVEL%"
if not "%ERR%"=="0" pause
exit /b %ERR%
