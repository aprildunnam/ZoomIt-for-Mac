#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="ZoomIt for Mac"
BUILD_DIR="$SCRIPT_DIR/.build"
APP_BUNDLE="$SCRIPT_DIR/$APP_NAME.app"

echo "🔨 Building ZoomIt for Mac…"

# Build with Swift Package Manager
cd "$SCRIPT_DIR"
swift build -c release 2>&1

EXECUTABLE="$BUILD_DIR/release/ZoomItMac"

if [ ! -f "$EXECUTABLE" ]; then
    echo "❌ Build failed - executable not found"
    exit 1
fi

echo "📦 Creating app bundle..."

# Create .app bundle structure
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# Copy executable
cp "$EXECUTABLE" "$APP_BUNDLE/Contents/MacOS/ZoomItMac"

# Copy Info.plist
cp "$SCRIPT_DIR/Sources/Info.plist" "$APP_BUNDLE/Contents/Info.plist"

# Create PkgInfo
echo -n "APPL????" > "$APP_BUNDLE/Contents/PkgInfo"

# Try to sign with a developer identity so TCC permissions persist across rebuilds.
# Falls back to ad-hoc signing if no developer certificate is available.
DEV_IDENTITY=$(security find-identity -v -p codesigning 2>/dev/null | grep -m1 'Apple Development\|Developer ID' | sed 's/.*"\(.*\)"/\1/')
if [ -n "$DEV_IDENTITY" ]; then
    echo "🔑 Signing with: $DEV_IDENTITY"
    codesign --force --deep --sign "$DEV_IDENTITY" "$APP_BUNDLE" 2>/dev/null || \
    codesign --force --deep --sign - "$APP_BUNDLE" 2>/dev/null || true
else
    echo "🔑 No developer certificate found, using ad-hoc signing"
    echo "   (Screen Recording permission may reset on each rebuild)"
    codesign --force --deep --sign - "$APP_BUNDLE" 2>/dev/null || true
fi

echo "✅ Build complete!"
echo "📍 App bundle: $APP_BUNDLE"
echo ""
echo "To run:  open \"$APP_BUNDLE\""
echo "To install: cp -r \"$APP_BUNDLE\" /Applications/"
