# Recommended Architecture: Reverse Proxy Migration

**Date:** February 27, 2026  
**Status:** ✅ Approved  
**Scope:** All internet-facing services behind Cloudflare → UDM-SE → Nginx reverse proxy

---

## Current State (What We're Replacing)

```
Internet
  ↓
ATT Fiber
  ↓
UDM-SE (port forwards port 80 → 192.168.4.253:80)
  ↓
macOS pf redirect (port 80 → 3000)
  ↓
Puma/Rails on :3000
```

**Problems:**
- No SSL/TLS (plain HTTP over the internet)
- No WAF, no DDoS protection
- No rate limiting
- No real IP logging (all requests look like localhost)
- PF is fragile — resets on macOS updates, no monitoring
- Can't serve multiple apps on port 80 (only one PF redirect)
- UDM-SE port-forwards directly to an unprotected application

---

## Recommended Architecture

### Approved: Cloudflare → UDM-SE → Nginx → Plain HTTP to Backends

```
Internet
  ↓ HTTPS
Cloudflare (CDN, WAF, DDoS, edge SSL)
  ↓ HTTPS (Origin Certificate, port 443)
UDM-SE Firewall (Cloudflare-only ingress, IDS/IPS)
  ↓ TCP 443
Nginx on 192.168.4.253 (SSL terminates HERE)
  ↓ Plain HTTP (localhost / LAN only — no encryption overhead)
  ├── nextgen.higroundsolutions.com  → 127.0.0.1:3000    (same server)
  ├── eureka.higroundsolutions.com → 127.0.0.1:3001    (same server)
  ├── agent-forge.higroundsolutions.com    → 192.168.4.200:3017 (LAN)
  └── blue.higroundsolutions.com    → 192.168.4.10:1234  (LAN)
```

### Complete Service Map

| Subdomain | Backend | Server | Port | Type |
|-----------|---------|--------|------|------|
| `nextgen.higroundsolutions.com` | 127.0.0.1:3000 | 192.168.4.253 (localhost) | 3000 | Rails — financial dashboard |
| `eureka.higroundsolutions.com` | 127.0.0.1:3001 | 192.168.4.253 (localhost) | 3001 | Rails — home automation & UniFi |
| `agent-forge.higroundsolutions.com` | 192.168.4.200:3017 | 192.168.4.200 (LAN) | 3017 | Rails — AI agent orchestration |
| `blue.higroundsolutions.com` | 192.168.4.10:1234 | 192.168.4.10 (LAN) | 1234 | iMessage relay server |

**Why This Is Best:**

| Concern | How It's Handled |
|---------|-----------------|
| SSL/TLS | Cloudflare → client; Origin Certificate → Nginx; end-to-end encrypted |
| DDoS | Cloudflare absorbs volumetric attacks before they reach your network |
| WAF | Cloudflare blocks SQL injection, XSS, etc. at the edge |
| Rate Limiting | Two layers: Cloudflare (edge) + Nginx (application) |
| Real IP | Cloudflare sends `CF-Connecting-IP` header → Nginx restores it |
| Multi-App | Nginx routes by `server_name` — one port serves all apps |
| Logging | Per-app access/error logs with real client IPs |
| WebSockets | Nginx proxies Upgrade headers for ActionCable |
| Monitoring | Health check endpoints, structured logging |
| Scalability | Add new apps by dropping a `.conf` file in sites-available |

---

### What the UDM-SE Does in This Architecture

The UDM-SE becomes a **critical security layer** between Cloudflare and your server:

#### 1. Port Forwarding (Replaces Current Port 80 Forward)

**Remove:**
```
Port 80 → 192.168.4.253:80  (current — insecure)
```

**Add:**
```
Port 443 → 192.168.4.253:443  (HTTPS only)
```

**Why:** Only encrypted traffic reaches your server. Port 80 is no longer forwarded at all — Cloudflare handles the HTTP→HTTPS redirect at the edge before traffic even reaches your network.

#### 2. Firewall: Cloudflare-Only Ingress (NEW — Critical)

Create a **firewall address group** for Cloudflare IPs, then create rules so that **only Cloudflare can reach port 443**.

**UDM-SE Settings → Profiles → IP Groups → Create:**
- **Name:** `Cloudflare_IPv4`
- **Addresses:**
  ```
  173.245.48.0/20
  103.21.244.0/22
  103.22.200.0/22
  103.31.4.0/22
  141.101.64.0/18
  108.162.192.0/18
  190.93.240.0/20
  188.114.96.0/20
  197.234.240.0/22
  198.41.128.0/17
  ```

**UDM-SE Settings → Firewall → Internet In → Create Rules:**

| Rule | Action | Source | Destination | Port | Notes |
|------|--------|--------|-------------|------|-------|
| Allow Cloudflare HTTPS | **Accept** | Cloudflare_IPv4 group | 192.168.4.253 | 443 | Only Cloudflare can reach Nginx |
| Block Direct HTTPS | **Drop** | Any | 192.168.4.253 | 443 | Prevents bypassing Cloudflare |
| Block Direct HTTP | **Drop** | Any | 192.168.4.253 | 80 | No more unencrypted access |

**Why This Matters:** Without this, an attacker who discovers your public IP can bypass Cloudflare entirely and hit your server directly. With these rules, your server is invisible to anyone except Cloudflare.

#### 3. IDS/IPS — Threat Management (NEW — Recommended)

**UDM-SE Settings → Security → Threat Management:**
- **Enable:** IDS/IPS
- **Mode:** IPS (actively blocks threats, not just detects)
- **Sensitivity:** Medium (tune later based on false positives)

**Why:** Acts as a second layer of defense. If something gets past Cloudflare, the UDM-SE can still catch and block known attack signatures.

#### 4. Traffic Analytics (Built-In — No Config Needed)

**UDM-SE gives you for free:**
- Bandwidth usage per client IP
- Connection counts to 192.168.4.253
- Deep Packet Inspection (DPI) application identification
- Historical traffic graphs

**View:** UniFi Console → Insights → Traffic Identification → Filter by 192.168.4.253

#### 5. Internal DNS (Optional — Useful for Testing)

**UDM-SE Settings → Networks → DHCP → DNS:**
- Add local DNS override: `nextgen.higroundsolutions.com → 192.168.4.253`

**Why:** Lets you test the full domain flow from your local network without waiting for DNS propagation. Your local machines resolve to the server directly, bypassing Cloudflare.

---

### What Gets Removed

| Component | Action | Reason |
|-----------|--------|--------|
| **PF redirect** (`/etc/pf.anchors/com.nextgen.plaid`) | **Remove** | Nginx handles routing now |
| **PF anchor** in `/etc/pf.conf` | **Remove** | No longer needed |
| **UDM-SE port 80 forward** | **Remove** | Replace with port 443 forward |
| **Direct port 3000 exposure** | **Blocked** | Only Nginx (localhost) reaches 3000 |

### What Gets Added

| Component | Where | Purpose |
|-----------|-------|---------|
| **Nginx** | 192.168.4.253 (Homebrew) | Reverse proxy, SSL termination, routing |
| **Cloudflare Origin Certificate** | `/etc/nginx/ssl/` | Encrypted connection from Cloudflare to Nginx |
| **Cloudflare DNS proxy** | Cloudflare Dashboard | CDN, WAF, DDoS, edge SSL |
| **UDM-SE port 443 forward** | UDM-SE Settings | Route HTTPS to server |
| **UDM-SE Cloudflare firewall rules** | UDM-SE Firewall | Block non-Cloudflare traffic |
| **UDM-SE IDS/IPS** | UDM-SE Security | Threat detection/prevention |

### What Stays the Same

| Component | Status | Notes |
|-----------|--------|-------|
| Rails app on port 3000 | **Unchanged** | No code changes needed |
| launchd LaunchAgents | **Unchanged** | Auto-start/restart as-is |
| SmartProxy on port 3001 | **Unchanged** | Internal only, no proxy needed |
| PostgreSQL, Redis, Ollama | **Unchanged** | Internal only |
| `.env.production` secrets | **Unchanged** | Same secrets management |
| `bin/deploy-prod` | **Minor update** | Add `nginx -s reload` after deploy |

---

## Security Model: Three Defense Layers

```
┌──────────────────────────────────────────────────┐
│                 LAYER 1: CLOUDFLARE               │
│                                                    │
│  ✓ Global CDN (absorbs volumetric DDoS)           │
│  ✓ WAF (blocks SQLi, XSS, RCE at edge)           │
│  ✓ Bot Management (challenges suspicious clients) │
│  ✓ SSL/TLS to client (free, auto-renewed)         │
│  ✓ Rate limiting (configurable per URL)           │
│  ✓ Analytics & logging                            │
└───────────────────────┬──────────────────────────┘
                        │ HTTPS (Origin Certificate)
                        ▼
┌──────────────────────────────────────────────────┐
│                 LAYER 2: UDM-SE                   │
│                                                    │
│  ✓ Firewall: Only Cloudflare IPs reach port 443  │
│  ✓ IDS/IPS: Blocks known attack signatures        │
│  ✓ DPI: Identifies application-layer traffic      │
│  ✓ Port forwarding: 443 only (no port 80)        │
│  ✓ Traffic analytics: Bandwidth, connections      │
│  ✓ No direct IP access possible                   │
└───────────────────────┬──────────────────────────┘
                        │ TCP 443
                        ▼
┌──────────────────────────────────────────────────┐
│                 LAYER 3: NGINX                    │
│                                                    │
│  ✓ SSL termination (Origin Certificate)           │
│  ✓ Rate limiting (10r/s general, 30r/s API)       │
│  ✓ Security headers (HSTS, CSP, X-Frame-Options) │
│  ✓ Real IP restoration from CF-Connecting-IP      │
│  ✓ Per-app routing by server_name                 │
│  ✓ Per-app access/error logging                   │
│  ✓ WebSocket support (ActionCable)                │
│  ✓ Health check endpoints                         │
└───────────────────────┬──────────────────────────┘
                        │ HTTP (localhost only)
                        ▼
┌──────────────────────────────────────────────────┐
│              RAILS APPLICATION                    │
│                                                    │
│  nextgen-plaid → 127.0.0.1:3000                   │
│  eureka-homekit → 127.0.0.1:3001 (future)         │
│  Only reachable from localhost                     │
└──────────────────────────────────────────────────┘
```

**Result:** An attacker must bypass ALL THREE layers to reach your application. Today they only need to find your IP and hit port 80.

---

## Domain Strategy

### Current
```
api.higroundsolutions.com → Cloudflare Tunnel → port 80 → pf → :3000
```

### Recommended

**Option A: Subdomains per App (Recommended)**
```
nextgen.higroundsolutions.com  → Cloudflare → Nginx → :3000
eureka.higroundsolutions.com → Cloudflare → Nginx → :3001
agent-forge.higroundsolutions.com    → Cloudflare → Nginx → :3017
```

**Option B: Keep Single Domain with Path Routing**
```
api.higroundsolutions.com/           → Nginx → :3000 (nextgen-plaid)
api.higroundsolutions.com/homekit/   → Nginx → :3001 (eureka-homekit)
api.higroundsolutions.com/forge/     → Nginx → :3017 (agent-forge)
```

**Recommendation:** Option A (subdomains). Each app gets its own SSL, rate limits, logging, and Nginx config. Cleaner separation, easier debugging, independent scaling.

---

## Cloudflare Tunnel vs. Port Forwarding

### Current: Cloudflare Tunnel (via UDM-SE or separate process)

Your current setup references a Cloudflare Tunnel. The question is whether to keep it or switch to direct port forwarding.

### Option 1: Keep Cloudflare Tunnel ✅ SIMPLER

```
Internet → Cloudflare → Tunnel → localhost:443 (Nginx)
```

**Pros:**
- No port forwarding needed on UDM-SE
- No public IP exposure at all
- Tunnel is already partially configured
- Works even behind CGNAT or dynamic IP

**Cons:**
- Additional process to manage (cloudflared daemon)
- Slight latency overhead (~10-20ms)
- Need to configure tunnel to point to Nginx port 443

**UDM-SE Role:** Firewall/IDS/IPS only. No port forwarding needed.

### Option 2: Direct Port Forwarding ✅ MORE CONTROL

```
Internet → Cloudflare → UDM-SE:443 → 192.168.4.253:443 (Nginx)
```

**Pros:**
- Lower latency (no tunnel overhead)
- One fewer process to manage
- More standard architecture
- UDM-SE firewall provides additional filtering

**Cons:**
- Requires static public IP (or dynamic DNS)
- UDM-SE port forwarding + Cloudflare-only firewall rules required
- Public IP is discoverable (Cloudflare hides it, but tools like Censys might find it)

**UDM-SE Role:** Port forwarding + Firewall + IDS/IPS.

### Recommendation

**If your Cloudflare Tunnel is already working:** Keep it (Option 1). It's simpler and your public IP stays fully hidden. Just reconfigure the tunnel endpoint from `localhost:80` to `localhost:443` (or `localhost:80` with Nginx handling the redirect).

**If setting up fresh:** Option 2 (port forwarding) gives you more control and visibility through the UDM-SE, but requires the Cloudflare-only firewall rules.

---

## Migration Execution Summary

### Human-Required Steps

| Step | Time | What |
|------|------|------|
| 1 | 15 min | Generate Cloudflare Origin Certificate (Dashboard) |
| 2 | 10 min | Upload certificate to server |
| 3 | 10 min | Update domain name in Nginx configs |
| 4 | 10 min | UDM-SE: Create Cloudflare IP group |
| 5 | 10 min | UDM-SE: Create firewall rules (Cloudflare-only) |
| 6 | 5 min | UDM-SE: Change port forward from 80 → 443 (or reconfigure tunnel) |
| 7 | 5 min | UDM-SE: Enable IDS/IPS |
| 8 | 5 min | Server: Backup PF config |
| 9 | 5 min | Server: Install & start Nginx |
| 10 | 5 min | Server: Disable PF redirect |
| 11 | 5 min | Cloudflare: Enable proxy (orange cloud) or update tunnel |
| 12 | 5 min | Cloudflare: Set SSL mode to Full (Strict) |
| 13 | 30 min | Test all endpoints, monitor logs |
| **Total** | **~2 hours** | |

### Automated Steps (Scripted)

| Step | Script |
|------|--------|
| Install Nginx | `brew install nginx` |
| Deploy configs | `scripts/deploy.sh` |
| Test config | `nginx -t` |
| Start Nginx | `brew services start nginx` |
| Disable PF | `pfctl -a com.nextgen.plaid -F all` |
| Health checks | `curl` commands |

### Rollback (If Anything Fails)

```bash
# 5-minute rollback:
sudo brew services stop nginx          # Stop Nginx
sudo pfctl -f /etc/pf.conf             # Restore PF redirect
# UDM-SE: Revert port forward to port 80
# Cloudflare: Disable proxy (gray cloud) or revert tunnel
```

---

## Post-Migration: Updated Port Registry

### 192.168.4.253 (Primary Server — Nginx + Apps)

| Port | Service | Exposed to Internet | Notes |
|------|---------|-------------------|-------|
| 80 | Nginx (HTTP → HTTPS redirect) | No — Cloudflare redirects at edge | Fallback only |
| 443 | Nginx (HTTPS reverse proxy) | Yes — via Cloudflare only | Origin Certificate SSL termination |
| 3000 | nextgen-plaid (Rails) | No — localhost only | Nginx proxies via `nextgen.higroundsolutions.com` |
| 3001 | eureka-homekit (Rails) | No — localhost only | Nginx proxies via `eureka.higroundsolutions.com` |
| 3002 | SmartProxy (Sinatra) | No — localhost only | Internal AI gateway (not proxied) |
| 5432 | PostgreSQL 16 | No — localhost only | Homebrew LaunchAgent |
| 6379 | Redis 7 | No — localhost only | Homebrew LaunchAgent |
| 8080 | Prefab (HomeKit bridge) | No — localhost only | Future |
| 11434 | Ollama | No — localhost only | macOS app |

### 192.168.4.200 (Agent Forge Server)

| Port | Service | Exposed to Internet | Notes |
|------|---------|-------------------|-------|
| 3017 | agent-forge (Rails) | No — LAN only | Nginx on .253 proxies via `agent-forge.higroundsolutions.com` |

### 192.168.4.10 (BlueBubbles Server)

| Port | Service | Exposed to Internet | Notes |
|------|---------|-------------------|-------|
| 1234 | BlueBubbles (iMessage relay) | No — LAN only | Nginx on .253 proxies via `blue.higroundsolutions.com` |

---

## All Four Services Configured

The reverse proxy is fully configured for all four services:

| Service | Nginx Config | Status |
|---------|-------------|--------|
| nextgen-plaid | `nginx/sites-available/nextgen-plaid.conf` | ✅ Ready |
| eureka-homekit | `nginx/sites-available/eureka-homekit.conf` | ✅ Ready (app not deployed yet) |
| agent-forge | `nginx/sites-available/agent-forge.conf` | ✅ Ready |
| bluebubbles | `nginx/sites-available/bluebubbles.conf` | ✅ Ready |

### Adding Future Services

To add a new service:

1. Create `nginx/sites-available/newservice.conf` (copy existing as template)
2. Add upstream block in `nginx/nginx.conf`
3. Create DNS A record in Cloudflare (`newservice.higroundsolutions.com`)
4. `nginx -s reload`
5. Done — zero downtime, no infrastructure changes

---

## Decision Checklist

Please confirm:

- [ ] **Architecture:** Option A (Cloudflare + Nginx on same server) — Agree?
- [ ] **Domain Strategy:** Subdomains per app — Agree? What subdomain? (e.g., `nextgen.higroundsolutions.com` or `plaid.higroundsolutions.com`)
- [ ] **Tunnel vs Port Forward:** Keep Cloudflare Tunnel or switch to port forwarding?
- [ ] **UDM-SE Security:** Cloudflare-only firewall + IDS/IPS — Agree?
- [ ] **Migration Window:** When?

Once confirmed, we execute the migration plan in `MIGRATION-NEXTGEN-PLAID-TO-REVERSE-PROXY.md`.
