#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

BUILD_DIR="$(pwd)/build"

echo "Building MyToday (Release)…"
xcodebuild \
    -project MyToday.xcodeproj \
    -scheme MyToday \
    -configuration Release \
    SYMROOT="$BUILD_DIR" \
    -quiet

APP_PATH="$BUILD_DIR/Release/MyToday.app"
if [ -d "$APP_PATH" ]; then
    echo "Build succeeded: $APP_PATH"
else
    echo "Build failed — .app not found at $APP_PATH"
    exit 1
fi
