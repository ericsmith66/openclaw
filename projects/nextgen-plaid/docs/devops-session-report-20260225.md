# DevOps Session Report
**Date:** February 25, 2026  
**Application:** nextgen-plaid + SmartProxy  
**Prepared by:** Eric Smith  
**Session type:** Production infrastructure audit, deployment fix & service hardening

---

## 1. Executive Summary

A full audit of the development and production environments was conducted. Fourteen issues were identified and resolved — including multiple deployment-blocking problems. All services are now managed by launchd LaunchAgents with auto-restart and auto-start on boot. A full production reboot test was performed and passed.

---

## 2. Environment

| | Development | Production |
|---|---|---|
| **Machine** | Local MacBook | 192.168.4.253 (M3 Ultra, hostname: `nextgen`) |
| **OS** | macOS Tahoe | macOS Tahoe |
| **User** | ericsmith66 | ericsmith66 |
| **Rails Path** | `/Users/ericsmith66/development/agent-forge/projects/nextgen-plaid` | `/Users/ericsmith66/Development/nextgen-plaid` |
| **SmartProxy Path** | (same repo) `smart_proxy/` | `/Users/ericsmith66/Development/nextgen-plaid/smart_proxy` |
| **Ruby** | 3.3.10 (rbenv) | 3.3.10 (rbenv) |
| **Rails** | 8.1.1 | 8.1.1 |
| **Branch** | main | main |

---

## 3. Issues Found & Resolved

### 3.1 Dev/Prod Branch Out of Sync (P0)
**Issue:** Production was 3 commits behind development with 9 locally modified/deleted files.  
**Fix:** Applied missing commits manually via file copy while SSH agent issue was being resolved.  
**Commits synced to prod:**
- `f8ceaef` — Remove empty stub files causing Zeitwerk autoloading errors
- `6309e80` — Fix PATH for PostgreSQL tools in bin/prod
- `d08d354` — Phase 1: Implement Foreman-based production launcher

---

### 3.2 SSH Agent Not Available in SSH Sessions (P0)
**Issue:** `git pull` on prod failed — `Permission denied (publickey)`. The macOS SSH agent socket (`SSH_AUTH_SOCK`) was not exported in non-GUI SSH sessions.  
**Fix applied to prod `~/.zprofile` and `~/.zshenv`:**
```bash
export SSH_AUTH_SOCK=$(ls /private/tmp/com.apple.launchd.*/Listeners 2>/dev/null | head -1)
```
**Key added to macOS Keychain (run once):**
```bash
ssh-add --apple-use-keychain ~/.ssh/id_ed25519
```
**Result:** `git pull` works in SSH sessions without passphrase prompt.

**Note:** The `SSH_AUTH_SOCK` socket path changes on each reboot. If `git pull` fails after a reboot, run:
```bash
source ~/.zprofile && git pull
```

---

### 3.3 Wrong Ruby Version in SSH Sessions (P0)
**Issue:** SSH sessions used system Ruby 2.6.10 instead of rbenv Ruby 3.3.10 — bundler 2.7.1 not available.  
**Root cause:** `rbenv init` was only in `~/.zshrc` (interactive shells), not `~/.zshenv` (all shells including SSH).  
**Fix added to prod `~/.zshenv`:**
```bash
export PATH="/opt/homebrew/bin:$PATH"
eval "$(rbenv init - zsh)"
```
**Result:** All SSH sessions now use Ruby 3.3.10 automatically.

---

### 3.4 FileVault Blocked Auto-Login (P0)
**Issue:** FileVault was enabled on prod, which prevents auto-login. LaunchAgents require a GUI login session to fire — without auto-login, services would not restart after a reboot.  
**Fix:**
- Disabled FileVault on production Mac
- Enabled auto-login for `ericsmith66` in System Settings → Users & Groups

---

### 3.5 No Auto-Start on Reboot for nextgen-plaid (P0)
**Issue:** nextgen-plaid ran via manual Foreman invocation with no supervision or auto-start.  
**Fix:** Created `~/Library/LaunchAgents/com.agentforge.nextgen-plaid.plist`:
- `RunAtLoad true` — starts on login
- `KeepAlive true` — auto-restarts on crash
- `ThrottleInterval 10` — prevents rapid restart loops
- Loads `.env.production` for secrets
- Runs `foreman start -f Procfile.prod` → Puma (port 3000) + SolidQueue
- Logs to `log/launchd.stdout.log` / `log/launchd.stderr.log`

---

### 3.6 No Auto-Start on Reboot for SmartProxy (P0)
**Issue:** SmartProxy had no LaunchAgent — not running after reboot. Rails app was logging `SmartProxy /v1/models discovery skipped: Errno::ECONNREFUSED` on every boot.  
**Fix:** Created `~/Library/LaunchAgents/com.agentforge.smart-proxy.plist`:
- Same KeepAlive/RunAtLoad pattern as nextgen-plaid
- Runs `bundle exec rackup config.ru -p 3001 -o 0.0.0.0` from `smart_proxy/`
- Created `smart_proxy/.env` with required secrets
- Logs to `log/smart_proxy.stdout.log` / `log/smart_proxy.stderr.log`

---

### 3.7 SmartProxy Port Mismatch (P0)
**Issue:** Rails initializer defaults SmartProxy to port 3001 in production, but `.env` and `smart_proxy/.env.example` showed port 4567/3002. `.env` (loaded first by dotenv) had `SMART_PROXY_PORT=3002` overriding `.env.production`'s `SMART_PROXY_PORT=3001`.  
**Fix:**
- Set `SMART_PROXY_PORT=3001` in `smart_proxy/.env`
- Updated `SMART_PROXY_PORT=3001` in `.env` on prod (was 3002)
- Added `SMART_PROXY_PORT=3001` to `.env.production` on prod

---

### 3.8 Secrets Locked in SSH Sessions (P0)
**Issue:** `bin/prod` read secrets from macOS Keychain, which is locked in SSH sessions and unavailable headlessly — service couldn't start via launchd.  
**Root cause:** Keychain requires GUI interaction to unlock.  
**Fix:** `.env.production` already existed on prod with all secrets. LaunchAgent loads it via:
```bash
set -a; source .env.production; set +a
```
**Backup created:** `~/.env.production.backup.20260225_114505` on prod.

---

### 3.9 `launchctl` in Deploy Script Referenced Non-Existent Service (P0)
**Issue:** `bin/deploy-prod` used `launchctl stop/start com.agentforge.nextgen-plaid` but no plist was registered — restart phase silently failed.  
**Fix:** Updated to use:
```bash
launchctl kickstart -k gui/<UID>/com.agentforge.nextgen-plaid
```
Added pre-flight check to verify the LaunchAgent is registered before proceeding.

---

### 3.10 Health Check Endpoint Returned 404 (P0)
**Issue:** `bin/deploy-prod` checked `GET /health` which returned 404. The only health endpoint was `GET /admin/health` — authenticated, not usable for automated checks.  
**Fix:** Created new public health endpoint:
- **Route:** `GET /health?token=<HEALTH_TOKEN>`
- **Controller:** `app/controllers/health_controller.rb`
- **Auth:** Timing-safe token comparison (`ActiveSupport::SecurityUtils.secure_compare`)
- **Fail closed:** Returns 503 if `HEALTH_TOKEN` not configured
- **DB check:** Runs `SELECT 1` on every request
- **SSL:** Excluded from `force_ssl` redirect
- **Logging:** Silenced in production logs

---

### 3.11 `bundle install --deployment` Flag (P1)
**Issue:** Deploy script used `bundle install --deployment` — requires `vendor/bundle` setup not configured on prod.  
**Fix:** Changed to `bundle install --without development test`.

---

### 3.12 `RAILS_ENV` Not Set in Remote Commands (P1)
**Issue:** `run_remote` helper in `bin/deploy-prod` didn't export `RAILS_ENV=production` — migrations could default to development.  
**Fix:** Added `export RAILS_ENV=production` to the `run_remote` function.

---

### 3.13 Fixed Sleep Before Health Check (P1)
**Issue:** Deploy script waited a fixed 8 seconds before health check — unreliable for cold starts.  
**Fix:** Replaced with retry loop: 5 attempts × 6 second intervals.

---

### 3.14 RUNBOOK.md Outdated (P2)
**Issue:** RUNBOOK listed Rails 7.2, Ruby 3.3.0, referenced Keychain-based secrets and non-existent launchd config. No mention of SmartProxy.  
**Fix:** Full rewrite to RUNBOOK v2.0 — Rails 8.1.1, Ruby 3.3.10, launchd, `.env.production`, SmartProxy, SSH setup, health endpoints.

---

## 4. Files Changed

### In Git (committed to `main`)

| File | Change |
|---|---|
| `app/controllers/health_controller.rb` | **New** — public token-authenticated health endpoint |
| `config/routes.rb` | Added `GET /health` route |
| `config/environments/production.rb` | Excluded `/health` from SSL redirect; silenced in logs |
| `bin/deploy-prod` | Full overhaul — launchctl, RAILS_ENV, bundle flags, retry health check |
| `test/controllers/health_controller_test.rb` | **New** — 6 tests covering all token auth branches |
| `RUNBOOK.md` | Full rewrite v2.0 |
| `docs/devops-handover.md` | **New** — DevOps handover document |
| `docs/devops-session-report-20260225.md` | **New** — this document |

### On Production Server Only (not in git)

| File | Change | Notes |
|---|---|---|
| `~/Library/LaunchAgents/com.agentforge.nextgen-plaid.plist` | **New** | Rails app LaunchAgent |
| `~/Library/LaunchAgents/com.agentforge.smart-proxy.plist` | **New** | SmartProxy LaunchAgent |
| `.env.production` | Added `HEALTH_TOKEN`, `SMART_PROXY_PORT=3001` | Rails secrets |
| `.env` | Updated `SMART_PROXY_PORT` from 3002 → 3001 | Dotenv override fix |
| `smart_proxy/.env` | **New** | SmartProxy secrets |
| `~/.zshenv` | **New** | rbenv init + SSH_AUTH_SOCK for all sessions |
| `~/.zprofile` | Added `SSH_AUTH_SOCK` export | GUI sessions |
| `~/.env.production.backup.20260225_114505` | **New** | Secrets backup |

---

## 5. Testing Performed

### 5.1 Unit Tests
| Test File | Tests | Result |
|---|---|---|
| `test/controllers/health_controller_test.rb` | 6 | ✅ All passing |

Test cases:
- Valid token → HTTP 200 + `{"status":"ok"}` ✅
- Wrong token → HTTP 401 ✅
- Blank token → HTTP 401 ✅
- Missing token → HTTP 401 ✅
- `HEALTH_TOKEN` not configured → HTTP 503 ✅
- DB unavailable → HTTP 503 ✅

### 5.2 Production Smoke Tests (pre-reboot)
| Test | Result |
|---|---|
| nextgen-plaid LaunchAgent starts Puma | ✅ |
| SmartProxy LaunchAgent starts Rack | ✅ |
| `/health` returns `{"status":"ok"}` | ✅ |
| Wrong token returns HTTP 401 | ✅ |
| SmartProxy `/health` returns `{"status":"ok"}` | ✅ |
| SmartProxy `/v1/models` returns model list | ✅ |
| Rails app connects to SmartProxy on port 3001 | ✅ |
| Rails running in production mode | ✅ |
| SolidQueue worker + scheduler running | ✅ |
| Ruby 3.3.10 in SSH sessions | ✅ |
| `git pull` works without passphrase | ✅ |

### 5.3 Reboot Test ✅
Machine rebooted at ~12:23 on February 25, 2026. All services verified after reboot:

| Service | Port | PID (post-reboot) | Auto-started |
|---|---|---|---|
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

## 6. Outstanding Issues

| Issue | Priority | Notes |
|---|---|---|
| Local dev can't push to GitHub (HTTPS remote, no token) | P2 | Use SSH remote or configure GitHub personal access token |
| `image_processing` gem warning in logs | P3 | Cosmetic — add gem to Gemfile when needed |
| CSV stdlib deprecation warning | P3 | Ruby 3.4 change — address when upgrading Ruby |
| SmartProxy running in Sinatra `development` env | P3 | Cosmetic — set `RACK_ENV=production` in smart-proxy plist if needed |

---

## 7. Commit History (this session)

```
202cac1  Add DevOps session report for February 25, 2026
fcd9475  Update RUNBOOK: Rails 8.1.1, Ruby 3.3.10, launchd, .env.production, health endpoint
1f6a87d  Add health controller tests, fix deploy health check URL comment
ec83e1b  Fix deployment: launchd, public health endpoint, deploy script overhaul
f8ceaef  Remove empty stub files causing Zeitwerk autoloading errors in production
6309e80  Fix PATH for PostgreSQL tools in bin/prod
d08d354  Phase 1: Implement Foreman-based production launcher
```

---

## 8. Reboot Verification Checklist (for future use)

After any reboot of 192.168.4.253:

```bash
ssh ericsmith66@192.168.4.253 '
  echo "=== LaunchAgents ==="
  launchctl list com.agentforge.nextgen-plaid | grep -E "PID|LastExit"
  launchctl list com.agentforge.smart-proxy | grep -E "PID|LastExit"
  echo "=== Ports ==="
  lsof -i :3000 -i :3001 -i :5432 -i :6379 -i :11434 2>/dev/null | grep LISTEN
'
curl "http://192.168.4.253:3000/health?token=<HEALTH_TOKEN>"
curl "http://192.168.4.253:3001/health"
```

Expected: All ports listening, both LaunchAgents show PID + `LastExitStatus=0`, both health checks return `{"status":"ok"}`.

---

*Document generated: February 25, 2026*
