#!/bin/zsh
# Builds, tests and packages Paint.app into a zip and a dmg for GitHub Releases.
#   ./release.sh              build + test + zip + dmg
#   ./release.sh 2.1.0        same, with an explicit version
#   ./release.sh 2.1.0 publish  also create the GitHub release (needs gh)
set -euo pipefail
cd "${0:A:h}"

VERSION="${1:-2.1.0}"
MODE="${2:-}"

./build.sh
./test.sh

OUT="build/release"
APP="$PWD/$OUT/Paint.app"
ZIP="$PWD/$OUT/Paint-mac-$VERSION.zip"
DMG="$PWD/$OUT/Paint-mac-$VERSION.dmg"
STAGE="$PWD/$OUT/dmg-root"
rm -rf "$OUT"
mkdir -p "$OUT"
cp -R build/Paint.app "$APP"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $VERSION" "$APP/Contents/Info.plist"
codesign --force --sign - "$APP"

# ditto keeps the bundle's symlinks, resource forks and the ad-hoc signature.
ditto -c -k --sequesterRsrc --keepParent "$APP" "$ZIP"
printf 'Packaged %s (%s)\n' "$ZIP" "$(du -h "$ZIP" | cut -f1)"

mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/Paint.app"
ln -s /Applications "$STAGE/Applications"
rm -f "$DMG"
diskutil image create from --format UDZO --volumeName "Paint $VERSION" "$STAGE" "$DMG"
rm -rf "$STAGE"
printf 'Packaged %s (%s)\n' "$DMG" "$(du -h "$DMG" | cut -f1)"

if [[ "$MODE" == "publish" ]]; then
  command -v gh >/dev/null || { print -u2 "gh CLI not installed"; exit 1; }
  gh release create "v$VERSION" "$ZIP" "$DMG" \
    --title "小畫家 for Mac $VERSION" \
    --notes "$(cat <<EOF
macOS 原生小畫家，可切換 Windows 11 / 10 / 7 / XP 四種介面。

- \`Paint-mac-$VERSION.zip\`：解壓後即可使用
- \`Paint-mac-$VERSION.dmg\`：打開後把 Paint 拖進「應用程式」

Apple Silicon、macOS 13 以上。本機 ad-hoc 簽署，未經 Apple 公證：第一次開啟請在 Finder 按右鍵選「打開」。自動移除背景需要 macOS 14 以上。
EOF
)"
  printf 'Published v%s\n' "$VERSION"
else
  printf 'To publish: ./release.sh %s publish\n' "$VERSION"
fi
