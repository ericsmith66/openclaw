# PRD 2-04: Task Re-Run & Error Recovery

**Epic:** [Epic 2 — WorkflowEngine & Quality Gates](0000-epic.md)

## Key Decisions

- D-25: Parallel file conflict is a blocking validation (auto-serialize conflicting tasks)
- D-30: Two distinct retry limits: `WorkflowExecution.attempt` (max 3, CODE→QA→RETRY cycles) + `Task.retry_count` (max configurable per-task)
**Log Requirements**
- Create/update task log under `knowledge_base/task-logs/`

---

### Overview

In Epic 1, a failed task stays `failed` forever. There's no way to re-run it with additional context, reset it to `pending`, or resume a plan from a failure point. If task #3 of 8 fails, the entire plan is abandoned.

PRD 2-04 adds task re-run capability: `--reset-failed` resets all failed tasks (and their skipped dependents) to `pending`, and `--reset-task <id>` resets a single task. Each reset increments `retry_count` and stores the failure context in `last_error`. When a reset task is re-dispatched, its prompt includes the accumulated error context so the agent can learn from previous failures.

---

### Requirements

#### Functional

- FR-1: Add `retry_count` (integer, default: 0) and `last_error` (text, nullable) fields to Task model (if not already added in 2-01)
- FR-2: `--reset-failed` flag on `bin/legion execute-plan`: resets all `failed` tasks to `pending`, increments `retry_count`, preserves `last_error`
- FR-3: `--reset-task <id>` flag on `bin/legion execute-plan`: resets a specific task to `pending`
- FR-4: When resetting a failed task, also reset its `skipped` dependents to `pending` (cascade reset)
- FR-5: `TaskResetService.call(task:)` — encapsulates reset logic: validate task is resettable, update status to `pending`, increment `retry_count`, clear timing fields (`queued_at`, `started_at`, `completed_at`), reset to `ready` if all dependencies met
- FR-6: `TaskResetService.reset_all_failed(workflow_run:)` — batch reset all failed tasks + cascading dependents
- FR-7: On re-dispatch, the task prompt includes accumulated error context from `last_error`: "Previous attempt failed: <error>. Fix this specific issue."
- FR-8: `Task#resettable?` — returns true if task is `failed` or `skipped`
- FR-9: After reset, re-evaluate dependency graph — if all dependencies of a reset task are `completed`, mark task as `ready`

#### Non-Functional

- NF-1: Reset operations must be atomic (transaction wrapping status changes for task + dependents)
- NF-2: Error context in re-dispatch prompt must be capped at 2000 characters to prevent context window pressure

#### Rails / Implementation Notes

- **Migration**: Add `retry_count` and `last_error` to tasks table (if not done in 2-01)
- **Service**: `app/services/legion/task_reset_service.rb`
- **Model**: Add `resettable?` method and error context enrichment to Task
- **CLI**: Add `--reset-failed` and `--reset-task` flags to `bin/legion execute-plan`

---

### Error Scenarios & Fallbacks

- **Reset non-failed task** → `TaskResetService` raises `Legion::TaskNotResettableError` ("Task #<id> is <status>, only failed/skipped tasks can be reset")
- **Task not found** → Exit code 1, "Task #<id> not found"
- **Circular dependency after reset** → Should not happen (DAG is validated at decomposition time). If detected: log error, skip reset for affected task.
- **last_error exceeds 2000 chars** → Truncate with "... (truncated, see full error in task log)"

---

### Architectural Context

Task re-run is a prerequisite for the retry logic in PRD 2-09. The Conductor's `retry_with_context` tool (PRD 2-06) will call `TaskResetService` internally. This PRD provides the manual CLI interface and the core reset logic.

The error context enrichment follows a simple pattern: when `PlanExecutionService` or `TaskDispatchJob` dispatches a task with `retry_count > 0`, it appends the `last_error` content to the task prompt. This is a lightweight form of context accumulation — the full accumulation across multiple QA cycles is handled in PRD 2-09.

---

### Acceptance Criteria

- [ ] AC-1: Given task #3 is `failed`, `bin/legion execute-plan --workflow-run <id> --reset-task 3` resets it to `pending` and increments `retry_count` to 1
- [ ] AC-2: Given task #3 is `failed` and task #5 is `skipped` (depends on #3), `--reset-failed` resets both to `pending`
- [ ] AC-3: After reset, if task #3's dependencies are all `completed`, task #3 status is `ready`
- [ ] AC-4: Given task #3 with `retry_count: 1` and `last_error: "Missing FK index"`, re-dispatch includes "Previous attempt failed: Missing FK index" in the prompt
- [ ] AC-5: `Task#resettable?` returns true for `failed` and `skipped`, false for all other statuses
- [ ] AC-6: Reset is atomic — if resetting task #3 and cascading to #5 fails on #5, neither is reset
- [ ] AC-7: Error context in prompt is capped at 2000 characters
- [ ] AC-8: Given task #3 is `completed`, `--reset-task 3` raises `TaskNotResettableError`
- [ ] AC-9: After `--reset-failed`, plan execution resumes from the reset tasks (newly ready tasks are dispatched)

---

### Test Cases

#### Unit (Minitest)

- `test/services/legion/task_reset_service_test.rb`: Single task reset (status, retry_count, timing fields cleared), batch reset (all failed + cascading skipped), non-resettable task error, dependency re-evaluation after reset
- `test/models/task_test.rb`: `resettable?` method for each status value, error context enrichment (appended to prompt, truncation at 2000 chars)

#### Integration (Minitest)

- `test/integration/task_rerun_test.rb`: Create workflow with 3 tasks (1→2→3), fail task 2, verify task 3 is skipped, reset-failed, verify both reset to pending, re-dispatch with error context in prompt (VCR-recorded)

#### System / Smoke

- `test/system/task_rerun_smoke_test.rb`: Run `execute-plan`, observe failure, run `execute-plan --reset-failed`, verify resumed execution

---

### Manual Verification

1. Run `bin/legion execute-plan --workflow-run <id>` — let a task fail (or force failure)
2. Verify: failed task has `status: failed`, `last_error` populated
3. Run `bin/legion execute-plan --workflow-run <id> --reset-failed`
4. Verify: failed task now `pending` (or `ready`), `retry_count: 1`
5. Observe task re-dispatches with error context in prompt
6. Try `--reset-task <id>` on a completed task — verify error message

**Expected:** Reset succeeds for failed tasks, error context appears in retry prompt, completed tasks cannot be reset.

---

### Dependencies

- **Blocked By:** 2-01 (TaskDispatchJob, parallel dispatch)
- **Blocks:** 2-06 (Conductor's retry_with_context uses TaskResetService), 2-09 (Retry Logic)


---

