# SmartProxy Operations Runbook

**Version:** 1.0  
**Last Updated:** February 22, 2026  
**Owner:** Agent Forge Team

---

## Table of Contents

1. [Service Overview](#service-overview)
2. [Architecture](#architecture)
3. [Operations](#operations)
4. [API Management](#api-management)
5. [Health Checks](#health-checks)
6. [Troubleshooting](#troubleshooting)
7. [Logs](#logs)
8. [Emergency Procedures](#emergency-procedures)

---

## Service Overview

### Description
SmartProxy is an intelligent AI gateway and router that provides unified access to multiple LLM providers (Anthropic Claude, Grok, Ollama) with smart routing, caching, and failover capabilities.

### Production Environment
- **Server:** 192.168.4.253 (M3 Ultra)
- **User:** ericsmith66
- **Path:** `/Users/ericsmith66/Development/SmartProxy`
- **Port:** 8080 (configurable)
- **Environment:** production

### Key Technologies
- **Framework:** Ruby on Rails 7.2 or Sinatra (check implementation)
- **Ruby Version:** 3.3.0
- **Cache:** Redis or in-memory
- **Providers:**
  - Anthropic Claude (cloud API)
  - Grok (cloud API)
  - Ollama (local LLM)

### Use Cases
- Unified LLM API endpoint for multiple clients
- Intelligent routing based on model capabilities
- Response caching for cost optimization
- Automatic failover between providers
- Rate limiting and quota management

---

## Architecture

### Request Flow
```
Client Application
      ↓
SmartProxy (Port 8080)
      ↓
   Router/Dispatcher
      ↓
┌─────┴─────┬─────────┬─────────┐
│           │         │         │
Anthropic   Grok    Ollama   Cache
Claude API   API    (Local)   Layer
```

### Supported Providers

| Provider | Type | Models | Endpoint |
|----------|------|--------|----------|
| Anthropic Claude | Cloud | Claude 3 Opus/Sonnet/Haiku | api.anthropic.com |
| Grok | Cloud | Grok models | api.x.ai |
| Ollama | Local | Llama, Mistral, etc. | localhost:11434 |

### Routing Strategy
1. **Model-based routing:** Specific model requests go to appropriate provider
2. **Cost optimization:** Prefer local Ollama for simple queries
3. **Failover:** Automatic fallback if primary provider fails
4. **Cache-first:** Check cache before routing to provider

---

## Operations

### Start Service

#### Development Mode
```bash
cd /Users/ericsmith66/Development/SmartProxy
bin/dev
```

#### Production Mode
```bash
cd /Users/ericsmith66/Development/SmartProxy
bin/prod
```

Using launchd (if configured):
```bash
launchctl start gui/$(id -u)/com.agentforge.smartproxy
```

### Stop Service

Using launchd:
```bash
launchctl stop gui/$(id -u)/com.agentforge.smartproxy
```

Manual process kill:
```bash
# Find process
ps aux | grep smartproxy

# Kill gracefully
kill -TERM <PID>

# Force kill if necessary
kill -9 <PID>
```

### Restart Service

Using launchd:
```bash
launchctl kickstart -k gui/$(id -u)/com.agentforge.smartproxy
```

Manual restart:
```bash
cd /Users/ericsmith66/Development/SmartProxy
pkill -TERM -f "smartproxy"
sleep 2
bin/prod
```

### Check Service Status

```bash
# Check if process is running
ps aux | grep smartproxy | grep -v grep

# Check service via launchd
launchctl list | grep smartproxy

# Check port binding
lsof -i :8080
```

---

## API Management

### API Keys

SmartProxy requires API keys for upstream providers.

#### Required API Keys
- `ANTHROPIC_API_KEY` - Anthropic Claude API
- `GROK_API_KEY` - Grok/X.AI API

#### Optional API Keys
- `OLLAMA_API_KEY` - If Ollama requires authentication

#### Retrieve API Keys

**From Keychain (if configured):**
```bash
# Template
security find-generic-password -a 'smartproxy' -s 'smartproxy-<KEY>' -w

# Examples
security find-generic-password -a 'smartproxy' -s 'smartproxy-ANTHROPIC_API_KEY' -w
security find-generic-password -a 'smartproxy' -s 'smartproxy-GROK_API_KEY' -w
```

**From environment variables:**
```bash
echo $ANTHROPIC_API_KEY
echo $GROK_API_KEY
```

#### Update API Keys

```bash
# Update in Keychain
security delete-generic-password -a 'smartproxy' -s 'smartproxy-ANTHROPIC_API_KEY'
security add-generic-password -a 'smartproxy' -s 'smartproxy-ANTHROPIC_API_KEY' -w '<NEW_KEY>'

# Or re-run setup script (if exists)
./scripts/setup-keys.sh
```

### Test Provider Connectivity

#### Test Anthropic Claude
```bash
curl -X POST http://192.168.4.253:8080/v1/claude/completions \
  -H "Content-Type: application/json" \
  -d '{"model": "claude-3-sonnet-20240229", "prompt": "Hello"}'
```

#### Test Grok
```bash
curl -X POST http://192.168.4.253:8080/v1/grok/completions \
  -H "Content-Type: application/json" \
  -d '{"model": "grok-1", "prompt": "Hello"}'
```

#### Test Ollama
```bash
curl -X POST http://192.168.4.253:8080/v1/ollama/completions \
  -H "Content-Type: application/json" \
  -d '{"model": "llama2", "prompt": "Hello"}'
```

### Rate Limiting

SmartProxy may implement rate limiting to prevent abuse.

**Check rate limit status:**
```bash
curl http://192.168.4.253:8080/v1/status
```

**Reset rate limits (admin only):**
```bash
curl -X POST http://192.168.4.253:8080/admin/reset-limits \
  -H "Authorization: Bearer <ADMIN_TOKEN>"
```

---

## Health Checks

### Application Health

```bash
curl http://192.168.4.253:8080/health
```

**Expected response:**
```json
{
  "status": "ok",
  "providers": {
    "claude": "connected",
    "grok": "connected",
    "ollama": "connected"
  },
  "cache": "active"
}
```

### Provider Health

Check each provider individually:

```bash
# Anthropic Claude
curl http://192.168.4.253:8080/health/claude

# Grok
curl http://192.168.4.253:8080/health/grok

# Ollama
curl http://192.168.4.253:8080/health/ollama
```

### Cache Health

```bash
# Check cache status
curl http://192.168.4.253:8080/health/cache

# Check cache hit rate
curl http://192.168.4.253:8080/stats/cache
```

### Service Metrics

```bash
# Get service metrics
curl http://192.168.4.253:8080/metrics

# Expected response
{
  "requests_total": 1234,
  "requests_per_minute": 12.5,
  "cache_hit_rate": 0.65,
  "avg_response_time_ms": 250,
  "providers": {
    "claude": {"requests": 500, "errors": 2},
    "grok": {"requests": 300, "errors": 0},
    "ollama": {"requests": 434, "errors": 1}
  }
}
```

---

## Troubleshooting

### Service Won't Start

**Symptoms:** Process exits immediately

**Diagnostic steps:**

1. Check logs:
   ```bash
   tail -100 log/production.log
   ```

2. Verify API keys are set:
   ```bash
   env | grep -E "ANTHROPIC|GROK|OLLAMA"
   ```

3. Check port availability:
   ```bash
   lsof -i :8080
   ```

4. Try starting manually:
   ```bash
   cd /Users/ericsmith66/Development/SmartProxy
   ruby app.rb  # Or appropriate start command
   ```

### Provider Connection Failures

**Symptoms:** Requests to specific provider failing

**Diagnostic steps:**

1. Check provider health:
   ```bash
   curl http://192.168.4.253:8080/health/claude
   curl http://192.168.4.253:8080/health/grok
   curl http://192.168.4.253:8080/health/ollama
   ```

2. Test provider directly:
   ```bash
   # Anthropic Claude
   curl https://api.anthropic.com/v1/messages \
     -H "x-api-key: $ANTHROPIC_API_KEY" \
     -H "anthropic-version: 2023-06-01" \
     -H "content-type: application/json" \
     -d '{"model":"claude-3-sonnet-20240229","max_tokens":1024,"messages":[{"role":"user","content":"Hello"}]}'
   
   # Ollama (local)
   curl http://localhost:11434/api/generate \
     -d '{"model":"llama2","prompt":"Hello"}'
   ```

3. Check API keys are valid:
   ```bash
   security find-generic-password -a 'smartproxy' -s 'smartproxy-ANTHROPIC_API_KEY' -w
   ```

4. Check logs for API errors:
   ```bash
   tail -100 log/production.log | grep -i "error\|fail"
   ```

### Ollama Not Responding

**Symptoms:** Ollama provider health check fails

**Diagnostic steps:**

1. Check if Ollama is running:
   ```bash
   ps aux | grep ollama
   ```

2. Start Ollama if not running:
   ```bash
   ollama serve
   ```

3. Test Ollama directly:
   ```bash
   curl http://localhost:11434/api/tags
   ```

4. Check Ollama logs:
   ```bash
   journalctl -u ollama -f  # If running as systemd service
   ```

### High Response Times

**Symptoms:** Slow API responses

**Diagnostic steps:**

1. Check cache hit rate:
   ```bash
   curl http://192.168.4.253:8080/stats/cache
   ```
   
   Low cache hit rate (<50%) may indicate cache issues.

2. Check provider response times:
   ```bash
   curl http://192.168.4.253:8080/metrics
   ```

3. Check system resources:
   ```bash
   top -pid $(pgrep -f smartproxy)
   ```

4. Enable debug logging:
   ```bash
   export LOG_LEVEL=debug
   launchctl kickstart -k gui/$(id -u)/com.agentforge.smartproxy
   ```

### Cache Issues

**Symptoms:** Cache not working or causing errors

**Diagnostic steps:**

1. Check cache backend (Redis or in-memory):
   ```bash
   # If using Redis
   redis-cli ping
   
   # Check cache status
   curl http://192.168.4.253:8080/health/cache
   ```

2. Clear cache:
   ```bash
   curl -X POST http://192.168.4.253:8080/admin/clear-cache \
     -H "Authorization: Bearer <ADMIN_TOKEN>"
   ```

3. Restart service:
   ```bash
   launchctl kickstart -k gui/$(id -u)/com.agentforge.smartproxy
   ```

---

## Logs

### Application Logs

**Production log:**
```bash
tail -f /Users/ericsmith66/Development/SmartProxy/log/production.log
```

**Request logs:**
```bash
# All requests
tail -f log/production.log | grep -i "request"

# Failed requests only
tail -f log/production.log | grep -i "error\|fail"
```

### Provider-Specific Logs

```bash
# Claude requests
tail -f log/production.log | grep -i "claude"

# Grok requests
tail -f log/production.log | grep -i "grok"

# Ollama requests
tail -f log/production.log | grep -i "ollama"
```

### Cache Logs

```bash
# Cache hits/misses
tail -f log/production.log | grep -i "cache"
```

### Access Logs

```bash
# If using Rack or similar
tail -f log/access.log
```

---

## Emergency Procedures

### Complete Service Restart

If service is unresponsive:

```bash
# 1. Stop service
launchctl stop gui/$(id -u)/com.agentforge.smartproxy

# 2. Kill any remaining processes
pkill -9 -f "smartproxy"

# 3. Clear cache (if using Redis)
redis-cli FLUSHDB

# 4. Wait for cleanup
sleep 5

# 5. Start service
launchctl start gui/$(id -u)/com.agentforge.smartproxy

# 6. Verify health
curl http://192.168.4.253:8080/health
```

**Estimated downtime:** 10-15 seconds

### Provider Failover

If one provider is down, verify failover is working:

```bash
# Make request that would normally go to failed provider
curl -X POST http://192.168.4.253:8080/v1/completions \
  -H "Content-Type: application/json" \
  -d '{"model": "auto", "prompt": "Hello"}'

# Check logs to see which provider handled it
tail -20 log/production.log
```

### Emergency API Key Rotation

If API key is compromised:

```bash
# 1. Stop service
launchctl stop gui/$(id -u)/com.agentforge.smartproxy

# 2. Update API key in Keychain
security delete-generic-password -a 'smartproxy' -s 'smartproxy-ANTHROPIC_API_KEY'
security add-generic-password -a 'smartproxy' -s 'smartproxy-ANTHROPIC_API_KEY' -w '<NEW_KEY>'

# 3. Start service
launchctl start gui/$(id -u)/com.agentforge.smartproxy

# 4. Verify new key works
curl -X POST http://192.168.4.253:8080/v1/claude/completions \
  -H "Content-Type: application/json" \
  -d '{"model": "claude-3-sonnet-20240229", "prompt": "Test"}'
```

---

## Deployment

### Manual Deployment

```bash
# 1. SSH to production
ssh ericsmith66@192.168.4.253

# 2. Navigate to app directory
cd Development/SmartProxy

# 3. Pull latest code
git pull origin main

# 4. Install dependencies
bundle install  # Or appropriate package manager

# 5. Restart service
launchctl kickstart -k gui/$(id -u)/com.agentforge.smartproxy

# 6. Verify health
curl http://localhost:8080/health
```

**Estimated downtime:** 5-10 seconds

### Configuration Changes

If updating routing rules or provider settings:

```bash
# 1. Edit configuration file
vim config/providers.yml  # Or appropriate config file

# 2. Validate configuration
bin/validate-config  # If validation script exists

# 3. Restart service
launchctl kickstart -k gui/$(id -u)/com.agentforge.smartproxy

# 4. Verify changes
curl http://192.168.4.253:8080/config
```

---

## Appendix

### File Locations

| File/Directory | Purpose |
|---------------|---------|
| `/Users/ericsmith66/Development/SmartProxy` | Application root |
| `log/production.log` | Application logs |
| `config/providers.yml` | Provider configuration |
| `tmp/cache/` | File-based cache (if used) |

### Network Ports

| Port | Protocol | Purpose |
|------|----------|---------|
| 8080 | HTTP | SmartProxy API |
| 11434 | HTTP | Ollama API (local) |

### API Endpoints

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/health` | GET | Service health check |
| `/health/:provider` | GET | Provider health check |
| `/metrics` | GET | Service metrics |
| `/stats/cache` | GET | Cache statistics |
| `/v1/completions` | POST | Unified completion API |
| `/v1/:provider/completions` | POST | Provider-specific API |
| `/admin/clear-cache` | POST | Clear cache (admin) |

### Emergency Contacts

| Role | Contact | Availability |
|------|---------|--------------|
| Primary | Eric Smith | 24/7 |
| Secondary | TBD | Business hours |

### External Services

| Service | Documentation | Status Page |
|---------|--------------|-------------|
| Anthropic Claude | https://docs.anthropic.com | https://status.anthropic.com |
| Grok (X.AI) | https://docs.x.ai | TBD |
| Ollama | https://ollama.ai/docs | N/A (local) |

---

**Document End**

*For updates to this runbook, contact the Agent Forge team.*
