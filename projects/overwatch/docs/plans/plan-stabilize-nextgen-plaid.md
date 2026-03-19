# Plan: Stabilize nextgen-plaid for Production
**Created:** February 17, 2026  
**Source:** [roadmap-nextgen-plaid.md](../roadmaps/roadmap-nextgen-plaid.md)  
**Status:** IN PROGRESS — Security remediation completed Feb 18, 2026  
**Updated:** February 18, 2026  
**Estimated Effort:** 5-6 hours across 2-3 days  
**Downtime Window:** ~5-10 minutes during cutover (Step 7 of Day 2)  
**Operations Log:** [2026-02-18 Security Remediation](../operations-log/2026-02-18-security-remediation-and-history-purge.md)

---

## Completed Pre-Work (Feb 18, 2026)

The following was completed as part of Epic 8 security remediation:

| Action | Status | Detail |
|--------|--------|--------|
| Git history purge (SQL blobs) | ✅ | `git filter-repo` removed all `.sql` files from history |
| Force-push clean history | ✅ | GitHub `main` updated to `4260ba5` |
| Prod server re-cloned | ✅ | Fresh clone via git bundle (SSH key issue — see below) |
| `.gitignore` hardened | ✅ | Global `*.sql` rule, `config/master.key`, `.env*` blocked |
| `.env.example` created | ✅ | Placeholders for all project secrets |
| Holdings migration preserved | ✅ | Committed on `feature/holdings` branch (`de48347`), pushed to GitHub |
| `bin/dev` port fix | ✅ | Default port changed from 3016 to 3000 (on `feature/holdings`) |
| `config/master.key` restored | ✅ | MD5 verified: `1428f4b005cee6cbe3db188907e4b340` (matches dev) |
| `config/credentials.yml.enc` restored | ✅ | MD5 verified: `f5659cd31978a64bae0e9efaa771ef05` (matches dev) |

### New Issues Identified (must address before/during stabilization)

| Issue | Priority | Impact | Resolution |
|-------|----------|--------|------------|
| SSH key on prod not registered with GitHub | High | Cannot `git pull`/`push` non-interactively | Register `id_ed25519` with GitHub or configure HTTPS credential caching |
| `credentials.yml.enc` missing from git | Medium | Fresh clones can't decrypt credentials | Commit to repo (encrypted file, safe for git) |
| Non-interactive service startup fails | High | Tailwind watcher requires TTY; foreman cascades SIGTERM | Addressed by TASK 1.1/1.2 (`Procfile.prod` + `bin/prod`) |
| Old backup on prod server | Low | Disk space: `~/Development/nextgen-plaid-old-backup/` | Clean up after confirming stability |
| Temp backup files on prod | Low | `/tmp/nextgen-plaid-*` artifacts | Clean up after confirming stability |
| 5 stashes lost from old repo | Info | Old WIP from various branches (pre-history-rewrite) | Stash list saved at `/tmp/nextgen-plaid-stash-list.txt` on prod |

---

## Pre-Flight Findings (from live audit)

| Item | Current State | Impact on Plan |
|------|--------------|----------------|
| Health endpoint | `admin/health#index` exists but **requires auth** (Pundit) | Still need unauthenticated `/health` for launchd/deploy |
| `force_ssl` | `true` in production.rb | Must add `/health` to SSL exclusion (like `/up` already is) |
| `assume_ssl` | `true` in production.rb | OK — Cloudflare/UDM terminates SSL before it hits the app |
| Production databases | **Do not exist** — only `_development` and `_test` | Must create and migrate data |
| Dev DB size | 88 MB, 38 tables | Small — pg_dump/restore will take < 1 minute |
| DB user `nextgen_plaid` | Exists with superuser privileges | Ready — no user creation needed |
| `psql` path | `/opt/homebrew/opt/postgresql@16/bin/psql` (not in default PATH) | All scripts must set PATH explicitly |
| `config/master.key` | ✅ Present on prod (32 bytes, verified Feb 18) | Good — Rails credentials will work |
| `secret_key_base` | Present in Rails credentials | Good — production encryption works |
| Orphaned test DBs | ~200+ test databases on prod | Cleanup task (not blocking) |
| Prod code | ✅ `main` at `4260ba5` (Feb 18, clean history) | `feature/holdings` ready to merge |

---

## Detailed Task List

### DAY 1 — Preparation (Dev Machine + Prod Server)

All Day 1 tasks can be done without any downtime.

---

#### TASK 1.1: Create `Procfile.prod` (dev machine)
**Where:** `nextgen-plaid/Procfile.prod` (new file)  
**Time:** 10 min  
**Depends on:** Nothing

**Content:**
```
web: bin/rails server -b 0.0.0.0 -p ${PORT:-3000} -e production
proxy: cd smart_proxy && SMART_PROXY_PORT=3002 bundle exec rackup -o 0.0.0.0 -p 3002
worker: RAILS_ENV=production bin/rails solid_queue:start
```

**Verify:** File exists, no syntax issues.  
**Note:** `proxy:` line is temporary — removed when SmartProxy extracts to standalone (Phase 1.5).

---

#### TASK 1.2: Create `bin/prod` launcher (dev machine)
**Where:** `nextgen-plaid/bin/prod` (new file, chmod +x)  
**Time:** 20 min  
**Depends on:** TASK 1.1

**Content:** See [roadmap-nextgen-plaid.md Step 2](../roadmaps/roadmap-nextgen-plaid.md) for full script.

**Key behaviors:**
- Loads all secrets from macOS Keychain via `security find-generic-password`
- Sets all non-secret env vars inline
- Validates `PLAID_SECRET` and `ENCRYPTION_KEY` are present before starting
- Runs `foreman start -f Procfile.prod --env /dev/null` (ignores `.env` files)

**Verify:** `bash -n bin/prod` (syntax check), `chmod +x bin/prod`.

---

#### TASK 1.3: Create `scripts/setup-keychain.sh` (dev machine)
**Where:** `nextgen-plaid/scripts/setup-keychain.sh` (new file)  
**Time:** 10 min  
**Depends on:** Nothing

**Content:** See [roadmap-nextgen-plaid.md Step 3](../roadmaps/roadmap-nextgen-plaid.md) for full script.

**Secrets to store (10 total):**
1. `PLAID_CLIENT_ID`
2. `PLAID_SECRET`
3. `ENCRYPTION_KEY`
4. `CLAUDE_CODE_API_KEY`
5. `GROK_API_KEY`
6. `PROXY_AUTH_TOKEN`
7. `FINNHUB_API_KEY`
8. `FMP_API_KEY`
9. `NEXTGEN_PLAID_DATABASE_PASSWORD`
10. `PROD_USER_PASSWORD`

**Verify:** `bash -n scripts/setup-keychain.sh` (syntax check).

---

#### TASK 1.4: Add unauthenticated `/health` endpoint (dev machine)
**Where:** `nextgen-plaid/config/routes.rb` (modify)  
**Time:** 15 min  
**Depends on:** Nothing

**What to add** (outside any authenticated scope, at the top of routes):
```ruby
get "/health", to: proc {
  [200, { "Content-Type" => "application/json" }, [
    { status: "ok", app: "nextgen-plaid", timestamp: Time.current.iso8601 }.to_json
  ]]
}
```

**Also update** `config/environments/production.rb` — extend the SSL exclusion:
```ruby
# Current:
config.ssl_options = { hsts: { subdomains: false }, redirect: { exclude: ->(request) { request.path == "/up" } } }

# Change to:
config.ssl_options = { hsts: { subdomains: false }, redirect: { exclude: ->(request) { request.path.in?(["/up", "/health"]) } } }
```

**Verify:** `bin/rails routes | grep health` shows the new route. Existing `admin/health` is unchanged.

---

#### TASK 1.5: Create `config/launchd/com.agentforge.nextgen-plaid.plist` (dev machine)
**Where:** `nextgen-plaid/config/launchd/com.agentforge.nextgen-plaid.plist` (new file)  
**Time:** 10 min  
**Depends on:** Nothing

**Content:** See [roadmap-nextgen-plaid.md Step 4](../roadmaps/roadmap-nextgen-plaid.md) for full plist.

**Key settings:**
- `RunAtLoad: true` — starts on login
- `KeepAlive: true` — restarts on crash
- Logs to `~/logs/nextgen-plaid/stdout.log` and `stderr.log`
- Runs `bin/prod` via `bash -lc` (loads brew + rbenv)

**Verify:** `plutil -lint config/launchd/com.agentforge.nextgen-plaid.plist` (valid plist XML).

---

#### TASK 1.6: Create `bin/deploy-prod` (dev machine)
**Where:** `nextgen-plaid/bin/deploy-prod` (new file, chmod +x)  
**Time:** 15 min  
**Depends on:** Nothing

**Content:** See [roadmap-nextgen-plaid.md Step 6](../roadmaps/roadmap-nextgen-plaid.md) for full script.

**Key behaviors:**
- Warns if not on `main` branch
- SSH → git pull → bundle install → db:migrate → assets:precompile → restart launchd → health check
- All remote commands set PATH to include postgres and rbenv

**Important fix from audit:** All `ssh` commands must prefix with:
```bash
export PATH="/opt/homebrew/opt/postgresql@16/bin:/opt/homebrew/bin:/opt/homebrew/sbin:$PATH" && eval "$(rbenv init -)"
```

**Verify:** `bash -n bin/deploy-prod` (syntax check), `chmod +x bin/deploy-prod`.

---

#### TASK 1.7: Commit and merge to `main`
**Where:** Dev machine  
**Time:** 15 min  
**Depends on:** TASKS 1.1–1.6

**Files to commit:**
```
new:  Procfile.prod
new:  bin/prod
new:  bin/deploy-prod
new:  scripts/setup-keychain.sh
new:  config/launchd/com.agentforge.nextgen-plaid.plist
mod:  config/routes.rb
mod:  config/environments/production.rb
```

**Process:**
1. Create branch `ops/production-stabilization` from `main`
2. Commit all files
3. Push and merge PR to `main` (or direct push if no branch protection yet)
4. Verify `main` has all new files

---

#### TASK 1.8: Populate Keychain on production server
**Where:** Production server (192.168.4.253), interactive SSH session  
**Time:** 15 min  
**Depends on:** TASK 1.7 (script must be on prod via git pull)

**Commands:**
```bash
ssh ericsmith66@192.168.4.253
cd ~/Development/nextgen-plaid
git pull origin main
bash scripts/setup-keychain.sh
```

**Secret values:** Copy from current `.env` on prod server (they're right there in plaintext today).

**Verify:** Script outputs `✓` for all 10 secrets with correct char lengths:
- `PLAID_CLIENT_ID`: 24 chars
- `PLAID_SECRET`: 30 chars
- `ENCRYPTION_KEY`: 64 chars
- `CLAUDE_CODE_API_KEY`: ~100 chars
- `GROK_API_KEY`: ~68 chars
- `PROXY_AUTH_TOKEN`: 64 chars
- `FINNHUB_API_KEY`: ~40 chars
- `FMP_API_KEY`: ~32 chars
- `NEXTGEN_PLAID_DATABASE_PASSWORD`: varies
- `PROD_USER_PASSWORD`: varies

---

### DAY 2 — Database Migration + Cutover

---

#### TASK 2.1: Create log directory on prod
**Where:** Production server  
**Time:** 1 min  
**Depends on:** Nothing

```bash
ssh ericsmith66@192.168.4.253 'mkdir -p ~/logs/nextgen-plaid'
```

**Verify:** Directory exists.

---

#### TASK 2.2: Backup development database
**Where:** Production server  
**Time:** 5 min (88 MB DB)  
**Depends on:** Nothing

```bash
ssh ericsmith66@192.168.4.253 '
export PATH="/opt/homebrew/opt/postgresql@16/bin:$PATH"
pg_dump nextgen_plaid_development > ~/backup-pre-production-$(date +%Y%m%d).sql
ls -lh ~/backup-pre-production-*.sql
'
```

**Verify:** Backup file exists, size ≈ 88 MB.  
**CRITICAL:** Do not proceed without a verified backup.

---

#### TASK 2.3: Create production databases
**Where:** Production server  
**Time:** 5 min  
**Depends on:** TASK 2.2

```bash
ssh ericsmith66@192.168.4.253 '
export PATH="/opt/homebrew/opt/postgresql@16/bin:$PATH"

# Primary database — copy from development
createdb -O nextgen_plaid nextgen_plaid_production
psql nextgen_plaid_production < ~/backup-pre-production-*.sql

# Cache and queue databases — create fresh (transient data, no need to copy)
createdb -O nextgen_plaid nextgen_plaid_production_cache
createdb -O nextgen_plaid nextgen_plaid_production_queue

# Verify
psql -d postgres -c "SELECT datname, pg_size_pretty(pg_database_size(datname)) FROM pg_database WHERE datname LIKE '\''nextgen_plaid_production%'\'';"
'
```

**Verify:**
- `nextgen_plaid_production` ≈ 88 MB (data from dev)
- `nextgen_plaid_production_cache` ≈ small (empty)
- `nextgen_plaid_production_queue` ≈ small (empty)

---

#### TASK 2.4: Set database user password
**Where:** Production server  
**Time:** 2 min  
**Depends on:** TASK 2.3

```bash
ssh ericsmith66@192.168.4.253 '
export PATH="/opt/homebrew/opt/postgresql@16/bin:$PATH"
psql -d postgres -c "ALTER USER nextgen_plaid WITH PASSWORD '\''YOUR_CHOSEN_PASSWORD'\'';"
'
```

**Important:** Use the same password you stored in Keychain as `NEXTGEN_PLAID_DATABASE_PASSWORD` in TASK 1.8.

**Verify:** `psql -U nextgen_plaid -d nextgen_plaid_production -c "SELECT 1;"` works with password.

---

#### TASK 2.5: Run production migrations
**Where:** Production server  
**Time:** 5 min  
**Depends on:** TASKS 2.3, 2.4, 1.8 (Keychain populated)

```bash
ssh ericsmith66@192.168.4.253 '
export PATH="/opt/homebrew/opt/postgresql@16/bin:/opt/homebrew/bin:$PATH"
eval "$(rbenv init -)"
cd ~/Development/nextgen-plaid

# Source secrets for the migration
export NEXTGEN_PLAID_DATABASE_PASSWORD=$(security find-generic-password -a "nextgen-plaid" -s "NEXTGEN_PLAID_DATABASE_PASSWORD" -w)
export ENCRYPTION_KEY=$(security find-generic-password -a "nextgen-plaid" -s "ENCRYPTION_KEY" -w)

RAILS_ENV=production bin/rails db:migrate
RAILS_ENV=production bin/rails db:migrate:status | tail -20
'
```

**Verify:** All migrations show `up`. No errors.

---

#### TASK 2.6: Precompile assets
**Where:** Production server  
**Time:** 2-5 min  
**Depends on:** TASK 2.5

```bash
ssh ericsmith66@192.168.4.253 '
export PATH="/opt/homebrew/opt/postgresql@16/bin:/opt/homebrew/bin:$PATH"
eval "$(rbenv init -)"
cd ~/Development/nextgen-plaid

export ENCRYPTION_KEY=$(security find-generic-password -a "nextgen-plaid" -s "ENCRYPTION_KEY" -w)

RAILS_ENV=production bin/rails assets:precompile
ls -la public/assets/ | head -10
'
```

**Verify:** `public/assets/` populated with fingerprinted files.

---

#### TASK 2.7: Verify pf rules
**Where:** Production server  
**Time:** 1 min  
**Depends on:** Nothing

```bash
ssh ericsmith66@192.168.4.253 'sudo pfctl -a com.nextgen.plaid -s nat'
```

**Expected output:**
```
rdr pass on lo0 inet proto tcp from any to any port = 80 -> 127.0.0.1 port 3000
rdr pass on en0 inet proto tcp from any to any port = 80 -> 192.168.4.253 port 3000
```

**Verify:** Both rules present. If not, DO NOT proceed — pf rules must be restored first.

---

#### TASK 2.8: ⚡ CUTOVER — Stop dev mode, start production mode
**Where:** Production server (interactive SSH)  
**Time:** 10 min  
**Depends on:** ALL previous tasks  
**⚠️ THIS IS THE DOWNTIME WINDOW (~5-10 minutes)**

```bash
ssh ericsmith66@192.168.4.253

# ── Step A: Kill the running foreman (dev mode) ──
# Find the PID (should be ~12143 but verify)
ps aux | grep foreman | grep -v grep
# Kill it
kill <FOREMAN_PID>
# Verify everything stopped
sleep 2
lsof -iTCP:3000 -sTCP:LISTEN   # Should show nothing
lsof -iTCP:3002 -sTCP:LISTEN   # Should show nothing

# ── Step B: Test bin/prod manually ──
export PATH="/opt/homebrew/opt/postgresql@16/bin:/opt/homebrew/bin:$PATH"
eval "$(rbenv init -)"
cd ~/Development/nextgen-plaid
bin/prod

# In another terminal/tab:
curl -k http://localhost:3000/health
# Expected: {"status":"ok","app":"nextgen-plaid","timestamp":"2026-02-..."}

curl http://localhost:3002/health
# Expected: SmartProxy health response

# If BOTH work → Ctrl+C to stop bin/prod
# If EITHER fails → see ROLLBACK PLAN below

# ── Step C: Install and load launchd plist ──
cp config/launchd/com.agentforge.nextgen-plaid.plist ~/Library/LaunchAgents/
launchctl load ~/Library/LaunchAgents/com.agentforge.nextgen-plaid.plist

# ── Step D: Verify launchd started it ──
sleep 5
launchctl list | grep nextgen
# Expected: <PID>  0  com.agentforge.nextgen-plaid

curl -k http://localhost:3000/health
# Expected: {"status":"ok",...}

curl http://localhost:3002/health
# Expected: SmartProxy OK

# ── Step E: Verify external access ──
curl -k http://localhost:80/health
# Expected: Same as :3000 (pf redirect working)
```

---

#### TASK 2.9: Test deploy script from dev machine
**Where:** Dev machine  
**Time:** 10 min  
**Depends on:** TASK 2.8

```bash
cd ~/development/agent-forge/projects/nextgen-plaid
bin/deploy-prod
```

**Verify:** Script completes with `✅ Deploy successful — app is healthy`.

---

#### TASK 2.10: Reboot test
**Where:** Production server  
**Time:** 10 min  
**Depends on:** TASK 2.8

```bash
# From dev machine, trigger reboot
ssh ericsmith66@192.168.4.253 'sudo reboot'

# Wait 2-3 minutes for macOS to come back up
sleep 180

# Verify everything came back
ssh ericsmith66@192.168.4.253 '
curl -sf http://localhost:3000/health
curl -sf http://localhost:3002/health
launchctl list | grep nextgen
lsof -iTCP:3000 -sTCP:LISTEN -nP
lsof -iTCP:3002 -sTCP:LISTEN -nP
'
```

**Verify:**
- `/health` returns 200
- SmartProxy on :3002
- launchd shows running PID
- PostgreSQL, Redis, Ollama also came back (they have their own LaunchAgents)

---

### DAY 3 — Cleanup + Monitoring

---

#### TASK 3.1: Clean up plaintext secrets on prod
**Where:** Production server  
**Time:** 10 min  
**Depends on:** TASK 2.10 passes (everything survived reboot)

```bash
ssh ericsmith66@192.168.4.253 '
cd ~/Development/nextgen-plaid

# Delete .env.production (secrets now in Keychain)
rm -f .env.production

# Sanitize .env — keep only non-secret dev config or remove entirely
# Option A: Remove it (bin/prod ignores .env files anyway)
rm -f .env

# Option B: Replace with sandbox-only values
# cat > .env << '\''EOF'\''
# PLAID_ENV=sandbox
# PLAID_CLIENT_ID=sandbox_client_id
# PLAID_SECRET=sandbox_secret
# EOF
'
```

**Verify:** `ls -la .env*` shows no secret-containing files.

---

#### TASK 3.2: Verify Solid Queue jobs run
**Where:** Production server  
**Time:** 15 min (observe)  
**Depends on:** TASK 2.8

```bash
ssh ericsmith66@192.168.4.253 '
export PATH="/opt/homebrew/opt/postgresql@16/bin:/opt/homebrew/bin:$PATH"
eval "$(rbenv init -)"
cd ~/Development/nextgen-plaid

export NEXTGEN_PLAID_DATABASE_PASSWORD=$(security find-generic-password -a "nextgen-plaid" -s "NEXTGEN_PLAID_DATABASE_PASSWORD" -w)
export ENCRYPTION_KEY=$(security find-generic-password -a "nextgen-plaid" -s "ENCRYPTION_KEY" -w)

RAILS_ENV=production bin/rails runner "
  puts \"Active processes: #{SolidQueue::Process.where(\"last_heartbeat_at >= ?\", 1.minute.ago).count}\"
  puts \"Pending jobs: #{SolidQueue::Job.where(finished_at: nil).count}\"
  puts \"Last finished: #{SolidQueue::Job.where.not(finished_at: nil).maximum(:finished_at)}\"
"
'
```

**Verify:** Active processes > 0, heartbeat recent.

---

#### TASK 3.3: Check production logs
**Where:** Production server  
**Time:** 10 min  
**Depends on:** TASK 2.8

```bash
ssh ericsmith66@192.168.4.253 '
echo "=== Launchd stderr (last 30 lines) ==="
tail -30 ~/logs/nextgen-plaid/stderr.log

echo ""
echo "=== Rails production log (last 30 lines) ==="
tail -30 ~/Development/nextgen-plaid/log/production.log

echo ""
echo "=== Any errors? ==="
grep -i "error\|fatal\|exception" ~/logs/nextgen-plaid/stderr.log | tail -10
grep -i "error\|fatal\|exception" ~/Development/nextgen-plaid/log/production.log | tail -10
'
```

**Verify:** No unexpected errors. Normal request logging visible.

---

#### TASK 3.4: Clean up orphaned test databases (optional)
**Where:** Production server  
**Time:** 15 min  
**Depends on:** Nothing (non-blocking)

```bash
ssh ericsmith66@192.168.4.253 '
export PATH="/opt/homebrew/opt/postgresql@16/bin:$PATH"

# List all test DBs
psql -d postgres -t -c "SELECT datname FROM pg_database WHERE datname LIKE '\''nextgen_plaid_test%'\'' ORDER BY datname;"

# Drop them (200+ databases!)
psql -d postgres -t -c "SELECT datname FROM pg_database WHERE datname LIKE '\''nextgen_plaid_test%'\'';" | while read db; do
  db=$(echo "$db" | xargs)  # trim whitespace
  [ -n "$db" ] && echo "Dropping $db..." && dropdb "$db"
done

echo "Remaining databases:"
psql -d postgres -l | grep nextgen
'
```

**Verify:** Only `_development`, `_development_cable`, `_development_queue`, `_production`, `_production_cache`, `_production_queue` remain.

---

## Rollback Plan

If anything fails during TASK 2.8 cutover:

```bash
# 1. Stop launchd if it was loaded
launchctl unload ~/Library/LaunchAgents/com.agentforge.nextgen-plaid.plist 2>/dev/null

# 2. Start the old way (dev mode — zero config changes needed)
cd ~/Development/nextgen-plaid
bin/dev

# 3. App is back on :3000 in development mode
# Total rollback time: < 30 seconds
```

**Database is safe** — we copied dev → production, never renamed or deleted the dev database.

---

## Complete Checklist

### Pre-Cutover (Day 1)
- [ ] TASK 1.1: `Procfile.prod` created
- [ ] TASK 1.2: `bin/prod` created and executable
- [ ] TASK 1.3: `scripts/setup-keychain.sh` created
- [ ] TASK 1.4: `/health` endpoint added to routes + SSL exclusion updated
- [ ] TASK 1.5: Launchd plist created
- [ ] TASK 1.6: `bin/deploy-prod` created and executable
- [ ] TASK 1.7: All files committed and merged to `main`
- [ ] TASK 1.8: Keychain populated on prod (all 10 secrets verified)

### Cutover (Day 2)
- [ ] TASK 2.1: Log directory created on prod
- [ ] TASK 2.2: Dev database backed up
- [ ] TASK 2.3: Production databases created + data restored
- [ ] TASK 2.4: Database user password set
- [ ] TASK 2.5: Production migrations run successfully
- [ ] TASK 2.6: Assets precompiled
- [ ] TASK 2.7: pf rules verified
- [ ] TASK 2.8: **CUTOVER** — dev mode stopped, production mode started via launchd
- [ ] TASK 2.9: Deploy script tested from dev machine
- [ ] TASK 2.10: Reboot test passed

### Post-Cutover (Day 3)
- [ ] TASK 3.1: Plaintext `.env` files cleaned up on prod
- [ ] TASK 3.2: Solid Queue jobs running
- [ ] TASK 3.3: Logs reviewed — no unexpected errors
- [ ] TASK 3.4: Orphaned test databases cleaned up (optional)

### Final Verification
- [ ] `curl https://api.higroundsolutions.com/health` returns 200
- [ ] Plaid sync completes successfully
- [ ] SmartProxy on :3002 responds
- [ ] Ollama accessible via SmartProxy
- [ ] Port 80 → 3000 pf redirect works
- [ ] App survives Mac reboot
- [ ] Deploy script works end-to-end
- [ ] No plaintext secrets on disk

---

## Files Created/Modified

| File | Location | Action | Committed to Git? |
|------|----------|--------|-------------------|
| `Procfile.prod` | nextgen-plaid repo | New | Yes |
| `bin/prod` | nextgen-plaid repo | New | Yes |
| `bin/deploy-prod` | nextgen-plaid repo | New | Yes |
| `scripts/setup-keychain.sh` | nextgen-plaid repo | New | Yes |
| `config/launchd/com.agentforge.nextgen-plaid.plist` | nextgen-plaid repo | New | Yes |
| `config/routes.rb` | nextgen-plaid repo | Modified | Yes |
| `config/environments/production.rb` | nextgen-plaid repo | Modified | Yes |
| `~/Library/LaunchAgents/com.agentforge.nextgen-plaid.plist` | Prod server only | Copied from repo | No (server-only) |
| `.env.production` | Prod server only | **Deleted** | N/A |
| `.env` | Prod server only | **Deleted or sanitized** | N/A |

---

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Asset precompilation fails | Low | Blocks cutover | Fix errors in production.rb, retry |
| DB migration fails | Low | Blocks cutover | Restore from backup, fix migration, retry |
| Keychain access denied by launchd | Medium | App won't start | Run `security` with `-T /bin/bash` to grant access |
| `force_ssl` blocks health check | Medium | Health check 301s | SSL exclusion added in TASK 1.4 |
| Foreman PID wrong | Low | Old process not killed | Use `lsof -iTCP:3000` to verify port is free |
| Pf rules lost after reboot | Very Low | Port 80 stops working | Rules loaded from `/etc/pf.conf` on boot; verified in TASK 2.7 |

---

## Next Steps After Completion

1. **Phase 1.5:** Extract SmartProxy to standalone service
2. **Phase 1.75:** Deploy Prefab (HomeKit bridge)
3. **Phase 2:** Deploy eureka-homekit

See [roadmap-environment.md](../roadmaps/roadmap-environment.md) for the full sequence.
