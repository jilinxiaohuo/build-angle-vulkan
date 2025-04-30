# build-angle

Scripts to build Google ANGLE binaries

## iOS

Build from Mac:

```
./build-angle-ios.sh
```

This will generate universal `libEGL.xcframework` and `libGLESv2.xcframework` for iOS devices (arm64) and simulator (arm64 + x86_64), configured to use Metal as backend.

## Mac

Build from Mac:

```
./build-angle-mac.sh
```

This will generate universal `libEGL.dylib` and `libGLESv2.dylib` binaries (arm64 + x86_64), configured to use Metal as backend.

## Windows

⚠️ Just a draft for now, not tested yet!

Build from Windows:

```
./build-angle-windows.bat
```

This will generate windows binaries for ARM64 and x64, configured to use D3D11 as backend.
