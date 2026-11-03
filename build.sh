#!/bin/bash
# Builds build/NotchFocus.app with the Command Line Tools. Pass --run to launch it.
set -euo pipefail
cd "$(dirname "$0")"

APP=build/NotchFocus.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

swiftc -O -swift-version 5 \
    -target "$(uname -m)-apple-macos14.0" \
    Sources/*.swift \
    -o "$APP/Contents/MacOS/NotchFocus"

cp Info.plist "$APP/Contents/Info.plist"
codesign --force --sign - "$APP" >/dev/null

echo "Built $APP"

if [[ "${1:-}" == "--run" ]]; then
    pkill -x NotchFocus 2>/dev/null || true
    open "$APP"
fi
