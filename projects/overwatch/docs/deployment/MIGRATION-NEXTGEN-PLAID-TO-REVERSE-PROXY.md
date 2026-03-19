# NextGen Plaid → Reverse Proxy Migration Plan

**Date Created:** February 27, 2026  
**Date Executed:** February 28, 2026  
**Target Infrastructure:** highground-rev-proxy (Cloudflare → Nginx → Rails)  
**Current Infrastructure:** Direct access with PF redirect (port 80 → 3000)  
**Status:** ✅ **COMPLETED** - Production deployment successful

---

## 🎉 Execution Summary (February 28, 2026)

### Deployment Results
**Status:** ✅ **Successfully deployed to production**  
**Execution Time:** ~2 hours  
**Downtime:** Zero (dual-path operation maintained)

### Services Deployed
| Service | URL | Status | Backend |
|---------|-----|--------|---------|
| nextgen-plaid | nextgen.higroundsolutions.com | ✅ Live | 192.168.4.253:3000 |
| api alias | api.higroundsolutions.com | ✅ Live | 192.168.4.253:3000 |
| eureka-homekit | eureka.higroundsolutions.com | ✅ Coming Soon | Static HTML |
| agent-forge | agent-forge.higroundsolutions.com | ✅ Coming Soon | Static HTML |
| bluebubbles | blue.higroundsolutions.com | ✅ Coming Soon | Static HTML |

### macOS-Specific Adaptations
During deployment on macOS (Homebrew Nginx), the following platform-specific changes were required:

1. **Nginx Paths:**
   - Config location: `/opt/homebrew/etc/nginx/` (not `/etc/nginx/`)
   - Sites: `/opt/homebrew/etc/nginx/sites-available/` and `sites-enabled/`
   - SSL certs: `/opt/homebrew/etc/nginx/ssl/`
   - Logs: `/opt/homebrew/var/log/nginx/`

2. **Configuration Changes:**
   - User: `nobody` (not `nginx`)
   - Event model: `kqueue` (not `epoll`)
   - Mime types path: `/opt/homebrew/etc/nginx/mime.types`

3. **Upstream Configuration:**
   - Changed from `127.0.0.1:3000` to `192.168.4.253:3000`
   - **Reason:** PF redirect on localhost created routing loops
   - Puma binds to `0.0.0.0:3000` so LAN IP works correctly

4. **Process Management:**
   - Start: `sudo nginx`
   - Reload: `sudo nginx -s reload`
   - Stop: `sudo nginx -s stop`
   - No systemctl (Linux-only)

### Current State
- ✅ Nginx running on port 443 (SSL termination with Cloudflare Origin Certificate)
- ✅ UDM-SE port forwarding: 443 → 192.168.4.253:443
- ✅ Cloudflare SSL mode: Full (Strict)
- ✅ Firewall rules: Cloudflare IPs only → port 443
- ⚠️ Legacy PF redirect still active (port 80 → 3000) - will remove after 2 weeks
- ⚠️ Legacy port forward still active (port 80) - will remove after 2 weeks

### Post-Deployment Monitoring
**Monitor for 2 weeks before removing legacy infrastructure:**
```bash
# Check Nginx status
ps aux | grep nginx

# Monitor logs
sudo tail -f /opt/homebrew/var/log/nginx/nextgen-access.log
sudo tail -f /opt/homebrew/var/log/nginx/error.log

# Test endpoints
curl -I https://nextgen.higroundsolutions.com/health
curl -I https://api.higroundsolutions.com/health
```

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [Current State Analysis](#current-state-analysis)
3. [Target Architecture](#target-architecture)
4. [Migration Strategy](#migration-strategy)
5. [Pre-Migration Checklist](#pre-migration-checklist)
6. [Migration Steps](#migration-steps)
7. [Rollback Procedures](#rollback-procedures)
8. [Testing & Verification](#testing--verification)
9. [Post-Migration Tasks](#post-migration-tasks)
10. [Risk Assessment](#risk-assessment)

---

## Executive Summary

### Objective
Migrate nextgen-plaid from direct access (with PF port redirect) to a production-grade Nginx reverse proxy with Cloudflare CDN/WAF integration.

### Benefits
- **Security**: Cloudflare WAF, DDoS protection, SSL/TLS termination
- **Performance**: HTTP/2, compression, caching, rate limiting
- **Observability**: Centralized logging, real IP tracking
- **Scalability**: Foundation for multi-app deployment
- **Reliability**: Health checks, automatic failover
- **WebSocket Support**: Proper handling of ActionCable connections

### Timeline
- **Planning & Review**: 1-2 hours
- **Preparation**: 2-4 hours
- **Migration Execution**: 1-2 hours
- **Testing & Verification**: 1-2 hours
- **Total**: 5-10 hours over 1-2 days

### Risk Level
🟡 **Medium** - Requires DNS changes, firewall reconfiguration, and service restarts. Rollback procedures are straightforward.

---

## Current State Analysis

### Infrastructure Overview

**Server:** 192.168.4.253 (M3 Ultra, macOS)  
**Application:** nextgen-plaid (Rails 8.1.1)  
**Port Configuration:** 
- Application runs on port 3000
- PF (Packet Filter) redirects port 80 → 3000

**Current Traffic Flow:**
```
Client
  ↓
192.168.4.253:80 (PF redirect)
  ↓
192.168.4.253:3000 (Puma/Rails)
```

### PF Configuration

**File:** `/etc/pf.conf`
```
rdr-anchor "com.nextgen.plaid"
anchor "com.nextgen.plaid"
load anchor "com.nextgen.plaid" from "/etc/pf.anchors/com.nextgen.plaid"
```

**File:** `/etc/pf.anchors/com.nextgen.plaid`
```
rdr pass on lo0 inet proto tcp from any to any port 80 -> 127.0.0.1 port 3000
rdr pass on en0 inet proto tcp from any to any port 80 -> 192.168.4.253 port 3000
```

### Limitations of Current Setup
- ❌ No SSL/TLS encryption
- ❌ No CDN/caching layer
- ❌ No DDoS protection
- ❌ No rate limiting
- ❌ No request logging/analytics
- ❌ No real IP tracking (all requests appear local)
- ❌ No health check/monitoring integration
- ❌ Single point of failure
- ❌ Port 80 only (no HTTPS)

---

## Target Architecture

### Infrastructure Overview

**Traffic Flow:**
```
Internet
  ↓
Cloudflare CDN/WAF (SSL termination, DDoS protection)
  ↓
Nginx Reverse Proxy on 192.168.4.253:443
  ↓
nextgen-plaid on 127.0.0.1:3000
```

### Components

#### 1. Cloudflare
- **DNS**: A record pointing to server public IP
- **SSL Mode**: Full (Strict) with Origin Certificate
- **Proxy**: Enabled (orange cloud)
- **Features**: CDN, WAF, DDoS protection, analytics

#### 2. Nginx Reverse Proxy
- **Location**: Same server (192.168.4.253)
- **Ports**: 80 (HTTP redirect), 443 (HTTPS)
- **Features**:
  - SSL/TLS termination with Cloudflare Origin Certificate
  - Real IP restoration from CF-Connecting-IP header
  - WebSocket support for ActionCable
  - Rate limiting (10 req/s general, 30 req/s API)
  - Compression (gzip)
  - Security headers (HSTS, X-Frame-Options, CSP)
  - Extended timeouts (300s for long operations)
  - Per-app access/error logging
  - Health check endpoint monitoring

#### 3. Rails Application
- **No changes required** to application code
- **Port**: Remains on 3000 (localhost only)
- **Process management**: Existing launchd LaunchAgents unchanged
- **Environment**: Existing .env.production unchanged

### Configuration Files

From `highground-rev-proxy` project:
- `nginx/nginx.conf` - Main Nginx configuration
- `nginx/sites-available/nextgen-plaid.conf` - NextGen Plaid site config
- `ssl/cloudflare-origin.pem` - SSL certificate
- `ssl/cloudflare-origin.key` - SSL private key

---

## Migration Strategy

### Approach: In-Place Migration with Rollback

**Strategy:** Replace PF redirect with Nginx reverse proxy on the same server.

**Key Principles:**
1. **Minimize downtime**: Use zero-downtime Nginx reload where possible
2. **Reversible**: Keep PF configuration backed up for instant rollback
3. **Test before commit**: Verify Nginx config before disabling PF
4. **Phased approach**: Enable Nginx first, then disable PF
5. **Monitoring**: Watch logs during migration

### Migration Windows

**Option 1: Maintenance Window (Recommended)**
- Schedule 2-hour window during low-traffic period (e.g., 2-4 AM)
- Brief downtime acceptable (5-10 minutes)
- Full testing before declaring success

**Option 2: Zero-Downtime Migration**
- Run Nginx on alternate port first
- Test thoroughly
- Switch traffic via DNS/firewall
- Slightly more complex but zero user impact

### Decision Required

**Question 1:** Which server will run the reverse proxy?
- [ ] Same server (192.168.4.253) - **Recommended for simplicity**
- [ ] Separate server - **Better for production, requires additional hardware**

**Question 2:** DNS/Public Access Strategy?
- [ ] Cloudflare Tunnel (existing setup)
- [ ] Direct public IP routing (requires firewall changes on UDM-SE)
- [ ] Keep localhost-only for now (testing phase)

**Question 3:** Migration Timing?
- [ ] Maintenance window (brief downtime acceptable)
- [ ] Zero-downtime migration (more complex)

---

## Pre-Migration Checklist

### Phase 1: Documentation & Planning (Day 1)

- [ ] **Review this migration plan with stakeholders**
- [ ] **Confirm domain name**: `nextgen-plaid.yourdomain.com` (update in configs)
- [ ] **Decide on migration strategy**: Maintenance window vs. zero-downtime
- [ ] **Schedule migration window** (if using maintenance approach)
- [ ] **Notify users** (if applicable)

### Phase 2: Preparation (Day 1-2)

#### A. Cloudflare Setup
- [ ] **Generate Cloudflare Origin Certificate**
  - Log into Cloudflare Dashboard
  - Navigate to: SSL/TLS → Origin Server → Create Certificate
  - Select RSA (2048), 15-year validity
  - Download certificate (`.pem`) and private key (`.key`)
  - Store securely (password manager, encrypted storage)

- [ ] **Configure DNS** (but don't enable proxy yet)
  - Create A record: `nextgen-plaid.yourdomain.com` → `192.168.4.253` (or public IP)
  - Set TTL to 60 seconds (for easy rollback)
  - Keep proxy disabled (gray cloud) during testing

- [ ] **Configure SSL/TLS Settings**
  - SSL/TLS mode: Full (Strict)
  - Minimum TLS Version: 1.2
  - Automatic HTTPS Rewrites: Enabled

#### B. Server Preparation
- [ ] **Backup current configuration**
  ```bash
  ssh ericsmith66@192.168.4.253
  sudo cp /etc/pf.conf /etc/pf.conf.backup-$(date +%Y%m%d)
  sudo cp /etc/pf.anchors/com.nextgen.plaid /etc/pf.anchors/com.nextgen.plaid.backup-$(date +%Y%m%d)
  ```

- [ ] **Install Nginx** (if not already installed)
  ```bash
  brew install nginx
  ```

- [ ] **Check current ports**
  ```bash
  netstat -an | grep LISTEN | grep -E ':(80|443|3000) '
  # Verify: port 3000 (Puma), port 80 (should show LISTEN if PF is active)
  ```

- [ ] **Verify disk space**
  ```bash
  df -h /var/log
  # Ensure >5GB free for logs
  ```

#### C. Configuration Preparation
- [ ] **Clone highground-rev-proxy to production server**
  ```bash
  ssh ericsmith66@192.168.4.253
  cd /Users/ericsmith66/Development
  git clone <repo-url> highground-rev-proxy
  cd highground-rev-proxy
  ```

- [ ] **Update domain names in configs**
  ```bash
  # Edit nginx/sites-available/nextgen-plaid.conf
  # Replace: nextgen-plaid.yourdomain.com → nextgen-plaid.example.com
  ```

- [ ] **Install SSL certificates**
  ```bash
  mkdir -p ssl/
  # Upload cloudflare-origin.pem and cloudflare-origin.key
  chmod 644 ssl/cloudflare-origin.pem
  chmod 600 ssl/cloudflare-origin.key
  ```

- [ ] **Test Nginx configuration** (dry run)
  ```bash
  sudo nginx -t -c /Users/ericsmith66/Development/highground-rev-proxy/nginx/nginx.conf
  ```

#### D. Testing Environment
- [ ] **Set up local testing** (on dev machine)
  - Add entry to `/etc/hosts`: `192.168.4.253 nextgen-plaid.test.local`
  - Verify can reach: `curl http://192.168.4.253:3000/health?token=<TOKEN>`

- [ ] **Prepare monitoring**
  - Open terminal windows for log tailing
  - Prepare health check commands

#### E. Rollback Preparation
- [ ] **Document current PF status**
  ```bash
  ssh ericsmith66@192.168.4.253
  sudo pfctl -s nat > /tmp/pf-nat-before-migration.txt
  sudo pfctl -s rules > /tmp/pf-rules-before-migration.txt
  ```

- [ ] **Test rollback procedure** (on paper, don't execute yet)
  - Write down exact commands to disable Nginx and re-enable PF
  - Keep in accessible location during migration

---

## Migration Steps

### Phase 1: Install Nginx (Zero Impact)

**Duration:** 30-60 minutes  
**Risk:** 🟢 Low - No service interruption

```bash
# SSH to production server
ssh ericsmith66@192.168.4.253

# Navigate to project directory
cd /Users/ericsmith66/Development/highground-rev-proxy

# Run deployment script (this will NOT start Nginx yet)
sudo ./scripts/deploy.sh

# Verify files copied
ls -l /etc/nginx/nginx.conf
ls -l /etc/nginx/sites-available/nextgen-plaid.conf
ls -l /etc/nginx/ssl/

# DO NOT start Nginx yet - we'll test first
```

**Verification:**
```bash
# Nginx should NOT be running yet
ps aux | grep nginx | grep -v grep
# (Should return nothing)

# Application should still be accessible on port 80
curl http://localhost/health?token=<HEALTH_TOKEN>
# (Should return {"status":"ok"})
```

---

### Phase 2: Test Nginx Configuration (Alternate Port)

**Duration:** 30-60 minutes  
**Risk:** 🟢 Low - Testing only

**Strategy:** Start Nginx on alternate ports (8080, 8443) to test without disrupting production.

```bash
# Edit nginx.conf temporarily to use alternate ports
sudo nano /etc/nginx/sites-available/nextgen-plaid.conf

# Change:
#   listen 80;        → listen 8080;
#   listen 443 ...;   → listen 8443 ssl http2;

# Test configuration
sudo nginx -t

# Start Nginx
sudo brew services start nginx
# OR
sudo nginx

# Verify Nginx started
ps aux | grep nginx
sudo lsof -iTCP:8080 -sTCP:LISTEN
sudo lsof -iTCP:8443 -sTCP:LISTEN
```

**Test alternate port access:**
```bash
# From production server (localhost)
curl -v http://localhost:8080/health?token=<HEALTH_TOKEN>

# Should see:
# - HTTP/1.1 200 OK
# - {"status":"ok"}

# Test HTTPS (ignore cert warning for localhost)
curl -k https://localhost:8443/health?token=<HEALTH_TOKEN>
```

**Test from dev machine:**
```bash
# From development machine
curl -v http://192.168.4.253:8080/health?token=<HEALTH_TOKEN>
curl -k https://192.168.4.253:8443/health?token=<HEALTH_TOKEN>

# Test WebSocket upgrade headers
curl -v -H "Upgrade: websocket" -H "Connection: Upgrade" \
  http://192.168.4.253:8080/cable
# Should see: Upgrade headers passed through
```

**Verify Nginx logs:**
```bash
sudo tail -f /var/log/nginx/nextgen-plaid-access.log
sudo tail -f /var/log/nginx/nextgen-plaid-error.log
sudo tail -f /var/log/nginx/error.log
```

**If tests pass:**
```bash
# Stop Nginx
sudo brew services stop nginx
# OR
sudo nginx -s quit

# Restore original port configuration
sudo nano /etc/nginx/sites-available/nextgen-plaid.conf
# Change back to ports 80 and 443

# Test configuration with correct ports
sudo nginx -t
```

---

### Phase 3: Switch to Nginx (Production Cutover)

**Duration:** 10-20 minutes  
**Risk:** 🟡 Medium - Production traffic will be interrupted briefly  
**Downtime:** 5-10 minutes expected

#### A. Pre-Cutover Verification

```bash
# 1. Verify application is healthy
curl http://localhost/health?token=<HEALTH_TOKEN>
# Must return: {"status":"ok"}

# 2. Verify Nginx config is ready
sudo nginx -t
# Must show: test is successful

# 3. Check no processes on ports 80/443
sudo lsof -iTCP:80 -sTCP:LISTEN
sudo lsof -iTCP:443 -sTCP:LISTEN
# Should only show PF, not nginx

# 4. Backup database (optional but recommended)
cd /Users/ericsmith66/Development/nextgen-plaid
./scripts/backup-database.sh
```

#### B. Disable PF Redirect

```bash
# Disable PF anchors for nextgen-plaid
sudo pfctl -a com.nextgen.plaid -F all

# Verify PF rules removed
sudo pfctl -s nat | grep 3000
# Should return nothing

# Verify port 80 is now free
sudo lsof -iTCP:80 -sTCP:LISTEN
# Should return nothing
```

**⚠️ WARNING: At this point, the application is NOT accessible on port 80!**

#### C. Start Nginx

```bash
# Start Nginx
sudo brew services start nginx
# OR
sudo nginx

# Verify Nginx is running
ps aux | grep nginx
# Should show: master process and worker processes

# Verify ports are bound
sudo lsof -iTCP:80 -sTCP:LISTEN
sudo lsof -iTCP:443 -sTCP:LISTEN
# Should show: nginx processes

# Check for errors
sudo tail -20 /var/log/nginx/error.log
```

#### D. Immediate Verification

```bash
# 1. Test HTTP (should redirect to HTTPS)
curl -v http://localhost/
# Should see: 301 Moved Permanently → https://

# 2. Test HTTPS health check
curl -k https://localhost/health?token=<HEALTH_TOKEN>
# Should return: {"status":"ok"}

# 3. Test full page load
curl -k https://localhost/ -H "Host: nextgen-plaid.yourdomain.com"
# Should return: HTML page

# 4. Monitor logs in real-time
sudo tail -f /var/log/nginx/nextgen-plaid-access.log &
sudo tail -f /var/log/nginx/nextgen-plaid-error.log &

# 5. Test from external machine (dev machine)
curl -k https://192.168.4.253/health?token=<HEALTH_TOKEN>
```

**If verification passes:** Proceed to Phase 4  
**If verification fails:** Execute rollback (see Rollback Procedures section)

---

### Phase 4: Enable Cloudflare (Optional)

**Duration:** 10-20 minutes  
**Risk:** 🟡 Medium - DNS propagation can cause temporary issues

**Prerequisites:**
- Nginx is running and accessible via HTTPS
- Cloudflare Origin Certificate is installed
- DNS record exists (gray cloud)

#### A. Enable Cloudflare Proxy

```bash
# In Cloudflare Dashboard:
# 1. Go to DNS settings
# 2. Find A record for nextgen-plaid.yourdomain.com
# 3. Click the cloud icon to enable proxy (turn orange)
# 4. Save
```

**Wait for DNS propagation:**
```bash
# Check DNS resolution (from dev machine)
dig nextgen-plaid.yourdomain.com +short
# Should show: Cloudflare IP (not your server IP)

# Test via domain name
curl -v https://nextgen-plaid.yourdomain.com/health?token=<HEALTH_TOKEN>
# Should return: {"status":"ok"}
# Response headers should show: cf-ray, cf-cache-status
```

#### B. Verify Cloudflare Features

```bash
# Check real IP is being logged (from dev machine)
curl https://nextgen-plaid.yourdomain.com/health?token=<HEALTH_TOKEN>

# On server, check logs:
sudo tail -1 /var/log/nginx/nextgen-plaid-access.log
# Should show: YOUR real IP (not Cloudflare IP)
# Should show: cf-ray header and cf-ipcountry
```

#### C. Configure Cloudflare Settings

In Cloudflare Dashboard:

**SSL/TLS:**
- Mode: Full (Strict) ✓
- Minimum TLS Version: 1.2 ✓
- Automatic HTTPS Rewrites: Enabled ✓

**Speed:**
- Auto Minify: JavaScript, CSS, HTML (optional)
- Brotli: Enabled (optional)

**Caching:**
- Caching Level: Standard (or higher based on app requirements)
- Browser Cache TTL: Respect Existing Headers

**Security:**
- Security Level: Medium (adjust based on traffic patterns)
- Challenge Passage: 30 minutes
- Bot Fight Mode: Enabled (optional)

**Firewall:**
- Create rate limiting rule (optional):
  - If requests > 100 per 10 seconds
  - Then block for 1 hour

---

### ✅ Actual Execution Log (February 28, 2026)

**Strategy Change:** Instead of the planned phases above, we executed a **zero-downtime parallel deployment** strategy:

#### What We Actually Did

**Phase 1: Install & Configure Nginx (macOS Homebrew)**
```bash
# Installed Nginx via Homebrew
brew install nginx  # Version 1.29.5

# Synced configs via rsync (GitHub SSH keys not on production)
rsync -avz highground-rev-proxy/ ericsmith66@192.168.4.253:~/Development/highground-rev-proxy/

# Created directories at Homebrew paths
sudo mkdir -p /opt/homebrew/etc/nginx/{sites-available,sites-enabled,ssl,html}

# Copied configs
sudo cp nginx/nginx.conf /opt/homebrew/etc/nginx/nginx.conf
sudo cp nginx/sites-available/*.conf /opt/homebrew/etc/nginx/sites-available/
sudo cp ssl/cloudflare-origin.{pem,key} /opt/homebrew/etc/nginx/ssl/
sudo cp html/coming-soon.html /opt/homebrew/etc/nginx/html/
```

**Phase 2: macOS-Specific Fixes**
```bash
# Fixed user (nginx → nobody)
sudo sed -i '' 's/^user nginx;/user nobody;/' /opt/homebrew/etc/nginx/nginx.conf

# Fixed event model (epoll → kqueue)
sudo sed -i '' 's/use epoll;/use kqueue;/' /opt/homebrew/etc/nginx/nginx.conf

# Fixed mime.types path
sudo sed -i '' 's|/etc/nginx/mime.types|/opt/homebrew/etc/nginx/mime.types|g' /opt/homebrew/etc/nginx/nginx.conf

# Fixed upstream to avoid PF redirect loop
sudo sed -i '' 's|server 127.0.0.1:3000|server 192.168.4.253:3000|' /opt/homebrew/etc/nginx/nginx.conf
```

**Phase 3: Create Symlinks & Start Nginx**
```bash
# Create symlinks for all 4 services
sudo ln -sf /opt/homebrew/etc/nginx/sites-available/nextgen-plaid.conf /opt/homebrew/etc/nginx/sites-enabled/
sudo ln -sf /opt/homebrew/etc/nginx/sites-available/eureka-homekit.conf /opt/homebrew/etc/nginx/sites-enabled/
sudo ln -sf /opt/homebrew/etc/nginx/sites-available/agent-forge.conf /opt/homebrew/etc/nginx/sites-enabled/
sudo ln -sf /opt/homebrew/etc/nginx/sites-available/bluebubbles.conf /opt/homebrew/etc/nginx/sites-enabled/

# Test config
sudo nginx -t  # ✅ Passed

# Start Nginx
sudo nginx
```

**Phase 4: UDM-SE Firewall Configuration**
- Created "cloudflare-ssl-tunnel" port forward: 443 → 192.168.4.253:443
- Created firewall rule: Allow Cloudflare IPs → 192.168.4.253:443
- **Kept existing port 80 rules active** (dual-path operation)

**Phase 5: Cloudflare SSL Mode**
- Switched from **Flexible** → **Full (Strict)**
- DNS propagation: ~2 minutes
- All 4 services immediately accessible

#### Testing Results
```bash
# nextgen.higroundsolutions.com
curl -I https://nextgen.higroundsolutions.com/health
# ✅ HTTP/2 401 (auth required - expected)

# api.higroundsolutions.com (alias)
curl -I https://api.higroundsolutions.com/health
# ✅ HTTP/2 401 (Plaid OAuth compatible)

# eureka.higroundsolutions.com
curl -I https://eureka.higroundsolutions.com/
# ✅ HTTP/2 200 (Coming Soon page)

# agent-forge.higroundsolutions.com
curl -I https://agent-forge.higroundsolutions.com/
# ✅ HTTP/2 200 (Coming Soon page)

# blue.higroundsolutions.com
curl -I https://blue.higroundsolutions.com/
# ✅ HTTP/2 200 (Coming Soon page)
```

#### Why No Downtime?
- Port 80 path stayed active during entire migration
- Port 443 path added in parallel
- Cloudflare SSL switch was instant (no DNS change needed)
- PF redirect remains active as fallback

#### Key Lessons Learned
1. **Homebrew Nginx paths differ from Linux** - all configs must use `/opt/homebrew/etc/nginx/`
2. **PF redirect creates localhost routing loops** - use LAN IP (`192.168.4.253:3000`) instead
3. **macOS uses kqueue, not epoll** - event model must be platform-specific
4. **Dual-path is safer than cutover** - keep legacy path active for 2 weeks

---

### Phase 5: Update Application Configuration

**Duration:** 10-20 minutes  
**Risk:** 🟢 Low - Optional improvements

#### A. Update Health Check Token (Optional)

Consider using a different token for external health checks vs. Cloudflare:

```bash
# In .env.production, add:
# CLOUDFLARE_HEALTH_TOKEN=<new-secure-token>

# Update Rails health controller to accept either token
```

#### B. Configure Trusted Proxies (Rails)

Update `config/environments/production.rb`:

```ruby
# Trust Cloudflare IPs + localhost
config.action_dispatch.trusted_proxies = [
  '127.0.0.1',
  '::1',
  '192.168.4.253',
  # Cloudflare IPv4 ranges
  IPAddr.new('173.245.48.0/20'),
  IPAddr.new('103.21.244.0/22'),
  IPAddr.new('103.22.200.0/22'),
  IPAddr.new('103.31.4.0/22'),
  IPAddr.new('141.101.64.0/18'),
  IPAddr.new('108.162.192.0/18'),
  IPAddr.new('190.93.240.0/20'),
  IPAddr.new('188.114.96.0/20'),
  IPAddr.new('197.234.240.0/22'),
  IPAddr.new('198.41.128.0/17'),
  # Cloudflare IPv6 ranges
  IPAddr.new('2400:cb00::/32'),
  IPAddr.new('2606:4700::/32'),
  IPAddr.new('2803:f800::/32'),
  IPAddr.new('2405:b500::/32'),
  IPAddr.new('2405:8100::/32'),
  IPAddr.new('2c0f:f248::/32'),
  IPAddr.new('2a06:98c0::/29'),
].freeze
```

**Restart application:**
```bash
launchctl kickstart -k gui/$(id -u)/com.agentforge.nextgen-plaid
```

#### C. Update Logging (Optional)

Add Cloudflare headers to Rails logs:

```ruby
# config/initializers/cloudflare_logging.rb
Rails.application.config.log_tags = [
  :request_id,
  -> (request) { request.headers['CF-Ray'] },
  -> (request) { request.headers['CF-IPCountry'] },
]
```

---

## Rollback Procedures

### Scenario 1: Nginx Won't Start (Phase 3)

**Symptoms:** Nginx fails to start, configuration errors

**Recovery:**
```bash
# 1. Check error logs
sudo tail -50 /var/log/nginx/error.log

# 2. Re-enable PF redirect immediately
sudo pfctl -f /etc/pf.conf

# 3. Verify PF is active
sudo pfctl -s nat | grep 3000
# Should show: rdr rules for port 80 → 3000

# 4. Test application access
curl http://localhost/health?token=<HEALTH_TOKEN>
# Should return: {"status":"ok"}

# 5. Fix Nginx configuration and retry
sudo nginx -t
# Address any errors
```

**Time to recover:** 2-5 minutes  
**Data loss:** None  
**Service impact:** 2-5 minutes downtime

---

### Scenario 2: Nginx Runs But Application Unreachable (Phase 3)

**Symptoms:** Nginx starts but requests fail, 502 Bad Gateway errors

**Recovery:**
```bash
# 1. Check if application is running
ps aux | grep puma
curl http://localhost:3000/health?token=<HEALTH_TOKEN>

# 2. If app is down, restart
launchctl kickstart -k gui/$(id -u)/com.agentforge.nextgen-plaid

# 3. If app is up but Nginx can't reach it, check upstream config
sudo grep -A5 "upstream nextgen_plaid" /etc/nginx/nginx.conf
# Should show: server 127.0.0.1:3000

# 4. If issue persists, rollback to PF
sudo nginx -s quit
sudo pfctl -f /etc/pf.conf

# 5. Verify rollback
curl http://localhost/health?token=<HEALTH_TOKEN>
```

**Time to recover:** 5-10 minutes  
**Data loss:** None  
**Service impact:** 5-10 minutes degraded service or downtime

---

### Scenario 3: Cloudflare Issues (Phase 4)

**Symptoms:** Can't reach via domain, SSL errors, connection timeouts

**Recovery:**
```bash
# 1. Disable Cloudflare proxy (gray cloud icon)
# In Cloudflare Dashboard: DNS → Edit A record → Disable proxy

# 2. Wait 60 seconds for DNS propagation

# 3. Test direct access
curl -k https://192.168.4.253/health?token=<HEALTH_TOKEN>
# If this works, issue is with Cloudflare config

# 4. Check Cloudflare SSL/TLS mode
# Should be: Full (Strict)

# 5. Verify Origin Certificate is installed
sudo openssl x509 -in /etc/nginx/ssl/cloudflare-origin.pem -noout -dates

# 6. Check Cloudflare Firewall rules
# Ensure no rules are blocking legitimate traffic

# 7. Re-enable proxy once issues resolved
```

**Time to recover:** 5-15 minutes  
**Data loss:** None  
**Service impact:** Temporary (application still accessible via IP)

---

### Scenario 4: Complete Rollback to PF

**When:** All else fails, need to restore original configuration

**Steps:**
```bash
# 1. Stop Nginx
sudo brew services stop nginx
sudo nginx -s quit

# 2. Restore PF configuration
sudo cp /etc/pf.conf.backup-YYYYMMDD /etc/pf.conf
sudo cp /etc/pf.anchors/com.nextgen.plaid.backup-YYYYMMDD /etc/pf.anchors/com.nextgen.plaid

# 3. Reload PF rules
sudo pfctl -f /etc/pf.conf

# 4. Verify PF rules active
sudo pfctl -s nat | grep 3000

# 5. Test application
curl http://localhost/health?token=<HEALTH_TOKEN>
curl http://192.168.4.253/health?token=<HEALTH_TOKEN>

# 6. Verify from external machine
curl http://192.168.4.253/health?token=<HEALTH_TOKEN>

# 7. Disable Cloudflare proxy (if enabled)
# In Cloudflare Dashboard: Disable proxy (gray cloud)

# 8. Update DNS TTL back to normal (e.g., 300 seconds)
```

**Time to recover:** 5-10 minutes  
**Data loss:** None  
**Service impact:** 5-10 minutes downtime

---

## Testing & Verification

### Immediate Post-Migration Tests (Phase 3)

**Run these immediately after Nginx cutover:**

```bash
# 1. Health Check
curl -k https://localhost/health?token=<HEALTH_TOKEN>
# Expected: {"status":"ok"}

# 2. HTTP Redirect
curl -v http://localhost/
# Expected: 301 redirect to https://

# 3. Full Page Load
curl -k https://localhost/ -H "Host: nextgen-plaid.yourdomain.com"
# Expected: HTML page content

# 4. API Endpoint
curl -k https://localhost/api/accounts -H "Authorization: Bearer <TOKEN>"
# Expected: JSON response (or 401 if auth required)

# 5. Static Assets
curl -k https://localhost/assets/application.css
# Expected: CSS content

# 6. WebSocket Connection (ActionCable)
# Use browser console or wscat:
wscat -c wss://localhost/cable --no-check
# Expected: WebSocket connection established
```

### Extended Verification Tests (Phase 4)

**Run after Cloudflare is enabled:**

```bash
# 1. DNS Resolution
dig nextgen-plaid.yourdomain.com +short
# Expected: Cloudflare IP range

# 2. Domain Access
curl https://nextgen-plaid.yourdomain.com/health?token=<HEALTH_TOKEN>
# Expected: {"status":"ok"}

# 3. SSL Certificate
curl -vI https://nextgen-plaid.yourdomain.com/ 2>&1 | grep -A5 "Server certificate"
# Expected: Cloudflare certificate, not origin certificate

# 4. Cloudflare Headers
curl -I https://nextgen-plaid.yourdomain.com/health?token=<HEALTH_TOKEN>
# Expected headers:
#   cf-ray: <ray-id>
#   cf-cache-status: DYNAMIC
#   server: cloudflare

# 5. Real IP Logging
# Make request from known IP
curl https://nextgen-plaid.yourdomain.com/health?token=<HEALTH_TOKEN>
# Check logs on server:
sudo tail -1 /var/log/nginx/nextgen-plaid-access.log
# Expected: Your real IP (not Cloudflare IP)

# 6. Rate Limiting
# Send rapid requests
for i in {1..50}; do curl -s https://nextgen-plaid.yourdomain.com/ > /dev/null; done
# Check logs for rate limiting:
sudo grep "limiting requests" /var/log/nginx/error.log

# 7. Compression
curl -H "Accept-Encoding: gzip" -I https://nextgen-plaid.yourdomain.com/
# Expected: Content-Encoding: gzip or br (brotli)
```

### Application Functionality Tests

**Test critical user flows:**

- [ ] User login
- [ ] Dashboard loads
- [ ] Plaid account connection
- [ ] Transaction sync
- [ ] AI insights generation
- [ ] SmartProxy LLM requests (if exposed via nextgen-plaid)
- [ ] Background jobs processing (check Solid Queue)
- [ ] ActionCable/WebSocket updates

### Performance Baseline

**Capture baseline metrics:**

```bash
# Request latency
time curl -s https://nextgen-plaid.yourdomain.com/health?token=<HEALTH_TOKEN>
# Target: < 100ms for health check

# Full page load time
time curl -s https://nextgen-plaid.yourdomain.com/ > /dev/null
# Target: < 500ms

# Concurrent requests
ab -n 100 -c 10 https://nextgen-plaid.yourdomain.com/health?token=<HEALTH_TOKEN>
# Check: Requests per second, failed requests

# Monitor server resources during test
ssh ericsmith66@192.168.4.253 'top -l 1 | grep -A 10 CPU'
```

### Monitoring & Alerting

**Set up ongoing monitoring:**

- [ ] Nginx error log monitoring (check for 5xx errors)
- [ ] Nginx access log analysis (track request rates)
- [ ] Application logs (check for new errors)
- [ ] Cloudflare Analytics (dashboard)
- [ ] Health check automation (cron job or monitoring service)

---

## Post-Migration Tasks

### Day 1: Immediate Post-Migration

- [ ] **Monitor logs continuously for first 4 hours**
  ```bash
  ssh ericsmith66@192.168.4.253
  sudo tail -f /var/log/nginx/nextgen-plaid-error.log &
  sudo tail -f /var/log/nginx/error.log &
  tail -f /Users/ericsmith66/Development/nextgen-plaid/log/production.log
  ```

- [ ] **Check Cloudflare Analytics**
  - Requests per minute
  - Bandwidth usage
  - Threat activity
  - Cache hit ratio

- [ ] **Verify background jobs are processing**
  ```bash
  cd /Users/ericsmith66/Development/nextgen-plaid
  RAILS_ENV=production bin/rails solid_queue:status
  ```

- [ ] **Test all critical user flows** (see Testing section)

- [ ] **Update documentation**
  - Update RUNBOOK.md with new architecture
  - Document Nginx management commands
  - Update health check URLs (if changed)

### Week 1: Stabilization

- [ ] **Review logs daily** for errors or anomalies

- [ ] **Monitor performance metrics**
  - Response times
  - Error rates
  - Resource usage (CPU, memory, disk)

- [ ] **Check SSL certificate expiry** (should be ~15 years out)
  ```bash
  openssl x509 -in /etc/nginx/ssl/cloudflare-origin.pem -noout -enddate
  ```

- [ ] **Verify log rotation is working**
  ```bash
  ls -lh /var/log/nginx/*.log*
  # Should see rotated logs after 24 hours
  ```

- [ ] **Tune rate limiting** (if needed)
  - Check if legitimate users are being blocked
  - Adjust `/etc/nginx/nginx.conf` if needed

- [ ] **Configure Cloudflare firewall rules** (if needed)
  - Block malicious IPs
  - Challenge suspicious traffic
  - Rate limit specific endpoints

### Month 1: Optimization

- [ ] **Analyze traffic patterns**
  - Peak hours
  - Geographic distribution
  - Popular endpoints
  - Slow endpoints

- [ ] **Optimize caching**
  - Configure Cloudflare Page Rules for static assets
  - Add Nginx caching for appropriate endpoints
  - Measure cache hit ratio improvements

- [ ] **Security hardening**
  - Review Cloudflare Firewall Events
  - Configure additional security rules
  - Enable Bot Fight Mode if needed

- [ ] **Set up automated health checks**
  - External monitoring service (UptimeRobot, Pingdom, etc.)
  - Alert on downtime or slow response
  - Test alert notifications

- [ ] **Document lessons learned**
  - What went well
  - What could be improved
  - Update migration plan for future apps

### Cleanup Tasks

- [ ] **Remove PF configuration** (once stable for 2+ weeks)
  ```bash
  sudo nano /etc/pf.conf
  # Remove or comment out:
  #   rdr-anchor "com.nextgen.plaid"
  #   anchor "com.nextgen.plaid"
  #   load anchor "com.nextgen.plaid" ...
  
  sudo pfctl -f /etc/pf.conf
  ```

- [ ] **Archive backups**
  - Move PF backup files to archive directory
  - Keep for 90 days, then delete

- [ ] **Update Git repository**
  - Commit final Nginx configuration
  - Tag release: `git tag nextgen-plaid-migration-v1.0`
  - Update README with new architecture

---

## Risk Assessment

### Risk Matrix

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Nginx config error | Medium | High | Test configuration before applying, have rollback ready |
| PF disable failure | Low | Medium | Keep backup, document exact commands |
| SSL certificate issues | Low | Medium | Verify certificate before migration, test HTTPS access |
| Cloudflare misconfiguration | Medium | Medium | Test with proxy disabled first, gray cloud for testing |
| DNS propagation delay | High | Low | Set low TTL before migration, communicate to users |
| Application compatibility issues | Low | High | Test WebSocket, ActionCable, all critical flows |
| Performance degradation | Low | Medium | Baseline metrics before, monitor after, tune if needed |
| Extended downtime | Low | High | Have clear rollback criteria, practice rollback |

### Mitigation Strategies

**1. Configuration Testing**
- Always run `nginx -t` before applying changes
- Test on alternate ports before production cutover
- Keep backup configurations readily accessible

**2. Phased Rollout**
- Enable Nginx but keep PF configuration intact initially
- Test thoroughly before removing PF
- Enable Cloudflare only after Nginx is stable

**3. Monitoring & Alerting**
- Watch logs continuously during migration
- Set up health check monitoring before migration
- Have team member available during migration window

**4. Communication**
- Notify stakeholders before migration
- Provide status updates during migration
- Document any issues encountered

**5. Rollback Readiness**
- Test rollback procedure before migration
- Keep rollback commands in terminal history
- Have clear go/no-go criteria

---

## Appendix: Quick Reference Commands

### Pre-Migration

```bash
# Backup PF configuration
sudo cp /etc/pf.conf /etc/pf.conf.backup-$(date +%Y%m%d)
sudo cp /etc/pf.anchors/com.nextgen.plaid /etc/pf.anchors/com.nextgen.plaid.backup-$(date +%Y%m%d)

# Check current state
curl http://localhost/health?token=<HEALTH_TOKEN>
sudo pfctl -s nat | grep 3000
```

### Migration

```bash
# Disable PF
sudo pfctl -a com.nextgen.plaid -F all

# Start Nginx
sudo brew services start nginx

# Test
curl -k https://localhost/health?token=<HEALTH_TOKEN>
```

### Rollback

```bash
# Stop Nginx
sudo brew services stop nginx

# Restore PF
sudo pfctl -f /etc/pf.conf

# Verify
curl http://localhost/health?token=<HEALTH_TOKEN>
```

### Monitoring

```bash
# Watch logs
sudo tail -f /var/log/nginx/nextgen-plaid-access.log
sudo tail -f /var/log/nginx/nextgen-plaid-error.log
sudo tail -f /var/log/nginx/error.log

# Check Nginx status
ps aux | grep nginx
sudo lsof -iTCP:80,443 -sTCP:LISTEN

# Test endpoints
curl -k https://localhost/health?token=<HEALTH_TOKEN>
curl -v http://localhost/
```

---

## Questions & Decisions Needed

Before proceeding with migration, please confirm:

1. **Domain name**: What domain will be used? (update `nextgen-plaid.yourdomain.com`)
2. **Public access strategy**: Cloudflare Tunnel or direct IP?
3. **Migration timing**: Maintenance window or zero-downtime approach?
4. **Maintenance window**: If using maintenance approach, what date/time?
5. **Cloudflare account**: Do you have admin access to configure DNS and SSL?
6. **Testing requirements**: Any specific user flows that must be tested?
7. **Rollback criteria**: Under what conditions should we rollback? (e.g., >5min downtime, >10% error rate)

---

**End of Migration Plan**
