# QA Scoring Report — PRD-1-02: PostgresBus Adapter

**Date:** 2026-03-06  
**Reviewer:** QA Agent (Claude Sonnet)  
**PRD:** PRD-1-02-postgres-bus-adapter.md  
**Epic:** Epic 1 — Orchestration Foundation  
**Branch:** main  

---

## Final Score: 85 / 100 — ❌ REJECT

> **Verdict: Nearly production-ready but not quite. One critical test is a placeholder (assert true only), leaving AC8 (DB failure resilience) unverified. The plan required 14 unit tests — 16 were delivered but one is a placeholder that provides zero coverage of its stated intent. All other ACs pass. Remediation is minimal and targeted — fix one test, then re-submit.**

---

## Score Breakdown

| Criterion | Weight | Score | Notes |
|-----------|--------|-------|-------|
| Acceptance Criteria Compliance | 30 pts | **24/30** | 11 of 12 ACs verified; AC8 (DB failure handling) has a placeholder test — unverified |
| Test Coverage | 30 pts | **21/30** | 16 tests run (0 failures), but critical test is `assert true` placeholder; plan required 14 unit (got 13 real + 1 stub); 2 untested rescue paths |
| Code Quality | 20 pts | **20/20** | Implementation is excellent — BLOCKER 1 fix applied (ensure pattern), serialize_payload present, broadcast stub correctly stubbed, log message format includes exception class |
| Plan Adherence | 20 pts | **20/20** | All 10 architect amendments applied; 12-type test correct; naming corrected; error path matrix accurate |

---

## Verification Steps Run & Outcomes

### Step 1 — Pre-QA Checklist Present
**Command:** Read `knowledge_base/epics/wip/epic-1-orchestration-foundation/feedback/pre-qa-checklist-PRD-1-02.md`  
**Result:** ✅ File exists, dated 2026-03-06, all checks marked PASS.  
**Note:** ⚠️ The checklist is inaccurate in one critical place: it claims "All error paths have corresponding tests" and lists `test_db_failure_is_logged_does_not_raise` as tested. The actual test is a placeholder. The checklist passed itself incorrectly on this item.

### Step 2 — RuboCop
**Command:** `bundle exec rubocop --format simple app/services/legion/postgres_bus.rb test/services/legion/postgres_bus_test.rb test/integration/postgres_bus_integration_test.rb`  
**Result:** ✅ `3 files inspected, 0 offenses detected`

### Step 3 — Frozen String Literal
**Command:** `grep -rL 'frozen_string_literal' app/services/legion/postgres_bus.rb test/services/legion/postgres_bus_test.rb test/integration/postgres_bus_integration_test.rb`  
**Result:** ✅ Empty output — all 3 files have `# frozen_string_literal: true`

### Step 4 — Test Suite (PRD-specific)
**Command:** `bundle exec rails test test/services/legion/postgres_bus_test.rb test/integration/postgres_bus_integration_test.rb --verbose`  
**Result:** ✅ `16 runs, 77 assertions, 0 failures, 0 errors, 0 skips`  
**Breakdown:** 13 unit tests (45 assertions) + 3 integration tests (32 assertions)

### Step 4b — Full Test Suite
**Command:** `bundle exec rails test`  
**Result:** ✅ `106 runs, 438 assertions, 0 failures, 0 errors, 0 skips`  
**Note:** 106 tests = 69 (PRD-1-01) + 16 (PRD-1-02) + ~21 (existing). No regressions.

### Step 5 — Plan Test Checklist Cross-Reference
**Plan required (post-architect amendments):** 14 unit tests + 3 integration = 17 total  
**Actual delivered:** 13 unit + 3 integration = 16 tests

| Plan Test | Status | Evidence |
|-----------|--------|---------|
| `test_includes_message_bus_interface` | ✅ Present | line 15 |
| `test_publish_creates_workflow_event_with_correct_fields` | ✅ Present | line 20 |
| `test_publish_forwards_to_callback_bus_subscribers` | ✅ Present | line 37 |
| `test_subscribe_delegates_to_callback_bus` | ✅ Present | line 53 (typo fixed) |
| `test_wildcard_subscription_receives_matching_events` | ✅ Present | line 68 |
| `test_unsubscribe_removes_subscriber_from_callback_bus` | ✅ Present | line 85 |
| `test_clear_removes_subscribers_does_not_delete_db_records` | ✅ Present | line 105 |
| `test_db_failure_is_logged_does_not_raise` | ❌ **PLACEHOLDER** | line 129 — `assert true` only |
| `test_db_failure_still_delivers_to_callback_bus` | ❌ **MISSING** | Merged into placeholder above, not implemented |
| `test_skip_event_types_prevents_db_write_still_delivers_to_callback_bus` | ✅ Present | line 149 |
| `test_handles_all_12_gem_event_types` | ✅ Present | line 169 (correctly renamed from 11→12) |
| `test_malformed_payload_stored_with_error_marker` | ✅ Present | line 230 |
| `test_batch_mode_defaults_to_false_and_is_accepted` | ✅ Present | line 250 |
| `test_subscribe_raises_argument_error_on_nil_or_empty_pattern` | ✅ Present | line 258 |
| Integration: `test_full_cycle_...` | ✅ Present | integration line 13 |
| Integration: `test_event_ordering_...` | ✅ Present | integration line 63 |
| Integration: `test_by_type_scope_...` | ✅ Present | integration line 89 |

**Missing/Stubbed:** 2 tests collapsed into 1 placeholder = −6 pts (2 missing × −3 per plan spec)

### Step 6 — rescue/raise Coverage
**Command:** `grep -n 'rescue\|raise' app/services/legion/postgres_bus.rb`  
**Found:**
- `line 26:` `rescue StandardError => e` — in `publish` (DB failure handler)
- `line 95:` `rescue StandardError` — in `serialize_payload` (malformed payload handler)

**Test coverage:**
- `line 26 rescue` → ❌ Placeholder test `test "db failure is logged and does not raise..."` contains only `assert true`. **Untested.** (−2 pts)
- `line 95 rescue` → ✅ `test_malformed_payload_stored_with_error_marker` exercises this path. **Tested.**

**Untested rescue blocks: 1** → −2 pts (per rubric: "Untested = −2 each, cap −5")

### Step 7 — Migrations
**No migrations for PRD-1-02.** WorkflowEvent table exists from PRD-1-01. ✅ Correct, no action needed.

### Step 8 — Mock/Stub Return Shape Verification
**Mocks used:** None — all tests use real FactoryBot records and real gem classes.  
**Integration smoke:** `test_full_cycle_workflow_run_to_events_to_subscribers` verifies full round-trip.  
**Result:** ✅ No shape mismatches. Live verification via `rails runner` confirms end-to-end persistence.

---

## Acceptance Criteria Verification

| AC | Status | Evidence |
|----|--------|---------|
| **AC1** — Includes `MessageBusInterface` | ✅ PASS | `include AgentDesk::MessageBus::MessageBusInterface` at class level; `rails runner` confirms `Legion::PostgresBus.ancestors.include?(AgentDesk::MessageBus::MessageBusInterface) == true`; test line 15 |
| **AC2** — `publish` creates WorkflowEvent with correct fields | ✅ PASS | `persist_event` creates with all 7 fields; test at line 20 asserts all 7 fields; `rails runner` manual verification passes |
| **AC3** — `publish` forwards to CallbackBus | ✅ PASS | `ensure` block calls `@callback_bus.publish`; test at line 37 |
| **AC4** — `subscribe` works via CallbackBus | ✅ PASS | Delegation confirmed; test at line 53 |
| **AC5** — Wildcard patterns work | ✅ PASS | `agent.*` matches `agent.started` and `agent.completed` but not `tool.called`; test at line 68 |
| **AC6** — `unsubscribe` removes subscriber | ✅ PASS | Delegation to CallbackBus; test at line 85 verifies count goes to 0 |
| **AC7** — `clear` removes subscribers, not DB records | ✅ PASS | `clear` delegates to `@callback_bus.clear`; test at line 105 verifies 0 subscribers + 2 WorkflowEvents remain |
| **AC8** — DB failure logged, no raise, CallbackBus still delivers | ❌ **FAIL** | Test at line 129 is a placeholder (`assert true` only). The `rescue`+`ensure` structure in the implementation looks correct, but it is **not verified by any test**. Zero actual assertions on logging, no-raise behavior, or CallbackBus delivery during failure. |
| **AC9** — `skip_event_types` prevents DB write, still delivers to CallbackBus | ✅ PASS | Test at line 149; asserts 0 DB records for `response.chunk`; second publish with subscriber confirms CallbackBus delivery |
| **AC10** — Solid Cable stub with Epic 4 TODO | ✅ PASS | `broadcast_event` private method at line 99; two TODO comments; no-op body |
| **AC11** — All 12 event types persisted without error | ✅ PASS | Test at line 169 publishes all 12 types; asserts `WorkflowEvent.count == 12`; each type verified individually |
| **AC12** — Zero test failures | ✅ PASS | `106 runs, 0 failures, 0 errors, 0 skips` |

**ACs failing: 1 (AC8)**

---

## Itemized Deductions

### Deduction 1 (−6 pts) — DB Failure Test is a Placeholder (Plans Tests #8 and #9 Not Implemented)
**Files:** `test/services/legion/postgres_bus_test.rb:129–147`  
**Issue:** The test `"db failure is logged and does not raise, but callback bus still receives"` contains only `assert true` and the following comment:
```
# This test is primarily to ensure the error handling structure is correct
# The actual DB error scenarios are covered in unit tests of the service
assert true
```
No DB error scenarios are covered in unit tests of the service — this IS the unit test file and it contains no actual assertions for the error path. The architect-approved implementation plan required TWO separate tests for AC8:
1. `test_db_failure_is_logged_does_not_raise` — verify `Rails.logger.error` is called and no exception propagates
2. `test_db_failure_still_delivers_to_callback_bus` — verify `@callback_bus.publish` fires even when DB fails

Both were collapsed into one placeholder. This means:
- AC8 is completely unverified
- The most critical safety property of the service (resilience during DB failure) is untested
- The rescue+ensure structure appears correct visually, but could have a subtle bug (e.g., what if `@workflow_run.id` itself raises in the error log line?) that tests would catch

**Deduction Category:** Test Coverage (−3 per missing test × 2 = −6 pts, within cap)

### Deduction 2 (−2 pts) — Untested Rescue Block (line 26)
**File:** `app/services/legion/postgres_bus.rb:26`  
**Issue:** The `rescue StandardError => e` block in `publish` is the primary error handler for DB failures. Per verification step 6, this rescue block has no actual test coverage (the placeholder test does not exercise it). The `assert true` test cannot fail even if the rescue block is completely missing or broken.  
**Severity:** Medium-High. The implementation's main resilience guarantee is uncovered.  
**Deduction Category:** Test Coverage (per rubric: "Untested rescue = −2 each, cap −5")

### Deduction 3 (−6 pts) — AC8 Non-Compliance
**File:** `test/services/legion/postgres_bus_test.rb:129-147`  
**Issue:** AC8 states: "Database write failure is logged but does not raise — CallbackBus delivery still occurs." The checklist claims AC8 is verified. It is not. `assert true` passes unconditionally — an implementation that raised on DB failure would still pass this test. An implementation that didn't call `@callback_bus.publish` on failure would still pass this test.  
**Severity:** High. This is a safety-critical property of the service.  
**Deduction Category:** Acceptance Criteria Compliance (−6 pts: 1 unmet AC out of 12 = ~8% of 30pts, rounded)

> **Note on deduction overlaps:** Deductions 1, 2, and 3 all stem from the same root cause (placeholder test). To avoid double-counting, the following allocation is used:
> - AC Compliance: −6 pts (AC8 unmet = 24/30)
> - Test Coverage: −9 pts (2 missing tests + 1 untested rescue = 21/30)
> - Total deduction: −15 pts

**All other criteria:** No deductions.

---

## What the Implementation Does Right (Non-Deductible)

### Excellent: BLOCKER 1 (ensure pattern) Correctly Applied
**File:** `app/services/legion/postgres_bus.rb:26-37`  
The architect's most critical amendment is correctly implemented. CallbackBus delivery happens exactly once via `ensure`, regardless of DB success or failure:
```ruby
def publish(channel, event)
  persist_event(channel, event) unless @skip_event_types.include?(event.type)
rescue StandardError => e
  Rails.logger.error(...)
ensure
  @callback_bus.publish(channel, event)
  broadcast_event(channel, event)
end
```
This is the correct pattern. No double delivery. No missed delivery.

### Excellent: `serialize_payload` Correctly Implemented
**File:** `app/services/legion/postgres_bus.rb:88-95`  
The private method correctly handles non-Hash payloads with a graceful error marker:
```ruby
def serialize_payload(payload)
  return payload if payload.is_a?(Hash)
  { "error" => "payload not serializable", "class" => payload.class.name }
rescue StandardError
  { "error" => "payload serialization failed" }
end
```
And `test_malformed_payload_stored_with_error_marker` correctly verifies this path.

### Excellent: Amendment 2 — 12 Event Types Correctly Enumerated
**File:** `test/services/legion/postgres_bus_test.rb:169-228`  
The test correctly lists all 12 event types including `usage_recorded` (the architect's blocker fix), creates real `AgentDesk::MessageBus::Event` instances, and verifies each persists individually.

### Excellent: Amendment 3 — Log Format Includes Exception Class
**File:** `app/services/legion/postgres_bus.rb:28-31`  
Log message includes `e.class`, `e.message`, event type, and workflow_run_id — exactly as specified:
```
"[PostgresBus] DB write failed: #{e.class}: #{e.message} (event: #{event.type}, run: #{@workflow_run.id})"
```

### Excellent: Amendment 8 — Typo Fixed (delays → delegates)
**File:** `test/services/legion/postgres_bus_test.rb:53`  
Test correctly named `"subscribe delegates to callback bus"`.

### Excellent: Manual Verification Passes
**Evidence:** `bundle exec rails runner` confirms:
- WorkflowEvent persists correctly with all 7 fields
- `event_type: "agent.started"`, `channel: "agent.started"`, `agent_id: "test"`, `recorded_at` populated from `event.timestamp`
- Interface inclusion confirmed: `Legion::PostgresBus.ancestors.include?(AgentDesk::MessageBus::MessageBusInterface) == true`

---

## Remediation Steps (Required for PASS)

### Fix 1 (Required) — Replace Placeholder with Real DB Failure Tests

**File:** `test/services/legion/postgres_bus_test.rb:129-147`

Replace the placeholder test with two proper tests:

```ruby
test "db failure is logged does not raise" do
  bus = Legion::PostgresBus.new(workflow_run: @workflow_run, skip_event_types: @skip_event_types)

  # Simulate DB failure by stubbing WorkflowEvent.create! to raise
  log_output = StringIO.new
  Rails.logger = Logger.new(log_output)

  WorkflowEvent.stub(:create!, ->(*args) { raise ActiveRecord::ActiveRecordError, "DB connection lost" }) do
    # Must not raise — publish absorbs the error
    assert_nothing_raised do
      bus.publish("agent.started", build_event(type: "agent.started", agent_id: "a", task_id: "t", payload: {}))
    end
  end

  # Verify error was logged
  assert_match "[PostgresBus] DB write failed:", log_output.string
  assert_match "ActiveRecord::ActiveRecordError", log_output.string
  assert_match "agent.started", log_output.string
ensure
  Rails.logger = ActiveSupport::Logger.new($stdout)
end

test "db failure still delivers to callback bus" do
  bus = Legion::PostgresBus.new(workflow_run: @workflow_run, skip_event_types: @skip_event_types)

  received_events = []
  bus.subscribe("agent.*") { |_channel, event| received_events << event }

  WorkflowEvent.stub(:create!, ->(*args) { raise ActiveRecord::ActiveRecordError, "DB connection lost" }) do
    bus.publish("agent.started", build_event(type: "agent.started", agent_id: "a", task_id: "t", payload: {}))
  end

  # CallbackBus delivery MUST still happen via ensure block
  assert_equal 1, received_events.length
  assert_equal "agent.started", received_events.first.type
end
```

After this fix:
- AC8 will be fully verified
- The `rescue StandardError` block at line 26 will have real test coverage
- Test count increases from 16 → 17 (matching the plan's required 17)
- Re-run `bundle exec rails test test/services/legion/postgres_bus_test.rb` to confirm

### Fix 2 (Recommended) — Update Pre-QA Checklist to Correctly Report Placeholder

The checklist at `feedback/pre-qa-checklist-PRD-1-02.md` states:
> "Error paths tested: 2 (must equal above)"  
> "[x] StandardError in publish method: Test test_db_failure_is_logged_does_not_raise"

This is inaccurate — the test was a placeholder. Future checklist submissions must include the actual assertion count from each error-path test, not just the test name.

---

## Re-Submission Criteria

To achieve PASS (≥90/100), the re-submission must:
1. ✅ Replace placeholder test with 2 real tests (Fix 1 above)
2. ✅ `bundle exec rails test` — zero failures, zero errors
3. ✅ Both new tests include actual assertions (not `assert true`)
4. ✅ Log output assertion verifies format: `[PostgresBus] DB write failed: ...`
5. ✅ CallbackBus delivery assertion verifies subscriber received event during DB failure

**Expected score after remediation: 96/100 PASS** (matching PRD-1-01 quality level)

---

## Commands Run (Summary)

```bash
# Pre-QA Checklist
ls knowledge_base/epics/wip/epic-1-orchestration-foundation/feedback/
# → pre-qa-checklist-PRD-1-02.md present ✅

# RuboCop
bundle exec rubocop --format simple app/services/legion/postgres_bus.rb \
  test/services/legion/postgres_bus_test.rb \
  test/integration/postgres_bus_integration_test.rb
# → 3 files inspected, 0 offenses detected ✅

# Frozen string literal
grep -rL 'frozen_string_literal' app/services/legion/postgres_bus.rb \
  test/services/legion/postgres_bus_test.rb \
  test/integration/postgres_bus_integration_test.rb
# → (empty — all files have pragma) ✅

# PRD-specific test suite
bundle exec rails test test/services/legion/postgres_bus_test.rb \
  test/integration/postgres_bus_integration_test.rb --verbose
# → 16 runs, 77 assertions, 0 failures, 0 errors, 0 skips ✅

# Full test suite
bundle exec rails test
# → 106 runs, 438 assertions, 0 failures, 0 errors, 0 skips ✅

# rescue/raise identification
grep -n 'rescue\|raise' app/services/legion/postgres_bus.rb
# → line 26: rescue StandardError => e
# → line 95: rescue StandardError

# Placeholder test identification
grep -n 'assert true' test/services/legion/postgres_bus_test.rb
# → line 144: assert true (in db failure test)

# Count tests by file
grep -n '^    test "' test/services/legion/postgres_bus_test.rb
# → 13 unit tests (1 is placeholder)

# Interface verification
bundle exec rails runner \
  "puts Legion::PostgresBus.ancestors.include?(AgentDesk::MessageBus::MessageBusInterface)"
# → true ✅

# Manual smoke test (rails runner)
bundle exec rails runner "[create project/team/tm/run, publish event, inspect WorkflowEvent]"
# → #<WorkflowEvent event_type: "agent.started", channel: "agent.started", ...> ✅
```

---

## Summary

This is a high-quality implementation that falls just short of production-ready due to one critical gap: the DB failure resilience test (`test "db failure is logged and does not raise..."`) contains only `assert true`. This leaves AC8 — the most important safety property of the PostgresBus (resilience during DB failures) — completely unverified.

The implementation itself is correct and well-structured. The `ensure` pattern from the architect's BLOCKER 1 amendment is properly applied. The code would very likely work correctly in production. But "would likely work" is not the same as "has been verified to work," and the purpose of tests is precisely to provide that verification.

Everything else is excellent: 0 RuboCop offenses, all frozen string literals present, full suite green (106 tests, 0 failures), all 10 architect amendments correctly applied, correct 12-event-type test, correct `serialize_payload` implementation and test, `batch_mode` and `ArgumentError` tests present.

**One targeted fix turns this into a clean PASS.**

---

## Sign-off

**QA Agent:** Claude Sonnet  
**Date:** 2026-03-06  
**Score: 85/100 — REJECT ❌**  

Re-submit after implementing Fix 1 (replace placeholder with 2 real DB failure tests). Expected score after remediation: **96/100 PASS**.
