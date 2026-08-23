# 2026-08-23 Bugfix: Duplicate Subtitles & Seeking Deadlock

## Overview
Resolved two critical bugs:
1. Tripled/repeated dialogue lines in the dialogue waterfall overlay.
2. Player freeze and dialogue history corruption when clicking an earlier line to seek.

## Root Cause & Fix Details
1. **DOM Extraction Sanitization (`SubtitleScriptInjector.swift`)**:
   - Netflix renders duplicate styled text spans (for shadow/outline layers) inside `.player-timedtext-text-container`. The previous selector queried both the wrapper and the spans, concatenating all text together.
   - Refactored `extractCleanSubtitles()` to target distinct line containers, collect only leaf spans (with duplicate token filtering), normalize whitespace, and trim repeated phrases.
2. **Cadence API Seeking & FairPlay Deadlock Prevention (`SubtitleScriptInjector.swift`)**:
   - Removed direct HTML5 `<video>.currentTime = targetSeconds` assignments which stall FairPlay MSE video decryption pipelines.
   - Used Netflix's internal Cadence API (`api.videoPlayer.getVideoPlayerBySessionId(activeSessionId).seek(targetMs)`).
   - Hooked `seeking` and `seeked` events to notify Swift and temporarily gate mutation events.
3. **Timeline Re-anchoring (`AppState.swift`)**:
   - Implemented `handleSeeked(at:)` to prune downstream cues when seeking backward so history is not corrupted with out-of-order duplicate cues.

## Verification
- Bundled and installed release to `/Applications/Netflix.app`.
