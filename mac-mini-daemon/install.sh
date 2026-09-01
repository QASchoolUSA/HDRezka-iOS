#!/bin/bash
set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PLIST_NAME="com.hdrezka.daemon.plist"
TARGET_DIR="$HOME/Library/LaunchAgents"
NODE_BIN="$(which node || echo '/opt/homebrew/bin/node')"

echo "=== Installing HDRezka 24/7 Mac Mini Service ==="
echo "Node binary: $NODE_BIN"
echo "Daemon directory: $DIR"

mkdir -p "$TARGET_DIR"

# Generate plist with exact local node path and strip-types flag
cat <<EOF > "$TARGET_DIR/$PLIST_NAME"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.hdrezka.daemon</string>
    <key>ProgramArguments</key>
    <array>
        <string>$NODE_BIN</string>
        <string>--strip-types</string>
        <string>$DIR/server.ts</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>$DIR/daemon.log</string>
    <key>StandardErrorPath</key>
    <string>$DIR/daemon.err</string>
    <key>WorkingDirectory</key>
    <string>$DIR</string>
</dict>
</plist>
EOF

echo "=== Loading macOS launchd Service ==="
launchctl unload "$TARGET_DIR/$PLIST_NAME" 2>/dev/null || true
launchctl load "$TARGET_DIR/$PLIST_NAME"

sleep 1.5

echo "=== Checking Service Status ==="
if curl -s http://localhost:7890/status > /dev/null; then
    echo "✅ HDRezka 24/7 Daemon is ACTIVE and running on http://localhost:7890"
    curl -s http://localhost:7890/status
    echo ""
else
    echo "⚠️ Daemon loaded. Check logs at: $DIR/daemon.log and $DIR/daemon.err"
fi
