#!/usr/bin/env bash
# Runs the macOS unit tests locally. Use this before merging.
set -euo pipefail

cd "$(dirname "$0")/.."

DERIVED_DATA="${DERIVED_DATA:-build/DerivedData}"

echo "Running Blink tests..."
xcodebuild test \
  -project Blink.xcodeproj \
  -scheme Blink \
  -destination 'platform=macOS' \
  -derivedDataPath "$DERIVED_DATA" \
  -quiet

echo "Tests passed."
