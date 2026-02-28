#!/usr/bin/env bash
# Submit a DMG (or .app / .zip) to Apple for notarization and staple the ticket.
#
# Uses App Store Connect API key — the recommended approach (no Apple ID / password needed).
#
# Usage:
#   scripts/notarize.sh <file> <key-id> <issuer-id> <path-to-p8-key>
#
# Arguments:
#   file         Path to the artifact to notarize (DMG recommended)
#   key-id       App Store Connect API key ID      (e.g. ABCDE12345)
#   issuer-id    App Store Connect issuer UUID
#   path-to-p8   Path to the .p8 private key file
#
set -euo pipefail

if [ $# -lt 4 ]; then
    echo "Usage: $0 <file> <key-id> <issuer-id> <path-to-p8>"
    exit 1
fi

FILE="$1"
KEY_ID="$2"
ISSUER_ID="$3"
KEY_PATH="$4"

if [ ! -f "$FILE" ]; then
    echo "Error: file not found: $FILE"
    exit 1
fi

echo "Submitting '$FILE' for notarization…"
xcrun notarytool submit "$FILE" \
    --key            "$KEY_PATH" \
    --key-id         "$KEY_ID" \
    --issuer         "$ISSUER_ID" \
    --wait \
    --timeout 30m

echo "Stapling notarization ticket to '$FILE'…"
xcrun stapler staple "$FILE"

echo "Notarization and stapling complete."
