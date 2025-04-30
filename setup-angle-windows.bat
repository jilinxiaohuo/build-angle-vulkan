@echo off
setlocal enabledelayedexpansion

:: Configure commits
set ANGLE_COMMIT="f6da7aed210035a54e406ada571fb34892092c24"
set DEPOT_TOOLS_COMMIT="43d3eba89bc6b4fe34d99f0ee4af0ccc291c528c"

:: Get current directory
set SCRIPT_DIR=%~dp0
cd %SCRIPT_DIR%

:: Check for required tools
where python >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo Python is required but not found in PATH.
    echo Please install Python and add it to your PATH.
    exit /b 1
)

where git >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo Git is required but not found in PATH.
    echo Please install Git and add it to your PATH.
    exit /b 1
)

:: Clone or update depot_tools
if not exist depot_tools (
    echo Cloning depot_tools...
    git clone https://chromium.googlesource.com/chromium/tools/depot_tools.git
    cd depot_tools
    git checkout %DEPOT_TOOLS_COMMIT%
    cd ..
) else (
    echo depot_tools directory already exists, checking out specific commit...
    cd depot_tools
    git fetch
    git checkout %DEPOT_TOOLS_COMMIT%
    cd ..
)

:: Add depot_tools to PATH
set PATH=%SCRIPT_DIR%depot_tools;%PATH%

:: Clone or update ANGLE
if not exist angle (
    echo Cloning ANGLE repository...
    git clone https://chromium.googlesource.com/angle/angle
    cd angle
    git checkout %ANGLE_COMMIT%
    cd ..
) else (
    echo ANGLE directory already exists, checking out specific commit...
    cd angle
    git fetch
    git checkout %ANGLE_COMMIT%
    cd ..
)

:: Configure and sync ANGLE dependencies
cd angle
echo Configuring gclient...
call gclient config --unmanaged https://chromium.googlesource.com/angle/angle

:: Create a .gclient file with proper setup
echo solutions = [ > .gclient
echo   { >> .gclient
echo     "name": ".", >> .gclient
echo     "url": "https://chromium.googlesource.com/angle/angle", >> .gclient
echo     "deps_file": "DEPS", >> .gclient
echo     "managed": False, >> .gclient
echo   }, >> .gclient
echo ] >> .gclient

echo Syncing ANGLE dependencies with gclient...
call gclient sync --no-history --with_branch_heads

echo.
echo ANGLE setup complete!
cd %SCRIPT_DIR%