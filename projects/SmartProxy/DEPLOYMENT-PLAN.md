# SmartProxy Deployment Plan

**Target Server:** 192.168.4.253 (M3 Ultra)  
**User:** ericsmith66  
**Current Location:** `/Users/ericsmith66/development/agent-forge/projects/SmartProxy`  
**Target Location:** `/Users/ericsmith66/Development/SmartProxy`  
**Port:** 8080 (production) / 3002 (development)  
**Status:** Currently part of agent-forge, needs independent deployment

---

## Current State Analysis

### Project Structure
```
projects/SmartProxy/
├── app.rb              # Main Sinatra application
├── config.ru           # Rack configuration
├── Gemfile             # Ruby dependencies
├── Gemfile.lock        # Locked dependency versions
├── .env                # Environment variables (LOCAL - DO NOT DEPLOY)
├── .env.example        # Environment template
├── lib/                # Core libraries
│   ├── grok_client.rb
│   ├── claude_client.rb
│   ├── ollama_client.rb
│   ├── tool_client.rb
│   ├── tool_executor.rb
│   ├── tool_orchestrator.rb
│   ├── model_router.rb
│   ├── model_aggregator.rb
│   ├── anonymizer.rb
│   ├── response_transformer.rb
│   ├── request_authenticator.rb
│   └── live_search.rb
├── spec/               # RSpec tests
├── RUNBOOK.md          # Operations runbook
└── README.md           # Project documentation

### Dependencies (from Gemfile)
- sinatra           # Web framework
- puma              # Application server
- faraday           # HTTP client
- faraday-retry     # Retry logic
- json              # JSON parsing
- dotenv            # Environment variable management
- rackup            # Rack server
```

### Environment Variables Required
```bash
# LLM Provider API Keys
GROK_API_KEY=<from keychain>
CLAUDE_API_KEY=<from keychain>

# Model Configuration
GROK_MODELS=grok-4,grok-4-latest,grok-4-with-live-search
CLAUDE_MODELS=claude-sonnet-4-5-20250929,claude-sonnet-4-20250514,claude-3-5-haiku-20241022,claude-3-haiku-20240307

# Authentication
PROXY_AUTH_TOKEN=<from keychain>

# Server Configuration
SMART_PROXY_PORT=8080
SMART_PROXY_ENABLE_WEB_TOOLS=true

# Logging
SMART_PROXY_LOG_BODY_BYTES=2000
SMART_PROXY_MODELS_CACHE_TTL=60

# Ollama Configuration (optional)
OLLAMA_TAGS_URL=http://localhost:11434/api/tags
```

### Secrets in Keychain
The following secrets are stored in macOS Keychain under nextgen-plaid:
- `GROK_API_KEY`
- `CLAUDE_API_KEY`
- `PROXY_AUTH_TOKEN`

---

## Deployment Strategy

### Phase 1: Preparation (Local)

#### 1.1 Create Deployment Package
```bash
cd /Users/ericsmith66/development/agent-forge/projects/SmartProxy

# Create deployment bundle
tar -czf smartproxy-deployment.tar.gz \
  --exclude='.git' \
  --exclude='.env' \
  --exclude='log/*' \
  --exclude='tmp/*' \
  --exclude='knowledge_base/test_artifacts/*' \
  --exclude='.aider-desk' \
  --exclude='.idea' \
  --exclude='spec' \
  .
```

#### 1.2 Extract Secrets from Keychain
```bash
# Create a temporary secure file with secrets
cat > /tmp/smartproxy-secrets.env << 'EOF'
# SmartProxy Secrets - Retrieved from Keychain
GROK_API_KEY=$(security find-generic-password -a 'nextgen-plaid' -s 'GROK_API_KEY' -w)
CLAUDE_API_KEY=$(security find-generic-password -a 'nextgen-plaid' -s 'CLAUDE_API_KEY' -w)
PROXY_AUTH_TOKEN=$(security find-generic-password -a 'nextgen-plaid' -s 'PROXY_AUTH_TOKEN' -w)
EOF

# Execute to get actual values
source /tmp/smartproxy-secrets.env

# Store in production keychain (will be done on remote server)
# security add-generic-password -a 'smartproxy' -s 'smartproxy-GROK_API_KEY' -w "$GROK_API_KEY"
# security add-generic-password -a 'smartproxy' -s 'smartproxy-CLAUDE_API_KEY' -w "$CLAUDE_API_KEY"
# security add-generic-password -a 'smartproxy' -s 'smartproxy-PROXY_AUTH_TOKEN' -w "$PROXY_AUTH_TOKEN"

# Clean up
rm /tmp/smartproxy-secrets.env
```

### Phase 2: Remote Server Setup

#### 2.1 Create Directory Structure
```bash
ssh ericsmith66@192.168.4.253

# Create application directory
mkdir -p /Users/ericsmith66/Development/SmartProxy
mkdir -p /Users/ericsmith66/Development/SmartProxy/log
mkdir -p /Users/ericsmith66/Development/SmartProxy/tmp
mkdir -p /Users/ericsmith66/Development/SmartProxy/knowledge_base/test_artifacts/llm_calls
```

#### 2.2 Transfer Deployment Package
```bash
# From local machine
scp smartproxy-deployment.tar.gz ericsmith66@192.168.4.253:~/Development/SmartProxy/

# On remote server
cd /Users/ericsmith66/Development/SmartProxy
tar -xzf smartproxy-deployment.tar.gz
rm smartproxy-deployment.tar.gz
```

#### 2.3 Install Ruby & Dependencies
```bash
# On remote server
cd /Users/ericsmith66/Development/SmartProxy

# Check Ruby version (should be 3.3.0 or compatible)
ruby -v

# Install bundler if needed
gem install bundler

# Install dependencies
bundle install --deployment --without test development
```

#### 2.4 Setup Secrets in Keychain
```bash
# On remote server - manually set each secret
# Get values from local keychain first, then run on remote:

# GROK_API_KEY
security add-generic-password -a 'smartproxy' -s 'smartproxy-GROK_API_KEY' -w 'REDACTED_XAI_API_KEY'

# CLAUDE_API_KEY
security add-generic-password -a 'smartproxy' -s 'smartproxy-CLAUDE_API_KEY' -w 'REDACTED_ANTHROPIC_API_KEY'

# PROXY_AUTH_TOKEN
security add-generic-password -a 'smartproxy' -s 'smartproxy-PROXY_AUTH_TOKEN' -w 'c2708a90c1fde993a6a7cb8bde2a4d1db708b91937ce1e228f6e4ba7b6891ad4'
```

#### 2.5 Create Production Environment File
```bash
# On remote server
cat > /Users/ericsmith66/Development/SmartProxy/.env.production << 'EOF'
# SmartProxy Production Configuration
# Secrets are loaded from macOS Keychain

# Server Configuration
SMART_PROXY_PORT=8080
RACK_ENV=production

# Model Configuration
GROK_MODELS=grok-4,grok-4-latest,grok-4-with-live-search
CLAUDE_MODELS=claude-sonnet-4-5-20250929,claude-sonnet-4-20250514,claude-3-5-haiku-20241022,claude-3-haiku-20240307

# Feature Flags
SMART_PROXY_ENABLE_WEB_TOOLS=true

# Logging
SMART_PROXY_LOG_BODY_BYTES=2000
SMART_PROXY_MODELS_CACHE_TTL=60

# Ollama Configuration
OLLAMA_TAGS_URL=http://localhost:11434/api/tags
EOF
```

### Phase 3: Service Configuration

#### 3.1 Create Launch Script
```bash
# On remote server
cat > /Users/ericsmith66/Development/SmartProxy/bin/start-production.sh << 'EOF'
#!/bin/bash
set -e

# Load environment
cd /Users/ericsmith66/Development/SmartProxy
export RACK_ENV=production

# Load secrets from keychain
export GROK_API_KEY=$(security find-generic-password -a 'smartproxy' -s 'smartproxy-GROK_API_KEY' -w)
export CLAUDE_API_KEY=$(security find-generic-password -a 'smartproxy' -s 'smartproxy-CLAUDE_API_KEY' -w)
export PROXY_AUTH_TOKEN=$(security find-generic-password -a 'smartproxy' -s 'smartproxy-PROXY_AUTH_TOKEN' -w)

# Load other environment variables
set -a
source .env.production
set +a

# Start server with Puma
bundle exec puma -C config/puma.rb
EOF

chmod +x /Users/ericsmith66/Development/SmartProxy/bin/start-production.sh
```

#### 3.2 Create Puma Configuration
```bash
# On remote server
mkdir -p /Users/ericsmith66/Development/SmartProxy/config

cat > /Users/ericsmith66/Development/SmartProxy/config/puma.rb << 'EOF'
#!/usr/bin/env puma

# Puma configuration for SmartProxy production

# Application root
app_dir = File.expand_path("../..", __FILE__)
directory app_dir

# Environment
environment ENV.fetch("RACK_ENV") { "production" }

# Port
port ENV.fetch("SMART_PROXY_PORT") { 8080 }

# Threads
threads_count = ENV.fetch("PUMA_THREADS") { 5 }.to_i
threads threads_count, threads_count

# Workers
workers ENV.fetch("PUMA_WORKERS") { 2 }.to_i

# Preload application
preload_app!

# Bind
bind "tcp://0.0.0.0:#{ENV.fetch('SMART_PROXY_PORT') { 8080 }}"

# Logging
stdout_redirect "#{app_dir}/log/puma.stdout.log", "#{app_dir}/log/puma.stderr.log", true

# Pidfile
pidfile "#{app_dir}/tmp/puma.pid"

# State
state_path "#{app_dir}/tmp/puma.state"

# Daemonize
daemonize true

# On worker boot
on_worker_boot do
  # Worker specific setup
end
EOF
```

#### 3.3 Create launchd Service (macOS)
```bash
# On remote server
cat > ~/Library/LaunchAgents/com.agentforge.smartproxy.plist << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.agentforge.smartproxy</string>
    
    <key>ProgramArguments</key>
    <array>
        <string>/Users/ericsmith66/Development/SmartProxy/bin/start-production.sh</string>
    </array>
    
    <key>RunAtLoad</key>
    <true/>
    
    <key>KeepAlive</key>
    <dict>
        <key>SuccessfulExit</key>
        <false/>
    </dict>
    
    <key>StandardOutPath</key>
    <string>/Users/ericsmith66/Development/SmartProxy/log/launchd.stdout.log</string>
    
    <key>StandardErrorPath</key>
    <string>/Users/ericsmith66/Development/SmartProxy/log/launchd.stderr.log</string>
    
    <key>WorkingDirectory</key>
    <string>/Users/ericsmith66/Development/SmartProxy</string>
    
    <key>EnvironmentVariables</key>
    <dict>
        <key>PATH</key>
        <string>/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin</string>
    </dict>
</dict>
</plist>
EOF

# Load the service
launchctl load ~/Library/LaunchAgents/com.agentforge.smartproxy.plist
```

### Phase 4: Deployment & Verification

#### 4.1 Start Service
```bash
# On remote server

# Option 1: Using launchd
launchctl start com.agentforge.smartproxy

# Option 2: Manual start for testing
cd /Users/ericsmith66/Development/SmartProxy
./bin/start-production.sh

# Check process
ps aux | grep smartproxy
lsof -i :8080
```

#### 4.2 Health Checks
```bash
# Basic health check
curl http://192.168.4.253:8080/health

# Expected response:
# {"status":"ok"}

# Test model listing
curl http://192.168.4.253:8080/v1/models \
  -H "Authorization: Bearer c2708a90c1fde993a6a7cb8bde2a4d1db708b91937ce1e228f6e4ba7b6891ad4"

# Test chat completion (with Ollama)
curl -X POST http://192.168.4.253:8080/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer c2708a90c1fde993a6a7cb8bde2a4d1db708b91937ce1e228f6e4ba7b6891ad4" \
  -d '{
    "model": "llama3.1:8b",
    "messages": [{"role": "user", "content": "Hello, test message"}]
  }'
```

#### 4.3 Log Verification
```bash
# Check application logs
tail -f /Users/ericsmith66/Development/SmartProxy/log/smart_proxy.log

# Check Puma logs
tail -f /Users/ericsmith66/Development/SmartProxy/log/puma.stdout.log
tail -f /Users/ericsmith66/Development/SmartProxy/log/puma.stderr.log

# Check launchd logs
tail -f /Users/ericsmith66/Development/SmartProxy/log/launchd.stdout.log
tail -f /Users/ericsmith66/Development/SmartProxy/log/launchd.stderr.log
```

### Phase 5: Post-Deployment

#### 5.1 Update RUNBOOK.md
- Update server paths from `/Users/ericsmith66/Development/SmartProxy`
- Confirm all operational procedures work
- Document any deployment-specific configurations

#### 5.2 Configure Monitoring
```bash
# Add to crontab for basic uptime monitoring
crontab -e

# Add line:
*/5 * * * * curl -s http://192.168.4.253:8080/health > /dev/null || echo "SmartProxy down at $(date)" >> /Users/ericsmith66/Development/SmartProxy/log/uptime.log
```

#### 5.3 Backup Strategy
```bash
# Create backup script
cat > /Users/ericsmith66/Development/SmartProxy/bin/backup.sh << 'EOF'
#!/bin/bash
BACKUP_DIR="/Users/ericsmith66/Backups/SmartProxy"
DATE=$(date +%Y%m%d-%H%M%S)

mkdir -p "$BACKUP_DIR"

tar -czf "$BACKUP_DIR/smartproxy-backup-$DATE.tar.gz" \
  --exclude='log/*' \
  --exclude='tmp/*' \
  --exclude='knowledge_base/test_artifacts/*' \
  /Users/ericsmith66/Development/SmartProxy

# Keep only last 7 backups
ls -t "$BACKUP_DIR"/smartproxy-backup-*.tar.gz | tail -n +8 | xargs rm -f
EOF

chmod +x /Users/ericsmith66/Development/SmartProxy/bin/backup.sh

# Add to crontab (daily at 2 AM)
# 0 2 * * * /Users/ericsmith66/Development/SmartProxy/bin/backup.sh
```

---

## Rollback Procedure

### Quick Rollback
```bash
# On remote server
# 1. Stop service
launchctl stop com.agentforge.smartproxy

# 2. Restore from backup
cd /Users/ericsmith66/Backups/SmartProxy
tar -xzf smartproxy-backup-YYYYMMDD-HHMMSS.tar.gz -C /

# 3. Restart service
launchctl start com.agentforge.smartproxy

# 4. Verify
curl http://192.168.4.253:8080/health
```

### Emergency Stop
```bash
# Stop via launchd
launchctl stop com.agentforge.smartproxy

# Force kill if needed
pkill -9 -f "smartproxy"
pkill -9 -f "puma.*SmartProxy"

# Remove PID file
rm /Users/ericsmith66/Development/SmartProxy/tmp/puma.pid
```

---

## Troubleshooting

### Service Won't Start
1. Check Ruby version: `ruby -v` (should be 3.3.0+)
2. Check bundle: `cd /Users/ericsmith66/Development/SmartProxy && bundle check`
3. Check secrets: `security find-generic-password -a 'smartproxy' -s 'smartproxy-GROK_API_KEY' -w`
4. Check port: `lsof -i :8080`
5. Check logs: `tail -100 log/puma.stderr.log`

### API Keys Not Found
```bash
# Verify keychain entries
security find-generic-password -a 'smartproxy' -s 'smartproxy-GROK_API_KEY'
security find-generic-password -a 'smartproxy' -s 'smartproxy-CLAUDE_API_KEY'
security find-generic-password -a 'smartproxy' -s 'smartproxy-PROXY_AUTH_TOKEN'

# Re-add if missing (get values from local machine first)
security add-generic-password -a 'smartproxy' -s 'smartproxy-GROK_API_KEY' -w '<value>'
```

### Connection Refused
1. Verify service is running: `ps aux | grep puma | grep SmartProxy`
2. Check if port is bound: `lsof -i :8080`
3. Check firewall: `sudo pfctl -s rules | grep 8080`
4. Test locally first: `curl http://localhost:8080/health`

---

## Security Considerations

### API Key Rotation
```bash
# 1. Update key in keychain
security delete-generic-password -a 'smartproxy' -s 'smartproxy-GROK_API_KEY'
security add-generic-password -a 'smartproxy' -s 'smartproxy-GROK_API_KEY' -w '<NEW_KEY>'

# 2. Restart service
launchctl kickstart -k com.agentforge.smartproxy
```

### File Permissions
```bash
# Ensure sensitive files are protected
chmod 600 /Users/ericsmith66/Development/SmartProxy/.env.production
chmod 700 /Users/ericsmith66/Development/SmartProxy/bin/start-production.sh
```

### Network Security
- SmartProxy binds to `0.0.0.0:8080` (all interfaces)
- Consider restricting to `127.0.0.1` if only local access needed
- Use firewall rules to limit external access
- PROXY_AUTH_TOKEN required for all non-health endpoints

---

## Deployment Checklist

- [ ] Create deployment package on local machine
- [ ] Extract secrets from local keychain
- [ ] Transfer package to remote server
- [ ] Create directory structure on remote server
- [ ] Extract deployment package
- [ ] Install Ruby dependencies
- [ ] Store secrets in remote keychain
- [ ] Create production environment file
- [ ] Create Puma configuration
- [ ] Create launch script
- [ ] Create launchd service
- [ ] Load launchd service
- [ ] Verify health endpoint
- [ ] Test API endpoints with authentication
- [ ] Verify logging is working
- [ ] Update RUNBOOK.md with production paths
- [ ] Configure monitoring/alerts
- [ ] Setup backup script
- [ ] Document rollback procedure
- [ ] Test rollback procedure

---

## Future Improvements

1. **CI/CD Pipeline**: Automate deployment via GitHub Actions
2. **Blue-Green Deployment**: Zero-downtime deployments
3. **Load Balancing**: Multiple instances behind nginx/HAProxy
4. **Metrics & Monitoring**: Prometheus/Grafana integration
5. **Container Deployment**: Docker/Kubernetes for easier scaling
6. **Secrets Management**: Migrate to Vault or AWS Secrets Manager
7. **SSL/TLS**: Add HTTPS support with Let's Encrypt
8. **Rate Limiting**: Redis-backed rate limiting for API protection

---

## Related Documentation

- [SmartProxy README](README.md)
- [Operations Runbook](RUNBOOK.md)
- [API Documentation](knowledge_base/api-documentation.md)
- [Agent Forge Integration](../../knowledge_base/smart-proxy.md)
