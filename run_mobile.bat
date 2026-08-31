@echo off
setlocal EnableExtensions
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%CD%\tools\launch.ps1" -ForceRenderer mobile
if errorlevel 1 pause
