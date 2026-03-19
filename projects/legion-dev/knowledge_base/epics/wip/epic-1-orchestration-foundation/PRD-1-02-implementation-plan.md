# Implementation Plan: PRD-1-02 PostgresBus Adapter

**PRD:** PRD-1-02-postgres-bus-adapter.md  
**Date:** 2026-03-06  
**Epic:** Epic 1 — Orchestration Foundation  
**Status:** In Progress

---

## 1. Overview

Implement `Legion::PostgresBus`, a MessageBus adapter that bridges the `agent_desk` gem's in-memory event system with PostgreSQL persistence.

---

## 2. File-by-File Changes

### 2.1 New Files

| File | Purpose |
|------|---------|
| `app/services/legion/postgres_bus.rb` | Main PostgresBus class implementing `AgentDesk::MessageBus::MessageBusInterface` |
| `test/services/legion/postgres_bus_test.rb` | Unit tests for PostgresBus |
| `test/integration/postgres_bus_integration_test.rb` | Integration tests for full event cycle |

### 2.2 Modified Files

| File | Changes |
|------|---------|
| (none) | No existing files require modification |

---

## 3. Implementation Details

### 3.1 `app/services/legion/postgres_bus.rb`

**Requirements:**
- Include `AgentDesk::MessageBus::MessageBusInterface` module
- Constructor accepts `workflow_run:` argument
- Internal `@callback_bus = AgentDesk::MessageBus::CallbackBus.new`
- Configuration options: `skip_event_types: []`, `batch_mode: false`

**Method: `publish(channel, event)`**
1. Check if event type is in `skip_event_types` → skip DB write if so
2. Create `WorkflowEvent` record with:
   - `workflow_run_id`
   - `event_type` (from `event.type`)
   - `channel`
   - `agent_id`
   - `task_id`
   - `payload` (from `event.payload`)
   - `recorded_at` (from `event.timestamp`)
3. Forward to `@callback_bus.publish(channel, event)`
4. Call `broadcast_event(channel, event)` (stub with TODO for Epic 4)

**Error Handling:**
- DB write failure → log with `Rails.logger.error`, still deliver to CallbackBus
- Malformed payload → store `{ "error": "payload not serializable" }`

### 3.2 `test/services/legion/postgres_bus_test.rb`

**Unit Tests:**
1. `test_publish_creates_workflow_event_with_correct_fields`
2. `test_publish_forwards_to_callback_bus_subscribers`
3. `test_subscribe_delays_to_callback_bus`
4. `test_wildcard_subscription_receives_matching_events`
5. `test_unsubscribe_removes_subscriber_from_callback_bus`
6. `test_clear_removes_subscribers_does_not_delete_db_records`
7. `test_db_failure_is_logged_does_not_raise`
8. `test_db_failure_still_delivers_to_callback_bus`
9. `test_skip_event_types_prevents_db_write_still_delivers_to_callback_bus`
10. `test_handles_all_11_gem_event_types`
11. `test_malformed_payload_stored_with_error_marker`

### 3.3 `test/integration/postgres_bus_integration_test.rb`

**Integration Tests:**
1. `test_full_cycle_workflow_run_to_events_to_subscribers`
2. `test_event_ordering_preserved_in_db`
3. `test_by_type_scope_returns_correct_subset`

---

## 4. Test Checklist (MUST-IMPLEMENT)

### 4.1 Unit Test Checklist

- [ ] AC1: `Legion::PostgresBus` includes `AgentDesk::MessageBus::MessageBusInterface`
- [ ] AC2: `publish(channel, event)` creates a `WorkflowEvent` record with correct field mapping
- [ ] AC3: `publish` forwards to internal CallbackBus after DB write
- [ ] AC4: Subscribers registered via `subscribe` receive events through CallbackBus
- [ ] AC5: Wildcard channel patterns work (e.g., `agent.*` matches `agent.started`)
- [ ] AC6: `unsubscribe` removes subscriber from CallbackBus
- [ ] AC7: `clear` removes all subscribers but does NOT delete WorkflowEvent records
- [ ] AC8: Database write failure is logged but does not raise — CallbackBus delivery still occurs
- [ ] AC9: `skip_event_types` option prevents specified event types from being persisted
- [ ] AC10: Solid Cable broadcast stub exists as a private method with Epic 4 TODO
- [ ] AC11: All event types from the gem (11 types) can be persisted without error
- [ ] AC12: `rails test` — zero failures for PostgresBus tests

### 4.2 Integration Test Checklist

- [ ] Full cycle test: WorkflowRun → PostgresBus → events → DB + subscribers
- [ ] Event ordering test: Rapid publishes maintain `recorded_at` ordering
- [ ] Scope test: `WorkflowEvent.by_type` returns correct subset

---

## 5. Error Path Matrix

| Error Scenario | Exception Type | Logging | DB Record | CallbackBus Delivery |
|---------------|----------------|---------|-----------|---------------------|
| DB write failure | `ActiveRecord::StatementInvalid` | `Rails.logger.error` | None | ✅ Yes |
| Malformed payload (not JSON) | `ActiveRecord::SerializationFailure` | `Rails.logger.error` | Error marker in payload | ✅ Yes |
| WorkflowRun deleted mid-run | `ActiveRecord::RecordNotFound` | `Rails.logger.error` | N/A | ✅ Yes |
| CallbackBus subscription error | `StandardError` | `warn` (internal to CallbackBus) | ✅ Yes | N/A |

---

## 6. Migration Steps (None)

No database migrations required — `WorkflowEvent` model already exists from PRD-1-01.

---

## 7. Pre-QA Checklist

Execute **BEFORE** QA submission:

### 7.1 Code Quality
- [ ] Zero RuboCop offenses on all modified files
- [ ] `frozen_string_literal: true` pragma on all `.rb` files
- [ ] No dead code or unexercised error paths

### 7.2 Test Coverage
- [ ] All 11 unit tests implemented and passing
- [ ] All 3 integration tests implemented and passing
- [ ] All error paths have corresponding tests

### 7.3 Manual Verification
- [ ] Manual steps from PRD execute successfully
- [ ] All 12 acceptance criteria verified

**Save completed checklist to:** `{epic-dir}/feedback/pre-qa-checklist-PRD-1-02.md`

---

## 8. Implementation Order

1. Create `app/services/legion/postgres_bus.rb`
2. Create `test/services/legion/postgres_bus_test.rb`
3. Create `test/integration/postgres_bus_integration_test.rb`
4. Run RuboCop, fix offenses
5. Run all tests, verify passing
6. Complete Pre-QA checklist
7. Save checklist to feedback directory
8. Submit to QA for scoring

---

## 9. Acceptance Criteria Verification

| AC # | Description | Verification Method |
|-----|-------------|-------------------|
| AC1 | Includes MessageBusInterface | `include?` check in test |
| AC2 | Creates WorkflowEvent with correct fields | DB inspection |
| AC3 | Forwards to CallbackBus | Test with subscriber |
| AC4 | Subscribe works via CallbackBus | Test with subscriber |
| AC5 | Wildcard patterns work | Test with `agent.*` pattern |
| AC6 | Unsubscribe removes subscriber | Count subscribers before/after |
| AC7 | Clear removes subscribers, not DB records | Count DB records after clear |
| AC8 | DB failure logged, no raise | Rescue block test |
| AC9 | skip_event_types works | Test with skip list |
| AC10 | Broadcast stub with TODO | Code inspection |
| AC11 | All 11 event types work | Test with each event type |
| AC12 | Zero test failures | `rails test` command |

---

## 10. Estimated Effort

- Implementation: 2 hours
- Unit tests: 1 hour
- Integration tests: 1 hour
- Pre-QA & fixes: 1 hour
- **Total: ~5 hours**

---

**Plan Created:** 2026-03-06  
**Ready for Architect Review:** ✅ Yes  
**Implementation Status:** In Progress

---

## Architect Review & Amendments

**Reviewer:** Architect Agent  
**Date:** 2026-03-06  
**Verdict:** APPROVED (with mandatory amendments below)

### Overall Assessment

This is a well-structured plan for a medium-complexity PRD. The file layout, AC-to-test mapping, error path matrix, and pre-QA checklist are all present and largely correct. The plan correctly identifies the delegation pattern to CallbackBus and the error-resilience requirement. However, there are several issues ranging from a correctness blocker to missing implementation detail that must be addressed before implementation.

---

### Amendments Made (tracked for retrospective)

#### BLOCKER 1 — [CHANGED] `publish` rescue block causes double CallbackBus delivery

The reference implementation in the epic master plan (lines 643–656) has a structural bug. When `persist_event` succeeds but `broadcast_event` (or any code after the CallbackBus line) raises, the `rescue` block calls `@callback_bus.publish(channel, event)` **again** — subscribers receive the event twice. Conversely, if `persist_event` raises, the happy path `@callback_bus.publish` is skipped (correct), and the rescue delivers it (correct). But the rescue is too broad.

**Required fix:** The `publish` method must ensure CallbackBus delivery happens **exactly once**, regardless of DB success or failure. Structure the method so that DB persistence is isolated in its own begin/rescue, and CallbackBus + broadcast always execute unconditionally after:

```ruby
def publish(channel, event)
  persist_event(channel, event) unless @skip_event_types.include?(event.type)
rescue StandardError => e
  Rails.logger.error(
    "[PostgresBus] DB write failed: #{e.class}: #{e.message} " \
    "(event: #{event.type}, run: #{@workflow_run.id})"
  )
ensure
  # CallbackBus delivery MUST happen exactly once, even if DB write fails.
  # broadcast_event is a no-op stub — safe to call unconditionally.
  @callback_bus.publish(channel, event)
  broadcast_event(channel, event)
end
```

**Why this matters:** Double delivery to subscribers (especially orchestrator hooks in PRD-1-05) could cause duplicate budget tracking, duplicate handoff creation, or double tool-blocking. This is a runtime correctness bug.

#### BLOCKER 2 — [CHANGED] Event type count is 12, not 11

The plan and PRD both say "11 gem event types." The actual count from the gem source is **12**:

1. `response.chunk`
2. `response.complete`
3. `tool.called`
4. `tool.result`
5. `agent.started`
6. `agent.completed`
7. `approval.request`
8. `approval.response`
9. `conversation.compacted`
10. `conversation.handoff`
11. `conversation.budget_warning`
12. `usage_recorded` (created directly in `Runner#record_budget_usage` via `Event.new`, not via the `Events` module)

Test #10 (`test_handles_all_11_gem_event_types`) must be renamed to `test_handles_all_12_gem_event_types` and must include `usage_recorded`. The AC11 reference should say "12 types." The test should enumerate all 12 types and verify each can be persisted as a WorkflowEvent without error.

**Implementation guidance for the test:** Create a helper method or constant array listing all 12 event type strings. For each, create an `Event.new(type: type, agent_id: "test", task_id: "t1", payload: { test: true })` and publish it. Assert `WorkflowEvent.count == 12` and that each `event_type` value is present in the DB.

#### AMENDMENT 3 — [CHANGED] Error Path Matrix exception types are incorrect

| Error Scenario | Correct Exception Type | Notes |
|---|---|---|
| DB write failure (generic) | `ActiveRecord::ActiveRecordError` (or subclass) | `StatementInvalid` is one subclass but not the only one. Rescue `StandardError` as the plan's code does. |
| Malformed payload (not JSON-serializable) | `ActiveModel::RangedEachValidator` or `JSON::GeneratorError` via ActiveRecord | `ActiveRecord::SerializationFailure` is a PostgreSQL transaction serialization failure (SQLSTATE 40001), NOT a JSON serialization error. The actual error when JSONB can't serialize is typically raised during `to_json` internally. The `serialize_payload` guard method handles this before it reaches ActiveRecord. |
| WorkflowRun deleted mid-run | `ActiveRecord::InvalidForeignKey` | NOT `RecordNotFound`. The INSERT references a non-existent `workflow_run_id`, causing a FK violation — that's `InvalidForeignKey`, not `RecordNotFound`. `RecordNotFound` only fires on `find`/`find_by!`. |

**Required fix:** Update the Error Path Matrix to use correct exception classes. The rescue in `publish` catches `StandardError`, which is correct and sufficient — but the matrix must accurately document what actually happens for the retrospective and for QA to write targeted tests.

#### AMENDMENT 4 — [ADDED] Missing `serialize_payload` private method in implementation details

Section 3.1 mentions the malformed payload error scenario but doesn't specify the `serialize_payload` private method. The epic master plan (lines 685–690) includes it. This method is essential for AC8 (malformed payload resilience).

**Required addition to Section 3.1:** Add a `serialize_payload(payload)` private method specification:

```ruby
def serialize_payload(payload)
  return payload if payload.is_a?(Hash)
  { "error" => "payload not serializable", "class" => payload.class.name }
rescue StandardError
  { "error" => "payload serialization failed" }
end
```

The `persist_event` method must call `serialize_payload(event.payload)` rather than passing `event.payload` directly. This ensures that non-Hash payloads (if any future gem change produces them) are caught gracefully rather than raising during INSERT.

#### AMENDMENT 5 — [ADDED] Missing directory creation step

`app/services/` and `app/services/legion/` directories don't exist yet. The implementation order (Section 8) must include creating these directories as Step 0. Similarly, `test/services/` and `test/services/legion/` don't exist.

**Required addition to Section 8, Step 0:**
- Create `app/services/legion/` directory
- Create `test/services/legion/` directory

#### AMENDMENT 6 — [ADDED] Missing test for `batch_mode` constructor parameter

The PRD specifies `batch_mode: false` as a constructor option. Section 3.1 mentions it in the requirements, but there is NO corresponding test. Even though `batch_mode` is a stub (does nothing in Epic 1), the constructor should accept the parameter and store it, and a test should verify:
1. The parameter defaults to `false`
2. When set to `true`, behavior is identical to `false` (stub)
3. The attribute is stored (for future use)

**Add unit test #12:** `test_batch_mode_defaults_to_false_and_is_accepted`

This prevents a breaking change if someone passes `batch_mode: true` before it's implemented.

#### AMENDMENT 7 — [ADDED] Test for subscribe raising ArgumentError on nil/empty pattern

The CallbackBus raises `ArgumentError` when `pattern` is nil or empty (verified in the gem source). Since PostgresBus delegates `subscribe` directly to CallbackBus, this behavior passes through. However, there should be a test verifying this contract is preserved:

**Add unit test #13:** `test_subscribe_raises_argument_error_on_nil_or_empty_pattern`

This ensures the PostgresBus doesn't swallow the ArgumentError (e.g., if someone adds a begin/rescue around the delegation in the future).

#### AMENDMENT 8 — [CHANGED] Test name typo: "delays" should be "delegates"

Unit test #3 is named `test_subscribe_delays_to_callback_bus`. This should be `test_subscribe_delegates_to_callback_bus`.

#### AMENDMENT 9 — [ADDED] Explicit guidance on test helper event creation

Multiple tests need to create gem `Event` objects. The plan should specify a helper method in the test file (or use a `setup` block) to reduce boilerplate:

```ruby
def build_event(type: "agent.started", agent_id: "test-agent", task_id: "task-1", payload: {})
  AgentDesk::MessageBus::Event.new(
    type: type,
    agent_id: agent_id,
    task_id: task_id,
    payload: payload
  )
end
```

This is guidance only — not a new test.

#### AMENDMENT 10 — [ADDED] Log message format should include exception class

The PRD error scenario says "log the error." The plan says log with `Rails.logger.error`. The log message should include `e.class` in addition to `e.message` for diagnostic clarity (as shown in BLOCKER 1's code example). Example:

```
[PostgresBus] DB write failed: ActiveRecord::InvalidForeignKey: PG::ForeignKeyViolation... (event: agent.started, run: 42)
```

---

### Updated Test Checklist (MUST-IMPLEMENT)

After amendments, the full test list is **13 unit tests + 3 integration tests = 16 total**:

#### Unit Tests (test/services/legion/postgres_bus_test.rb)
1. `test_includes_message_bus_interface` — MUST-IMPLEMENT (AC1)
2. `test_publish_creates_workflow_event_with_correct_fields` — MUST-IMPLEMENT (AC2)
3. `test_publish_forwards_to_callback_bus_subscribers` — MUST-IMPLEMENT (AC3)
4. `test_subscribe_delegates_to_callback_bus` — MUST-IMPLEMENT (AC4)
5. `test_wildcard_subscription_receives_matching_events` — MUST-IMPLEMENT (AC5)
6. `test_unsubscribe_removes_subscriber_from_callback_bus` — MUST-IMPLEMENT (AC6)
7. `test_clear_removes_subscribers_does_not_delete_db_records` — MUST-IMPLEMENT (AC7)
8. `test_db_failure_is_logged_does_not_raise` — MUST-IMPLEMENT (AC8)
9. `test_db_failure_still_delivers_to_callback_bus` — MUST-IMPLEMENT (AC8)
10. `test_skip_event_types_prevents_db_write_still_delivers_to_callback_bus` — MUST-IMPLEMENT (AC9)
11. `test_handles_all_12_gem_event_types` — MUST-IMPLEMENT (AC11)
12. `test_malformed_payload_stored_with_error_marker` — MUST-IMPLEMENT (AC8)
13. `test_batch_mode_defaults_to_false_and_is_accepted` — MUST-IMPLEMENT (PRD config requirement)
14. `test_subscribe_raises_argument_error_on_nil_or_empty_pattern` — MUST-IMPLEMENT (interface contract)

#### Integration Tests (test/integration/postgres_bus_integration_test.rb)
15. `test_full_cycle_workflow_run_to_events_to_subscribers` — MUST-IMPLEMENT
16. `test_event_ordering_preserved_in_db` — MUST-IMPLEMENT
17. `test_by_type_scope_returns_correct_subset` — MUST-IMPLEMENT

### Updated Error Path Matrix

| Error Scenario | Exception Type | Logging | DB Record | CallbackBus Delivery | Test # |
|---|---|---|---|---|---|
| DB write failure (generic) | `ActiveRecord::ActiveRecordError` subclasses | `Rails.logger.error` with class + message | None | ✅ Yes (via ensure) | #8, #9 |
| Malformed payload (not Hash) | Caught by `serialize_payload` before DB | `Rails.logger.error` | Error marker payload | ✅ Yes (via ensure) | #12 |
| WorkflowRun deleted mid-run | `ActiveRecord::InvalidForeignKey` | `Rails.logger.error` | None | ✅ Yes (via ensure) | #8 |
| CallbackBus subscriber error | `StandardError` (caught by CallbackBus internally) | `warn` (internal to gem) | ✅ Yes (already persisted) | N/A (per-subscriber isolation) | — |
| nil/empty subscribe pattern | `ArgumentError` (from CallbackBus) | N/A (raises to caller) | N/A | N/A | #14 |

### Updated Implementation Order

0. Create directories: `app/services/legion/`, `test/services/legion/`
1. Create `app/services/legion/postgres_bus.rb` (with BLOCKER 1 fix, AMENDMENT 4 serialize_payload, AMENDMENT 6 batch_mode)
2. Create `test/services/legion/postgres_bus_test.rb` (14 unit tests per updated checklist)
3. Create `test/integration/postgres_bus_integration_test.rb` (3 integration tests)
4. Run RuboCop, fix offenses
5. Run `rails test test/services/legion/ test/integration/postgres_bus_integration_test.rb` — zero failures
6. Complete Pre-QA checklist
7. Save checklist to `{epic-dir}/feedback/pre-qa-checklist-PRD-1-02.md`
8. Submit to QA for scoring

### Items NOT Requiring Change (Confirmed Correct)
- File paths `app/services/legion/postgres_bus.rb` — ✅ correct Rails service namespace
- CallbackBus delegation for `subscribe`, `unsubscribe`, `clear` — ✅ correct
- `clear` does NOT delete WorkflowEvent records — ✅ correct per PRD
- No migrations needed — ✅ correct, WorkflowEvent table exists from PRD-1-01
- Factory `:workflow_event` already exists in `test/factories/workflow_events.rb` — ✅ available
- Solid Cable broadcast as private no-op method — ✅ correct Epic 4 stub pattern

---

PLAN-APPROVED
