@echo off
setlocal
where py >nul 2>nul
if not errorlevel 1 (
    py -3 "%~dp0integrations\arena_mcp.py" %*
    exit /b
)
where python >nul 2>nul
if not errorlevel 1 (
    python "%~dp0integrations\arena_mcp.py" %*
    exit /b
)
>&2 echo Optional MCP integration requires Python 3.10 or newer. The normal game does not require Python.
exit /b 1
