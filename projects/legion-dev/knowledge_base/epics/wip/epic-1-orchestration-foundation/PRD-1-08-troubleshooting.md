# PRD-1-08 Troubleshooting Guide

## Problem: "Provider 'anthropic' not configured"

**Error Message:**
```
Error: Provider 'anthropic' not configured. Must be one of: openai, smart_proxy, custom
```

**Cause:** Your agent configs in `~/.aider-desk/` use unsupported providers (`anthropic`, `deepseek`).

**Solution:**
```bash
# Update all agent configs to use smart_proxy provider
ruby scripts/fix_agent_providers.rb

# Re-import the ROR team
rails runner /tmp/reimport_team.rb
```

---

## Problem: "Provider 'smart_proxy' not configured"

**Error Message:**
```
Error: Provider 'smart_proxy' not configured. Must be one of: openai, smart_proxy, custom
```

**Cause:** Environment variables `SMART_PROXY_TOKEN` and `SMART_PROXY_BASE_URL` are not set in your shell session.

**Solution:**
```bash
# Set environment variables (MUST be done in every new terminal session)
source scripts/set_smartproxy_env.sh

# Verify they're set
echo $SMART_PROXY_TOKEN
echo $SMART_PROXY_BASE_URL
```

**Note:** The `.env` file contains these values, but `bin/legion` CLI doesn't load it automatically. You must export the variables manually.

---

## Problem: "api_key is required for provider :smart_proxy"

**Error Message:**
```
api_key is required for provider :smart_proxy (AgentDesk::ConfigurationError)
```

**Cause:** `SMART_PROXY_TOKEN` environment variable is not set.

**Solution:**
```bash
source scripts/set_smartproxy_env.sh
```

---

## Problem: SmartProxy Connection Refused

**Error Message:**
```
Connection refused - connect(2) for "192.168.4.253" port 3001
```

**Cause:** SmartProxy server is not running at `192.168.4.253:3001`.

**Solution:**
1. Verify SmartProxy is running:
   ```bash
   curl http://192.168.4.253:3001/health
   ```
   Expected: `{"status":"ok","version":"1.0.0"}`

2. If not running, start SmartProxy on the remote machine
3. Verify network connectivity:
   ```bash
   ping 192.168.4.253
   telnet 192.168.4.253 3001
   ```

---

## Problem: WorkflowRun status "failed" with 0 events

**Symptoms:**
```ruby
legion(dev):001> run = WorkflowRun.last
legion(dev):002> run.status
=> "failed"
legion(dev):003> run.workflow_events.count
=> 0
```

**Cause:** Agent execution failed before any events were emitted (e.g., provider configuration error).

**Debug:**
```bash
# Check Rails logs
tail -f log/development.log

# Try executing with verbose output
bin/legion execute --team ROR --agent "Rails Lead" --prompt "test" --verbose
```

**Common Causes:**
- Missing environment variables (see above)
- SmartProxy not running
- Invalid agent configuration
- Network connectivity issues

---

## Problem: "Team 'ROR' not found"

**Error Message:**
```
Team 'ROR' not found in project
```

**Cause:** ROR team hasn't been imported yet.

**Solution:**
```bash
# Import ROR team
cat > /tmp/reimport_team.rb << 'EOF'
project = Project.last
result = Legion::TeamImportService.call(
  aider_desk_path: '/Users/ericsmith66/.aider-desk',
  project_path: project.path,
  team_name: 'ROR',
  dry_run: false
)

if result.errors.empty?
  puts '✅ ROR team imported successfully'
  result.team.team_memberships.order(:position).each do |tm|
    puts "  - #{tm.config['name']}: #{tm.config['provider']}/#{tm.config['model']}"
  end
else
  puts '❌ Import failed:'
  result.errors.each { |e| puts "  - #{e}" }
end
EOF

rails runner /tmp/reimport_team.rb
```

---

## Problem: Agent Config Has Wrong Provider After Import

**Symptoms:**
```bash
rails runner "AgentTeam.find_by(name: 'ROR').team_memberships.first.config"
# Shows: {"provider": "anthropic", ...}
```

**Cause:** Agent configs in `~/.aider-desk/` haven't been updated.

**Solution:**
```bash
# 1. Update agent configs
ruby scripts/fix_agent_providers.rb

# 2. Re-import team
rails runner /tmp/reimport_team.rb

# 3. Verify
rails runner "
  AgentTeam.find_by(name: 'ROR').team_memberships.each do |tm|
    puts \"#{tm.config['name']}: #{tm.config['provider']}/#{tm.config['model']}\"
  end
"
# Expected: All agents show "smart_proxy" as provider
```

---

## Verification Checklist

Before running manual tests, verify:

- [ ] **Agent configs updated:**
  ```bash
  cat ~/.aider-desk/agents/ror-rails/config.json | grep provider
  # Expected: "provider": "smart_proxy"
  ```

- [ ] **Environment variables set:**
  ```bash
  echo $SMART_PROXY_TOKEN
  echo $SMART_PROXY_BASE_URL
  # Both should show values (not empty)
  ```

- [ ] **SmartProxy accessible:**
  ```bash
  curl http://192.168.4.253:3001/health
  # Expected: {"status":"ok","version":"1.0.0"}
  ```

- [ ] **ROR team imported with smart_proxy provider:**
  ```bash
  rails runner "
    team = AgentTeam.find_by(name: 'ROR')
    puts \"Agents: #{team.team_memberships.count}\"
    team.team_memberships.first(3).each do |tm|
      puts \"  #{tm.config['name']}: #{tm.config['provider']}\"
    end
  "
  # Expected: All agents show "smart_proxy"
  ```

- [ ] **Test execution:**
  ```bash
  bin/legion execute --team ROR --agent "Rails Lead" --prompt "Say PONG" --verbose
  # Expected: Success with "completed" status
  ```

---

## Still Having Issues?

1. **Check Rails logs:**
   ```bash
   tail -f log/development.log
   ```

2. **Enable verbose output:**
   ```bash
   bin/legion execute --team ROR --agent "Rails Lead" --prompt "test" --verbose
   ```

3. **Verify database state:**
   ```bash
   rails console
   ```
   ```ruby
   # Check last workflow run
   run = WorkflowRun.last
   puts "Status: #{run.status}"
   puts "Error: #{run.error_message}" if run.error_message
   puts "Events: #{run.workflow_events.count}"
   
   # Check agent config
   tm = run.team_membership
   puts "Agent: #{tm.config['name']}"
   puts "Provider: #{tm.config['provider']}"
   puts "Model: #{tm.config['model']}"
   ```

4. **Test SmartProxy directly:**
   ```bash
   curl -X POST http://192.168.4.253:3001/v1/chat/completions \
     -H "Content-Type: application/json" \
     -H "Authorization: Bearer $SMART_PROXY_TOKEN" \
     -d '{
       "model": "claude-sonnet-4-6",
       "messages": [{"role": "user", "content": "Say PONG"}],
       "max_tokens": 10
     }'
   ```
