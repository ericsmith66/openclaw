# Deployment Log: Reverse Proxy Migration

**Date:** February 28, 2026  
**Project:** highground-rev-proxy  
**Status:** ✅ **Successfully Deployed**  
**Downtime:** Zero (dual-path operation)

---

## Executive Summary

Successfully migrated HiGround Solutions infrastructure from a fragile single-service setup (PF redirect on port 80) to a production-grade three-layer reverse proxy architecture (Cloudflare → UDM-SE → Nginx). All 5 services are now live or showing "Coming Soon" pages.

### Architecture Deployed

```
Internet
  ↓
Cloudflare (CDN, WAF, DDoS, SSL edge)
  ↓ HTTPS port 443 (Origin Certificate)
UDM-SE Firewall (Cloudflare IPs only, IDS/IPS)
  ↓ TCP 443
Nginx on 192.168.4.253 (SSL termination, HTTP/2, rate limiting)
  ↓ Plain HTTP
Backend Applications (Rails, BlueBubbles)
```

---

## Services Deployed

| Service | Domain | Backend | Status |
|---------|--------|---------|--------|
| **nextgen-plaid** | nextgen.higroundsolutions.com | 192.168.4.253:3000 | ✅ Live (401 auth) |
| **api alias** | api.higroundsolutions.com | 192.168.4.253:3000 | ✅ Live (Plaid OAuth) |
| **eureka-homekit** | eureka.higroundsolutions.com | Static HTML | ✅ Coming Soon |
| **agent-forge** | agent-forge.higroundsolutions.com | Static HTML | ✅ Coming Soon |
| **bluebubbles** | blue.higroundsolutions.com | Static HTML | ✅ Coming Soon |

---

## Deployment Timeline

| Time | Phase | Action | Result |
|------|-------|--------|--------|
| 10:19 | Setup | Installed Nginx via Homebrew | ✅ v1.29.5 |
| 10:23 | Config | Synced repo via rsync | ✅ 27 files |
| 10:26 | Fix | Applied macOS adaptations | ✅ user, kqueue, paths |
| 10:28 | Start | Started Nginx on port 443 | ✅ 32 workers |
| 10:30 | Test | Local HTTPS tests | ❌ 502 (PF loop) |
| 10:57 | Fix | Changed upstream to LAN IP | ✅ 401 (working) |
| 11:00 | UDM-SE | Added port forward & firewall | ✅ Cloudflare-only |
| 11:05 | Cloudflare | Switched SSL to Full (Strict) | ✅ Propagated |
| 11:10 | Verify | External testing all endpoints | ✅ All responding |

**Total Time:** ~2 hours  
**Downtime:** 0 minutes

---

## macOS-Specific Changes

### Configuration Paths
- **Base:** `/opt/homebrew/etc/nginx/` (not `/etc/nginx/`)
- **Logs:** `/opt/homebrew/var/log/nginx/`
- **Sites:** `/opt/homebrew/etc/nginx/sites-{available,enabled}/`
- **SSL:** `/opt/homebrew/etc/nginx/ssl/`

### nginx.conf Adaptations
```bash
# User (macOS has no 'nginx' user)
user nobody;

# Event model (macOS uses kqueue, not epoll)
events {
    use kqueue;
}

# Mime types path
include /opt/homebrew/etc/nginx/mime.types;
```

### Upstream Fix
**Problem:** PF redirect on localhost created routing loops when Nginx tried to connect to `127.0.0.1:3000`

**Solution:** Use LAN IP instead
```nginx
upstream nextgen_plaid {
    server 192.168.4.253:3000;  # Was: 127.0.0.1:3000
}
```

**Why this works:**
- Puma binds to `0.0.0.0:3000` (all interfaces)
- PF redirect only affects localhost interface (lo0)
- LAN IP bypasses the redirect, connects directly to Puma

---

## UDM-SE Configuration

### Port Forwarding
| Name | Protocol | From | To | WAN |
|------|----------|------|-----|-----|
| cloudflare-ssl-tunnel | TCP/UDP | Cloudflare:443 | 192.168.4.253:443 | Internet 1 |
| NextGen (legacy) | TCP/UDP | Cloudflare:80 | 192.168.4.253:80 | Internet 1 |

### Firewall Rules
| Name | Type | Protocol | Source | Destination | Port |
|------|------|----------|--------|-------------|------|
| Allow Port Forward cloudflare-ssl-tunnel | Allow | TCP/UDP | Cloudflare IPs | 192.168.4.253 | 443 |
| Allow Port Forward NextGen (legacy) | Allow | TCP/UDP | Cloudflare IPs | 192.168.4.253 | 80 |

**Cloudflare IP Group:** 15 CIDR ranges (173.245.48.0/20, 103.21.244.0/22, etc.)

---

## Cloudflare Configuration

### DNS Records (All Proxied)
| Subdomain | Type | Target | Proxy | SSL Mode |
|-----------|------|--------|-------|----------|
| nextgen | A | 104.14.41.31 | ✅ Orange | Full (Strict) |
| api | A | 104.14.41.31 | ✅ Orange | Full (Strict) |
| eureka | A | 104.14.41.31 | ✅ Orange | Full (Strict) |
| agent-forge | A | 104.14.41.31 | ✅ Orange | Full (Strict) |
| blue | A | 104.14.41.31 | ✅ Orange | Full (Strict) |

### SSL/TLS Settings
- **Mode:** Full (Strict)
- **Origin Certificate:** Installed (15-year wildcard `*.higroundsolutions.com`)
- **Edge Certificate:** Cloudflare Universal SSL

---

## Testing Results

### Local Tests (from 192.168.4.253)
```bash
curl -k -I https://localhost/health -H 'Host: nextgen.higroundsolutions.com'
# ✅ HTTP/2 401 (auth required - Rails responding)

curl -k -I https://localhost/ -H 'Host: eureka.higroundsolutions.com'
# ✅ HTTP/2 200 (Coming Soon page)
```

### External Tests (via Cloudflare)
```bash
curl -I https://nextgen.higroundsolutions.com/health
# ✅ HTTP/2 401 (Rails app)

curl -I https://api.higroundsolutions.com/health
# ✅ HTTP/2 401 (Plaid OAuth alias)

curl -I https://eureka.higroundsolutions.com/
# ✅ HTTP/2 200 (Coming Soon)

curl -I https://agent-forge.higroundsolutions.com/
# ✅ HTTP/2 200 (Coming Soon)

curl -I https://blue.higroundsolutions.com/
# ✅ HTTP/2 200 (Coming Soon)
```

**Response Headers Verified:**
- `server: cloudflare` ✅
- `cf-ray: ...` ✅
- `cf-cache-status: DYNAMIC` ✅
- HTTP/2 ✅
- HSTS headers ✅

---

## Legacy Infrastructure (Active for 2 weeks)

### PF Redirect (Still Active)
**File:** `/etc/pf.anchors/com.nextgen.plaid`
```
rdr pass on lo0 inet proto tcp from any to any port 80 -> 127.0.0.1 port 3000
rdr pass on en0 inet proto tcp from any to any port 80 -> 192.168.4.253 port 3000
```

**Status:** ⚠️ Active (fallback path)  
**Action:** Remove after 2 weeks of stable operation

### Port 80 Forward (Still Active)
**UDM-SE:** Port 80 → 192.168.4.253:80  
**Status:** ⚠️ Active (legacy path for api.higroundsolutions.com)  
**Action:** Remove after 2 weeks of stable operation

---

## Post-Deployment Tasks

### Monitor (2 weeks)
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

### Remove Legacy Infrastructure (After 2 weeks stable)
```bash
# 1. Disable PF redirect
sudo pfctl -a com.nextgen.plaid -F all

# 2. Remove PF anchor file
sudo rm /etc/pf.anchors/com.nextgen.plaid

# 3. Remove from pf.conf
sudo sed -i '' '/com.nextgen.plaid/d' /etc/pf.conf
sudo pfctl -f /etc/pf.conf

# 4. Remove UDM-SE port 80 forward and firewall rule
# (via UniFi console)
```

### Activate Backend Services (When deployed)
```bash
# Example: Activate eureka-homekit
sudo cp /opt/homebrew/etc/nginx/sites-available/eureka-homekit.conf.live \
        /opt/homebrew/etc/nginx/sites-available/eureka-homekit.conf
sudo nginx -t && sudo nginx -s reload
```

---

## Files Modified

### highground-rev-proxy
- ✅ Created `scripts/deploy-macos.sh` (macOS-specific deploy script)
- ✅ Updated `README.md` (added macOS deployment section)
- ✅ Updated upstream in nginx.conf: `127.0.0.1:3000` → `192.168.4.253:3000`

### overwatch
- ✅ Updated `docs/deployment/MIGRATION-NEXTGEN-PLAID-TO-REVERSE-PROXY.md`
  - Changed status to "COMPLETED"
  - Added execution summary
  - Documented macOS adaptations
  - Added actual execution log
- ✅ Created `docs/deployment/DEPLOYMENT-LOG-2026-02-28.md` (this file)

---

## Lessons Learned

### Platform-Specific Differences Matter
- Homebrew Nginx paths differ significantly from standard Linux
- Always check event models (epoll vs kqueue)
- User accounts differ (nginx vs nobody)

### Localhost Can Be Problematic
- PF redirects create routing loops on localhost
- Use LAN IPs when possible for inter-service communication
- Puma binding to `0.0.0.0` saves the day

### Dual-Path Is Safer Than Cutover
- Keeping legacy path active eliminated downtime
- Allows gradual migration verification
- Provides instant rollback capability

### Coming Soon Pattern Works Well
- `.conf` files for active "Coming Soon" pages
- `.conf.live` files ready for backend activation
- Simple `cp` command to activate service

### Testing Sequence Matters
1. Local testing first (curl localhost)
2. LAN testing second (curl LAN IP)
3. External testing last (curl domain)
4. Each layer catches different issues

---

## Metrics

### Performance
- **HTTP/2:** Enabled ✅
- **Compression:** gzip on text/html, text/css, application/json ✅
- **Rate Limiting:** 10 req/s general, 30 req/s API ✅
- **SSL Termination:** Cloudflare Origin Certificate (15-year validity) ✅

### Security
- **Cloudflare-Only Ingress:** ✅ (15 IP ranges)
- **IDS/IPS:** Enabled on UDM-SE ✅
- **SSL Mode:** Full (Strict) ✅
- **Security Headers:** HSTS, X-Frame-Options, CSP ✅

### Reliability
- **Health Endpoints:** Configured for all services ✅
- **WebSocket Support:** ActionCable/Turbo Streams ready ✅
- **Failover:** Upstream health checks configured ✅
- **Logging:** Per-service access logs ✅

---

## Sign-Off

**Deployed By:** agent-forge AI orchestration system  
**Approved By:** Eric Smith  
**Date:** February 28, 2026  
**Status:** ✅ Production Ready

**Next Review:** March 14, 2026 (2 weeks) - Remove legacy infrastructure
