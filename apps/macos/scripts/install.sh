#!/usr/bin/env bash
# Builds Blink in Release mode and installs it into /Applications.
set -euo pipefail

cd "$(dirname "$0")/.."

BUILD_DIR="build"
APP="$BUILD_DIR/Build/Products/Release/Blink.app"
DEST="${INSTALL_DIR:-/Applications}/Blink.app"

xcodebuild \
  -project Blink.xcodeproj \
  -scheme Blink \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -derivedDataPath "$BUILD_DIR" \
  -quiet \
  build

osascript -e 'quit app "Blink"' 2>/dev/null || true
rm -rf "$DEST"
cp -R "$APP" "$DEST"
echo "Installed Blink to $DEST"

if [[ "${1:-}" == "--zip" ]]; then
  mkdir -p dist
  ditto -c -k --keepParent "$APP" dist/Blink.zip
  echo "Packaged dist/Blink.zip"
fi
