#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
swift build
BINARY_DIR="$(swift build --show-bin-path)"
APP_DIR="$PWD/.build/OpenUI Demo.app"
mkdir -p "$APP_DIR/Contents/MacOS"
cp "$BINARY_DIR/OpenUIDemo" "$APP_DIR/Contents/MacOS/OpenUIDemo"
cat > "$APP_DIR/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>OpenUIDemo</string>
<key>CFBundleIdentifier</key><string>dev.openui.swift.demo</string>
<key>CFBundleName</key><string>OpenUI Demo</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>1.0</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
codesign --force --sign - "$APP_DIR"
printf 'Built: %s\n' "$APP_DIR"
