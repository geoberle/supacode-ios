# SupacodeViewer — iOS Terminal Viewer

Native iOS app connecting to Supacode macOS via HTTP/WebSocket API.

## Stack

- SwiftUI, iOS 17+, iPhone + iPad
- SwiftTerm for terminal emulation
- URLSession for REST + WebSocket
- Network.framework for Bonjour discovery
- XcodeGen for project generation

## Build

```bash
make build     # generate + build
make run       # build + install + launch on simulator
make test      # run tests
make lint      # swiftlint
```

## Testing on Simulator

Build, install, and verify using the `ios-sim` skill or these steps:

```bash
xcodebuild -scheme SupacodeViewer -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' \
  -derivedDataPath .build/derived-data build 2>&1 | xcbeautify

xcrun simctl boot "iPad Pro 13-inch (M5)"
xcrun simctl install booted .build/derived-data/Build/Products/Debug-iphonesimulator/SupacodeViewer.app
xcrun simctl launch booted app.supabit.supacode.viewer

sleep 2
xcrun simctl io booted screenshot /tmp/ios-sim-screenshot.png
```

For UI interaction (tap, swipe, type), use the `ios-simulator` MCP tools.
For build/test/debug, use the `xcode` MCP tools.
Always screenshot after launch to verify changes visually.

## Project Generation

Source of truth is `project.yml`. The `.xcodeproj` is generated:

```bash
make generate   # or: xcodegen generate
```

Never edit `.xcodeproj` directly.
