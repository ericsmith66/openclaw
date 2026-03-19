# OpenClaw Deployment Guide
**Version:** 1.0  
**Date:** February 27, 2026  
**Server:** 192.168.4.10 (macOS, user: "eric smith")  
**Purpose:** Camera management and surveillance system alongside Homebridge and BlueBubbles

---

## Table of Contents

1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Installation Steps](#installation-steps)
4. [Configuration](#configuration)
5. [Integration with Existing Services](#integration-with-existing-services)
6. [Post-Installation](#post-installation)
7. [Troubleshooting](#troubleshooting)
8. [Maintenance](#maintenance)

---

## Overview

**OpenClaw** is a camera management system (based on OpenCV/Python) for surveillance, motion detection, and video analytics.

### Service Overview

| Service | Purpose | Port | Status |
|---------|---------|------|--------|
| Homebridge | HomeKit bridge | 8080 | Running |
| BlueBubbles | iMessage relay | 1234 | To be deployed |
| OpenClaw | Camera management | TBA | To be deployed |

### Key Features
- ✅ Real-time video streaming
- ✅ Motion detection
- ✅ Object detection (optional)
- ✅ Video recording and storage
- ✅ Web-based management interface
- ✅ Integration with HomeKit (via Homebridge)

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
│                    Camera Sources                           │
│                    (IP Cameras, USB Cameras)                │
└─────────────────────────────────────────────────────────────┘
```

### Network Flow
1. **Cameras** → Stream video to OpenClaw server
2. **OpenClaw** → Process video, detect motion, record
3. **Web UI** → Access management interface
4. **HomeKit** → Stream via Homebridge integration (optional)

---

## Installation Steps

### Prerequisites
- ✅ macOS 14+ running on 192.168.4.10
- ✅ User account: "eric smith" (primary user)
- ✅ Python 3.10+ installed
- ✅ Internet connection
- ✅ Camera sources (IP cameras or USB camera)

### Step 1: Install Dependencies

```bash
# SSH to server
ssh "eric smith"@192.168.4.10

# Install Homebrew (if not already installed)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install required packages
brew install python opencv ffmpeg
```

### Step 2: Clone OpenClaw Repository

```bash
# Navigate to development directory
cd ~/development

# Clone OpenClaw (replace with actual repo URL)
git clone https://github.com/your-org/openclaw.git
cd openclaw
```

### Step 3: Create Virtual Environment

```bash
# Create virtual environment
python3 -m venv venv

# Activate virtual environment
source venv/bin/activate

# Install dependencies
pip install -r requirements.txt
```

### Step 4: Configure OpenClaw

```bash
# Copy example configuration
cp config.example.yaml config.yaml

# Edit configuration
nano config.yaml
# Or use your preferred editor
```

**Configuration Example:**
```yaml
camera:
  devices:
    - name: "Front Door"
      type: "ip"
      url: "rtsp://username:password@192.168.1.100:554/stream"
      port: 8081
      
    - name: "Backyard"
      type: "usb"
      device: "/dev/video0"
      port: 8082

server:
  host: "0.0.0.0"
  port: 8080  # TBA - will be documented later
  
storage:
  path: "/Users/eric smith/openclaw/videos"
  retention_days: 7

motion_detection:
  enabled: true
  sensitivity: 50
  min_duration: 5
```

### Step 5: Test Installation

```bash
# Activate virtual environment (if not already active)
source venv/bin/activate

# Run test
python -m openclaw --test
```

**Expected Output:**
```
[INFO] OpenClaw initialized successfully
[INFO] Detected 2 camera(s)
[INFO] Server ready on port 8080
```

---

## Configuration

### Camera Configuration

#### IP Cameras
```yaml
- name: "Front Door"
  type: "ip"
  url: "rtsp://username:password@192.168.1.100:554/stream"
  port: 8081
  resolution: "1920x1080"
  fps: 30
```

#### USB Cameras
```yaml
- name: "Backyard"
  type: "usb"
  device: "/dev/video0"
  port: 8082
  resolution: "1280x720"
  fps: 15
```

### Motion Detection Configuration

```yaml
motion_detection:
  enabled: true
  sensitivity: 50  # 0-100
  min_duration: 5  # seconds
  cooldown: 10     # seconds between alerts
  zones:           # Define motion zones
    - name: "Driveway"
      points: [[0,0], [100,0], [100,100], [0,100]]
```

### Storage Configuration

```yaml
storage:
  path: "/Users/eric smith/openclaw/videos"
  retention_days: 7
  max_size_gb: 50
  format: "mp4"
  compression: "high"
```

---

## Integration with Existing Services

### Integration with Homebridge

**Option 1: Homebridge Camera Plugin**
- Use `homebridge-camera-ffmpeg` plugin
- Configure OpenClaw as FFmpeg source

**Option 2: HomeKit Native Integration**
- OpenClaw can expose cameras as HomeKit accessories
- Requires Homebridge pairing

### Integration with BlueBubbles

**Current:** No direct integration  
**Future:** Could trigger alerts when motion detected

### Integration with Reverse Proxy

**TBA:** Configure subdomain routing when reverse proxy is deployed

---

## Post-Installation

### Start OpenClaw Service

```bash
# Activate virtual environment
source ~/development/openclaw/venv/bin/activate

# Start OpenClaw
python -m openclaw --config config.yaml
```

### Verify Service is Running

```bash
# Check if process is running
ps aux | grep openclaw

# Check if port is listening (replace with actual port)
netstat -an | grep 8080

# Test web interface
curl -v http://127.0.0.1:8080/api/health
```

### Test Camera Streams

```bash
# Test stream from camera
ffplay "rtsp://username:password@192.168.1.100:554/stream"
```

---

## Troubleshooting

### 🔴 Issue 1: Service Not Starting

**Symptoms:**
- `python -m openclaw` fails with no output
- No process running

**Diagnostic:**
```bash
# Check for errors
python -m openclaw --config config.yaml 2>&1

# Check dependencies
python -c "import cv2; import flask; print('OK')"

# Check permissions
ls -la ~/development/openclaw/
```

**Resolution:**
```bash
# Reinstall dependencies
source venv/bin/activate
pip install --upgrade -r requirements.txt

# Verify installation
python -m openclaw --test
```

---

### 🔴 Issue 2: Camera Not Detected

**Symptoms:**
- OpenClaw starts but shows "0 cameras detected"
- No video streams

**Diagnostic:**
```bash
# Check for available video devices
# For USB cameras
ls -la /dev/video*

# For RTSP streams, test with ffplay
ffplay "rtsp://username:password@192.168.1.100:554/stream"
```

**Resolution:**
```bash
# Check camera configuration
# Verify RTSP URL format
# Verify credentials
# Check network connectivity to IP camera
ping 192.168.1.100
```

---

### 🟡 Issue 3: High CPU Usage

**Symptoms:**
- Mac running hot
- Video processing slow

**Diagnostic:**
```bash
# Check CPU usage
top -o cpu | grep openclaw

# Check if resolution is too high
# Lower resolution in config.yaml
```

**Resolution:**
```bash
# Reduce resolution
# In config.yaml:
resolution: "1280x720"  # Instead of 1920x1080

# Reduce FPS
fps: 15  # Instead of 30

# Disable motion detection temporarily
motion_detection:
  enabled: false
```

---

### 🟡 Issue 4: Storage Full

**Symptoms:**
- OpenClaw stops recording
- "No space left on device" in logs

**Diagnostic:**
```bash
# Check disk usage
df -h /Users/eric\ smith/openclaw/videos

# Check storage usage
du -sh /Users/eric\ smith/openclaw/videos
```

**Resolution:**
```bash
# Clear old recordings
rm -rf /Users/eric\ smith/openclaw/videos/*.mp4

# Or configure retention
# In config.yaml:
storage:
  retention_days: 7
```

---

### 🟡 Issue 5: Web UI Not Accessible

**Symptoms:**
- Service running but web UI not accessible
- Connection refused

**Diagnostic:**
```bash
# Check if process is running
ps aux | grep openclaw

# Check if port is listening
netstat -an | grep 8080

# Check firewall
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate
```

**Resolution:**
```bash
# Check configuration
# Ensure server is bound to 0.0.0.0, not 127.0.0.1
# Check firewall allows connections on port

# Restart service
# Kill and restart
killall python
python -m openclaw --config config.yaml
```

---

## Maintenance

### Update OpenClaw

```bash
# SSH to server
ssh "eric smith"@192.168.4.10

# Navigate to directory
cd ~/development/openclaw

# Pull latest changes
git pull

# Update dependencies
source venv/bin/activate
pip install -r requirements.txt

# Restart service
# Kill existing process and restart
killall python
python -m openclaw --config config.yaml
```

### Backup Configuration

```bash
# Backup config file
cp config.yaml config.yaml.backup-$(date +%Y%m%d)

# Backup camera settings
tar -czf ~/openclaw-backup-$(date +%Y%m%d).tar.gz \
  config.yaml \
  ~/development/openclaw/
```

### Clear Cache

```bash
# Clear OpenClaw cache
rm -rf ~/development/openclaw/cache/*

# Restart service
killall python
python -m openclaw --config config.yaml
```

---

## Quick Reference

| Task | Command |
|------|---------|
| Start service | `cd ~/development/openclaw && source venv/bin/activate && python -m openclaw --config config.yaml` |
| Stop service | `killall python` |
| Check status | `netstat -an \| grep 8080` |
| Test health | `curl -s http://127.0.0.1:8080/api/health` |
| View logs | `tail -f ~/development/openclaw/logs/*.log` |
| Backup config | `tar -czf ~/openclaw-backup-$(date +%Y%m%d).tar.gz config.yaml` |
| Clear cache | `rm -rf ~/development/openclaw/cache/*` |

---

## Related Documentation

- [BlueBubbles Deployment Guide](./deployment-bluebubbles.md)
- [BlueBubbles Runbook](./runbook-bluebubbles.md)
- [Service Port Assignments](./service-ports.md)
- [Reverse Proxy Setup](./reverse-proxy-configuration.md) (Future)

---

## Next Steps

1. Complete OpenClaw installation as described above
2. Configure camera sources
3. Test video streams and recording
4. Configure HomeKit integration (optional)
5. Set up reverse proxy (when ready)

---

**Note:** This is a placeholder deployment guide. Actual OpenClaw repository URL, configuration details, and specific installation steps should be updated once the actual repository is available.
