# QA Report: PRD-1-05 Orchestrator Hooks

**PRD:** `knowledge_base/epics/wip/epic-1-orchestration-foundation/PRD-1-05-orchestrator-hooks.md`
**Implementation Plan:** `knowledge_base/epics/wip/epic-1-orchestration-foundation/PRD-1-05-orchestrator-hooks-implementation-plan.md`
**Pre-QA Checklist:** `knowledge_base/epics/wip/epic-1-orchestration-foundation/feedback/pre-qa-checklist-PRD-1-05.md`
**QA Date:** 2026-03-08
**Reviewer:** QA Specialist Agent

---

## Final Score: 71/100 — REJECT

---

## Per-Criteria Breakdown

| Category | Max | Score | Notes |
|----------|-----|-------|-------|
| Acceptance Criteria Compliance | 30 | 18 | AC2 unimplemented; AC7 semantics incorrect; `.to_json` metadata bug |
| Test Coverage | 30 | 22 | 2 of 15 planned unit tests missing; error resilience stub incorrect; idempotency test absent |
| Code Quality | 20 | 16 | `.to_json` anti-pattern in JSONB column; warn_at_threshold doesn't return HookResult |
| Plan Adherence | 20 | 15 | Architect R2-2 not properly implemented; AC2 block-at-double-threshold absent from impl |

---

## Verification Commands & Outputs

### 1. Pre-QA Checklist
```
File: knowledge_base/epics/wip/epic-1-orchestration-foundation/feedback/pre-qa-checklist-PRD-1-05.md
Status: EXISTS ✅
```

### 2. RuboCop
```
Command: rubocop app/services/legion/orchestrator_hooks.rb app/services/legion/orchestrator_hooks_service.rb
         app/services/legion/agent_assembly_service.rb test/services/legion/orchestrator_hooks_service_test.rb
         test/services/legion/orchestrator_hooks_integration_test.rb test/services/legion/agent_assembly_service_test.rb
         --format simple
Result: 6 files inspected, no offenses detected ✅
```

### 3. frozen_string_literal
```
Command: grep -rL 'frozen_string_literal' [all modified files]
Result: (empty — no files missing pragma) ✅
```

### 4. Full Test Suite
```
Command: bundle exec rails test
Result: 183 runs, 673 assertions, 0 failures, 0 errors, 0 skips ✅
```

### 5. PRD-specific Tests
```
Command: bundle exec rails test test/services/legion/orchestrator_hooks_service_test.rb
         test/services/legion/orchestrator_hooks_integration_test.rb
         test/services/legion/agent_assembly_service_test.rb --verbose
Result: 27 runs, 60 assertions, 0 failures, 0 errors, 0 skips ✅
```

### 6. rescue/raise Audit
```
Command: grep -n 'rescue\|raise' app/services/legion/orchestrator_hooks_service.rb
Result: Lines 37, 76, 111, 135 — all 4 hooks wrapped in rescue StandardError ✅
```

### 7. Migration Check
```
No migrations required (no schema changes). JSONB metadata column exists from PRD-1-01. ✅
```

---

## Itemized Deductions

---

### Acceptance Criteria Deductions (-12 pts)

#### DEDUCTION 1: AC2 — Iteration budget hook does NOT block at 2× threshold (-8 pts)
**Severity: CRITICAL**

**File:** `app/services/legion/orchestrator_hooks_service.rb` lines 142–168

**PRD AC2:** "At 2× threshold: Update WorkflowRun status to `iteration_limit`, return `HookResult(blocked: true)` to stop execution."

**Actual implementation:** The `warn_at_threshold` method has NO branching at 2× threshold. It issues warnings at `>= threshold` for every call thereafter, but never:
- Sets `status: :iteration_limit`
- Returns `HookResult(blocked: true)` (it returns `nil` implicitly)

```ruby
# orchestrator_hooks_service.rb:142-168 — warn_at_threshold method
def warn_at_threshold(threshold)
  @iteration_count ||= 0
  @iteration_count += 1

  return if @iteration_count < threshold   # ← exits below threshold

  # ← NO branch for @iteration_count >= threshold * 2
  # ← Never calls update!(status: :iteration_limit)
  # ← Never returns HookResult(blocked: true)

  Rails.logger.warn(...)
  @workflow_run.update!(metadata: ...)
end
```

The `on_tool_called` hook block also ignores the return value of `warn_at_threshold`:
```ruby
# line 34-41
@hook_manager.on(:on_tool_called) do |event_data, context|
  begin
    warn_at_threshold(threshold)   # ← return value DISCARDED
  rescue ...
  end
end
```

Even if `warn_at_threshold` returned a `HookResult`, the caller discards it, returning `nil` from the block.

**Integration test confirms the bug** — `test_full_dispatch_with_low_iteration_limit` at line 44 explicitly asserts `assert_equal "running", @workflow_run.status` after 2× iterations, documenting that the implementation does NOT set `iteration_limit`. This test was **rewritten to assert the wrong/incomplete behavior** instead of the PRD-required behavior.

#### DEDUCTION 2: AC7 test renames incorrectly mask semantics (-4 pts)
**Severity: MODERATE**

**File:** `test/services/legion/orchestrator_hooks_service_test.rb` line 232

The test is named `test_cost_hook_blocks_and_updates_status` but AC7 reads "Cost budget hook blocks execution with `budget_exceeded` status." The implementation returns `nil` (correct per Architect) which allows the runner's `:stop` — but the test name says "blocks" which is the OPPOSITE of what the hook does. This is a naming inconsistency that could mislead future maintainers.

More critically: the test does NOT assert on the hook result's blocked state (should be `refute result.blocked` to confirm the runner will stop via default `:stop`). This was explicitly identified as BLOCKER #R2-1 in the Architect Round 2 review.

---

### Test Coverage Deductions (-8 pts)

#### DEDUCTION 3: Plan test #2 (iteration_hook_blocks_at_double_threshold) is MISSING (-3 pts)
**File:** `test/services/legion/orchestrator_hooks_service_test.rb`

The implementation plan's numbered test checklist item #2: "Iteration hook blocks at 2× threshold, sets `iteration_limit` status" is completely absent from the test file. The 13 unit tests present do NOT include any test asserting `status == "iteration_limit"`.

```
Plan test checklist item 2: test_iteration_hook_blocks_at_double_threshold ← MISSING
```

This directly corresponds to AC2's unimplemented behavior.

#### DEDUCTION 4: Idempotency test (plan test #14-15) is MISSING (-3 pts)
**File:** `test/services/legion/orchestrator_hooks_service_test.rb`

Plan test checklist item #15: "Registration idempotency — double-call doesn't double-register" is absent. The Pre-QA checklist states "16 / 18 planned tests implemented" and notes "2 tests merged," but the idempotency test is not in the file. This was originally present in the plan (and pre-qa checklist listed it), but was dropped without documentation of why.

#### DEDUCTION 5: Error resilience test stubs wrong method — Architect BLOCKER R2-2 not properly applied (-2 pts)
**File:** `test/services/legion/orchestrator_hooks_service_test.rb` line 272

The Architect's Round 2 BLOCKER #R2-2 required:
> "Stub `save!` instead of (or in addition to) `update!`: `@workflow_run.stubs(:save!).raises(ActiveRecord::StatementInvalid.new(\"simulated DB error\"))`"

**However**, the implementation changed the `on_tool_called` hook from calling `save!` to calling `update!` (through `warn_at_threshold`). Looking at the actual code:
- `warn_at_threshold` (line 162) calls `@workflow_run.update!` — not `save!`
- The test stubs `update!` (line 272) — which IS the correct method to stub given the actual implementation

But here is the problem: the stub raises `ActiveRecord::StatementInvalid` without a message argument, which in Rails 8 requires a message string. While this happened to pass (Rails may accept nil message), the Architect explicitly noted this requirement:
> "Note: `ActiveRecord::StatementInvalid` requires a message argument in Rails 8."

The test works in practice but doesn't follow the Architect's explicit guidance. This is a minor compliance issue now that the implementation uses `update!` instead of `save!` — the stub IS correct for the current code. Deduction reduced to minor.

---

### Code Quality Deductions (-4 pts)

#### DEDUCTION 6: `.to_json` anti-pattern in JSONB column — metadata values stored as strings (-3 pts)
**Severity: MODERATE — data integrity bug**

**Files:** `app/services/legion/orchestrator_hooks_service.rb` lines 54-59, 65-70, 95, 126-131

The implementation calls `.to_json` on hash values before storing them in the `workflow_runs.metadata` JSONB column:

```ruby
# Line 58: context_warning stored as JSON string, not hash
metadata: @workflow_run.metadata.merge({
  "context_warning" => {
    percentage: percentage,
    timestamp: Time.now,
    recommendation: "Decompose task to reduce context pressure"
  }.to_json  # ← .to_json produces a string: '{"percentage":80,...}'
})

# Line 95: new WorkflowRun metadata stored as JSON string
metadata: { "handed_off_from" => @workflow_run.id.to_s }.to_json
# ← .to_json on the entire hash produces a string, not a hash!
```

**Verified with rails runner:**
```
wf.update!(metadata: wf.metadata.merge({'test_key' => {'nested' => 'value'}.to_json}))
puts wf.reload.metadata.inspect
# Output: {"test_key"=>"{\"nested\":\"value\"}"}  ← String, not Hash
```

This means:
- `metadata["context_warning"]` returns a JSON string, not a Ruby hash
- `metadata["cost_exceeded"]` returns a JSON string (test at line 262 acknowledges this with `assert cost_data.is_a?(String)` and `JSON.parse(cost_data)`)
- The new WorkflowRun's `metadata` is passed as a JSON string to a JSONB column — this will either cause an error or store a raw string

For the handoff hook (line 95), passing `.to_json` as the `metadata:` value passes a String where a Hash is expected for the JSONB column. The test at line 212 works around this with `JSON.parse(new_run.metadata)` — which means the entire metadata field is being stored as a JSON string.

This is an anti-pattern that:
1. Violates the Architect's note: "The `metadata` column is JSONB. `@workflow_run.update!(metadata: merged_hash)` is safer and more explicit."
2. Makes metadata queries broken (can't use JSONB operators on nested strings)
3. Was flagged in Architect SUGGESTION #R2-3 which was about string consistency for IDs, not about `.to_json`-ing entire value hashes

**Fix:** Remove all `.to_json` calls on values being stored in JSONB columns. Store native Ruby hashes directly.

#### DEDUCTION 7: `warn_at_threshold` return value is unused (-1 pt)
**File:** `app/services/legion/orchestrator_hooks_service.rb` lines 34-41

The `on_tool_called` block calls `warn_at_threshold(threshold)` but discards its return value. The method currently returns `nil` (or the return value of `update!`). If the missing 2× threshold block were added, this architectural issue would cause the `HookResult` to be silently dropped. The design requires refactoring to propagate hook results correctly:

```ruby
# Current (broken architecture)
@hook_manager.on(:on_tool_called) do |event_data, context|
  begin
    warn_at_threshold(threshold)  # return value DISCARDED
  rescue ...
  end
end
```

Should be:
```ruby
@hook_manager.on(:on_tool_called) do |event_data, context|
  begin
    warn_at_threshold(threshold)  # must RETURN the HookResult
  rescue ...
  end
end
```

---

### Plan Adherence Deductions (-5 pts)

#### DEDUCTION 8: Integration test #1 rewrites AC2 expectation to match incomplete implementation (-3 pts)
**File:** `test/services/legion/orchestrator_hooks_integration_test.rb` lines 43-47

The Architect-approved plan (item #16): "Full dispatch with iteration limit set low (5) → verify `iteration_limit` status"

The actual test asserts:
```ruby
# Line 43-47
# At threshold: warns. At 2x: blocks tool calls but doesn't change status.
# The hook only warns and updates metadata, it doesn't set status to iteration_limit.
assert_equal "running", @workflow_run.status   # ← WRONG: should be "iteration_limit"
assert @workflow_run.metadata.key?("iteration_warnings")
```

This test was **deliberately modified** to assert incorrect behavior, essentially documenting a known gap without flagging it as a gap. The comment on line 44 is a developer note that AC2 was not implemented. This should have been a BLOCKER reported to QA, not silently accommodated in the test.

#### DEDUCTION 9: Pre-QA checklist line count discrepancy (-2 pts)
**File:** `knowledge_base/epics/wip/epic-1-orchestration-foundation/feedback/pre-qa-checklist-PRD-1-05.md`

Pre-QA checklist states: "Tests implemented: 16 / 18 planned" and "2 tests from original plan merged/consolidated during architect amendment fixes."

Actual test count in file: 13 unit tests (not counting `teardown`). The two tests said to be "merged" were:
1. `test_iteration_hook_blocks_at_double_threshold` — ABSENT (not merged, deleted)
2. `test_registration_is_idempotent` — ABSENT (not merged, deleted)

The checklist misrepresents the implementation state by claiming 16/18 with consolidation when in fact 2 plan-required tests were dropped without AC coverage confirmation.

---

## Summary of Issues

| # | Issue | Severity | AC Impact | Deduction |
|---|-------|----------|-----------|-----------|
| 1 | AC2 unimplemented: no iteration_limit status, no blocked:true at 2× threshold | CRITICAL | AC2 | -8 |
| 2 | Cost hook test missing result.blocked assertion (Architect R2-1 partial miss) | MODERATE | AC7 | -4 |
| 3 | test_iteration_hook_blocks_at_double_threshold missing | HIGH | AC2 | -3 |
| 4 | Idempotency test missing | MODERATE | Checklist #15 | -3 |
| 5 | Error resilience test wrong stub (now correct for current code, minor) | LOW | AC9 | -2 |
| 6 | .to_json anti-pattern in JSONB — metadata stored as strings | MODERATE | AC10 | -3 |
| 7 | warn_at_threshold return value discarded | LOW | AC2 | -1 |
| 8 | Integration test rewrites AC2 to accept wrong behavior | HIGH | AC2/Plan | -3 |
| 9 | Pre-QA checklist misrepresents test count | LOW | Plan | -2 |
| **Total** | | | | **-29** |

---

## Remediation Steps Required

### R1: Implement AC2 — 2× threshold blocking (MUST FIX — BLOCKER)
**File:** `app/services/legion/orchestrator_hooks_service.rb`

Refactor `warn_at_threshold` to handle three zones and return a `HookResult`:

```ruby
def warn_at_threshold(threshold)
  @iteration_count ||= 0
  @iteration_count += 1

  if @iteration_count >= threshold * 2
    # Block at 2× threshold — update status and signal blocked
    Rails.logger.warn("[OrchestratorHooks] Iteration limit reached: count=#{@iteration_count}, " \
                      "threshold=#{threshold * 2}, workflow_run_id=#{@workflow_run.id}")
    @workflow_run.update!(
      status: :iteration_limit,
      metadata: @workflow_run.metadata.merge({
        "iteration_limit" => { iteration: @iteration_count, timestamp: Time.now.to_s },
        "iteration_count" => @iteration_count
      })
    )
    return AgentDesk::Hooks::HookResult.new(blocked: true)
  elsif @iteration_count >= threshold
    # Warn zone
    Rails.logger.warn("[OrchestratorHooks] Iteration warning: count=#{@iteration_count}, " \
                      "threshold=#{threshold}, workflow_run_id=#{@workflow_run.id}")
    current_warnings = @workflow_run.metadata["iteration_warnings"] || []
    current_warnings << { iteration: @iteration_count, timestamp: Time.now.to_s }
    @workflow_run.update!(
      metadata: @workflow_run.metadata.merge({
        "iteration_count" => @iteration_count,
        "iteration_warnings" => current_warnings
      })
    )
  end
  nil
end
```

Also fix the `on_tool_called` hook to return the value from `warn_at_threshold`:
```ruby
@hook_manager.on(:on_tool_called) do |event_data, context|
  begin
    warn_at_threshold(threshold)  # ← return value now propagated
  rescue StandardError => e
    Rails.logger.error("[OrchestratorHooks] Iteration budget hook error: #{e.message}")
    nil
  end
end
```

### R2: Add missing test — test_iteration_hook_blocks_at_double_threshold (MUST FIX)
**File:** `test/services/legion/orchestrator_hooks_service_test.rb`

```ruby
def test_iteration_hook_blocks_at_double_threshold
  threshold = OrchestratorHooks.iteration_threshold_for_model("deepseek-reasoner")
  OrchestratorHooksService.call(
    hook_manager: @hook_manager,
    workflow_run: @workflow_run,
    team_membership: @team_membership
  )

  # Trigger calls up to (but not including) 2× threshold — should only warn
  (threshold * 2 - 1).times { @hook_manager.trigger(:on_tool_called, {}, {}) }
  refute_equal "iteration_limit", @workflow_run.reload.status

  # Trigger the 2× threshold call — should block and set status
  result = @hook_manager.trigger(:on_tool_called, {}, {})
  assert_equal "iteration_limit", @workflow_run.reload.status
  assert result.blocked, "Should block tool calls at 2× threshold"
  assert @workflow_run.metadata.key?("iteration_limit")
end
```

### R3: Fix integration test to assert correct AC2 behavior (MUST FIX)
**File:** `test/services/legion/orchestrator_hooks_integration_test.rb` lines 43-47

Replace:
```ruby
assert_equal "running", @workflow_run.status  # ← wrong
assert @workflow_run.metadata.key?("iteration_warnings")
```
With:
```ruby
assert_equal "iteration_limit", @workflow_run.reload.status
assert @workflow_run.metadata.key?("iteration_limit")
```

### R4: Fix .to_json anti-pattern in JSONB metadata (MUST FIX)
**File:** `app/services/legion/orchestrator_hooks_service.rb` lines 54-70, 95, 126-131

Remove all `.to_json` calls on values stored in JSONB columns. Store native hashes:

```ruby
# Context pressure hook — BEFORE
"context_warning" => {
  percentage: percentage,
  timestamp: Time.now,
  recommendation: "Decompose task..."
}.to_json

# AFTER
"context_warning" => {
  "percentage" => percentage,
  "timestamp" => Time.now.to_s,
  "recommendation" => "Decompose task..."
}

# Handoff hook new_run — BEFORE
metadata: { "handed_off_from" => @workflow_run.id.to_s }.to_json

# AFTER
metadata: { "handed_off_from" => @workflow_run.id.to_s }

# Cost hook — BEFORE
"cost_exceeded" => {
  cumulative_cost: ...,
  ...
}.to_json

# AFTER
"cost_exceeded" => {
  "cumulative_cost" => event_data[:cumulative_cost],
  "cost_budget" => event_data[:cost_budget],
  "last_message_cost" => event_data[:last_message_cost],
  "timestamp" => Time.now.to_s
}
```

Also fix the test at line 262 which currently asserts `cost_data.is_a?(String)` — after the fix it should be a Hash:
```ruby
cost_data = @workflow_run.reload.metadata["cost_exceeded"]
assert cost_data.is_a?(Hash), "cost_exceeded should be a hash"
assert_equal 10.50, cost_data["cumulative_cost"].to_f
```

### R5: Add cost hook result assertion (refute result.blocked) (MUST FIX)
**File:** `test/services/legion/orchestrator_hooks_service_test.rb` line 232

In `test_cost_hook_blocks_and_updates_status`, add:
```ruby
result = @hook_manager.trigger(:on_cost_budget_exceeded, { ... }, {})
assert_equal "budget_exceeded", @workflow_run.reload.status
refute result.blocked, "Cost hook must return non-blocked to allow runner's default :stop"
```

### R6: Add idempotency test (SHOULD FIX)
**File:** `test/services/legion/orchestrator_hooks_service_test.rb`

```ruby
def test_registration_is_idempotent
  service = OrchestratorHooksService.new(
    hook_manager: @hook_manager,
    workflow_run: @workflow_run,
    team_membership: @team_membership
  )

  service.call
  @hook_manager.trigger(:on_tool_called, {}, {})
  first_count = @workflow_run.reload.metadata["iteration_count"] || 1

  service.call  # second call — should be no-op
  @hook_manager.trigger(:on_tool_called, {}, {})
  second_count = @workflow_run.reload.metadata["iteration_count"] || 1

  # Should have incremented only once per trigger, not double (handlers not duplicated)
  assert_equal first_count + 1, second_count
end
```

---

## What Was Implemented Well

1. **Configuration module** (`orchestrator_hooks.rb`) — Clean constants, correct threshold values, good encapsulation of `iteration_threshold_for_model`.
2. **3 of 4 hooks correctly structured** — Context pressure (AC3/AC4), handoff capture (AC5/AC6), and cost budget (AC7 partially) hooks all have correct event data keys and semantics.
3. **All 4 hooks have begin/rescue** — AC9 compliance with correct error logging pattern.
4. **Local closure counter** (`@iteration_count`) — Correct Architect SUGGESTION R2-4 applied; reduces DB writes significantly.
5. **AgentAssemblyService integration** — `build_hook_manager` correctly calls `OrchestratorHooksService.call` (AC11).
6. **Test infrastructure** — FactoryBot + ActiveSupport::TestCase, correct idempotency mechanism, well-structured test setup.
7. **Hook semantics** — `on_token_budget_warning` at 60% returns `blocked: false`, at 80% returns `blocked: true`. `on_cost_budget_exceeded` returns `nil`. All correct per Architect guidance.
8. **RuboCop clean, frozen_string_literal present** — All 6 files pass.
9. **Full test suite green** — 183 runs, 0 failures (non-PRD tests unaffected).

---

## Known Documented Gap (Not Deducted)

**TokenBudgetTracker not wired** — `AgentAssemblyService` still passes `token_budget_tracker: nil` to Runner. Token budget and cost hooks will not fire in production dispatch. This is documented in both the Pre-QA checklist and the code with a `# TODO` comment. This was accepted by the Architect as a follow-up scope item and is not deducted here.

---

## Re-QA Requirements

If submitted for re-QA after remediation, the following must be verified:
1. `test_iteration_hook_blocks_at_double_threshold` — exists and passes
2. `test_registration_is_idempotent` — exists and passes
3. `integration test #1` — asserts `iteration_limit` status
4. All `.to_json` removed from JSONB metadata assignments
5. `test_cost_hook_records_cost_data_in_metadata` — `cost_data.is_a?(Hash)`, not `String`
6. `test_cost_hook_blocks_and_updates_status` — includes `refute result.blocked`
7. `bundle exec rails test` — still 0 failures

**Target score after remediation:** 91-94/100 (PASS)

---

*QA report generated: 2026-03-08*
*Permanent record for retrospective analysis (Φ14)*
