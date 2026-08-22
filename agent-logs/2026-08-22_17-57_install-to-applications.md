# Agent Log: Automatically Install App to /Applications on Build

- **Date**: 2026-08-22 17:57:00
- **Status**: Completed

## Changes Made
1. **`bin/build_and_bundle.sh`**:
   - Added automated installation step copying the built and ad-hoc signed app bundle directly to `/Applications/Netflix.app`.
   - Safely moves any pre-existing `/Applications/Netflix.app` to `~/.Trash/` before installation.
   - Refreshes bundle timestamps and ad-hoc codesigning for `/Applications/Netflix.app`.
2. **`package.json`**:
   - Updated `dev` and `start` scripts to launch `/Applications/Netflix.app`.
