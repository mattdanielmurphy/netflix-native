# 2026-08-23 Auto-Subtitle Activation & On-Screen Visibility Toggle

## Overview
Added automatic background subtitle track activation so subtitles are captured for dialogue history even if the user has closed-caption subtitles turned off on the screen.

## Implementation Details
1. **`ensureSubtitlesActive()` (`SubtitleScriptInjector.swift`)**:
   - Queries `player.getTimedTextTracks()` and automatically activates the English/primary track via `player.setTimedTextTrack(selectedTrack)` whenever playing video.
2. **Independent On-Screen Visibility Toggling**:
   - Injects a dynamic CSS rule targeting `.player-timedtext` with `opacity: 0 !important;` when closed captions are hidden from view.
   - Subtitle DOM mutations continue firing and streaming into `AppState` and secondary displays.
   - Added hotkeys **`C`** and **`V`** to toggle whether subtitles are visibly shown on top of the video or hidden.

## Verification
- Rebuilt and installed to `/Applications/Netflix.app`.
