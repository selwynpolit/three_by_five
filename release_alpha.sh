#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_OUTPUT="$SCRIPT_DIR/build/macos/Build/Products/Release/3by5.app"
ALPHA_NAME="3by5 Alpha.app"
INSTALL_PATH="/Applications/$ALPHA_NAME"

echo "Building 3by5 (release)…"
cd "$SCRIPT_DIR"
flutter build macos --release

if [[ ! -d "$BUILD_OUTPUT" ]]; then
  echo "Error: build output not found at $BUILD_OUTPUT" >&2
  exit 1
fi

echo "Installing to ${INSTALL_PATH}…"
rm -rf "$INSTALL_PATH"
cp -R "$BUILD_OUTPUT" "$INSTALL_PATH"

BUILD_DATE="$(date '+%Y-%m-%d %H:%M:%S')"
echo "Done — 3by5 Alpha installed to /Applications at $BUILD_DATE"
