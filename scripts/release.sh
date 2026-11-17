#!/bin/bash
# 配布用の zip を dist/ に作る（ユニバーサルバイナリ、ad-hoc 署名）。
# usage: scripts/release.sh <version>
#
# GitHub Actions の中では、zip のパスと SHA-256 を $GITHUB_OUTPUT（zip / sha256）に書く。
set -euo pipefail

VERSION="${1:?usage: scripts/release.sh <version>}"

cd "$(dirname "$0")/.."
SOURCE_VERSION="$(sed -n 's/.*current = "\(.*\)"/\1/p' Sources/Taffy/Version.swift)"
if [[ "$SOURCE_VERSION" != "$VERSION" ]]; then
  echo "バージョンが一致しません: 指定 $VERSION / Version.swift $SOURCE_VERSION" >&2
  exit 1
fi

UNIVERSAL=1 CODESIGN_IDENTITY=- scripts/build-app.sh
test "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' build/Taffy.app/Contents/Info.plist)" = "$VERSION"

rm -rf dist
mkdir -p dist
ZIP="dist/Taffy-${VERSION}-macos-universal.zip"
ditto -c -k --keepParent build/Taffy.app "$ZIP"

SHA256="$(shasum -a 256 "$ZIP" | cut -d ' ' -f 1)"
echo "$SHA256  $(basename "$ZIP")" > "$ZIP.sha256"
if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  { echo "zip=$ZIP"; echo "sha256=$SHA256"; } >> "$GITHUB_OUTPUT"
fi
echo "完成: $ZIP"
echo "SHA-256: $SHA256"
echo "cask: scripts/cask.sh $VERSION $SHA256"
