# Quick Start Guide - Production Deployment

**Status:** ⚠️ **DEPRECATED** — See current documentation below

---

## ⚠️ **DEPRECATION NOTICE**

**This document describes the initial setup from February 2026.**  
**The architecture has since evolved. For current procedures, see:**

📄 **Current Documentation:**
- `/Users/ericsmith66/Development/nextgen-plaid/RUNBOOK.md` (v2.0) — **AUTHORITATIVE**
- `docs/deployments/nextgen-plaid-current-state-2026-02-25.md` — **Current state summary**

**Key Changes:**
- ❌ Keychain → ✅ `.env.production` files
- ❌ `bin/prod` → ✅ LaunchAgents
- ✅ Rails 8.1.1 + SmartProxy added

**This document is retained for historical reference only.**

---

## 🚀 Get Started in 3 Steps (30 minutes)

### Step 1: Setup PostgreSQL Passwords (10 min)
```bash
cd /Users/ericsmith66/development/agent-forge/projects/overwatch
chmod +x scripts/setup-postgres-passwords.sh
./scripts/setup-postgres-passwords.sh
```

**What it does:**
- Generates secure 32-character password
- Sets password for `nextgen_plaid` user (dev + prod)
- Stores in macOS Keychain
- Tests database connectivity

---

### Step 2: Setup Application Secrets (10 min)
```bash
ssh ericsmith66@192.168.4.253
cd Development/nextgen-plaid
chmod +x scripts/setup-keychain.sh
./scripts/setup-keychain.sh
```

**What it does:**
- Prompts for all required secrets
- Validates secret strength
- Stores in macOS Keychain
- Tests database connectivity

**Required secrets:**
- `DATABASE_PASSWORD` - From Step 1
- `PLAID_CLIENT_ID` - From Plaid dashboard
- `PLAID_SECRET` - From Plaid dashboard
- `CLAUDE_API_KEY` - From Anthropic console
- `RAILS_MASTER_KEY` - From `config/master.key`

---

### Step 3: Setup GitHub Deployment (10 min)

**On production server:**
```bash
ssh ericsmith66@192.168.4.253
ssh-keygen -t ed25519 -C "github-actions-deploy" -f ~/.ssh/github_deploy_nextgen_plaid
cat ~/.ssh/github_deploy_nextgen_plaid.pub >> ~/.ssh/authorized_keys
cat ~/.ssh/github_deploy_nextgen_plaid  # Copy this output
```

**On GitHub:**
1. Go to repository → Settings → Secrets → Actions
2. Add secret `PROD_DEPLOY_KEY` = [paste private key from above]
3. Add secret `PROD_HOST` = `192.168.4.253`
4. Add secret `PROD_USER` = `ericsmith66`

---

## ✅ Test Your Setup (10 minutes)

### Test 1: Database Sync (Dry Run)
```bash
cd /Users/ericsmith66/development/agent-forge/projects/nextgen-plaid
bin/sync-from-prod --dry-run
```

**Expected:** All checks pass, no actual changes made

---

### Test 2: Manual Deployment
```bash
cd /Users/ericsmith66/development/agent-forge/projects/nextgen-plaid
bin/deploy-prod
```

**Expected:** 7 phases complete, health check passes

---

### Test 3: GitHub Actions Deployment
1. Go to GitHub → Actions → "Deploy to Production"
2. Click "Run workflow"
3. Leave defaults (don't skip backup or tests)
4. Click "Run workflow"

**Expected:** All steps pass, deployment summary shows success

---

## 📚 Key Commands Reference

### Database Operations
```bash
# Sync production data to dev
bin/sync-from-prod

# Create backup
./scripts/backup-database.sh

# List backups
./scripts/restore-database.sh --list

# Restore from backup
./scripts/restore-database.sh 20260222_143015
```

### Deployment
```bash
# Deploy from dev machine
bin/deploy-prod

# Deploy via GitHub Actions
# Go to repository → Actions → Deploy to Production → Run workflow

# Start production app
bin/prod
```

### Secrets Management
```bash
# Setup all secrets
./scripts/setup-keychain.sh

# Retrieve a secret
security find-generic-password -a 'nextgen-plaid' -s 'nextgen-plaid-DATABASE_PASSWORD' -w
```

### Troubleshooting
```bash
# Check service status
ps aux | grep puma | grep production
lsof -i :3000

# Check logs
tail -100 log/production.log

# Restart service
launchctl kickstart -k gui/$(id -u)/com.agentforge.nextgen-plaid

# Check health
curl http://192.168.4.253:3000/health
```

---

## 🆘 Emergency Procedures

### Rollback Deployment
```bash
# SSH to production
ssh ericsmith66@192.168.4.253
cd Development/nextgen-plaid

# Get previous commit
PREV_COMMIT=$(cat .last_commit)

# Rollback code
git reset --hard ${PREV_COMMIT}

# Restart service
launchctl kickstart -k gui/$(id -u)/com.agentforge.nextgen-plaid

# Verify
curl http://localhost:3000/health
```

### Restore Database
```bash
ssh ericsmith66@192.168.4.253
cd Development/nextgen-plaid

# List available backups
./scripts/restore-database.sh --list

# Restore from backup
./scripts/restore-database.sh <TIMESTAMP>
```

---

## 📖 Documentation Links

| Document | Purpose |
|----------|---------|
| **RUNBOOK.md** | Complete operational guide (nextgen-plaid) |
| **DEPLOYMENT_SETUP.md** | Detailed setup instructions |
| **IMPLEMENTATION_SUMMARY.md** | Full implementation details |
| **eureka-homekit/RUNBOOK.md** | HomeKit operations guide |
| **SmartProxy/RUNBOOK.md** | SmartProxy operations guide |

---

## ✨ What You Got

### Scripts & Tools (13 total)
- `bin/sync-from-prod` - Sync prod DB to dev
- `bin/prod` - Start production app
- `bin/deploy-prod` - Deploy to production
- `scripts/backup-database.sh` - Create backups
- `scripts/restore-database.sh` - Restore from backup
- `scripts/setup-keychain.sh` - Setup secrets
- `scripts/setup-postgres-passwords.sh` - Setup DB passwords
- `.github/workflows/deploy.yml` - GitHub Actions workflow

### Documentation (4 runbooks)
- `nextgen-plaid/RUNBOOK.md` (4,700+ lines)
- `eureka-homekit/RUNBOOK.md` (600+ lines)
- `SmartProxy/RUNBOOK.md` (700+ lines)
- `docs/DEPLOYMENT_SETUP.md` (500+ lines)

### Safety Features
- ✅ Automated backups before deployment
- ✅ Pre-flight checks (branch, tests, SSH)
- ✅ Health check validation
- ✅ Rollback procedures
- ✅ 30-day backup retention
- ✅ Keychain-based secrets (no .env files)

---

## 🎯 Next Steps

1. **Complete setup** (Steps 1-3 above) - 30 minutes
2. **Run tests** (Test 1-3 above) - 10 minutes
3. **Deploy to production** - 5-15 minutes
4. **Enjoy automated deployments!** 🎉

---

**Questions?** Check `RUNBOOK.md` or `DEPLOYMENT_SETUP.md`

**Issues?** See Troubleshooting section in `RUNBOOK.md`
