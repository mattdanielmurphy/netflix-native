# Agent Log: Fix App Launch Entrypoint and Bun Scripts

- **Date**: 2026-08-22 17:43:00
- **Status**: Completed

## Root Cause
- In a nib-less / storyboard-less AppKit app, using `@main` on an `NSApplicationDelegate` class defaults to `NSApplicationMain()`, which searches `Info.plist` for `NSMainNibFile` to instantiate the delegate. Without a nib file specified, `NSApplication.shared.delegate` remained `nil`, so `applicationDidFinishLaunching` was never invoked and no window was instantiated or displayed.
- `package.json` was missing in the project root, causing `bun dev` and `bun start` to report `Script not found`.

## Changes Made
1. **`Sources/AppDelegate.swift`**:
   - Added explicit `static func main()` that instantiates `NSApplication.shared`, sets `app.delegate = delegate`, and runs `app.run()`.
   - Added `applicationShouldHandleReopen(_:hasVisibleWindows:)` to support reopening/unhiding windows from Dock.
   - Updated modern activation API call with fallback.
2. **`Sources/MainWindowController.swift`**:
   - Configured `window.isReleasedWhenClosed = false` and `window.center()`.
3. **`bin/build_and_bundle.sh`**:
   - Added ad-hoc code signing (`codesign --force --deep --sign -`) and bundle touch to force LaunchServices cache refresh.
4. **`package.json`**:
   - Added `dev`, `start`, and `build` scripts for Bun.
5. **`.gitignore` & `AG_CONTEXT.md`**:
   - Added `.gitignore` to avoid checking in `.build/` binary caches.
   - Created `AG_CONTEXT.md`.
