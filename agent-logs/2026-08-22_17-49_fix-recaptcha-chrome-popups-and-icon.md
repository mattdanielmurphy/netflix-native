# Agent Log: Fix Recaptcha/Tracking Browser Popups and Add Big Sur App Icon

- **Date**: 2026-08-22 17:49:00
- **Status**: Completed

## Issues Addressed
1. **Unintended External Browser Popups (Recaptcha / Analytics)**:
   - When loading `netflix.com`, subframes (reCAPTCHA iframes, Google/Arkose authentication beacons, analytics) were triggering `decidePolicyFor navigationAction`.
   - The policy checked only `host.contains("netflix.com")` and called `NSWorkspace.shared.open(url)` on any non-Netflix host, sending subframe URLs directly to Google Chrome.
2. **App Icon**:
   - Custom macOS Big Sur Netflix icon requested from `/Users/matt/Downloads/netflix_macos_bigsur_icon_189917.png`.

## Changes Made
1. **`Sources/WebViewController.swift`**:
   - Added `isInternalDomain` helper with domain matching for Netflix, Fast.com, Google/Recaptcha, and Arkose auth.
   - Guaranteed that subframes (`targetFrame?.isMainFrame == false`) always stay inside `WKWebView`.
   - Restricted `NSWorkspace.shared.open(url)` strictly to user-initiated clicks (`navigationAction.navigationType == .linkActivated`) on top-level frames pointing to external third-party websites.
2. **`Resources/AppIcon.icns` & `Resources/AppIcon.png`**:
   - Converted the PNG icon to full multi-resolution Apple ICNS format (16x16 through 1024x1024 Retina) using `sips` and `iconutil`.
   - Packaged and verified in `build/Netflix.app/Contents/Resources/AppIcon.icns`.
