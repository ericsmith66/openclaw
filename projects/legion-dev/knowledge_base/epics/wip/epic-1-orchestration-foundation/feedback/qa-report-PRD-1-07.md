# QA Report: PRD-1-07 — Plan Execution CLI

**Date:** 2026-03-07 (Re-score: 2026-03-07)
**PRD:** `knowledge_base/epics/wip/epic-1-orchestration-foundation/PRD-1-07-plan-execution-cli.md`
**Implementation Plan:** `knowledge_base/epics/wip/epic-1-orchestration-foundation/PRD-1-07-implementation-plan.md`
**QA Agent:** QA Specialist
**Epic:** Epic 1 — Orchestration Foundation
**Review Round:** 2 (Re-score after debug fixes)
**Previous Score:** 88/100 REJECT

---

## Final Score: 97/100 — PASS

> **Verdict:** PASS — All four previously-cited deductions have been resolved. The implementation is production-ready: zero dead variables, Amendment #7 exit code correctly implemented, execution WorkflowRun reverse link set, and integration test stub syntax corrected. One minor residual note (CLI exit code not tested at the bin/legion level) is noted but does not constitute a blocking defect given full service-layer coverage.

---

## Per-Criteria Breakdown

| Criterion | Max | Score | Notes |
|-----------|-----|-------|-------|
| Acceptance Criteria Compliance | 30 | 30 | All 14 ACs verified. AC4 (task_id reverse link) now set. |
| Test Coverage | 30 | 28 | 25 PRD-specific tests pass. CLI exit-code behavior tested indirectly via result struct; no direct bin/legion integration test (-2). |
| Code Quality | 20 | 20 | All 3 dead variables removed; `duration_s` in `print_task_result` is legitimate use. RuboCop clean. |
| Plan Adherence | 20 | 19 | Amendment #7 exit code implemented correctly. Integration test `.then.returns` fixed. Minor: CLI exit code test not added (-1). |

---

## Verification Commands Run

### 1. RuboCop
```
bundle exec rubocop --format simple \
  app/services/legion/plan_execution_service.rb \
  bin/legion \
  test/services/legion/plan_execution_service_test.rb \
  test/integration/plan_execution_integration_test.rb
```
**Result:** `4 files inspected, no offenses detected` ✅

### 2. frozen_string_literal
```
grep -rn 'frozen_string_literal' \
  app/services/legion/plan_execution_service.rb \
  bin/legion \
  test/services/legion/plan_execution_service_test.rb \
  test/integration/plan_execution_integration_test.rb
```
**Result:** All 4 files have `# frozen_string_literal: true` on line 1 ✅

### 3. Full Test Suite
```
bundle exec rails test
```
**Result:** `248 runs, 901 assertions, 0 failures, 0 errors, 0 skips` ✅

### 4. PRD-Specific Tests
```
bundle exec rails test \
  test/services/legion/plan_execution_service_test.rb \
  test/integration/plan_execution_integration_test.rb
```
**Result:** `25 runs, 100 assertions, 0 failures, 0 errors, 0 skips` ✅

### 5. Pre-QA Checklist
**File:** `knowledge_base/epics/wip/epic-1-orchestration-foundation/feedback/pre-qa-checklist-PRD-1-07.md`
**Result:** ✅ Present and complete (12/12 mandatory items checked)

### 6. Dead Variable Scan
```
grep -n 'task_map\|dep_statuses' app/services/legion/plan_execution_service.rb
```
**Result:** No output (empty) — both dead variables successfully removed ✅

### 7. duration_s in print_summary Scan
```
grep -n 'duration_s' app/services/legion/plan_execution_service.rb
```
**Result:** Lines 320, 322 — `duration_s` in `print_task_result` (legitimate: computed and used in the same method). **NOT** present in `print_summary`. ✅

### 8. Amendment #7 Exit Code Fix
```
grep -n 'elsif result.failed_count\|exit 3\|exit 0' bin/legion
```
**Result:**
```
55:        exit 0
58:        exit 3
61:        exit 3
95:          exit 3
96:        elsif result.failed_count > 0
97:          exit 3
100:        exit 0
140:        exit 0
149:        exit 3
152:        exit 3
```
`bin/legion:94-100` correctly implements Amendment #7 logic:
```ruby
if result.halted && result.halt_reason != "interrupted"
  exit 3
elsif result.failed_count > 0
  exit 3
end
exit 0
```
✅

### 9. WorkflowRun Reverse Link
```
grep -n 'execution_run.update\|task_id' app/services/legion/plan_execution_service.rb
```
**Result:** Line 120: `execution_run.update!(task: task) if execution_run.task_id.nil?` ✅

### 10. Integration Test Stub Syntax
```
grep -n '\.then\.returns' test/integration/plan_execution_integration_test.rb
```
**Result:** Lines 50, 72 — valid `.returns(...).then.returns(...)` chain syntax ✅

### 11. Error/Rescue Coverage
```
grep -n 'rescue\|raise' app/services/legion/plan_execution_service.rb
```
All rescue/raise paths verified:
- Line 105: `raise DeadlockError` → `test_deadlock_detection_raises_error` ✅
- Line 127: `rescue StandardError => e` (dispatch failure) → `test_halt_on_first_failure`, `test_continue_on_failure_*` ✅
- Line 171: `raise Interrupt` → `test_sigint_simulation_marks_loop_as_interrupted_and_halts` ✅
- Line 183: `raise WorkflowRunNotFoundError` → `test_workflow_run_not_found_raises_error` ✅
- Line 193: `raise NoTasksFoundError` → `test_empty_task_list_raises_error` ✅
- Line 206: `raise StartFromTaskNotFoundError` → `test_start_from_task_not_found_raises_error` ✅
- Lines 304, 345: `rescue StandardError` (profile fallback) → covered by happy-path tests ✅
- Lines 393, 402: `rescue StandardError` (count helpers → return 0) → benign, no fatal path ✅

### 12. Migration Integrity
No new migrations required. Existing schema confirmed:
- `tasks.execution_run_id` FK → `workflow_runs.id` ✅
- `workflow_runs.task_id` FK → `tasks.id` ✅
- `tasks.metadata` JSONB for error_message storage ✅

---

## Fix Verification Summary

| Fix # | Description | Previous Deduction | Status |
|-------|-------------|-------------------|--------|
| Fix 1 | Removed dead `task_map` variable in `compute_waves` | -1 Code Quality | ✅ RESOLVED |
| Fix 2 | Removed dead `dep_statuses` variable in `print_task_start` | -1 Code Quality | ✅ RESOLVED |
| Fix 3 | Removed dead `duration_s` variable in `print_summary` | -1 Code Quality | ✅ RESOLVED — `duration_s` in `print_task_result` is legitimate use |
| Fix 4 | `bin/legion` exit code 3 for `continue_on_failure` with failures (Amendment #7) | -7 (Plan -5, Quality -2) | ✅ RESOLVED |
| Fix 5 | `execution_run.update!(task: task)` sets reverse WorkflowRun.task_id | -2 (Plan -1, AC -1) | ✅ RESOLVED |
| Fix 6 | Integration test `.then.returns` chain syntax | (part of Fix 1-6 set) | ✅ RESOLVED |

**Total recovered from previous deductions: 12 points**

---

## Residual Deductions

### Deduction 1 — CLI Exit Code Not Tested at bin/legion Level
**Severity:** Minor
**Points Deducted:** -3 (Test Coverage: -2, Plan Adherence: -1)

The `bin/legion execute-plan` exit codes (0, 3, 4, 5) are verified correct by code inspection but are not exercised by any test. The service layer (`PlanExecutionService`) is fully tested and `result.failed_count` assertions exist in:
- `test_all_tasks_in_terminal_states_exits_without_dispatch` → `result.failed_count = 1`
- Integration test `continue_on_failure_integration` → `result.failed_count = 1`

However, no test verifies that `bin/legion execute-plan --workflow-run N --continue-on-failure` actually exits with code 3 when tasks fail. The Amendment #7 fix is correct but untested at the CLI integration level.

**Remediation (Optional — not blocking for PASS):**
Add a system test or CLI test that spawns `bin/legion execute-plan` as a subprocess and asserts the exit code:
```ruby
test "execute-plan exits 3 when continue-on-failure and tasks failed" do
  # set up workflow_run with a failed task...
  output = `bin/legion execute-plan --workflow-run #{run.id} --continue-on-failure`
  assert_equal 3, $?.exitstatus
end
```

---

## Acceptance Criteria Verification (All 14 ACs)

| AC | Description | Status | Evidence |
|----|-------------|--------|----------|
| AC1 | Dispatches tasks respecting dependency order | ✅ | T1, T18 integration |
| AC2 | Tasks with no dependencies dispatched first | ✅ | T2 parallel eligible |
| AC3 | Tasks dispatched only when ALL deps completed | ✅ | T1, T2, T18 |
| AC4 | Each task creates its own WorkflowRun | ✅ | T16, T19; `execution_run.update!(task: task)` sets reverse link |
| AC5 | Status transitions pending→running→completed/failed | ✅ | T1, T5, T18 |
| AC6 | Task.execution_run_id set after execution | ✅ | T16, T20 integration |
| AC7 | Halt on first failure | ✅ | T5 |
| AC8 | --continue-on-failure skips dependents | ✅ | T6, T7, T23 |
| AC9 | --start-from skips tasks before N | ✅ | T9 |
| AC10 | --dry-run shows waves without dispatching | ✅ | T12, T13 |
| AC11 | Deadlock detection | ✅ | T11 |
| AC12 | SIGINT graceful stop | ✅ | T17 |
| AC13 | Final summary with counts/time/iterations | ✅ | T4 result struct |
| AC14 | rails test zero failures | ✅ | 248 runs, 0 failures |

---

## Plan Adherence — Architect Amendments

| Amendment | Description | Status |
|-----------|-------------|--------|
| Amend #1 | All-terminal early exit | ✅ Implemented (T25) |
| Amend #2 | BFS transitive dependent skipping | ✅ Implemented |
| Amend #3 | verbose flag passthrough | ✅ Implemented (T24) |
| Amend #4 | All-terminal states test | ✅ Implemented |
| Amend #5 | with_lock on status transitions | ✅ Implemented |
| Amend #6 | ready_for_run scope + test | ✅ Implemented (T26) |
| Amend #7 | exit 3 for continue_on_failure with failures | ✅ **FIXED** — `elsif result.failed_count > 0; exit 3` |

---

## Strengths

### ✅ Comprehensive Test Coverage (25 PRD-specific tests)
All 25 tests pass in 0.59s. Includes all architect-mandated tests (T24 verbose, T25 all-terminal, T26 ready_for_run). Integration test chain stubs use correct `.returns(...).then.returns(...)` syntax.

### ✅ Correct BFS Transitive Dependency Skip
`mark_dependents_skipped` performs correct BFS across the full dependent tree using in-memory `all_tasks` lookup. No N+1 on dep traversal.

### ✅ Interrupt Safety
`@interrupted` flag set via `trap("INT")` checked each loop iteration. Service re-raises `Interrupt` after summary; `bin/legion` catches and exits 5 distinctly from other error paths.

### ✅ Deadlock Detection
Detects incomplete tasks with no ready tasks available; raises `DeadlockError` with diagnostic output listing all stuck tasks and their unmet dependencies.

### ✅ Mock/Stub Contract Correctness
`DispatchService.stubs(:call).returns(@mock_execution_run)` returns a real `WorkflowRun` — identical type to what the real `DispatchService.call` returns. No shape mismatch.

### ✅ Clean Code Structure
Service follows project conventions: `self.call` class method delegating to `new(...).call`, private methods named clearly, error classes defined at top. 414 lines including all helpers — appropriate length.

---

## Score History

| Round | Date | Score | Verdict |
|-------|------|-------|---------|
| 1 | 2026-03-07 | 88/100 | REJECT |
| 2 | 2026-03-07 | **97/100** | **PASS** |
