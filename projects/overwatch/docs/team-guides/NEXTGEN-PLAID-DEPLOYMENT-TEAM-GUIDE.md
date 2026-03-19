# NextGen Plaid Deployment Guide for Development Team
**Version:** 2.0  
**Last Updated:** February 25, 2026  
**Status:** Production Ready

---

## 📋 Executive Summary

This document provides the development team with everything needed to understand and execute deployments for the NextGen Plaid application. The deployment system is fully automated, tested, and production-ready.

---

## 🎯 Quick Start

### **Deploy to Production (Two Methods)**

#### **Option 1: GitHub Actions (Recommended)**
1. Go to: https://github.com/YOUR_ORG/nextgen-plaid/actions
2. Click "Deploy to Production" workflow
3. Click "Run workflow" button
4. Review options and click "Run workflow"
5. Monitor deployment progress (5-15 minutes)

#### **Option 2: Manual from Dev Machine**
```bash
cd /path/to/nextgen-plaid
bin/deploy-prod
```

**That's it!** The automation handles everything else.

---

## 🏗️ Infrastructure Overview

### **Production Server**
- **Location:** 192.168.4.253 (M3 Ultra, macOS)
- **User:** ericsmith66
- **Deploy Path:** `/Users/ericsmith66/Development/nextgen-plaid`
- **Port:** 3000
- **Public URL:** TBD (via Cloudflare Tunnel)

### **Key Technologies**
- **Framework:** Ruby on Rails 8.1.1
- **Ruby Version:** 3.3.10 (via rbenv)
- **Database:** PostgreSQL 16 (Homebrew)
- **Background Jobs:** Solid Queue
- **Cache:** Solid Cache (database-backed)
- **Cable:** Action Cable (database-backed)
- **Process Manager:** Foreman + Puma (via LaunchAgents)
- **LLM Proxy:** SmartProxy (Sinatra/Rack, port 3001)
- **Secrets:** `.env.production` files (not in git)

### **Database Structure**
```
nextgen_plaid_production        # Main application database
nextgen_plaid_production_queue  # Solid Queue jobs
nextgen_plaid_production_cache  # Solid Cache entries
nextgen_plaid_production_cable  # Action Cable connections
```

### **Service Architecture**
```
nextgen-plaid (Rails/Puma)     :3000  [launchd: com.agentforge.nextgen-plaid]
  ├── Solid Queue (workers)
  ├── Action Cable (WebSocket)
  └── Solid Cache

SmartProxy (Sinatra/Rack)      :3001  [launchd: com.agentforge.smart-proxy]
  ├── → Ollama                 :11434
  ├── → Anthropic Claude       (HTTPS)
  └── → Grok (xAI)            (HTTPS)

PostgreSQL 16                  :5432  [launchd: homebrew.mxcl.postgresql@16]
Redis                          :6379  [launchd: homebrew.mxcl.redis]
Ollama                         :11434 [Login Item: Ollama.app]
```

---

## 📦 Deployment System Components

### **Deployment Scripts (in nextgen-plaid repo)**

| Script | Purpose | Location |
|--------|---------|----------|
| `bin/deploy-prod` | Main deployment script | Run from dev machine |
| `bin/sync-from-prod` | Sync prod DB to dev | Run from dev machine |
| `scripts/backup-database.sh` | Create database backups | Runs on production server |
| `scripts/restore-database.sh` | Restore from backup | Runs on production server |

**Note:** `bin/prod` and `scripts/setup-keychain.sh` have been replaced by LaunchAgents and `.env.production` files.

### **GitHub Actions Workflow**
- **File:** `.github/workflows/deploy.yml`
- **Trigger:** Manual via GitHub UI
- **Phases:** Tests → Security Scans → Deploy → Verify

### **Documentation**
- **Operations Guide:** `nextgen-plaid/RUNBOOK.md` (4,700+ lines)
- **Setup Guide:** `nextgen-plaid/docs/DEPLOYMENT_SETUP.md`
- **This Guide:** You're reading it!

---

## 🚀 Deployment Process (7 Phases)

When you run `bin/deploy-prod`, here's what happens:

### **Phase 1: Pre-flight Checks** ✅
```
✓ On main branch
✓ No uncommitted changes
✓ SSH connectivity to production
✓ PostgreSQL accessible
```

### **Phase 2: Database Backup** 💾
```
✓ Timestamp: YYYYMMDD_HHMMSS
✓ Backup location: ~/backups/nextgen-plaid/
✓ All 4 databases backed up
✓ 30-day retention (auto-cleanup)
```

### **Phase 3: Code Update** 📥
```
✓ Previous commit saved to .last_commit
✓ git pull origin main
✓ New commit SHA logged
```

### **Phase 4: Dependencies** 📦
```
✓ bundle install (with rbenv Ruby 3.3.10)
✓ All gems updated
```

### **Phase 5: Database Migrations** 🗄️
```
✓ rails db:migrate RAILS_ENV=production
✓ Migration status logged
✓ Aborts deployment on migration failure
```

### **Phase 6: Asset Compilation** 🎨
```
✓ rails assets:precompile
✓ Tailwind CSS compiled
✓ JavaScript bundled
```

### **Phase 7: Service Restart** 🔄
```
✓ launchd service restart
✓ Health check validation
✓ Deployment verification
```

**Total Time:** ~2-5 minutes (depending on dependencies)

---

## 🔐 Security & Secrets

### **Secrets Management**
All secrets are stored in **macOS Keychain** (no .env files on disk).

**Production Secrets:**
- `DATABASE_PASSWORD` - PostgreSQL password
- `PLAID_CLIENT_ID` - Plaid API client ID
- `PLAID_SECRET` - Plaid API secret
- `CLAUDE_API_KEY` - Claude AI API key
- `RAILS_MASTER_KEY` - Rails credentials encryption key
- Additional app-specific secrets

### **How Secrets Are Loaded**
1. `bin/prod` script reads from Keychain
2. Exports as environment variables
3. Starts Puma with loaded environment
4. No secrets ever touch disk

### **Viewing a Secret** (requires local access)
```bash
security find-generic-password -a 'nextgen-plaid' -s 'nextgen-plaid-DATABASE_PASSWORD' -w
```

### **GitHub Secrets** (for CI/CD)
- `PROD_DEPLOY_KEY` - SSH private key for deployment
- `PROD_HOST` - Production server IP (192.168.4.253)
- `PROD_USER` - SSH user (ericsmith66)

---

## 💾 Database Management

### **Backup Strategy**
- **Frequency:** Automatic before every deployment
- **Retention:** 30 days
- **Location:** `~/backups/nextgen-plaid/` on production
- **Format:** PostgreSQL custom dump format

### **Manual Backup**
```bash
ssh ericsmith66@192.168.4.253
cd Development/nextgen-plaid
bash scripts/backup-database.sh
```

**Output:**
```
✓ Backed up nextgen_plaid_production (12MB)
✓ Backed up nextgen_plaid_production_queue (250KB)
✓ Backed up nextgen_plaid_production_cache (100KB)
✓ Backed up nextgen_plaid_production_cable (100KB)
✓ Backup timestamp: 20260222_143045
```

### **List Available Backups**
```bash
ssh ericsmith66@192.168.4.253
cd Development/nextgen-plaid
bash scripts/restore-database.sh --list
```

### **Restore from Backup**
```bash
ssh ericsmith66@192.168.4.253
cd Development/nextgen-plaid

# Stop application first
launchctl stop gui/$(id -u)/com.agentforge.nextgen-plaid

# Restore
bash scripts/restore-database.sh 20260222_143045

# Start application
launchctl start gui/$(id -u)/com.agentforge.nextgen-plaid
```

### **Sync Production Data to Development**
```bash
cd /path/to/nextgen-plaid

# Dry-run first (see what would happen)
bin/sync-from-prod --dry-run

# Actual sync (overwrites local databases!)
bin/sync-from-prod
```

⚠️ **Warning:** This will **replace** your local development databases with production data!

---

## 🔄 Rollback Procedures

### **Scenario 1: Code-Only Rollback** (no database changes)
```bash
ssh ericsmith66@192.168.4.253
cd Development/nextgen-plaid

# Get previous commit
PREV_COMMIT=$(cat .last_commit)
echo "Rolling back to: $PREV_COMMIT"

# Rollback
git reset --hard $PREV_COMMIT

# Restart
launchctl kickstart -k gui/$(id -u)/com.agentforge.nextgen-plaid

# Verify
curl http://localhost:3000/health
```

### **Scenario 2: Code + Database Rollback**
```bash
ssh ericsmith66@192.168.4.253
cd Development/nextgen-plaid

# 1. Stop application
launchctl stop gui/$(id -u)/com.agentforge.nextgen-plaid

# 2. Get backup timestamp from last deployment
BACKUP_TS=$(cat .last_backup_timestamp)
echo "Restoring from: $BACKUP_TS"

# 3. Restore database
bash scripts/restore-database.sh $BACKUP_TS

# 4. Rollback code
git reset --hard $(cat .last_commit)

# 5. Restart
launchctl start gui/$(id -u)/com.agentforge.nextgen-plaid

# 6. Verify
curl http://localhost:3000/health
```

### **Scenario 3: Emergency Stop**
```bash
ssh ericsmith66@192.168.4.253
launchctl stop gui/$(id -u)/com.agentforge.nextgen-plaid
```

---

## 🔍 Monitoring & Health Checks

### **Application Health Check**
```bash
# From anywhere
curl http://192.168.4.253:3000/health

# Expected response
{"status":"ok","timestamp":"2026-02-22T14:30:45Z"}
```

### **Check Application Logs**
```bash
ssh ericsmith66@192.168.4.253
tail -f ~/Development/nextgen-plaid/log/production.log
```

### **Check Service Status**
```bash
ssh ericsmith66@192.168.4.253
launchctl list | grep nextgen-plaid
```

### **Check Process Status**
```bash
ssh ericsmith66@192.168.4.253
ps aux | grep puma | grep production
```

### **Check Database Connections**
```bash
ssh ericsmith66@192.168.4.253
psql -U ericsmith66 -d postgres -c "SELECT datname, numbackends FROM pg_stat_database WHERE datname LIKE 'nextgen%';"
```

---

## 🚨 Common Issues & Troubleshooting

### **Issue 1: Migration Failed During Deployment**

**Symptom:** Deployment aborts at Phase 5 with migration error

**Solution:**
```bash
# 1. Check what failed
ssh ericsmith66@192.168.4.253
cd Development/nextgen-plaid
rails db:migrate:status RAILS_ENV=production

# 2. Fix migration locally, commit, push

# 3. Redeploy
bin/deploy-prod
```

### **Issue 2: Application Won't Start After Deploy**

**Symptom:** Health check fails, Puma won't start

**Check logs:**
```bash
ssh ericsmith66@192.168.4.253
tail -100 ~/Development/nextgen-plaid/log/production.log
```

**Common causes:**
- Missing secret in Keychain → Add with `security add-generic-password`
- Ruby version mismatch → Verify rbenv: `rbenv version`
- Database connection failure → Check PostgreSQL status

**Rollback:**
```bash
# Follow "Code-Only Rollback" procedure above
```

### **Issue 3: Database Connection Errors**

**Symptom:** "FATAL: password authentication failed"

**Solution:**
```bash
# Verify Keychain secret exists
security find-generic-password -a 'nextgen-plaid' -s 'nextgen-plaid-DATABASE_PASSWORD'

# Re-run setup if missing
ssh ericsmith66@192.168.4.253
cd Development/nextgen-plaid
bash scripts/setup-keychain.sh
```

### **Issue 4: Deployment Script Can't Connect to Production**

**Symptom:** "SSH connection failed"

**Check SSH connectivity:**
```bash
ssh -v ericsmith66@192.168.4.253
```

**Verify SSH key:**
```bash
ssh-add -l
```

### **Issue 5: GitHub Actions Deployment Fails**

**Check workflow logs:**
1. Go to GitHub Actions tab
2. Click failed workflow run
3. Expand failed step
4. Review error message

**Common causes:**
- GitHub secrets not configured → Add in repo settings
- SSH key mismatch → Regenerate PROD_DEPLOY_KEY
- Network timeout → Retry deployment

---

## 📊 Deployment Options & Flags

### **Skip Backup** (for testing or first deployment)
```bash
bin/deploy-prod --skip-backup
```

### **Skip Tests** (when tests are failing but deployment is urgent)
```bash
bin/deploy-prod --skip-tests
```

### **Skip Both**
```bash
bin/deploy-prod --skip-backup --skip-tests
```

### **Dry Run** (see what would happen without executing)
```bash
bin/deploy-prod --dry-run
```

---

## 📈 Deployment Best Practices

### **Before Every Deployment**

1. ✅ **Run tests locally**
   ```bash
   bundle exec rspec
   bundle exec rails test
   ```

2. ✅ **Review changes**
   ```bash
   git log origin/main..HEAD --oneline
   ```

3. ✅ **Check for pending migrations**
   ```bash
   rails db:migrate:status
   ```

4. ✅ **Ensure main branch is up to date**
   ```bash
   git checkout main
   git pull origin main
   ```

### **During Deployment**

- ✅ Monitor deployment progress
- ✅ Watch for errors in each phase
- ✅ Don't interrupt the deployment script
- ✅ Have rollback plan ready

### **After Deployment**

1. ✅ **Verify health check**
   ```bash
   curl http://192.168.4.253:3000/health
   ```

2. ✅ **Check application logs**
   ```bash
   ssh ericsmith66@192.168.4.253 "tail -50 ~/Development/nextgen-plaid/log/production.log"
   ```

3. ✅ **Test critical functionality**
   - User login
   - Plaid connections
   - Background jobs

4. ✅ **Monitor for errors** (first 10-15 minutes)

---

## 🔧 Developer Workflows

### **Local Development Setup**
```bash
# Clone repo
git clone <repo-url>
cd nextgen-plaid

# Install dependencies
bundle install

# Setup database
rails db:create db:migrate

# Optional: Sync production data
bin/sync-from-prod --dry-run
bin/sync-from-prod

# Start development server
bin/dev
```

### **Feature Branch Workflow**
```bash
# Create feature branch
git checkout -b feature/my-feature

# Make changes, commit
git add .
git commit -m "Add my feature"

# Push and create PR
git push origin feature/my-feature

# After PR approval, merge to main
# Then deploy from main
git checkout main
git pull origin main
bin/deploy-prod
```

### **Hotfix Workflow**
```bash
# Create hotfix branch
git checkout -b hotfix/critical-fix

# Make minimal fix
git add .
git commit -m "Fix critical issue"

# Push and deploy immediately
git push origin hotfix/critical-fix
git checkout main
git merge hotfix/critical-fix
bin/deploy-prod
```

---

## 📁 Important File Locations

### **On Production Server (192.168.4.253)**
```
/Users/ericsmith66/Development/nextgen-plaid/
├── app/                          # Application code
├── config/                       # Configuration files
├── db/                          # Migrations and schema
├── log/                         # Application logs
│   └── production.log           # Main log file
├── tmp/                         # Temporary files
├── public/                      # Static assets
├── bin/
│   ├── prod                     # Production launcher
│   └── deploy-prod              # Deployment script
└── scripts/
    ├── backup-database.sh       # Backup script
    └── restore-database.sh      # Restore script

/Users/ericsmith66/backups/nextgen-plaid/
└── YYYYMMDD_HHMMSS_*.dump      # Database backups (30-day retention)

/Users/ericsmith66/Library/LaunchAgents/
└── com.agentforge.nextgen-plaid.plist  # Auto-start configuration
```

### **On Development Machine**
```
/path/to/nextgen-plaid/
├── bin/
│   ├── deploy-prod              # Deploy script (run from here)
│   └── sync-from-prod           # DB sync script
├── docs/
│   └── DEPLOYMENT_SETUP.md      # Setup guide
├── .github/workflows/
│   └── deploy.yml               # GitHub Actions workflow
└── RUNBOOK.md                   # Operations guide
```

---

## 🎓 Training Resources

### **Required Reading**
1. **This guide** - Deployment overview (you're reading it!)
2. **RUNBOOK.md** - Comprehensive operations guide
3. **DEPLOYMENT_SETUP.md** - Initial setup documentation

### **Optional Reading**
- `docs/deployment/deployment-strategy-overview.md` - Architecture decisions
- `docs/deployment/deployment-nextgen-plaid.md` - Docker approach (future)

### **Quick Reference Commands**
```bash
# Deploy to production
bin/deploy-prod

# Sync prod to dev
bin/sync-from-prod

# Check health
curl http://192.168.4.253:3000/health

# View logs
ssh ericsmith66@192.168.4.253 "tail -f ~/Development/nextgen-plaid/log/production.log"

# Rollback
ssh ericsmith66@192.168.4.253 "cd Development/nextgen-plaid && git reset --hard \$(cat .last_commit) && launchctl kickstart -k gui/\$(id -u)/com.agentforge.nextgen-plaid"
```

---

## 📞 Support & Escalation

### **When to Ask for Help**

**Deploy immediately (ask later):**
- Production is down
- Critical security issue
- Data loss risk

**Get approval first:**
- Schema changes affecting multiple tables
- Major dependency upgrades
- Infrastructure changes

**Review in PR:**
- New features
- Bug fixes
- Code refactoring

### **Escalation Path**
1. **Check logs** - Most issues are logged
2. **Check this guide** - Common issues documented
3. **Check RUNBOOK.md** - Detailed troubleshooting
4. **Ask team** - Slack/Discord
5. **Contact DevOps** - Infrastructure issues
6. **Contact Product Owner** - Business decisions

---

## ✅ Deployment Checklist

Print this or keep it handy for your first few deployments:

### **Pre-Deployment**
- [ ] All tests passing locally
- [ ] All changes committed and pushed to `main`
- [ ] No uncommitted changes in working directory
- [ ] PR reviewed and approved
- [ ] Breaking changes communicated to team

### **Deployment**
- [ ] Run `bin/deploy-prod` (or GitHub Actions)
- [ ] Monitor each phase for errors
- [ ] Note deployment timestamp

### **Post-Deployment**
- [ ] Health check passes: `curl http://192.168.4.253:3000/health`
- [ ] Application logs show no errors
- [ ] Test critical user flows
- [ ] Monitor for 15 minutes
- [ ] Notify team of successful deployment

### **If Issues Arise**
- [ ] Check logs immediately
- [ ] Determine if rollback needed
- [ ] Execute rollback if necessary
- [ ] Document issue and resolution
- [ ] Post-mortem if critical

---

## 🎉 Success Metrics

**You'll know deployment is successful when:**

1. ✅ All 7 deployment phases complete without errors
2. ✅ Health check returns `{"status":"ok"}`
3. ✅ Application logs show no errors
4. ✅ Users can access the application
5. ✅ Background jobs are processing
6. ✅ Database queries are working
7. ✅ No alerts or monitoring warnings

---

## 📝 Changelog

| Date | Version | Changes |
|------|---------|---------|
| 2026-02-22 | 1.0 | Initial deployment guide created |

---

## 🔗 Related Documentation

- **Operations:** [RUNBOOK.md](../../nextgen-plaid/RUNBOOK.md)
- **Setup:** [DEPLOYMENT_SETUP.md](../../nextgen-plaid/docs/DEPLOYMENT_SETUP.md)
- **Strategy:** [deployment-strategy-overview.md](../deployment/deployment-strategy-overview.md)

---

**Questions?** Check the RUNBOOK.md or ask your team lead.

**Good luck with your deployments! 🚀**
