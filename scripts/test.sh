#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

echo "Running tests…"
swift test 2>&1

if [ $? -eq 0 ]; then
    echo "All tests passed."
else
    echo "Tests failed."
    exit 1
fi
