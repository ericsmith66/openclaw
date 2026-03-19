# PRD-1-08 Quick Start - SmartProxy Testing

**SmartProxy Location:** `192.168.4.253:3001` (remote server)  
**Estimated Time:** 45-60 minutes

---

## Prerequisites

- [ ] SmartProxy running at `192.168.4.253:3001`
- [ ] SMART_PROXY_TOKEN (get from SmartProxy admin)
- [ ] Network access to SmartProxy server
- [ ] ROR team agents updated to use `smart_proxy` provider

---

## Step 0: One-Time Setup (REQUIRED!)

**⚠️ Do this BEFORE running any tests!**

```bash
cd /Users/ericsmith66/development/legion

# 1. Update all agent configs to use smart_proxy provider
ruby scripts/fix_agent_providers.rb

# 2. Re-import ROR team with updated configs
cat > /tmp/reimport_team.rb << 'EOF'
project = Project.last
result = Legion::TeamImportService.call(
  aider_desk_path: '/Users/ericsmith66/.aider-desk',
  project_path: project.path,
  team_name: 'ROR',
  dry_run: false
)
puts result.errors.empty? ? "✅ Team imported" : "❌ #{result.errors.join(', ')}"
EOF
rails runner /tmp/reimport_team.rb
```

**Verify agents use smart_proxy:**
```bash
rails runner "
  AgentTeam.find_by(name: 'ROR').team_memberships.first(3).each do |tm|
    puts \"#{tm.config['name']}: #{tm.config['provider']}\"
  end
"
# Expected: All show "smart_proxy"
```

---

## Quick Start Commands

### 1. Verify SmartProxy Access

```bash
curl http://192.168.4.253:3001/health
```

**Expected:** `{"status":"ok","version":"1.0.0"}`

---

### 2. Set Environment Variables (REQUIRED in every terminal session!)

```bash
cd /Users/ericsmith66/development/legion

export SMART_PROXY_TOKEN=your_actual_token_here
export SMART_PROXY_BASE_URL=http://192.168.4.253:3001

# Verify
echo $SMART_PROXY_TOKEN
echo $SMART_PROXY_BASE_URL
```

---

### 3. Verify ROR Team

```bash
rails runner "puts AgentTeam.find_by(name: 'ROR')&.team_memberships&.count || 'Team not found'"
```

**Expected:** `4`

**If "Team not found":**
```bash
rake teams:import[~/.aider-desk]
```

---

### 4. Record VCR Cassettes (THE MAIN TEST)

```bash
RECORD_VCR=1 rails test test/e2e/epic_1_validation_test.rb -v
```

**What to expect:**
- Duration: 2-3 minutes
- Makes real API calls to SmartProxy
- Records 8 VCR cassettes
- All 10 tests pass

**Expected Output:**
```
Legion::Epic1ValidationTest#test_scenario_1_team_import_round_trip = 0.XX s = .
Legion::Epic1ValidationTest#test_scenario_2_single_agent_full_identity = 15.XX s = .
[Recording new cassette: test/vcr_cassettes/e2e/scenario_2_rails_lead_dispatch.yml]
Legion::Epic1ValidationTest#test_scenario_3_multi_agent_dispatch = 45.XX s = .
[Recording new cassette: test/vcr_cassettes/e2e/scenario_3_multi_agent.yml]
...
10 runs, XXX assertions, 0 failures, 0 errors, 0 skips
```

---

### 5. Verify Cassettes Created

```bash
ls -lh test/vcr_cassettes/e2e/
```

**Expected:** 8 .yml files (45KB - 180KB each)

---

### 6. Test Offline Replay

```bash
rails test test/e2e/epic_1_validation_test.rb -v
```

**What to expect:**
- Duration: 5-10 seconds (fast!)
- No API calls (uses cassettes)
- All 10 tests pass
- 0 skips

**Expected Output:**
```
..........

10 runs, XXX assertions, 0 failures, 0 errors, 0 skips
```

---

### 7. Run Validation Command

```bash
bin/legion validate
```

**Expected Output:**
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Legion E2E Validation Suite
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Running 10 tests...
..........

10 runs, XXX assertions, 0 failures, 0 errors, 0 skips

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  ✅ All E2E validation tests passed
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

### 8. Verify Full Test Suite

```bash
rails test
```

**Expected:**
```
263 runs, 975+ assertions, 0 failures, 0 errors, 0 skips
```

---

### 9. Commit VCR Cassettes

```bash
git add test/vcr_cassettes/e2e/
git commit -m "E2E: VCR cassettes recorded - all 10 scenarios passing"
git push
```

---

## Success Checklist

After completing all steps:

- [ ] SmartProxy accessible at `192.168.4.253:3001`
- [ ] Environment variables set (`SMART_PROXY_TOKEN`, `SMART_PROXY_BASE_URL`)
- [ ] VCR recording completed (all 10 tests pass)
- [ ] 8 cassette files created in `test/vcr_cassettes/e2e/`
- [ ] Offline replay works (all 10 tests pass in < 10 seconds)
- [ ] `bin/legion validate` exits 0
- [ ] Full test suite passes (263 runs, 0 failures)
- [ ] Cassettes committed to git

---

## Troubleshooting

### Can't reach SmartProxy

```bash
# Test connectivity
ping 192.168.4.253
curl http://192.168.4.253:3001/health
```

**Solutions:**
- Check you're on the correct network/VPN
- Verify firewall allows port 3001
- Contact SmartProxy administrator

---

### Tests fail with authentication errors

**Error:** `401 Unauthorized`

**Solution:**
```bash
# Verify token is set correctly
echo $SMART_PROXY_TOKEN

# Test token with curl
curl -H "Authorization: Bearer $SMART_PROXY_TOKEN" http://192.168.4.253:3001/health
```

---

### VCR cassette recording hangs

**Possible causes:**
- Rate limiting (429 errors)
- Model unavailable (503 errors)
- Network timeout

**Check SmartProxy logs** or wait and retry

---

### Offline replay fails

**Error:** `VCR::Errors::UnhandledHTTPRequestError`

**Solution:**
```bash
# Verify cassettes exist
ls test/vcr_cassettes/e2e/*.yml

# If missing or corrupted, re-record
rm -rf test/vcr_cassettes/e2e/*.yml
RECORD_VCR=1 rails test test/e2e/epic_1_validation_test.rb -v
```

---

## What You're Testing

These 10 scenarios validate the complete Epic 1 orchestration pipeline:

1. **Team Import** - 4 agents with full configs
2. **Single Agent Dispatch** - Full identity (rules, skills, approvals)
3. **Multi-Agent Dispatch** - 4 agents with distinct identities
4. **Orchestrator Hooks** - Iteration budget monitoring
5. **Event Trail Forensics** - Complete event logging
6. **Decomposition** - PRD → scored tasks with dependencies
7. **Plan Execution** - Tasks execute in dependency order
8. **Full Cycle** - Decompose → Execute complete pipeline
9. **Dependency Graph** - Fan-in, fan-out, parallel groups
10. **Error Handling** - Non-existent team/agent, task failures

---

## Next Steps After Success

1. **Submit for final QA scoring** - All 14 ACs now met
2. **Update implementation status** - Mark PRD-1-08 complete
3. **Epic 1 completion** - Mark 8/8 PRDs done ✅
4. **Celebrate!** 🎉

---

**Full Guide:** See `PRD-1-08-smartproxy-testing-guide.md` for detailed instructions and troubleshooting.
