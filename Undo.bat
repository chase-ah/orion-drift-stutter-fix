@echo off
title Orion Drift Spectator - Undo Stutter Fix
cd /d "%~dp0"

if not exist "OrionDriftStutterFix.ps1" (
    echo.
    echo   ERROR: OrionDriftStutterFix.ps1 is missing.
    echo   Keep both files in the same folder.
    echo.
    pause
    exit /b 1
)

powershell -NoProfile -ExecutionPolicy Bypass -File "OrionDriftStutterFix.ps1" -Undo

echo.
pause
