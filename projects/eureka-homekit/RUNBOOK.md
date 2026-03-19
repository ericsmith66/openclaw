# eureka-homekit Operations Runbook

**Version:** 1.0  
**Last Updated:** February 22, 2026  
**Owner:** Agent Forge Team

---

## Table of Contents

1. [Service Overview](#service-overview)
2. [Architecture](#architecture)
3. [Operations](#operations)
4. [HomeKit-Specific Operations](#homekit-specific-operations)
5. [Health Checks](#health-checks)
6. [Troubleshooting](#troubleshooting)
7. [Logs](#logs)
8. [Emergency Procedures](#emergency-procedures)

---

## Service Overview

### Description
eureka-homekit is a Rails 7 application providing HomeKit integration and automation. It acts as a HomeKit bridge, allowing control of smart home devices and automation through HomeKit protocols.

### Production Environment
- **Server:** 192.168.4.253 (M3 Ultra)
- **User:** ericsmith66
- **Path:** `/Users/ericsmith66/Development/eureka-homekit`
- **Port:** 3001
- **Environment:** production
- **Network:** Host networking (required for HomeKit mDNS/Bonjour discovery)

### Key Technologies
- **Framework:** Ruby on Rails 7.2
- **Ruby Version:** 3.3.0
- **HomeKit:** HAP (HomeKit Accessory Protocol)
- **Discovery:** mDNS/Bonjour
- **Database:** SQLite (embedded) or PostgreSQL

---

## Architecture

### HomeKit Protocol Stack
```
HomeKit iOS App
      ↓
   Bonjour/mDNS Discovery
      ↓
   HAP over HTTP/TLS
      ↓
eureka-homekit Rails App
      ↓
Device Controllers
```

### Service Components
```
Puma (Port 3001)
  ├── Rails Application
  ├── HomeKit Bridge Service
  ├── Device Discovery (mDNS)
  └── Accessory Management
```

### Network Requirements
- **Port 3001:** HTTP API
- **Port 51827:** HomeKit HAP (configurable)
- **mDNS:** Service discovery (UDP 5353)
- **Network Mode:** Host networking (not bridged)

---

## Operations

### Start Service

#### Development Mode
```bash
cd /Users/ericsmith66/Development/eureka-homekit
bin/dev
```

#### Production Mode
```bash
cd /Users/ericsmith66/Development/eureka-homekit
bin/prod
```

Using launchd (if configured):
```bash
launchctl start gui/$(id -u)/com.agentforge.eureka-homekit
```

### Stop Service

Using launchd:
```bash
launchctl stop gui/$(id -u)/com.agentforge.eureka-homekit
```

Manual process kill:
```bash
# Find Puma process
ps aux | grep puma | grep eureka

# Kill gracefully
kill -TERM <PID>

# Force kill if necessary
kill -9 <PID>
```

### Restart Service

Using launchd:
```bash
launchctl kickstart -k gui/$(id -u)/com.agentforge.eureka-homekit
```

Manual restart:
```bash
cd /Users/ericsmith66/Development/eureka-homekit
pkill -TERM -f "eureka-homekit"
sleep 2
bin/prod
```

### Check Service Status

```bash
# Check if process is running
ps aux | grep puma | grep eureka

# Check service via launchd
launchctl list | grep eureka-homekit

# Check port binding
lsof -i :3001

# Check HomeKit HAP port (if configured)
lsof -i :51827
```

---

## HomeKit-Specific Operations

### Verify mDNS/Bonjour Discovery

Check if service is discoverable on the network:

```bash
# List HomeKit accessories on network
dns-sd -B _hap._tcp

# Check specific service
dns-sd -L "Eureka HomeKit" _hap._tcp
```

Expected output:
```
Browsing for _hap._tcp
Timestamp     A/R  Flags  if Domain  Service Type         Instance Name
...
ADD           ...        _hap._tcp.  local.  Eureka HomeKit
```

### Pairing with HomeKit

1. **Ensure service is running** on production server
2. **Open Home app** on iOS device
3. **Tap "Add Accessory"**
4. **Scan QR code** or enter setup code (8-digit PIN)
5. **Follow pairing prompts**

### Reset HomeKit Pairing

If pairing is corrupt or you need to re-pair:

```bash
# Stop service
launchctl stop gui/$(id -u)/com.agentforge.eureka-homekit

# Clear pairing data (adjust path as needed)
rm -f /Users/ericsmith66/Development/eureka-homekit/tmp/homekit_persist.json

# Restart service
launchctl start gui/$(id -u)/com.agentforge.eureka-homekit

# Re-pair using Home app
```

### List Paired Devices

```bash
cd /Users/ericsmith66/Development/eureka-homekit

# Via Rails console
bin/rails console -e production

# Inside console:
# HomeKit.paired_devices (or equivalent command based on your app)
```

### Trigger Automation

```bash
# Via API (if exposed)
curl -X POST http://192.168.4.253:3001/automations/morning_routine

# Via HomeKit
# Use Home app → Automations tab
```

---

## Health Checks

### Application Health

```bash
curl http://192.168.4.253:3001/health
```

**Expected response:**
```json
{"status": "ok"}
```

### HomeKit Service Health

```bash
# Check if HAP service is responding
curl -k https://192.168.4.253:51827/

# Check mDNS service advertisement
dns-sd -B _hap._tcp
```

### Service Health

```bash
# Check process
ps aux | grep puma | grep eureka

# Check port
lsof -i :3001

# Check logs
tail -100 /Users/ericsmith66/Development/eureka-homekit/log/production.log
```

---

## Troubleshooting

### Service Won't Start

**Symptoms:** Puma process exits immediately or fails to bind to port

**Diagnostic steps:**

1. Check logs:
   ```bash
   tail -100 log/production.log
   ```

2. Check port availability:
   ```bash
   lsof -i :3001
   ```

3. Try starting manually:
   ```bash
   RAILS_ENV=production bin/rails server -p 3001
   ```

4. Check for missing dependencies:
   ```bash
   bundle check
   ```

### HomeKit Discovery Fails

**Symptoms:** Device not appearing in Home app

**Common causes:**
- mDNS/Bonjour not working
- Firewall blocking port 5353 (UDP)
- Service not advertising properly
- iOS device on different network/VLAN

**Diagnostic steps:**

1. Verify mDNS service is running:
   ```bash
   dns-sd -B _hap._tcp
   ```

2. Check firewall settings:
   ```bash
   # macOS firewall status
   sudo /usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate
   ```

3. Verify network connectivity:
   ```bash
   ping 192.168.4.253
   ```

4. Check if service is advertising:
   ```bash
   dns-sd -L "Eureka HomeKit" _hap._tcp
   ```

5. Restart service:
   ```bash
   launchctl kickstart -k gui/$(id -u)/com.agentforge.eureka-homekit
   ```

### Pairing Fails

**Symptoms:** Home app shows "Unable to Add Accessory"

**Common causes:**
- Wrong setup code
- Service not responding
- Previous pairing data conflicts
- Network issues

**Diagnostic steps:**

1. Verify service is running:
   ```bash
   ps aux | grep eureka
   ```

2. Check logs for pairing errors:
   ```bash
   tail -100 log/production.log | grep -i pair
   ```

3. Reset pairing data (see "Reset HomeKit Pairing" above)

4. Verify setup code is correct (check app configuration)

5. Try pairing from different iOS device

### Device Control Not Working

**Symptoms:** Devices not responding in Home app

**Diagnostic steps:**

1. Check service health:
   ```bash
   curl http://192.168.4.253:3001/health
   ```

2. Check device connectivity:
   ```bash
   # Check device-specific endpoints (adjust as needed)
   curl http://192.168.4.253:3001/devices/status
   ```

3. Check logs for device errors:
   ```bash
   tail -100 log/production.log | grep -i device
   ```

4. Restart service:
   ```bash
   launchctl kickstart -k gui/$(id -u)/com.agentforge.eureka-homekit
   ```

### High Memory Usage

**Symptoms:** Service consuming excessive RAM

**Diagnostic steps:**

1. Check memory usage:
   ```bash
   ps aux | grep puma | grep eureka
   ```

2. Check for memory leaks in logs:
   ```bash
   grep -i "memory" log/production.log
   ```

3. Restart service to free memory:
   ```bash
   launchctl kickstart -k gui/$(id -u)/com.agentforge.eureka-homekit
   ```

4. Monitor memory over time:
   ```bash
   while true; do ps aux | grep puma | grep eureka; sleep 60; done
   ```

---

## Logs

### Application Logs

**Production log:**
```bash
tail -f /Users/ericsmith66/Development/eureka-homekit/log/production.log
```

**Puma logs:**
```bash
tail -f /Users/ericsmith66/Development/eureka-homekit/log/puma.stdout.log
tail -f /Users/ericsmith66/Development/eureka-homekit/log/puma.stderr.log
```

### HomeKit-Specific Logs

**HAP protocol logs:**
```bash
# Filter for HomeKit-related entries
tail -f log/production.log | grep -i "homekit\|hap\|pairing"
```

**Device interaction logs:**
```bash
tail -f log/production.log | grep -i "device\|accessory"
```

### System Logs

**macOS system log (for mDNS issues):**
```bash
log stream --predicate 'subsystem == "com.apple.mDNSResponder"' --level debug
```

---

## Emergency Procedures

### Complete Service Restart

If service is unresponsive or behaving abnormally:

```bash
# 1. Stop service
launchctl stop gui/$(id -u)/com.agentforge.eureka-homekit

# 2. Kill any remaining processes
pkill -9 -f "eureka-homekit"

# 3. Wait for cleanup
sleep 5

# 4. Start service
launchctl start gui/$(id -u)/com.agentforge.eureka-homekit

# 5. Verify health
curl http://192.168.4.253:3001/health
```

**Estimated downtime:** 10-15 seconds

### Reset All HomeKit Pairings

If all HomeKit functionality is broken:

```bash
# 1. Stop service
launchctl stop gui/$(id -u)/com.agentforge.eureka-homekit

# 2. Backup pairing data
cp /Users/ericsmith66/Development/eureka-homekit/tmp/homekit_persist.json \
   /Users/ericsmith66/Development/eureka-homekit/tmp/homekit_persist.json.backup

# 3. Remove pairing data
rm -f /Users/ericsmith66/Development/eureka-homekit/tmp/homekit_persist.json

# 4. Start service
launchctl start gui/$(id -u)/com.agentforge.eureka-homekit

# 5. Re-pair all iOS devices
# Open Home app → Add Accessory → Scan code
```

**Estimated time:** 15-30 minutes (including re-pairing)

### Network Isolation Recovery

If network issues prevent discovery:

```bash
# 1. Check network interface status
ifconfig en0

# 2. Restart mDNSResponder
sudo killall -HUP mDNSResponder

# 3. Restart eureka-homekit
launchctl kickstart -k gui/$(id -u)/com.agentforge.eureka-homekit

# 4. Verify discovery
dns-sd -B _hap._tcp
```

---

## Deployment

### Manual Deployment

**Note:** Deployment for eureka-homekit should be done carefully as it may disconnect HomeKit devices temporarily.

```bash
# 1. SSH to production
ssh ericsmith66@192.168.4.253

# 2. Navigate to app directory
cd Development/eureka-homekit

# 3. Pull latest code
git pull origin main

# 4. Install dependencies
bundle install

# 5. Run migrations (if needed)
RAILS_ENV=production bin/rails db:migrate

# 6. Restart service
launchctl kickstart -k gui/$(id -u)/com.agentforge.eureka-homekit

# 7. Verify health
curl http://localhost:3001/health

# 8. Verify HomeKit discovery
dns-sd -B _hap._tcp
```

**Estimated downtime:** 15-30 seconds

---

## Appendix

### File Locations

| File/Directory | Purpose |
|---------------|---------|
| `/Users/ericsmith66/Development/eureka-homekit` | Application root |
| `log/production.log` | Application logs |
| `tmp/homekit_persist.json` | HomeKit pairing data |
| `tmp/pids/puma.pid` | Puma process ID |

### Network Ports

| Port | Protocol | Purpose |
|------|----------|---------|
| 3001 | HTTP | Rails API |
| 51827 | TCP | HomeKit HAP |
| 5353 | UDP | mDNS/Bonjour |

### Emergency Contacts

| Role | Contact | Availability |
|------|---------|--------------|
| Primary | Eric Smith | 24/7 |
| Secondary | TBD | Business hours |

### Useful Commands

```bash
# Check all HomeKit services on network
dns-sd -B _hap._tcp

# Monitor mDNS traffic
sudo tcpdump -i any port 5353

# Check Rails routes
RAILS_ENV=production bin/rails routes | grep homekit

# Rails console (for debugging)
RAILS_ENV=production bin/rails console
```

---

**Document End**

*For updates to this runbook, contact the Agent Forge team.*
