# SmartProxy Standalone Deployment - Execution Checklist

**Date:** March 2, 2026  
**Estimated Time:** 45-60 minutes  
**Server:** 192.168.4.253

---

## Pre-Flight Check

- [ ] Read executive summary: `SMARTPROXY-DEPLOYMENT-SUMMARY.md`
- [ ] Review full plan: `deployment-smartproxy.md`
- [ ] Backup current state (nextgen-plaid git status clean or stashed)
- [ ] Confirm SmartProxy repo is up to date locally

---

## Phase 1: Local Preparation (10 min)

### Step 1.1: Extract Secrets
```bash
cd /Users/ericsmith66/development/agent-forge/projects/SmartProxy

GROK_API_KEY=$(security find-generic-password -a 'nextgen-plaid' -s 'GROK_API_KEY' -w)
CLAUDE_API_KEY=$(security find-generic-password -a 'nextgen-plaid' -s 'CLAUDE_API_KEY' -w)
PROXY_AUTH_TOKEN=$(security find-generic-password -a 'nextgen-plaid' -s 'PROXY_AUTH_TOKEN' -w)

echo "GROK_API_KEY=${GROK_API_KEY}"
echo "CLAUDE_API_KEY=${CLAUDE_API_KEY}"
echo "PROXY_AUTH_TOKEN=${PROXY_AUTH_TOKEN}"
```
- [ ] Secrets extracted
- [ ] Save these temporarily (will need for Step 2.3)

### Step 1.2: Create Deployment Package
```bash
cd /Users/ericsmith66/development/agent-forge/projects/SmartProxy

tar -czf /tmp/smartproxy-deployment.tar.gz \
  --exclude='.git' --exclude='.env' --exclude='log/*' \
  --exclude='tmp/*' --exclude='spec' .

ls -lh /tmp/smartproxy-deployment.tar.gz
```
- [ ] Package created (~500KB expected)

---

## Phase 2: Production Deployment (30 min)

### Step 2.1: Create Directories
```bash
ssh ericsmith66@192.168.4.253

mkdir -p /Users/ericsmith66/Development/SmartProxy/{log,tmp,knowledge_base/test_artifacts/llm_calls,bin}

ls -la /Users/ericsmith66/Development/SmartProxy/
```
- [ ] Directories created

### Step 2.2: Transfer & Extract Package
```bash
# From local machine:
scp /tmp/smartproxy-deployment.tar.gz ericsmith66@192.168.4.253:/tmp/

# On production:
ssh ericsmith66@192.168.4.253
cd /Users/ericsmith66/Development/SmartProxy
tar -xzf /tmp/smartproxy-deployment.tar.gz
rm /tmp/smartproxy-deployment.tar.gz
ls -la
```
- [ ] Package transferred
- [ ] Package extracted
- [ ] Files verified (should see app.rb, config.ru, Gemfile, lib/)

### Step 2.3: Setup Keychain Secrets
```bash
# On production (use values from Step 1.1):

security add-generic-password \
  -a 'smartproxy' \
  -s 'smartproxy-GROK_API_KEY' \
  -w 'PASTE_GROK_KEY_HERE' \
  -T /usr/bin/security

security add-generic-password \
  -a 'smartproxy' \
  -s 'smartproxy-CLAUDE_API_KEY' \
  -w 'PASTE_CLAUDE_KEY_HERE' \
  -T /usr/bin/security

security add-generic-password \
  -a 'smartproxy' \
  -s 'smartproxy-PROXY_AUTH_TOKEN' \
  -w 'PASTE_TOKEN_HERE' \
  -T /usr/bin/security

# Verify:
security find-generic-password -a 'smartproxy' -s 'smartproxy-GROK_API_KEY' | grep "account:"
security find-generic-password -a 'smartproxy' -s 'smartproxy-CLAUDE_API_KEY' | grep "account:"
security find-generic-password -a 'smartproxy' -s 'smartproxy-PROXY_AUTH_TOKEN' | grep "account:"
```
- [ ] GROK_API_KEY stored
- [ ] CLAUDE_API_KEY stored
- [ ] PROXY_AUTH_TOKEN stored
- [ ] All secrets verified

### Step 2.4: Create .env.production
```bash
cat > /Users/ericsmith66/Development/SmartProxy/.env.production << 'EOF'
# SmartProxy Production Configuration
SMART_PROXY_PORT=3002
RACK_ENV=production
GROK_MODELS=grok-4,grok-4-latest,grok-4-with-live-search
CLAUDE_MODELS=claude-sonnet-4-5-20250929,claude-sonnet-4-20250514,claude-3-5-haiku-20241022,claude-3-haiku-20240307
SMART_PROXY_ENABLE_WEB_TOOLS=true
SMART_PROXY_LOG_BODY_BYTES=2000
SMART_PROXY_MODELS_CACHE_TTL=60
OLLAMA_TAGS_URL=http://localhost:11434/api/tags
PUMA_THREADS=5
PUMA_WORKERS=2
EOF

chmod 600 /Users/ericsmith66/Development/SmartProxy/.env.production
cp /Users/ericsmith66/Development/SmartProxy/.env.production \
   ~/.env.smartproxy.production.backup.$(date +%Y%m%d_%H%M%S)
```
- [ ] .env.production created
- [ ] File secured (600 permissions)
- [ ] Backup created

### Step 2.5: Install Dependencies
```bash
cd /Users/ericsmith66/Development/SmartProxy

ruby -v  # Should be 3.3.x
gem list | grep bundler || gem install bundler

bundle config set --local deployment 'true'
bundle config set --local without 'development test'
bundle install

bundle check
```
- [ ] Ruby version verified
- [ ] Bundler installed
- [ ] Dependencies installed
- [ ] Bundle check passed

### Step 2.6: Create Startup Script
Copy from full deployment plan, Section 2.6, or use:
```bash
cat > /Users/ericsmith66/Development/SmartProxy/bin/start-production.sh << 'EOF'
#!/bin/bash
set -e
cd /Users/ericsmith66/Development/SmartProxy
export RACK_ENV=production
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
export GROK_API_KEY=$(security find-generic-password -a 'smartproxy' -s 'smartproxy-GROK_API_KEY' -w)
export CLAUDE_API_KEY=$(security find-generic-password -a 'smartproxy' -s 'smartproxy-CLAUDE_API_KEY' -w)
export PROXY_AUTH_TOKEN=$(security find-generic-password -a 'smartproxy' -s 'smartproxy-PROXY_AUTH_TOKEN' -w)
if [ -f .env.production ]; then set -a; source .env.production; set +a; else echo "ERROR: .env.production not found" >&2; exit 1; fi
if [ -z "$GROK_API_KEY" ] || [ -z "$CLAUDE_API_KEY" ] || [ -z "$PROXY_AUTH_TOKEN" ]; then echo "ERROR: Secrets not found" >&2; exit 1; fi
exec bundle exec puma -C config/puma.rb
EOF

chmod +x /Users/ericsmith66/Development/SmartProxy/bin/start-production.sh
```
- [ ] Script created
- [ ] Made executable

### Step 2.7: Create Puma Config
Copy from full deployment plan, Section 2.7, or use:
```bash
mkdir -p /Users/ericsmith66/Development/SmartProxy/config
# (Full puma.rb content from deployment plan)
```
- [ ] config/puma.rb created

### Step 2.8: Create LaunchAgent
Copy from full deployment plan, Section 2.8, or use:
```bash
# (Full plist content from deployment plan)
cat > ~/Library/LaunchAgents/com.agentforge.smartproxy.plist << 'EOF'
# ...full plist XML...
EOF

chmod 644 ~/Library/LaunchAgents/com.agentforge.smartproxy.plist
```
- [ ] LaunchAgent plist created
- [ ] Permissions set

### Step 2.9: Start Service
```bash
launchctl bootout gui/$(id -u)/com.agentforge.smartproxy 2>/dev/null || true
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.agentforge.smartproxy.plist

sleep 5

launchctl list | grep smartproxy
ps aux | grep smartproxy | grep -v grep
lsof -nP -iTCP:3002 -sTCP:LISTEN
```
- [ ] Service loaded
- [ ] Process running (PID shown)
- [ ] Port 3002 listening

### Step 2.10: Verify Health
```bash
# Health check (no auth)
curl -s http://localhost:3002/health
# Expected: {"status":"ok"}

# Model listing (with auth)
curl -s http://localhost:3002/v1/models \
  -H "Authorization: Bearer c2708a90c1fde993a6a7cb8bde2a4d1db708b91937ce1e228f6e4ba7b6891ad4"
# Expected: JSON with models

# Test Ollama
curl -s -X POST http://localhost:3002/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer c2708a90c1fde993a6a7cb8bde2a4d1db708b91937ce1e228f6e4ba7b6891ad4" \
  -d '{"model": "llama3.1:70b", "messages": [{"role": "user", "content": "Test"}], "max_tokens": 20}'
# Expected: JSON response with content

tail -20 /Users/ericsmith66/Development/SmartProxy/log/smart_proxy.log
```
- [ ] Health check passed
- [ ] Model listing works
- [ ] Ollama test passed
- [ ] Logs look clean (no errors)

---

## Phase 3: Update NextGen Plaid (10 min)

### Step 3.1: Remove Embedded SmartProxy
```bash
cd /Users/ericsmith66/Development/nextgen-plaid

git status
# If clean, proceed. If not, stash:
git stash save "backup-before-smartproxy-extraction-$(date +%Y%m%d_%H%M%S)"

# Check if smart_proxy directory exists
ls -d smart_proxy 2>/dev/null && rm -rf smart_proxy || echo "smart_proxy not found (OK)"
```
- [ ] Working directory backed up
- [ ] smart_proxy/ removed (if existed)

### Step 3.2: Verify Procfile.prod
```bash
cat Procfile.prod
# Should only have:
# web: env PORT=3000 bin/rails server -e production -b 0.0.0.0
# worker: bin/rails solid_queue:start
```
- [ ] No `proxy:` line in Procfile.prod

### Step 3.3: Update Environment Variables
```bash
grep SMART_PROXY .env.production
# If missing, add:
cat >> .env.production << 'EOF'

# SmartProxy Configuration (Standalone Service)
SMART_PROXY_PORT=3002
OPENAI_API_BASE=http://localhost:3002/v1
EOF
```
- [ ] SMART_PROXY_PORT=3002 confirmed
- [ ] OPENAI_API_BASE set to SmartProxy

### Step 3.4: Restart NextGen Plaid
```bash
launchctl kickstart -k gui/$(id -u)/com.agentforge.nextgen-plaid

sleep 10

launchctl list | grep nextgen-plaid
ps aux | grep puma | grep production

tail -50 /Users/ericsmith66/Development/nextgen-plaid/log/production.log | grep -i smart
```
- [ ] NextGen Plaid restarted
- [ ] Process running
- [ ] No SmartProxy connection errors in logs

---

## Phase 4: Verification (10 min)

### Test 1: Service Status
```bash
launchctl list | grep -E "(smartproxy|nextgen)"
lsof -nP -iTCP -sTCP:LISTEN | grep -E ":(3000|3002) "
```
- [ ] Both services running
- [ ] Both ports listening

### Test 2: Health Checks
```bash
curl -s http://localhost:3002/health
# Expected: {"status":"ok"}

curl -s "http://localhost:3000/health?token=$(grep HEALTH_TOKEN /Users/ericsmith66/Development/nextgen-plaid/.env.production | cut -d'=' -f2 | tr -d '\"')"
# Expected: {"status":"ok",...}
```
- [ ] SmartProxy health OK
- [ ] NextGen Plaid health OK

### Test 3: Rails Integration
```bash
cd /Users/ericsmith66/Development/nextgen-plaid
RAILS_ENV=production bin/rails console

# In console:
client = AgentHub::SmartProxyClient.new
response = client.chat(model: 'llama3.1:70b', messages: [{role: 'user', content: 'Test'}])
puts response
exit
```
- [ ] Rails console loaded
- [ ] SmartProxy client connected
- [ ] Chat completion worked

### Test 4: Log Verification
```bash
tail -20 /Users/ericsmith66/Development/SmartProxy/log/smart_proxy.log
tail -20 /Users/ericsmith66/Development/nextgen-plaid/log/production.log

grep -i "error\|fatal\|exception" /Users/ericsmith66/Development/SmartProxy/log/*.log | tail -20
```
- [ ] SmartProxy logs clean
- [ ] NextGen Plaid logs clean
- [ ] No unexpected errors

---

## Optional: Reboot Test

```bash
# ⚠️ Only if you want to verify auto-start
sudo reboot

# After reboot (wait 3-5 minutes):
ssh ericsmith66@192.168.4.253

launchctl list | grep -E "(smartproxy|nextgen)"
curl -s http://localhost:3002/health
curl -s "http://localhost:3000/health?token=YOUR_TOKEN"
```
- [ ] SmartProxy auto-started
- [ ] NextGen Plaid auto-started
- [ ] Both health checks pass

---

## Post-Deployment

- [ ] Update RUNBOOK.md if needed
- [ ] Document any issues/deviations
- [ ] Remove temporary files (`/tmp/smartproxy-deployment.tar.gz`)
- [ ] Clear secrets from temporary storage
- [ ] Update overwatch deployment log

---

## Rollback (If Needed)

If anything fails:

```bash
# Stop SmartProxy
launchctl bootout gui/$(id -u)/com.agentforge.smartproxy
rm ~/Library/LaunchAgents/com.agentforge.smartproxy.plist

# Restore nextgen-plaid if needed
cd /Users/ericsmith66/Development/nextgen-plaid
git stash pop

# Restart nextgen-plaid
launchctl kickstart -k gui/$(id -u)/com.agentforge.nextgen-plaid
```

See full rollback procedures in `deployment-smartproxy.md`, Section "Rollback Procedure".

---

## Completion

**Deployment Status:** [ ] SUCCESS  [ ] FAILED  [ ] ROLLED BACK

**Notes:**
```
(Add any notes, issues, or deviations here)
```

**Completed By:** _________________  
**Date/Time:** _________________  
**Duration:** _________________

---

**Reference Documents:**
- Full Plan: `docs/deployment/deployment-smartproxy.md`
- Executive Summary: `docs/deployment/SMARTPROXY-DEPLOYMENT-SUMMARY.md`
