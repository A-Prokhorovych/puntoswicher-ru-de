#!/usr/bin/env bash
set -euo pipefail

mkdir -p .build
clang \
  -fobjc-arc \
  Sources/PuntoSwitcherRUDE/main.m \
  -framework AppKit \
  -framework Carbon \
  -framework ApplicationServices \
  -o .build/puntoswicher-ru-de

APP_DIR="dist/PuntoSwitcherRUDE.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR"
cp .build/puntoswicher-ru-de "$MACOS_DIR/PuntoSwitcherRUDE"

cat > "$CONTENTS_DIR/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>PuntoSwitcherRUDE</string>
  <key>CFBundleIdentifier</key>
  <string>com.andreyprokhorovich.puntoswicher-rude</string>
  <key>CFBundleName</key>
  <string>PuntoSwitcher RU-DE</string>
  <key>CFBundleDisplayName</key>
  <string>PuntoSwitcher RU-DE</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>0.8</string>
  <key>CFBundleVersion</key>
  <string>8</string>
  <key>LSMinimumSystemVersion</key>
  <string>13.0</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSHumanReadableCopyright</key>
  <string>Copyright © 2026 Andrey Prokhorovich</string>
</dict>
</plist>
PLIST

echo ".build/puntoswicher-ru-de"
echo "$APP_DIR"
