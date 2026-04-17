#!/usr/bin/env bash
# Package the .app bundle into a DMG with a drag-to-Applications layout.
# Usage: VERSION=0.1.0 ./scripts/make-dmg.sh
set -euo pipefail

cd "$(dirname "$0")/.."

DISPLAY_NAME="Claude Token Widget"
VERSION="${VERSION:-0.0.0-dev}"
BUILD_DIR="build"
APP_DIR="$BUILD_DIR/$DISPLAY_NAME.app"
DMG_PATH="$BUILD_DIR/ClaudeTokenWidget-$VERSION.dmg"
STAGING="$BUILD_DIR/dmg-staging"

if [ ! -d "$APP_DIR" ]; then
    echo "Error: $APP_DIR not found. Run scripts/make-app.sh first." >&2
    exit 1
fi

echo "==> Staging DMG contents..."
rm -rf "$STAGING"
mkdir -p "$STAGING"
cp -R "$APP_DIR" "$STAGING/"
ln -s /Applications "$STAGING/Applications"

echo "==> Creating DMG at $DMG_PATH ..."
rm -f "$DMG_PATH"
hdiutil create \
    -volname "$DISPLAY_NAME" \
    -srcfolder "$STAGING" \
    -ov -format UDZO \
    "$DMG_PATH" >/dev/null

rm -rf "$STAGING"

SIZE=$(du -h "$DMG_PATH" | cut -f1)
echo "==> Done."
echo "    DMG: $DMG_PATH ($SIZE)"
