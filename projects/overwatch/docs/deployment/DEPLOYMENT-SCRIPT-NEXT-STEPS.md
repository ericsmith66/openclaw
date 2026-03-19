# Deployment Script Next Steps

**Date:** February 22, 2026  
**Current Status:** Scripts exist on production but have known issues  
**Priority:** Fix and validate before enabling automated deployments

---

## 📊 Current State Assessment

### ✅ What Exists
- **`bin/deploy-prod`** - Exists on production (10,475 bytes)
- **`bin/prod`** - Exists on production (3,831 bytes)
- **`bin/sync-from-prod`** - Exists on production (12,199 bytes)
- **`scripts/backup-database.sh`** - Should exist (needs verification)
- **`scripts/restore-database.sh`** - Should exist (needs verification)
- **`scripts/setup-keychain.sh`** - Should exist (needs verification)
- **`.github/workflows/deploy.yml`** - Should exist in repo (needs verification)

### ⚠️ Known Issues from Production Report

1. **Secret Management Mismatch**
   - Scripts expect: macOS Keychain
   - Production uses: `.env` and `.env.production` files
   - Impact: `bin/prod` cannot start the app (expects Keychain secrets)

2. **PostgreSQL Path Issues**
   - Scripts use: `/opt/homebrew/bin/psql`
   - Actual path: `/opt/homebrew/Cellar/postgresql@16/16.11_1/bin/psql`
   - Impact: Database commands may fail

3. **rbenv Initialization**
   - SSH sessions don't have rbenv in PATH by default
   - Scripts need: `source ~/.zprofile && eval "$(rbenv init -)"`
   - Impact: May use system Ruby instead of rbenv Ruby

4. **No SSH Deploy Keys**
   - Production cannot `git pull` from origin
   - Current: Must push changes manually or use local commits
   - Impact: `bin/deploy-prod` step 3 (code update) fails

5. **No launchd Service**
   - Scripts reference: `com.agentforge.nextgen-plaid` service
   - Reality: No launchd plist installed
   - Impact: Cannot auto-start/restart via launchd

6. **Health Endpoint Authentication**
   - Scripts expect: Public `/health` endpoint
   - Reality: Only `/admin/health` exists (requires auth)
   - Impact: Health checks return 401, deployment verification fails

---

## 🎯 Next Steps (Prioritized)

### Phase 1: Critical Fixes (Required for basic deployment)

#### 1.1 Fix PostgreSQL Paths ⚠️ HIGH PRIORITY
**Issue:** Scripts hardcode `/opt/homebrew/bin/psql` but actual path is in Cellar

**Solution A: Use Homebrew symlinks (RECOMMENDED)**
```bash
# Check if symlinks exist
ls -la /opt/homebrew/bin/psql
ls -la /opt/homebrew/bin/pg_dump

# If not, create them
ln -s /opt/homebrew/Cellar/postgresql@16/16.11_1/bin/psql /opt/homebrew/bin/psql
ln -s /opt/homebrew/Cellar/postgresql@16/16.11_1/bin/pg_dump /opt/homebrew/bin/pg_dump
ln -s /opt/homebrew/Cellar/postgresql@16/16.11_1/bin/pg_restore /opt/homebrew/bin/pg_restore
```

**Solution B: Update scripts to detect PostgreSQL path**
```bash
# Add to scripts:
if [ -d "/opt/homebrew/Cellar/postgresql@16" ]; then
  PG_BIN="/opt/homebrew/Cellar/postgresql@16/16.11_1/bin"
else
  PG_BIN="/opt/homebrew/bin"
fi
```

**Action:**
- [ ] Create symlinks on production server
- [ ] Test `bin/deploy-prod --dry-run`
- [ ] Verify database backup/restore scripts work

---

#### 1.2 Resolve Secrets Management ⚠️ HIGH PRIORITY
**Issue:** Scripts expect Keychain, production uses `.env` files

**DECISION MADE: Move to Keychain** ✅

**Rationale:**
- More secure (no secrets on disk)
- Matches script expectations
- Industry best practice for macOS deployments
- No .env files to accidentally commit

**Implementation:**
```bash
# On production server
ssh ericsmith66@192.168.4.253
cd ~/Development/nextgen-plaid

# Verify setup script exists
ls -la scripts/setup-keychain.sh

# Run setup script
bash scripts/setup-keychain.sh

# Script will prompt for each secret:
# - DATABASE_PASSWORD
# - PLAID_CLIENT_ID
# - PLAID_SECRET
# - CLAUDE_API_KEY
# - RAILS_MASTER_KEY
# (copy values from current .env.production)

# Verify secrets stored correctly
security find-generic-password -a 'nextgen-plaid' -s 'nextgen-plaid-DATABASE_PASSWORD' -w
security find-generic-password -a 'nextgen-plaid' -s 'nextgen-plaid-PLAID_CLIENT_ID' -w
security find-generic-password -a 'nextgen-plaid' -s 'nextgen-plaid-PLAID_SECRET' -w
security find-generic-password -a 'nextgen-plaid' -s 'nextgen-plaid-CLAUDE_API_KEY' -w
security find-generic-password -a 'nextgen-plaid' -s 'nextgen-plaid-RAILS_MASTER_KEY' -w

# Test bin/prod can start the application
bin/prod

# Once confirmed working, backup and remove .env files
cp .env .env.backup
cp .env.production .env.production.backup
rm .env .env.production
```

**Action:**
- [ ] Run `scripts/setup-keychain.sh` on production
- [ ] Verify all secrets stored correctly
- [ ] Test `bin/prod` can start the application
- [ ] Backup and remove .env files
- [ ] Update documentation to reflect Keychain approach

---

#### 1.3 Fix rbenv Initialization ⚠️ MEDIUM PRIORITY
**Issue:** SSH sessions don't have rbenv in PATH

**Solution:** Update scripts to initialize rbenv at the start

**Template for all scripts:**
```bash
#!/usr/bin/env bash
set -euo pipefail

# Initialize rbenv for non-interactive shells
if [ -d "$HOME/.rbenv" ]; then
  export PATH="$HOME/.rbenv/shims:$PATH"
  eval "$(rbenv init - --no-rehash)"
fi

# Rest of script...
```

**Action:**
- [ ] Update `bin/deploy-prod` with rbenv initialization
- [ ] Update `bin/prod` with rbenv initialization
- [ ] Update `bin/sync-from-prod` with rbenv initialization
- [ ] Test scripts work via SSH (non-interactive)

---

### Phase 2: Infrastructure Setup (Required for automation)

#### 2.1 Setup SSH Deploy Keys ⚠️ MEDIUM PRIORITY → ✅ ALREADY DONE!
**Issue:** Production cannot pull from GitHub

**STATUS:** SSH key already exists! ✅

**Verification:**
```bash
ssh ericsmith66@192.168.4.253
ls -la ~/.ssh/ | grep github

# Output shows:
# github_deploy_nextgen_plaid (private key)
# github_deploy_nextgen_plaid.pub (public key)
```

**Remaining Actions:**
```bash
# Configure git to use the existing deploy key
ssh ericsmith66@192.168.4.253
cd ~/Development/nextgen-plaid
git config core.sshCommand "ssh -i ~/.ssh/github_deploy_nextgen_plaid"

# Test connection
ssh -T git@github.com -i ~/.ssh/github_deploy_nextgen_plaid

# Test pull
git pull origin main
```

**Action:**
- [x] SSH deploy key already exists ✅
- [x] Public key already added to GitHub ✅
- [ ] Configure git to use deploy key
- [ ] Test `git pull origin main` works
- [ ] Verify `bin/deploy-prod` uses correct key path

---

#### 2.2 Create Public Health Endpoint with Token Auth ⚠️ MEDIUM PRIORITY
**Issue:** Only `/admin/health` exists (requires user authentication)

**DECISION MADE: Add token-based authentication** ✅

**Rationale:**
- Public health endpoint poses security risk
- Token auth allows automation while maintaining security
- Deployment scripts can use token without user session

**Implementation (Development Ticket Required):**

This needs to be implemented by the dev team:

1. **Add Health Token to Secrets**
   ```bash
   # Generate secure token
   HEALTH_TOKEN=$(openssl rand -hex 32)
   
   # Add to .env files
   echo "HEALTH_CHECK_TOKEN=${HEALTH_TOKEN}" >> .env
   echo "HEALTH_CHECK_TOKEN=${HEALTH_TOKEN}" >> .env.production
   
   # Add to Keychain (production)
   security add-generic-password -a 'nextgen-plaid' \
     -s 'nextgen-plaid-HEALTH_CHECK_TOKEN' \
     -w "${HEALTH_TOKEN}"
   ```

2. **Create Token-Authenticated Health Controller**
   ```ruby
   # app/controllers/health_controller.rb
   class HealthController < ApplicationController
     skip_before_action :authenticate_user!
     before_action :verify_health_token
     
     def index
       render json: { 
         status: 'ok', 
         timestamp: Time.current.iso8601,
         version: ENV['GIT_COMMIT']&.first(7) || 'unknown',
         environment: Rails.env
       }
     end
     
     private
     
     def verify_health_token
       expected_token = ENV['HEALTH_CHECK_TOKEN']
       provided_token = request.headers['X-Health-Token'] || params[:token]
       
       unless ActiveSupport::SecurityUtils.secure_compare(
         expected_token.to_s,
         provided_token.to_s
       )
         render json: { error: 'Unauthorized' }, status: :unauthorized
       end
     end
   end
   ```

3. **Add Route**
   ```ruby
   # config/routes.rb
   get '/health', to: 'health#index'
   ```

4. **Usage in Deployment Scripts**
   ```bash
   # Read token from Keychain
   HEALTH_TOKEN=$(security find-generic-password -a 'nextgen-plaid' \
     -s 'nextgen-plaid-HEALTH_CHECK_TOKEN' -w)
   
   # Make health check with token
   curl -H "X-Health-Token: ${HEALTH_TOKEN}" http://localhost:3000/health
   
   # Or via query parameter
   curl "http://localhost:3000/health?token=${HEALTH_TOKEN}"
   ```

**Development Ticket:**
- [ ] Create ticket: "Implement token-authenticated /health endpoint"
- [ ] Include security requirements (timing-safe comparison)
- [ ] Include token generation script
- [ ] Include usage examples for deployment scripts

**Deployment Script Updates (After Dev Ticket Complete):**
- [ ] Update `bin/deploy-prod` to use token-authenticated `/health`
- [ ] Update `bin/prod` to include HEALTH_CHECK_TOKEN from Keychain
- [ ] Update health check examples in documentation
- [ ] Test health check with valid and invalid tokens

---

#### 2.3 Install launchd Service ⚠️ MEDIUM PRIORITY → REQUIRED
**Issue:** No auto-start/restart capability

**DECISION MADE: Required for production stability** ✅

**Current:** Server is manually started with `nohup bundle exec rails server`  
**Desired:** Auto-start on boot, auto-restart on crash, managed process lifecycle

**Research Summary:**

Based on launchd best practices and existing services on the production server:

**Key Points:**
- launchd is macOS's service manager (like systemd on Linux)
- User Agents run in `~/Library/LaunchAgents` (run as user when logged in)
- System Daemons run in `/Library/LaunchDaemons` (run as root at boot)
- For web apps run as user, User Agents are correct approach
- PostgreSQL and Redis already use this pattern successfully

**Working Example from Production:**
PostgreSQL runs as User Agent with these key settings:
- `KeepAlive: true` - auto-restart on crash
- `RunAtLoad: true` - start on login
- `LimitLoadToSessionType` - runs in multiple session types
- Logs to `/opt/homebrew/var/log/`

**Implementation for nextgen-plaid:**

```bash
# On production server
ssh ericsmith66@192.168.4.253

# Create launchd plist
cat > ~/Library/LaunchAgents/com.agentforge.nextgen-plaid.plist << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>com.agentforge.nextgen-plaid</string>
  
  <key>ProgramArguments</key>
  <array>
    <string>/Users/ericsmith66/Development/nextgen-plaid/bin/prod</string>
  </array>
  
  <key>WorkingDirectory</key>
  <string>/Users/ericsmith66/Development/nextgen-plaid</string>
  
  <key>EnvironmentVariables</key>
  <dict>
    <key>PATH</key>
    <string>/Users/ericsmith66/.rbenv/shims:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin</string>
    <key>RAILS_ENV</key>
    <string>production</string>
  </dict>
  
  <key>RunAtLoad</key>
  <true/>
  
  <key>KeepAlive</key>
  <true/>
  
  <key>ThrottleInterval</key>
  <integer>30</integer>
  
  <key>StandardOutPath</key>
  <string>/Users/ericsmith66/Development/nextgen-plaid/log/launchd.stdout.log</string>
  
  <key>StandardErrorPath</key>
  <string>/Users/ericsmith66/Development/nextgen-plaid/log/launchd.stderr.log</string>
  
  <key>LimitLoadToSessionType</key>
  <array>
    <string>Aqua</string>
    <string>Background</string>
    <string>LoginWindow</string>
    <string>StandardIO</string>
  </array>
</dict>
</plist>
EOF

# Load service
launchctl load ~/Library/LaunchAgents/com.agentforge.nextgen-plaid.plist

# Verify it's loaded
launchctl list | grep nextgen-plaid

# Check logs
tail -f ~/Development/nextgen-plaid/log/launchd.stdout.log
tail -f ~/Development/nextgen-plaid/log/launchd.stderr.log
```

**Key Configuration Explained:**

- **Label:** Unique identifier (reverse domain notation)
- **ProgramArguments:** Path to `bin/prod` (which loads Keychain secrets)
- **WorkingDirectory:** Rails app root
- **EnvironmentVariables:** 
  - PATH with rbenv shims first
  - RAILS_ENV=production
- **RunAtLoad:** Start immediately when plist loads
- **KeepAlive:** Auto-restart if process dies
- **ThrottleInterval:** Wait 30 seconds between restart attempts (prevents rapid restart loops)
- **StandardOutPath/StandardErrorPath:** Capture all output to log files
- **LimitLoadToSessionType:** Run in Aqua (GUI), Background, LoginWindow, StandardIO sessions

**Testing the Service:**

```bash
# Check service status
launchctl list | grep nextgen-plaid
# Shows: PID STATUS LABEL

# View logs
tail -f ~/Development/nextgen-plaid/log/launchd.stdout.log

# Test auto-restart (kill process)
kill -9 <PID>
# Wait 30 seconds, check if it restarted
launchctl list | grep nextgen-plaid

# Manually stop (will not auto-restart until reload)
launchctl stop com.agentforge.nextgen-plaid

# Manually start
launchctl start com.agentforge.nextgen-plaid

# Unload (disable service)
launchctl unload ~/Library/LaunchAgents/com.agentforge.nextgen-plaid.plist

# Reload (after making changes)
launchctl unload ~/Library/LaunchAgents/com.agentforge.nextgen-plaid.plist
launchctl load ~/Library/LaunchAgents/com.agentforge.nextgen-plaid.plist
```

**Deployment Script Integration:**

Update `bin/deploy-prod` Phase 7 to use launchctl:

```bash
# Instead of: nohup bundle exec rails server...
# Use:
launchctl kickstart -k gui/$(id -u)/com.agentforge.nextgen-plaid

# -k flag kills existing process before starting new one
# gui/$(id -u) is the user domain
```

**Prerequisites:**
- [x] PostgreSQL already has working launchd service as reference ✅
- [ ] Phase 1.2 complete (Keychain secrets working)
- [ ] `bin/prod` tested and working
- [ ] Verify rbenv available in PATH

**Action Items:**
- [ ] Create launchd plist file
- [ ] Load service with launchctl
- [ ] Verify service starts successfully
- [ ] Test auto-restart (kill process)
- [ ] Update `bin/deploy-prod` to use launchctl restart
- [ ] Document service management commands in RUNBOOK.md
- [ ] Add launchd troubleshooting section to docs

---

### Phase 3: Validation & Testing (Before production use)

#### 3.1 Test Database Sync Script ✅ ALREADY TESTED
**Status:** `bin/sync-from-prod` works (tested earlier today)

**Action:**
- [x] Dry-run test complete
- [ ] Document any issues found
- [ ] Add to runbook

---

#### 3.2 Test Backup/Restore Scripts ⏳ PENDING
**Status:** Scripts exist but not tested

**Test Plan:**
```bash
# On production server
ssh ericsmith66@192.168.4.253
cd ~/Development/nextgen-plaid

# Test backup
bash scripts/backup-database.sh
ls -lh ~/backups/nextgen-plaid/

# Test restore (list backups)
bash scripts/restore-database.sh --list

# Test restore (restore to test database)
# Create test database first
/opt/homebrew/Cellar/postgresql@16/16.11_1/bin/createdb -U nextgen_plaid nextgen_plaid_test
bash scripts/restore-database.sh TIMESTAMP_HERE --database nextgen_plaid_test

# Verify data
/opt/homebrew/Cellar/postgresql@16/16.11_1/bin/psql -U nextgen_plaid -d nextgen_plaid_test -c "SELECT COUNT(*) FROM users;"
```

**Action:**
- [ ] Test backup script creates valid backups
- [ ] Test restore script can list backups
- [ ] Test restore script can restore data
- [ ] Verify restored data is complete
- [ ] Test 30-day retention cleanup works

---

#### 3.3 Test Deployment Script (End-to-End) ⏳ CRITICAL
**Status:** NOT TESTED - needs all Phase 1 & 2 fixes first

**Prerequisites:**
- [x] PostgreSQL paths fixed
- [ ] Secrets management resolved
- [ ] rbenv initialization added
- [ ] SSH deploy keys configured
- [ ] Public health endpoint created

**Test Plan:**
```bash
# On development machine
cd ~/development/agent-forge/projects/nextgen-plaid

# Make a trivial change
echo "# Test deployment" >> README.md
git add README.md
git commit -m "Test: Verify deployment script"
git push origin main

# Run deployment (dry-run first)
bin/deploy-prod --dry-run

# Review output, then run for real
bin/deploy-prod

# Expected output:
# ✓ Phase 1: Pre-flight checks
# ✓ Phase 2: Database backup
# ✓ Phase 3: Code update (git pull)
# ✓ Phase 4: Dependencies (bundle install)
# ✓ Phase 5: Migrations (rails db:migrate)
# ✓ Phase 6: Assets (rails assets:precompile)
# ✓ Phase 7: Restart (service restart + health check)
```

**Success Criteria:**
- All 7 phases complete without errors
- Health check returns 200 OK
- Application serves requests after deployment
- Rollback capability verified

**Action:**
- [ ] Complete all Phase 1 & 2 prerequisites
- [ ] Run dry-run test
- [ ] Fix any errors found
- [ ] Run actual deployment
- [ ] Test rollback procedure
- [ ] Document any issues

---

#### 3.4 Test GitHub Actions Workflow ⏳ PENDING
**Status:** Workflow file should exist but never tested

**Prerequisites:**
- [ ] `bin/deploy-prod` working end-to-end
- [ ] GitHub secrets configured (PROD_DEPLOY_KEY, PROD_HOST, PROD_USER)

**Test Plan:**
```bash
# Verify workflow file exists
cat .github/workflows/deploy.yml

# Check GitHub secrets are configured
# Go to: GitHub → Settings → Secrets and variables → Actions
# Verify: PROD_DEPLOY_KEY, PROD_HOST, PROD_USER exist

# Trigger workflow
# Go to: GitHub → Actions → Deploy to Production → Run workflow
# Select options and run

# Monitor deployment
# Watch logs in GitHub Actions UI
```

**Action:**
- [ ] Verify workflow file exists and is valid
- [ ] Configure GitHub secrets (if not already done)
- [ ] Test manual trigger from GitHub UI
- [ ] Verify workflow can SSH to production
- [ ] Verify workflow can run deployment script
- [ ] Test rollback if deployment fails

---

### Phase 4: Documentation & Training

#### 4.1 Update Deployment Guide ⏳ PENDING
**Action:**
- [ ] Document actual secrets approach (Keychain vs .env)
- [ ] Update PostgreSQL paths in all examples
- [ ] Document SSH deploy key setup
- [ ] Update health endpoint path
- [ ] Add troubleshooting for common issues
- [ ] Update rollback procedures

**Files to update:**
- `docs/team-guides/NEXTGEN-PLAID-DEPLOYMENT-TEAM-GUIDE.md`
- `docs/operations/PRODUCTION-ISSUES-RESOLUTION.md`
- `docs/deployment/deployment-nextgen-plaid.md`
- `RUNBOOK.md` (in nextgen-plaid repo)

---

#### 4.2 Create Deployment Checklist ⏳ PENDING
**Action:**
- [ ] Create pre-deployment checklist
- [ ] Create deployment execution checklist
- [ ] Create post-deployment verification checklist
- [ ] Create rollback decision tree

---

#### 4.3 Train Team on Deployment Process ⏳ PENDING
**Action:**
- [ ] Schedule training session
- [ ] Walk through deployment process
- [ ] Demonstrate rollback procedure
- [ ] Practice emergency scenarios
- [ ] Document lessons learned

---

## 📋 Implementation Checklist

### Phase 1: Critical Fixes (Week 1)
- [ ] 1.1 Fix PostgreSQL paths
- [ ] 1.2 Resolve secrets management (Keychain or .env)
- [ ] 1.3 Fix rbenv initialization

### Phase 2: Infrastructure Setup (Week 1-2)
- [x] 2.1 Setup SSH deploy keys ✅ (Already done!)
- [ ] 2.2 Create health endpoint with token auth (Dev ticket required)
- [ ] 2.3 Install launchd service (Required for production)

### Phase 3: Validation & Testing (Week 2)
- [x] 3.1 Test database sync script ✅
- [ ] 3.2 Test backup/restore scripts
- [ ] 3.3 Test deployment script (end-to-end)
- [ ] 3.4 Test GitHub Actions workflow

### Phase 4: Documentation & Training (Week 2-3)
- [ ] 4.1 Update deployment guide
- [ ] 4.2 Create deployment checklist
- [ ] 4.3 Train team on deployment process

---

## 🚦 Recommended Approach

### Option 1: Quick Fix (1-2 days)
**Goal:** Get basic deployment working

1. Fix PostgreSQL paths (create symlinks)
2. Choose secrets approach and implement
3. Test `bin/deploy-prod` end-to-end
4. Document any workarounds

**Pros:** Fast, minimal changes  
**Cons:** May have rough edges, manual process

---

### Option 2: Complete Solution (1-2 weeks)
**Goal:** Fully automated, production-ready deployment

1. Complete all Phase 1 fixes
2. Complete all Phase 2 infrastructure
3. Complete all Phase 3 testing
4. Complete all Phase 4 documentation

**Pros:** Robust, automated, documented  
**Cons:** Takes longer, more testing needed

---

## 🎯 Immediate Next Actions (Prioritized)

### Action 1: Create PostgreSQL Symlinks (5 minutes) ⚠️ CRITICAL
```bash
ssh ericsmith66@192.168.4.253
sudo ln -s /opt/homebrew/Cellar/postgresql@16/16.11_1/bin/psql /opt/homebrew/bin/psql
sudo ln -s /opt/homebrew/Cellar/postgresql@16/16.11_1/bin/pg_dump /opt/homebrew/bin/pg_dump
sudo ln -s /opt/homebrew/Cellar/postgresql@16/16.11_1/bin/pg_restore /opt/homebrew/bin/pg_restore
```

### Action 2: Setup Keychain Secrets (15 minutes) ⚠️ CRITICAL
```bash
ssh ericsmith66@192.168.4.253
cd ~/Development/nextgen-plaid

# Verify script exists
ls -la scripts/setup-keychain.sh

# Run setup (will prompt for each secret)
bash scripts/setup-keychain.sh

# Copy values from .env.production when prompted

# Verify
security find-generic-password -a 'nextgen-plaid' -s 'nextgen-plaid-DATABASE_PASSWORD' -w
```

### Action 3: Configure Git SSH Key (2 minutes) ⚠️ HIGH
```bash
ssh ericsmith66@192.168.4.253
cd ~/Development/nextgen-plaid

# Configure git to use existing deploy key
git config core.sshCommand "ssh -i ~/.ssh/github_deploy_nextgen_plaid"

# Test
git pull origin main
```

### Action 4: Fix rbenv in Scripts (10 minutes) 🔧 MEDIUM
Update `bin/deploy-prod`, `bin/prod`, and `bin/sync-from-prod` to initialize rbenv

### Action 5: Test bin/prod (5 minutes) ✅ VALIDATION
```bash
ssh ericsmith66@192.168.4.253
cd ~/Development/nextgen-plaid

# Kill existing manual process
kill $(cat tmp/pids/server.pid 2>/dev/null)

# Test bin/prod
bin/prod

# Verify it starts successfully
# Press Ctrl-C to stop

# If successful, proceed to launchd
```

### Action 6: Install launchd Service (15 minutes) 🚀 PRODUCTION READY
After bin/prod works, create and load launchd plist (see section 2.3 for full instructions)

### Action 7: Create Dev Ticket for Health Endpoint (5 minutes) 📝 DEV TEAM
Create ticket for token-authenticated `/health` endpoint (see section 2.2 for requirements)

### Action 8: Test Deployment Script (30 minutes) 🎯 END-TO-END
After all above complete:
```bash
bin/deploy-prod --dry-run
# Fix any errors
bin/deploy-prod
```

---

## ✅ Decisions Made

1. **Secrets Management:** ✅ **Use macOS Keychain** (more secure, matches script expectations)

2. **SSH Deploy Keys:** ✅ **Already configured!** Key exists at `~/.ssh/github_deploy_nextgen_plaid`

3. **Health Endpoint:** ✅ **Token-based authentication** (Dev ticket required)

4. **launchd Service:** ✅ **Required for production** (auto-start/restart capability)

## 📞 Questions Still to Answer

1. **Deployment Frequency:** How often will you deploy? (Daily, weekly, monthly?)

2. **Automation Priority:** Do you need GitHub Actions automation, or is manual deployment sufficient?

3. **Rollback Requirements:** What's your RTO (Recovery Time Objective) for rollbacks?

---

## 📚 Related Documentation

- **Current Status:** `docs/operations/PRODUCTION-STATUS-FINAL.md`
- **Team Guide:** `docs/team-guides/NEXTGEN-PLAID-DEPLOYMENT-TEAM-GUIDE.md`
- **Issues Report:** `docs/operations/PRODUCTION-ISSUES-RESOLUTION.md`
- **Emergency Procedures:** `docs/operations/EMERGENCY-DB-COPY-DEV-TO-PROD.md`

---

**Document Created:** February 22, 2026  
**Last Updated:** February 22, 2026  
**Next Review:** After Phase 1 completion
