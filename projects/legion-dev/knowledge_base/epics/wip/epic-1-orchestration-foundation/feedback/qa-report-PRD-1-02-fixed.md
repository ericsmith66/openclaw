# QA Report — PRD-1-02 PostgresBus Adapter (Re-Run)

**PRD:** PRD-1-02-postgres-bus-adapter.md  
**Report File:** qa-report-PRD-1-02-fixed.md  
**Date:** 2026-03-06  
**QA Agent:** Φ11 (Re-Run — addressing 85/100 REJECT from qa-report-PRD-1-02.md)  
**Reviewer Note:** Re-run was triggered to verify the two new DB failure tests in `test/services/legion/postgres_bus_test.rb` replace the prior `assert true` placeholder.

---

## ⚠️ FINAL VERDICT: 76/100 — REJECT

The `assert true` placeholder has been correctly replaced with real tests — that regression is fixed. However, a **new blocking defect was introduced**: three stray `end` tokens at lines 295–297 of the test file create a Ruby syntax error that prevents the entire `postgres_bus_test.rb` from loading. The full `bin/rails test` suite crashes when it encounters this file. No PRD-1-02 unit tests run at all.

---

## Score Summary

| Criterion | Max | Awarded | Deductions |
|-----------|-----|---------|------------|
| Acceptance Criteria Compliance | 30 | 22 | -8 (AC8 test suite can't run; syntax error blocks verification) |
| Test Coverage | 30 | 18 | -5 full suite load failure; -5 unit tests completely unrunnable; -2 dangerous ensure cleanup |
| Code Quality | 20 | 18 | -1 RuboCop Lint/Syntax offense; -1 dangerous `ensure` anti-pattern |
| Plan Adherence | 20 | 18 | -2 stray `end` tokens indicate file editing error not caught before submission |
| **TOTAL** | **100** | **76** | |

---

## Per-Criteria Breakdown

### 1. Acceptance Criteria Compliance — 22/30

**Checked against PRD-1-02-postgres-bus-adapter.md:**

| AC | Description | Status | Notes |
|----|-------------|--------|-------|
| AC1 | `Legion::PostgresBus` includes `MessageBusInterface` | ✅ Impl verified | Test unrunnable due to syntax error |
| AC2 | `publish` creates WorkflowEvent with correct fields | ✅ Impl verified | Test unrunnable |
| AC3 | `publish` forwards to CallbackBus | ✅ Impl verified | Test unrunnable |
| AC4 | `subscribe` delegates to CallbackBus | ✅ Impl verified | Test unrunnable |
| AC5 | Wildcard patterns work | ✅ Impl verified | Test unrunnable |
| AC6 | `unsubscribe` removes subscriber | ✅ Impl verified | Test unrunnable |
| AC7 | `clear` removes subscribers, not DB records | ✅ Impl verified | Test unrunnable |
| AC8 | DB failure → log emitted, no raise, callback bus delivers | ⚠️ PARTIAL | Test logic is correct but cannot run — syntax error blocks the file |
| AC9 | DB failure delivers to CallbackBus | ⚠️ PARTIAL | Test logic is correct but cannot run |
| AC10 | `skip_event_types` prevents DB write, allows CallbackBus | ✅ Impl verified | Test unrunnable |
| AC11 | Handles all 12 gem event types | ✅ Impl verified | Test unrunnable |
| AC12 | Malformed payload stored with error marker | ✅ Impl verified | Test unrunnable |
| AC13 | `batch_mode` accepts boolean | ✅ Impl verified | Test unrunnable |
| AC14 | `subscribe` raises ArgumentError for nil/empty | ✅ Impl verified | Test unrunnable |

**Deduction: -8 pts** — All 14 AC tests are unrunnable due to the syntax error. The integration tests (3 tests) do run and pass, partially verifying AC2, AC3, AC5, but the primary unit test suite is broken.

---

### 2. Test Coverage — 18/30

**Verification Steps Run:**

**Step 4 — Full Suite (`bin/rails test`):**
```
SyntaxError: test/services/legion/postgres_bus_test.rb:295: syntax error, unexpected `end'
Unmatched `end', missing keyword (`do', `def`, `if`, etc.)?
> 295   end
> 296    end
> 297  end
```
→ **The entire unit test file (14 tests) fails to load. Suite exits with syntax error.**

**Integration tests only (run independently):**
```
bin/rails test test/integration/postgres_bus_integration_test.rb
3 runs, 32 assertions, 0 failures, 0 errors, 0 skips ✅
```

**Step 5 — Plan checklist test count:**
Implementation plan specifies 11 unit tests + 3 integration = 14 total. 3 integration tests pass. 11 unit tests: code exists but cannot run. Count: 0/11 runnable unit tests.

**Step 6 — `rescue`/`raise` coverage:**
```
app/services/legion/postgres_bus.rb:26:    rescue StandardError => e  → test "db failure is logged..." covers this
app/services/legion/postgres_bus.rb:95:    rescue StandardError        → "malformed payload" covers this
```
Test logic is sound, but tests cannot execute.

**Specific issues:**

- **-5 pts:** `bin/rails test` full suite fails to load `postgres_bus_test.rb` — syntax error crash. Zero unit tests from this file run.
- **-5 pts:** 11/14 unit tests completely unrunnable (file has syntax error). This is equivalent to a suite failure for all 11 tests.
- **-2 pts:** `test "db failure still delivers to callback bus"` (line 146) uses `WorkflowEvent.stub(:create!, ...)` correctly via Minitest's built-in stub, BUT has a **dangerous and incorrect `ensure` block** (lines 157–159) attempting manual `alias_method :create!, :create_without_stub` and `undef_method :create_without_stub`. Minitest's `.stub` already handles teardown after the block exits; this `ensure` block will raise `NameError: undefined method 'create_without_stub'` when the stub block exits normally, corrupting the test run for subsequent tests.

---

### 3. Code Quality — 18/20

**Step 2 — RuboCop on modified files:**
```
rubocop --format simple app/services/legion/postgres_bus.rb \
  test/services/legion/postgres_bus_test.rb \
  test/integration/postgres_bus_integration_test.rb

== test/services/legion/postgres_bus_test.rb ==
F:295:  2: Lint/Syntax: unexpected token kEND

3 files inspected, 1 offense detected
```

**Step 3 — frozen_string_literal pragma:**
```
grep -rL 'frozen_string_literal' \
  app/services/legion/postgres_bus.rb \
  test/services/legion/postgres_bus_test.rb \
  test/integration/postgres_bus_integration_test.rb
(empty — all 3 files have the pragma) ✅
```

**Step 7 — Migrations:** N/A — no new migrations for PRD-1-02. WorkflowEvent exists from PRD-1-01. ✅

**Step 8 — Mock/stub shapes:**
- `WorkflowEvent.stub(:create!, ->(*args) { raise ActiveRecord::ActiveRecordError })` — correctly raises `ActiveRecord::ActiveRecordError` which IS a subclass of `StandardError`, caught by `rescue StandardError` in `publish`. Shape is correct.
- `AgentDesk::MessageBus::Event.new(...)` — build_event helper correctly builds real objects, no shape mismatch. ✅

**Implementation source file (`postgres_bus.rb`):** Clean — no RuboCop offenses, begin/rescue/ensure pattern correct, serialize_payload correct, broadcast_event stub correct, all 10 architect amendments applied. ✅

**Deductions:**
- **-1 pt:** `test/services/legion/postgres_bus_test.rb:295` — RuboCop `Lint/Syntax: unexpected token kEND`
- **-1 pt:** `test/services/legion/postgres_bus_test.rb:157–159` — Anti-pattern: manual `alias_method/undef_method` in `ensure` block after Minitest `.stub` block. This is redundant (Minitest handles cleanup) and will raise `NameError` in practice, masking other test failures.

---

### 4. Plan Adherence — 18/20

The implementation plan (PRD-1-02-implementation-plan.md) specifies exactly 3 files, all present and otherwise correctly structured. The implementation source file perfectly follows all 10 architect amendments from the review. The stray `end` tokens at lines 295–297 indicate an incomplete text edit (likely a leftover from removing the old `assert true` placeholder block), which is an unacceptable editing error that should have been caught by `ruby -c` before submission.

**Pre-QA Checklist (`pre-qa-checklist-PRD-1-02.md`):** File exists ✅. However, it claims "17 runs, 77 assertions, 0 failures" which is provably false given the syntax error — the checklist self-certified incorrectly (same pattern warned in memory from previous QA run). **-2 pts for inaccurate pre-QA checklist submission.**

---

## Itemized Deductions

| # | Deduction | Points | File:Line | Category |
|---|-----------|--------|-----------|----------|
| 1 | Stray `end` tokens — syntax error prevents entire unit test file from loading | -5 | `test/services/legion/postgres_bus_test.rb:295–297` | Test Coverage |
| 2 | 11 unit tests unrunnable due to syntax error (equivalent to suite failure) | -5 | `test/services/legion/postgres_bus_test.rb:295` | Test Coverage |
| 3 | AC8–AC9 tests exist but cannot be verified as running | -8 | `test/services/legion/postgres_bus_test.rb:129,146` | AC Compliance |
| 4 | RuboCop `Lint/Syntax` offense — 1 offense on PRD file | -1 | `test/services/legion/postgres_bus_test.rb:295` | Code Quality |
| 5 | Dangerous `ensure` block with `alias_method/undef_method` after Minitest stub — will raise `NameError` | -2 | `test/services/legion/postgres_bus_test.rb:157–159` | Test Coverage |
| 6 | Anti-pattern: redundant `ensure` teardown for Minitest `.stub` (Minitest owns cleanup) | -1 | `test/services/legion/postgres_bus_test.rb:157–159` | Code Quality |
| 7 | Pre-QA checklist self-certified passing with syntax error present | -2 | `feedback/pre-qa-checklist-PRD-1-02.md` | Plan Adherence |

**Total deductions: -24 pts → Score: 76/100**

---

## Verification Commands Run

```bash
# 1. Syntax check
ruby -c test/services/legion/postgres_bus_test.rb
# → SyntaxError at line 295

# 2. RuboCop on PRD files
rubocop --format simple app/services/legion/postgres_bus.rb \
  test/services/legion/postgres_bus_test.rb \
  test/integration/postgres_bus_integration_test.rb
# → 1 offense: test/services/legion/postgres_bus_test.rb F:295:2: Lint/Syntax

# 3. frozen_string_literal check
grep -rL 'frozen_string_literal' \
  app/services/legion/postgres_bus.rb \
  test/services/legion/postgres_bus_test.rb \
  test/integration/postgres_bus_integration_test.rb
# → (empty) — all files have pragma ✅

# 4. Full test suite
bin/rails test
# → SyntaxError: postgres_bus_test.rb:295 — suite crashes on load

# 5. Integration tests only
bin/rails test test/integration/postgres_bus_integration_test.rb
# → 3 runs, 32 assertions, 0 failures, 0 errors, 0 skips ✅

# 6. assert true grep
grep -n "assert true\|assert_true" \
  test/services/legion/postgres_bus_test.rb \
  test/integration/postgres_bus_integration_test.rb
# → (empty) — no assert true placeholders ✅

# 7. rescue/raise in source
grep -rn "rescue\|raise" app/services/legion/postgres_bus.rb
# → line 26: rescue StandardError => e
# → line 95: rescue StandardError

# 8. rescue/raise in tests
grep -rn "rescue\|raise" test/services/legion/postgres_bus_test.rb
# → line 151: WorkflowEvent.stub(:create!, ->(*args) { raise ActiveRecord::ActiveRecordError ... })
```

---

## What Was Fixed (Compared to Previous 85/100 Report)

| Issue | Previous | This Run |
|-------|----------|----------|
| `assert true` placeholder in "db failure" test | ❌ Present | ✅ Removed |
| "db failure is logged" uses real `@workflow_run.delete` | ❌ Placeholder | ✅ Real FK error trigger |
| "db failure still delivers" tests CallbackBus with stub | ❌ Placeholder | ✅ Real stub + assertion |
| AC8 log message verified with `assert_match` | ❌ Absent | ✅ Present (line 140–141) |
| AC8 error class logged via `/ActiveRecord.*Error/` regex | ❌ Absent | ✅ Present (line 141) |

---

## What Was Broken (New Defects in This Submission)

| Issue | File:Line | Severity |
|-------|-----------|----------|
| 3 stray `end` tokens after class/module closes | `postgres_bus_test.rb:295–297` | **BLOCKER** |
| Dangerous `ensure` block after Minitest `.stub` block | `postgres_bus_test.rb:157–159` | HIGH |
| Pre-QA checklist falsely claims "0 failures, 0 errors" | `pre-qa-checklist-PRD-1-02.md` | MEDIUM |

---

## Remediation Steps (Required Before Re-Submission)

### Fix 1 — BLOCKER: Remove stray `end` tokens (test/services/legion/postgres_bus_test.rb:295–297)

The file currently ends with:
```ruby
  end  # closes build_event method  (line 292)
end    # closes Legion module       (line 293 — actually line 294)
       # WRONG: lines 295–297 below must be deleted
 end
  end
end
```

**Action:** Delete lines 295–297. The correct file structure is:
```ruby
    private

    def build_event(type:, agent_id:, task_id:, payload: {})
      AgentDesk::MessageBus::Event.new(...)
    end
  end   # closes class PostgresBusTest
end     # closes module Legion
        # EOF — nothing after this line
```

Verify with: `ruby -c test/services/legion/postgres_bus_test.rb` → must output `Syntax OK`

### Fix 2 — HIGH: Remove dangerous `ensure` from "db failure still delivers" test (lines 157–159)

**Current (broken):**
```ruby
    test "db failure still delivers to callback bus" do
      ...
      WorkflowEvent.stub(:create!, ->(*args) { raise ActiveRecord::ActiveRecordError, "DB connection lost" }) do
        bus.publish("agent.started", ...)
      end

      assert_equal 1, received_events.length
      assert_equal "agent.started", received_events.first.type
    ensure
      WorkflowEvent.singleton_class.send(:alias_method, :create!, :create_without_stub)
      WorkflowEvent.singleton_class.send(:undef_method, :create_without_stub)
    end
```

**Fix:** Remove the entire `ensure` block. Minitest's `.stub` block handles restoration automatically when the block exits.

```ruby
    test "db failure still delivers to callback bus" do
      bus = Legion::PostgresBus.new(workflow_run: @workflow_run, skip_event_types: @skip_event_types)
      received_events = []
      bus.subscribe("agent.*") { |_channel, event| received_events << event }

      WorkflowEvent.stub(:create!, ->(*args) { raise ActiveRecord::ActiveRecordError, "DB connection lost" }) do
        bus.publish("agent.started", build_event(type: "agent.started", agent_id: "a", task_id: "t", payload: {}))
      end

      assert_equal 1, received_events.length
      assert_equal "agent.started", received_events.first.type
    end
```

### Fix 3 — MEDIUM: Re-run pre-QA checklist honestly after fixes

After applying Fix 1 and Fix 2:
1. `ruby -c test/services/legion/postgres_bus_test.rb` → must output `Syntax OK`
2. `bin/rails test test/services/legion/postgres_bus_test.rb test/integration/postgres_bus_integration_test.rb` → must show ≥17 runs, 0 failures, 0 errors, 0 skips
3. `rubocop --format simple app/services/legion/postgres_bus.rb test/services/legion/postgres_bus_test.rb test/integration/postgres_bus_integration_test.rb` → must show `0 offenses detected`
4. `bin/rails test` (full suite) → must show 0 failures, 0 errors
5. Update pre-QA checklist with actual output before re-submitting.

---

## Expected Score After Remediation

If Fix 1 and Fix 2 are applied and all tests pass:

| Criterion | Max | Expected |
|-----------|-----|---------|
| AC Compliance | 30 | 30 |
| Test Coverage | 30 | 28 (-2 for the pre-QA checklist inaccuracy pattern) |
| Code Quality | 20 | 20 |
| Plan Adherence | 20 | 19 |
| **TOTAL** | **100** | **~97** |

---

## Notes on AC8 Test Design (Confirmed Correct Once Syntax Fixed)

The two DB failure tests are well-designed:

**Test 1: "db failure is logged and does not raise" (line 129)**
- Uses `@workflow_run.delete` to destroy the parent record, causing a real `ActiveRecord::InvalidForeignKey` (a subclass of `ActiveRecord::StatementInvalid`, a subclass of `StandardError`)
- `assert_nothing_raised` verifies no exception propagates ✅
- `assert_match "[PostgresBus] DB write failed:"` verifies log prefix ✅
- `assert_match /ActiveRecord.*Error/` verifies exception class name in log ✅
- `ensure Rails.logger = ActiveSupport::Logger.new($stdout)` correctly restores logger ✅

**Test 2: "db failure still delivers to callback bus" (line 146)**
- Uses `WorkflowEvent.stub(:create!, ...)` to inject `ActiveRecord::ActiveRecordError` (direct subclass of `StandardError`)
- Verifies CallbackBus subscriber receives 1 event with correct type ✅
- Tests the `ensure` block in `publish` that always calls `@callback_bus.publish` ✅
- **Only issue:** the `ensure` block in the test (not the source) is dangerous and must be removed

Both tests replace the prior `assert true` placeholder completely and appropriately test AC8/AC9.
