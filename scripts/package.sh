#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

BUILD_DIR="$(pwd)/build"
APP_PATH="$BUILD_DIR/Release/MyToday.app"

# Build the app first
bash scripts/build.sh

# Read metadata from the built bundle
PLIST="$APP_PATH/Contents/Info.plist"
VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$PLIST")
BUILD=$(/usr/libexec/PlistBuddy -c "Print CFBundleVersion" "$PLIST")
IDENTIFIER=$(/usr/libexec/PlistBuddy -c "Print CFBundleIdentifier" "$PLIST")

PKG_PATH="$BUILD_DIR/MyToday-${VERSION}.pkg"

echo "Packaging MyToday ${VERSION} (build ${BUILD})…"

# Stage into a temp directory that mirrors /Applications
STAGE_DIR="$(mktemp -d)"
trap "rm -rf '$STAGE_DIR'" EXIT

mkdir -p "$STAGE_DIR/Applications"
cp -R "$APP_PATH" "$STAGE_DIR/Applications/"

pkgbuild \
    --root "$STAGE_DIR" \
    --identifier "$IDENTIFIER" \
    --version "$VERSION" \
    --install-location "/" \
    "$PKG_PATH"

echo "Package created: $PKG_PATH"
