#!/usr/bin/env bash
set -euo pipefail

APP_NAME="PuntoSwitcherRUDE.app"
BUNDLE_ID="com.andreyprokhorovich.puntoswicher-rude"
APP_TARGET="$HOME/Applications/$APP_NAME"
PLIST_PATH="$HOME/Library/LaunchAgents/$BUNDLE_ID.plist"

launchctl unload "$PLIST_PATH" >/dev/null 2>&1 || true
rm -f "$PLIST_PATH"
rm -rf "$APP_TARGET"

echo "PuntoSwitcher RU-DE uninstalled."
echo "Removed app: $APP_TARGET"
echo "Removed LaunchAgent: $PLIST_PATH"
