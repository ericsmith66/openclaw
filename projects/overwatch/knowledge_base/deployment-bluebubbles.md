# BlueBubbles Server Deployment Guide
**Version:** 1.0  
**Date:** February 27, 2026  
**Server:** 192.168.4.10 (macOS, user: "eric smith")  
**Purpose:** iMessage relay service alongside Homebridge and OpenClaw

---

## Table of Contents

1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Installation Steps](#installation-steps)
4. [Configuration](#configuration)
5. [Post-Installation](#post-installation)
6. [Troubleshooting](#troubleshooting)
7. [Maintenance](#maintenance)

---

## Overview

BlueBubbles Server enables iMessage on non-Apple devices (Android, Windows) by relaying messages from a connected Mac. This deployment runs alongside existing services on 192.168.4.10:

| Service | Purpose | Port | Status |
|---------|---------|------|--------|
| Homebridge | HomeKit bridge | 8080 | Running |
| BlueBubbles | iMessage relay | 1234 | To be deployed |
| OpenClaw | Camera management | TBA | To be deployed |

### Key Features
- ✅ iMessage relay to Android/Windows devices
- ✅ Push notifications via Firebase (optional, secondary)
- ✅ Web-based interface
- ✅ File transfer support
- ✅ Group messaging

---

## Architecture

### System Architecture
```
┌─────────────────────────────────────────────────────────────┐
│                    192.168.4.10 (macOS)                     │
├─────────────────────────────────────────────────────────────┤
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │  Homebridge  │  │ BlueBubbles  │  │  OpenClaw    │      │
│  │   (8080)     │  │   (1234)     │  │    (TBA)     │      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
│         │                  │                  │              │
│         └──────────────────┴──────────────────┘              │
│                              │                              │
│                    ┌─────────┴─────────┐                    │
│                    │   Reverse Proxy   │                    │
│                    │   (TBA - Future)  │                    │
│                    └─────────┬─────────┘                    │
│                              │                              │
│                    ┌─────────┴─────────┐                    │
│                    │   Cloudflare      │                    │
│                    │   Tunnel          │                    │
│                    └─────────┬─────────┘                    │
│                              │                              │
│                    ┌─────────┴─────────┐                    │
│                    │   Internet        │                    │
│                    └───────────────────┘                    │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│                    iMessage Source                          │
│                    (Connected Mac)                          │
└─────────────────────────────────────────────────────────────┘
```

### Network Flow
1. **Server Side:** BlueBubbles connects to macOS iMessage database
2. **Client Side:** Android/Windows app connects to BlueBubbles server
3. **Relay:** Messages flow bidirectionally between client and iMessage

---

## Installation Steps

### Prerequisites
- ✅ macOS 14+ running on 192.168.4.10
- ✅ User account: "eric smith" (primary user)
- ✅ Internet connection
- ✅ iMessage logged in on the Mac

### Step 1: Download BlueBubbles Server

```bash
# SSH to the server
ssh "eric smith"@192.168.4.10

# Download the latest release
cd ~/Downloads
curl -L -o BlueBubbles.dmg \
  "https://github.com/BlueBubblesApp/bluebubbles-server/releases/latest/download/BlueBubbles.dmg"

# Mount the DMG
hdiutil attach ~/Downloads/BlueBubbles.dmg
```

### Step 2: Install the Application

```bash
# Copy to Applications
cp -R /Volumes/BlueBubbles/BlueBubbles.app /Applications/

# Eject the DMG
hdiutil detach /Volumes/BlueBubbles
```

### Step 3: Grant Permissions

**Note:** BlueBubbles requires **Full Disk Access** to read iMessage database

1. Open **System Settings** → **Privacy & Security** → **Full Disk Access**
2. Click **+** and add `/Applications/BlueBubbles.app`
3. Enable the toggle for BlueBubbles

**Optional:** Enable Accessibility permissions (not required for basic functionality)

### Step 4: Launch BlueBubbles

```bash
# Launch the application
open /Applications/BlueBubbles.app
```

### Step 5: Complete Initial Setup

When the app launches:

1. **Intro Screen** → Click "Continue"
2. **Permissions Screen** → Ensure Full Disk Access is enabled
3. **Notifications Screen** → 
   - For now, select **"Skip"** (Firebase setup is secondary)
   - Or follow manual Firebase setup if needed later
4. **Connection Screen** → Set a strong server password
   - Save with the **floppy disk icon**
   - Note: This password is for client connections
5. **Finish Screen** → Click "Finish"

---

## Configuration

### Server Settings

After initial setup, configure the server:

1. **Proxy Service:** Leave as "None" for now (will configure reverse proxy later)
2. **Server Port:** Default is `1234` (HTTP)
3. **Server Password:** Your strong password from Step 5

### Manual Firebase Setup (Optional - For Android Notifications)

If you want push notifications on Android clients:

1. Create Firebase project: https://console.firebase.google.com/
2. Enable Firestore Database
3. Generate `google_services.json` and `firebase-adminsdk.json`
4. In BlueBubbles UI → Notifications → Manual Setup → Upload files

**Note:** This is optional. Messages will still relay without Firebase.

### Disable Firebase (Recommended for Now)

To avoid Firebase setup complexity:

1. In BlueBubbles UI → Notifications → Select **"Skip"**
2. Continue to Connection screen

---

## Post-Installation

### Verify Server is Running

```bash
# Check if port 1234 is listening
netstat -an | grep 1234

# Test connectivity (from another device on network)
curl -v http://192.168.4.10:1234/api/health
```

**Expected response:**
```json
{
  "status": "ok",
  "version": "X.X.X"
}
```

### Test iMessage Connection

1. On the Mac, check BlueBubbles UI → it should show "Connected to iMessage"
2. Try sending a test message from iMessage
3. The server logs should show the message being relayed

---

## Troubleshooting

### Common Issues

#### 1. "Cannot Access iMessage Database"
**Solution:** Full Disk Access not granted
- System Settings → Privacy & Security → Full Disk Access
- Re-add BlueBubbles.app and enable toggle

#### 2. "Connection Failed" on Client
**Solutions:**
- Verify server is running: `netstat -an | grep 1234`
- Check firewall: System Settings → Network → Firewall → Disable temporarily
- Verify password is correct on client

#### 3. Messages Not Relaying
**Solutions:**
- Check BlueBubbles UI shows "Connected to iMessage"
- Restart BlueBubbles: `killall BlueBubbles && open /Applications/BlueBubbles.app`
- Reconnect client app

#### 4. Server Crashes
**Solutions:**
- Check logs: `~/Library/Logs/BlueBubbles/`
- Reinstall BlueBubbles
- Update to latest version

---

## Maintenance

### Update BlueBubbles

```bash
# Download latest version
curl -L -o BlueBubbles.dmg \
  "https://github.com/BlueBubblesApp/bluebubbles-server/releases/latest/download/BlueBubbles.dmg"

# Mount and reinstall
hdiutil attach ~/Downloads/BlueBubbles.dmg
rm -rf /Applications/BlueBubbles.app
cp -R /Volumes/BlueBubbles/BlueBubbles.app /Applications/
hdiutil detach /Volumes/BlueBubbles
```

### View Logs

```bash
# Application logs
tail -f ~/Library/Logs/BlueBubbles/*.log

# System logs
log show --predicate 'process == "BlueBubbles"' --last 1h
```

### Backup Configuration

```bash
# BlueBubbles stores config here:
# ~/Library/Application Support/bluebubbles-server/

# Backup command
tar -czf ~/bluebubbles-backup-$(date +%Y%m%d).tar.gz \
  ~/Library/Application\ Support/bluebubbles-server/
```

---

## Related Documentation

- [OpenClaw Deployment Guide](./deployment-openclaw.md)
- [Service Port Assignments](./service-ports.md)
- [Reverse Proxy Setup](./reverse-proxy-configuration.md) (Future)
- [Runbook: BlueBubbles](./runbook-bluebubbles.md)

---

## Quick Reference

| Task | Command |
|------|---------|
| Start BlueBubbles | `open /Applications/BlueBubbles.app` |
| Stop BlueBubbles | `killall BlueBubbles` |
| Check port | `netstat -an | grep 1234` |
| Test health | `curl http://192.168.4.10:1234/api/health` |
| View logs | `tail -f ~/Library/Logs/BlueBubbles/*.log` |

---

**Next Steps:**
1. Complete initial setup as described above
2. Test message relay with Android/Windows client
3. Configure reverse proxy (when ready)
4. Set up automated backups
