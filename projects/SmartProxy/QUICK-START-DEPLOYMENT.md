# SmartProxy Quick Start Deployment Guide

This guide provides a quick reference for deploying SmartProxy to the production server.

## Prerequisites

1. SSH access to `192.168.4.253` as user `ericsmith66`
2. Secrets stored in local macOS Keychain under account `nextgen-plaid`:
   - `GROK_API_KEY`
   - `CLAUDE_API_KEY`
   - `PROXY_AUTH_TOKEN`
3. Ruby 3.3.0+ installed on remote server
4. Bundler installed on remote server

## Quick Deployment (Automated)

### 1. Make deploy script executable
```bash
chmod +x /Users/ericsmith66/development/agent-forge/projects/SmartProxy/bin/deploy.sh
```

### 2. Run deployment
```bash
cd /Users/ericsmith66/development/agent-forge/projects/SmartProxy
./bin/deploy.sh
```

The script will:
- ✓ Create deployment package (excludes .git, logs, etc.)
- ✓ Extract secrets from local keychain
- ✓ Test SSH connection
- ✓ Transfer package to remote server
- ✓ Install Ruby dependencies
- ✓ Setup secrets in remote keychain
- ✓ Create production configuration
- ✓ Setup Puma and launchd service
- ✓ Start the service
- ✓ Verify deployment

**Total time:** ~2-3 minutes

## Manual Deployment (Step-by-Step)

If you prefer manual deployment or need to troubleshoot, follow the detailed steps in [DEPLOYMENT-PLAN.md](DEPLOYMENT-PLAN.md).

## Post-Deployment Verification

### 1. Check service status
```bash
ssh ericsmith66@192.168.4.253 "launchctl list | grep smartproxy"
```

### 2. Test health endpoint
```bash
curl http://192.168.4.253:8080/health
# Expected: {"status":"ok"}
```

### 3. Test API endpoint
```bash
curl http://192.168.4.253:8080/v1/models \
  -H "Authorization: Bearer c2708a90c1fde993a6a7cb8bde2a4d1db708b91937ce1e228f6e4ba7b6891ad4"
```

### 4. View logs
```bash
# Application logs
ssh ericsmith66@192.168.4.253 "tail -f /Users/ericsmith66/Development/SmartProxy/log/smart_proxy.log"

# Puma logs
ssh ericsmith66@192.168.4.253 "tail -f /Users/ericsmith66/Development/SmartProxy/log/puma.stdout.log"
```

## Common Management Commands

All commands should be run on the remote server via SSH:

```bash
# Start service
launchctl start com.agentforge.smartproxy

# Stop service
launchctl stop com.agentforge.smartproxy

# Restart service
launchctl kickstart -k com.agentforge.smartproxy

# Check status
launchctl list | grep smartproxy
ps aux | grep smartproxy

# View logs
tail -f /Users/ericsmith66/Development/SmartProxy/log/smart_proxy.log
tail -f /Users/ericsmith66/Development/SmartProxy/log/puma.stdout.log
```

## Redeployment / Updates

To redeploy after making changes:

```bash
cd /Users/ericsmith66/development/agent-forge/projects/SmartProxy
./bin/deploy.sh
```

The script will:
1. Stop the existing service
2. Create new deployment package
3. Transfer and extract
4. Restart the service

**Note:** No downtime mitigation in basic deployment. For zero-downtime updates, see blue-green deployment section in DEPLOYMENT-PLAN.md.

## Rollback

If deployment fails or issues are detected:

```bash
# On remote server
launchctl stop com.agentforge.smartproxy

# Restore from backup
cd /Users/ericsmith66/Backups/SmartProxy
tar -xzf smartproxy-backup-YYYYMMDD-HHMMSS.tar.gz -C /

# Restart
launchctl start com.agentforge.smartproxy
```

## Troubleshooting

### Service won't start
```bash
# Check logs for errors
ssh ericsmith66@192.168.4.253 "tail -100 /Users/ericsmith66/Development/SmartProxy/log/puma.stderr.log"

# Check if port is already in use
ssh ericsmith66@192.168.4.253 "lsof -i :8080"

# Verify secrets are set
ssh ericsmith66@192.168.4.253 "security find-generic-password -a 'smartproxy' -s 'smartproxy-GROK_API_KEY'"
```

### Health endpoint not responding
```bash
# Check if process is running
ssh ericsmith66@192.168.4.253 "ps aux | grep puma | grep SmartProxy"

# Test locally on server
ssh ericsmith66@192.168.4.253 "curl http://localhost:8080/health"

# Check firewall
ssh ericsmith66@192.168.4.253 "sudo pfctl -s rules | grep 8080"
```

### API authentication failures
```bash
# Verify PROXY_AUTH_TOKEN is set correctly
ssh ericsmith66@192.168.4.253 "security find-generic-password -a 'smartproxy' -s 'smartproxy-PROXY_AUTH_TOKEN' -w"

# Test with token from local keychain
TOKEN=$(security find-generic-password -a 'nextgen-plaid' -s 'PROXY_AUTH_TOKEN' -w)
curl http://192.168.4.253:8080/v1/models -H "Authorization: Bearer $TOKEN"
```

## Emergency Contacts

| Issue | Action |
|-------|--------|
| Service down | Check logs, restart service, contact ops |
| API errors | Check provider status pages, verify API keys |
| Performance issues | Check server resources, review logs |
| Security incident | Rotate API keys immediately, check access logs |

## Additional Resources

- **Full Deployment Plan:** [DEPLOYMENT-PLAN.md](DEPLOYMENT-PLAN.md)
- **Operations Runbook:** [RUNBOOK.md](RUNBOOK.md)
- **README:** [README.md](README.md)
- **Agent Forge Integration:** [../../knowledge_base/smart-proxy.md](../../knowledge_base/smart-proxy.md)

---

**Last Updated:** February 23, 2026  
**Maintainer:** Agent Forge Team
