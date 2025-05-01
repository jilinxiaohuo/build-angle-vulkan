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

# Common GN args for all iOS builds
COMMON_ARGS='
    is_debug=false
    ios_enable_code_signing=false
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
    ios_deployment_target="16.0"
'

# Build for iOS ARM64 (device)
echo "Building ANGLE for iOS ARM64 (device)..."
gn gen out/ios-release-arm64 --args="
    target_os=\"ios\"
    target_cpu=\"arm64\"
    target_environment=\"device\"
    $COMMON_ARGS
"
ninja -C out/ios-release-arm64 libEGL libGLESv2

# Copy the frameworks to build directory
rm -rf ../build/ios/arm64/*
mkdir -p ../build/ios/arm64
cp -R out/ios-release-arm64/*.framework ../build/ios/arm64/

# Build for iOS ARM64 Simulator
echo "Building ANGLE for iOS ARM64 Simulator..."
gn gen out/ios-release-simulator-arm64 --args="
    target_os=\"ios\"
    target_cpu=\"arm64\"
    target_environment=\"simulator\"
    $COMMON_ARGS
"
ninja -C out/ios-release-simulator-arm64 libEGL libGLESv2

# Copy the frameworks to build directory
rm -rf ../build/ios/simulator-arm64/*
mkdir -p ../build/ios/simulator-arm64
cp -R out/ios-release-simulator-arm64/*.framework ../build/ios/simulator-arm64/

# Build for iOS x86_64 Simulator
echo "Building ANGLE for iOS x86_64 Simulator..."
gn gen out/ios-release-simulator-x86_64 --args="
    target_os=\"ios\"
    target_cpu=\"x64\"
    target_environment=\"simulator\"
    $COMMON_ARGS
"
ninja -j 10 -k1 -C out/ios-release-simulator-x86_64 libEGL libGLESv2

# Copy the frameworks to build directory
rm -rf ../build/ios/simulator-x86_64/*
mkdir -p ../build/ios/simulator-x86_64
cp -R out/ios-release-simulator-x86_64/*.framework ../build/ios/simulator-x86_64/

cd ..

# Create XCFrameworks
echo "Creating XCFrameworks..."
mkdir -p build/ios/universal

# Get list of all frameworks from device build
FRAMEWORKS=$(ls build/ios/arm64/)

# Create XCFramework for each framework
for FRAMEWORK in $FRAMEWORKS; do
    echo "Creating XCFramework for $FRAMEWORK..."

    # Extract the base name without the .framework extension
    FRAMEWORK_BASE=$(basename "$FRAMEWORK" .framework)

    # Remove existing XCFrameworks if they exist
    rm -rf "build/ios/universal/$FRAMEWORK_BASE-simulator-x86_64.xcframework"
    rm -rf "build/ios/universal/$FRAMEWORK_BASE-simulator-arm64.xcframework"
    rm -rf "build/ios/universal/$FRAMEWORK_BASE.xcframework"

    # Create separate XCFrameworks because xcodebuild doesn't like bundling both ARM64 and x64 simulator binaries at once
    xcodebuild -create-xcframework \
        -framework "build/ios/arm64/$FRAMEWORK" \
        -framework "build/ios/simulator-arm64/$FRAMEWORK" \
        -output "build/ios/universal/$FRAMEWORK_BASE-simulator-arm64.xcframework"
    xcodebuild -create-xcframework \
        -framework "build/ios/arm64/$FRAMEWORK" \
        -framework "build/ios/simulator-x86_64/$FRAMEWORK" \
        -output "build/ios/universal/$FRAMEWORK_BASE-simulator-x86_64.xcframework"

    # Now manually merge the XCFrameworks to create one that supports all architectures
    echo "Manually merging XCFrameworks for $FRAMEWORK_BASE to create a unified version..."

    # Create a directory for the unified XCFramework
    UNIFIED_XCFRAMEWORK="build/ios/universal/$FRAMEWORK_BASE.xcframework"
    mkdir -p "$UNIFIED_XCFRAMEWORK"

    # Copy the device ARM64 framework
    ARM64_DIR=$(find "build/ios/universal/$FRAMEWORK_BASE-simulator-arm64.xcframework" -name "ios-arm64" -type d)
    cp -R "$ARM64_DIR" "$UNIFIED_XCFRAMEWORK/"

    # Copy the simulator ARM64 framework
    SIM_ARM64_DIR=$(find "build/ios/universal/$FRAMEWORK_BASE-simulator-arm64.xcframework" -name "ios-arm64-simulator" -type d)
    cp -R "$SIM_ARM64_DIR" "$UNIFIED_XCFRAMEWORK/"

    # Copy the simulator x86_64 framework
    SIM_X86_64_DIR=$(find "build/ios/universal/$FRAMEWORK_BASE-simulator-x86_64.xcframework" -name "ios-*-simulator" -type d | grep -v arm64)
    cp -R "$SIM_X86_64_DIR" "$UNIFIED_XCFRAMEWORK/"

    # Now create a proper merged Info.plist using PlistBuddy
    echo "Creating merged Info.plist for $FRAMEWORK_BASE.xcframework..."

    # Create a temporary directory
    TEMP_DIR=$(mktemp -d)
    TEMP_PLIST="$TEMP_DIR/Info.plist"

    # Create a new empty plist file
    /usr/libexec/PlistBuddy -c "Save" "$TEMP_PLIST"

    # Initialize the plist with required structure
    /usr/libexec/PlistBuddy -c "Add :CFBundlePackageType string XFWK" "$TEMP_PLIST"
    /usr/libexec/PlistBuddy -c "Add :XCFrameworkFormatVersion string 1.0" "$TEMP_PLIST"
    /usr/libexec/PlistBuddy -c "Add :AvailableLibraries array" "$TEMP_PLIST"

    # Add device ARM64 library info - get from the simulator-arm64 xcframework
    ARM64_PLIST="build/ios/universal/$FRAMEWORK_BASE-simulator-arm64.xcframework/Info.plist"
    COUNTER=0

    # Add the device ARM64 entry (index 0 in the arm64 xcframework)
    /usr/libexec/PlistBuddy -c "Add :AvailableLibraries:$COUNTER dict" "$TEMP_PLIST"
    /usr/libexec/PlistBuddy -c "Add :AvailableLibraries:$COUNTER:LibraryIdentifier string ios-arm64" "$TEMP_PLIST"
    FRAMEWORK_PATH=$(/usr/libexec/PlistBuddy -c "Print :AvailableLibraries:0:LibraryPath" "$ARM64_PLIST")
    BINARY_PATH=$(/usr/libexec/PlistBuddy -c "Print :AvailableLibraries:0:BinaryPath" "$ARM64_PLIST")
    /usr/libexec/PlistBuddy -c "Add :AvailableLibraries:$COUNTER:LibraryPath string $FRAMEWORK_PATH" "$TEMP_PLIST"
    /usr/libexec/PlistBuddy -c "Add :AvailableLibraries:$COUNTER:BinaryPath string $BINARY_PATH" "$TEMP_PLIST"
    /usr/libexec/PlistBuddy -c "Add :AvailableLibraries:$COUNTER:SupportedPlatform string ios" "$TEMP_PLIST"
    /usr/libexec/PlistBuddy -c "Add :AvailableLibraries:$COUNTER:SupportedArchitectures array" "$TEMP_PLIST"
    /usr/libexec/PlistBuddy -c "Add :AvailableLibraries:$COUNTER:SupportedArchitectures:0 string arm64" "$TEMP_PLIST"

    # Add simulator ARM64 library info
    COUNTER=$((COUNTER+1))
    /usr/libexec/PlistBuddy -c "Add :AvailableLibraries:$COUNTER dict" "$TEMP_PLIST"
    /usr/libexec/PlistBuddy -c "Add :AvailableLibraries:$COUNTER:LibraryIdentifier string ios-arm64-simulator" "$TEMP_PLIST"
    FRAMEWORK_PATH=$(/usr/libexec/PlistBuddy -c "Print :AvailableLibraries:1:LibraryPath" "$ARM64_PLIST")
    BINARY_PATH=$(/usr/libexec/PlistBuddy -c "Print :AvailableLibraries:1:BinaryPath" "$ARM64_PLIST")
    /usr/libexec/PlistBuddy -c "Add :AvailableLibraries:$COUNTER:LibraryPath string $FRAMEWORK_PATH" "$TEMP_PLIST"
    /usr/libexec/PlistBuddy -c "Add :AvailableLibraries:$COUNTER:BinaryPath string $BINARY_PATH" "$TEMP_PLIST"
    /usr/libexec/PlistBuddy -c "Add :AvailableLibraries:$COUNTER:SupportedPlatform string ios" "$TEMP_PLIST"
    /usr/libexec/PlistBuddy -c "Add :AvailableLibraries:$COUNTER:SupportedPlatformVariant string simulator" "$TEMP_PLIST"
    /usr/libexec/PlistBuddy -c "Add :AvailableLibraries:$COUNTER:SupportedArchitectures array" "$TEMP_PLIST"
    /usr/libexec/PlistBuddy -c "Add :AvailableLibraries:$COUNTER:SupportedArchitectures:0 string arm64" "$TEMP_PLIST"

    # Add simulator x86_64 library info - get from the simulator-x86_64 xcframework
    X86_64_PLIST="build/ios/universal/$FRAMEWORK_BASE-simulator-x86_64.xcframework/Info.plist"
    COUNTER=$((COUNTER+1))

    # Find the simulator slice (index 1)
    SIM_INDEX=1

    /usr/libexec/PlistBuddy -c "Add :AvailableLibraries:$COUNTER dict" "$TEMP_PLIST"
    /usr/libexec/PlistBuddy -c "Add :AvailableLibraries:$COUNTER:LibraryIdentifier string ios-x86_64-simulator" "$TEMP_PLIST"
    FRAMEWORK_PATH=$(/usr/libexec/PlistBuddy -c "Print :AvailableLibraries:$SIM_INDEX:LibraryPath" "$X86_64_PLIST")
    BINARY_PATH=$(/usr/libexec/PlistBuddy -c "Print :AvailableLibraries:$SIM_INDEX:BinaryPath" "$X86_64_PLIST")
    /usr/libexec/PlistBuddy -c "Add :AvailableLibraries:$COUNTER:LibraryPath string $FRAMEWORK_PATH" "$TEMP_PLIST"
    /usr/libexec/PlistBuddy -c "Add :AvailableLibraries:$COUNTER:BinaryPath string $BINARY_PATH" "$TEMP_PLIST"
    /usr/libexec/PlistBuddy -c "Add :AvailableLibraries:$COUNTER:SupportedPlatform string ios" "$TEMP_PLIST"
    /usr/libexec/PlistBuddy -c "Add :AvailableLibraries:$COUNTER:SupportedPlatformVariant string simulator" "$TEMP_PLIST"
    /usr/libexec/PlistBuddy -c "Add :AvailableLibraries:$COUNTER:SupportedArchitectures array" "$TEMP_PLIST"
    /usr/libexec/PlistBuddy -c "Add :AvailableLibraries:$COUNTER:SupportedArchitectures:0 string x86_64" "$TEMP_PLIST"

    # Copy the properly formatted plist to the unified XCFramework
    cp "$TEMP_PLIST" "$UNIFIED_XCFRAMEWORK/Info.plist"

    # Add flattened headers to each framework slice
    for SLICE_DIR in "$UNIFIED_XCFRAMEWORK"/*; do
        if [ -d "$SLICE_DIR" ]; then
            FRAMEWORK_DIR=$(find "$SLICE_DIR" -name "*.framework" -type d)
            if [ -n "$FRAMEWORK_DIR" ]; then
                HEADERS_DIR_TARGET="$FRAMEWORK_DIR/Headers"
                mkdir -p "$HEADERS_DIR_TARGET"

                # Copy appropriate headers based on framework name (flattened structure)
                if [[ "$FRAMEWORK_BASE" == "libEGL" ]]; then
                    cp -R angle/include/EGL/*.h "$HEADERS_DIR_TARGET/"
                    cp -R angle/include/KHR/*.h "$HEADERS_DIR_TARGET/"
                elif [[ "$FRAMEWORK_BASE" == "libGLESv2" ]]; then
                    cp -R angle/include/GLES2/*.h "$HEADERS_DIR_TARGET/"
                    cp -R angle/include/GLES3/*.h "$HEADERS_DIR_TARGET/"
                    cp -R angle/include/KHR/*.h "$HEADERS_DIR_TARGET/"
                fi

                echo "Added headers to $FRAMEWORK_DIR"
            fi
        fi
    done

    # Clean up
    rm -rf "$TEMP_DIR"
    rm -rf "build/ios/universal/$FRAMEWORK_BASE-simulator-x86_64.xcframework"
    rm -rf "build/ios/universal/$FRAMEWORK_BASE-simulator-arm64.xcframework"

    echo "Created unified XCFramework with headers: $UNIFIED_XCFRAMEWORK"
done

# Create a standard include directory structure alongside the XCFrameworks
echo "Creating standard include directory structure..."
mkdir -p build/ios/universal/include/EGL
mkdir -p build/ios/universal/include/GLES2
mkdir -p build/ios/universal/include/GLES3
mkdir -p build/ios/universal/include/KHR

# Copy headers to the standard include structure
cp -R angle/include/EGL/*.h build/ios/universal/include/EGL/
cp -R angle/include/GLES2/*.h build/ios/universal/include/GLES2/
cp -R angle/include/GLES3/*.h build/ios/universal/include/GLES3/
cp -R angle/include/KHR/*.h build/ios/universal/include/KHR/

# Create a README in the include directory explaining usage
cat > "build/ios/universal/include/README.md" << EOL
# ANGLE Headers for iOS

These headers are organized in a standard structure for cross-platform consistency.

## Usage in Cross-Platform Code

For cross-platform code that needs to compile on multiple platforms (Windows, macOS, iOS),
include these headers as follows:

\`\`\`c
#include <EGL/egl.h>
#include <GLES2/gl2.h>
\`\`\`

## Integration with Xcode

1. Add this include directory to your Header Search Paths
2. Link against the ANGLE XCFrameworks (libEGL.xcframework and libGLESv2.xcframework)

## Alternative Usage for iOS-only Code

For iOS-only code, you can also use the framework-style includes:

\`\`\`objc
#import <libEGL/egl.h>
#import <libGLESv2/gl2.h>
\`\`\`

Both approaches will work, but the first is recommended for cross-platform consistency.
EOL

echo "iOS builds complete! Frameworks are available in:"
echo "  - build/ios/arm64 (for iOS devices)"
echo "  - build/ios/simulator-arm64 (for ARM64 simulators)"
echo "  - build/ios/simulator-x86_64 (for x86_64 simulators)"
echo "  - build/ios/universal (XCFrameworks for all platforms)"
echo "Headers are available in two formats:"
echo "  - Standard include structure: build/ios/universal/include/"
echo "  - Framework-embedded headers: inside each XCFramework"