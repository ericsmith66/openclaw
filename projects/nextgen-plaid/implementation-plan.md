# Implementation Plan: Production Deployment Fix for nextgen-plaid

**Status:** PENDING REVIEW  
**Date:** February 2026  
**Rails:** 8.1.1 · **Ruby:** 3.3.10 · **Prod server:** 192.168.4.253

---

## Table of Contents

1. [Execution Order & Dependencies](#execution-order--dependencies)
2. [Step 1 — Public Health Endpoint (Rails)](#step-1--public-health-endpoint-rails)
3. [Step 2 — SSL Exclusion for /health](#step-2--ssl-exclusion-for-health)
4. [Step 3 — Rewrite bin/prod (dotenv instead of Keychain)](#step-3--rewrite-binprod-dotenv-instead-of-keychain)
5. [Step 4 — Create .env.production on prod](#step-4--create-envproduction-on-prod)
6. [Step 5 — Create launchd plist for nextgen-plaid](#step-5--create-launchd-plist-for-nextgen-plaid)
7. [Step 6 — Create launchd plist for Ollama](#step-6--create-launchd-plist-for-ollama)
8. [Step 7 — Rewrite bin/deploy-prod](#step-7--rewrite-bindeploy-prod)
9. [Step 8 — Update RUNBOOK.md](#step-8--update-runbookmd)
10. [Step 9 — Update docs/devops-handover.md](#step-9--update-docsdevops-handovermd)
11. [Step 10 — Deploy & Smoke Test](#step-10--deploy--smoke-test)
12. [Step 11 — Reboot Verification](#step-11--reboot-verification)
13. [Rollback Master Plan](#rollback-master-plan)

---

## Execution Order & Dependencies

```
Step 1  ──→  Step 2  ──→  (commit & push to main)
                               │
Step 3  ──→  (commit & push)   │
                               │
Step 7  ──→  (commit & push)   │
                               │
Step 8  ──→  Step 9  ──→  (commit & push)
                               │
                               ▼
                     Step 4 (PROD-ONLY: .env.production)
                               │
                     Step 5 (PROD-ONLY: launchd plist for app)
                               │
                     Step 6 (PROD-ONLY: launchd plist for Ollama)
                               │
                     Step 10 (Deploy & smoke test)
                               │
                     Step 11 (Reboot verification)
```

**Critical rule:** Steps 1–3, 7–9 are committed to git and pushed.  
Steps 4–6 are prod-only manual setup (files are NOT in the repo).  
Step 10 is the first deploy using the new tooling.  
Step 11 validates auto-start after reboot.

---

## Step 1 — Public Health Endpoint (Rails)

**Problem:** The health check in `bin/deploy-prod` hits `/health` but that route doesn't exist. The existing `/admin/health` requires Devise authentication — an unauthenticated `curl` gets a 302 redirect, not 200.

**Decision:** Add a lightweight public `/health` route protected only by a `HEALTH_TOKEN` query-string parameter. No Devise auth, no CSRF. Returns `{"status":"ok"}` (200) or `{"status":"error"}` (503).

### 1a. Create `app/controllers/health_controller.rb`

**Location:** Local repo (committed to git)

```ruby
# app/controllers/health_controller.rb
#
# Public health-check endpoint for deployment scripts and uptime monitors.
# Protected by a shared HEALTH_TOKEN query-string parameter (not Devise).
# Returns HTTP 200 + {"status":"ok"} when the app can serve requests and
# reach the primary database; HTTP 503 otherwise.
#
# Usage:
#   curl http://localhost:3000/health?token=<HEALTH_TOKEN>
#
class HealthController < ApplicationController
  # Skip Devise — this endpoint must work without a session.
  skip_before_action :authenticate_user!, raise: false
  skip_before_action :verify_authenticity_token, raise: false

  def show
    unless valid_token?
      render json: { error: "unauthorized" }, status: :unauthorized
      return
    end

    if database_healthy?
      render json: { status: "ok" }, status: :ok
    else
      render json: { status: "error", detail: "database unreachable" }, status: :service_unavailable
    end
  end

  private

  def valid_token?
    expected = ENV["HEALTH_TOKEN"]
    # If HEALTH_TOKEN is not configured, deny all requests (fail closed).
    return false if expected.blank?

    ActiveSupport::SecurityUtils.secure_compare(
      params[:token].to_s,
      expected
    )
  end

  def database_healthy?
    ActiveRecord::Base.connection.execute("SELECT 1")
    true
  rescue StandardError
    false
  end
end
```

**Design notes:**
- Inherits `ApplicationController` so standard error handling works, but skips the two before_actions that would block unauthenticated/API access.
- `raise: false` on the skip ensures no error if the parent doesn't define the callback (future-proof).
- Uses `secure_compare` to prevent timing attacks on the token.
- Fail-closed: if `HEALTH_TOKEN` env var is unset, endpoint returns 401. This prevents accidentally exposing health info.
- Database check is the minimum viable liveness probe — if Puma can serve a request and PG is reachable, the app is alive.

### 1b. Add route in `config/routes.rb`

**Location:** Local repo (committed to git)

Add the following line **above** the `devise_for :users` line (placing it early ensures it's matched before any Devise catch-all):

```ruby
  # Public health check for deployment scripts & uptime monitors.
  # Protected by HEALTH_TOKEN query parameter (not Devise).
  get "/health", to: "health#show"
```

**Exact edit location** — insert immediately after this existing block:

```ruby
  get "/privacy", to: "static#privacy"
  get "/terms", to: "static#terms"
```

So the file reads:

```ruby
  get "/privacy", to: "static#privacy"
  get "/terms", to: "static#terms"

  # Public health check for deployment scripts & uptime monitors.
  # Protected by HEALTH_TOKEN query parameter (not Devise).
  get "/health", to: "health#show"

  mount ActionCable.server => "/cable"
```

### 1c. Create test `test/controllers/health_controller_test.rb`

**Location:** Local repo (committed to git)

```ruby
# test/controllers/health_controller_test.rb
require "test_helper"

class HealthControllerTest < ActionDispatch::IntegrationTest
  test "returns 401 when no token provided" do
    get "/health"
    assert_response :unauthorized
    body = JSON.parse(response.body)
    assert_equal "unauthorized", body["error"]
  end

  test "returns 401 when wrong token provided" do
    ClimateControl.modify(HEALTH_TOKEN: "real-secret") do
      get "/health?token=wrong-secret"
      assert_response :unauthorized
    end
  end

  test "returns 401 when HEALTH_TOKEN env var is blank" do
    ClimateControl.modify(HEALTH_TOKEN: "") do
      get "/health?token="
      assert_response :unauthorized
    end
  end

  test "returns 200 with valid token and healthy database" do
    ClimateControl.modify(HEALTH_TOKEN: "test-secret-token") do
      get "/health?token=test-secret-token"
      assert_response :ok
      body = JSON.parse(response.body)
      assert_equal "ok", body["status"]
    end
  end

  test "returns 503 when database is unreachable" do
    ClimateControl.modify(HEALTH_TOKEN: "test-secret-token") do
      ActiveRecord::Base.connection.stub(:execute, ->(_) { raise PG::ConnectionBad, "simulated" }) do
        get "/health?token=test-secret-token"
        assert_response :service_unavailable
        body = JSON.parse(response.body)
        assert_equal "error", body["status"]
      end
    end
  end
end
```

### 1d. How to test

```bash
# Run just the health controller tests:
bin/rails test test/controllers/health_controller_test.rb

# Manual curl test (dev):
HEALTH_TOKEN=dev-token bin/dev
curl -s http://localhost:3016/health?token=dev-token
# Expected: {"status":"ok"} with HTTP 200

curl -s -o /dev/null -w '%{http_code}' http://localhost:3016/health
# Expected: 401

curl -s -o /dev/null -w '%{http_code}' http://localhost:3016/health?token=wrong
# Expected: 401
```

### 1e. Rollback

Delete `app/controllers/health_controller.rb`, remove the route from `config/routes.rb`, delete the test file. The existing `/admin/health` endpoint is unchanged.

---

## Step 2 — SSL Exclusion for /health

**Problem:** `config.force_ssl = true` in production causes Puma to return a 301 redirect for plain HTTP requests. The deploy script's `curl http://localhost:3000/health` would get redirected and fail.

**Current state:** The file already excludes `/up`:
```ruby
config.ssl_options = { hsts: { subdomains: false }, redirect: { exclude: ->(request) { request.path == "/up" } } }
```

**Change:** Extend the lambda to also exclude `/health`.

### 2a. Edit `config/environments/production.rb`

**Location:** Local repo (committed to git — already tracked despite .gitignore entry)

**Find:**
```ruby
  config.ssl_options = { hsts: { subdomains: false }, redirect: { exclude: ->(request) { request.path == "/up" } } }
```

**Replace with:**
```ruby
  config.ssl_options = { hsts: { subdomains: false }, redirect: { exclude: ->(request) { request.path.in?(["/up", "/health"]) } } }
```

Also update `config.silence_healthcheck_path`:

**Find:**
```ruby
  config.silence_healthcheck_path = "/up"
```

**Replace with:**
```ruby
  config.silence_healthcheck_path = "/health"
```

This prevents health check polls from flooding `production.log`.

### 2b. How to test

```bash
# After deploying to prod, verify HTTP (not HTTPS) health check works:
ssh ericsmith66@192.168.4.253 "curl -s -o /dev/null -w '%{http_code}' 'http://localhost:3000/health?token=<HEALTH_TOKEN>'"
# Expected: 200 (not 301)
```

### 2c. Rollback

Revert the line back to the original `/up`-only exclusion.

---

## Step 3 — Rewrite `bin/prod` (dotenv instead of Keychain)

**Problem:** `bin/prod` uses `security find-generic-password` to load secrets from macOS Keychain. The Keychain is locked in SSH sessions and after reboot (before GUI login). This makes headless/launchd startup impossible.

**Decision:** Switch to `dotenv-rails` loading `.env.production` (already in Gemfile and .gitignore). The `bin/prod` script becomes a thin wrapper that sets `RAILS_ENV`, verifies dependencies, and starts Puma + SolidQueue via Foreman.

**Location:** Local repo (committed to git)

### 3a. Full replacement of `bin/prod`

```bash
#!/usr/bin/env bash
#
# Production Launcher for nextgen-plaid
# Purpose: Start the application in production mode.
#
# Secrets are loaded from .env.production by dotenv-rails at boot time.
# This script only needs to set RAILS_ENV and start Foreman.
#
# Usage:
#   bin/prod                  # default: Foreman (Puma + SolidQueue)
#   bin/prod --puma-only      # Puma only (SolidQueue via Puma plugin)
#

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

cd "$(dirname "$0")/.."

# ── Environment setup ──────────────────────────────────────────────────
# Source zprofile for Homebrew/rbenv paths (needed when run from launchd)
if [ -f "$HOME/.zprofile" ]; then
  source "$HOME/.zprofile"
fi

export PATH="/opt/homebrew/bin:/opt/homebrew/Cellar/postgresql@16/16.11_1/bin:$PATH"

# Initialize rbenv
if command -v rbenv >/dev/null 2>&1; then
  eval "$(rbenv init -)"
fi

export RAILS_ENV=production
export PORT=3000

# ── Preflight checks ──────────────────────────────────────────────────
echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  nextgen-plaid — Production Mode${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
echo ""
echo -e "${BLUE}Ruby:${NC} $(ruby -v)"
echo ""

# Verify .env.production exists
if [ ! -f ".env.production" ]; then
  echo -e "${RED}✗ .env.production not found${NC}" >&2
  echo -e "${RED}  Create it with required secrets (see RUNBOOK.md)${NC}" >&2
  exit 1
fi
echo -e "${GREEN}✓ .env.production found${NC}"

# Verify critical env vars are present in the file
# (dotenv-rails loads them at Rails boot, but we check the file now for early feedback)
for var in NEXTGEN_PLAID_DATABASE_PASSWORD PLAID_CLIENT_ID PLAID_SECRET RAILS_MASTER_KEY HEALTH_TOKEN ENCRYPTION_KEY; do
  if ! grep -q "^${var}=" .env.production; then
    echo -e "${RED}✗ Missing ${var} in .env.production${NC}" >&2
    exit 1
  fi
done
echo -e "${GREEN}✓ Required env vars present in .env.production${NC}"

# Verify psql is available
if ! command -v psql >/dev/null 2>&1; then
  echo -e "${RED}✗ psql not found — install postgresql@16${NC}" >&2
  exit 1
fi
echo -e "${GREEN}✓ PostgreSQL client available${NC}"

# Verify database connectivity (read password from .env.production)
DB_PASS=$(grep '^NEXTGEN_PLAID_DATABASE_PASSWORD=' .env.production | cut -d'=' -f2- | tr -d '"' | tr -d "'")
if PGPASSWORD="${DB_PASS}" psql -U nextgen_plaid -d nextgen_plaid_production -c "SELECT 1;" > /dev/null 2>&1; then
  echo -e "${GREEN}✓ Database connection verified${NC}"
else
  echo -e "${RED}✗ Database connection failed${NC}" >&2
  exit 1
fi

echo ""
echo -e "${BLUE}Starting services via Foreman...${NC}"
echo -e "${BLUE}  • Puma web server on port 3000${NC}"
echo -e "${BLUE}  • SolidQueue background workers${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
echo ""

exec foreman start -f Procfile.prod "$@"
```

**Key changes from the original:**
1. **No Keychain calls** — all `security find-generic-password` removed.
2. **No secret export** — `dotenv-rails` loads `.env.production` at Rails boot automatically when `RAILS_ENV=production`.
3. **Preflight validates `.env.production` file** — checks file exists and key variables are defined (by grepping the file, not loading them into shell — avoids quoting issues with special chars like `%($!^^200`).
4. **Database connectivity check** parses password from the file directly.
5. **Foreman startup is unchanged** — still uses `Procfile.prod`.

### 3b. How to test

```bash
# On dev machine (with a local .env.production containing test values):
echo 'NEXTGEN_PLAID_DATABASE_PASSWORD="test"' > .env.production.test-dummy
# ... (just verify the script runs preflight checks — it will fail on DB which is expected)
# Remove test dummy after.

# Full test on prod after Step 4 (creating .env.production there):
ssh ericsmith66@192.168.4.253
cd /Users/ericsmith66/Development/nextgen-plaid
bin/prod
# Should show all green checks and start Foreman.
```

### 3c. Rollback

`git checkout bin/prod` to restore the Keychain version. Keychain secrets are still intact on prod — they're never deleted by this plan.

---

## Step 4 — Create `.env.production` on Prod

**Problem:** Secrets must be available as environment variables without Keychain.

**Location:** PROD ONLY (`/Users/ericsmith66/Development/nextgen-plaid/.env.production`) — NOT committed to git (already in `.gitignore`).

**Note:** Memory indicates a `.env.production` file may already exist on prod with `NEXTGEN_PLAID_DATABASE_PASSWORD`. This step ensures ALL required vars are present.

### 4a. SSH to prod and create/update the file

```bash
ssh ericsmith66@192.168.4.253
cd /Users/ericsmith66/Development/nextgen-plaid
```

Extract current secrets from Keychain (while GUI session still has it unlocked) and write them to the file:

```bash
# Extract secrets from Keychain while it's still accessible
DB_PASS=$(security find-generic-password -a 'nextgen-plaid' -s 'nextgen-plaid-DATABASE_PASSWORD' -w 2>/dev/null)
PLAID_ID=$(security find-generic-password -a 'nextgen-plaid' -s 'nextgen-plaid-PLAID_CLIENT_ID' -w 2>/dev/null)
PLAID_SEC=$(security find-generic-password -a 'nextgen-plaid' -s 'nextgen-plaid-PLAID_SECRET' -w 2>/dev/null)
CLAUDE_KEY=$(security find-generic-password -a 'nextgen-plaid' -s 'nextgen-plaid-CLAUDE_API_KEY' -w 2>/dev/null)
MASTER_KEY=$(security find-generic-password -a 'nextgen-plaid' -s 'nextgen-plaid-RAILS_MASTER_KEY' -w 2>/dev/null)
REDIS_PASS=$(security find-generic-password -a 'nextgen-plaid' -s 'nextgen-plaid-REDIS_PASSWORD' -w 2>/dev/null || echo "")
SENTRY=$(security find-generic-password -a 'nextgen-plaid' -s 'nextgen-plaid-SENTRY_DSN' -w 2>/dev/null || echo "")
ENCRYPT_KEY=$(security find-generic-password -a 'nextgen-plaid' -s 'nextgen-plaid-ENCRYPTION_KEY' -w 2>/dev/null)
# NOTE: ENCRYPTION_KEY is REQUIRED (64-hex-char string). If not in Keychain, check
# config/initializers/encryption_key.rb — the app will refuse to boot without it.
# Generate one with: openssl rand -hex 32

# Generate a random health token
HEALTH_TKN=$(openssl rand -hex 24)

echo "Extracted secrets. Writing .env.production..."
```

Then write the file (**use a heredoc with single-quoted delimiter to prevent shell expansion of special chars**):

```bash
cat > .env.production << 'ENVEOF'
# nextgen-plaid production secrets
# NEVER commit this file to git. It is in .gitignore.
# Last updated: <DATE>

# ── Core ───────────────────────────────────────────
RAILS_ENV=production
RAILS_MASTER_KEY=<REPLACE>
NEXTGEN_PLAID_DATABASE_PASSWORD=<REPLACE>
ENCRYPTION_KEY=<REPLACE_64_HEX_CHARS>

# ── Plaid ──────────────────────────────────────────
PLAID_CLIENT_ID=<REPLACE>
PLAID_SECRET=<REPLACE>
PLAID_ENV=production

# ── AI / LLM ──────────────────────────────────────
CLAUDE_API_KEY=<REPLACE>

# ── Health Check ───────────────────────────────────
HEALTH_TOKEN=<REPLACE>

# ── Optional ───────────────────────────────────────
REDIS_PASSWORD=<REPLACE_OR_BLANK>
SENTRY_DSN=<REPLACE_OR_BLANK>

# ── Layout ─────────────────────────────────────────
ENABLE_NEW_LAYOUT=true
ENVEOF
```

**After writing the template,** manually replace each `<REPLACE>` with the actual value extracted above. For the database password (which contains special characters like `%($!^^200`), **do NOT wrap in quotes** in the .env file — dotenv-rails handles unquoted values correctly. If the value contains `#`, wrap in double quotes.

**Important:** Verify the file looks right:

```bash
cat .env.production | head -20
```

Lock down permissions:

```bash
chmod 600 .env.production
```

### 4b. Verify dotenv-rails loads it

```bash
cd /Users/ericsmith66/Development/nextgen-plaid
export PATH="/opt/homebrew/bin:$PATH"
eval "$(rbenv init -)"
RAILS_ENV=production bin/rails runner "puts ENV['HEALTH_TOKEN'].present? ? 'OK' : 'MISSING'"
# Expected: OK
```

### 4c. Record the HEALTH_TOKEN

Write down the generated `HEALTH_TOKEN` value — it will be needed in `bin/deploy-prod` (Step 7) and for monitoring. Store it securely (e.g., password manager).

### 4d. Rollback

If the file is wrong, `bin/prod` won't start (it validates the file). Fix the file or, as a last resort, restore the old Keychain-based `bin/prod` via `git checkout bin/prod`.

---

## Step 5 — Create launchd Plist for nextgen-plaid

**Problem:** No launchd plist exists. The app runs via manual `bin/prod` and does not survive reboots.

**Location:** PROD ONLY at `~/Library/LaunchAgents/com.agentforge.nextgen-plaid.plist`

### 5a. Create the plist

```bash
ssh ericsmith66@192.168.4.253
```

```bash
cat > ~/Library/LaunchAgents/com.agentforge.nextgen-plaid.plist << 'PLISTEOF'
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
    <string>-l</string>
    <string>-c</string>
    <string>cd /Users/ericsmith66/Development/nextgen-plaid &amp;&amp; exec bin/prod 2>&amp;1</string>
  </array>

  <key>WorkingDirectory</key>
  <string>/Users/ericsmith66/Development/nextgen-plaid</string>

  <key>RunAtLoad</key>
  <true/>

  <key>KeepAlive</key>
  <true/>

  <key>StandardOutPath</key>
  <string>/Users/ericsmith66/Development/nextgen-plaid/log/launchd-stdout.log</string>

  <key>StandardErrorPath</key>
  <string>/Users/ericsmith66/Development/nextgen-plaid/log/launchd-stderr.log</string>

  <key>EnvironmentVariables</key>
  <dict>
    <key>PATH</key>
    <string>/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin</string>
    <key>LANG</key>
    <string>en_US.UTF-8</string>
  </dict>

  <key>ThrottleInterval</key>
  <integer>10</integer>
</dict>
</plist>
PLISTEOF
```

**Design notes:**
- `bash -l` ensures login shell (loads `~/.zprofile` → rbenv, Homebrew).
- `RunAtLoad + KeepAlive` = auto-start on login AND restart if Puma crashes.
- `ThrottleInterval 10` prevents rapid restart loops (launchd waits 10s between restarts).
- `WorkingDirectory` set explicitly for safety.
- Logs go to `log/launchd-stdout.log` and `log/launchd-stderr.log` inside the app directory.
- Environment only sets `PATH` and `LANG` — all app secrets come from `.env.production` via dotenv-rails.

### 5b. Load the plist

```bash
# First, stop any running bin/prod (Foreman) process:
pkill -TERM -f "puma.*production" 2>/dev/null || true
pkill -TERM -f "foreman" 2>/dev/null || true
sleep 2

# Load and start the launchd service:
launchctl bootout gui/$(id -u)/com.agentforge.nextgen-plaid 2>/dev/null || true
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.agentforge.nextgen-plaid.plist

# Verify it started:
launchctl list | grep nextgen-plaid
# Expected: PID column shows a number (not "-")

# Check logs:
tail -20 /Users/ericsmith66/Development/nextgen-plaid/log/launchd-stdout.log
tail -20 /Users/ericsmith66/Development/nextgen-plaid/log/launchd-stderr.log
```

### 5c. Verify the service

```bash
# Check Puma is running:
ps aux | grep puma | grep production

# Check port:
lsof -i :3000

# Health check:
HEALTH_TOKEN=$(grep '^HEALTH_TOKEN=' /Users/ericsmith66/Development/nextgen-plaid/.env.production | cut -d'=' -f2-)
curl -s "http://localhost:3000/health?token=${HEALTH_TOKEN}"
# Expected: {"status":"ok"}
```

### 5d. Verify KeepAlive (crash recovery)

```bash
# Find Puma PID and kill it:
PUMA_PID=$(pgrep -f "puma.*production" | head -1)
kill -9 $PUMA_PID
sleep 15   # ThrottleInterval is 10s

# Verify it restarted:
ps aux | grep puma | grep production
# Expected: new PID running
```

### 5e. Rollback

```bash
launchctl bootout gui/$(id -u)/com.agentforge.nextgen-plaid
rm ~/Library/LaunchAgents/com.agentforge.nextgen-plaid.plist
# Then start manually:
cd /Users/ericsmith66/Development/nextgen-plaid && bin/prod
```

---

## Step 6 — Create launchd Plist for Ollama

**Problem:** Ollama runs via `/Applications/Ollama.app` (GUI launch) and doesn't auto-start on reboot unless a user logs into the GUI.

**Location:** PROD ONLY at `~/Library/LaunchAgents/com.agentforge.ollama.plist`

### 6a. Create the plist

```bash
cat > ~/Library/LaunchAgents/com.agentforge.ollama.plist << 'PLISTEOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>com.agentforge.ollama</string>

  <key>ProgramArguments</key>
  <array>
    <string>/usr/local/bin/ollama</string>
    <string>serve</string>
  </array>

  <key>RunAtLoad</key>
  <true/>

  <key>KeepAlive</key>
  <true/>

  <key>StandardOutPath</key>
  <string>/Users/ericsmith66/Library/Logs/ollama-stdout.log</string>

  <key>StandardErrorPath</key>
  <string>/Users/ericsmith66/Library/Logs/ollama-stderr.log</string>

  <key>EnvironmentVariables</key>
  <dict>
    <key>OLLAMA_HOST</key>
    <string>0.0.0.0:11434</string>
    <key>HOME</key>
    <string>/Users/ericsmith66</string>
  </dict>

  <key>ThrottleInterval</key>
  <integer>10</integer>
</dict>
</plist>
PLISTEOF
```

**Important:** Verify the ollama binary path first:

```bash
which ollama
# If it's at /opt/homebrew/bin/ollama instead of /usr/local/bin/ollama,
# update the ProgramArguments path accordingly.
```

### 6b. Stop Ollama.app and load the plist

```bash
# Quit the Ollama GUI app:
osascript -e 'tell application "Ollama" to quit' 2>/dev/null || true
pkill -f "Ollama" 2>/dev/null || true
sleep 2

# Load the launchd service:
launchctl bootout gui/$(id -u)/com.agentforge.ollama 2>/dev/null || true
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.agentforge.ollama.plist

# Verify:
launchctl list | grep ollama
curl -s http://localhost:11434/api/tags | head -c 200
# Expected: JSON response listing available models
```

### 6c. Disable Ollama.app from Login Items

Open **System Settings → General → Login Items** and remove Ollama if it's listed (to prevent double-launch after reboot).

### 6d. Rollback

```bash
launchctl bootout gui/$(id -u)/com.agentforge.ollama
rm ~/Library/LaunchAgents/com.agentforge.ollama.plist
# Restart via GUI: open /Applications/Ollama.app
```

---

## Step 7 — Rewrite `bin/deploy-prod`

**Problems fixed:**
1. `launchctl stop/start` → `launchctl kickstart -k` (atomic restart)
2. Health check `/health` → `/health?token=...` with token from `.env.production`
3. `bundle install --deployment` → `bundle install` (deployment mode deprecated in Bundler 2.7+)
4. `RAILS_ENV` missing from `run_remote` → always set
5. `SERVICE_NAME` uses local `id -u` → use remote `id -u`
6. Fixed 8-second sleep → retry loop with backoff (up to 30s)
7. `check_status()` unreliable with `set -e` → inline checks

**Location:** Local repo (committed to git)

### 7a. Full replacement of `bin/deploy-prod`

```bash
#!/usr/bin/env bash
#
# Production Deployment Script for nextgen-plaid
# Purpose: Deploy application to production with automated backups
# Usage: bin/deploy-prod [--skip-backup] [--skip-tests]
#

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# ── Configuration ─────────────────────────────────────────────────────
PROD_HOST="192.168.4.253"
PROD_USER="ericsmith66"
PROD_PATH="/Users/ericsmith66/Development/nextgen-plaid"
LAUNCHD_LABEL="com.agentforge.nextgen-plaid"

# rbenv init command for remote SSH commands
RBENV_INIT='/opt/homebrew/bin/rbenv init - zsh'

# ── Parse arguments ───────────────────────────────────────────────────
SKIP_BACKUP=false
SKIP_TESTS=false

for arg in "$@"; do
  case $arg in
    --skip-backup) SKIP_BACKUP=true ;;
    --skip-tests)  SKIP_TESTS=true ;;
    *)
      echo "Unknown argument: $arg"
      echo "Usage: $0 [--skip-backup] [--skip-tests]"
      exit 1
      ;;
  esac
done

# ── Helper functions ──────────────────────────────────────────────────
log() {
  echo -e "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

# Run a command on the production server with proper rbenv + RAILS_ENV
run_remote() {
  local cmd=$1
  ssh "${PROD_USER}@${PROD_HOST}" \
    "cd ${PROD_PATH} && export PATH=\"/opt/homebrew/bin:\$PATH\" && eval \"\$(${RBENV_INIT})\" && export RAILS_ENV=production && ${cmd}"
}

# Read a value from .env.production on the remote server
read_remote_env() {
  local var_name=$1
  ssh "${PROD_USER}@${PROD_HOST}" \
    "grep '^${var_name}=' ${PROD_PATH}/.env.production | cut -d'=' -f2- | tr -d '\"' | tr -d \"'\""
}

echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  Production Deployment — nextgen-plaid${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  Target: ${PROD_USER}@${PROD_HOST}${NC}"
echo -e "${BLUE}  Path:   ${PROD_PATH}${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
echo ""

# ══════════════════════════════════════════════════════════════════════
# Phase 1: Pre-flight Checks
# ══════════════════════════════════════════════════════════════════════
log "${BLUE}→ [1/7] Running pre-flight checks...${NC}"

CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
if [[ "${CURRENT_BRANCH}" != "main" ]]; then
  log "${RED}✗ Not on main branch (current: ${CURRENT_BRANCH})${NC}"
  exit 1
fi
log "${GREEN}  ✓ On main branch${NC}"

if [[ -n $(git status --porcelain) ]]; then
  log "${RED}✗ Uncommitted changes detected${NC}"
  exit 1
fi
log "${GREEN}  ✓ No uncommitted changes${NC}"

if ! ssh -o ConnectTimeout=10 -o BatchMode=yes "${PROD_USER}@${PROD_HOST}" "echo SSH_OK" > /dev/null 2>&1; then
  log "${RED}✗ Cannot connect to production server${NC}"
  exit 1
fi
log "${GREEN}  ✓ SSH connectivity verified${NC}"

if [[ "${SKIP_TESTS}" == "false" ]]; then
  log "${YELLOW}  Running test suite...${NC}"
  if bin/rails test > /dev/null 2>&1; then
    log "${GREEN}  ✓ All tests passed${NC}"
  else
    log "${RED}✗ Tests failed — fix before deploying${NC}"
    exit 1
  fi
else
  log "${YELLOW}  ⊙ Tests skipped (--skip-tests)${NC}"
fi

echo ""

# ══════════════════════════════════════════════════════════════════════
# Phase 2: Database Backup
# ══════════════════════════════════════════════════════════════════════
if [[ "${SKIP_BACKUP}" == "false" ]]; then
  log "${BLUE}→ [2/7] Creating database backups...${NC}"

  BACKUP_OUTPUT=$(run_remote "./scripts/backup-database.sh" 2>&1) || {
    log "${RED}✗ Database backup failed${NC}"
    log "${RED}${BACKUP_OUTPUT}${NC}"
    exit 1
  }

  BACKUP_TIMESTAMP=$(echo "${BACKUP_OUTPUT}" | grep -o "[0-9]\{8\}_[0-9]\{6\}" | head -1)
  log "${GREEN}  ✓ Backups created (${BACKUP_TIMESTAMP})${NC}"
  echo "${BACKUP_TIMESTAMP}" > .last_backup_timestamp
else
  log "${YELLOW}→ [2/7] Backup skipped (--skip-backup)${NC}"
  log "${RED}  ⚠ WARNING: No backup!${NC}"
  read -p "  Continue? (type 'yes'): " -r
  if [[ ! $REPLY =~ ^yes$ ]]; then
    log "${YELLOW}Cancelled${NC}"
    exit 0
  fi
fi

echo ""

# ══════════════════════════════════════════════════════════════════════
# Phase 3: Pull Latest Code
# ══════════════════════════════════════════════════════════════════════
log "${BLUE}→ [3/7] Updating production code...${NC}"

PREVIOUS_COMMIT=$(run_remote "git rev-parse HEAD" 2>&1)
log "${BLUE}  → Previous: ${PREVIOUS_COMMIT:0:7}${NC}"

run_remote "git fetch origin main" || { log "${RED}✗ git fetch failed${NC}"; exit 1; }
run_remote "git reset --hard origin/main" || { log "${RED}✗ git reset failed${NC}"; exit 1; }

CURRENT_COMMIT=$(run_remote "git rev-parse HEAD" 2>&1)
log "${GREEN}  ✓ Updated to: ${CURRENT_COMMIT:0:7}${NC}"

echo "${PREVIOUS_COMMIT}" > .last_commit

echo ""

# ══════════════════════════════════════════════════════════════════════
# Phase 4: Install Dependencies
# ══════════════════════════════════════════════════════════════════════
log "${BLUE}→ [4/7] Installing dependencies...${NC}"

run_remote "bundle install" || { log "${RED}✗ bundle install failed${NC}"; exit 1; }

log "${GREEN}  ✓ Dependencies installed${NC}"
echo ""

# ══════════════════════════════════════════════════════════════════════
# Phase 5: Database Migrations
# ══════════════════════════════════════════════════════════════════════
log "${BLUE}→ [5/7] Running database migrations...${NC}"

MIGRATION_OUTPUT=$(run_remote "bin/rails db:migrate" 2>&1) || {
  log "${RED}✗ Migrations failed${NC}"
  log "${RED}${MIGRATION_OUTPUT}${NC}"
  log "${YELLOW}Rollback:${NC}"
  log "${YELLOW}  1. Restore DB: ssh ${PROD_USER}@${PROD_HOST} 'cd ${PROD_PATH} && ./scripts/restore-database.sh ${BACKUP_TIMESTAMP:-TIMESTAMP}'${NC}"
  log "${YELLOW}  2. Rollback code: ssh ${PROD_USER}@${PROD_HOST} 'cd ${PROD_PATH} && git reset --hard ${PREVIOUS_COMMIT}'${NC}"
  exit 1
}

if echo "${MIGRATION_OUTPUT}" | grep -q "migrating"; then
  log "${GREEN}  ✓ New migrations applied${NC}"
else
  log "${GREEN}  ✓ No new migrations${NC}"
fi

echo ""

# ══════════════════════════════════════════════════════════════════════
# Phase 6: Precompile Assets
# ══════════════════════════════════════════════════════════════════════
log "${BLUE}→ [6/7] Precompiling assets...${NC}"

run_remote "bin/rails assets:precompile" || { log "${RED}✗ Asset precompile failed${NC}"; exit 1; }

log "${GREEN}  ✓ Assets precompiled${NC}"
echo ""

# ══════════════════════════════════════════════════════════════════════
# Phase 7: Restart Application via launchd
# ══════════════════════════════════════════════════════════════════════
log "${BLUE}→ [7/7] Restarting application...${NC}"

# Get the REMOTE user's UID for launchctl (not the local dev machine's UID)
REMOTE_UID=$(ssh "${PROD_USER}@${PROD_HOST}" "id -u")
SERVICE_TARGET="gui/${REMOTE_UID}/${LAUNCHD_LABEL}"

# kickstart -k = kill existing process and restart immediately
ssh "${PROD_USER}@${PROD_HOST}" "launchctl kickstart -k ${SERVICE_TARGET}" || {
  log "${RED}✗ launchctl kickstart failed${NC}"
  log "${YELLOW}  Try manually: ssh ${PROD_USER}@${PROD_HOST} 'launchctl kickstart -k ${SERVICE_TARGET}'${NC}"
  exit 1
}

log "${GREEN}  ✓ Restart signal sent${NC}"
echo ""

# ══════════════════════════════════════════════════════════════════════
# Health Check with Retry
# ══════════════════════════════════════════════════════════════════════
log "${BLUE}→ Verifying deployment...${NC}"

# Read HEALTH_TOKEN from prod's .env.production
HEALTH_TOKEN=$(read_remote_env "HEALTH_TOKEN")
if [[ -z "${HEALTH_TOKEN}" ]]; then
  log "${RED}✗ Cannot read HEALTH_TOKEN from prod .env.production${NC}"
  exit 1
fi

MAX_ATTEMPTS=6
ATTEMPT=0
HEALTH_OK=false

while [[ ${ATTEMPT} -lt ${MAX_ATTEMPTS} ]]; do
  ATTEMPT=$((ATTEMPT + 1))
  WAIT_SECONDS=$((ATTEMPT * 5))  # 5, 10, 15, 20, 25, 30
  log "${YELLOW}  Attempt ${ATTEMPT}/${MAX_ATTEMPTS} — waiting ${WAIT_SECONDS}s...${NC}"
  sleep ${WAIT_SECONDS}

  HTTP_CODE=$(ssh "${PROD_USER}@${PROD_HOST}" \
    "curl -s -o /dev/null -w '%{http_code}' 'http://localhost:3000/health?token=${HEALTH_TOKEN}'" 2>/dev/null || echo "000")

  if [[ "${HTTP_CODE}" == "200" ]]; then
    HEALTH_OK=true
    break
  fi
  log "${YELLOW}  → Got HTTP ${HTTP_CODE}${NC}"
done

if [[ "${HEALTH_OK}" == "true" ]]; then
  log "${GREEN}  ✓ Health check passed (HTTP 200)${NC}"
else
  log "${RED}✗ Health check failed after ${MAX_ATTEMPTS} attempts${NC}"
  log "${YELLOW}Troubleshooting:${NC}"
  log "${YELLOW}  1. Logs: ssh ${PROD_USER}@${PROD_HOST} 'tail -50 ${PROD_PATH}/log/launchd-stderr.log'${NC}"
  log "${YELLOW}  2. Service: ssh ${PROD_USER}@${PROD_HOST} 'launchctl list | grep nextgen-plaid'${NC}"
  log "${YELLOW}  3. See RUNBOOK.md${NC}"
  exit 1
fi

echo ""

# ══════════════════════════════════════════════════════════════════════
# Summary
# ══════════════════════════════════════════════════════════════════════
echo -e "${GREEN}═══════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  Deployment Successful! ✓${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════${NC}"
echo ""
log "${BLUE}  Previous: ${PREVIOUS_COMMIT:0:7}${NC}"
log "${BLUE}  Current:  ${CURRENT_COMMIT:0:7}${NC}"
if [[ -n "${BACKUP_TIMESTAMP:-}" ]]; then
  log "${BLUE}  Backup:   ${BACKUP_TIMESTAMP}${NC}"
fi
log "${BLUE}  Health:   Passed${NC}"
echo ""
log "${BLUE}  URL: http://${PROD_HOST}:3000${NC}"
echo ""
```

### 7b. Key changes from original

| Issue | Old | New |
|-------|-----|-----|
| `SERVICE_NAME` | `gui/$(id -u)/...` (local UID) | `REMOTE_UID=$(ssh ... "id -u")` |
| Restart | `launchctl stop` + `launchctl start` | `launchctl kickstart -k` (atomic) |
| Health URL | `http://localhost:3000/health` | `http://localhost:3000/health?token=<TOKEN>` |
| Health token | Hardcoded/none | Read from prod `.env.production` |
| Health wait | Fixed `sleep 8` | Retry loop: 5/10/15/20/25/30s (up to 105s total) |
| Bundle | `--deployment --without dev test` | `bundle install` (no deprecated flags) |
| RAILS_ENV | Missing from `run_remote` | Always exported in `run_remote` |
| Error handling | `check_status()` with `$?` | Inline `|| { ...; exit 1; }` |

### 7c. How to test

```bash
# Dry-run pre-flight only (will fail at SSH if not on network — that's fine):
bin/deploy-prod --skip-tests --skip-backup
# Observe output up to SSH check.

# Full test: after Steps 1-6 are done on prod:
bin/deploy-prod --skip-tests
```

### 7d. Rollback

`git checkout bin/deploy-prod` restores the old version. If the new script partially deployed, follow the manual rollback in the [Rollback Master Plan](#rollback-master-plan).

---

## Step 8 — Update RUNBOOK.md

**Location:** Local repo (committed to git)

### 8a. Changes required

The RUNBOOK.md needs a comprehensive update. Key changes:

1. **Service Overview section:**
   - Rails 7.2 → Rails 8.1.1
   - Ruby 3.3.0 → Ruby 3.3.10
   - Add Redis to Key Technologies
   - Process manager: Foreman → launchd

2. **Operations section:**
   - Start: `bin/prod` description updated (no longer reads from Keychain)
   - Stop/Restart: Use `launchctl kickstart -k gui/$(id -u)/com.agentforge.nextgen-plaid`
   - Remove all Foreman references for production

3. **Secrets Management section:**
   - Replace entire Keychain section with `.env.production` instructions
   - Document all env vars and their purpose
   - Remove `scripts/setup-keychain.sh` references (keep script for legacy/migration)

4. **Health Checks section:**
   - Update URL: `curl 'http://192.168.4.253:3000/health?token=<HEALTH_TOKEN>'`
   - Document the `HEALTH_TOKEN` requirement
   - Mention SSL exclusion for localhost health checks

5. **Troubleshooting section:**
   - Replace all Keychain troubleshooting with `.env.production` checks
   - Add launchd-specific troubleshooting (`launchctl list`, log paths)
   - Add `log/launchd-stdout.log` and `log/launchd-stderr.log` to log locations

6. **Rollback Procedures:**
   - All `launchctl stop/start` → `launchctl kickstart -k`
   - Remove Keychain references

7. **Deployment section:**
   - Update Phase 4 (no `--deployment` flag)
   - Update Phase 7 (launchctl kickstart, retry health check)

8. **Appendix:**
   - Add `~/Library/LaunchAgents/com.agentforge.nextgen-plaid.plist` to file locations
   - Add `~/Library/LaunchAgents/com.agentforge.ollama.plist` to file locations
   - Remove `scripts/setup-keychain.sh` from active scripts (mark as legacy)

The full rewritten RUNBOOK.md should be produced during implementation. The implementer should use the existing structure as a template and apply all changes listed above.

### 8b. How to test

Read through the updated document and verify every command shown actually works on prod.

### 8c. Rollback

`git checkout RUNBOOK.md`

---

## Step 9 — Update docs/devops-handover.md

**Location:** Local repo (committed to git)

### 9a. Changes required

1. **Section 2 (Stack):** Process Manager: Foreman → launchd (LaunchAgent)
2. **Section 4 (Starting/Stopping):**
   - Start: `launchctl kickstart -k gui/$(id -u)/com.agentforge.nextgen-plaid`
   - Stop: `launchctl kill SIGTERM gui/$(id -u)/com.agentforge.nextgen-plaid`
   - Check Status: `launchctl list | grep nextgen-plaid`
   - Health Check: `curl 'http://localhost:3000/health?token=<HEALTH_TOKEN>'`
3. **Section 5 (Deployment):** Reference updated `bin/deploy-prod` behavior
4. **Section 6 (Secrets):** Replace entire Keychain section with `.env.production` documentation
5. **Section 10 (Logs):** Add `log/launchd-stdout.log`, `log/launchd-stderr.log`
6. **Section 11 (Known Issues):** Remove Keychain and Foreman issues; add new items if any
7. **Section 12 (Scripts):** Update `bin/prod` description; mark `scripts/setup-keychain.sh` as legacy

### 9b. How to test

Read through; verify accuracy against actual prod state.

### 9c. Rollback

`git checkout docs/devops-handover.md`

---

## Step 10 — Deploy & Smoke Test

**Prerequisites:** Steps 1–9 all complete. Steps 1–3, 7–9 committed and pushed to main. Steps 4–6 done on prod.

### 10a. Deploy from dev machine

```bash
cd /Users/ericsmith66/development/agent-forge/projects/nextgen-plaid
git checkout main
git pull origin main
bin/deploy-prod --skip-tests   # Skip tests for the first deploy (we ran them locally already)
```

**Expected output:**
- All 7 phases succeed
- Health check passes on retry (likely attempt 1 or 2)
- "Deployment Successful!" message

### 10b. Smoke tests (manual)

```bash
# 1. Health endpoint from dev machine:
HEALTH_TOKEN="<the-token>"
curl -s "http://192.168.4.253:3000/health?token=${HEALTH_TOKEN}"
# Expected: {"status":"ok"}

# 2. Health endpoint without token (should be rejected):
curl -s -o /dev/null -w '%{http_code}' "http://192.168.4.253:3000/health"
# Expected: 401

# 3. App login page loads (through Cloudflare or direct):
curl -s -o /dev/null -w '%{http_code}' "http://192.168.4.253:3000/users/sign_in"
# Expected: 200 (or 301 if force_ssl redirects — that's OK for browser access)

# 4. launchd service status:
ssh ericsmith66@192.168.4.253 "launchctl list | grep nextgen-plaid"
# Expected: PID  0  com.agentforge.nextgen-plaid

# 5. Ollama is running:
ssh ericsmith66@192.168.4.253 "curl -s http://localhost:11434/api/tags | head -c 100"
# Expected: JSON with models listed

# 6. SolidQueue is processing:
ssh ericsmith66@192.168.4.253 "cd /Users/ericsmith66/Development/nextgen-plaid && ps aux | grep solid_queue | grep -v grep"
# Expected: process running
```

### 10c. Rollback

If deployment fails, follow [Rollback Master Plan](#rollback-master-plan).

---

## Step 11 — Reboot Verification

**Purpose:** Confirm that PostgreSQL, Redis, Ollama, nextgen-plaid (Puma + SolidQueue), and the health endpoint all auto-start after a clean reboot.

### 11a. Reboot prod

```bash
ssh ericsmith66@192.168.4.253 "sudo shutdown -r now"
```

### 11b. Wait and verify (allow 2-3 minutes for boot + service startup)

After 3 minutes, run the following checks from the **dev machine**:

```bash
# 1. SSH connectivity:
ssh ericsmith66@192.168.4.253 "echo OK"
# Expected: OK

# 2. PostgreSQL:
ssh ericsmith66@192.168.4.253 "pg_isready -h localhost -p 5432"
# Expected: localhost:5432 - accepting connections

# 3. Redis:
ssh ericsmith66@192.168.4.253 "redis-cli ping"
# Expected: PONG

# 4. Ollama:
ssh ericsmith66@192.168.4.253 "curl -s http://localhost:11434/api/tags | head -c 100"
# Expected: JSON response

# 5. nextgen-plaid (Puma):
ssh ericsmith66@192.168.4.253 "lsof -i :3000 | head -5"
# Expected: puma process listening

# 6. Health endpoint:
HEALTH_TOKEN="<the-token>"
curl -s "http://192.168.4.253:3000/health?token=${HEALTH_TOKEN}"
# Expected: {"status":"ok"}

# 7. SolidQueue:
ssh ericsmith66@192.168.4.253 "ps aux | grep solid_queue | grep -v grep"
# Expected: running process

# 8. launchd services:
ssh ericsmith66@192.168.4.253 "launchctl list | grep -E 'nextgen-plaid|ollama'"
# Expected: Both show PID numbers (not "-")
```

### 11c. Reboot Verification Checklist

| # | Service | Check Command | Expected | Pass? |
|---|---------|---------------|----------|-------|
| 1 | SSH | `ssh ... "echo OK"` | OK | ☐ |
| 2 | PostgreSQL | `pg_isready -h localhost -p 5432` | accepting connections | ☐ |
| 3 | Redis | `redis-cli ping` | PONG | ☐ |
| 4 | Ollama | `curl localhost:11434/api/tags` | JSON response | ☐ |
| 5 | Puma (port 3000) | `lsof -i :3000` | puma process | ☐ |
| 6 | Health endpoint | `curl .../health?token=...` | `{"status":"ok"}` HTTP 200 | ☐ |
| 7 | SolidQueue | `ps aux \| grep solid_queue` | running | ☐ |
| 8 | launchd plists | `launchctl list \| grep ...` | PID for both services | ☐ |

### 11d. If any check fails

1. **SSH fails:** Machine may still be booting. Wait another 2 minutes. If still fails, check physical access/display.
2. **PostgreSQL/Redis fail:** Check Homebrew LaunchAgents — `launchctl list | grep -E 'postgres|redis'`. May need `brew services start postgresql@16` / `brew services start redis`.
3. **Ollama fails:** Check `~/Library/Logs/ollama-stderr.log`. May have wrong binary path in plist.
4. **Puma/Health fails:** Check `log/launchd-stderr.log`. Most likely cause: `.env.production` parsing error or missing secret.
5. **SolidQueue fails:** SolidQueue runs inside Foreman (via `Procfile.prod`). If Puma is up but SQ is not, check `log/launchd-stdout.log` for Foreman output.

---

## Rollback Master Plan

### Scenario A: Deployment partially broke prod (app won't start)

```bash
# 1. Rollback code to previous commit:
ssh ericsmith66@192.168.4.253 \
  "cd /Users/ericsmith66/Development/nextgen-plaid && git reset --hard $(cat .last_commit)"

# 2. Restore old bin/prod (Keychain version):
ssh ericsmith66@192.168.4.253 \
  "cd /Users/ericsmith66/Development/nextgen-plaid && git checkout HEAD -- bin/prod"

# 3. Stop launchd service and start manually:
ssh ericsmith66@192.168.4.253 "launchctl bootout gui/\$(id -u)/com.agentforge.nextgen-plaid 2>/dev/null || true"
# Then start manually with unlocked Keychain (GUI terminal):
ssh ericsmith66@192.168.4.253 "cd /Users/ericsmith66/Development/nextgen-plaid && security unlock-keychain ~/Library/Keychains/login.keychain-db && bin/prod"
```

### Scenario B: Database migration broke data

```bash
# 1. Stop app:
ssh ericsmith66@192.168.4.253 "launchctl kill SIGTERM gui/\$(id -u)/com.agentforge.nextgen-plaid"

# 2. Restore database:
TIMESTAMP=$(cat .last_backup_timestamp)
ssh ericsmith66@192.168.4.253 \
  "cd /Users/ericsmith66/Development/nextgen-plaid && ./scripts/restore-database.sh ${TIMESTAMP}"

# 3. Rollback code:
ssh ericsmith66@192.168.4.253 \
  "cd /Users/ericsmith66/Development/nextgen-plaid && git reset --hard $(cat .last_commit)"

# 4. Restart:
ssh ericsmith66@192.168.4.253 "launchctl kickstart -k gui/\$(id -u)/com.agentforge.nextgen-plaid"
```

### Scenario C: Revert launchd entirely (go back to manual Foreman)

```bash
ssh ericsmith66@192.168.4.253
launchctl bootout gui/$(id -u)/com.agentforge.nextgen-plaid
rm ~/Library/LaunchAgents/com.agentforge.nextgen-plaid.plist
cd /Users/ericsmith66/Development/nextgen-plaid
git checkout HEAD -- bin/prod
security unlock-keychain ~/Library/Keychains/login.keychain-db
bin/prod
```

---

## Risks & Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| `.env.production` password with special chars fails dotenv parsing | Medium | App won't start | Test with `bin/rails runner` before going live (Step 4b). If needed, wrap value in double quotes in the file. |
| launchd `bash -l` doesn't source rbenv properly | Low | App won't start | `bin/prod` also sources `~/.zprofile` explicitly. Check `log/launchd-stderr.log`. |
| Ollama binary path differs from `/usr/local/bin/ollama` | Medium | Ollama won't auto-start | Verify with `which ollama` before writing plist (Step 6a). |
| `HEALTH_TOKEN` read from `.env.production` fails in deploy script | Low | Deploy aborts at health check | `read_remote_env` function is tested in isolation first. |
| Reboot takes longer than 3 min (macOS updates, etc.) | Low | False negative on reboot test | Wait longer; checks are idempotent. |
| Foreman + KeepAlive rapid-restart loop on crash | Low | High CPU, log spam | `ThrottleInterval 10` limits to 1 restart per 10s. `bin/prod` exits on missing `.env.production` (fast, clean failure). |

---

**End of Implementation Plan**
