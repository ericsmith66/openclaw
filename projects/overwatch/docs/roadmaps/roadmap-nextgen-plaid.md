# NextGen Plaid — Production Deployment Roadmap
**Created:** February 17, 2026  
**Priority:** P0 — First application to production  
**Parent:** [roadmap-environment.md](roadmap-environment.md)  
**Approach:** Native macOS, no Docker

---

## Current State (as of Feb 17, 2026)

### What's Running on Production (192.168.4.253)
```
foreman (PID 12143, started Feb 9 via terminal ttys003)
├── puma 7.1.0 — Rails app on :3000       [RAILS_ENV=development] ⚠️
│   └── port 80 → pf rdr → :3000          [/etc/pf.anchors/com.nextgen.plaid]
├── puma 7.1.0 — SmartProxy on :3002      [Sinatra, proxies to Claude/Grok/Ollama]
├── solid-queue-scheduler × 2             [workers]
└── tailwindcss --watch                   [unnecessary in prod] ⚠️

Ollama (separate macOS app, auto-starts on login)
└── localhost:11434  [llama3.1:70b, palmyra-fin-70b, groq-tool-use:70b, nomic-embed-text]
```

**Traffic path:** Internet → UDM-SE firewall → port 80 on 192.168.4.253 → macOS `pf` redirect → port 3000 (Puma).  
**SmartProxy** is internal-only (:3002) — it fronts Claude API, Grok API, and local Ollama for the Rails app.  
**Ollama** provides zero-cloud-cost AI inference (70B models fit in the 256GB RAM).

### Problems to Fix
| # | Problem | Risk |
|---|---------|------|
| 1 | `RAILS_ENV=development` | Uncompiled assets, verbose errors exposed, no caching, debug mode |
| 2 | Manual terminal launch | App dies if terminal closes, Mac restarts, or SSH disconnects |
| 3 | Plaintext secrets in `.env` | All API keys readable on disk |
| 4 | No health check endpoint | Can't verify app is running without manual curl |
| 5 | Tailwind watcher running in prod | Wastes CPU, unnecessary — assets should be precompiled |
| 6 | Dev 8+ commits ahead of prod | `feature/epic-6` on dev, `main` (fbc0064) on prod |
| 7 | No deploy script | Manual SSH → git pull → restart |
| 8 | No runbook | No documented recovery procedures |

---

## Step 1: Create Production Procfile
> **What:** A `Procfile.prod` that runs only what production needs.  
> **Where:** `nextgen-plaid/Procfile.prod` (new file, committed to repo)

```
web: bin/rails server -b 0.0.0.0 -p ${PORT:-3000} -e production
proxy: cd smart_proxy && SMART_PROXY_PORT=3002 bundle exec rackup -o 0.0.0.0 -p 3002
worker: RAILS_ENV=production bin/rails solid_queue:start
```

**What's different from `Procfile.dev`:**
- No `tailwindcss:watch` (assets are precompiled)
- No `RUBY_DEBUG_OPEN`
- Explicit `RAILS_ENV=production`
- No `-e production` needed on worker since env var handles it

> **Note:** The `proxy:` line is temporary. After SmartProxy extraction (Phase 1.5), it will be removed — SmartProxy will run as its own launchd service. Keeping it here for Phase 1 so we don't change two things at once.

---

## Step 2: Create `bin/prod` Launcher
> **What:** A startup script for production, equivalent to `bin/dev`.  
> **Where:** `nextgen-plaid/bin/prod` (new file, committed to repo)

```bash
#!/usr/bin/env bash
set -e

APP_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$APP_DIR"

# ── Load secrets from macOS Keychain ──
export PLAID_CLIENT_ID=$(security find-generic-password -a "nextgen-plaid" -s "PLAID_CLIENT_ID" -w 2>/dev/null)
export PLAID_SECRET=$(security find-generic-password -a "nextgen-plaid" -s "PLAID_SECRET" -w 2>/dev/null)
export ENCRYPTION_KEY=$(security find-generic-password -a "nextgen-plaid" -s "ENCRYPTION_KEY" -w 2>/dev/null)
export CLAUDE_CODE_API_KEY=$(security find-generic-password -a "nextgen-plaid" -s "CLAUDE_CODE_API_KEY" -w 2>/dev/null)
export GROK_API_KEY=$(security find-generic-password -a "nextgen-plaid" -s "GROK_API_KEY" -w 2>/dev/null)
export PROXY_AUTH_TOKEN=$(security find-generic-password -a "nextgen-plaid" -s "PROXY_AUTH_TOKEN" -w 2>/dev/null)
export FINNHUB_API_KEY=$(security find-generic-password -a "nextgen-plaid" -s "FINNHUB_API_KEY" -w 2>/dev/null)
export FMP_API_KEY=$(security find-generic-password -a "nextgen-plaid" -s "FMP_API_KEY" -w 2>/dev/null)
export NEXTGEN_PLAID_DATABASE_PASSWORD=$(security find-generic-password -a "nextgen-plaid" -s "NEXTGEN_PLAID_DATABASE_PASSWORD" -w 2>/dev/null)

# ── Non-secret configuration ──
export RAILS_ENV=production
export PORT="${PORT:-3000}"
export PLAID_ENV=production
export PLAID_REDIRECT_URI=https://api.higroundsolutions.com/plaid_oauth/callback
export PLAID_ENRICH_ENABLED=true
export PLAID_ENRICH_DAILY_LIMIT=20000
export SMART_PROXY_PORT=3002
export SMART_PROXY_ENABLE_WEB_TOOLS=true
export OLLAMA_MODEL=llama3.1:70b
export ENABLE_NEW_LAYOUT=true
export SOLID_QUEUE_IN_PUMA=false

# ── Validate critical secrets loaded ──
if [ -z "$PLAID_SECRET" ] || [ -z "$ENCRYPTION_KEY" ]; then
  echo "FATAL: Could not load secrets from Keychain. Run setup-keychain.sh first."
  exit 1
fi

# ── Ensure foreman is available ──
if ! gem list foreman -i --silent; then
  echo "Installing foreman..."
  gem install foreman
fi

echo "Starting nextgen-plaid in PRODUCTION mode on port $PORT..."
exec foreman start -f Procfile.prod --env /dev/null "$@"
```

**Key design decisions:**
- `--env /dev/null` prevents foreman from loading `.env` files
- Secrets fetched from Keychain at boot, never touch disk
- Validates critical secrets before starting
- Non-secret config is inline (these are not sensitive)

---

## Step 3: Store Secrets in macOS Keychain
> **What:** One-time setup to load all production secrets into Keychain on prod server.  
> **Where:** Run interactively on 192.168.4.253

### Setup Script: `scripts/setup-keychain.sh`
```bash
#!/usr/bin/env bash
# Run this ONCE on the production server to populate Keychain.
# It will prompt for each value interactively.

set -e

APP="nextgen-plaid"

secrets=(
  PLAID_CLIENT_ID
  PLAID_SECRET
  ENCRYPTION_KEY
  CLAUDE_CODE_API_KEY
  GROK_API_KEY
  PROXY_AUTH_TOKEN
  FINNHUB_API_KEY
  FMP_API_KEY
  NEXTGEN_PLAID_DATABASE_PASSWORD
  PROD_USER_PASSWORD
)

echo "=== Keychain Setup for $APP ==="
echo "You will be prompted for each secret value."
echo ""

for secret in "${secrets[@]}"; do
  echo -n "Enter value for $secret: "
  read -s value
  echo ""
  security add-generic-password -a "$APP" -s "$secret" -w "$value" -U
  echo "  ✓ $secret stored"
done

echo ""
echo "=== Verification ==="
for secret in "${secrets[@]}"; do
  val=$(security find-generic-password -a "$APP" -s "$secret" -w 2>/dev/null)
  if [ -n "$val" ]; then
    echo "  ✓ $secret: loaded (${#val} chars)"
  else
    echo "  ✗ $secret: MISSING"
  fi
done
```

### Reading a secret (for debugging):
```bash
security find-generic-password -a "nextgen-plaid" -s "PLAID_SECRET" -w
```

### Updating a secret:
```bash
security add-generic-password -a "nextgen-plaid" -s "PLAID_SECRET" -w "new_value" -U
```

---

## Step 4: Create launchd Plist for Auto-Start
> **What:** macOS LaunchAgent so nextgen-plaid starts on boot and restarts on crash.  
> **Where:** `~/Library/LaunchAgents/com.agentforge.nextgen-plaid.plist` on prod server

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>com.agentforge.nextgen-plaid</string>

  <key>ProgramArguments</key>
  <array>
    <string>/bin/bash</string>
    <string>-lc</string>
    <string>eval "$(/opt/homebrew/bin/brew shellenv)" && eval "$(rbenv init -)" && exec /Users/ericsmith66/Development/nextgen-plaid/bin/prod</string>
  </array>

  <key>WorkingDirectory</key>
  <string>/Users/ericsmith66/Development/nextgen-plaid</string>

  <key>RunAtLoad</key>
  <true/>

  <key>KeepAlive</key>
  <true/>

  <key>StandardOutPath</key>
  <string>/Users/ericsmith66/logs/nextgen-plaid/stdout.log</string>

  <key>StandardErrorPath</key>
  <string>/Users/ericsmith66/logs/nextgen-plaid/stderr.log</string>

  <key>EnvironmentVariables</key>
  <dict>
    <key>PATH</key>
    <string>/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin</string>
    <key>HOME</key>
    <string>/Users/ericsmith66</string>
  </dict>
</dict>
</plist>
```

### Managing the service:
```bash
# Load and start
launchctl load ~/Library/LaunchAgents/com.agentforge.nextgen-plaid.plist

# Stop
launchctl unload ~/Library/LaunchAgents/com.agentforge.nextgen-plaid.plist

# Restart (force kill + auto-restart via KeepAlive)
launchctl kickstart -k gui/$(id -u)/com.agentforge.nextgen-plaid

# Check status
launchctl list | grep nextgen
```

---

## Step 5: Add Health Check Endpoint
> **What:** A `/health` route that returns 200 when the app is operational.  
> **Where:** `nextgen-plaid` Rails app (small code change)

```ruby
# config/routes.rb — add:
get "/health", to: proc {
  [200, { "Content-Type" => "application/json" }, [
    { status: "ok", app: "nextgen-plaid", timestamp: Time.current.iso8601 }.to_json
  ]]
}
```

**Why a proc and not a controller:** Zero overhead, no DB hit, just confirms Puma is alive and routing.

---

## Step 6: Create Deploy Script
> **What:** One-command deploy from dev machine.  
> **Where:** `nextgen-plaid/bin/deploy-prod` (on dev machine, committed to repo)

```bash
#!/usr/bin/env bash
set -e

SERVER="ericsmith66@192.168.4.253"
APP_DIR="~/Development/nextgen-plaid"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)

echo "╔══════════════════════════════════════╗"
echo "║  Deploying nextgen-plaid to prod     ║"
echo "╚══════════════════════════════════════╝"

# 1. Pre-flight: make sure we're deploying from main
CURRENT_BRANCH=$(git branch --show-current)
if [ "$CURRENT_BRANCH" != "main" ]; then
  echo "⚠️  You're on '$CURRENT_BRANCH', not 'main'. Continue? (y/N)"
  read -r answer
  [ "$answer" != "y" ] && exit 1
fi

# 2. Pull latest on prod
echo "→ [$TIMESTAMP] Pulling latest code..."
ssh $SERVER "cd $APP_DIR && git fetch origin && git reset --hard origin/main"

# 3. Install dependencies
echo "→ Installing Ruby dependencies..."
ssh $SERVER "cd $APP_DIR && bundle install --without development test"
ssh $SERVER "cd $APP_DIR/smart_proxy && bundle install"

# 4. Run migrations
echo "→ Running migrations..."
ssh $SERVER "cd $APP_DIR && eval \"\$(/opt/homebrew/bin/brew shellenv)\" && eval \"\$(rbenv init -)\" && RAILS_ENV=production bin/rails db:migrate"

# 5. Precompile assets
echo "→ Precompiling assets..."
ssh $SERVER "cd $APP_DIR && eval \"\$(/opt/homebrew/bin/brew shellenv)\" && eval \"\$(rbenv init -)\" && RAILS_ENV=production bin/rails assets:precompile"

# 6. Restart service
echo "→ Restarting service..."
ssh $SERVER "launchctl kickstart -k gui/\$(id -u)/com.agentforge.nextgen-plaid"

# 7. Wait and health check
echo "→ Waiting 8 seconds for startup..."
sleep 8
HEALTH=$(ssh $SERVER "curl -sf http://localhost:3000/health" 2>/dev/null || echo "FAILED")
if echo "$HEALTH" | grep -q '"status":"ok"'; then
  echo "✅ Deploy successful — app is healthy"
  echo "   $HEALTH"
else
  echo "❌ HEALTH CHECK FAILED"
  echo "   Response: $HEALTH"
  echo "   Check logs: ssh $SERVER 'tail -50 ~/logs/nextgen-plaid/stderr.log'"
  exit 1
fi
```

---

## Step 7: First Production Migration
> **What:** The one-time cutover from dev mode to production mode.  
> **This is the actual execution sequence.**

### Pre-Cutover (on prod server)
```bash
# Create log directory
mkdir -p ~/logs/nextgen-plaid

# Create production databases (if they don't exist yet)
createdb nextgen_plaid_production
createdb nextgen_plaid_production_cache
createdb nextgen_plaid_production_queue

# Set database user password
psql -c "ALTER USER nextgen_plaid PASSWORD 'your_password_here';"
# (or create user if doesn't exist)
psql -c "CREATE USER nextgen_plaid WITH PASSWORD 'your_password_here';"
psql -c "GRANT ALL PRIVILEGES ON DATABASE nextgen_plaid_production TO nextgen_plaid;"
psql -c "GRANT ALL PRIVILEGES ON DATABASE nextgen_plaid_production_cache TO nextgen_plaid;"
psql -c "GRANT ALL PRIVILEGES ON DATABASE nextgen_plaid_production_queue TO nextgen_plaid;"
```

### Pre-Cutover: Verify pf Rules Are Intact
The port 80 → 3000 redirect is handled by macOS `pf` and survives reboots (loaded via `/etc/pf.conf`).
No changes needed here — just verify it's still active after cutover:
```bash
sudo pfctl -a com.nextgen.plaid -s nat
# Should show:
# rdr pass on lo0 inet proto tcp from any to any port = 80 -> 127.0.0.1 port 3000
# rdr pass on en0 inet proto tcp from any to any port = 80 -> 192.168.4.253 port 3000
```

### Cutover Sequence
```bash
# 1. Store secrets in Keychain (run setup-keychain.sh interactively)
bash scripts/setup-keychain.sh

# 2. Stop the current dev-mode foreman process
#    (it's running in ttys003 — Ctrl+C or kill the foreman PID 12143)
kill 12143

# 3. Pull latest code (make sure Procfile.prod, bin/prod are merged to main)
cd ~/Development/nextgen-plaid
git pull origin main

# 4. Install deps
bundle install --without development test
cd smart_proxy && bundle install && cd ..

# 5. Precompile assets
RAILS_ENV=production bin/rails assets:precompile

# 6. Run production migrations
RAILS_ENV=production bin/rails db:migrate

# 7. Test bin/prod works manually first
bin/prod
# Verify: curl http://localhost:3000/health
# If good, Ctrl+C

# 8. Install launchd plist
cp ~/Development/nextgen-plaid/config/launchd/com.agentforge.nextgen-plaid.plist \
   ~/Library/LaunchAgents/
launchctl load ~/Library/LaunchAgents/com.agentforge.nextgen-plaid.plist

# 9. Verify it started
sleep 5
curl http://localhost:3000/health
launchctl list | grep nextgen

# 10. Clean up plaintext secrets
#     (after confirming everything works)
rm ~/Development/nextgen-plaid/.env.production
#     Sanitize .env to sandbox-only values or remove entirely
```

---

## Step 8: Database Migration Strategy
> **Important:** Prod currently uses `nextgen_plaid_development` databases. Production mode needs `nextgen_plaid_production` databases.

### Options
| Option | Approach | Downtime | Risk |
|--------|----------|----------|------|
| **A: Copy data** | `pg_dump` dev DB → restore to prod DB | Minutes | Low — data preserved |
| **B: Fresh start** | Run `db:create db:migrate db:seed` | None | Data loss — only if acceptable |
| **C: Rename databases** | `ALTER DATABASE ... RENAME TO ...` | Seconds | Low — fastest |

**Recommended: Option A** (copy data, since this is a financial app with real Plaid data)

```bash
# Dump current dev database
pg_dump nextgen_plaid_development > ~/backup-pre-production-$(date +%Y%m%d).sql

# Create production DB and restore
createdb nextgen_plaid_production
psql nextgen_plaid_production < ~/backup-pre-production-*.sql

# Same for queue and cache (or just migrate fresh — these are transient)
RAILS_ENV=production bin/rails db:migrate
```

---

## Execution Timeline

| Day | Task | Est. Time | Depends On |
|-----|------|-----------|------------|
| **Day 1** | Step 3: Set up Keychain secrets on prod | 30 min | — |
| **Day 1** | Step 1: Create `Procfile.prod` | 15 min | — |
| **Day 1** | Step 2: Create `bin/prod` | 30 min | Step 1 |
| **Day 1** | Step 5: Add `/health` endpoint | 15 min | — |
| **Day 1** | Merge above to `main` branch | 15 min | Steps 1,2,5 |
| **Day 2** | Step 8: Database migration (dump → restore) | 30 min | — |
| **Day 2** | Step 7: Execute cutover sequence | 1 hr | Steps 1-3,5,8 |
| **Day 2** | Step 4: Install launchd plist | 15 min | Step 7 |
| **Day 2** | Step 6: Test `bin/deploy-prod` from dev | 30 min | Step 7 |
| **Day 2** | Verify: reboot prod server, confirm auto-start | 15 min | Step 4 |
| **Day 3** | Monitor, clean up `.env.production`, update docs | 1 hr | All |

**Total: ~5-6 hours across 2-3 days**

---

## Rollback Plan

If production mode fails after cutover:

```bash
# 1. Stop the launchd service
launchctl unload ~/Library/LaunchAgents/com.agentforge.nextgen-plaid.plist

# 2. Start the old way (back to dev mode)
cd ~/Development/nextgen-plaid
bin/dev

# 3. App is back to previous state on :3000
```

Database is safe — we copied, didn't rename. Dev databases still exist.

---

## Post-Deploy Checklist

- [ ] `curl https://api.higroundsolutions.com/health` returns 200
- [ ] Plaid sync runs successfully (check Solid Queue jobs)
- [ ] SmartProxy responds on `:3002` (internal)
- [ ] Ollama integration works via SmartProxy (`curl http://localhost:11434/api/tags`)
- [ ] Port 80 → 3000 pf redirect still works (`curl http://localhost:80/health`)
- [ ] `launchctl list | grep nextgen` shows running
- [ ] Reboot test: restart prod Mac, verify auto-start
- [ ] `~/logs/nextgen-plaid/stderr.log` shows no errors
- [ ] `.env.production` deleted from prod server
- [ ] `.env` on prod contains only dev/sandbox values (or removed)

---

## Files Created/Modified (Summary)

| File | Repo | Action |
|------|------|--------|
| `Procfile.prod` | nextgen-plaid | **New** — production process definitions |
| `bin/prod` | nextgen-plaid | **New** — production launcher with Keychain secrets |
| `bin/deploy-prod` | nextgen-plaid | **New** — deploy script for dev machine |
| `scripts/setup-keychain.sh` | nextgen-plaid | **New** — one-time Keychain population |
| `config/routes.rb` | nextgen-plaid | **Modified** — add `/health` endpoint |
| `config/launchd/com.agentforge.nextgen-plaid.plist` | nextgen-plaid | **New** — auto-start config |
| `RUNBOOK.md` | nextgen-plaid | **New** — operational runbook (Phase 2 follow-up) |
| `.env.production` | nextgen-plaid (prod) | **Deleted** — secrets move to Keychain |

---

---

## What Comes Immediately After: SmartProxy Extraction

Once nextgen-plaid is stable in production mode, the **next priority** is extracting SmartProxy to run as a standalone service.

### Why
- SmartProxy is currently embedded at `nextgen-plaid/smart_proxy/` and launched via nextgen-plaid's Procfile
- It has already been extracted to its own repo: `projects/SmartProxy` (GitHub: `ericsmith66/SmartProxy`)
- Both nextgen-plaid **and** eureka-homekit need SmartProxy — it must be a shared service, not embedded in one app
- Eureka-homekit cannot deploy until SmartProxy runs independently

### What Changes in nextgen-plaid
1. **`Procfile.prod`** — Remove the `proxy:` line (SmartProxy gets its own launchd plist)
2. **`smart_proxy/` directory** — Delete from nextgen-plaid repo entirely
3. **No code changes** — `AgentHub::SmartProxyClient` and `AiFinancialAdvisor` both connect via `localhost:3002` using env vars; port stays the same
4. **`bin/prod`** — Add a wait-for-port-3002 check before starting Rails (SmartProxy must be up first)

### Connection Map (after extraction)
```
nextgen-plaid (:3000) ──→ SmartProxy (:3002) ──→ Claude API (cloud)
                                               ──→ Grok API (cloud)
                                               ──→ Ollama (:11434, local)

eureka-homekit (:3001) ──→ SmartProxy (:3002) ──→ (same backends)
```

See **[roadmap-environment.md](roadmap-environment.md) Phase 1.5** for the full SmartProxy extraction plan.

---

**Next:** When you approve this plan, we start creating the files in Step 1-3, 5.
