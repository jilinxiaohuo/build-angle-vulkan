# build-angle

Scripts to build Google ANGLE binaries for iOS (Metal), macOS (Metal), and Windows (D3D11).

## Prebuilt Binaries

Check the [Releases](https://github.com/jeremyfa/build-angle/releases) page for prebuilt binaries. New releases are automatically created when a new ANGLE commit is detected by the daily build workflow.

## Building from Source

### iOS

Build from macOS:

```bash
./build-angle-ios.sh
```

This will generate universal `libEGL.xcframework` and `libGLESv2.xcframework` for iOS devices (arm64) and simulator (arm64 + x86_64), configured to use Metal as backend.

Output will be in `build/ios/universal/`.

### macOS

Build from macOS:

```bash
./build-angle-mac.sh
```

This will generate universal `libEGL.dylib` and `libGLESv2.dylib` binaries (arm64 + x86_64), configured to use Metal as backend.

Output will be in `build/mac/universal/lib/` and `build/mac/universal/include/`.

### Windows

Build from Windows:

```bash
./build-angle-windows.bat
```

This will generate Windows binaries for ARM64 and x64, configured to use D3D11 as backend.

Output will be in:
- `build/windows/x64/bin/` - DLLs
- `build/windows/x64/lib/` - Import libraries
- `build/windows/x64/include/` - Headers

And similarly for ARM64.

## Specifying Custom Commits

By default, the build scripts will use the latest commit from ANGLE and depot_tools. If you want to use specific commits, set the following environment variables:

```bash
# macOS/Linux
export ANGLE_COMMIT=your-specific-commit-hash
export DEPOT_TOOLS_COMMIT=your-specific-depot-tools-hash
./build-angle-mac.sh  # or build-angle-ios.sh
```

```bat
:: Windows
set ANGLE_COMMIT=your-specific-commit-hash
set DEPOT_TOOLS_COMMIT=your-specific-depot-tools-hash
build-angle-windows.bat
```

## Cleaning up

To remove all downloaded and built files:

```bash
./clean-angle.sh
```

## Automated Builds

This repository uses GitHub Actions to automatically build ANGLE binaries:
- On every push to main that changes the build scripts
- Every 24 hours (to pick up new ANGLE commits)
- When manually triggered via workflow_dispatch

When a new ANGLE commit is detected, a new GitHub Release is automatically created with the binaries for all platforms.