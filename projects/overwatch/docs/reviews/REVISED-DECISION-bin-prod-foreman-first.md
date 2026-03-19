# REVISED DECISION: Implement Foreman First (Pragmatic Approach)

**Date:** 2026-02-23  
**Decision:** ✅ Implement Option B (Foreman) NOW, migrate to launchd LATER  
**Rationale:** Get reliable deployment working before optimizing process management

---

## The Pragmatic Reality ✅

**User's Insight:**
> "Until we have our push working I would implement Foreman. I agree that we should change to launchd but until we can reliably deploy I won't want to start another effort."

**This is CORRECT engineering judgment:**
- ✅ Working deployment >> Perfect architecture
- ✅ Ship incremental improvements
- ✅ Reduce variables during stabilization
- ✅ Optimize after validating the baseline

---

## Revised Implementation Plan

### Phase 1: Get Deployment Working (NOW)
**Goal:** Reliable automated deployments  
**Timeline:** This week  
**Approach:** Use Foreman (matches bin/dev pattern)

### Phase 2: Optimize Process Management (LATER)
**Goal:** Production-grade supervision  
**Timeline:** After deployment is stable  
**Approach:** Migrate to launchd

---

## Phase 1: Implement Foreman (Immediate)

### Changes to Make:

#### 1. Add rbenv Initialization (CRITICAL - Still Required)

**Location:** After line 21 in `bin/prod`

```bash
# Initialize rbenv for correct Ruby version
if [ -f ~/.zprofile ]; then
    source ~/.zprofile
fi
if command -v rbenv >/dev/null 2>&1; then
    eval "$(rbenv init -)"
fi

# Display Ruby version
echo -e "${BLUE}Ruby Version:${NC} $(ruby -v)"
echo ""
```

#### 2. Create Procfile.prod

**Location:** `nextgen-plaid/Procfile.prod` (new file)

```yaml
web: env PORT=3000 bin/rails server -e production -b 0.0.0.0
worker: bin/rails solid_queue:start
```

**Notes:**
- No `css:` watcher (assets precompiled in production)
- No `proxy:` line yet (still embedded, Phase 1.5 will extract)

#### 3. Update bin/prod to Use Foreman

**Location:** `nextgen-plaid/bin/prod`

**Replace lines 89-96 with:**

```bash
# Install foreman if needed
if ! gem list foreman -i --silent; then
    echo -e "${YELLOW}Installing foreman...${NC}"
    gem install foreman
fi

export PORT=3000
export RAILS_ENV=production

# Start all services via Foreman
echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
echo -e "${GREEN}Starting services via Foreman...${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
echo ""

exec foreman start -f Procfile.prod "$@"
```

#### 4. Add PATH Validation (RECOMMENDED)

**Location:** Before database checks

```bash
# Verify required commands
echo -e "${YELLOW}→ Verifying system dependencies...${NC}"

if ! command -v psql >/dev/null 2>&1; then
    echo -e "${RED}✗ psql command not found${NC}" >&2
    echo -e "${YELLOW}  Try: brew install postgresql@16${NC}" >&2
    exit 1
fi

echo -e "${GREEN}✓ System dependencies verified${NC}"
echo ""
```

#### 5. Fix Database Check (ACCURACY)

**Location:** Line 60

```bash
# FROM:
if PGPASSWORD="${NEXTGEN_PLAID_DATABASE_PASSWORD}" psql -U nextgen_plaid -d postgres -c "SELECT 1;" > /dev/null 2>&1; then

# TO:
if PGPASSWORD="${NEXTGEN_PLAID_DATABASE_PASSWORD}" psql -U nextgen_plaid -d nextgen_plaid_production -c "SELECT 1;" > /dev/null 2>&1; then
```

---

## Complete Updated bin/prod (Foreman Version)

```bash
#!/usr/bin/env bash
#
# Production Launcher for nextgen-plaid
# Purpose: Start application with secrets from macOS Keychain
# Usage: bin/prod
#
# PHASE 1: Uses Foreman for process management (temporary)
# PHASE 2: Will migrate to launchd supervision (future)
#

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Service prefix for keychain
SERVICE_PREFIX="nextgen-plaid"

# Change to app directory
cd "$(dirname "$0")/.."

# Initialize rbenv for correct Ruby version
if [ -f ~/.zprofile ]; then
    source ~/.zprofile
fi
if command -v rbenv >/dev/null 2>&1; then
    eval "$(rbenv init -)"
fi

echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  nextgen-plaid - Production Mode${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
echo ""
echo -e "${BLUE}Ruby Version:${NC} $(ruby -v)"
echo ""

# Verify required system dependencies
echo -e "${YELLOW}→ Verifying system dependencies...${NC}"

if ! command -v psql >/dev/null 2>&1; then
    echo -e "${RED}✗ psql command not found${NC}" >&2
    echo -e "${RED}  Ensure PostgreSQL client is installed${NC}" >&2
    echo -e "${YELLOW}  Try: brew install postgresql@16${NC}" >&2
    exit 1
fi

echo -e "${GREEN}✓ System dependencies verified${NC}"
echo ""

# Function to get secret from Keychain
get_secret() {
    local key=$1
    local service="${SERVICE_PREFIX}-${key}"
    local account="${SERVICE_PREFIX}"
    
    security find-generic-password -a "${account}" -s "${service}" -w 2>/dev/null || {
        echo -e "${RED}✗ Failed to retrieve secret: ${key}${NC}" >&2
        echo -e "${RED}  Run './scripts/setup-keychain.sh' to configure secrets${NC}" >&2
        exit 1
    }
}

# Load secrets from Keychain
echo -e "${YELLOW}→ Loading secrets from Keychain...${NC}"

export RAILS_ENV=production
export NEXTGEN_PLAID_DATABASE_PASSWORD=$(get_secret "DATABASE_PASSWORD")
export PLAID_CLIENT_ID=$(get_secret "PLAID_CLIENT_ID")
export PLAID_SECRET=$(get_secret "PLAID_SECRET")
export CLAUDE_API_KEY=$(get_secret "CLAUDE_API_KEY")
export RAILS_MASTER_KEY=$(get_secret "RAILS_MASTER_KEY")

# Optional secrets (don't fail if missing)
export REDIS_PASSWORD=$(security find-generic-password -a "${SERVICE_PREFIX}" -s "${SERVICE_PREFIX}-REDIS_PASSWORD" -w 2>/dev/null || echo "")
export SENTRY_DSN=$(security find-generic-password -a "${SERVICE_PREFIX}" -s "${SERVICE_PREFIX}-SENTRY_DSN" -w 2>/dev/null || echo "")

echo -e "${GREEN}✓ Secrets loaded successfully${NC}"
echo ""

# Verify database connectivity
echo -e "${YELLOW}→ Verifying database connectivity...${NC}"
if PGPASSWORD="${NEXTGEN_PLAID_DATABASE_PASSWORD}" psql -U nextgen_plaid -d nextgen_plaid_production -c "SELECT 1;" > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Database connection verified${NC}"
else
    echo -e "${RED}✗ Database connection failed${NC}"
    echo -e "${RED}  Check PostgreSQL is running and password is correct${NC}"
    exit 1
fi
echo ""

# Check if database exists and is up to date
echo -e "${YELLOW}→ Checking database status...${NC}"
if bin/rails db:version > /dev/null 2>&1; then
    CURRENT_VERSION=$(bin/rails db:version 2>/dev/null | grep "Current version:" | awk '{print $3}')
    echo -e "${GREEN}✓ Database ready (migration version: ${CURRENT_VERSION:-unknown})${NC}"
else
    echo -e "${YELLOW}⚠ Database may need setup or migrations${NC}"
    echo -e "${YELLOW}  Run: RAILS_ENV=production bin/rails db:migrate${NC}"
fi
echo ""

# Display startup info
echo -e "${BLUE}Environment:${NC}"
echo -e "  RAILS_ENV:     ${RAILS_ENV}"
echo -e "  Ruby Version:  $(ruby -v | awk '{print $2}')"
echo -e "  Database:      nextgen_plaid_production"
echo -e "  Queue:         nextgen_plaid_production_queue"
echo -e "  Cable:         nextgen_plaid_production_cable"
echo ""

# Install foreman if needed
if ! gem list foreman -i --silent; then
    echo -e "${YELLOW}Installing foreman gem...${NC}"
    gem install foreman
    echo ""
fi

export PORT=3000

# Start services via Foreman
echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
echo -e "${GREEN}Starting services via Foreman...${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
echo ""

exec foreman start -f Procfile.prod "$@"
```

---

## Procfile.prod

```yaml
# Production Process Definitions
# Phase 1: Foreman-based (temporary)
# Phase 2: Will migrate to individual launchd plists

web: env PORT=3000 bin/rails server -e production -b 0.0.0.0
worker: bin/rails solid_queue:start
```

---

## Testing Plan (Phase 1)

```bash
# 1. Create Procfile.prod
cat > Procfile.prod << 'EOF'
web: env PORT=3000 bin/rails server -e production -b 0.0.0.0
worker: bin/rails solid_queue:start
EOF

# 2. Update bin/prod with Foreman approach

# 3. Test locally
./bin/prod

# Expected output:
# ══════════════════════════════════════════════════════
#   nextgen-plaid - Production Mode
# ══════════════════════════════════════════════════════
# Ruby Version: ruby 3.3.10
# 
# → Verifying system dependencies...
# ✓ System dependencies verified
# 
# → Loading secrets from Keychain...
# ✓ Secrets loaded successfully
# 
# → Verifying database connectivity...
# ✓ Database connection verified
# 
# → Checking database status...
# ✓ Database ready
# 
# Environment:
#   RAILS_ENV:     production
#   Ruby Version:  3.3.10
#   Database:      nextgen_plaid_production
# 
# ══════════════════════════════════════════════════════
# Starting services via Foreman...
# ══════════════════════════════════════════════════════
# 
# 14:23:45 web.1    | started with pid 12345
# 14:23:45 worker.1 | started with pid 12346
# 14:23:46 web.1    | Puma starting in production on http://0.0.0.0:3000
# 14:23:46 worker.1 | SolidQueue starting...

# 4. Verify services running
curl http://localhost:3000/health

# 5. Commit
git add Procfile.prod bin/prod
git commit -m "Phase 1: Add Foreman-based production launcher"
git push origin main

# 6. Deploy to production
bin/deploy-prod
```

---

## Deployment Integration

### Update bin/deploy-prod Phase 7

**Current (doesn't restart properly):**
```bash
# Phase 7: Restart Services
echo -e "${YELLOW}Phase 7: Restarting application...${NC}"
```

**Updated (Foreman-based restart):**
```bash
# Phase 7: Restart Services
echo -e "${YELLOW}Phase 7: Restarting application...${NC}"

# Find and stop existing Foreman process
if pgrep -f "foreman start -f Procfile.prod" > /dev/null; then
    echo "  Stopping existing Foreman process..."
    pkill -TERM -f "foreman start -f Procfile.prod"
    sleep 3
    
    # Force kill if still running
    if pgrep -f "foreman start -f Procfile.prod" > /dev/null; then
        pkill -KILL -f "foreman start -f Procfile.prod"
        sleep 2
    fi
fi

# Start new instance in background
echo "  Starting Foreman..."
nohup bin/prod > log/production-foreman.log 2>&1 &
FOREMAN_PID=$!

# Wait for startup
sleep 5

# Verify services are running
if curl -sf http://localhost:3000/health > /dev/null; then
    echo -e "${GREEN}✓ Application restarted successfully (PID: ${FOREMAN_PID})${NC}"
else
    echo -e "${RED}✗ Application failed to start${NC}"
    tail -20 log/production-foreman.log
    exit 1
fi
```

---

## Phase 2: Migration to launchd (Future)

**When to migrate:**
- ✅ Deployments working reliably for 2+ weeks
- ✅ Team comfortable with current workflow
- ✅ No active production issues

**What changes:**
1. Create `com.agentforge.nextgen-plaid.plist` (web)
2. Create `com.agentforge.nextgen-plaid-worker.plist` (workers)
3. Update `bin/prod` to be single-purpose (web only)
4. Update `bin/deploy-prod` Phase 7 to use `launchctl restart`
5. Remove Foreman dependency

**Benefits of waiting:**
- Lower risk during stabilization period
- One change at a time
- Proven baseline before optimization

---

## Comparison: Phase 1 vs Phase 2

| Aspect | Phase 1 (Foreman) | Phase 2 (launchd) |
|--------|------------------|-------------------|
| **Start command** | `bin/prod` (manual) | `launchctl start` (automatic) |
| **Auto-restart** | No (manual restart) | Yes (KeepAlive) |
| **Boot startup** | No (manual start) | Yes (RunAtLoad) |
| **Process count** | 2 (web + worker) | 2 (separate plists) |
| **Logging** | `log/production-foreman.log` | System logs |
| **Service isolation** | No | Yes |
| **Complexity** | LOW (familiar pattern) | MEDIUM (new pattern) |

---

## Files to Create

### 1. Procfile.prod (New)

```yaml
web: env PORT=3000 bin/rails server -e production -b 0.0.0.0
worker: bin/rails solid_queue:start
```

### 2. bin/prod (Modified)

See complete script above.

### 3. bin/deploy-prod (Update Phase 7)

Add Foreman restart logic.

---

## Rollout Steps

### Step 1: Create Files (5 minutes)

```bash
cd /path/to/nextgen-plaid

# Create Procfile.prod
cat > Procfile.prod << 'EOF'
web: env PORT=3000 bin/rails server -e production -b 0.0.0.0
worker: bin/rails solid_queue:start
EOF

# Update bin/prod (copy from complete script above)

# Commit
git add Procfile.prod bin/prod
git commit -m "Phase 1: Implement Foreman-based production launcher

- Add rbenv initialization for correct Ruby version
- Add PATH validation for better error messages
- Fix database check to use nextgen_plaid_production
- Use Foreman to manage web + worker processes
- Temporary approach until launchd migration (Phase 2)"

git push origin main
```

### Step 2: Deploy to Production (10 minutes)

```bash
# Deploy via script
bin/deploy-prod

# Or manually:
ssh ericsmith66@192.168.4.253
cd ~/Development/nextgen-plaid
git pull origin main
./bin/prod
```

### Step 3: Verify (5 minutes)

```bash
# Check processes
ps aux | grep foreman
ps aux | grep puma
ps aux | grep solid_queue

# Check web server
curl http://localhost:3000/health

# Check logs
tail -f log/production.log
tail -f log/production-foreman.log
```

---

## Advantages of This Approach

### ✅ Immediate Benefits:

1. **Familiar Pattern:** Matches `bin/dev` workflow
2. **Lower Risk:** No new concepts during stabilization
3. **Multi-process:** Web + workers in one command
4. **Faster Iteration:** Easy to test and restart
5. **Development Parity:** Same tool in dev and prod

### ✅ Future Benefits (Phase 2):

1. **Production Grade:** Native OS supervision
2. **Auto-restart:** Crash recovery
3. **Boot Startup:** Automatic on reboot
4. **Better Isolation:** Independent service management
5. **Resource Limits:** Per-service controls

---

## Known Limitations (Phase 1)

**Accept these temporarily:**

1. **No auto-restart on crash:** Must manually restart
2. **No boot startup:** Must manually start after reboot
3. **Single point of failure:** Foreman crash stops everything
4. **Manual management:** No system integration

**Mitigation:**
- Document restart procedures
- Set up monitoring/alerts
- Plan Phase 2 migration after stabilization

---

## Migration Path (Phase 1 → Phase 2)

**Criteria to start Phase 2:**
- [ ] Deployments successful for 2+ weeks
- [ ] No active production issues
- [ ] Team has capacity for migration
- [ ] Monitoring in place

**Migration checklist:**
- [ ] Create launchd plists
- [ ] Update bin/prod (single-purpose)
- [ ] Update bin/deploy-prod (launchctl restart)
- [ ] Test in production
- [ ] Document new service management
- [ ] Remove Foreman dependency (optional)

---

## Summary

### Revised Decision: ✅ Implement Foreman First

**Phase 1 (NOW):**
- ✅ Use Foreman for process management
- ✅ Add rbenv initialization
- ✅ Add PATH validation
- ✅ Fix database check
- ✅ Create Procfile.prod

**Phase 2 (LATER):**
- ⏳ Migrate to launchd supervision
- ⏳ Split into separate service plists
- ⏳ Update deployment scripts

**Rationale:**
- Get reliable deployments working FIRST
- Optimize process management LATER
- Reduce complexity during stabilization
- One major change at a time

---

**Status:** ✅ READY TO IMPLEMENT  
**Risk:** LOW (using familiar tool)  
**Timeline:** Phase 1 this week, Phase 2 in 2-4 weeks  
**Approved:** User validated pragmatic approach
