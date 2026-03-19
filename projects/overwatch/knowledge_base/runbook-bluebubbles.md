# Runbook: BlueBubbles Server
**Version:** 1.0  
**Date:** February 27, 2026  
**Server:** 192.168.4.10  
**Primary User:** "eric smith"

---

## Table of Contents

1. [Overview](#overview)
2. [Health Check](#health-check)
3. [Common Issues](#common-issues)
4. [Recovery Procedures](#recovery-procedures)
5. [Maintenance Tasks](#maintenance-tasks)
6. [Escalation](#escalation)

---

## Overview

**Service:** BlueBubbles Server  
**Purpose:** iMessage relay for Android/Windows devices  
**Port:** 1234 (HTTP)  
**Data Location:** `~/Library/Application Support/bluebubbles-server/`  
**Logs Location:** `~/Library/Logs/BlueBubbles/`

### Service Status
- **Process:** `BlueBubbles`
- **User:** `eric smith`
- **Dependencies:** macOS iMessage (built-in)

---

## Health Check

### Manual Health Check

```bash
# SSH to server
ssh "eric smith"@192.168.4.10

# Check if process is running
ps aux | grep -v grep | grep BlueBubbles

# Check if port is listening
netstat -an | grep 1234

# Test API endpoint
curl -s http://127.0.0.1:1234/api/health | jq .
```

**Expected Output:**
```json
{
  "status": "ok",
  "version": "X.X.X",
  "connected": true,
  "connected_to_imessage": true
}
```

### Automated Health Check (Future)

```bash
# Add to monitoring system
# Endpoint: http://192.168.4.10:1234/api/health
# Expected status: 200 OK
# JSON field: "connected" == true
```

---

## Common Issues

### 🔴 Issue 1: Service Not Running

**Symptoms:**
- Client cannot connect to port 1234
- `netstat -an | grep 1234` returns no results

**Diagnostic:**
```bash
# Check if process is running
ps aux | grep BlueBubbles

# Check recent logs
tail -50 ~/Library/Logs/BlueBubbles/*.log

# Check if app was quit manually
ps aux | grep -v grep | grep BlueBubbles
```

**Resolution:**
```bash
# Start BlueBubbles
open /Applications/BlueBubbles.app

# Verify it started
sleep 3
netstat -an | grep 1234
```

---

### 🟡 Issue 2: Cannot Access iMessage Database

**Symptoms:**
- BlueBubbles shows "Cannot access iMessage database"
- Logs show permission errors

**Diagnostic:**
```bash
# Check Full Disk Access
# System Settings → Privacy & Security → Full Disk Access
# Verify BlueBubbles is listed and enabled
```

**Resolution:**
```bash
# Manual fix (requires GUI access to Mac)
# 1. System Settings → Privacy & Security → Full Disk Access
# 2. Click lock icon, enter password
# 3. Click + and add /Applications/BlueBubbles.app
# 4. Enable the toggle for BlueBubbles
```

**Scripted Check (Future):**
```bash
# Check if permission is granted
defaults read ~/Library/Preferences/com.apple.UniversalAccess.plist
```

---

### 🟡 Issue 3: Client Connection Failed

**Symptoms:**
- Android/Windows app shows "Connection failed"
- Wrong password error

**Diagnostic:**
```bash
# Check server password in BlueBubbles UI
# UI path: Settings → Connection → Server Password

# Check firewall
# System Settings → Network → Firewall → Disable temporarily
# Test connection from client device
```

**Resolution:**
```bash
# Verify server is accessible from client
# From client device (Android/Windows):
# http://192.168.4.10:1234

# Check firewall rules
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate

# Temporarily disable firewall (for testing only)
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate off
```

---

### 🟡 Issue 4: Messages Not Relaying

**Symptoms:**
- Client connected but messages not appearing
- iMessage sent but not relayed to client

**Diagnostic:**
```bash
# Check BlueBubbles UI status
# Should show "Connected to iMessage"

# Check logs for message relay
grep "message" ~/Library/Logs/BlueBubbles/*.log | tail -20

# Verify iMessage is working on Mac
# Send test message from Mac → check if relayed
```

**Resolution:**
```bash
# Restart BlueBubbles
killall BlueBubbles
open /Applications/BlueBubbles.app
sleep 5

# Verify connection
ps aux | grep BlueBubbles
netstat -an | grep 1234
```

---

### 🟢 Issue 5: High CPU Usage

**Symptoms:**
- Mac running hot
- Fans running constantly

**Diagnostic:**
```bash
# Check CPU usage
top -o cpu | head -20

# Check if BlueBubbles is the culprit
ps -p $(pgrep BlueBubbles) -o %cpu,comm
```

**Resolution:**
```bash
# Restart BlueBubbles
killall BlueBubbles
open /Applications/BlueBubbles.app

# If persists, check for problematic messages
# Clear cache (caution: may lose some data)
rm -rf ~/Library/Application\ Support/bluebubbles-server/Cache/*
```

---

## Recovery Procedures

### Recovery 1: Service Restart

```bash
# SSH to server
ssh "eric smith"@192.168.4.10

# Graceful restart
killall BlueBubbles
sleep 2
open /Applications/BlueBubbles.app

# Verify
sleep 3
netstat -an | grep 1234
curl -s http://127.0.0.1:1234/api/health | jq .
```

### Recovery 2: Reinstall BlueBubbles

```bash
# SSH to server
ssh "eric smith"@192.168.4.10

# Download latest version
curl -L -o ~/Downloads/BlueBubbles.dmg \
  "https://github.com/BlueBubblesApp/bluebubbles-server/releases/latest/download/BlueBubbles.dmg"

# Uninstall
killall BlueBubbles
rm -rf /Applications/BlueBubbles.app
hdiutil detach /Volumes/BlueBubbles 2>/dev/null || true

# Install
hdiutil attach ~/Downloads/BlueBubbles.dmg
cp -R /Volumes/BlueBubbles/BlueBubbles.app /Applications/
hdiutil detach /Volumes/BlueBubbles

# Launch
open /Applications/BlueBubbles.app
```

**Note:** Configuration is preserved in `~/Library/Application Support/bluebubbles-server/`

### Recovery 3: Full Reset

```bash
# Warning: This deletes all configuration!
ssh "eric smith"@192.168.4.10

# Stop service
killall BlueBubbles

# Backup configuration
tar -czf ~/bluebubbles-config-backup-$(date +%Y%m%d).tar.gz \
  ~/Library/Application\ Support/bluebubbles-server/

# Reset
rm -rf ~/Library/Application\ Support/bluebubbles-server/
rm -rf ~/Library/Logs/BlueBubbles/

# Launch fresh
open /Applications/BlueBubbles.app
# Complete initial setup again
```

---

## Maintenance Tasks

### Task 1: Update BlueBubbles

**Frequency:** Monthly or when security patches released

```bash
# SSH to server
ssh "eric smith"@192.168.4.10

# Download latest
curl -L -o ~/Downloads/BlueBubbles.dmg \
  "https://github.com/BlueBubblesApp/bluebubbles-server/releases/latest/download/BlueBubbles.dmg"

# Install
hdiutil attach ~/Downloads/BlueBubbles.dmg
rm -rf /Applications/BlueBubbles.app
cp -R /Volumes/BlueBubbles/BlueBubbles.app /Applications/
hdiutil detach /Volumes/BlueBubbles

# Restart
killall BlueBubbles
open /Applications/BlueBubbles.app

# Verify version
curl -s http://127.0.0.1:1234/api/health | jq .version
```

### Task 2: Backup Configuration

**Frequency:** Weekly

```bash
# SSH to server
ssh "eric smith"@192.168.4.10

# Create backup
BACKUP_DATE=$(date +%Y%m%d)
BACKUP_FILE="~/bluebubbles-config-backup-${BACKUP_DATE}.tar.gz"

tar -czf "$BACKUP_FILE" \
  ~/Library/Application\ Support/bluebubbles-server/

# Verify backup
ls -lh "$BACKUP_FILE"
```

### Task 3: Clear Cache

**Frequency:** Monthly (or when experiencing issues)

```bash
# SSH to server
ssh "eric smith"@192.168.4.10

# Stop service
killall BlueBubbles

# Clear cache (does not affect configuration)
rm -rf ~/Library/Application\ Support/bluebubbles-server/Cache/*

# Restart
open /Applications/BlueBubbles.app
```

### Task 4: Review Logs

**Frequency:** Weekly (manual) or continuous (monitoring)

```bash
# SSH to server
ssh "eric smith"@192.168.4.10

# View recent errors
grep -i "error" ~/Library/Logs/BlueBubbles/*.log | tail -50

# View recent warnings
grep -i "warn" ~/Library/Logs/BlueBubbles/*.log | tail -50
```

---

## Escalation

### Level 1: Self-Service
- Service restart (Recovery 1)
- Configuration reset (Recovery 3)
- Reinstall (Recovery 2)

### Level 2: Developer Support
If issues persist after basic recovery:

```bash
# Gather diagnostic information
ssh "eric smith"@192.168.4.10

# System info
uname -a
sw_vers

# BlueBubbles info
curl -s http://127.0.0.1:1234/api/health

# Recent logs
tail -100 ~/Library/Logs/BlueBubbles/*.log

# Process info
ps aux | grep BlueBubbles
```

**Contact:** Developer/Support team with diagnostic output

### Level 3: Escalation Path
1. Review this runbook
2. Try all recovery procedures
3. Gather diagnostic information
4. Contact BlueBubbles support: https://discord.gg/6nrGRHT
5. Provide full diagnostic output

---

## Quick Reference

| Task | Command |
|------|---------|
| Start service | `open /Applications/BlueBubbles.app` |
| Stop service | `killall BlueBubbles` |
| Restart service | `killall BlueBubbles; sleep 2; open /Applications/BlueBubbles.app` |
| Check status | `netstat -an | grep 1234` |
| Test health | `curl -s http://127.0.0.1:1234/api/health` |
| View logs | `tail -f ~/Library/Logs/BlueBubbles/*.log` |
| Backup config | `tar -czf ~/bluebubbles-backup-$(date +%Y%m%d).tar.gz ~/Library/Application\ Support/bluebubbles-server/` |
| Clear cache | `killall BlueBubbles; rm -rf ~/Library/Application\ Support/bluebubbles-server/Cache/*; open /Applications/BlueBubbles.app` |

---

## Related Documentation

- [Deployment Guide](./deployment-bluebubbles.md)
- [OpenClaw Runbook](./runbook-openclaw.md)
- [Service Port Assignments](./service-ports.md)
- [System Runbook](./runbook-system.md)
