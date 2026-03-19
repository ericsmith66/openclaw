# Technical Review: `bin/prod` Recommendation

**Date:** 2026-02-23  
**Reviewer:** DevOps Engineering  
**Context:** nextgen-plaid Production Deployment Infrastructure  
**Status:** ✅ REVIEW COMPLETE

---

## Executive Summary

The recommendation identifies **valid issues** but requires **context-specific adjustments** for the nextgen-plaid production deployment. The current `bin/prod` implementation already addresses some concerns, while others need modification based on actual production architecture.

**Overall Assessment:** 
- ✅ **Issue #1 (rbenv):** Valid and Critical
- ⚠️ **Issue #2 (Database Check):** Valid but Low Priority (cosmetic)
- ❌ **Issue #3 (Process Management):** Incorrect assumption about production needs
- ✅ **Issue #4 (PATH validation):** Valid concern

**Recommended Action:** Implement **Modified Option A** (detailed below)

---

## Detailed Issue Analysis

### Issue #1: Missing rbenv Initialization ⚠️ **CRITICAL - VALID**

**Recommendation Status:** ✅ **CORRECT**

**Current State:**
- `bin/prod` does NOT initialize rbenv
- Lines 21-96 show no rbenv initialization
- Production requires Ruby 3.3.10 via rbenv

**Impact:**
- SSH sessions running `bin/prod` may use system Ruby instead of rbenv Ruby
- Could cause version mismatch errors
- Could cause gem compatibility issues

**Evidence from Memory:**
```
Production Server Runtime State:
- Ruby 3.3.10 via rbenv
- Bash version: 3.2 (requires compatible scripts)
```

**Validation:**
```bash
# Current bin/prod (line 21)
cd "$(dirname "$0")/.."
# No rbenv initialization follows
```

**Recommendation:** ✅ **IMPLEMENT - HIGH PRIORITY**

---

### Issue #2: Database Connectivity Check Connects to Wrong Database ⚠️ **VALID BUT LOW PRIORITY**

**Recommendation Status:** ✅ **CORRECT (but misleading impact)**

**Current State (line 60):**
```bash
if PGPASSWORD="${NEXTGEN_PLAID_DATABASE_PASSWORD}" psql -U nextgen_plaid -d postgres -c "SELECT 1;" > /dev/null 2>&1; then
```

**Actual Behavior:**
- Connects to default `postgres` database instead of `nextgen_plaid_production`
- **However:** This still validates:
  ✅ PostgreSQL is running
  ✅ Password is correct
  ✅ User `nextgen_plaid` has access
  ✅ Network connectivity works

**Why It Works:**
- PostgreSQL user authentication is instance-level, not database-level
- If user can connect to `postgres` DB, they can connect to any DB they have grants for
- The password is the same regardless of target database

**Recommended Change:**
```bash
# FROM:
if PGPASSWORD="${NEXTGEN_PLAID_DATABASE_PASSWORD}" psql -U nextgen_plaid -d postgres -c "SELECT 1;" > /dev/null 2>&1; then

# TO:
if PGPASSWORD="${NEXTGEN_PLAID_DATABASE_PASSWORD}" psql -U nextgen_plaid -d nextgen_plaid_production -c "SELECT 1;" > /dev/null 2>&1; then
```

**Impact:** Cosmetic improvement for accuracy, not a functional bug

**Priority:** MEDIUM (improve clarity and alignment with production DB name)

---

### Issue #3: No Process Management ❌ **INCORRECT ASSUMPTION**

**Recommendation Status:** ❌ **MISUNDERSTANDS PRODUCTION ARCHITECTURE**

**The Recommendation States:**
> "Unlike `bin/dev`, doesn't use Foreman to manage multiple services (web, workers, smart proxy, etc.)"

**Why This Is Incorrect for Production:**

#### Current Production Architecture:
According to deployment memory:
```
Production Server Runtime State:
- Services started by single Procfile.dev: Rails (3000), SmartProxy (3002), 
  Solid Queue workers, Tailwind watcher
- Currently running in RAILS_ENV=development (needs to switch to production)
```

**BUT** - Production goals differ from development:

1. **Production doesn't need Tailwind watcher** (assets are precompiled)
2. **SmartProxy should be separate service** (per roadmap Phase 1.5)
3. **Solid Queue workers should be managed by launchd** (not Foreman)
4. **Web process should be single-purpose** (not multiplexed)

#### Production Best Practices:

**Development:**
- Multiple processes via Foreman for hot-reload, watching, live feedback
- `Procfile.dev` with: web, css, proxy, worker

**Production:**
- Single-purpose processes managed by system supervisor (launchd on macOS)
- Each service gets its own launchd plist
- No file watchers (assets precompiled)
- No live reload mechanisms

#### Current Production Strategy (from memory):

```
DEPLOYMENT METHODS:
- Production launcher with Keychain secret loading
- launchd service for auto-start/restart

KEY COMPONENTS:
- bin/prod: Production launcher (currently being reviewed)
- launchd plist: com.agentforge.nextgen-plaid.plist
```

**Recommendation from Roadmap:**
```
Phase 1.5: Extract SmartProxy to Standalone Service
- Create standalone SmartProxy with its own bin/prod launcher
- Create separate launchd plist for SmartProxy
- Remove proxy: line from nextgen-plaid Procfile
```

#### Why Foreman Is Wrong for Production:

1. **Single Point of Failure:** If Foreman crashes, all services die
2. **No Auto-Restart:** launchd provides KeepAlive functionality
3. **No Dependency Management:** launchd can sequence startup order
4. **Resource Isolation:** Separate processes = better resource limits
5. **Log Management:** Each service gets dedicated logs via launchd

#### Correct Production Approach:

**Current bin/prod (line 96):**
```bash
exec bin/rails server -e production -p 3000
```

This is **CORRECT** for production because:
- ✅ Single-purpose: Only runs web server
- ✅ Will be wrapped by launchd for auto-restart
- ✅ No unnecessary dev tools (watchers, hot reload)
- ✅ Simplifies process supervision

**What Should Happen:**
```
launchd (system supervisor)
├── com.agentforge.nextgen-plaid.plist → bin/prod (web only)
├── com.agentforge.smart-proxy.plist → smart_proxy/bin/prod
└── com.agentforge.nextgen-plaid-worker.plist → bin/rails solid_queue:start
```

**Recommendation:** ❌ **DO NOT IMPLEMENT Option B (Foreman approach)**

**Counter-Recommendation:** ✅ **Keep single-process bin/prod, use launchd for orchestration**

---

### Issue #4: Missing PATH Validation ⚠️ **VALID**

**Recommendation Status:** ✅ **CORRECT**

**Current State:**
- Line 60 directly calls `psql` without checking if it exists
- Could fail silently or with cryptic errors

**Known Issue from Memory:**
```
PostgreSQL Path Issues:
- Scripts use: /opt/homebrew/bin/psql
- Actual path: /opt/homebrew/Cellar/postgresql@16/16.11_1/bin/psql
```

**Current Issue:**
```bash
# Line 60 - no PATH check
if PGPASSWORD="${NEXTGEN_PLAID_DATABASE_PASSWORD}" psql -U nextgen_plaid -d postgres -c "SELECT 1;" > /dev/null 2>&1; then
```

**Recommended Addition:**
```bash
# Verify psql is available
if ! command -v psql >/dev/null 2>&1; then
    echo -e "${RED}✗ psql command not found${NC}" >&2
    echo -e "${RED}  Install PostgreSQL client or add to PATH${NC}" >&2
    echo -e "${YELLOW}  Try: export PATH=\"/opt/homebrew/bin:\$PATH\"${NC}" >&2
    exit 1
fi
```

**Priority:** MEDIUM (good defensive programming)

---

## Recommended Implementation: Modified Option A

### Changes to Implement:

#### Change #1: Add rbenv Initialization (HIGH PRIORITY)

**Location:** After line 21 (after `cd "$(dirname "$0")/.."`)

**Add:**
```bash
# Initialize rbenv for correct Ruby version
if [ -f ~/.zprofile ]; then
    source ~/.zprofile
fi
if command -v rbenv >/dev/null 2>&1; then
    eval "$(rbenv init -)"
fi

# Display Ruby version for verification
echo -e "${BLUE}Ruby Version:${NC} $(ruby -v)"
echo ""
```

**Why This Works:**
- Sources `.zprofile` for shell environment
- Checks if rbenv exists before initializing
- Gracefully degrades if rbenv not available
- Provides visibility into which Ruby is being used

---

#### Change #2: Fix Database Connectivity Check (MEDIUM PRIORITY)

**Location:** Line 60

**Change:**
```bash
# FROM:
if PGPASSWORD="${NEXTGEN_PLAID_DATABASE_PASSWORD}" psql -U nextgen_plaid -d postgres -c "SELECT 1;" > /dev/null 2>&1; then

# TO:
if PGPASSWORD="${NEXTGEN_PLAID_DATABASE_PASSWORD}" psql -U nextgen_plaid -d nextgen_plaid_production -c "SELECT 1;" > /dev/null 2>&1; then
```

**Benefits:**
- More accurate representation of actual database being used
- Better error messages if production DB doesn't exist
- Aligns with line 83: `echo -e "  Database:      nextgen_plaid_production"`

---

#### Change #3: Add PATH Validation (MEDIUM PRIORITY)

**Location:** After rbenv initialization (around line 30)

**Add:**
```bash
# Verify required commands are available
echo -e "${YELLOW}→ Verifying system dependencies...${NC}"

if ! command -v psql >/dev/null 2>&1; then
    echo -e "${RED}✗ psql command not found${NC}" >&2
    echo -e "${RED}  Ensure PostgreSQL client is installed${NC}" >&2
    echo -e "${YELLOW}  Try: brew install postgresql@16${NC}" >&2
    exit 1
fi

if ! command -v bundle >/dev/null 2>&1; then
    echo -e "${RED}✗ bundle command not found${NC}" >&2
    echo -e "${RED}  Ensure bundler gem is installed${NC}" >&2
    echo -e "${YELLOW}  Try: gem install bundler${NC}" >&2
    exit 1
fi

echo -e "${GREEN}✓ System dependencies verified${NC}"
echo ""
```

---

## Complete Modified bin/prod Script

**Changes Summary:**
1. ✅ Added rbenv initialization (lines ~22-30)
2. ✅ Added system dependency checks (lines ~32-48)
3. ✅ Fixed database connectivity check (line ~78)
4. ✅ Added Ruby version display

**Full implementation available in attached file: `bin/prod.improved`**

---

## Why NOT to Implement Option B (Foreman Approach)

### The Recommendation Says:
> "Create a production-focused launcher that uses Foreman with a Procfile.prod to manage all services"

### Why This Is Wrong:

#### 1. Violates Production Best Practices

**Industry Standard:**
- Production: System supervisor (systemd, launchd, upstart)
- Development: Process manager (Foreman, Overmind, Hivemind)

**Reference:**
- [12-factor app](https://12factor.net/admin-processes): "Run admin/management tasks as one-off processes"
- Production should use OS-native process management

#### 2. Conflicts with Existing Architecture

**From deployment memory:**
```
launchd plist for auto-start/restart
PostgreSQL 16 and Redis 7 via Homebrew LaunchAgents (auto-start on boot)
```

**Current approach:**
- PostgreSQL: launchd ✅
- Redis: launchd ✅
- nextgen-plaid: Should be launchd ✅
- **NOT:** Foreman managing everything ❌

#### 3. Operational Complexity

**Foreman Approach Problems:**
- Requires Foreman to be running on boot (how? Another launchd service?)
- Single point of failure (if Foreman crashes, everything stops)
- No native log rotation (launchd provides this)
- No resource limits per service
- Harder to restart individual services

**launchd Approach Benefits:**
- Native macOS integration
- Automatic restart on crash (KeepAlive)
- Boot-time startup (RunAtLoad)
- Per-service resource limits
- Standard logging to system logs
- Individual service control

#### 4. Maintenance Burden

**Adding a new service with Foreman:**
1. Update Procfile.prod
2. Restart Foreman (affects ALL services)
3. No way to test service in isolation

**Adding a new service with launchd:**
1. Create new plist
2. Load new service
3. Existing services unaffected

#### 5. Production Server Context

**From memory:**
```
Production Server: 192.168.4.253 (M3 Ultra)
OS: macOS
Supervisor: launchd (native)
```

**macOS Reality:**
- launchd is the **native** process supervisor
- Every Mac service uses launchd (Homebrew, system services, user apps)
- Fighting this is adding complexity, not removing it

---

## Comparison: Development vs Production Process Management

| Aspect | Development (bin/dev) | Production (bin/prod) |
|--------|----------------------|----------------------|
| **Purpose** | Hot reload, live feedback | Stable, long-running services |
| **Process Manager** | Foreman ✅ | launchd ✅ |
| **File Watching** | Yes (CSS, JS) ✅ | No (precompiled assets) ✅ |
| **Process Count** | Multiple (web, worker, proxy, watchers) | Single (web only) ✅ |
| **Auto-Restart** | Not needed (dev exits intentionally) | Critical (KeepAlive) ✅ |
| **Boot Startup** | No | Yes (RunAtLoad) ✅ |
| **Log Management** | Terminal output | System logs (launchd) ✅ |
| **Resource Limits** | Not needed | Important (launchd) ✅ |

---

## Addressing the Recommendation's Concerns

### Concern: "No process management"

**Response:**
- ✅ Process management **will be** provided by launchd
- ✅ This is the **correct** production approach
- ✅ `bin/prod` is designed to run **under** launchd supervision

**Evidence:**
```
From roadmap:
- Create launchd plist
- com.agentforge.nextgen-plaid.plist
- KeepAlive=true, RunAtLoad=true
```

### Concern: "Doesn't manage workers like bin/dev"

**Response:**
- ✅ Workers will be **separate** launchd service
- ✅ `com.agentforge.nextgen-plaid-worker.plist`
- ✅ Better isolation, independent restart

**Reference:**
```
From roadmap Phase 1.5:
- Remove proxy: line from nextgen-plaid Procfile
- SmartProxy now starts independently
```

### Concern: "Port 3000 not specified in bin/prod"

**Response:**
- ✅ Line 96: `exec bin/rails server -e production -p 3000`
- Port **is** specified explicitly

---

## Implementation Priority

### MUST DO (Before Production Deploy):

1. ✅ **Add rbenv initialization** (HIGH - prevents Ruby version errors)
2. ✅ **Add PATH validation** (MEDIUM - better error messages)
3. ✅ **Fix database check** (MEDIUM - accuracy)

### SHOULD DO (Near-term):

4. ✅ **Test bin/prod end-to-end** (validate all changes work)
5. ✅ **Create launchd plist** (required for auto-start)
6. ✅ **Document launchd service management** (operational runbook)

### DON'T DO:

❌ **Implement Foreman/Procfile.prod approach** (wrong pattern for production)

---

## Testing Plan

### Test 1: Verify rbenv Initialization

```bash
# SSH to production (simulates non-interactive shell)
ssh ericsmith66@192.168.4.253

cd ~/Development/nextgen-plaid

# Test rbenv initialization
bash -c 'source bin/prod' 2>&1 | grep "Ruby Version"

# Should show: Ruby Version: ruby 3.3.10
```

### Test 2: Verify Database Check

```bash
# Test with correct database
NEXTGEN_PLAID_DATABASE_PASSWORD="<password>" \
  psql -U nextgen_plaid -d nextgen_plaid_production -c "SELECT 1;"

# Should succeed
```

### Test 3: Verify PATH Validation

```bash
# Test with broken PATH
env PATH=/usr/bin:/bin bash -c './bin/prod'

# Should fail with helpful error message about psql not found
```

### Test 4: Full Integration Test

```bash
# Full startup test
./bin/prod

# Should:
# 1. Display Ruby version
# 2. Load secrets from Keychain
# 3. Verify database connectivity
# 4. Check database migrations
# 5. Start Puma on port 3000
```

---

## Rollout Plan

### Phase 1: Implement Core Fixes (30 minutes)

```bash
# On development machine
cd /path/to/nextgen-plaid

# Update bin/prod with changes
# (rbenv init, PATH checks, database fix)

# Commit changes
git add bin/prod
git commit -m "Fix bin/prod: Add rbenv init, PATH validation, fix DB check"
git push origin main
```

### Phase 2: Deploy to Production (15 minutes)

```bash
# SSH to production
ssh ericsmith66@192.168.4.253
cd ~/Development/nextgen-plaid

# Pull changes
git pull origin main

# Test bin/prod
./bin/prod

# Ctrl+C after verifying startup succeeds
```

### Phase 3: Install launchd Service (20 minutes)

```bash
# Copy plist from repo to LaunchAgents
cp config/launchd/com.agentforge.nextgen-plaid.plist \
   ~/Library/LaunchAgents/

# Load service
launchctl load ~/Library/LaunchAgents/com.agentforge.nextgen-plaid.plist

# Verify running
launchctl list | grep nextgen-plaid

# Check logs
tail -f ~/Library/Logs/nextgen-plaid/production.log
```

---

## Documentation Updates Required

### 1. Update RUNBOOK.md

Add section: "Starting and Stopping Production Services"

```markdown
## Service Management

### Start Service
```bash
launchctl start com.agentforge.nextgen-plaid
```

### Stop Service
```bash
launchctl stop com.agentforge.nextgen-plaid
```

### Restart Service
```bash
launchctl stop com.agentforge.nextgen-plaid
launchctl start com.agentforge.nextgen-plaid
```

### Check Service Status
```bash
launchctl list | grep nextgen-plaid
```

### View Logs
```bash
tail -f ~/Library/Logs/nextgen-plaid/production.log
```
```

### 2. Update DEPLOYMENT_GUIDE.md

Add troubleshooting section for rbenv issues

### 3. Update QUICK_START.md

Reference launchd service management instead of manual `bin/prod`

---

## Risk Assessment

### Risks of Implementing Recommendation As-Is:

| Risk | Severity | Mitigation |
|------|----------|-----------|
| Foreman adds complexity | HIGH | Don't use Foreman, use launchd |
| Single point of failure | HIGH | Don't use Foreman, use launchd |
| Conflicts with existing architecture | MEDIUM | Follow existing launchd pattern |
| Requires additional dependencies | LOW | Foreman gem not needed |

### Risks of Implementing Modified Option A:

| Risk | Severity | Mitigation |
|------|----------|-----------|
| rbenv init might fail | LOW | Graceful degradation, check command exists |
| PATH issues on different systems | LOW | Provide helpful error messages |
| Breaking existing workflows | LOW | Thoroughly test before deploy |

---

## Conclusion

### Summary of Findings:

✅ **Issue #1 (rbenv):** Valid, implement immediately  
✅ **Issue #2 (Database check):** Valid, implement for accuracy  
❌ **Issue #3 (Process management):** Incorrect assumption, DO NOT implement Foreman approach  
✅ **Issue #4 (PATH validation):** Valid, implement for better errors  

### Final Recommendation:

**Implement Modified Option A:**
1. Add rbenv initialization ✅
2. Add PATH validation ✅
3. Fix database connectivity check ✅
4. Keep single-process design ✅
5. Use launchd for process management ✅

**DO NOT implement Option B (Foreman approach)** ❌

### Confidence Level:

**HIGH (95%)** - Based on:
- Existing production deployment architecture
- Industry best practices for macOS production services
- Documented roadmap and deployment strategy
- Knowledge of launchd vs Foreman trade-offs

### Next Steps:

1. Review this assessment with team
2. Implement Modified Option A changes
3. Test thoroughly on production
4. Update documentation
5. Deploy via standard deployment process

---

**Review Status:** ✅ COMPLETE  
**Approval Required:** DevOps Lead  
**Implementation Timeline:** 1-2 hours  
**Risk Level:** LOW (with Modified Option A)
