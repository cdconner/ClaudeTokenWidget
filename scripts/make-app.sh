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

echo "==> Building release binary…"
# Don't pass --arch: on Apple Silicon (both local and macos-14 runners) the
# default native build produces an arm64 binary. Passing --arch arm64
# explicitly can trip SwiftPM with "error: fatalError" on some toolchains.
swift build -c release

BIN_PATH=""
for candidate in \
    ".build/release/$EXECUTABLE" \
    ".build/arm64-apple-macosx/release/$EXECUTABLE"
do
    if [ -f "$candidate" ]; then
        BIN_PATH="$candidate"
        break
    fi
done
if [ -z "$BIN_PATH" ]; then
    echo "Error: could not locate built binary. .build tree:" >&2
    find .build -maxdepth 4 -name "$EXECUTABLE" >&2 || true
    exit 1
fi
echo "==> Found binary at $BIN_PATH"

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
