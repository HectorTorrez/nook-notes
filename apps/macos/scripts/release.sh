#!/usr/bin/env bash
# Builds, signs, notarizes, and staples a distributable Blink.zip.
#
# Required:
#   DEVELOPER_ID_APPLICATION  e.g. "Developer ID Application: Name (TEAMID)"
#   NOTARY_PROFILE            a keychain profile created with:
#     xcrun notarytool store-credentials "blink-notary" \
#       --apple-id "you@example.com" --team-id "TEAMID" \
#       --password "app-specific-password"
#
# Or set APPLE_ID, TEAM_ID, and APP_SPECIFIC_PASSWORD instead of NOTARY_PROFILE.
set -euo pipefail

cd "$(dirname "$0")/.."

APP_NAME="Blink"
BUILD_DIR="build"
APP="$BUILD_DIR/Build/Products/Release/$APP_NAME.app"
DIST="dist"
ZIP="$DIST/$APP_NAME.zip"

if [[ -z "${DEVELOPER_ID_APPLICATION:-}" ]]; then
  echo "Set DEVELOPER_ID_APPLICATION to your Developer ID Application certificate." >&2
  exit 1
fi

if [[ -z "${NOTARY_PROFILE:-}" ]]; then
  : "${APPLE_ID:?Set NOTARY_PROFILE or APPLE_ID}"
  : "${TEAM_ID:?Set TEAM_ID or NOTARY_PROFILE}"
  : "${APP_SPECIFIC_PASSWORD:?Set APP_SPECIFIC_PASSWORD or NOTARY_PROFILE}"
fi

echo "Building Release..."
xcodebuild \
  -project Blink.xcodeproj \
  -scheme Blink \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -derivedDataPath "$BUILD_DIR" \
  CODE_SIGN_IDENTITY="$DEVELOPER_ID_APPLICATION" \
  CODE_SIGN_STYLE=Manual \
  OTHER_CODE_SIGN_FLAGS="--timestamp --options runtime" \
  -quiet \
  build

echo "Signing..."
codesign \
  --force \
  --deep \
  --options runtime \
  --timestamp \
  --sign "$DEVELOPER_ID_APPLICATION" \
  "$APP"
codesign --verify --deep --strict --verbose=2 "$APP"

mkdir -p "$DIST"
echo "Creating $ZIP..."
ditto -c -k --keepParent "$APP" "$ZIP"

echo "Submitting for notarization (this can take a few minutes)..."
if [[ -n "${NOTARY_PROFILE:-}" ]]; then
  xcrun notarytool submit "$ZIP" --keychain-profile "$NOTARY_PROFILE" --wait
else
  xcrun notarytool submit "$ZIP" \
    --apple-id "$APPLE_ID" \
    --team-id "$TEAM_ID" \
    --password "$APP_SPECIFIC_PASSWORD" \
    --wait
fi

echo "Stapling the notarization ticket..."
xcrun stapler staple "$APP"
xcrun stapler validate "$APP"

# Recreate the zip after stapling so the downloaded app needs no ticket lookup.
ditto -c -k --keepParent "$APP" "$ZIP"

echo "Done: $ZIP is signed, notarized, and stapled."
