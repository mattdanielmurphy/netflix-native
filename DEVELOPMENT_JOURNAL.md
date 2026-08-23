# Development Journal

- **2026-08-22 17:43**: Fixed programmatic AppKit initialization bug in `AppDelegate.swift` by implementing `static func main()`, setting `NSApplication.shared.delegate = delegate`, and calling `app.run()`.
- **2026-08-22 17:43**: Added `package.json` with scripts for `bun dev`, `bun start`, and `bun run build`. Configured `.gitignore` and ad-hoc code signing in `bin/build_and_bundle.sh`.
- **2026-08-22 17:49**: Fixed external browser popups by restricting `NSWorkspace.shared.open` in `WebViewController.swift` strictly to user `.linkActivated` clicks on main frames, whitelisting captcha/tracking subframes. Generated and integrated Big Sur app icon (`Resources/AppIcon.icns`).
- **2026-08-22 17:53**: Silenced macOS system alert sound on Spacebar/media keys by creating custom `MainWindow: NSWindow` subclass overriding `keyDown` to absorb unhandled media keys, and injected a `WKUserScript` DOM listener to toggle play/pause and prevent scroll.
- **2026-08-22 17:57**: Updated `bin/build_and_bundle.sh` to automatically install `Netflix.app` to `/Applications/Netflix.app` upon build completion, safely trashing any preexisting version, and updated `package.json` scripts.
- **2026-08-22 18:04**: Created public GitHub repository (`mattdanielmurphy/netflix-native`), added MIT license, and published comprehensive README with 4K requirements warning, feature breakdown, keyboard shortcuts, and 1-line installation instructions.
- **2026-08-23 01:08**: Implemented real-time subtitle extraction, Mac dialogue waterfall HUD overlay (with search and click-to-seek via `⌘⇧D` / `D` / scroll-up), and an embedded zero-dependency local HTTP/WebSocket streaming server (`EmbeddedHTTPServer.swift` using `NWListener`) with Bonjour LAN auto-discovery and bundled mobile client (`SecondaryDisplayClient.html`).
- **2026-08-23 01:30**: Fixed tripled/repeated subtitle lines by sanitizing DOM extraction to target distinct visual line containers and leaf text nodes. Fixed player freezing and history corruption on seek by using Netflix's Cadence `videoPlayer.seek()` API (removing `<video>.currentTime` mutations) and adding `handleSeeked` timeline re-anchoring in `AppState`.


