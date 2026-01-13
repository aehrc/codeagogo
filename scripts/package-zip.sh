#!/usr/bin/env bash
set -euo pipefail

APP_NAME="SNOMED Lookup"
SCHEME="SNOMED Lookup"
CONFIG="${1:-Release}"
OUT_DIR="${2:-dist}"

mkdir -p "$OUT_DIR"

echo "Building $SCHEME ($CONFIG)..."

xcodebuild \
  -scheme "$SCHEME" \
  -configuration "$CONFIG" \
  -derivedDataPath build \
  clean build

APP_PATH="build/Build/Products/${CONFIG}/${APP_NAME}.app"

if [[ ! -d "$APP_PATH" ]]; then
  echo "ERROR: App not found at: $APP_PATH"
  echo "Hint: Check the scheme name in Xcode matches: $SCHEME"
  exit 1
fi

ZIP_PATH="${OUT_DIR}/SNOMED-Lookup-macOS-${CONFIG}.zip"

echo "Packaging: $ZIP_PATH"
rm -f "$ZIP_PATH"

# ditto preserves macOS app bundle metadata correctly
ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$ZIP_PATH"

echo "Done."
echo "Created: $ZIP_PATH"
