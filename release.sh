#!/bin/zsh
# Builds, tests and packages Paint.app into a zip for GitHub Releases.
#   ./release.sh              build + test + zip
#   ./release.sh 2.1.0        same, with an explicit version
#   ./release.sh 2.1.0 publish  also create the GitHub release (needs gh)
set -euo pipefail
cd "${0:A:h}"

VERSION="${1:-2.1.0}"
MODE="${2:-}"

./build.sh
./test.sh

OUT="build/release"
ZIP="$PWD/$OUT/Paint-mac-$VERSION.zip"
rm -rf "$OUT"
mkdir -p "$OUT"
cp -R build/Paint.app "$OUT/Paint.app"
# ditto keeps the bundle's symlinks, resource forks and the ad-hoc signature.
ditto -c -k --sequesterRsrc --keepParent "$OUT/Paint.app" "$ZIP"
printf 'Packaged %s (%s)\n' "$ZIP" "$(du -h "$ZIP" | cut -f1)"

if [[ "$MODE" == "publish" ]]; then
  command -v gh >/dev/null || { print -u2 "gh CLI not installed"; exit 1; }
  gh release create "v$VERSION" "$ZIP" \
    --title "小畫家 for Mac $VERSION" \
    --notes "macOS 原生小畫家，可切換 Windows 11 / 10 / 7 / XP 四種介面。Apple Silicon、macOS 13 以上。本機 ad-hoc 簽署，未經 Apple 公證：第一次開啟請在 Finder 按右鍵選「打開」。"
  printf 'Published v%s\n' "$VERSION"
else
  printf 'To publish: ./release.sh %s publish\n' "$VERSION"
fi
