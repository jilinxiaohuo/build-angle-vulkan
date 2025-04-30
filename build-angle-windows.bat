@echo off
setlocal enabledelayedexpansion

:: Get current directory
set SCRIPT_DIR=%~dp0
cd %SCRIPT_DIR%

:: Setup ANGLE if needed
if not exist angle (
    echo ANGLE not found. Running setup script...
    call setup-angle-windows.bat
    if %ERRORLEVEL% NEQ 0 (
        echo Setup failed. Exiting.
        exit /b 1
    )
)

:: Add depot_tools to PATH
set PATH=%SCRIPT_DIR%depot_tools;%PATH%

:: Go to ANGLE directory
cd angle

:: Common GN args for all Windows builds
set COMMON_ARGS=^
    is_debug=false ^
    is_component_build=true ^
    angle_standalone=true ^
    angle_build_tests=false ^
    angle_enable_swiftshader=false ^
    chrome_pgo_phase=0 ^
    is_official_build=true ^
    use_custom_libcxx=false ^
    strip_debug_info=true ^
    symbol_level=0 ^
    angle_enable_trace=false ^
    angle_enable_d3d9=false ^
    angle_enable_gl=false ^
    angle_enable_vulkan=false ^
    angle_enable_null=false ^
    angle_enable_metal=false ^
    angle_enable_wgpu=false ^
    angle_enable_d3d11=true ^
    angle_enable_essl=true ^
    angle_enable_glsl=true

:: Create output directories
if not exist ..\build\windows\x64 mkdir ..\build\windows\x64
if not exist ..\build\windows\arm64 mkdir ..\build\windows\arm64

:: Build for Windows x64
echo Building ANGLE for Windows x64...
call gn gen out/windows-x64 --args="%COMMON_ARGS% target_cpu=\"x64\""
if %ERRORLEVEL% NEQ 0 (
    echo Failed to generate x64 build files. Exiting.
    exit /b 1
)

call ninja -C out/windows-x64
if %ERRORLEVEL% NEQ 0 (
    echo Failed to build x64 version. Exiting.
    exit /b 1
)

:: Copy the DLLs and libs to build directory
echo Copying x64 files to build directory...
copy /Y out\windows-x64\libEGL.dll ..\build\windows\x64\
copy /Y out\windows-x64\libGLESv2.dll ..\build\windows\x64\
copy /Y out\windows-x64\libGLESv1_CM.dll ..\build\windows\x64\
copy /Y out\windows-x64\*.lib ..\build\windows\x64\

:: Build for Windows ARM64
echo Building ANGLE for Windows ARM64...
call gn gen out/windows-arm64 --args="%COMMON_ARGS% target_cpu=\"arm64\""
if %ERRORLEVEL% NEQ 0 (
    echo Failed to generate ARM64 build files. Exiting.
    exit /b 1
)

call ninja -C out/windows-arm64
if %ERRORLEVEL% NEQ 0 (
    echo Failed to build ARM64 version. Exiting.
    exit /b 1
)

:: Copy the DLLs and libs to build directory
echo Copying ARM64 files to build directory...
copy /Y out\windows-arm64\libEGL.dll ..\build\windows\arm64\
copy /Y out\windows-arm64\libGLESv2.dll ..\build\windows\arm64\
copy /Y out\windows-arm64\libGLESv1_CM.dll ..\build\windows\arm64\
copy /Y out\windows-arm64\*.lib ..\build\windows\arm64\

:: Return to script directory
cd %SCRIPT_DIR%

echo.
echo Windows builds complete! Files are available in:
echo   - build\windows\x64 (for Windows x64)
echo   - build\windows\arm64 (for Windows ARM64)