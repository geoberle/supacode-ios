---
name: ios-sim
description: Build, install, launch, and screenshot the iOS app on the simulator for visual verification. Use when asked to run the app, verify a UI change, test on simulator, or take a screenshot.
---

# iOS Simulator Skill

Build and visually verify iOS app changes using the simulator and MCP tools.

## MCP Servers Available

- **`xcode`** — Xcode native MCP bridge (`xcrun mcpbridge`). Build, test, debug, LLDB.
- **`ios-simulator`** — iOS Simulator MCP (`ios-simulator-mcp`). Tap, swipe, type, screenshot, UI hierarchy.

Before first use in a session, discover available tools:
```
ToolSearch: select:xcode
ToolSearch: select:ios-simulator
```

## Workflow

### 1. Build

```bash
make build
```

Or directly:
```bash
xcodebuild -scheme SupacodeViewer -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' \
  -derivedDataPath .build/derived-data build 2>&1 | xcbeautify
```

### 2. Install and launch

```bash
make run
```

Or directly:
```bash
xcrun simctl boot "iPad Pro 13-inch (M5)" 2>/dev/null || true
xcrun simctl install booted .build/derived-data/Build/Products/Debug-iphonesimulator/SupacodeViewer.app
xcrun simctl terminate booted app.supabit.supacode.viewer 2>/dev/null || true
xcrun simctl launch booted app.supabit.supacode.viewer
```

### 3. Screenshot and verify

```bash
sleep 2
xcrun simctl io booted screenshot /tmp/ios-sim-screenshot.png
```

Read the screenshot with the Read tool to visually inspect.

### 4. UI interaction (via ios-simulator MCP)

Use MCP tools for tap, swipe, type, UI hierarchy inspection.

## Notes

- `.build/` is in `.gitignore`
- Fix build errors before proceeding to install
- Always screenshot after launch to verify
- Prefer MCP tools for interaction; XCUITests for complex flows
