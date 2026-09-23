#!/usr/bin/env bash
#
# Builds a distributable, notarized macOS app bundle (+ DMG) for Moonlight Study.
#
# Requirements (run from a macOS machine with Xcode installed):
#   1. A "Developer ID Application" signing certificate in the keychain.
#   2. Xcode 13.2+ (notarytool). Apple Developer ID + notarization credentials.
#
# Config via environment:
#   DEV_ID            Developer ID identity. Default: auto-grant "Developer ID Application".
#                     Example: DEV_ID="Developer ID Application: Navatej Ratnan (TEAMID123)"
#   APPLE_PROFILE     keychain notarytool profile created with `xcrun notarytool
#                     store-credentials` (default "notarytool").
#   SKIP_NOTARY=1     skip notarization + stapling (unsigned local DMG).
#
# Output: dist/Moonlight Study-<version>.dmg
set -euo pipefail

cd "$(dirname "$0")/.."   # app/

APP_NAME="${APP_NAME:-study_companion}"
DMG_VOLUME="Moonlight Study"
VERSION="$(grep -m1 '^version:' pubspec.yaml | sed -E 's/version: ([^+]*).*/\1/')"

DIST_DIR="$(pwd)/dist"
BUILD_APP="build/macos/Build/Products/Release/${APP_NAME}.app"
STAGING="build/release-staging"
DMG_DIR="${STAGING}/${DMG_VOLUME}.app"
DMG_PATH="${DIST_DIR}/${DMG_VOLUME}-${VERSION}.dmg"

command -v flutter >/dev/null || { echo "flutter not on PATH"; exit 1; }
command -v hdiutil >/dev/null || { echo "hdiutil missing (macOS only)"; exit 1; }

echo "▶ Building macOS release (this may take a few minutes)…"
flutter build macos --release

test -d "$BUILD_APP" || { echo "Build incomplete: $BUILD_APP missing"; exit 1; }

# Signing identity:
#   - SKIP_NOTARY=1 → ad-hoc ("-") so anyone can produce a local DMG.
#   - otherwise a Developer ID Application cert is required for notarization.
SKIP_NOTARY="${SKIP_NOTARY:-0}"
if [ "$SKIP_NOTARY" = "1" ]; then
  IDENTITY="${DEV_ID:--}"
  echo "▶ SKIP_NOTARY=1 — using ad-hoc signing identity (${IDENTITY})."
else
  IDENTITY="${DEV_ID:-$(security find-identity -v -p codesigning | grep -oE 'Developer ID Application[^"]*(\([A-Z0-9]{10}\))' | head -1)}"
  if [ -z "$IDENTITY" ]; then
    echo "✗ No Developer ID Application identity found in the keychain." >&2
    echo "  Install one, or set DEV_ID to use a specific identity." >&2
    exit 1
  fi
  echo "▶ Signing with: $IDENTITY"
fi

# Hardened runtime + secure timestamp (required for notarization).
codesign --force --options runtime --timestamp --deep \
  --entitlements macos/Runner/Release.entitlements \
  --sign "$IDENTITY" "$BUILD_APP"
echo "▶ Verification:"
codesign --verify --deep --strict --verbose=2 "$BUILD_APP"

if [ "$SKIP_NOTARY" = "1" ]; then
  echo "▶ SKIP_NOTARY=1 — skipping notarization."
else
  echo "▶ Notarizing…"
  xcrun notarytool submit "$BUILD_APP" \
    --keychain-profile "${APPLE_PROFILE:-notarytool}" --wait

  echo "▶ Stapling the ticket…"
  xcrun stapler staple "$BUILD_APP"
fi

echo "▶ Building DMG…"
rm -rf "$STAGING" "$DIST_DIR"
mkdir -p "$DIST_DIR" "$STAGING"
cp -R "$BUILD_APP" "$DMG_DIR"
ln -s /Applications "$STAGING/Applications"

hdiutil create -volname "$DMG_VOLUME" -srcfolder "$STAGING" \
  -ov -format UDZO "$DMG_PATH"

echo
echo "✓ Done: $DMG_PATH"