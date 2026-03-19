# SmartProxy Deployment Mechanisms

**Date:** March 2, 2026  
**Status:** Design Document  
**Related:** `deployment-smartproxy.md`

---

## Overview

This document describes the deployment mechanisms for SmartProxy as a standalone service on 192.168.4.253, comparing with the existing nextgen-plaid deployment infrastructure and proposing deployment strategies.

---

## Current NextGen Plaid Deployment Model

### Architecture

NextGen Plaid uses a **dual-track deployment mechanism**:

#### 1. Manual Deployment (Primary)
**Script:** `bin/deploy-prod`

**Workflow:**
```bash
# From local development machine
cd /Users/ericsmith66/development/agent-forge/projects/nextgen-plaid
bin/deploy-prod
```

**What it does:**
1. **Pre-flight checks**
   - Verifies on main branch
   - Checks for uncommitted changes
   - Tests SSH connectivity
   - Verifies launchd service registered
   - Runs test suite (optional)

2. **Database backup**
   - Runs `scripts/backup-database.sh` on production
   - Creates timestamped backup
   - Stores backup timestamp locally

3. **Code update**
   - SSH to production server
   - `git fetch origin main`
   - `git reset --hard origin/main`
   - Stores previous commit for rollback

4. **Dependencies**
   - `bundle install --without development test`

5. **Database migrations**
   - `RAILS_ENV=production bin/rails db:migrate`

6. **Asset compilation**
   - `RAILS_ENV=production bin/rails assets:precompile`

7. **Service restart**
   - `launchctl kickstart -k gui/$(id -u)/com.agentforge.nextgen-plaid`

8. **Health check**
   - Polls `http://192.168.4.253:3000/health?token=HEALTH_TOKEN`
   - Retries 5 times with 6s delay
   - Reports success/failure

**Connection:** SSH via `ericsmith66@192.168.4.253`

#### 2. GitHub Actions (CI/CD)
**Workflow:** `.github/workflows/deploy.yml`

**Trigger:** Manual (workflow_dispatch)

**What it does:**
- Runs on GitHub-hosted Ubuntu runner
- Checks out code
- Runs tests, Brakeman, RuboCop
- Configures SSH with `PROD_DEPLOY_KEY` secret
- Executes `bin/deploy-prod` on production server via SSH
- Verifies deployment
- Posts summary to GitHub

**Required Secrets:**
- `PROD_DEPLOY_KEY` - SSH private key (ed25519)
- `PROD_HOST` - 192.168.4.253
- `PROD_USER` - ericsmith66

**Advantages:**
- Automated testing before deploy
- Security scanning (Brakeman)
- Code linting (RuboCop)
- Audit trail via GitHub Actions logs
- No local machine dependency

---

## SmartProxy Deployment Options

### Option 1: Manual-Only Deployment (Simplest)

**For initial deployment only** - No ongoing deployment mechanism.

#### Rationale
- SmartProxy is infrastructure (like PostgreSQL or Redis)
- Changes infrequently
- No CI/CD needed for infrastructure
- Manual SSH deployment is sufficient

#### Process
Follow the deployment checklist:
```bash
# One-time setup (from deployment plan)
1. Extract secrets
2. Create deployment package
3. SSH to production
4. Transfer and extract
5. Setup keychain
6. Create configs
7. Install dependencies
8. Create LaunchAgent
9. Start service
```

#### Updates
```bash
# SSH to production
ssh ericsmith66@192.168.4.253
cd /Users/ericsmith66/Development/SmartProxy

# Pull changes
git pull origin main

# Install dependencies
bundle install

# Restart service
launchctl kickstart -k gui/$(id -u)/com.agentforge.smartproxy

# Verify
curl -s http://localhost:3002/health
```

**Advantages:**
- ✅ Simple
- ✅ No additional infrastructure
- ✅ Direct control

**Disadvantages:**
- ❌ Manual process
- ❌ No automated testing
- ❌ No audit trail

---

### Option 2: Script-Based Deployment (Recommended)

Create `bin/deploy-smartproxy` script similar to nextgen-plaid's `bin/deploy-prod`.

#### Script Location
```
/Users/ericsmith66/development/agent-forge/projects/SmartProxy/bin/deploy-smartproxy
```

#### Script Responsibilities
1. **Pre-flight checks**
   - SSH connectivity
   - Git status (clean working directory)
   - On main branch

2. **Code update**
   - SSH to production
   - Pull latest from origin/main

3. **Dependencies**
   - Bundle install

4. **Service restart**
   - Restart via launchctl

5. **Health check**
   - Test /health endpoint
   - Test /v1/models endpoint
   - Test Ollama integration

6. **Summary**
   - Report commit deployed
   - Confirm health status

#### Usage
```bash
# From local machine
cd /Users/ericsmith66/development/agent-forge/projects/SmartProxy
bin/deploy-smartproxy
```

#### Script Template
```bash
#!/usr/bin/env bash
# SmartProxy Production Deployment Script
set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
PROD_HOST="192.168.4.253"
PROD_USER="ericsmith66"
PROD_PATH="/Users/ericsmith66/Development/SmartProxy"
LAUNCHD_SERVICE="com.agentforge.smartproxy"
PROXY_AUTH_TOKEN="${PROXY_AUTH_TOKEN:-}"

echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  SmartProxy Production Deployment${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
echo ""

# Function to log with timestamp
log() {
    echo -e "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

# Function to run command on production
run_remote() {
    ssh "${PROD_USER}@${PROD_HOST}" "
        export PATH=\"/opt/homebrew/bin:/usr/local/bin:\$PATH\"
        cd ${PROD_PATH}
        ${1}
    "
}

# Pre-flight checks
log "${BLUE}→ [1/5] Pre-flight checks...${NC}"

# Check branch
BRANCH=$(git rev-parse --abbrev-ref HEAD)
if [[ "${BRANCH}" != "main" ]]; then
    log "${RED}✗ Not on main branch (current: ${BRANCH})${NC}"
    exit 1
fi
log "${GREEN}  ✓ On main branch${NC}"

# Check uncommitted changes
if [[ -n $(git status --porcelain) ]]; then
    log "${RED}✗ Uncommitted changes detected${NC}"
    exit 1
fi
log "${GREEN}  ✓ No uncommitted changes${NC}"

# Check SSH
if ! ssh -o ConnectTimeout=10 "${PROD_USER}@${PROD_HOST}" "echo SSH_OK" > /dev/null 2>&1; then
    log "${RED}✗ Cannot connect to production${NC}"
    exit 1
fi
log "${GREEN}  ✓ SSH connectivity verified${NC}"

# Get auth token from keychain
if [[ -z "${PROXY_AUTH_TOKEN}" ]]; then
    PROXY_AUTH_TOKEN=$(ssh "${PROD_USER}@${PROD_HOST}" "security find-generic-password -a 'smartproxy' -s 'smartproxy-PROXY_AUTH_TOKEN' -w" 2>/dev/null || echo "")
fi
if [[ -z "${PROXY_AUTH_TOKEN}" ]]; then
    log "${YELLOW}  ⚠ PROXY_AUTH_TOKEN not available (will skip authenticated tests)${NC}"
fi

echo ""

# Update code
log "${BLUE}→ [2/5] Updating code...${NC}"

PREVIOUS_COMMIT=$(run_remote "git rev-parse HEAD")
log "${BLUE}  → Previous commit: ${PREVIOUS_COMMIT:0:7}${NC}"

run_remote "git fetch origin main"
run_remote "git reset --hard origin/main"

CURRENT_COMMIT=$(run_remote "git rev-parse HEAD")
log "${GREEN}  ✓ Updated to: ${CURRENT_COMMIT:0:7}${NC}"

echo ""

# Install dependencies
log "${BLUE}→ [3/5] Installing dependencies...${NC}"

run_remote "bundle install --without development test"
log "${GREEN}  ✓ Dependencies installed${NC}"

echo ""

# Restart service
log "${BLUE}→ [4/5] Restarting service...${NC}"

PROD_UID=$(ssh "${PROD_USER}@${PROD_HOST}" 'id -u')
ssh "${PROD_USER}@${PROD_HOST}" "launchctl kickstart -k gui/${PROD_UID}/${LAUNCHD_SERVICE}"
log "${GREEN}  ✓ Service restarted${NC}"

sleep 5

echo ""

# Health checks
log "${BLUE}→ [5/5] Verifying deployment...${NC}"

# Basic health
HEALTH=$(ssh "${PROD_USER}@${PROD_HOST}" "curl -s http://localhost:3002/health" 2>/dev/null || echo "")
if [[ "${HEALTH}" == '{"status":"ok"}' ]]; then
    log "${GREEN}  ✓ Health check passed${NC}"
else
    log "${RED}✗ Health check failed${NC}"
    log "${RED}  Response: ${HEALTH}${NC}"
    exit 1
fi

# Model listing (if auth token available)
if [[ -n "${PROXY_AUTH_TOKEN}" ]]; then
    MODELS=$(ssh "${PROD_USER}@${PROD_HOST}" "curl -s -H 'Authorization: Bearer ${PROXY_AUTH_TOKEN}' http://localhost:3002/v1/models" 2>/dev/null || echo "")
    if echo "${MODELS}" | grep -q '"data"'; then
        log "${GREEN}  ✓ Model listing works${NC}"
    else
        log "${YELLOW}  ⚠ Model listing test skipped or failed${NC}"
    fi
fi

# Check port
PORT_CHECK=$(ssh "${PROD_USER}@${PROD_HOST}" "lsof -nP -iTCP:3002 -sTCP:LISTEN" 2>/dev/null || echo "")
if [[ -n "${PORT_CHECK}" ]]; then
    log "${GREEN}  ✓ Port 3002 listening${NC}"
else
    log "${RED}✗ Port 3002 not listening${NC}"
    exit 1
fi

echo ""

# Summary
echo -e "${GREEN}═══════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  Deployment Successful! ✓${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════${NC}"
echo ""
log "${BLUE}Deployment Summary:${NC}"
log "${BLUE}  Previous commit: ${PREVIOUS_COMMIT:0:7}${NC}"
log "${BLUE}  Current commit:  ${CURRENT_COMMIT:0:7}${NC}"
log "${BLUE}  Service status:  Running${NC}"
log "${BLUE}  Health check:    Passed${NC}"
echo ""
log "${BLUE}SmartProxy URL: http://192.168.4.253:3002${NC}"
echo ""
```

**Advantages:**
- ✅ Automated deployment process
- ✅ Health checks built-in
- ✅ Rollback information captured
- ✅ Easy to use
- ✅ No additional infrastructure needed

**Disadvantages:**
- ❌ Still manual trigger
- ❌ No pre-deployment testing
- ❌ No audit trail

---

### Option 3: GitHub Actions (Full CI/CD) [Future]

Create `.github/workflows/deploy-smartproxy.yml` similar to nextgen-plaid.

#### When to Implement
- **NOT for initial deployment** (use manual process)
- Consider if SmartProxy becomes actively developed
- Consider if multiple developers deploy

#### Requirements
1. **GitHub Repository**
   - SmartProxy needs to be in its own GitHub repo
   - Currently: `/Users/ericsmith66/development/agent-forge/projects/SmartProxy`
   - Future: `github.com/ericsmith66/SmartProxy` or similar

2. **GitHub Secrets**
   - `SMARTPROXY_DEPLOY_KEY` - SSH key for deployment
   - `PROD_HOST` - 192.168.4.253
   - `PROD_USER` - ericsmith66

3. **Workflow Configuration**
   ```yaml
   name: Deploy SmartProxy to Production
   
   on:
     workflow_dispatch:
     push:
       branches:
         - main
   
   jobs:
     deploy:
       runs-on: ubuntu-latest
       steps:
         - name: Checkout
           uses: actions/checkout@v4
         
         - name: Setup Ruby
           uses: ruby/setup-ruby@v1
           with:
             ruby-version: '3.3.0'
             bundler-cache: true
         
         - name: Run tests
           run: bundle exec rspec
         
         - name: Configure SSH
           env:
             SSH_KEY: ${{ secrets.SMARTPROXY_DEPLOY_KEY }}
           run: |
             mkdir -p ~/.ssh
             echo "$SSH_KEY" > ~/.ssh/deploy_key
             chmod 600 ~/.ssh/deploy_key
         
         - name: Deploy
           env:
             PROD_HOST: ${{ secrets.PROD_HOST }}
             PROD_USER: ${{ secrets.PROD_USER }}
           run: |
             ssh -i ~/.ssh/deploy_key ${PROD_USER}@${PROD_HOST} \
               "cd /Users/${PROD_USER}/Development/SmartProxy && ./bin/deploy-smartproxy"
   ```

**Advantages:**
- ✅ Fully automated
- ✅ Pre-deployment testing
- ✅ Audit trail
- ✅ No local machine needed

**Disadvantages:**
- ❌ Requires GitHub repo setup
- ❌ Additional complexity
- ❌ May be overkill for infrastructure

---

## Recommended Approach

### Phase 1: Initial Deployment (Manual)
**Status:** Ready to execute

Follow the deployment checklist in `SMARTPROXY-DEPLOYMENT-CHECKLIST.md` for one-time setup.

### Phase 2: Create Deployment Script (Week 1-2)
**Priority:** Medium

Create `bin/deploy-smartproxy` script for future updates.

**Implementation steps:**
1. Create script based on template above
2. Test deployment to production
3. Document usage in RUNBOOK.md
4. Add to SmartProxy README

### Phase 3: GitHub Actions (Future - If Needed)
**Priority:** Low

Only implement if:
- SmartProxy becomes actively developed
- Multiple developers need to deploy
- Automated testing becomes critical

---

## Deployment Comparison

| Aspect | NextGen Plaid | SmartProxy (Recommended) |
|--------|--------------|--------------------------|
| **Frequency** | Regular (weekly) | Rare (monthly or less) |
| **Complexity** | High (Rails app with DB) | Low (Sinatra app, no DB) |
| **Backup Required** | Yes (database) | No (stateless) |
| **Migration** | Yes (db:migrate) | No |
| **Assets** | Yes (precompile) | No |
| **Tests** | Yes (extensive suite) | Yes (but smaller) |
| **CI/CD** | GitHub Actions + Script | Script only (for now) |
| **Rollback** | Complex (code + DB) | Simple (code only) |

---

## Deployment Dependencies

### For SmartProxy Deployment

**Required before deploying SmartProxy:**
- ✅ PostgreSQL running (required by Ollama data, if any)
- ✅ Redis running (if SmartProxy caching uses Redis)
- ✅ Ollama running (Port 11434)

**Required after SmartProxy deployed:**
- ✅ NextGen Plaid (connects to SmartProxy on 3002)
- ✅ Eureka HomeKit (future - will connect to SmartProxy)

### Service Restart Order

If restarting multiple services:

1. **Stop in reverse dependency order:**
   ```bash
   launchctl stop com.agentforge.nextgen-plaid
   launchctl stop com.agentforge.smartproxy
   ```

2. **Start in dependency order:**
   ```bash
   launchctl start com.agentforge.smartproxy
   sleep 5  # Wait for SmartProxy to be ready
   launchctl start com.agentforge.nextgen-plaid
   ```

---

## Security Considerations

### SSH Key Management

SmartProxy deployment uses the same SSH access as nextgen-plaid:
- User: `ericsmith66@192.168.4.253`
- Key: `~/.ssh/id_ed25519` (or as configured)

### Secrets Management

SmartProxy secrets are stored in macOS Keychain:
- Account: `smartproxy`
- Services:
  - `smartproxy-GROK_API_KEY`
  - `smartproxy-CLAUDE_API_KEY`
  - `smartproxy-PROXY_AUTH_TOKEN`

**Rotation procedure:**
```bash
# On production
security delete-generic-password -a 'smartproxy' -s 'smartproxy-GROK_API_KEY'
security add-generic-password -a 'smartproxy' -s 'smartproxy-GROK_API_KEY' -w 'NEW_KEY'

# Restart service
launchctl kickstart -k gui/$(id -u)/com.agentforge.smartproxy
```

---

## Rollback Procedures

### SmartProxy Rollback (Simple)

```bash
# SSH to production
ssh ericsmith66@192.168.4.253
cd /Users/ericsmith66/Development/SmartProxy

# Get previous commit
git log --oneline -10

# Reset to previous commit
git reset --hard COMMIT_HASH

# Restart
launchctl kickstart -k gui/$(id -u)/com.agentforge.smartproxy

# Verify
curl -s http://localhost:3002/health
```

### If SmartProxy Breaks NextGen Plaid

```bash
# Option 1: Rollback SmartProxy (preferred)
# (Use steps above)

# Option 2: Temporarily disable SmartProxy in NextGen Plaid
ssh ericsmith66@192.168.4.253
cd /Users/ericsmith66/Development/nextgen-plaid

# Edit .env.production - comment out SmartProxy
nano .env.production
# Comment: # OPENAI_API_BASE=http://localhost:3002/v1

# Restart NextGen Plaid
launchctl kickstart -k gui/$(id -u)/com.agentforge.nextgen-plaid
```

---

## Monitoring & Alerts

### Current State
- **None** - Manual checking only

### Recommended (Future)
1. **Health Check Monitoring**
   - Cron job to test `/health` endpoint
   - Alert if down for >5 minutes

2. **Log Monitoring**
   - Watch for errors in `log/smart_proxy.log`
   - Alert on repeated errors

3. **Dependency Monitoring**
   - Watch Ollama availability
   - Alert if upstream APIs fail repeatedly

### Simple Monitoring Script
```bash
# Add to crontab (every 5 minutes)
# */5 * * * * /Users/ericsmith66/Development/SmartProxy/bin/health-check.sh

#!/bin/bash
# SmartProxy Health Check

HEALTH=$(curl -s -m 5 http://localhost:3002/health 2>/dev/null || echo "")

if [[ "${HEALTH}" != '{"status":"ok"}' ]]; then
    echo "$(date): SmartProxy health check failed" >> /Users/ericsmith66/logs/smartproxy-health.log
    # Optional: Send alert (email, SMS, etc.)
fi
```

---

## Summary

### For Initial Deployment
✅ **Use:** Manual deployment via checklist (`SMARTPROXY-DEPLOYMENT-CHECKLIST.md`)

### For Ongoing Updates
✅ **Recommended:** Create `bin/deploy-smartproxy` script (Phase 2)

### For Future
⏳ **Consider:** GitHub Actions if deployment frequency increases

---

**Document Version:** 1.0  
**Last Updated:** March 2, 2026  
**Related Documents:**
- Full Deployment Plan: `deployment-smartproxy.md`
- Deployment Checklist: `SMARTPROXY-DEPLOYMENT-CHECKLIST.md`
- Executive Summary: `SMARTPROXY-DEPLOYMENT-SUMMARY.md`
