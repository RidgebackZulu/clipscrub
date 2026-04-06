#!/bin/bash
set -euo pipefail

APP_NAME="ClipScrub"
BUILD_DIR=".build/release"
APP_BUNDLE="${APP_NAME}.app"
CONTENTS="${APP_BUNDLE}/Contents"
MACOS="${CONTENTS}/MacOS"
RESOURCES="${CONTENTS}/Resources"

echo "Building ${APP_NAME}..."
swift build -c release

echo "Creating app bundle..."
rm -rf "${APP_BUNDLE}"
mkdir -p "${MACOS}" "${RESOURCES}"

cp "${BUILD_DIR}/${APP_NAME}" "${MACOS}/${APP_NAME}"
cp Resources/Info.plist "${CONTENTS}/Info.plist"

echo "Signing with ad-hoc signature..."
codesign -s - --force --deep "${APP_BUNDLE}"

echo ""
echo "Done! ${APP_BUNDLE} is ready."
echo "To install: cp -r ${APP_BUNDLE} /Applications/"
