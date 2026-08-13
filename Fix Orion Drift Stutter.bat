@echo off
title Orion Drift Spectator - Stutter Fix
cd /d "%~dp0"

if not exist "OrionDriftStutterFix.ps1" (
    echo.
    echo   ERROR: OrionDriftStutterFix.ps1 is missing.
    echo   Keep both files in the same folder, and make sure you EXTRACTED the zip
    echo   instead of running it from inside the zip viewer.
    echo.
    pause
    exit /b 1
)

powershell -NoProfile -ExecutionPolicy Bypass -File "OrionDriftStutterFix.ps1"

echo.
pause
