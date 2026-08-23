# 2026-08-23 Subtitle Streaming and Dialogue Waterfall Integration

## Overview
Revived and integrated real-time Netflix subtitle extraction and remote playback control into `netflix-native`. Added a native Mac "dialogue waterfall" overlay and an embedded zero-configuration HTTP/WebSocket server for secondary displays.

## Changes
1. **`SubtitleModels.swift`**: Defined data structures for subtitle cues, player snapshots, server messages, and client commands.
2. **`SubtitleScriptInjector.swift`**: JavaScript injector attaching a `MutationObserver` to Netflix subtitle containers (`.player-timedtext`, `.timed-text-container`), synchronizing with HTML5 video timestamps, and exposing `__netflixNativeSeek(seconds)`. Added scroll-up gesture and `D` key detection to toggle the waterfall view.
3. **`SubtitleStreamBridge.swift`**: `WKScriptMessageHandler` routing cues and commands between JavaScript and Swift.
4. **`DialogueOverlayView.swift`**: SwiftUI/AppKit translucent glassmorphic overlay for scrolling recent dialogue, real-time filtering/search, and 1-click seeking.
5. **`EmbeddedHTTPServer.swift`**: Native `NWListener` server hosting `SecondaryDisplayClient.html` and streaming WebSocket frames with Bonjour advertisement (`_netflixsub._tcp`).
6. **`SecondaryDisplayClient.html`**: Mobile and tablet-optimized dark-mode web application for viewing the live subtitle stream and remotely seeking playback.
7. **`WebViewController.swift` & `AppDelegate.swift`**: Integrated overlay view lifecycle, menu items (`⌘⇧D` for Dialogue Waterfall, and browser client opener), and local server auto-start.

## Verification
- Built and bundled release binary with `bin/build_and_bundle.sh` -> verified successful compile and installation to `/Applications/Netflix.app`.
