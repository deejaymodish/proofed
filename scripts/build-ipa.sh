#!/bin/bash
# Builds an unsigned-ish .ipa for SideStore from the free-account device build.
# SideStore re-signs it with your Apple ID, so the signature here does not matter.
# Usage: ./scripts/build-ipa.sh        (run from the repo root, with the iPhone plugged in)
set -euo pipefail

SCHEME=Proofed
CONFIG=Release
BUILD_DIR="$PWD/build"
PAYLOAD="$BUILD_DIR/Payload"
OUT="$PWD/Proofed.ipa"

command -v xcodebuild >/dev/null || { echo "xcodebuild not found. Install Xcode."; exit 1; }
[ -d "$SCHEME.xcodeproj" ] || { echo "Run xcodegen generate first."; exit 1; }

rm -rf "$BUILD_DIR" "$OUT"
mkdir -p "$PAYLOAD"

echo "Building $SCHEME ($CONFIG) for a generic iOS device..."
xcodebuild -project "$SCHEME.xcodeproj" -scheme "$SCHEME" -configuration "$CONFIG" \
  -destination 'generic/platform=iOS' -derivedDataPath "$BUILD_DIR/dd" \
  CODE_SIGNING_ALLOWED=NO build

APP="$BUILD_DIR/dd/Build/Products/$CONFIG-iphoneos/$SCHEME.app"
[ -d "$APP" ] || { echo "Build product not found at $APP"; exit 1; }

cp -R "$APP" "$PAYLOAD/"
( cd "$BUILD_DIR" && zip -qr "$OUT" Payload )
rm -rf "$BUILD_DIR"

echo
echo "Created: $OUT"
echo "Send it to your iPhone (AirDrop or iCloud Drive), then open it in SideStore."
