#!/bin/bash
set -e

PLIST_NAME="com.hdrezka.daemon.plist"
TARGET_FILE="$HOME/Library/LaunchAgents/$PLIST_NAME"

echo "=== Disabling HDRezka 24/7 Mac Mini Service ==="
launchctl unload "$TARGET_FILE" 2>/dev/null || true
rm -f "$TARGET_FILE"

# Kill any leftover node processes on port 7890
lsof -ti :7890 | xargs kill -9 2>/dev/null || true

echo "✅ HDRezka daemon is completely stopped and disabled on this Mac."
