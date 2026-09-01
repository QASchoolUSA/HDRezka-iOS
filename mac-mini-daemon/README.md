# Mac Mini 24/7 Companion Daemon

A lightweight companion service designed to run 24/7 on your powered Mac Mini.

## What It Does
- **Continuous Mirror Health**: Continuously checks and discovers fastest responsive HDRezka mirrors.
- **Local Residential Proxy**: Lets your iPhone & iPad route traffic through your home network for zero ISP throttling.
- **Zero-Maintenance**: Managed by macOS `launchd` — automatically starts on boot and restarts if crashed.

## How to Run

### Manual test run:
```bash
npx tsx server.ts
```

### Install as 24/7 macOS Background Service:
```bash
chmod +x install.sh
./install.sh
```

### Stop/Uninstall Service:
```bash
launchctl unload ~/Library/LaunchAgents/com.hdrezka.daemon.plist
```
