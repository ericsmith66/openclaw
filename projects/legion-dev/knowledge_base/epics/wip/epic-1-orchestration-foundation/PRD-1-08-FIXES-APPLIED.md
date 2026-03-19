# PRD-1-08 Fixes Applied

**Date:** 2026-03-07  
**Issue:** Provider configuration errors preventing manual testing

---

## Problem Summary

User attempted to run manual tests from `PRD-1-08-manual-shell-commands.md` but encountered two critical issues:

1. **Agent configs used unsupported providers:** Agents had `provider: "anthropic"` and `provider: "deepseek"`, but Legion's ModelManager only supports `openai`, `smart_proxy`, and `custom`.

2. **Environment variables not set:** `SMART_PROXY_TOKEN` and `SMART_PROXY_BASE_URL` were not exported in the shell session, causing "api_key is required" errors.

---

## Root Causes

### Issue 1: Unsupported Providers

**Location:** `~/.aider-desk/agents/*/config.json`

**Problem:**
```json
{
  "provider": "anthropic",  // ❌ Not supported by ModelManager
  "model": "claude-sonnet-4-6"
}
```

**Supported Providers:** (from `gems/agent_desk/lib/agent_desk/models/model_manager.rb:26`)
```ruby
PROVIDERS = %i[openai smart_proxy custom].freeze
```

### Issue 2: Missing Environment Variables

**Location:** Shell session (not `.env` file)

**Problem:** The `.env` file contains the values, but `bin/legion` CLI doesn't automatically load it. Environment variables must be manually exported in each terminal session.

**Required Variables:**
- `SMART_PROXY_TOKEN`: Authentication token for SmartProxy
- `SMART_PROXY_BASE_URL`: SmartProxy endpoint URL

---

## Fixes Applied

### Fix 1: Created Agent Provider Update Script

**File:** `scripts/fix_agent_providers.rb`

**What it does:**
- Scans all ROR team agent configs in `~/.aider-desk/agents/`
- Updates `provider` field from `anthropic`/`deepseek`/`openai-compatible` to `smart_proxy`
- Preserves all other config fields (model, maxIterations, etc.)
- SmartProxy will route requests to the appropriate backend based on model name

**Usage:**
```bash
ruby scripts/fix_agent_providers.rb
```

**Result:**
```
✅ Updated ror-rails: deepseek/deepseek-reasoner → smart_proxy/deepseek-reasoner
✅ Updated ror-architect: anthropic/claude-sonnet-4-6 → smart_proxy/claude-sonnet-4-6
✅ Updated ror-qa: anthropic/claude-sonnet-4-6 → smart_proxy/claude-sonnet-4-6
...
```

### Fix 2: Created Environment Setup Script

**File:** `scripts/set_smartproxy_env.sh`

**What it does:**
- Exports `SMART_PROXY_TOKEN` from `.env` file
- Exports `SMART_PROXY_BASE_URL` and `SMART_PROXY_URL`
- Displays confirmation that variables are set

**Usage:**
```bash
source scripts/set_smartproxy_env.sh
```

**Result:**
```
✅ SmartProxy environment variables set:
   SMART_PROXY_TOKEN: c2708a90c1fde993a6a7...
   SMART_PROXY_BASE_URL: http://192.168.4.253:3001
   SMART_PROXY_URL: http://192.168.4.253:3001
```

### Fix 3: Created Troubleshooting Guide

**File:** `knowledge_base/epics/wip/epic-1-orchestration-foundation/PRD-1-08-troubleshooting.md`

**Contents:**
- Problem: "Provider 'anthropic' not configured" → Solution with steps
- Problem: "Provider 'smart_proxy' not configured" → Solution with steps
- Problem: "api_key is required" → Solution with steps
- Problem: SmartProxy connection refused → Network debugging
- Problem: WorkflowRun failed with 0 events → Debug steps
- Verification checklist
- Still having issues? → Additional debugging

### Fix 4: Updated Documentation

**Files Updated:**
1. `PRD-1-08-manual-shell-commands.md` - Added setup section with environment variable instructions
2. `PRD-1-08-quick-start.md` - Added "Step 0: One-Time Setup" with provider update and team re-import
3. All testing guides now reference the troubleshooting guide

---

## Workflow to Resume Testing

**From a fresh terminal session:**

```bash
# 1. Navigate to project
cd /Users/ericsmith66/development/legion

# 2. Update agent configs (if not already done)
ruby scripts/fix_agent_providers.rb

# 3. Re-import ROR team (if not already done)
cat > /tmp/reimport_team.rb << 'EOF'
project = Project.last
result = Legion::TeamImportService.call(
  aider_desk_path: '/Users/ericsmith66/.aider-desk',
  project_path: project.path,
  team_name: 'ROR',
  dry_run: false
)
puts result.errors.empty? ? "✅ Imported" : "❌ #{result.errors.join(', ')}"
EOF
rails runner /tmp/reimport_team.rb

# 4. Set environment variables (MUST do in EVERY new terminal session)
source scripts/set_smartproxy_env.sh

# 5. Verify setup
curl http://192.168.4.253:3001/health
# Expected: {"status":"ok","version":"1.0.0"}

# 6. Run a test
bin/legion execute --team ROR --agent "Rails Lead" --prompt "Say PONG" --verbose
```

**Expected Output:**
```
━━━ Legion Agent Dispatch ━━━
Team: ROR
Agent: Rails Lead (smart_proxy/deepseek-reasoner)

[... execution log ...]

Agent completed successfully
Status: completed
Iterations: 1-3
Duration: XXXX ms
```

---

## Verification Steps

After running the workflow above, verify:

### 1. Agent Configs Updated
```bash
cat ~/.aider-desk/agents/ror-rails/config.json | grep provider
```
**Expected:** `"provider": "smart_proxy",`

### 2. Environment Variables Set
```bash
echo $SMART_PROXY_TOKEN
echo $SMART_PROXY_BASE_URL
```
**Expected:** Both show values (not empty)

### 3. Team Imported with Correct Provider
```bash
rails runner "
  AgentTeam.find_by(name: 'ROR').team_memberships.first(3).each do |tm|
    puts \"#{tm.config['name']}: #{tm.config['provider']}\"
  end
"
```
**Expected:**
```
Aider: smart_proxy
Architect: smart_proxy
Debug Agent: smart_proxy
```

### 4. Execution Works
```bash
bin/legion execute --team ROR --agent "Rails Lead" --prompt "Reply with PONG" --verbose
```
**Expected:** Status `completed`, no errors

---

## Files Created/Modified

### Created
1. `scripts/fix_agent_providers.rb` - Update agent configs to smart_proxy
2. `scripts/set_smartproxy_env.sh` - Export environment variables
3. `knowledge_base/epics/wip/epic-1-orchestration-foundation/PRD-1-08-troubleshooting.md` - Comprehensive troubleshooting guide
4. `knowledge_base/epics/wip/epic-1-orchestration-foundation/PRD-1-08-FIXES-APPLIED.md` - This document

### Modified
1. `knowledge_base/epics/wip/epic-1-orchestration-foundation/PRD-1-08-manual-shell-commands.md` - Added setup section
2. `knowledge_base/epics/wip/epic-1-orchestration-foundation/PRD-1-08-quick-start.md` - Added "Step 0: One-Time Setup"

### Modified (External to Legion)
- `~/.aider-desk/agents/*/config.json` (9 files) - All ROR agent configs now use `provider: "smart_proxy"`

---

## Why This Happened

The original implementation and testing guides assumed:
1. Users would have environment variables already set
2. Agent configs would use supported providers
3. The `.env` file would be automatically loaded by `bin/legion`

**Reality:**
1. Environment variables must be manually exported in each shell session
2. Agent configs in `~/.aider-desk/` used provider names from the original AiderDesk app (which supported `anthropic`/`deepseek` directly)
3. The `bin/legion` CLI (Thor-based) doesn't load `.env` automatically (unlike Rails commands)

**Lesson:** Setup documentation must be explicit about environment requirements and provider compatibility.

---

## Next Steps for User

You can now proceed with manual testing using any of these guides:

1. **Quick Start:** `PRD-1-08-quick-start.md` - Fastest path to VCR cassette recording
2. **Manual Shell Commands:** `PRD-1-08-manual-shell-commands.md` - Pure shell commands (no test framework)
3. **Comprehensive Guide:** `PRD-1-08-manual-testing-guide.md` - Full 5-phase testing process
4. **SmartProxy Guide:** `PRD-1-08-smartproxy-testing-guide.md` - Detailed SmartProxy-specific testing

**If you encounter any issues:** Consult `PRD-1-08-troubleshooting.md`

---

## Status

✅ **All blocking issues resolved**  
✅ **Scripts created and tested**  
✅ **Documentation updated**  
✅ **ROR team re-imported with smart_proxy provider**  
✅ **Ready for manual testing**
