@echo off
setlocal enabledelayedexpansion

:: Use environment variables for commits if specified, otherwise use latest
if defined ANGLE_COMMIT (
    set ANGLE_COMMIT_TO_USE=%ANGLE_COMMIT%
    echo Using specified ANGLE commit: %ANGLE_COMMIT_TO_USE%
) else (
    set ANGLE_COMMIT_TO_USE=
    echo Using latest ANGLE commit
)

if defined DEPOT_TOOLS_COMMIT (
    set DEPOT_TOOLS_COMMIT_TO_USE=%DEPOT_TOOLS_COMMIT%
    echo Using specified depot_tools commit: %DEPOT_TOOLS_COMMIT_TO_USE%
) else (
    set DEPOT_TOOLS_COMMIT_TO_USE=
    echo Using latest depot_tools commit
)

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
    git clone --depth 1 https://chromium.googlesource.com/chromium/tools/depot_tools.git

    :: Checkout specific commit if provided
    if defined DEPOT_TOOLS_COMMIT_TO_USE (
        cd depot_tools
        git fetch --depth 1 origin %DEPOT_TOOLS_COMMIT_TO_USE%
        git checkout %DEPOT_TOOLS_COMMIT_TO_USE%
        cd ..
    )
) else (
    echo depot_tools directory already exists, updating...
    cd depot_tools

    if defined DEPOT_TOOLS_COMMIT_TO_USE (
        git fetch --depth 1 origin %DEPOT_TOOLS_COMMIT_TO_USE%
        git checkout %DEPOT_TOOLS_COMMIT_TO_USE%
    ) else (
        git pull
    )
    cd ..
)

:: Add depot_tools to PATH
set PATH=%SCRIPT_DIR%depot_tools;%PATH%

:: Clone or update ANGLE
if not exist angle (
    echo Cloning ANGLE repository...
    git clone --depth 1 https://chromium.googlesource.com/angle/angle

    :: Checkout specific commit if provided
    if defined ANGLE_COMMIT_TO_USE (
        cd angle
        git fetch --depth 1 origin %ANGLE_COMMIT_TO_USE%
        git checkout %ANGLE_COMMIT_TO_USE%
        cd ..
    )
) else (
    echo ANGLE directory already exists, updating...
    cd angle

    if defined ANGLE_COMMIT_TO_USE (
        git fetch --depth 1 origin %ANGLE_COMMIT_TO_USE%
        git checkout %ANGLE_COMMIT_TO_USE%
    ) else (
        git pull
    )
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

:: Store the current ANGLE commit hash for reference
for /f "tokens=*" %%a in ('git rev-parse HEAD') do set CURRENT_ANGLE_COMMIT=%%a
echo Current ANGLE commit: %CURRENT_ANGLE_COMMIT%
echo %CURRENT_ANGLE_COMMIT%> ..\.angle_commit

cd %SCRIPT_DIR%