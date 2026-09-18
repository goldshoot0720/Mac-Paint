#!/bin/zsh
set -euo pipefail
cd "${0:A:h}"
export DEVELOPER_DIR=/Library/Developer/CommandLineTools
mkdir -p build/Paint.app/Contents/MacOS build/Paint.app/Contents/Resources build/module-cache
swiftc -O -module-cache-path "$PWD/build/module-cache" -target arm64-apple-macosx13.0 -framework AppKit -framework UniformTypeIdentifiers Sources/Document.swift Sources/Fluent.swift Sources/Canvas.swift Sources/Ribbon.swift Sources/Classic.swift Sources/App.swift Sources/main.swift -o build/Paint.app/Contents/MacOS/Paint
swiftc -O -module-cache-path "$PWD/build/module-cache" Scripts/Icon.swift -o build/MakeIcon
build/MakeIcon "$PWD/build/Paint.iconset"
python3 Scripts/package-icon.py
cp Info.plist build/Paint.app/Contents/Info.plist
codesign --force --sign - build/Paint.app
printf 'Built %s/build/Paint.app\n' "$PWD"
