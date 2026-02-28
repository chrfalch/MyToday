#!/usr/bin/env bash
# Bump the marketing version and build number in Info.plist.
#
# Usage:
#   scripts/version.sh --marketing 1.2.3 [--build 42]
#   scripts/version.sh --marketing 1.2.3           # build number unchanged
#
# Options:
#   --marketing VERSION   CFBundleShortVersionString (e.g. 1.2.3)
#   --build     NUMBER    CFBundleVersion            (e.g. 42)
#   --tag                 Also create a git tag vVERSION and push it
#
set -euo pipefail
cd "$(dirname "$0")/.."

MARKETING_VERSION=""
BUILD_NUMBER=""
CREATE_TAG=false

# ── Parse arguments ──────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
    case "$1" in
        --marketing) MARKETING_VERSION="$2"; shift 2 ;;
        --build)     BUILD_NUMBER="$2";      shift 2 ;;
        --tag)       CREATE_TAG=true;        shift   ;;
        *) echo "Unknown argument: $1"; exit 1 ;;
    esac
done

if [ -z "$MARKETING_VERSION" ]; then
    echo "Error: --marketing VERSION is required"
    exit 1
fi

PLIST="Info.plist"

# ── Update Info.plist ─────────────────────────────────────────────────────────
echo "Setting marketing version → $MARKETING_VERSION"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $MARKETING_VERSION" "$PLIST"

if [ -n "$BUILD_NUMBER" ]; then
    echo "Setting build number → $BUILD_NUMBER"
    /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD_NUMBER" "$PLIST"
fi

echo "Version updated in $PLIST"

# ── Create git tag ────────────────────────────────────────────────────────────
if [ "$CREATE_TAG" = true ]; then
    TAG="v$MARKETING_VERSION"
    echo "Creating git tag $TAG…"
    git add "$PLIST"
    git commit -m "chore: bump version to $MARKETING_VERSION"
    git tag -a "$TAG" -m "Release $TAG"
    echo "Pushing tag $TAG…"
    git push origin "$TAG"
    echo "Tag $TAG pushed. The Release workflow will start automatically."
fi
