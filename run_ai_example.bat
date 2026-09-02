@echo off
setlocal
where py >nul 2>nul
if not errorlevel 1 (
    py -3 "%~dp0integrations\arena_client.py" %*
    exit /b
)
where python >nul 2>nul
if not errorlevel 1 (
    python "%~dp0integrations\arena_client.py" %*
    exit /b
)
>&2 echo Optional AI example requires Python 3.10 or newer.
exit /b 1
