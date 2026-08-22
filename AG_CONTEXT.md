# Netflix Native Context

- Native macOS WebKit wrapper app for Netflix built in Swift using AppKit + WKWebView.
- Targets macOS 13.0+ with modern Safari user-agent string for FairPlay & HEVC 4K playback.
- Nib-less architecture: AppDelegate and main event loop initialized programmatically without storyboards/XIBs.
- Custom window styling with darkAqua appearance, hidden titlebar, movable by window background, and fullscreen support.
- Build scripts located in `bin/build_and_bundle.sh` creating `.app` bundle at `build/Netflix.app`.
- Package scripts configured via `package.json` for Bun commands (`bun dev`, `bun start`, `bun run build`).
