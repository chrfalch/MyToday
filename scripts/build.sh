#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

BUILD_DIR="$(pwd)/build"

echo "Building MyToday (Release)…"

# In CI there are no signing certificates, so disable code signing.
# Local builds use the project's signing settings as normal.
if [ "${CI:-}" = "true" ]; then
    SIGNING_FLAGS=(
        CODE_SIGNING_REQUIRED=NO
        CODE_SIGN_IDENTITY=""
        CODE_SIGNING_ALLOWED=NO
    )
else
    SIGNING_FLAGS=()
fi

xcodebuild \
    -project MyToday.xcodeproj \
    -scheme MyToday \
    -configuration Release \
    SYMROOT="$BUILD_DIR" \
    "${SIGNING_FLAGS[@]}" \
    -quiet

APP_PATH="$BUILD_DIR/Release/MyToday.app"
if [ -d "$APP_PATH" ]; then
    echo "Build succeeded: $APP_PATH"
else
    echo "Build failed — .app not found at $APP_PATH"
    exit 1
fi
