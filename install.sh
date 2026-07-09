#!/usr/bin/env bash
set -euo pipefail

APP_NAME="PuntoSwitcherRUDE.app"
APP_DISPLAY_NAME="PuntoSwitcher RU-DE"
BUNDLE_ID="com.andreyprokhorovich.puntoswicher-rude"
INSTALL_DIR="$HOME/Applications"
APP_SOURCE="dist/$APP_NAME"
APP_TARGET="$INSTALL_DIR/$APP_NAME"
LAUNCH_AGENTS_DIR="$HOME/Library/LaunchAgents"
PLIST_PATH="$LAUNCH_AGENTS_DIR/$BUNDLE_ID.plist"

cd "$(dirname "$0")"
./build.sh

mkdir -p "$INSTALL_DIR" "$LAUNCH_AGENTS_DIR"
rm -rf "$APP_TARGET"
cp -R "$APP_SOURCE" "$APP_TARGET"

cat > "$PLIST_PATH" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>$BUNDLE_ID</string>
  <key>ProgramArguments</key>
  <array>
    <string>$APP_TARGET/Contents/MacOS/PuntoSwitcherRUDE</string>
    <string>--hotkey</string>
    <string>cmd+^</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <false/>
  <key>StandardOutPath</key>
  <string>$HOME/Library/Logs/$BUNDLE_ID.out.log</string>
  <key>StandardErrorPath</key>
  <string>$HOME/Library/Logs/$BUNDLE_ID.err.log</string>
</dict>
</plist>
PLIST

launchctl unload "$PLIST_PATH" >/dev/null 2>&1 || true
launchctl load "$PLIST_PATH"

echo "$APP_DISPLAY_NAME installed."
echo "App: $APP_TARGET"
echo "LaunchAgent: $PLIST_PATH"
echo "If hotkeys do not work, grant Accessibility permission to the app in System Settings."
