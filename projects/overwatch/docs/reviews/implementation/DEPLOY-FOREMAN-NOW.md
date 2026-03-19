# Deploy Foreman-Based bin/prod (5 Minutes)

**Goal:** Get reliable Foreman-based production deployment working NOW

---

## Quick Steps

### 1. Copy Files to nextgen-plaid (2 minutes)

```bash
cd /Users/ericsmith66/development/agent-forge/projects/nextgen-plaid

# Copy Procfile.prod
cp /Users/ericsmith66/development/agent-forge/projects/overwatch/docs/reviews/implementation/Procfile.prod .

# Copy new bin/prod
cp /Users/ericsmith66/development/agent-forge/projects/overwatch/docs/reviews/implementation/bin-prod-foreman.sh bin/prod

# Make executable
chmod +x bin/prod

# Verify files
ls -la Procfile.prod bin/prod
```

### 2. Test Locally (2 minutes)

```bash
# Test startup (will fail on secrets if Keychain not configured, that's OK)
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
# (may fail here if Keychain not configured - that's OK)

# Press Ctrl+C to exit
```

### 3. Commit and Push (1 minute)

```bash
git add Procfile.prod bin/prod
git commit -m "Phase 1: Implement Foreman-based production launcher

- Add rbenv initialization for correct Ruby version
- Add PATH validation for better error messages  
- Fix database check to use nextgen_plaid_production
- Use Foreman to manage web + worker processes
- Matches bin/dev pattern for familiarity
- Will migrate to launchd supervision in Phase 2"

git push origin main
```

---

## Deploy to Production

### Option A: Via Deployment Script

```bash
cd /Users/ericsmith66/development/agent-forge/projects/nextgen-plaid
bin/deploy-prod
```

### Option B: Manual Deployment

```bash
# SSH to production
ssh ericsmith66@192.168.4.253

# Navigate to app
cd ~/Development/nextgen-plaid

# Pull changes
git pull origin main

# Stop existing process (if running)
pkill -f "foreman start" || true
pkill -f "rails server" || true

# Start with new bin/prod
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
# ✓ Database ready (migration version: 20260218123456)
# 
# Environment:
#   RAILS_ENV:     production
#   Ruby Version:  3.3.10
#   Database:      nextgen_plaid_production
#   Queue:         nextgen_plaid_production_queue
#   Cable:         nextgen_plaid_production_cable
# 
# ══════════════════════════════════════════════════════
# Starting services via Foreman...
#   - Web server (Puma) on port 3000
#   - Background workers (SolidQueue)
# ══════════════════════════════════════════════════════
# 
# Note: This is Phase 1 (Foreman). Will migrate to launchd in Phase 2.
# 
# 14:23:45 web.1    | started with pid 12345
# 14:23:45 worker.1 | started with pid 12346
# 14:23:46 web.1    | Puma starting in production on http://0.0.0.0:3000
# 14:23:46 worker.1 | SolidQueue processor starting...
```

---

## Verify Working

```bash
# In another terminal, check health
curl http://localhost:3000/health

# Check processes
ps aux | grep foreman
ps aux | grep puma
ps aux | grep solid_queue

# Check logs
tail -f log/production.log
```

---

## What This Gives You

✅ **Reliable startup:** All checks pass before starting services  
✅ **Multi-process:** Web + workers in one command  
✅ **Correct Ruby:** rbenv initialization ensures 3.3.10  
✅ **Better errors:** PATH validation gives helpful messages  
✅ **Accurate checks:** Database verification uses correct DB  
✅ **Familiar pattern:** Matches bin/dev workflow  

---

## Limitations (Accept for Now)

⚠️ **Manual restart required** after crash  
⚠️ **Manual start required** after reboot  
⚠️ **No system integration** (yet)  

**These are acceptable during stabilization phase.**

---

## Next Steps (Phase 2 - Later)

After deployments are stable for 2+ weeks:

1. Create launchd plists
2. Migrate from Foreman to launchd
3. Get auto-restart on crash
4. Get auto-start on boot
5. Better service isolation

**For now: Get it working, optimize later ✅**

---

## Troubleshooting

### "psql command not found"

```bash
# Install PostgreSQL client
brew install postgresql@16

# Add to PATH
export PATH="/opt/homebrew/bin:$PATH"
```

### "Failed to retrieve secret: DATABASE_PASSWORD"

```bash
# Run Keychain setup
./scripts/setup-keychain.sh
```

### "Database connection failed"

```bash
# Check PostgreSQL running
brew services list | grep postgresql

# Start if needed
brew services start postgresql@16

# Verify password
psql -U nextgen_plaid -d nextgen_plaid_production
```

### "Foreman not found"

```bash
# Install foreman gem
gem install foreman
```

---

## Files Provided

All files ready to copy:

1. **`Procfile.prod`** - Process definitions
2. **`bin-prod-foreman.sh`** - Complete bin/prod implementation
3. **`DEPLOY-FOREMAN-NOW.md`** - This deployment guide

**Location:** `/Users/ericsmith66/development/agent-forge/projects/overwatch/docs/reviews/implementation/`

---

**Total Time:** ~5 minutes  
**Risk:** LOW (familiar tool)  
**Status:** ✅ READY TO DEPLOY
