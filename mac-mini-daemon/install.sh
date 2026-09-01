#!/bin/bash
set -e

PLIST_NAME="com.hdrezka.daemon.plist"
TARGET_DIR="$HOME/Library/LaunchAgents"

echo "=== Installing HDRezka 24/7 Mac Mini Service ==="
mkdir -p "$TARGET_DIR"
cp "$PLIST_NAME" "$TARGET_DIR/"

echo "=== Loading Service ==="
launchctl unload "$TARGET_DIR/$PLIST_NAME" 2>/dev/null || true
launchctl load "$TARGET_DIR/$PLIST_NAME"

echo "=== HDRezka Daemon installed and active! ==="
echo "Logs available at: $PWD/daemon.log"
