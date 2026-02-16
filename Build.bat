@echo off
REM ============================================================================
REM BetterStartHide Build Script
REM ============================================================================
REM This script compiles the AHK script and creates the installer
REM Requirements:
REM   - AutoHotkey v2 installed at C:\Program Files\AutoHotkey\v2\
REM   - Inno Setup 6 installed at "C:\Program Files (x86)\Inno Setup 6\"
REM ============================================================================

setlocal enabledelayedexpansion

echo ============================================
echo BetterStartHide Build Script
echo ============================================
echo.

REM Read version from VERSION.txt
set "VERSION_FILE=%~dp0VERSION.txt"
if exist "%VERSION_FILE%" (
    set /p APP_VERSION=<"%VERSION_FILE%"
    REM Skip comment lines and get first non-empty line
    for /f "usebackq tokens=*" %%a in ("%VERSION_FILE%") do (
        set "APP_VERSION=%%a"
        goto :got_version
    )
    :got_version
) else (
    set "APP_VERSION=1.3.1"
)
echo Version: %APP_VERSION%
echo.

REM Set paths - Try multiple locations for AutoHotkey
set "AHK_PATH="
if exist "%LOCALAPPDATA%\Programs\AutoHotkey\v2\AutoHotkey.exe" set "AHK_PATH=%LOCALAPPDATA%\Programs\AutoHotkey\v2\AutoHotkey.exe"
if not defined AHK_PATH if exist "C:\Program Files\AutoHotkey\v2\AutoHotkey.exe" set "AHK_PATH=C:\Program Files\AutoHotkey\v2\AutoHotkey.exe"
if not defined AHK_PATH if exist "C:\Program Files (x86)\AutoHotkey\v2\AutoHotkey.exe" set "AHK_PATH=C:\Program Files (x86)\AutoHotkey\v2\AutoHotkey.exe"
if not defined AHK_PATH if exist "C:\Program Files\AutoHotkey\AutoHotkey.exe" set "AHK_PATH=C:\Program Files\AutoHotkey\AutoHotkey.exe"
set "INNO_PATH=C:\Program Files (x86)\Inno Setup 6\ISCC.exe"
set "PROJECT_DIR=%~dp0"
set "OUTPUT_DIR=%PROJECT_DIR%installer\output"

REM Check if AutoHotkey exists
if not exist "%AHK_PATH%" (
    echo ERROR: AutoHotkey v2 not found at "%AHK_PATH%"
    echo Please install AutoHotkey v2 or update AHK_PATH in this script.
    goto :error
)

REM Check if Inno Setup exists
if not exist "%INNO_PATH%" (
    echo WARNING: Inno Setup 6 not found at "%INNO_PATH%"
    echo The compiled EXE will be created, but the installer will not be built.
    echo To build the installer, install Inno Setup 6 from https://jrsoftware.org/isdl.php
    set "INNO_MISSING=1"
)

REM Create output directory
if not exist "%OUTPUT_DIR%" mkdir "%OUTPUT_DIR%"

echo Step 1: Compiling BetterStartHide.ahk...
"%AHK_PATH%" /compile "%PROJECT_DIR%Compile.ahk"
if %ERRORLEVEL% neq 0 (
    echo ERROR: Failed to compile BetterStartHide.ahk
    goto :error
)

REM Check if EXE was created
if not exist "%PROJECT_DIR%BetterStartHide.exe" (
    echo ERROR: BetterStartHide.exe was not created
    goto :error
)

echo       BetterStartHide.exe created successfully!
echo.

if "%INNO_MISSING%"=="1" (
    echo ============================================
    echo Build completed (without installer)
    echo ============================================
    echo.
    echo Compiled EXE: %PROJECT_DIR%BetterStartHide.exe
    echo.
    echo To create an installer, install Inno Setup 6 and run this script again.
    goto :success
)

echo Step 2: Building installer...
cd /d "%PROJECT_DIR%installer"
"%INNO_PATH%" "BetterStartHide-Setup.iss"
if %ERRORLEVEL% neq 0 (
    echo ERROR: Failed to build installer
    goto :error
)

echo.
echo ============================================
echo Build completed successfully!
echo ============================================
echo.
echo Compiled EXE: %PROJECT_DIR%BetterStartHide.exe
echo Installer:    %OUTPUT_DIR%\BetterStartHide-%APP_VERSION%-Setup.exe
echo.

goto :success

:error
echo.
echo ============================================
echo Build FAILED!
echo ============================================
exit /b 1

:success
exit /b 0