#!/bin/bash
set -e

# Get current directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
cd "$SCRIPT_DIR"

# Setup ANGLE if needed
if [ ! -d "angle" ]; then
    source ./setup-angle-mac.sh
else
    # Add depot_tools to PATH
    export PATH="$PATH:$SCRIPT_DIR/depot_tools"
fi

# Go to ANGLE directory
cd angle

# Common GN args for all macOS builds
COMMON_ARGS='
    is_debug=false
    is_component_build=false
    angle_enable_metal=true
    angle_standalone=true
    angle_build_tests=false

    # Enable official build optimizations
    is_official_build=true
    chrome_pgo_phase=0

    # Disable unused backends
    angle_enable_d3d9=false
    angle_enable_d3d11=false
    angle_enable_gl=false
    angle_enable_null=false
    angle_enable_vulkan=false
    angle_enable_wgpu=false

    # Language settings
    angle_enable_essl=false
    angle_enable_glsl=true

    # Optimize for size
    symbol_level=0
    strip_debug_info=true
    angle_enable_trace=false
    mac_deployment_target="12.0"
'

# Build for macOS ARM64
echo "Building ANGLE for macOS ARM64..."
gn gen out/mac-release-arm64 --args="
    target_os=\"mac\"
    target_cpu=\"arm64\"
    $COMMON_ARGS
"
ninja -C out/mac-release-arm64 libEGL libGLESv2

# Copy the dylibs to build directory
rm -rf ../build/mac/arm64/*
mkdir -p ../build/mac/arm64
cp -R out/mac-release-arm64/*.dylib ../build/mac/arm64/

# Build for macOS x86_64
echo "Building ANGLE for macOS x86_64..."
gn gen out/mac-release-x86_64 --args="
    target_os=\"mac\"
    target_cpu=\"x64\"
    $COMMON_ARGS
"
ninja -C out/mac-release-x86_64 libEGL libGLESv2

# Copy the dylibs to build directory
rm -rf ../build/mac/x86_64/*
mkdir -p ../build/mac/x86_64
cp -R out/mac-release-x86_64/*.dylib ../build/mac/x86_64/

# Create universal binaries
cd ..
echo "Creating universal binaries..."
rm -rf build/mac/universal/*
mkdir -p build/mac/universal

# Get a list of all dylibs from the arm64 build
DYLIBS=$(ls build/mac/arm64/)

# For each dylib, create a universal version
for DYLIB in $DYLIBS; do
    echo "Creating universal binary for $DYLIB..."

    # Create universal binary
    lipo -create -output "build/mac/universal/$DYLIB" \
        "build/mac/arm64/$DYLIB" \
        "build/mac/x86_64/$DYLIB"
done

# Copy headers for all architectures
echo "Copying headers..."

# Create header directories for each architecture
mkdir -p build/mac/arm64/include/{EGL,GLES2,GLES3,KHR}
mkdir -p build/mac/x86_64/include/{EGL,GLES2,GLES3,KHR}
mkdir -p build/mac/universal/include/{EGL,GLES2,GLES3,KHR}

# Copy headers to each architecture directory
cp -R angle/include/EGL/*.h build/mac/arm64/include/EGL/
cp -R angle/include/GLES2/*.h build/mac/arm64/include/GLES2/
cp -R angle/include/GLES3/*.h build/mac/arm64/include/GLES3/
cp -R angle/include/KHR/*.h build/mac/arm64/include/KHR/

cp -R angle/include/EGL/*.h build/mac/x86_64/include/EGL/
cp -R angle/include/GLES2/*.h build/mac/x86_64/include/GLES2/
cp -R angle/include/GLES3/*.h build/mac/x86_64/include/GLES3/
cp -R angle/include/KHR/*.h build/mac/x86_64/include/KHR/

cp -R angle/include/EGL/*.h build/mac/universal/include/EGL/
cp -R angle/include/GLES2/*.h build/mac/universal/include/GLES2/
cp -R angle/include/GLES3/*.h build/mac/universal/include/GLES3/
cp -R angle/include/KHR/*.h build/mac/universal/include/KHR/

echo "macOS builds complete! Libraries are available in:"
echo "  - build/mac/arm64 (for Apple Silicon Macs)"
echo "  - build/mac/x86_64 (for Intel Macs)"
echo "  - build/mac/universal (Universal binaries for both architectures)"
echo "Headers are included in the include directory within each build folder."