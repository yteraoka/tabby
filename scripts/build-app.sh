#!/usr/bin/env bash
# Builds build/Tabby.app from the Swift package.
#
#   CONFIG=debug|release   build configuration (default: release)
#   UNIVERSAL=1            build an arm64 + x86_64 binary (needs full Xcode)
#   CODESIGN_IDENTITY=...  signing identity (default: "-", ad-hoc)
set -euo pipefail

cd "$(dirname "$0")/.."

CONFIG="${CONFIG:-release}"
ARCH_FLAGS=()
if [[ "${UNIVERSAL:-0}" == "1" ]]; then
  ARCH_FLAGS=(--arch arm64 --arch x86_64)
fi

swift build -c "$CONFIG" ${ARCH_FLAGS[@]+"${ARCH_FLAGS[@]}"}
BIN_DIR="$(swift build -c "$CONFIG" ${ARCH_FLAGS[@]+"${ARCH_FLAGS[@]}"} --show-bin-path)"

APP="build/Tabby.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/Tabby" "$APP/Contents/MacOS/Tabby"
cp Resources/Info.plist "$APP/Contents/Info.plist"

codesign --force --sign "${CODESIGN_IDENTITY:--}" "$APP"

echo "Built $APP"
