#!/usr/bin/env bash
# Build a double-clickable .app bundle from the Swift package.
# Usage: VERSION=0.1.0 ./scripts/make-app.sh
set -euo pipefail

cd "$(dirname "$0")/.."

EXECUTABLE="ClaudeTokenWidget"
DISPLAY_NAME="Claude Token Widget"
VERSION="${VERSION:-0.0.0-dev}"
BUILD_DIR="build"
APP_DIR="$BUILD_DIR/$DISPLAY_NAME.app"

echo "==> Building release binary (arm64)…"
swift build -c release --arch arm64

BIN_PATH=".build/arm64-apple-macosx/release/$EXECUTABLE"
if [ ! -f "$BIN_PATH" ]; then
    BIN_PATH=".build/release/$EXECUTABLE"
fi
if [ ! -f "$BIN_PATH" ]; then
    echo "Error: binary not found at $BIN_PATH" >&2
    exit 1
fi

echo "==> Assembling .app bundle at $APP_DIR…"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

cp "$BIN_PATH" "$APP_DIR/Contents/MacOS/$EXECUTABLE"
chmod +x "$APP_DIR/Contents/MacOS/$EXECUTABLE"

sed "s/__VERSION__/$VERSION/g" resources/Info.plist > "$APP_DIR/Contents/Info.plist"

echo "==> Ad-hoc codesigning…"
codesign --force --deep --sign - --options runtime "$APP_DIR"

echo "==> Verifying signature…"
codesign --verify --verbose=2 "$APP_DIR"

echo "==> Done."
echo "    App: $APP_DIR"
echo "    Version: $VERSION"
