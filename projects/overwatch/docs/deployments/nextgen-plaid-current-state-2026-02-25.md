# NextGen Plaid — Current Production State
**Date:** February 25, 2026  
**Status:** ✅ Production Stable  
**RUNBOOK Version:** 2.0

---

## Executive Summary

NextGen Plaid is a Rails 8.1.1 application providing financial account aggregation and AI-powered financial insights using Plaid and Anthropic Claude APIs. It is deployed natively on macOS with LaunchAgents for process management and includes SmartProxy, a Sinatra-based LLM routing proxy.

**All infrastructure documented in this file is current as of the February 25, 2026 DevOps session.**

---

## Authoritative Documentation

**Primary Source:** `/Users/ericsmith66/Development/nextgen-plaid/RUNBOOK.md` (v2.0)

- **Lines:** 700+
- **Last Updated:** February 25, 2026
- **Covers:** Architecture, SSH access, operations, database management, deployment, secrets, health checks, troubleshooting, rollback procedures

**Session Report:** `/Users/ericsmith66/Development/nextgen-plaid/docs/devops-session-report-20260225.md`

- Comprehensive audit report
- 14 issues identified and resolved
- Full reboot test passed
- Post-reboot verification successful

---

## Production Environment

### Infrastructure
- **Server:** 192.168.4.253 (M3 Ultra, hostname: `nextgen`)
- **User:** ericsmith66
- **App Path:** `/Users/ericsmith66/Development/nextgen-plaid`
- **SmartProxy Path:** `/Users/ericsmith66/Development/nextgen-plaid/smart_proxy`
- **Auto-login:** Enabled (required for LaunchAgents on boot)

### Technology Stack
- **Framework:** Ruby on Rails 8.1.1
- **Ruby Version:** 3.3.10 (rbenv)
- **Database:** PostgreSQL 16
- **Queue:** Solid Queue (database-backed)
- **Cable:** Action Cable (database-backed)
- **Cache:** Solid Cache (database-backed)
- **Process Manager:** launchd LaunchAgents (KeepAlive + RunAtLoad)
- **Web Server:** Puma 7.1.0 (via Foreman)
- **LLM Proxy:** SmartProxy (Sinatra/Rack, port 3001)

### Service Map
```
Internet
  └── 192.168.4.253
        ├── nextgen-plaid (Rails/Puma)     :3000  [launchd: com.agentforge.nextgen-plaid]
        │     ├── Solid Queue (workers)
        │     ├── Action Cable (WebSocket)
        │     └── Solid Cache
        ├── SmartProxy (Sinatra/Rack)       :3001  [launchd: com.agentforge.smart-proxy]
        │     ├── → Ollama                  :11434
        │     ├── → Anthropic Claude        (HTTPS)
        │     └── → Grok (xAI)             (HTTPS)
        ├── PostgreSQL 16                   :5432  [launchd: homebrew.mxcl.postgresql@16]
        ├── Redis                           :6379  [launchd: homebrew.mxcl.redis]
        └── Ollama                          :11434 [Login Item: Ollama.app]
```

### Database Structure
```
nextgen_plaid_production          # Main application database
nextgen_plaid_production_queue    # Solid Queue background jobs
nextgen_plaid_production_cable    # Action Cable connections
nextgen_plaid_production_cache    # Solid Cache entries
```

---

## Deployment Architecture

### Process Management: LaunchAgents

| Service | LaunchAgent | Port | Logs |
|---------|------------|------|------|
| nextgen-plaid | `com.agentforge.nextgen-plaid` | 3000 | `log/launchd.stdout.log` |
| SmartProxy | `com.agentforge.smart-proxy` | 3001 | `log/smart_proxy.stdout.log` |
| PostgreSQL | `homebrew.mxcl.postgresql@16` | 5432 | `/opt/homebrew/var/log/postgresql@16.log` |
| Redis | `homebrew.mxcl.redis` | 6379 | — |

**LaunchAgent Features:**
- `RunAtLoad true` — starts on user login
- `KeepAlive true` — auto-restarts on crash
- `ThrottleInterval 10` — prevents rapid restart loops
- Sources `.env.production` for secrets (no Keychain dependency)

### Secrets Management

**Rails Secrets:** `.env.production` (not in git)
- `NEXTGEN_PLAID_DATABASE_PASSWORD`
- `PLAID_CLIENT_ID`
- `PLAID_SECRET`
- `CLAUDE_API_KEY`
- `RAILS_MASTER_KEY`
- `ENCRYPTION_KEY`
- `HEALTH_TOKEN`
- `SMART_PROXY_PORT=3001`
- `PORT=3000`

**SmartProxy Secrets:** `smart_proxy/.env` (not in git)
- `GROK_API_KEY`
- `CLAUDE_API_KEY`
- `PROXY_AUTH_TOKEN`
- `SMART_PROXY_PORT=3001`
- `SMART_PROXY_ENABLE_WEB_TOOLS`

### Deployment Script

**Location:** `bin/deploy-prod` (run from dev machine)

**7 Deployment Phases:**
1. Pre-flight (branch check, SSH check, tests)
2. Backup (pg_dump all 4 databases)
3. Pull code (`git reset --hard origin/main`)
4. Dependencies (`bundle install --without development test`)
5. Migrations (`RAILS_ENV=production bin/rails db:migrate`)
6. Assets (`RAILS_ENV=production bin/rails assets:precompile`)
7. Restart (`launchctl kickstart -k` + health check retry loop)

**Total deployment time:** 5-15 minutes

---

## Health Checks

### nextgen-plaid Health Endpoint
```bash
curl "http://192.168.4.253:3000/health?token=<HEALTH_TOKEN>"
```

**Returns:**
- HTTP 200 + `{"status":"ok"}` if healthy
- HTTP 401 if token wrong/missing
- HTTP 503 if DB down or token not configured

**Features:**
- Timing-safe token comparison (`ActiveSupport::SecurityUtils.secure_compare`)
- Database connectivity check on every request
- Excluded from SSL redirect
- Silenced in production logs

### SmartProxy Health Endpoint
```bash
curl http://192.168.4.253:3001/health
```

**Returns:** `{"status":"ok"}` (no auth required)

---

## SSH & Git Configuration

### SSH Access
```bash
ssh ericsmith66@192.168.4.253
```

**Key:** `~/.ssh/id_ed25519` (passphrase stored in macOS Keychain via `ssh-add --apple-use-keychain`)

### Ruby Environment
rbenv is initialized in `~/.zshenv` so all SSH sessions automatically use Ruby 3.3.10:
```bash
ruby -v      # Should show: ruby 3.3.10
which ruby   # Should show: /Users/ericsmith66/.rbenv/shims/ruby
```

### Git Pull
SSH agent forwarding is configured. `git pull` works without passphrase:
```bash
ssh ericsmith66@192.168.4.253
cd /Users/ericsmith66/Development/nextgen-plaid
git pull
```

**Note:** The `SSH_AUTH_SOCK` socket path changes on each reboot. If `git pull` fails after a reboot, run:
```bash
source ~/.zprofile && git pull
```

---

## SmartProxy (LLM Gateway)

### Overview
SmartProxy is a Sinatra/Rack application that acts as an OpenAI-compatible API gateway, routing LLM requests to Ollama, Claude, or Grok. The Rails app connects to it on port 3001.

### Operations
```bash
# Start
launchctl load ~/Library/LaunchAgents/com.agentforge.smart-proxy.plist

# Stop
launchctl unload ~/Library/LaunchAgents/com.agentforge.smart-proxy.plist

# Restart
launchctl kickstart -k gui/501/com.agentforge.smart-proxy
```

### Logs
```bash
# Structured JSON application log (LLM requests/responses)
tail -f /Users/ericsmith66/Development/nextgen-plaid/log/smart_proxy.log

# Rack/Puma access log
tail -f /Users/ericsmith66/Development/nextgen-plaid/log/smart_proxy.stderr.log

# Startup log
tail -f /Users/ericsmith66/Development/nextgen-plaid/log/smart_proxy.stdout.log
```

---

## Database Management

### Backups

**Manual backup:**
```bash
cd /Users/ericsmith66/Development/nextgen-plaid
./scripts/backup-database.sh
```

Backups stored at: `~/backups/nextgen-plaid/`  
Format: `YYYYMMDD_HHMMSS_<database>.dump`  
Retention: 30 days auto-cleanup

**List backups:**
```bash
./scripts/restore-database.sh --list
```

**Restore:**
```bash
./scripts/restore-database.sh 20260222_143015
```

### Database Sync (Production → Development)
```bash
# On dev machine
cd /Users/ericsmith66/development/agent-forge/projects/nextgen-plaid
bin/sync-from-prod --dry-run  # Preview
bin/sync-from-prod            # Full sync (⚠️ overwrites local DBs)
```

---

## Rollback Procedures

### Scenario 1: Bad Migration (Database Issues)
**Estimated time:** 10-20 minutes

```bash
# 1. Stop app
ssh ericsmith66@192.168.4.253 "launchctl unload ~/Library/LaunchAgents/com.agentforge.nextgen-plaid.plist"

# 2. Find backup timestamp
ssh ericsmith66@192.168.4.253 "ls -lt ~/backups/nextgen-plaid/ | head -5"

# 3. Restore database
ssh ericsmith66@192.168.4.253 "cd /Users/ericsmith66/Development/nextgen-plaid && ./scripts/restore-database.sh <TIMESTAMP>"

# 4. Rollback code
ssh ericsmith66@192.168.4.253 "cd /Users/ericsmith66/Development/nextgen-plaid && git reset --hard <SHA>"

# 5. Restart
ssh ericsmith66@192.168.4.253 "launchctl load ~/Library/LaunchAgents/com.agentforge.nextgen-plaid.plist"

# 6. Verify
sleep 20 && curl "http://192.168.4.253:3000/health?token=<HEALTH_TOKEN>"
```

### Scenario 2: Bad Code (No DB Changes)
**Estimated time:** 2-5 minutes

```bash
ssh ericsmith66@192.168.4.253 "cd /Users/ericsmith66/Development/nextgen-plaid && git reset --hard <SHA>"
ssh ericsmith66@192.168.4.253 "launchctl kickstart -k gui/501/com.agentforge.nextgen-plaid"
sleep 20 && curl "http://192.168.4.253:3000/health?token=<HEALTH_TOKEN>"
```

---

## Reboot Verification Checklist

After any reboot of 192.168.4.253:

```bash
ssh ericsmith66@192.168.4.253 '
  echo "=== LaunchAgents ==="
  launchctl list com.agentforge.nextgen-plaid | grep -E "PID|LastExit"
  launchctl list com.agentforge.smart-proxy | grep -E "PID|LastExit"
  echo "=== Ports ==="
  lsof -i :3000 -i :3001 -i :5432 -i :6379 -i :11434 2>/dev/null | grep LISTEN
'

# Health checks
curl "http://192.168.4.253:3000/health?token=<HEALTH_TOKEN>"
curl "http://192.168.4.253:3001/health"
```

**Expected:** All ports listening, both LaunchAgents show PID + LastExitStatus=0, both health endpoints return `{"status":"ok"}`.

---

## Key Differences from Previous Setup

### What Changed (February 25, 2026)

| Aspect | Old (Pre-Feb 25) | New (Current) |
|--------|------------------|---------------|
| **Rails Version** | 7.x | 8.1.1 |
| **Ruby Version** | 3.3.0 | 3.3.10 |
| **Secrets** | macOS Keychain | `.env.production` files |
| **Process Mgmt** | `bin/prod` script | LaunchAgents |
| **LLM Proxy** | None | SmartProxy on port 3001 |
| **Health Endpoint** | `/admin/health` (auth) | `/health?token=` (public with token) |
| **Deployment** | Docker Compose (planned) | Native macOS |
| **Auto-start** | Manual | LaunchAgents (auto-start on boot) |
| **SSH Agent** | Not configured | Configured in `~/.zshenv` |
| **FileVault** | Enabled | Disabled (allows auto-login) |

---

## Outstanding Issues

| Issue | Priority | Notes |
|---|---|---|
| SmartProxy running in Sinatra `development` env | P3 | Cosmetic — set `RACK_ENV=production` in plist if needed |
| CSV stdlib deprecation warning | P3 | Ruby 3.4 change — address when upgrading Ruby |
| No Prometheus/Grafana monitoring | P2 | Observability gap — recommended for Phase 2 |
| No structured JSON logging | P2 | Rails logs still in text format |

---

## Testing Performed (February 25, 2026)

### Reboot Test ✅
Machine rebooted at ~12:23 on February 25, 2026. All services verified after reboot:

| Service | Port | PID (post-reboot) | Auto-started |
|---------|------|-------------------|--------------|
| nextgen-plaid (Puma) | 3000 | 678 | ✅ LaunchAgent |
| SolidQueue (worker + scheduler) | — | 700 | ✅ via Foreman |
| SmartProxy | 3001 | 1571 | ✅ LaunchAgent |
| PostgreSQL 16 | 5432 | 458 | ✅ Homebrew LaunchAgent |
| Redis | 6379 | 443 | ✅ Homebrew LaunchAgent |
| Ollama | 11434 | 566 | ✅ Login Item |

**Post-reboot health checks:**
- `GET /health?token=...` → `{"status":"ok"}` ✅
- `GET :3001/health` → `{"status":"ok"}` ✅

---

## Related Documentation

### In overwatch Repository
- **Team Guide:** `docs/team-guides/NEXTGEN-PLAID-DEPLOYMENT-TEAM-GUIDE.md` (v2.0)
- **Obsolete Deployment Guide:** `docs/deployment/deployment-nextgen-plaid.md` (marked obsolete)
- **DevOps Assessment:** `docs/assessments/devops-assessment.md`

### In nextgen-plaid Repository
- **RUNBOOK:** `RUNBOOK.md` (v2.0) — **AUTHORITATIVE SOURCE**
- **Session Report:** `docs/devops-session-report-20260225.md`
- **Deploy Script:** `bin/deploy-prod`
- **Backup Script:** `scripts/backup-database.sh`
- **Restore Script:** `scripts/restore-database.sh`

---

**Document End**  
*Last Updated: February 25, 2026*
