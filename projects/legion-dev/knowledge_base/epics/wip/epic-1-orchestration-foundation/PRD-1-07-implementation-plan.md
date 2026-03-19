# PRD-1-07: Plan Execution CLI — Implementation Plan

**Date:** 2026-03-07  
**PRD:** `knowledge_base/epics/wip/epic-1-orchestration-foundation/PRD-1-07-plan-execution-cli.md`  
**Implementer:** Rails Lead (DeepSeek Reasoner)  
**Epic:** Epic 1 — Orchestration Foundation

---

## Overview

Build `bin/legion execute-plan` CLI command that walks a decomposed task list's dependency graph and dispatches each ready task sequentially. This is the orchestration loop connecting decomposition (PRD-1-06) to agent dispatch (PRD-1-04).

**Key flow:**
```
bin/legion execute-plan --workflow-run 42
  → PlanExecutionService
    → Load Tasks for WorkflowRun #42
    → Loop: find ready tasks → dispatch first → update status → re-evaluate
    → Report results
```

---

## Pre-Implementation Analysis

### Existing Infrastructure (Reuse)
- `DispatchService.call(...)` — returns `WorkflowRun` (patched in PRD-1-06)
- `AgentAssemblyService.call(...)` — full agent assembly pipeline
- `Task.ready` scope — SQL scope using `GROUP BY / HAVING` for readiness calculation
- `Task.by_position` scope — ordered by position
- `Task` model — already has `status` enum, `execution_run_id`, `dependencies`, `dependents`
- `WorkflowRun` — has `task_id` FK (links execution run to the task being executed)
- `TaskDependency` model with cycle detection

### Schema Observations
- `tasks.execution_run_id` → FK to `workflow_runs` ✅
- `workflow_runs.task_id` → FK to `tasks` ✅ (links execution WorkflowRun to parent Task)
- `Task.ready` scope uses SQL `COUNT(CASE WHEN dependencies_tasks.status != 'completed' THEN 1 END) = 0` ✅

### Gaps to Fill
1. `Task.ready` scope is generic; need `Task.ready_for_run(workflow_run)` scoped version
2. No `PlanExecutionService` exists yet
3. `bin/legion` needs `execute-plan` subcommand
4. Need test file: `test/services/legion/plan_execution_service_test.rb`
5. Need test file: `test/integration/plan_execution_integration_test.rb`
6. SIGINT handling in execute-plan context (register trap before dispatch loop)

---

## File-by-File Changes

### 1. `app/services/legion/plan_execution_service.rb` (New)
**Purpose:** Orchestrates the plan execution loop — loads tasks, walks dependency graph, dispatches each task, handles failures, reports results.

**Public interface:**
```ruby
PlanExecutionService.call(
  workflow_run:,
  start_from: nil,
  continue_on_failure: false,
  interactive: false,
  verbose: false,
  max_iterations: nil,
  dry_run: false
)
```

**Result struct:**
```ruby
Result = Struct.new(
  :completed_count, :failed_count, :skipped_count, :total_count,
  :duration_ms, :halted, :halt_reason,
  keyword_init: true
)
```

**Custom errors:**
- `WorkflowRunNotFoundError < StandardError`
- `NoTasksFoundError < StandardError`
- `StartFromTaskNotFoundError < StandardError`
- `DeadlockError < StandardError`

**Core algorithm:**
```
1. Load workflow_run or raise WorkflowRunNotFoundError
2. Load tasks (by_position) or raise NoTasksFoundError
3. Validate start_from task exists in run (if given) or raise StartFromTaskNotFoundError
4. Check already-all-completed → early exit
5. If dry_run: compute waves (topological sort) → print → return
6. Handle SIGINT: trap("INT") { @interrupted = true }
7. Apply start_from: mark skipped tasks as :skipped
8. Print execution header
9. Loop:
   a. Find ready tasks (status pending/ready, all deps completed)
   b. If no ready tasks + incomplete tasks remain → DeadlockError
   c. If interrupted → halt, report
   d. Pick first ready task
   e. task.with_lock { task.update!(status: :running) }
   f. Create execution WorkflowRun (project:, team_membership:, prompt: task.prompt, task: task)
   g. Call DispatchService.call(...) → execution_run
   h. On success: task.with_lock { task.update!(status: :completed, execution_run: execution_run) }
   i. On StandardError: task.with_lock { task.update!(status: :failed, execution_run: execution_run) }
      - continue_on_failure=false → halt
      - continue_on_failure=true → mark dependents :skipped, continue
   j. Increment task counter
   k. Re-evaluate ready tasks
10. Print summary
```

**Dry-run wave computation:**
- Uses same topological sort as `detect_parallel_groups` in DecompositionService
- Computes "waves" from the in-memory tasks using `depends_on` via `TaskDependency`

**Private methods:**
- `#find_workflow_run` — find or raise
- `#load_tasks` — `Task.where(workflow_run:).by_position.includes(:dependencies, :dependents, :team_membership)`
- `#ready_tasks(all_tasks)` — filter: status pending/ready AND all deps completed
- `#all_incomplete(all_tasks)` — filter: not completed/failed/skipped
- `#apply_start_from(tasks, start_from_id)` — mark tasks before start_from as :skipped
- `#dispatch_task(task, project_path)` — create execution WorkflowRun + call DispatchService
- `#mark_dependents_skipped(task, all_tasks)` — BFS through dependents, mark :skipped
- `#compute_waves(tasks)` — topological sort for dry-run
- `#print_header(workflow_run, task_count)` — formatted header
- `#print_task_start(index, total, task)` — `[N/M] Task #ID: prompt — agent`
- `#print_task_result(task, execution_run)` — ✅/❌ with iterations, duration, events
- `#print_dry_run(workflow_run, waves)` — execution plan with waves
- `#print_summary(result)` — final counts + time

**SIGINT handling:** `@interrupted` flag checked each loop iteration.  
**Task agent not found:** `DispatchService::AgentNotFoundError` → task marked failed, treated as failure.

---

### 2. `app/models/task.rb` (Modified)
**Changes:**
- Add `scope :ready_for_run, ->(workflow_run) { where(workflow_run:).ready }` — scoped version of the existing `ready` scope.

---

### 3. `bin/legion` (Modified)
**Add `execute-plan` subcommand:**
```ruby
desc "execute-plan", "Execute a decomposed plan task by task"
method_option :workflow_run, type: :numeric, required: true, desc: "WorkflowRun ID"
method_option :start_from, type: :numeric, desc: "Task ID to start from (skip tasks before)"
method_option :continue_on_failure, type: :boolean, default: false, desc: "Continue after task failure"
method_option :interactive, type: :boolean, default: false, desc: "Enable interactive tool approval"
method_option :verbose, type: :boolean, default: false, desc: "Print real-time event stream"
method_option :dry_run, type: :boolean, default: false, desc: "Show execution plan without running tasks"
method_option :max_iterations, type: :numeric, desc: "Override per-task max iterations"
```

**Exit codes:**
- `exit 0` — all tasks completed (or dry-run)
- `exit 1` — unexpected error
- `exit 2` — validation error (workflow run not found, no tasks, start_from not found)
- `exit 3` — plan halted due to task failure (without --continue-on-failure)
- `exit 4` — deadlock detected
- `exit 5` — interrupted (SIGINT)

**Error handling:**
```ruby
rescue Legion::PlanExecutionService::WorkflowRunNotFoundError => e
  # exit 2
rescue Legion::PlanExecutionService::NoTasksFoundError => e
  # exit 2
rescue Legion::PlanExecutionService::StartFromTaskNotFoundError => e
  # exit 2
rescue Legion::PlanExecutionService::DeadlockError => e
  # exit 4
rescue Interrupt
  # exit 5 (SIGINT already handled in service; CLI catches re-raise)
rescue StandardError => e
  # exit 1
```

**SIGINT note:** The global `trap("INT")` in `bin/legion` raises `Interrupt`. The service also sets `@interrupted`. The CLI rescues `Interrupt` and exits 5.

---

### 4. `test/services/legion/plan_execution_service_test.rb` (New)

**Total: 17 unit tests**

Setup: project, team, membership, workflow_run (decomposition run), tasks created with factories. DispatchService stubbed to return mock execution_run.

#### Group A — Happy Path
1. `test_linear_chain_executes_in_order` — A→B→C: dispatches A first, then B (after A complete), then C
2. `test_parallel_eligible_tasks_dispatch_first_ready` — A, B independent, C depends on A+B: dispatches A first (first ready in by_position), then B, then C
3. `test_all_tasks_already_completed_exits_early` — all tasks :completed → reports "all tasks already completed", no dispatch
4. `test_returns_result_struct` — Result struct has correct counts, duration_ms

#### Group B — Failure Handling
5. `test_halt_on_first_failure` — task B fails → C not dispatched, result.halted=true
6. `test_continue_on_failure_skips_dependents` — B fails, continue_on_failure=true → C (depends on B) skipped, D (independent) dispatched
7. `test_continue_on_failure_marks_direct_and_transitive_dependents_skipped` — B→C→D chain, B fails → C and D both :skipped
8. `test_running_task_from_interrupted_run_is_redispatched` — task with status :running is re-dispatched (treated as pending)

#### Group C — Start-From
9. `test_start_from_skips_tasks_before_start` — tasks 1,2,3; start_from=task_2 → task_1 marked :skipped, starts from task_2
10. `test_start_from_task_not_found_raises_error` — task_id not in this workflow_run → StartFromTaskNotFoundError

#### Group D — Deadlock
11. `test_deadlock_detection_raises_error` — manually create unsatisfiable state (all pending, none have completed deps) → DeadlockError

#### Group E — Dry Run
12. `test_dry_run_returns_waves_without_dispatching` — no DispatchService calls, returns wave structure
13. `test_dry_run_prints_wave_output` — captures stdout, verifies "Wave 1", "DRY RUN"

#### Group F — Special Cases
14. `test_empty_task_list_raises_error` — workflow_run with no tasks → NoTasksFoundError
15. `test_workflow_run_not_found_raises_error` — id=9999999 → WorkflowRunNotFoundError
16. `test_each_task_creates_own_execution_workflow_run` — 3 tasks → 3 new WorkflowRun records with task_id set
17. `test_sigint_simulation_marks_current_task_failed` — `@interrupted` set before dispatch → task stays :pending (no dispatch), result.halted=true

---

### 5. `test/integration/plan_execution_integration_test.rb` (New)

**Total: 6 integration tests**

Setup: real DB records (project, team, memberships, workflow_run, tasks with dependencies). DispatchService stubbed to simulate execution (returns real WorkflowRun created in test).

1. `test_executes_tasks_in_dependency_order` — full graph, verifies Task status transitions match expected order
2. `test_each_task_creates_execution_workflow_run` — verifies WorkflowRun.where(task: task) created per task; execution_run_id set
3. `test_execution_run_id_set_on_task_after_completion` — Task.execution_run_id populated after dispatch
4. `test_workflow_events_query_per_task` — verifies WorkflowEvent records accessible via task.execution_run.workflow_events (using real PostgresBus stub)
5. `test_full_cycle_decompose_then_execute` — mock decompose creates tasks, execute dispatches all; verifies all :completed
6. `test_continue_on_failure_integration` — end-to-end: one task fails, dependents skipped, independent tasks complete

---

## Error Path Matrix

| Scenario | Error Class | Exit Code | Behavior |
|----------|-------------|-----------|----------|
| WorkflowRun #N not found | `WorkflowRunNotFoundError` | 2 | "WorkflowRun #N not found" |
| No tasks in WorkflowRun | `NoTasksFoundError` | 2 | "No tasks found for WorkflowRun #N" |
| `--start-from` task not in run | `StartFromTaskNotFoundError` | 2 | "Task #N not found in WorkflowRun" |
| Deadlock: no ready tasks, incomplete remain | `DeadlockError` | 4 | "Deadlock: N tasks have unsatisfied dependencies\n  Task #ID: deps [X, Y]" |
| Task agent TeamMembership missing | `DispatchService::AgentNotFoundError` | (task failure) | Task marked :failed, treated as failure |
| Task fails, continue_on_failure=false | (halt) | 3 | "Plan halted: N/M completed, 1 failed, K pending" |
| Task fails, continue_on_failure=true | (continue) | 0 or 3 | Dependents :skipped, continue |
| SIGINT during execution | `Interrupt` | 5 | Current task :failed, print progress, re-raise |
| All tasks already completed | (early exit) | 0 | "All tasks already completed" |
| SmartProxy/network error during dispatch | `StandardError` | (task failure) | Task :failed, error_message set |
| Task had :running status (previous interrupted run) | — | — | Re-dispatch (treated as :pending) |

---

## Migration Steps

**No new migrations required.** The schema already supports all required fields:
- `tasks.execution_run_id` FK → `workflow_runs.id`
- `workflow_runs.task_id` FK → `tasks.id`
- All Task status values exist in enum

---

## Test Checklist (MUST-IMPLEMENT)

### Unit Tests — `test/services/legion/plan_execution_service_test.rb` (17 tests)

- [ ] T1: `test_linear_chain_executes_in_order`
- [ ] T2: `test_parallel_eligible_tasks_dispatch_first_ready`
- [ ] T3: `test_all_tasks_already_completed_exits_early`
- [ ] T4: `test_returns_result_struct`
- [ ] T5: `test_halt_on_first_failure`
- [ ] T6: `test_continue_on_failure_skips_dependents`
- [ ] T7: `test_continue_on_failure_marks_direct_and_transitive_dependents_skipped`
- [ ] T8: `test_running_task_from_interrupted_run_is_redispatched`
- [ ] T9: `test_start_from_skips_tasks_before_start`
- [ ] T10: `test_start_from_task_not_found_raises_error`
- [ ] T11: `test_deadlock_detection_raises_error`
- [ ] T12: `test_dry_run_returns_waves_without_dispatching`
- [ ] T13: `test_dry_run_prints_wave_output`
- [ ] T14: `test_empty_task_list_raises_error`
- [ ] T15: `test_workflow_run_not_found_raises_error`
- [ ] T16: `test_each_task_creates_own_execution_workflow_run`
- [ ] T17: `test_sigint_simulation_marks_current_task_failed`

### Integration Tests — `test/integration/plan_execution_integration_test.rb` (6 tests)

- [ ] T18: `test_executes_tasks_in_dependency_order`
- [ ] T19: `test_each_task_creates_execution_workflow_run`
- [ ] T20: `test_execution_run_id_set_on_task_after_completion`
- [ ] T21: `test_workflow_events_query_per_task`
- [ ] T22: `test_full_cycle_decompose_then_execute`
- [ ] T23: `test_continue_on_failure_integration`

**Total planned tests: 23**

---

## Pre-QA Checklist Acknowledgment

Before submitting to QA, I will verify:
- [ ] `rubocop -A app/ lib/ test/ --only-recognized-file-types` → 0 offenses
- [ ] Every `.rb` file begins with `# frozen_string_literal: true`
- [ ] `rails test` → 0 failures, 0 errors, 0 skips on PRD tests
- [ ] All 23 tests from the checklist above are implemented (no stubs, no placeholders)
- [ ] Every `rescue` block and error class has a corresponding test
- [ ] No dead code — every error class raised somewhere
- [ ] Mocks/stubs return same structure as real implementations
- [ ] All 14 Acceptance Criteria verified

---

## Implementation Order

1. `app/services/legion/plan_execution_service.rb` — core service
2. `app/models/task.rb` — add `ready_for_run` scope
3. `bin/legion` — add `execute-plan` subcommand
4. `test/services/legion/plan_execution_service_test.rb` — unit tests
5. `test/integration/plan_execution_integration_test.rb` — integration tests
6. Run full test suite, fix failures
7. Run RuboCop, fix offenses

---

## Acceptance Criteria Mapping

| AC | Covered By |
|----|-----------|
| AC1: dispatches tasks respecting dependency order | T1, T2, T18 |
| AC2: tasks with no dependencies dispatched first | T2 |
| AC3: tasks dispatched only when ALL deps completed | T1, T2, T18 |
| AC4: each task creates its own WorkflowRun | T16, T19 |
| AC5: status transitions pending→running→completed/failed | T1, T5, T18 |
| AC6: Task.execution_run_id set after execution | T16, T20 |
| AC7: halt on first failure | T5 |
| AC8: --continue-on-failure skips dependents | T6, T7, T23 |
| AC9: --start-from skips tasks before N | T9 |
| AC10: --dry-run shows waves without dispatching | T12, T13 |
| AC11: deadlock detection | T11 |
| AC12: SIGINT graceful stop | T17 |
| AC13: final summary with counts/time/iterations | T4 |
| AC14: rails test zero failures | Full suite |

---

## Notes

- **SIGINT in bin/legion:** The global `trap("INT")` block already in `bin/legion` raises `Interrupt`. For the service, we use `@interrupted = false; trap("INT") { @interrupted = true }` within `execute-plan` invocation so the loop can check it between tasks (clean termination). The service re-raises `Interrupt` after marking current task failed, allowing the CLI to catch and exit 5.
- **`ready_for_run` scope:** Reuses `Task.ready` (which uses a SQL GROUP/HAVING query) with an additional `.where(workflow_run:)` filter. The model-level `ready` scope already uses `left_joins(:dependencies)` which correctly handles tasks with zero dependencies (HAVING count=0 is satisfied).
- **`with_lock` on Task status transitions:** Use `task.with_lock { task.update!(status: :running) }` to prevent concurrent writes (Epic 2 readiness).
- **Task :running re-dispatch:** In `#load_tasks`, treat `:running` tasks as `:pending` for the ready check. No status reset needed — `ready_tasks` already includes `:ready` status; we'll also include `:running` in the ready calculation filter.
- **Execution WorkflowRun prompt:** Use `task.prompt` as the prompt. The `team_membership` is `task.team_membership`.
- **DispatchService project_path:** Use `workflow_run.project.path`.

---

*Plan version: 1.0 — 2026-03-07*

---

## Architect Review & Amendments

**Reviewer:** Architect (Legion)
**Date:** 2026-03-07
**Verdict:** PLAN-APPROVED

### Amendments

**Amendment #1 — `ready_tasks` filter must include `:running` status explicitly**
The plan notes in the Notes section that `:running` tasks should be re-dispatched (for interrupted runs), but the `#ready_tasks` method description only mentions `status: [:pending, :ready]`. Amend: `#ready_tasks` must also include `:running` in the status filter: `status: [:pending, :ready, :running]` OR reset `:running` → `:pending` on load. Preferred: reset to `:pending` at load time (before the loop) so status semantics are clean. **Required test:** T8 must verify a `:running` task is re-dispatched (currently stated as tested — confirm the approach matches implementation).

**Amendment #2 — `mark_dependents_skipped` must be transitive (BFS through all descendants)**
The plan says "BFS through dependents" — confirm this is a full recursive traversal, not just direct dependents. A task C that depends on B (which depends on failed A) should also be skipped when `continue_on_failure: true` and A fails. T7 tests this (`test_continue_on_failure_marks_direct_and_transitive_dependents_skipped`) — good. Ensure the implementation uses BFS across the full `dependents` graph, not just `task.dependents`.

**Amendment #3 — Add test for `--verbose` flag event subscription**
The PRD specifies `--verbose` prints real-time event stream per task (same as `DispatchService` verbose mode). The plan does not have a test for this. **Add T24:** `test_verbose_passes_flag_to_dispatch_service` — verifies `DispatchService.call` receives `verbose: true` when `--verbose` is passed.

**Amendment #4 — All-tasks-completed check should also handle mix of completed+failed+skipped**
The "early exit" logic for all-tasks-already-completed should cover the case where all tasks are in terminal states (completed/failed/skipped), not just all-completed. This prevents re-running a partially-failed plan without `--start-from`. **Add T25:** `test_all_tasks_in_terminal_states_exits_without_dispatch` — workflow_run where all tasks are :completed/:failed/:skipped → reports summary without dispatching.

**Amendment #5 — `print_task_start` should show dependency status**
The PRD progress output shows "Depends on: Task 1 ✅" for tasks with dependencies. Ensure `#print_task_start` includes dependency info when task has dependencies (matching PRD output spec). No test required for exact formatting, but existing output tests (T13) should verify the dependency line appears.

**Amendment #6 — Add `Task.ready_for_run` scope test to Task model test**
The plan adds `ready_for_run` scope to `Task` model but does not add a test to `test/models/task_test.rb`. **Required:** Add 1 test to `test/models/task_test.rb`: `test_ready_for_run_scope_returns_tasks_ready_for_given_workflow_run` — creates two workflow_runs with tasks, verifies scope filters by workflow_run correctly. Count this as T26.

**Amendment #7 — Exit code 3 vs 0 for `continue_on_failure` with failures**
Clarify: when `--continue-on-failure` is used and some tasks fail, the CLI should exit 3 (not 0) if any task failed. Exit 0 should only occur when ALL tasks completed successfully (or dry-run). Update the exit code logic in `bin/legion` accordingly.

### Summary of Additions
- T24: verbose flag passes through to DispatchService
- T25: all-terminal-states early exit
- T26: `Task.ready_for_run` scope test in model test file
- Total planned tests: **26** (up from 23)

### No Removals

All existing tests and design decisions are approved as-is. The plan structure is strong: Result struct pattern, with_lock on status transitions, BFS for dependent skipping, topological sort for waves, and the two-phase WorkflowRun creation approach are all correct.

PLAN-APPROVED
