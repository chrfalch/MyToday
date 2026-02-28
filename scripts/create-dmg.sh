#!/usr/bin/env bash
# Package the exported MyToday.app into a distributable DMG.
#
# Usage:
#   scripts/create-dmg.sh [output-name.dmg]
#
# Inputs:
#   build/export/MyToday.app   – produced by scripts/archive.sh
#
# Output:
#   build/<output-name.dmg>    – default: build/MyToday.dmg
#
set -euo pipefail
cd "$(dirname "$0")/.."

APP_PATH="build/export/MyToday.app"
DMG_NAME="${1:-MyToday.dmg}"
DMG_PATH="build/$DMG_NAME"
STAGING_DIR="build/dmg-staging"
VOLUME_NAME="MyToday"

if [ ! -d "$APP_PATH" ]; then
    echo "Error: $APP_PATH not found. Run scripts/archive.sh first."
    exit 1
fi

echo "Creating DMG: $DMG_PATH"

# ── Prepare staging folder ────────────────────────────────────────────────────
rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR"
cp -R "$APP_PATH" "$STAGING_DIR/"

# Symlink to /Applications for drag-install UX
ln -s /Applications "$STAGING_DIR/Applications"

# ── Create read/write image ───────────────────────────────────────────────────
TMP_DMG="build/tmp-rw.dmg"
hdiutil create \
    -volname "$VOLUME_NAME" \
    -srcfolder "$STAGING_DIR" \
    -ov -format UDRW \
    "$TMP_DMG"

# ── Convert to compressed, read-only final DMG ────────────────────────────────
rm -f "$DMG_PATH"
hdiutil convert "$TMP_DMG" \
    -format UDZO \
    -imagekey zlib-level=9 \
    -o "$DMG_PATH"

rm -f "$TMP_DMG"
rm -rf "$STAGING_DIR"

echo "DMG created: $DMG_PATH ($(du -sh "$DMG_PATH" | cut -f1))"
