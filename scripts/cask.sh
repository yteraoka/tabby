#!/bin/bash
# packaging/tabby.rb の version と sha256 を書き換えた cask を標準出力に出す
# usage: scripts/cask.sh <version> <sha256>
set -euo pipefail
VERSION="${1:?usage: scripts/cask.sh <version> <sha256>}"
SHA256="${2:?usage: scripts/cask.sh <version> <sha256>}"
[[ "$SHA256" =~ ^[0-9a-f]{64}$ ]] || { echo "sha256 が不正です: $SHA256" >&2; exit 1; }
cd "$(dirname "$0")/.."
sed -e "s/^  version \".*\"/  version \"$VERSION\"/" \
    -e "s/^  sha256 \".*\"/  sha256 \"$SHA256\"/" \
    -e "/^# Homebrew の tap/,/^# version と sha256/d" \
    packaging/tabby.rb
