#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
APP_BUNDLE="$PROJECT_ROOT/build/Netflix.app"

echo "🔨 Building NetflixNative binary..."
cd "$PROJECT_ROOT"
swift build -c release

echo "📦 Creating macOS App Bundle..."
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

cp "$PROJECT_ROOT/.build/release/NetflixNative" "$APP_BUNDLE/Contents/MacOS/NetflixNative"
cp "$PROJECT_ROOT/Resources/Info.plist" "$APP_BUNDLE/Contents/Info.plist"

# Copy icon if available
if [ -f "$PROJECT_ROOT/Resources/AppIcon.icns" ]; then
    cp "$PROJECT_ROOT/Resources/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
fi

# Ad-hoc code sign bundle for LaunchServices
codesign --force --deep --sign - "$APP_BUNDLE" 2>/dev/null || true
touch "$APP_BUNDLE"

DEST_APP="/Applications/Netflix.app"
echo "🚀 Installing to /Applications..."
if [ -d "$DEST_APP" ]; then
    mv "$DEST_APP" "$HOME/.Trash/Netflix_$(date +%s).app" 2>/dev/null || true
fi
cp -R "$APP_BUNDLE" "$DEST_APP"
codesign --force --deep --sign - "$DEST_APP" 2>/dev/null || true
touch "$DEST_APP"

echo "✅ Successfully built and installed: $DEST_APP"
