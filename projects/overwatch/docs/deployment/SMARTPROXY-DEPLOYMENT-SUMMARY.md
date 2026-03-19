# SmartProxy Standalone Deployment - Executive Summary

**Date:** March 2, 2026  
**Status:** Ready for Execution  
**Estimated Time:** 45-60 minutes  
**Risk Level:** Low (with rollback available)

---

## What We're Doing

**Current State:**
- SmartProxy runs embedded inside nextgen-plaid at `smart_proxy/` subdirectory
- Started via Procfile.prod (or was previously)
- Port 3002

**Target State:**
- SmartProxy runs as standalone service from `/Users/ericsmith66/Development/SmartProxy`
- Independent launchd service: `com.agentforge.smartproxy`
- Same port: 3002 (no network changes needed)
- Starts **before** nextgen-plaid (proper dependency order)

---

## Why We're Doing This

1. **Independent Deployment** - Update SmartProxy without touching nextgen-plaid
2. **Proper Service Architecture** - SmartProxy is a shared service, should be standalone
3. **Better Observability** - Dedicated logs, clearer boundaries
4. **Reboot Resilience** - Proper startup order via launchd
5. **Future Consumers** - Eureka-homekit and other apps can easily consume it

---

## What Changes

### On 192.168.4.253 (Production):

**New:**
- `/Users/ericsmith66/Development/SmartProxy/` - Standalone application
- `~/Library/LaunchAgents/com.agentforge.smartproxy.plist` - LaunchAgent
- Dedicated logs under `SmartProxy/log/`
- Dedicated keychain entries (account: `smartproxy`)

**Modified:**
- NextGen Plaid: Remove embedded `smart_proxy/` directory (if exists)
- NextGen Plaid: Procfile.prod already has no `proxy:` line
- NextGen Plaid: .env.production updated with SmartProxy connection details

**No Changes:**
- Network configuration (no firewall rules, no port changes)
- SmartProxy API (100% compatible, same port)
- NextGen Plaid code (already uses environment variables to connect)

---

## Execution Plan (High-Level)

### Phase 1: Prepare (Local Machine) - 10 min
1. Extract secrets from keychain
2. Create deployment package

### Phase 2: Deploy (Production) - 30 min
1. Create directory structure
2. Transfer and extract package
3. Setup keychain secrets
4. Create config files (.env.production, puma.rb)
5. Create startup script
6. Create LaunchAgent plist
7. Start service and verify

### Phase 3: Update NextGen Plaid - 10 min
1. Remove embedded smart_proxy directory (if exists)
2. Verify Procfile.prod (no `proxy:` line)
3. Update environment variables
4. Restart nextgen-plaid

### Phase 4: Verification - 10 min
1. Health checks
2. API functionality tests
3. Integration test (Rails → SmartProxy)
4. Log verification

---

## Key Commands

### Start Deployment
```bash
# On local machine - extract secrets
cd /Users/ericsmith66/development/agent-forge/projects/SmartProxy
security find-generic-password -a 'nextgen-plaid' -s 'GROK_API_KEY' -w
security find-generic-password -a 'nextgen-plaid' -s 'CLAUDE_API_KEY' -w
security find-generic-password -a 'nextgen-plaid' -s 'PROXY_AUTH_TOKEN' -w

# Create deployment package
tar -czf /tmp/smartproxy-deployment.tar.gz \
  --exclude='.git' --exclude='.env' --exclude='log/*' \
  --exclude='tmp/*' --exclude='spec' .

# SSH to production
ssh ericsmith66@192.168.4.253
```

### Verify Deployment
```bash
# On production - check service
launchctl list | grep smartproxy
curl -s http://localhost:3002/health

# Check logs
tail -20 /Users/ericsmith66/Development/SmartProxy/log/smart_proxy.log
```

### Rollback (If Needed)
```bash
# On production - emergency stop
launchctl bootout gui/$(id -u)/com.agentforge.smartproxy
rm ~/Library/LaunchAgents/com.agentforge.smartproxy.plist

# Restart nextgen-plaid (will work without SmartProxy if needed)
launchctl kickstart -k gui/$(id -u)/com.agentforge.nextgen-plaid
```

---

## Success Criteria

- [ ] SmartProxy responds to `curl http://localhost:3002/health`
- [ ] Model listing works: `/v1/models` returns JSON
- [ ] Chat completions work with Ollama, Claude, and Grok
- [ ] NextGen Plaid health check passes
- [ ] NextGen Plaid can successfully call SmartProxy API
- [ ] No errors in SmartProxy logs
- [ ] No errors in NextGen Plaid logs
- [ ] Services survive reboot (optional but recommended test)

---

## Log Locations

**SmartProxy:**
- Application: `/Users/ericsmith66/Development/SmartProxy/log/smart_proxy.log`
- Puma stdout: `/Users/ericsmith66/Development/SmartProxy/log/puma.stdout.log`
- Puma stderr: `/Users/ericsmith66/Development/SmartProxy/log/puma.stderr.log`
- LaunchAgent: `/Users/ericsmith66/Development/SmartProxy/log/launchd.stderr.log`

**NextGen Plaid (unchanged):**
- Application: `/Users/ericsmith66/Development/nextgen-plaid/log/production.log`
- LaunchAgent: `/Users/ericsmith66/Development/nextgen-plaid/log/launchd.stderr.log`

---

## Risk Assessment

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| SmartProxy won't start | Low | Medium | Detailed troubleshooting in plan, manual start script for debugging |
| NextGen Plaid can't connect | Low | High | SmartProxy uses same port, API is identical, rollback available |
| Port conflict | Very Low | Medium | Port 3002 currently in use by embedded version, just replacing it |
| Secrets not found | Low | High | Explicit keychain setup steps, verification commands |
| Rollback needed | Low | Low | Simple rollback procedure, can restore embedded version |

**Overall Risk:** Low - This is a service relocation with 100% API compatibility.

---

## Support

**Full Deployment Plan:** `/Users/ericsmith66/development/agent-forge/projects/overwatch/docs/deployment/deployment-smartproxy.md`

**Questions/Issues:**
- Check SmartProxy logs first
- Review troubleshooting section in full deployment plan
- Test manually: `./bin/start-production.sh` to see live errors

---

**Prepared By:** AiderDesk (DevOps Agent)  
**Review Status:** Ready for Execution  
**Approval Required:** Yes (Eric) - Review and confirm secrets before executing Step 2.3
