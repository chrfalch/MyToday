#!/usr/bin/env bash
# Build an Xcode archive and export it for Developer ID distribution.
#
# Usage:
#   scripts/archive.sh
#
# Outputs:
#   build/MyToday.xcarchive   – raw Xcode archive
#   build/export/MyToday.app  – signed, exported app bundle
#
set -euo pipefail
cd "$(dirname "$0")/.."

PROJECT="MyToday.xcodeproj"
SCHEME="MyToday"
ARCHIVE_PATH="build/MyToday.xcarchive"
EXPORT_PATH="build/export"
EXPORT_OPTIONS="ExportOptions.plist"

mkdir -p build

echo "Archiving $SCHEME…"
xcodebuild archive \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration Release \
    -archivePath "$ARCHIVE_PATH" \
    -destination "generic/platform=macOS" \
    CODE_SIGN_STYLE=Automatic \
    -quiet

if [ ! -d "$ARCHIVE_PATH" ]; then
    echo "Archive failed — $ARCHIVE_PATH not found"
    exit 1
fi
echo "Archive created: $ARCHIVE_PATH"

echo "Exporting archive…"
xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportOptionsPlist "$EXPORT_OPTIONS" \
    -exportPath "$EXPORT_PATH" \
    -quiet

APP_PATH="$EXPORT_PATH/MyToday.app"
if [ ! -d "$APP_PATH" ]; then
    echo "Export failed — $APP_PATH not found"
    exit 1
fi
echo "Export succeeded: $APP_PATH"
