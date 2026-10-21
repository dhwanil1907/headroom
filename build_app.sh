#!/bin/bash
# Builds a release binary and wraps it in Headroom.app (ad-hoc signed) in ./build.
set -euo pipefail
cd "$(dirname "$0")"
swift build -c release
APP=build/Headroom.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$(swift build -c release --show-bin-path)/Headroom" "$APP/Contents/MacOS/Headroom"
ICONSET="$(mktemp -d)/AppIcon.iconset"
swift Support/make_icon.swift "$ICONSET"
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"
cp Support/Info.plist "$APP/Contents/Info.plist"
codesign --force --sign - "$APP"
echo "Built $APP"
