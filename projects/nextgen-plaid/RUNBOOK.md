# nextgen-plaid Operations Runbook

**Version:** 2.0  
**Last Updated:** February 25, 2026  
**Owner:** Agent Forge Team

---

## Table of Contents

1. [Service Overview](#service-overview)
2. [Architecture](#architecture)
3. [SSH Access & Environment Setup](#ssh-access--environment-setup)
4. [Operations — nextgen-plaid](#operations--nextgen-plaid)
5. [Operations — SmartProxy](#operations--smartproxy)
6. [Database Management](#database-management)
7. [Deployment](#deployment)
8. [Secrets Management](#secrets-management)
9. [Health Checks](#health-checks)
10. [Troubleshooting](#troubleshooting)
11. [Rollback Procedures](#rollback-procedures)
12. [Emergency Contacts](#emergency-contacts)
13. [Appendix](#appendix)

---

## Service Overview

### Description
nextgen-plaid is a Rails 8.1.1 application providing financial account aggregation and AI-powered financial insights using Plaid and Anthropic Claude APIs. It is accompanied by SmartProxy, a Sinatra-based LLM routing proxy that sits between the Rails app and AI providers (Ollama, Claude, Grok).

### Production Environment
- **Server:** 192.168.4.253 (M3 Ultra, hostname: `nextgen`)
- **User:** ericsmith66
- **App Path:** `/Users/ericsmith66/Development/nextgen-plaid`
- **SmartProxy Path:** `/Users/ericsmith66/Development/nextgen-plaid/smart_proxy`
- **Rails Port:** 3000
- **SmartProxy Port:** 3001
- **Environment:** production
- **Auto-login:** Enabled (required for LaunchAgents to fire on boot)

### Key Technologies
- **Framework:** Ruby on Rails 8.1.1
- **Ruby Version:** 3.3.10 (rbenv)
- **Database:** PostgreSQL 16
- **Queue:** Solid Queue (database-backed)
- **Cable:** Action Cable (database-backed)
- **Cache:** Solid Cache (database-backed)
- **Process Manager:** launchd LaunchAgents (KeepAlive + RunAtLoad)
- **Web Server:** Puma 7.1.0 (via Foreman)
- **LLM Proxy:** SmartProxy (Sinatra/Rack, port 3001)

### Dependencies
- **Plaid API:** Financial data aggregation
- **Anthropic Claude:** AI-powered insights
- **Ollama:** Local LLM inference (port 11434)
- **Grok (xAI):** LLM provider via SmartProxy
- **PostgreSQL:** Primary data store
- **Redis:** Background job support

---

## Architecture

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

### Network
- **Internal Rails Port:** 3000 (HTTP)
- **Internal SmartProxy Port:** 3001 (HTTP)
- **External Access:** Via Cloudflare Tunnel (TBD)
- **Subdomain:** plaid.api.higroundsolution.com (planned)

---

## SSH Access & Environment Setup

### SSH Into Production
```bash
ssh ericsmith66@192.168.4.253
```

**Key:** `~/.ssh/id_ed25519` (passphrase stored in macOS Keychain via `ssh-add --apple-use-keychain`)  
No passphrase prompt — key is cached automatically on GUI login.

### Ruby Environment in SSH Sessions
rbenv is initialised in `~/.zshenv` so all SSH sessions automatically use Ruby 3.3.10:
```bash
ruby -v      # Should show: ruby 3.3.10
which ruby   # Should show: /Users/ericsmith66/.rbenv/shims/ruby
```

If wrong Ruby appears, check `~/.zshenv`:
```bash
cat ~/.zshenv
# Should contain:
# export PATH="/opt/homebrew/bin:$PATH"
# eval "$(rbenv init - zsh)"
```

### Git Pull From Production
SSH agent forwarding is configured. `git pull` works without passphrase:
```bash
ssh ericsmith66@192.168.4.253
cd /Users/ericsmith66/Development/nextgen-plaid
git pull
```

If `git pull` fails with `Permission denied (publickey)`, check SSH agent:
```bash
# On prod machine (SSH session)
ssh-add -l
# If "no identities", the agent socket may have changed after reboot:
export SSH_AUTH_SOCK=$(ls /private/tmp/com.apple.launchd.*/Listeners 2>/dev/null | head -1)
ssh-add -l   # Should now show the key
```

The `~/.zprofile` and `~/.zshenv` on prod both export `SSH_AUTH_SOCK` automatically, but the socket path changes on each reboot — if `git pull` fails, sourcing the profile fixes it:
```bash
source ~/.zprofile && git pull
```

---

## Operations — nextgen-plaid

### Start / Stop / Restart
```bash
# Start (loads LaunchAgent — app starts and stays running)
launchctl load ~/Library/LaunchAgents/com.agentforge.nextgen-plaid.plist

# Stop (unloads — app stops and won't auto-restart)
launchctl unload ~/Library/LaunchAgents/com.agentforge.nextgen-plaid.plist

# Restart (clean kill + immediate restart — used by deploy script)
launchctl kickstart -k gui/501/com.agentforge.nextgen-plaid
```

### What the LaunchAgent Does
- Sources `.env.production` for all secrets (no Keychain dependency)
- Sets `RAILS_ENV=production` and `PORT=3000`
- Runs `foreman start -f Procfile.prod` which manages:
  - **web.1** — Puma on port 3000
  - **worker.1** — SolidQueue (workers + scheduler + dispatcher)
- `KeepAlive true` — auto-restarts on crash
- `RunAtLoad true` — auto-starts on user login
- Logs to `log/launchd.stdout.log` / `log/launchd.stderr.log`

### Check Status
```bash
# LaunchAgent status (look for PID and LastExitStatus=0)
launchctl list com.agentforge.nextgen-plaid

# Puma process
ps aux | grep puma | grep -v grep

# Port binding
lsof -i :3000

# Health check
curl "http://192.168.4.253:3000/health?token=<HEALTH_TOKEN>"
```

### Logs
```bash
# Foreman/Puma startup log
tail -f /Users/ericsmith66/Development/nextgen-plaid/log/launchd.stdout.log

# LaunchAgent errors (startup failures)
tail -f /Users/ericsmith66/Development/nextgen-plaid/log/launchd.stderr.log

# Rails application log
tail -f /Users/ericsmith66/Development/nextgen-plaid/log/production.log
```

---

## Operations — SmartProxy

### Overview
SmartProxy is a Sinatra/Rack application that acts as an OpenAI-compatible API gateway, routing LLM requests to Ollama, Claude, or Grok. The Rails app connects to it on port 3001.

- **Path:** `/Users/ericsmith66/Development/nextgen-plaid/smart_proxy/`
- **Port:** 3001
- **LaunchAgent:** `com.agentforge.smart-proxy`
- **Secrets file:** `smart_proxy/.env`

### Start / Stop / Restart
```bash
# Start
launchctl load ~/Library/LaunchAgents/com.agentforge.smart-proxy.plist

# Stop
launchctl unload ~/Library/LaunchAgents/com.agentforge.smart-proxy.plist

# Restart
launchctl kickstart -k gui/501/com.agentforge.smart-proxy
```

### Check Status
```bash
# LaunchAgent status
launchctl list com.agentforge.smart-proxy

# Port binding
lsof -i :3001

# Health check (no auth required)
curl http://192.168.4.253:3001/health

# Model listing (requires PROXY_AUTH_TOKEN)
curl -H "Authorization: Bearer <PROXY_AUTH_TOKEN>" http://192.168.4.253:3001/v1/models
```

### Secrets File
SmartProxy reads its secrets from `smart_proxy/.env` (separate from the Rails `.env.production`):

| Variable | Description |
|---|---|
| `GROK_API_KEY` | xAI Grok API key |
| `CLAUDE_API_KEY` | Anthropic Claude API key |
| `PROXY_AUTH_TOKEN` | Token Rails uses to authenticate with SmartProxy |
| `SMART_PROXY_PORT` | Port (set to `3001`) |
| `SMART_PROXY_ENABLE_WEB_TOOLS` | Enable web search tools (`true`/`false`) |

To update a secret:
```bash
ssh ericsmith66@192.168.4.253
nano /Users/ericsmith66/Development/nextgen-plaid/smart_proxy/.env
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

### Deploying SmartProxy Changes
SmartProxy is deployed as part of the main repo. After `git pull` on prod, restart SmartProxy:
```bash
cd /Users/ericsmith66/Development/nextgen-plaid/smart_proxy
bundle install
launchctl kickstart -k gui/501/com.agentforge.smart-proxy
```

---

## Database Management

### Connection Details
- **Host:** localhost
- **Port:** 5432
- **User:** nextgen_plaid
- **Password:** stored in `.env.production` as `NEXTGEN_PLAID_DATABASE_PASSWORD`

### Test Connection
```bash
PGPASSWORD=$(grep NEXTGEN_PLAID_DATABASE_PASSWORD /Users/ericsmith66/Development/nextgen-plaid/.env.production | cut -d'=' -f2- | tr -d '"') \
  psql -U nextgen_plaid -d nextgen_plaid_production -c "SELECT 1;"
```

### Database Backups

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

### Database Migrations
```bash
ssh ericsmith66@192.168.4.253
cd /Users/ericsmith66/Development/nextgen-plaid
source ~/.zprofile && eval "$(/opt/homebrew/bin/rbenv init - bash)"
export RAILS_ENV=production
bin/rails db:migrate          # Run pending migrations
bin/rails db:version          # Check current version
bin/rails db:rollback         # Rollback last migration
```

### Database Sync (Production → Development)
```bash
# On dev machine
cd /Users/ericsmith66/development/agent-forge/projects/nextgen-plaid
bin/sync-from-prod --dry-run  # Preview
bin/sync-from-prod            # Full sync (⚠️ overwrites local DBs)
```

---

## Deployment

### Prerequisites
Before running `bin/deploy-prod`, ensure:
1. You are on the `main` branch locally with no uncommitted changes
2. SSH access to 192.168.4.253 works (`ssh ericsmith66@192.168.4.253 "echo ok"`)
3. The LaunchAgent is registered on prod (`launchctl list com.agentforge.nextgen-plaid`)
4. `HEALTH_TOKEN` is set in `.env.production` on prod

### Deploy From Dev Machine
```bash
cd /Users/ericsmith66/development/agent-forge/projects/nextgen-plaid
bin/deploy-prod
```

Options:
```bash
bin/deploy-prod --skip-tests    # Skip test suite (faster)
bin/deploy-prod --skip-backup   # Skip DB backup (⚠️ not recommended)
```

### Deployment Phases
The script executes 7 phases automatically:

| Phase | Action | Time |
|---|---|---|
| 1 — Pre-flight | Branch check, SSH check, HEALTH_TOKEN check, LaunchAgent check, tests | ~30s |
| 2 — Backup | pg_dump all 4 databases | 2-5 min |
| 3 — Pull code | `git fetch` + `git reset --hard origin/main` | ~15s |
| 4 — Dependencies | `bundle install --without development test` | 30-60s |
| 5 — Migrations | `RAILS_ENV=production bin/rails db:migrate` | 1-5 min |
| 6 — Assets | `RAILS_ENV=production bin/rails assets:precompile` | 30-90s |
| 7 — Restart | `launchctl kickstart -k` + health check retry loop (5×6s) | ~30s |

**Total time:** 5-15 minutes

### SmartProxy Is NOT Automatically Deployed
SmartProxy does not have an asset pipeline or migrations, but its bundle must be kept up to date. After deploying the Rails app, if `smart_proxy/Gemfile` changed:
```bash
ssh ericsmith66@192.168.4.253
cd /Users/ericsmith66/Development/nextgen-plaid/smart_proxy
bundle install
launchctl kickstart -k gui/501/com.agentforge.smart-proxy
```

### Manual Deployment Steps (if script unavailable)
```bash
ssh ericsmith66@192.168.4.253
cd /Users/ericsmith66/Development/nextgen-plaid
source ~/.zprofile && eval "$(/opt/homebrew/bin/rbenv init - bash)"

git pull
bundle install --without development test
export RAILS_ENV=production
bin/rails db:migrate
bin/rails assets:precompile
launchctl kickstart -k gui/501/com.agentforge.nextgen-plaid

# Verify
sleep 20
curl "http://192.168.4.253:3000/health?token=<HEALTH_TOKEN>"
```

---

## Secrets Management

### nextgen-plaid Secrets (`.env.production`)
**Location:** `/Users/ericsmith66/Development/nextgen-plaid/.env.production`  
**Never committed to git** (in `.gitignore`)  
**Backup:** `~/.env.production.backup.YYYYMMDD_HHMMSS`

| Variable | Description |
|---|---|
| `NEXTGEN_PLAID_DATABASE_PASSWORD` | PostgreSQL password |
| `PLAID_CLIENT_ID` | Plaid API Client ID |
| `PLAID_SECRET` | Plaid API Secret |
| `CLAUDE_API_KEY` | Anthropic Claude API Key |
| `RAILS_MASTER_KEY` | Rails credentials encryption key |
| `ENCRYPTION_KEY` | ActiveRecord encryption key (64 hex chars) |
| `HEALTH_TOKEN` | Token for `/health` endpoint |
| `SMART_PROXY_PORT` | SmartProxy port (3001) |
| `PORT` | Rails port (3000) |

### SmartProxy Secrets (`smart_proxy/.env`)
**Location:** `/Users/ericsmith66/Development/nextgen-plaid/smart_proxy/.env`  
**Never committed to git**

| Variable | Description |
|---|---|
| `GROK_API_KEY` | xAI Grok API key |
| `CLAUDE_API_KEY` | Anthropic Claude API Key |
| `PROXY_AUTH_TOKEN` | Token for Rails → SmartProxy auth |
| `SMART_PROXY_PORT` | Port (3001) |
| `SMART_PROXY_ENABLE_WEB_TOOLS` | Enable web search (true/false) |

### Update a Secret
```bash
ssh ericsmith66@192.168.4.253

# Rails secrets
nano /Users/ericsmith66/Development/nextgen-plaid/.env.production
launchctl kickstart -k gui/501/com.agentforge.nextgen-plaid

# SmartProxy secrets
nano /Users/ericsmith66/Development/nextgen-plaid/smart_proxy/.env
launchctl kickstart -k gui/501/com.agentforge.smart-proxy
```

---

## Health Checks

### Full System Check
```bash
ssh ericsmith66@192.168.4.253 '
  echo "=== LaunchAgents ===" 
  launchctl list com.agentforge.nextgen-plaid | grep -E "PID|LastExit"
  launchctl list com.agentforge.smart-proxy | grep -E "PID|LastExit"
  echo "=== Ports ==="
  lsof -i :3000 -i :3001 -i :5432 -i :6379 -i :11434 2>/dev/null | grep LISTEN
'
```

### nextgen-plaid Health Endpoint
```bash
# Returns {"status":"ok"} + HTTP 200 if healthy
# Returns {"status":"error"} + HTTP 401 if token wrong/missing
# Returns {"status":"error"} + HTTP 503 if DB down or token not configured
curl "http://192.168.4.253:3000/health?token=<HEALTH_TOKEN>"
```
`HEALTH_TOKEN` is in `.env.production` on prod.

### SmartProxy Health Endpoint
```bash
# No auth required
curl http://192.168.4.253:3001/health
# Expected: {"status":"ok"}
```

### Database Health
```bash
ssh ericsmith66@192.168.4.253 '
  source ~/.zprofile && eval "$(/opt/homebrew/bin/rbenv init - bash)"
  DB_PASS=$(grep NEXTGEN_PLAID_DATABASE_PASSWORD /Users/ericsmith66/Development/nextgen-plaid/.env.production | cut -d= -f2- | tr -d "\"")
  PGPASSWORD="$DB_PASS" psql -U nextgen_plaid -d nextgen_plaid_production -c "SELECT COUNT(*) FROM ar_internal_metadata;"
'
```

---

## Troubleshooting

### nextgen-plaid Won't Start

**Check launchd logs first:**
```bash
tail -50 /Users/ericsmith66/Development/nextgen-plaid/log/launchd.stderr.log
tail -50 /Users/ericsmith66/Development/nextgen-plaid/log/launchd.stdout.log
tail -50 /Users/ericsmith66/Development/nextgen-plaid/log/production.log
```

**Check LaunchAgent exit status:**
```bash
launchctl list com.agentforge.nextgen-plaid
# LastExitStatus=0 = running
# LastExitStatus=9 = killed (normal after kickstart -k)
# LastExitStatus=256 = crashed
# No PID = not running
```

**Port already in use:**
```bash
lsof -i :3000
# Kill the occupying process, then:
launchctl kickstart -k gui/501/com.agentforge.nextgen-plaid
```

**Secrets missing:**
```bash
cat /Users/ericsmith66/Development/nextgen-plaid/.env.production
# Verify all required keys are present
```

### SmartProxy Won't Start

**Check logs:**
```bash
tail -20 /Users/ericsmith66/Development/nextgen-plaid/log/smart_proxy.stderr.log
tail -20 /Users/ericsmith66/Development/nextgen-plaid/log/smart_proxy.stdout.log
```

**Port conflict:**
```bash
lsof -i :3001
```

**Bundle missing:**
```bash
cd /Users/ericsmith66/Development/nextgen-plaid/smart_proxy
bundle check || bundle install
launchctl kickstart -k gui/501/com.agentforge.smart-proxy
```

**Rails reports SmartProxy connection refused:**
```bash
# Verify SMART_PROXY_PORT in both env files matches
grep SMART_PROXY_PORT /Users/ericsmith66/Development/nextgen-plaid/.env
grep SMART_PROXY_PORT /Users/ericsmith66/Development/nextgen-plaid/.env.production
# Both should be 3001
```

### git pull Fails on Prod

```bash
# Check SSH agent
ssh-add -l
# If no identities:
export SSH_AUTH_SOCK=$(ls /private/tmp/com.apple.launchd.*/Listeners 2>/dev/null | head -1)
ssh-add -l   # Should show key now
git pull
```

### Database Connection Errors

```bash
# Verify password
grep NEXTGEN_PLAID_DATABASE_PASSWORD /Users/ericsmith66/Development/nextgen-plaid/.env.production

# Test connection
PGPASSWORD='<PASSWORD>' psql -U nextgen_plaid -d nextgen_plaid_production -c "SELECT 1;"

# Reset password if needed (run on prod)
psql -U ericsmith66 -d postgres -c "ALTER USER nextgen_plaid WITH PASSWORD '<NEW_PASSWORD>';"
# Then update .env.production
```

### Migration Failures

```bash
ssh ericsmith66@192.168.4.253
cd /Users/ericsmith66/Development/nextgen-plaid
source ~/.zprofile && eval "$(/opt/homebrew/bin/rbenv init - bash)"
export RAILS_ENV=production
bin/rails db:migrate 2>&1       # See full error
bin/rails db:rollback           # Rollback if needed
```

### Health Check Fails After Deploy

```bash
# 1. Check launchd
launchctl list com.agentforge.nextgen-plaid

# 2. Check logs
tail -50 log/launchd.stdout.log
tail -50 log/production.log

# 3. Force restart
launchctl kickstart -k gui/501/com.agentforge.nextgen-plaid
sleep 20
curl "http://192.168.4.253:3000/health?token=<HEALTH_TOKEN>"
```

### Plaid API Errors

```bash
# Verify credentials
grep PLAID_SECRET /Users/ericsmith66/Development/nextgen-plaid/.env.production
# Check Plaid dashboard: https://dashboard.plaid.com
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

# 4. Rollback code (get SHA from .last_commit)
ssh ericsmith66@192.168.4.253 "cd /Users/ericsmith66/Development/nextgen-plaid && cat .last_commit"
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

### Rollback Checklist
- [ ] nextgen-plaid health endpoint returns HTTP 200
- [ ] SmartProxy health endpoint returns `{"status":"ok"}`
- [ ] Database connections working
- [ ] SolidQueue workers running
- [ ] No errors in `log/production.log`

---

## Emergency Contacts

| Role | Contact | Availability |
|---|---|---|
| Primary | Eric Smith | 24/7 |
| Secondary | TBD | Business hours |

| Service | Support |
|---|---|
| Plaid API | https://plaid.com/support |
| Anthropic | https://console.anthropic.com |
| xAI (Grok) | https://x.ai/api |

---

## Appendix

### LaunchAgent Reference

| Label | Plist | Port | Log |
|---|---|---|---|
| `com.agentforge.nextgen-plaid` | `~/Library/LaunchAgents/com.agentforge.nextgen-plaid.plist` | 3000 | `log/launchd.stdout.log` |
| `com.agentforge.smart-proxy` | `~/Library/LaunchAgents/com.agentforge.smart-proxy.plist` | 3001 | `log/smart_proxy.stdout.log` |
| `homebrew.mxcl.postgresql@16` | `~/Library/LaunchAgents/homebrew.mxcl.postgresql@16.plist` | 5432 | `/opt/homebrew/var/log/postgresql@16.log` |
| `homebrew.mxcl.redis` | `~/Library/LaunchAgents/homebrew.mxcl.redis.plist` | 6379 | — |
| Ollama.app | Login Item (macOS) | 11434 | — |

### File Locations

| Path | Purpose |
|---|---|
| `/Users/ericsmith66/Development/nextgen-plaid` | Rails app root |
| `/Users/ericsmith66/Development/nextgen-plaid/smart_proxy` | SmartProxy root |
| `.env.production` | Rails production secrets (not in git) |
| `smart_proxy/.env` | SmartProxy secrets (not in git) |
| `~/.env.production.backup.*` | Secrets backup |
| `~/backups/nextgen-plaid/` | Database backups |
| `log/production.log` | Rails application log |
| `log/launchd.stdout.log` | Foreman/Puma startup log |
| `log/launchd.stderr.log` | LaunchAgent error log |
| `log/smart_proxy.log` | SmartProxy structured JSON log |
| `log/smart_proxy.stderr.log` | SmartProxy access log |
| `~/Library/LaunchAgents/` | All launchd plist files |

### Scripts Reference

| Script | Purpose | Usage |
|---|---|---|
| `bin/dev` | Start development server (port 3016) | `bin/dev` |
| `bin/prod` | Legacy production launcher (replaced by launchd) | — |
| `bin/deploy-prod` | Deploy to production | `bin/deploy-prod` |
| `bin/sync-from-prod` | Sync prod DB to local dev | `bin/sync-from-prod` |
| `scripts/backup-database.sh` | Manual database backup | `./scripts/backup-database.sh` |
| `scripts/restore-database.sh` | Restore database from backup | `./scripts/restore-database.sh <TIMESTAMP>` |

### Reboot Verification Checklist

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

Expected: All ports listening, both LaunchAgents show PID + LastExitStatus=0, both health endpoints return `{"status":"ok"}`.

---

**Document End**  
*Version 2.0 — February 25, 2026*
