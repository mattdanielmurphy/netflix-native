# Development Journal

- **2026-08-22 17:43**: Fixed programmatic AppKit initialization bug in `AppDelegate.swift` by implementing `static func main()`, setting `NSApplication.shared.delegate = delegate`, and calling `app.run()`.
- **2026-08-22 17:43**: Added `package.json` with scripts for `bun dev`, `bun start`, and `bun run build`. Configured `.gitignore` and ad-hoc code signing in `bin/build_and_bundle.sh`.
