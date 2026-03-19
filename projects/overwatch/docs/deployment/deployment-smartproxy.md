# SmartProxy Deployment Plan

**Project:** SmartProxy (Standalone AI Gateway)  
**Target Server:** 192.168.4.253 (M3 Ultra)  
**User:** ericsmith66  
**Source Location:** `/Users/ericsmith66/development/agent-forge/projects/SmartProxy`  
**Target Location:** `/Users/ericsmith66/Development/SmartProxy`  
**Port:** 3002 (same as current embedded version)  
**Status:** Migration from embedded (nextgen-plaid/smart_proxy/) to standalone service  
**Date Created:** March 2, 2026

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [Current State Analysis](#current-state-analysis)
3. [Target Architecture](#target-architecture)
4. [Prerequisites](#prerequisites)
5. [Deployment Steps](#deployment-steps)
6. [NextGen Plaid Configuration Changes](#nextgen-plaid-configuration-changes)
7. [Verification & Testing](#verification--testing)
8. [Rollback Procedure](#rollback-procedure)
9. [Post-Deployment Operations](#post-deployment-operations)
10. [Troubleshooting](#troubleshooting)

---

## Executive Summary

### Objective
Deploy SmartProxy as a **standalone service** with its own launchd configuration, independent of nextgen-plaid, while maintaining the same port (3002) and API compatibility.

### Current State
- SmartProxy runs **embedded** inside nextgen-plaid at `smart_proxy/` subdirectory
- Started via nextgen-plaid's Procfile.prod as the `proxy:` process (though currently commented out or removed)
- Shares logging directory with nextgen-plaid
- Secrets stored in nextgen-plaid's keychain entries

### Target State
- SmartProxy runs as **standalone service** from `/Users/ericsmith66/Development/SmartProxy`
- Managed by its own launchd plist: `com.agentforge.smartproxy`
- Independent logging under `/Users/ericsmith66/Development/SmartProxy/log/`
- Dedicated keychain entries under account `smartproxy`
- Starts **before** nextgen-plaid (dependency order preserved)

### Key Benefits
1. **Independent deployment** - Update SmartProxy without touching nextgen-plaid
2. **Cleaner dependency management** - SmartProxy becomes a true shared service
3. **Better observability** - Dedicated logs and process management
4. **Reboot resilience** - Auto-starts before dependent services
5. **Easier debugging** - Isolated service with clear boundaries

---

## Current State Analysis

### Project Structure (Standalone Repo)
```
/Users/ericsmith66/development/agent-forge/projects/SmartProxy/
├── app.rb                  # Main Sinatra application
├── config.ru               # Rack configuration
├── Gemfile                 # Ruby dependencies
├── Gemfile.lock            # Locked versions
├── .env.example            # Environment template
├── lib/                    # Core libraries
│   ├── grok_client.rb      # Grok/xAI integration
│   ├── claude_client.rb    # Anthropic Claude integration
│   ├── ollama_client.rb    # Local Ollama integration
│   ├── model_router.rb     # Model routing logic
│   ├── model_aggregator.rb # Model listing aggregation
│   ├── tool_client.rb      # Tool/function calling
│   ├── tool_executor.rb    # Tool execution
│   ├── tool_orchestrator.rb # Tool orchestration loops
│   ├── anonymizer.rb       # PII anonymization
│   ├── response_transformer.rb # Response transformation
│   ├── request_authenticator.rb # Request auth
│   └── live_search.rb      # Web search integration
├── spec/                   # RSpec tests
├── RUNBOOK.md             # Operations documentation
├── README.md              # Project documentation
├── DEPLOYMENT-PLAN.md     # Existing deployment plan (reference)
└── QUICK-START-DEPLOYMENT.md # Quick start guide
```

### Current Dependencies (from Gemfile)
```ruby
gem 'sinatra'           # Web framework
gem 'puma'              # Application server
gem 'faraday'           # HTTP client
gem 'faraday-retry'     # Retry middleware
gem 'json'              # JSON parsing
gem 'dotenv'            # Environment variables
gem 'rackup'            # Rack server
```

### Current Port Configuration
- **Port 3002** - SmartProxy HTTP API
- **Port 11434** - Ollama (upstream dependency)

### Consumers
- **nextgen-plaid** - Primary consumer via:
  - `AgentHub::SmartProxyClient` (connects via `OPENAI_API_BASE`)
  - `AiFinancialAdvisor` (connects via `SMART_PROXY_PORT`)
  - `admin/health_controller.rb` (health checks)
- **Future**: eureka-homekit (planned but not yet integrated)

---

## Target Architecture

### Service Dependency Order
```
Boot Sequence:
1. PostgreSQL (Homebrew LaunchAgent) - Port 5432
2. Redis (Homebrew LaunchAgent) - Port 6379
3. Ollama (macOS LaunchAgent) - Port 11434
4. SmartProxy (launchd) - Port 3002  ← NEW STANDALONE SERVICE
5. NextGen Plaid (launchd) - Port 3000
6. (Future) Eureka HomeKit - Port 3001
```

### Network Architecture
```
┌─────────────────────────────────────────────────────┐
│ Internet                                            │
└─────────────────┬───────────────────────────────────┘
                  │
┌─────────────────▼───────────────────────────────────┐
│ Cloudflare (SSL, DDoS, WAF)                         │
└─────────────────┬───────────────────────────────────┘
                  │
┌─────────────────▼───────────────────────────────────┐
│ UDM-SE (Firewall, Port Forwarding)                  │
│  - Port 443 → 192.168.4.253:443                     │
│  - Port 80 → 192.168.4.253:80 (legacy)              │
└─────────────────┬───────────────────────────────────┘
                  │
┌─────────────────▼───────────────────────────────────┐
│ 192.168.4.253 (M3 Ultra - Production Server)        │
│                                                      │
│  ┌───────────────────────────────────────────────┐  │
│  │ Nginx (Reverse Proxy) - Port 443 & 80        │  │
│  │  - Terminates SSL                             │  │
│  │  - Routes to backend services                 │  │
│  └───┬────────────────────────────────────────┬──┘  │
│      │                                        │      │
│  ┌───▼────────────────────┐    ┌─────────────▼───┐  │
│  │ NextGen Plaid          │    │ (Future Apps)   │  │
│  │ Port 3000              │    │                 │  │
│  │ (Rails + Puma)         │    └─────────────────┘  │
│  │                        │                         │
│  │  Uses SmartProxy API   │                         │
│  └───┬────────────────────┘                         │
│      │                                               │
│      │ HTTP localhost:3002                           │
│      │                                               │
│  ┌───▼────────────────────────────────────────────┐ │
│  │ SmartProxy (Standalone)                        │ │
│  │ Port 3002                                      │ │
│  │ (Sinatra + Puma)                               │ │
│  │                                                │ │
│  │  ┌──────────────────────────────────────────┐ │ │
│  │  │ Model Router & Aggregator                │ │ │
│  │  │  - Routes to Claude, Grok, or Ollama     │ │ │
│  │  │  - Aggregates model listings             │ │ │
│  │  └──┬───────────────┬──────────────┬────────┘ │ │
│  │     │               │              │          │ │
│  └─────┼───────────────┼──────────────┼──────────┘ │
│        │               │              │            │
│  ┌─────▼─────────┐ ┌───▼──────────┐ ┌▼──────────┐ │
│  │ Claude API    │ │ Grok/xAI API │ │ Ollama    │ │
│  │ (External)    │ │ (External)   │ │ (Local)   │ │
│  │               │ │              │ │ Port 11434│ │
│  └───────────────┘ └──────────────┘ └───────────┘ │
│                                                     │
│  ┌──────────────────────────────────────────────┐  │
│  │ PostgreSQL 16 - Port 5432 (Homebrew)         │  │
│  └──────────────────────────────────────────────┘  │
│                                                     │
│  ┌──────────────────────────────────────────────┐  │
│  │ Redis 7 - Port 6379 (Homebrew)               │  │
│  └──────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────┘
```

### File System Layout
```
/Users/ericsmith66/Development/
├── SmartProxy/                          ← NEW STANDALONE SERVICE
│   ├── app.rb
│   ├── config.ru
│   ├── Gemfile
│   ├── Gemfile.lock
│   ├── .env.production                  ← Production config
│   ├── bin/
│   │   └── start-production.sh          ← Startup script
│   ├── lib/                             ← All core libraries
│   ├── log/                             ← Dedicated logs
│   │   ├── smart_proxy.log              ← Application log (JSON)
│   │   ├── puma.stdout.log              ← Puma stdout
│   │   ├── puma.stderr.log              ← Puma stderr
│   │   └── launchd.stderr.log           ← LaunchAgent errors
│   ├── tmp/
│   │   ├── puma.pid
│   │   └── puma.state
│   └── knowledge_base/
│       └── test_artifacts/
│           └── llm_calls/               ← Request/response artifacts
│
└── nextgen-plaid/
    ├── (no more smart_proxy/ subdirectory)
    ├── Procfile.prod                    ← REMOVE 'proxy:' line
    └── .env.production                  ← UPDATE SMART_PROXY_PORT=3002
```

### Log Locations
```
SmartProxy Logs:
  Application:  /Users/ericsmith66/Development/SmartProxy/log/smart_proxy.log
  Puma stdout:  /Users/ericsmith66/Development/SmartProxy/log/puma.stdout.log
  Puma stderr:  /Users/ericsmith66/Development/SmartProxy/log/puma.stderr.log
  LaunchAgent:  /Users/ericsmith66/Development/SmartProxy/log/launchd.stderr.log
  Artifacts:    /Users/ericsmith66/Development/SmartProxy/knowledge_base/test_artifacts/llm_calls/

NextGen Plaid Logs (unchanged):
  Application:  /Users/ericsmith66/Development/nextgen-plaid/log/production.log
  Puma stdout:  /Users/ericsmith66/Development/nextgen-plaid/log/launchd.stdout.log
  LaunchAgent:  /Users/ericsmith66/Development/nextgen-plaid/log/launchd.stderr.log
```

---

## Prerequisites

### Required Secrets (from nextgen-plaid Keychain)
Extract these values from existing keychain before deployment:

```bash
# Extract from existing nextgen-plaid keychain
GROK_API_KEY=$(security find-generic-password -a 'nextgen-plaid' -s 'GROK_API_KEY' -w)
CLAUDE_API_KEY=$(security find-generic-password -a 'nextgen-plaid' -s 'CLAUDE_API_KEY' -w)
PROXY_AUTH_TOKEN=$(security find-generic-password -a 'nextgen-plaid' -s 'PROXY_AUTH_TOKEN' -w)
```

### Required Software (Already Installed)
- Ruby 3.3.0+ (via rbenv)
- Bundler
- PostgreSQL 16 (Homebrew)
- Redis 7 (Homebrew)
- Ollama (macOS app)

### Network Requirements
- Port 3002 must be free (currently used by embedded SmartProxy)
- Port 11434 must be accessible (Ollama)
- No external firewall changes needed (SmartProxy is localhost-only)

---

## Deployment Steps

### Phase 1: Prepare Local Development Machine

#### Step 1.1: Extract Secrets from Keychain
```bash
# On LOCAL development machine
cd /Users/ericsmith66/development/agent-forge/projects/SmartProxy

# Extract secrets (will be transferred to production manually)
echo "Extracting secrets from keychain..."

GROK_API_KEY=$(security find-generic-password -a 'nextgen-plaid' -s 'GROK_API_KEY' -w 2>/dev/null || echo "")
CLAUDE_API_KEY=$(security find-generic-password -a 'nextgen-plaid' -s 'CLAUDE_API_KEY' -w 2>/dev/null || echo "")
PROXY_AUTH_TOKEN=$(security find-generic-password -a 'nextgen-plaid' -s 'PROXY_AUTH_TOKEN' -w 2>/dev/null || echo "")

# Display for manual transfer (DO NOT COMMIT)
echo ""
echo "==================================================================="
echo "SECRETS FOR PRODUCTION DEPLOYMENT (Copy these manually to prod)"
echo "==================================================================="
echo "GROK_API_KEY=${GROK_API_KEY}"
echo "CLAUDE_API_KEY=${CLAUDE_API_KEY}"
echo "PROXY_AUTH_TOKEN=${PROXY_AUTH_TOKEN}"
echo "==================================================================="
echo ""
echo "⚠️  Save these temporarily in a secure location for Step 2.3"
```

#### Step 1.2: Create Production-Ready Deployment Package
```bash
# On LOCAL development machine
cd /Users/ericsmith66/development/agent-forge/projects/SmartProxy

# Create deployment tarball (excludes dev files)
tar -czf /tmp/smartproxy-deployment.tar.gz \
  --exclude='.git' \
  --exclude='.env' \
  --exclude='.env.local' \
  --exclude='log/*' \
  --exclude='tmp/*' \
  --exclude='knowledge_base/test_artifacts/*' \
  --exclude='.aider-desk' \
  --exclude='.idea' \
  --exclude='spec' \
  --exclude='.rspec' \
  --exclude='*.swp' \
  --exclude='*.swo' \
  --exclude='.DS_Store' \
  .

echo "✅ Deployment package created: /tmp/smartproxy-deployment.tar.gz"
ls -lh /tmp/smartproxy-deployment.tar.gz
```

---

### Phase 2: Deploy to Production Server

#### Step 2.1: Create Directory Structure on Production
```bash
# SSH to production
ssh ericsmith66@192.168.4.253

# Create directory structure
mkdir -p /Users/ericsmith66/Development/SmartProxy/{log,tmp,knowledge_base/test_artifacts/llm_calls,bin}

# Verify
ls -la /Users/ericsmith66/Development/SmartProxy/
```

#### Step 2.2: Transfer Deployment Package
```bash
# From LOCAL machine, transfer package
scp /tmp/smartproxy-deployment.tar.gz ericsmith66@192.168.4.253:/tmp/

# On PRODUCTION, extract package
ssh ericsmith66@192.168.4.253

cd /Users/ericsmith66/Development/SmartProxy
tar -xzf /tmp/smartproxy-deployment.tar.gz
rm /tmp/smartproxy-deployment.tar.gz

# Verify extraction
ls -la
# Should see: app.rb, config.ru, Gemfile, lib/, etc.
```

#### Step 2.3: Setup Secrets in Production Keychain
```bash
# On PRODUCTION server (192.168.4.253)
# Use values from Step 1.1

# Add SmartProxy-specific keychain entries
security add-generic-password \
  -a 'smartproxy' \
  -s 'smartproxy-GROK_API_KEY' \
  -w 'REDACTED_XAI_API_KEY' \
  -T /usr/bin/security

security add-generic-password \
  -a 'smartproxy' \
  -s 'smartproxy-CLAUDE_API_KEY' \
  -w 'REDACTED_ANTHROPIC_API_KEY' \
  -T /usr/bin/security

security add-generic-password \
  -a 'smartproxy' \
  -s 'smartproxy-PROXY_AUTH_TOKEN' \
  -w 'c2708a90c1fde993a6a7cb8bde2a4d1db708b91937ce1e228f6e4ba7b6891ad4' \
  -T /usr/bin/security

# Verify secrets were stored
security find-generic-password -a 'smartproxy' -s 'smartproxy-GROK_API_KEY' | grep "account:"
security find-generic-password -a 'smartproxy' -s 'smartproxy-CLAUDE_API_KEY' | grep "account:"
security find-generic-password -a 'smartproxy' -s 'smartproxy-PROXY_AUTH_TOKEN' | grep "account:"

echo "✅ Secrets stored in keychain under account 'smartproxy'"
```

#### Step 2.4: Create Production Environment File
```bash
# On PRODUCTION server
cat > /Users/ericsmith66/Development/SmartProxy/.env.production << 'EOF'
# SmartProxy Production Configuration
# Created: 2026-03-02
# Secrets loaded from macOS Keychain (account: smartproxy)

# Server Configuration
SMART_PROXY_PORT=3002
RACK_ENV=production

# Model Configuration
GROK_MODELS=grok-4,grok-4-latest,grok-4-with-live-search
CLAUDE_MODELS=claude-sonnet-4-5-20250929,claude-sonnet-4-20250514,claude-3-5-haiku-20241022,claude-3-haiku-20240307

# Feature Flags
SMART_PROXY_ENABLE_WEB_TOOLS=true

# Logging Configuration
SMART_PROXY_LOG_BODY_BYTES=2000
SMART_PROXY_MODELS_CACHE_TTL=60

# Ollama Configuration (Local)
OLLAMA_TAGS_URL=http://localhost:11434/api/tags

# Puma Configuration
PUMA_THREADS=5
PUMA_WORKERS=2
EOF

# Secure the file
chmod 600 /Users/ericsmith66/Development/SmartProxy/.env.production

# Backup
cp /Users/ericsmith66/Development/SmartProxy/.env.production \
   ~/.env.smartproxy.production.backup.$(date +%Y%m%d_%H%M%S)

echo "✅ Production environment file created and backed up"
```

#### Step 2.5: Install Ruby Dependencies
```bash
# On PRODUCTION server
cd /Users/ericsmith66/Development/SmartProxy

# Ensure correct Ruby version
ruby -v
# Should show: ruby 3.3.x

# Install Bundler if needed
gem list | grep bundler || gem install bundler

# Install dependencies (production mode)
bundle config set --local deployment 'true'
bundle config set --local without 'development test'
bundle install

# Verify installation
bundle check

echo "✅ Dependencies installed"
```

#### Step 2.6: Create Startup Script
```bash
# On PRODUCTION server
cat > /Users/ericsmith66/Development/SmartProxy/bin/start-production.sh << 'EOF'
#!/bin/bash
# SmartProxy Production Startup Script
# Version: 1.0
# Date: 2026-03-02

set -e

# Change to application directory
cd /Users/ericsmith66/Development/SmartProxy

# Set environment
export RACK_ENV=production
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

# Load secrets from keychain
export GROK_API_KEY=$(security find-generic-password -a 'smartproxy' -s 'smartproxy-GROK_API_KEY' -w)
export CLAUDE_API_KEY=$(security find-generic-password -a 'smartproxy' -s 'smartproxy-CLAUDE_API_KEY' -w)
export PROXY_AUTH_TOKEN=$(security find-generic-password -a 'smartproxy' -s 'smartproxy-PROXY_AUTH_TOKEN' -w)

# Load other environment variables from .env.production
if [ -f .env.production ]; then
  set -a
  source .env.production
  set +a
else
  echo "ERROR: .env.production not found" >&2
  exit 1
fi

# Verify required secrets are loaded
if [ -z "$GROK_API_KEY" ] || [ -z "$CLAUDE_API_KEY" ] || [ -z "$PROXY_AUTH_TOKEN" ]; then
  echo "ERROR: One or more required secrets not found in keychain" >&2
  echo "  GROK_API_KEY: ${GROK_API_KEY:+SET}" >&2
  echo "  CLAUDE_API_KEY: ${CLAUDE_API_KEY:+SET}" >&2
  echo "  PROXY_AUTH_TOKEN: ${PROXY_AUTH_TOKEN:+SET}" >&2
  exit 1
fi

# Start Puma
exec bundle exec puma -C config/puma.rb
EOF

# Make executable
chmod +x /Users/ericsmith66/Development/SmartProxy/bin/start-production.sh

echo "✅ Startup script created"
```

#### Step 2.7: Create Puma Configuration
```bash
# On PRODUCTION server
mkdir -p /Users/ericsmith66/Development/SmartProxy/config

cat > /Users/ericsmith66/Development/SmartProxy/config/puma.rb << 'EOF'
#!/usr/bin/env puma
# SmartProxy Puma Configuration (Production)
# Version: 1.0
# Date: 2026-03-02

# Application root
app_dir = File.expand_path('../..', __FILE__)
directory app_dir

# Environment
environment ENV.fetch('RACK_ENV') { 'production' }

# Port
port ENV.fetch('SMART_PROXY_PORT') { 3002 }

# Threads
threads_count = ENV.fetch('PUMA_THREADS') { 5 }.to_i
threads threads_count, threads_count

# Workers
workers ENV.fetch('PUMA_WORKERS') { 2 }.to_i

# Preload application for faster worker boot
preload_app!

# Bind to all interfaces (allows nextgen-plaid on localhost to connect)
bind "tcp://0.0.0.0:#{ENV.fetch('SMART_PROXY_PORT') { 3002 }}"

# Logging
stdout_redirect(
  "#{app_dir}/log/puma.stdout.log",
  "#{app_dir}/log/puma.stderr.log",
  true
)

# Pidfile
pidfile "#{app_dir}/tmp/puma.pid"

# State file
state_path "#{app_dir}/tmp/puma.state"

# Daemonize (run in background)
daemonize false  # LaunchAgent manages daemonization

# On worker boot
on_worker_boot do
  # Worker-specific setup if needed
end

# On restart
on_restart do
  puts "Restarting SmartProxy..."
end
EOF

echo "✅ Puma configuration created"
```

#### Step 2.8: Create LaunchAgent Plist
```bash
# On PRODUCTION server
cat > ~/Library/LaunchAgents/com.agentforge.smartproxy.plist << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>com.agentforge.smartproxy</string>

  <key>ProgramArguments</key>
  <array>
    <string>/bin/bash</string>
    <string>-l</string>
    <string>-c</string>
    <string>cd /Users/ericsmith66/Development/SmartProxy &amp;&amp; exec bin/start-production.sh 2>&amp;1</string>
  </array>

  <key>WorkingDirectory</key>
  <string>/Users/ericsmith66/Development/SmartProxy</string>

  <key>RunAtLoad</key>
  <true/>

  <key>KeepAlive</key>
  <dict>
    <key>SuccessfulExit</key>
    <false/>
  </dict>

  <key>ThrottleInterval</key>
  <integer>10</integer>

  <key>StandardOutPath</key>
  <string>/Users/ericsmith66/Development/SmartProxy/log/launchd.stdout.log</string>

  <key>StandardErrorPath</key>
  <string>/Users/ericsmith66/Development/SmartProxy/log/launchd.stderr.log</string>

  <key>EnvironmentVariables</key>
  <dict>
    <key>PATH</key>
    <string>/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin</string>
    <key>HOME</key>
    <string>/Users/ericsmith66</string>
  </dict>

  <key>ProcessType</key>
  <string>Interactive</string>
</dict>
</plist>
EOF

# Set proper permissions
chmod 644 ~/Library/LaunchAgents/com.agentforge.smartproxy.plist

echo "✅ LaunchAgent plist created"
```

#### Step 2.9: Load and Start SmartProxy Service
```bash
# On PRODUCTION server

# Stop any existing embedded SmartProxy (if running via nextgen-plaid)
# This will be handled when we update nextgen-plaid's Procfile.prod

# Load the new LaunchAgent
launchctl bootout gui/$(id -u)/com.agentforge.smartproxy 2>/dev/null || true
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.agentforge.smartproxy.plist

# Give it a few seconds to start
sleep 5

# Verify it's running
launchctl list | grep smartproxy

# Check process
ps aux | grep -i smartproxy | grep -v grep

# Check port
lsof -nP -iTCP:3002 -sTCP:LISTEN

echo "✅ SmartProxy service started"
```

#### Step 2.10: Verify SmartProxy Health
```bash
# On PRODUCTION server

# Health check (no auth required)
curl -s http://localhost:3002/health

# Expected output: {"status":"ok"}

# Model listing (requires auth)
curl -s http://localhost:3002/v1/models \
  -H "Authorization: Bearer c2708a90c1fde993a6a7cb8bde2a4d1db708b91937ce1e228f6e4ba7b6891ad4"

# Should return JSON with model list

# Test Ollama integration
curl -s -X POST http://localhost:3002/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer c2708a90c1fde993a6a7cb8bde2a4d1db708b91937ce1e228f6e4ba7b6891ad4" \
  -d '{
    "model": "llama3.1:70b",
    "messages": [{"role": "user", "content": "Hello from standalone SmartProxy!"}],
    "max_tokens": 50
  }'

# Check logs
tail -20 /Users/ericsmith66/Development/SmartProxy/log/smart_proxy.log
tail -20 /Users/ericsmith66/Development/SmartProxy/log/puma.stdout.log

echo "✅ SmartProxy health verified"
```

---

### Phase 3: Update NextGen Plaid Configuration

#### Step 3.1: Remove Embedded SmartProxy from NextGen Plaid
```bash
# On PRODUCTION server
cd /Users/ericsmith66/Development/nextgen-plaid

# Backup current state
git status
git stash save "backup-before-smartproxy-extraction-$(date +%Y%m%d_%H%M%S)"

# The smart_proxy/ directory may already be removed from git
# If it exists in the working directory, remove it
if [ -d "smart_proxy" ]; then
  echo "Removing embedded smart_proxy directory..."
  rm -rf smart_proxy
fi
```

#### Step 3.2: Update NextGen Plaid Procfile.prod
```bash
# On PRODUCTION server
cd /Users/ericsmith66/Development/nextgen-plaid

# Check current Procfile.prod
cat Procfile.prod

# It should already NOT have a 'proxy:' line
# If it does, remove it:
# (Normally this is already done, but confirm)

# Verify Procfile.prod only has:
# web: env PORT=3000 bin/rails server -e production -b 0.0.0.0
# worker: bin/rails solid_queue:start
```

**Expected Procfile.prod:**
```
# Production Process Definitions
# Phase 1: Foreman-based process management
#
# Usage: foreman start -f Procfile.prod
#
# Processes:
#   web    - Puma web server (port 3000)
#   worker - SolidQueue background job processor
#
# Future (Phase 2): Will migrate to individual launchd plists

web: env PORT=3000 bin/rails server -e production -b 0.0.0.0
worker: bin/rails solid_queue:start
```

#### Step 3.3: Verify NextGen Plaid Environment Variables
```bash
# On PRODUCTION server
cd /Users/ericsmith66/Development/nextgen-plaid

# Check .env.production for SmartProxy configuration
grep SMART_PROXY .env.production || echo "# SmartProxy settings not found - may need to add"

# Ensure these are set:
# SMART_PROXY_PORT=3002
# SMART_PROXY_AUTH_TOKEN=<token>  (if used by Rails client)

# If missing, add them:
cat >> .env.production << 'EOF'

# SmartProxy Configuration (Standalone Service)
SMART_PROXY_PORT=3002
OPENAI_API_BASE=http://localhost:3002/v1
EOF
```

#### Step 3.4: Restart NextGen Plaid
```bash
# On PRODUCTION server

# Restart nextgen-plaid via launchd
launchctl kickstart -k gui/$(id -u)/com.agentforge.nextgen-plaid

# Give it time to restart
sleep 10

# Verify it started
launchctl list | grep nextgen-plaid

# Check process
ps aux | grep puma | grep production

# Check logs for any SmartProxy connection issues
tail -50 /Users/ericsmith66/Development/nextgen-plaid/log/production.log | grep -i smart
```

---

## Verification & Testing

### Test 1: Service Health Checks
```bash
# On PRODUCTION server

echo "=== Service Health Checks ==="

# 1. SmartProxy
echo "1. SmartProxy Health:"
curl -s http://localhost:3002/health || echo "FAIL"

# 2. NextGen Plaid
echo "2. NextGen Plaid Health:"
curl -s "http://localhost:3000/health?token=$(grep HEALTH_TOKEN /Users/ericsmith66/Development/nextgen-plaid/.env.production | cut -d'=' -f2 | tr -d '\"')" || echo "FAIL"

# 3. Port bindings
echo "3. Port Bindings:"
lsof -nP -iTCP -sTCP:LISTEN | grep -E ":(3000|3002|11434) "
```

### Test 2: SmartProxy API Functionality
```bash
# On PRODUCTION server

# Test model listing
echo "=== Testing Model Listing ==="
curl -s http://localhost:3002/v1/models \
  -H "Authorization: Bearer c2708a90c1fde993a6a7cb8bde2a4d1db708b91937ce1e228f6e4ba7b6891ad4" \
  | jq '.data[].id'

# Test Ollama chat completion
echo "=== Testing Ollama Integration ==="
curl -s -X POST http://localhost:3002/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer c2708a90c1fde993a6a7cb8bde2a4d1db708b91937ce1e228f6e4ba7b6891ad4" \
  -d '{
    "model": "llama3.1:70b",
    "messages": [{"role": "user", "content": "Test message"}],
    "max_tokens": 20
  }' | jq '.choices[0].message.content'
```

### Test 3: NextGen Plaid → SmartProxy Integration
```bash
# On PRODUCTION server or from Rails console

# SSH to production
ssh ericsmith66@192.168.4.253

# Open Rails console
cd /Users/ericsmith66/Development/nextgen-plaid
RAILS_ENV=production bin/rails console

# Test SmartProxy connection
client = AgentHub::SmartProxyClient.new
response = client.chat(
  model: 'llama3.1:70b',
  messages: [{ role: 'user', content: 'Test from Rails console' }]
)
puts response

# Exit console
exit
```

### Test 4: Logging Verification
```bash
# On PRODUCTION server

echo "=== Verifying Logs ==="

# SmartProxy logs
echo "SmartProxy Application Log (last 10 lines):"
tail -10 /Users/ericsmith66/Development/SmartProxy/log/smart_proxy.log

echo "SmartProxy Puma Log (last 10 lines):"
tail -10 /Users/ericsmith66/Development/SmartProxy/log/puma.stdout.log

echo "SmartProxy LaunchAgent Log (last 10 lines):"
tail -10 /Users/ericsmith66/Development/SmartProxy/log/launchd.stderr.log

# Verify no errors
echo "Checking for errors in SmartProxy logs:"
grep -i "error\|fatal\|exception" /Users/ericsmith66/Development/SmartProxy/log/*.log | tail -20
```

### Test 5: Reboot Resilience
```bash
# On PRODUCTION server

echo "⚠️  This test requires a server reboot"
echo "Press ENTER to reboot, or Ctrl+C to skip"
read

# Reboot
sudo reboot

# After reboot, SSH back in and verify:
ssh ericsmith66@192.168.4.253

# Wait 3-5 minutes for all services to start

# Check service status
launchctl list | grep -E "(smartproxy|nextgen-plaid)"

# Verify SmartProxy started before NextGen Plaid
ps aux | grep -E "(puma|smartproxy)" | grep -v grep

# Test health
curl -s http://localhost:3002/health
curl -s "http://localhost:3000/health?token=YOUR_TOKEN"
```

---

## Rollback Procedure

### Scenario 1: SmartProxy Won't Start

```bash
# On PRODUCTION server

# 1. Check logs for errors
tail -50 /Users/ericsmith66/Development/SmartProxy/log/launchd.stderr.log
tail -50 /Users/ericsmith66/Development/SmartProxy/log/puma.stderr.log

# 2. Stop SmartProxy
launchctl bootout gui/$(id -u)/com.agentforge.smartproxy

# 3. Remove LaunchAgent
rm ~/Library/LaunchAgents/com.agentforge.smartproxy.plist

# 4. (Optional) If nextgen-plaid is already broken, restore embedded version:
cd /Users/ericsmith66/Development/nextgen-plaid
git stash pop  # Restore backup from Step 3.1

# 5. Re-add proxy to Procfile.prod (if reverting fully)
# Edit Procfile.prod and add:
# proxy: cd smart_proxy && bundle exec puma -C config/puma.rb

# 6. Restart nextgen-plaid
launchctl kickstart -k gui/$(id -u)/com.agentforge.nextgen-plaid
```

### Scenario 2: NextGen Plaid Can't Connect to SmartProxy

```bash
# On PRODUCTION server

# 1. Verify SmartProxy is running
ps aux | grep smartproxy
lsof -nP -iTCP:3002 -sTCP:LISTEN

# 2. Check firewall/network
curl -v http://localhost:3002/health

# 3. Check environment variables in nextgen-plaid
cd /Users/ericsmith66/Development/nextgen-plaid
grep SMART_PROXY .env.production

# 4. Restart both services in order
launchctl kickstart -k gui/$(id -u)/com.agentforge.smartproxy
sleep 5
launchctl kickstart -k gui/$(id -u)/com.agentforge.nextgen-plaid
```

### Complete Rollback (Emergency)

```bash
# On PRODUCTION server

# 1. Stop SmartProxy
launchctl bootout gui/$(id -u)/com.agentforge.smartproxy
rm ~/Library/LaunchAgents/com.agentforge.smartproxy.plist

# 2. Restore nextgen-plaid with embedded SmartProxy
cd /Users/ericsmith66/Development/nextgen-plaid
git stash pop

# 3. Restart nextgen-plaid
launchctl kickstart -k gui/$(id -u)/com.agentforge.nextgen-plaid

# 4. Verify
curl -s http://localhost:3000/health?token=YOUR_TOKEN
```

---

## Post-Deployment Operations

### Daily Operations

#### Check Service Status
```bash
# Quick status check
launchctl list | grep -E "(smartproxy|nextgen)"

# Detailed status
ps aux | grep -E "(puma.*SmartProxy|puma.*production)" | grep -v grep

# Port check
lsof -nP -iTCP -sTCP:LISTEN | grep -E ":(3000|3002) "
```

#### Monitor Logs
```bash
# Tail SmartProxy logs
tail -f /Users/ericsmith66/Development/SmartProxy/log/smart_proxy.log

# Tail all SmartProxy logs
tail -f /Users/ericsmith66/Development/SmartProxy/log/*.log

# Search for errors in last hour
grep -i "error\|fatal\|exception" /Users/ericsmith66/Development/SmartProxy/log/smart_proxy.log | tail -50
```

#### Restart Services
```bash
# Restart SmartProxy only
launchctl kickstart -k gui/$(id -u)/com.agentforge.smartproxy

# Restart NextGen Plaid only
launchctl kickstart -k gui/$(id -u)/com.agentforge.nextgen-plaid

# Restart both (in correct order)
launchctl kickstart -k gui/$(id -u)/com.agentforge.smartproxy
sleep 5
launchctl kickstart -k gui/$(id -u)/com.agentforge.nextgen-plaid
```

### Updating SmartProxy

#### Deploy Code Update
```bash
# From LOCAL machine
cd /Users/ericsmith66/development/agent-forge/projects/SmartProxy

# Commit and push changes to git
git add .
git commit -m "Update SmartProxy"
git push origin main

# SSH to production
ssh ericsmith66@192.168.4.253
cd /Users/ericsmith66/Development/SmartProxy

# Pull changes
git pull origin main

# Install any new dependencies
bundle install

# Restart service
launchctl kickstart -k gui/$(id -u)/com.agentforge.smartproxy

# Verify
sleep 5
curl -s http://localhost:3002/health
tail -20 log/smart_proxy.log
```

#### Update Environment Variables
```bash
# On PRODUCTION server
cd /Users/ericsmith66/Development/SmartProxy

# Backup current .env.production
cp .env.production .env.production.backup.$(date +%Y%m%d_%H%M%S)

# Edit .env.production
nano .env.production

# Restart service to apply changes
launchctl kickstart -k gui/$(id -u)/com.agentforge.smartproxy
```

#### Rotate API Keys
```bash
# On PRODUCTION server

# Update keychain entry
security delete-generic-password -a 'smartproxy' -s 'smartproxy-GROK_API_KEY'
security add-generic-password \
  -a 'smartproxy' \
  -s 'smartproxy-GROK_API_KEY' \
  -w 'NEW_API_KEY_HERE' \
  -T /usr/bin/security

# Restart service
launchctl kickstart -k gui/$(id -u)/com.agentforge.smartproxy

# Verify
curl -s -X POST http://localhost:3002/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer c2708a90c1fde993a6a7cb8bde2a4d1db708b91937ce1e228f6e4ba7b6891ad4" \
  -d '{"model": "grok-4", "messages": [{"role": "user", "content": "test"}]}'
```

### Backup & Restore

#### Create Backup
```bash
# On PRODUCTION server

# Create backup directory
mkdir -p ~/Backups/SmartProxy

# Create backup
tar -czf ~/Backups/SmartProxy/smartproxy-backup-$(date +%Y%m%d-%H%M%S).tar.gz \
  --exclude='log/*' \
  --exclude='tmp/*' \
  --exclude='knowledge_base/test_artifacts/*' \
  /Users/ericsmith66/Development/SmartProxy

# Keep only last 7 backups
ls -t ~/Backups/SmartProxy/smartproxy-backup-*.tar.gz | tail -n +8 | xargs rm -f

# Verify backup
ls -lh ~/Backups/SmartProxy/
```

#### Restore from Backup
```bash
# On PRODUCTION server

# Stop service
launchctl bootout gui/$(id -u)/com.agentforge.smartproxy

# Choose backup
ls ~/Backups/SmartProxy/

# Restore
cd /Users/ericsmith66/Development
rm -rf SmartProxy
tar -xzf ~/Backups/SmartProxy/smartproxy-backup-YYYYMMDD-HHMMSS.tar.gz

# Start service
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.agentforge.smartproxy.plist

# Verify
sleep 5
curl -s http://localhost:3002/health
```

---

## Troubleshooting

### Issue 1: SmartProxy Won't Start

**Symptoms:**
- `launchctl list` shows `-` for PID
- Port 3002 not listening
- `launchd.stderr.log` shows errors

**Diagnosis:**
```bash
# Check launchd logs
tail -50 /Users/ericsmith66/Development/SmartProxy/log/launchd.stderr.log

# Check Puma logs
tail -50 /Users/ericsmith66/Development/SmartProxy/log/puma.stderr.log

# Try manual start to see errors
cd /Users/ericsmith66/Development/SmartProxy
./bin/start-production.sh
```

**Common Causes:**

1. **Missing secrets in keychain**
   ```bash
   # Verify
   security find-generic-password -a 'smartproxy' -s 'smartproxy-GROK_API_KEY' -w
   
   # Re-add if missing
   security add-generic-password -a 'smartproxy' -s 'smartproxy-GROK_API_KEY' -w 'YOUR_KEY'
   ```

2. **Bundle install errors**
   ```bash
   cd /Users/ericsmith66/Development/SmartProxy
   bundle check || bundle install
   ```

3. **Port already in use**
   ```bash
   lsof -nP -iTCP:3002 -sTCP:LISTEN
   # Kill process using port if needed
   ```

4. **Missing .env.production**
   ```bash
   ls -la /Users/ericsmith66/Development/SmartProxy/.env.production
   # Recreate from Step 2.4 if missing
   ```

---

### Issue 2: 401 Unauthorized Errors

**Symptoms:**
- API calls return 401
- Logs show authentication failures

**Diagnosis:**
```bash
# Check if PROXY_AUTH_TOKEN is loaded
cd /Users/ericsmith66/Development/SmartProxy
security find-generic-password -a 'smartproxy' -s 'smartproxy-PROXY_AUTH_TOKEN' -w

# Check if Rails app is using correct token
cd /Users/ericsmith66/Development/nextgen-plaid
grep SMART_PROXY .env.production
```

**Solution:**
```bash
# Ensure token matches in both places
TOKEN=$(security find-generic-password -a 'smartproxy' -s 'smartproxy-PROXY_AUTH_TOKEN' -w)

# Update Rails .env.production if needed
cd /Users/ericsmith66/Development/nextgen-plaid
echo "SMART_PROXY_AUTH_TOKEN=$TOKEN" >> .env.production

# Restart services
launchctl kickstart -k gui/$(id -u)/com.agentforge.nextgen-plaid
```

---

### Issue 3: High Memory Usage

**Symptoms:**
- SmartProxy using >1GB RAM
- System slowness

**Diagnosis:**
```bash
# Check memory usage
ps aux | grep smartproxy
top -l 1 | grep -A 5 "PID.*COMMAND"
```

**Solution:**
```bash
# Reduce Puma workers
cd /Users/ericsmith66/Development/SmartProxy
nano .env.production
# Change: PUMA_WORKERS=1 (down from 2)

# Restart
launchctl kickstart -k gui/$(id -u)/com.agentforge.smartproxy
```

---

### Issue 4: Logs Growing Too Large

**Symptoms:**
- `smart_proxy.log` exceeds 1GB
- Disk space warnings

**Solution:**
```bash
# Rotate logs manually
cd /Users/ericsmith66/Development/SmartProxy/log

# Archive old logs
tar -czf archived-logs-$(date +%Y%m%d).tar.gz *.log
rm *.log

# Restart service to recreate logs
launchctl kickstart -k gui/$(id -u)/com.agentforge.smartproxy

# Setup automatic rotation (add to crontab)
crontab -e
# Add: 0 2 * * 0 cd /Users/ericsmith66/Development/SmartProxy/log && tar -czf archived-$(date +\%Y\%m\%d).tar.gz *.log && rm *.log && launchctl kickstart -k gui/$(id -u)/com.agentforge.smartproxy
```

---

## Summary Checklist

### Pre-Deployment
- [ ] Extract secrets from keychain (Step 1.1)
- [ ] Create deployment package (Step 1.2)

### Production Setup
- [ ] Create directory structure (Step 2.1)
- [ ] Transfer deployment package (Step 2.2)
- [ ] Setup keychain secrets (Step 2.3)
- [ ] Create .env.production (Step 2.4)
- [ ] Install dependencies (Step 2.5)
- [ ] Create startup script (Step 2.6)
- [ ] Create Puma config (Step 2.7)
- [ ] Create LaunchAgent plist (Step 2.8)
- [ ] Start SmartProxy service (Step 2.9)
- [ ] Verify health (Step 2.10)

### NextGen Plaid Updates
- [ ] Remove embedded smart_proxy (Step 3.1)
- [ ] Verify Procfile.prod (Step 3.2)
- [ ] Update environment variables (Step 3.3)
- [ ] Restart nextgen-plaid (Step 3.4)

### Verification
- [ ] Service health checks (Test 1)
- [ ] SmartProxy API functionality (Test 2)
- [ ] NextGen Plaid integration (Test 3)
- [ ] Logging verification (Test 4)
- [ ] Reboot resilience (Test 5)

### Documentation
- [ ] Update RUNBOOK.md with production paths
- [ ] Document any deployment-specific changes
- [ ] Update overwatch deployment registry

---

## Related Documentation

- **SmartProxy RUNBOOK.md**: `/Users/ericsmith66/Development/SmartProxy/RUNBOOK.md`
- **NextGen Plaid RUNBOOK.md**: `/Users/ericsmith66/Development/nextgen-plaid/RUNBOOK.md`
- **Overwatch Deployment Registry**: `/Users/ericsmith66/development/agent-forge/projects/overwatch/README.md`

---

**Deployment Plan Version:** 1.0  
**Last Updated:** March 2, 2026  
**Author:** AiderDesk (DevOps Agent)  
**Status:** Ready for Execution
