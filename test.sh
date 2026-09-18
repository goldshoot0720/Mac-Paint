#!/bin/zsh
set -euo pipefail
cd "${0:A:h}"
export DEVELOPER_DIR=/Library/Developer/CommandLineTools
mkdir -p build/tests build/module-cache
swiftc -O -module-cache-path "$PWD/build/module-cache" -target arm64-apple-macosx13.0 -framework AppKit -framework UniformTypeIdentifiers Sources/Document.swift Sources/Fluent.swift Sources/Canvas.swift Tests/main.swift -o build/tests/PaintTests
build/tests/PaintTests "$PWD/build/tests/artifacts"
