@echo off
REM Text to Voice Converter - Launcher
REM Double-click this file to start the application

title Text to Voice Converter

echo ================================================
echo   Text to Voice Converter
echo   100%% Offline Speech Generation
echo ================================================
echo.

REM Check if PowerShell is available
where powershell >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo ERROR: PowerShell not found!
    echo This application requires PowerShell to run.
    pause
    exit /b 1
)

REM Check if the PowerShell script exists
if not exist "%~dp0Convert_Text_To_Voice.ps1" (
    echo ERROR: Convert_Text_To_Voice.ps1 not found!
    echo Please ensure all files are in the same directory.
    pause
    exit /b 1
)

echo Starting application...
echo.

REM Run the PowerShell script with execution policy bypass
powershell.exe -ExecutionPolicy Bypass -NoProfile -File "%~dp0Convert_Text_To_Voice.ps1"

REM Check if there was an error
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo Application exited with an error.
    pause
)

exit /b 0
