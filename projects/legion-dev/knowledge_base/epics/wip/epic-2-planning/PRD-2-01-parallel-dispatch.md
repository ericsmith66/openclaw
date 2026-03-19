# PRD 2-01: Parallel Task Dispatch via Solid Queue

**Epic:** [Epic 2 — WorkflowEngine & Quality Gates](0000-epic.md)

## Key Decisions

- D-2: Solid Queue for parallel dispatch
- D-9: Per-project PostgreSQL advisory lock
- D-25: Parallel file conflict is a blocking validation (auto‑serialize conflicting tasks)
- D-35: Concurrency enforcement via application‑level count check (`Task.where(status: [:queued, :running]).count < concurrency`). Soft cap, not hard mutex.

**Log Requirements**
- Create/update task log under `knowledge_base/task-logs/`
- Include detailed manual test steps and expected results

---

### Overview

Epic 1's `PlanExecutionService` dispatches ready tasks one at a time in a synchronous loop (`ready.first`). For PRDs with parallel-eligible tasks, this leaves performance on the table — two independent tasks that could run simultaneously instead wait in line.

PRD 2-01 replaces the synchronous dispatch loop with Solid Queue background jobs. A new `TaskDispatchJob` encapsulates the dispatch of a single task. When a task completes, the job checks if new tasks are now ready (dependencies satisfied) and enqueues them. A per-project PostgreSQL advisory lock prevents two workflows from editing the same project simultaneously. The human controls parallelism via `--sequential` and `--concurrency` flags.

---

### Requirements

#### Functional

- FR-1: Create `TaskDispatchJob` (ActiveJob backed by Solid Queue) that dispatches a single task via `DispatchService`
- FR-2: `TaskDispatchJob#perform` sets `Task.started_at` on begin, `Task.completed_at` on success, and updates status (`queued` → `running` → `completed`/`failed`)
- FR-3: On task completion, `TaskDispatchJob` checks for newly-ready tasks (`Task.ready` scope) and enqueues a `TaskDispatchJob` for each
- FR-4: On task failure, store error in `Task.last_error` and mark status `failed`
- FR-5: When all tasks are in terminal state (`completed`, `failed`, `skipped`), fire a completion callback (enqueue `ConductorJob` when Conductor exists in PRD 2-06; for now, log completion)
- FR-6: Modify `PlanExecutionService` to support parallel dispatch mode: enqueue ALL ready tasks simultaneously instead of dispatching `ready.first`. Before enqueuing each TaskDispatchJob, check `Task.where(workflow_execution_id: x, status: [:queued, :running]).count`. Only enqueue if count < `concurrency`. Hold remaining ready tasks in `pending`. Brief over-dispatch is acceptable — concurrency limit is a soft cap, not a hard mutex (D-35).
- FR-7: Implement file conflict validation (D-25): before enqueuing a parallel wave, check for overlapping file paths. Conflicting tasks are held in `pending` until the conflicting task completes. Log serialization decisions.
- FR-8: Implement per-project advisory lock: `SELECT pg_try_advisory_lock(project_id)` before first task dispatch. Released on workflow completion or CLI disconnect.
- FR-9: If advisory lock unavailable, raise `Legion::WorkflowLockError` with message identifying the locking execution
- FR-10: Add `--sequential` flag to `bin/legion execute-plan` (preserves Epic 1 behavior, dispatches one task at a time)
- FR-11: Add `--concurrency <N>` flag to `bin/legion execute-plan` (limits parallel workers, default 3). Concurrency enforcement via application-level count check (see FR-6).
- FR-12: Add `queued` status to Task enum (between `ready` and `running`)
- FR-13: Add `queued_at`, `started_at`, `completed_at` datetime fields to Task
- FR-14: Add `workflow_execution_id` FK to Task (nullable for backwards compatibility)
- FR-15: Configure Solid Queue: `config/solid_queue.yml` with `task_dispatch` queue, 3 threads, 1 process, 1s polling
- FR-16: Add Solid Queue worker to `Procfile.dev`: `worker: bundle exec rake solid_queue:start`

#### Non-Functional

- NF-1: Parallel dispatch must not introduce data races on Task status updates (use `with_lock` or atomic updates)
- NF-2: Advisory lock must auto-release on process crash (PostgreSQL advisory locks release on disconnect)
- NF-3: Task status transitions must be idempotent (re-running a completed TaskDispatchJob is a no-op)
- NF-4: File conflict detection must complete in < 100ms for up to 50 tasks

#### Rails / Implementation Notes

- **Migration**: Add `queued_at`, `started_at`, `completed_at` to tasks table. Add `queued` to status enum. Add `workflow_execution_id` FK (nullable).
- **Job**: `app/jobs/task_dispatch_job.rb` — ActiveJob class, `queue_as :task_dispatch`
- **Service**: Modify `app/services/legion/plan_execution_service.rb` — add parallel mode
- **Lock**: `app/services/legion/advisory_lock_service.rb` — acquire/release/check advisory lock
- **Config**: `config/solid_queue.yml`, update `Procfile.dev`
- **CLI**: Modify `bin/legion execute-plan` to accept `--sequential` and `--concurrency` flags

---

### Error Scenarios & Fallbacks

- **Task raises exception during dispatch** → `TaskDispatchJob` catches, marks task `failed`, stores exception message in `last_error`. Checks if all tasks terminal → fires completion callback.
- **Solid Queue worker crashes mid-task** → Task stays `running` with `started_at` set. ConductorHeartbeatJob (PRD 2-06) will detect stale task after 15 min and reset to `pending`. Before PRD 2-06: manual detection via `Task.where(status: :running).where("started_at < ?", 15.minutes.ago)`.
- **Advisory lock unavailable** → `WorkflowLockError` raised with locking execution details. CLI prints message and exits with code 4.
- **File conflict detected** → Conflicting task held in `pending`. Log message: "Tasks #3 and #5 both reference `app/models/user.rb` — serializing to prevent file conflict." When first task completes, second becomes ready and is enqueued.
- **Database connection lost during dispatch** → Solid Queue handles reconnection. Task may remain in `queued` state. Heartbeat job (PRD 2-06) handles detection.

---

### Architectural Context

This PRD extends `PlanExecutionService` (Epic 1) from synchronous sequential dispatch to asynchronous parallel dispatch. The key architectural boundary: `TaskDispatchJob` wraps `DispatchService.call()` — the existing agent dispatch pipeline is unchanged. The job adds lifecycle management (status transitions, timing, completion detection) around the existing dispatch.

The advisory lock is a PostgreSQL-level mechanism that works across processes without external dependencies. It prevents two `implement` or `execute-plan` commands from dispatching tasks against the same project simultaneously, which would cause file conflicts.

File conflict validation (D-25) adds a safety layer that the explicit DAG cannot capture — implicit file-level dependencies between tasks that reference the same source files.

**Non-goals:** This PRD does not implement ConductorJob, ConductorHeartbeatJob, or the full WorkflowEngine — those are in PRD 2-06. The completion callback in this PRD is a hook point that PRD 2-06 will connect to.

---

### Acceptance Criteria

- [ ] AC-1: Given 3 ready tasks with no dependencies between them, `PlanExecutionService` in parallel mode enqueues 3 `TaskDispatchJob`s simultaneously (verified by Solid Queue job count)
- [ ] AC-2: Given `--sequential` flag, tasks dispatch one at a time in dependency order (Epic 1 behavior preserved)
- [ ] AC-3: Given `--concurrency 2` flag, at most 2 tasks run simultaneously (third waits for a slot)
- [ ] AC-4: Given Task A completes and Task B depends on Task A, a `TaskDispatchJob` for Task B is automatically enqueued
- [ ] AC-5: Given all tasks reach terminal state, a completion callback fires (logged as WorkflowEvent or hook call)
- [ ] AC-6: Given a task raises an exception, its status is `failed`, `last_error` contains the exception message, and `completed_at` is set
- [ ] AC-7: Given two tasks reference the same file path (e.g., both touch `app/models/user.rb`), the second task is held in `pending` until the first completes
- [ ] AC-8: Given a project advisory lock is held by execution #1, a second `execute-plan` command for the same project raises `WorkflowLockError` with execution #1's ID
- [ ] AC-9: Given a successful task dispatch, `Task.queued_at` is set when enqueued, `Task.started_at` when `perform` begins, `Task.completed_at` when done
- [ ] AC-10: Solid Queue worker starts via `bin/dev` (Procfile.dev entry exists and works)
- [ ] AC-11: `config/solid_queue.yml` configures `task_dispatch` queue with 3 threads
- [ ] AC-12: Task status enum includes `queued` value between `ready` and `running`

---

### Test Cases

#### Unit (Minitest)

- `test/jobs/task_dispatch_job_test.rb`: Test perform with successful dispatch (status transitions, timing fields set), perform with dispatch failure (status=failed, last_error set), idempotent re-run of completed task
- `test/services/legion/plan_execution_service_test.rb`: Test parallel mode enqueues all ready tasks, sequential mode dispatches one at a time, concurrency limit respected
- `test/services/legion/advisory_lock_service_test.rb`: Test lock acquire/release, lock contention detection, lock auto-release simulation
- `test/models/task_test.rb`: Test new status enum values, queued_at/started_at/completed_at presence, status transition validations

#### Integration (Minitest)

- `test/integration/parallel_dispatch_test.rb`: Enqueue 3 tasks, verify all complete with correct timing (VCR-recorded). Verify dependency chain: A completes → B enqueued. Verify file conflict serialization.
- `test/integration/advisory_lock_test.rb`: Two concurrent PlanExecutionService calls on same project — second raises WorkflowLockError.

#### System / Smoke

- `test/system/parallel_dispatch_smoke_test.rb`: Run `bin/legion execute-plan --workflow-run <id>` and verify parallel execution via task timing (parallel tasks have overlapping started_at/completed_at windows)

---

### Manual Verification

1. Create a workflow run with 4 tasks: Tasks 1+2 have no dependencies, Task 3 depends on Task 1, Task 4 depends on Task 2
2. Run `bin/legion execute-plan --workflow-run <id> --team ROR`
3. Observe CLI output showing Tasks 1+2 dispatching simultaneously (Wave 1)
4. After Tasks 1+2 complete, observe Tasks 3+4 dispatching simultaneously (Wave 2)
5. Run `bin/legion execute-plan --workflow-run <id> --sequential` — verify tasks run one at a time
6. Open a second terminal, run `bin/legion execute-plan` on the same project — verify advisory lock error

**Expected:**
- Parallel mode: Tasks 1+2 start within 2s of each other. Wave 2 starts only after Wave 1 completes.
- Sequential mode: Each task starts after the previous completes.
- Lock contention: Second command fails with "Project locked by execution #N" message.

---

### Dependencies

- **Blocked By:** Epic 1 (complete)
- **Blocks:** 2-02 (Artifact), 2-03 (Score), 2-04 (Task Re-Run), 2-05 (PromptBuilder), 2-06 (Conductor)

---

### Rollout / Deployment Notes

- **Migration:** Add columns to tasks table. Add `queued` to status enum. Non-destructive — existing tasks unaffected.
- **Solid Queue setup:** Run `bin/rails solid_queue:install` if not already done. Create `config/solid_queue.yml`.
- **Procfile.dev:** Add worker process. Developers must restart `bin/dev` after this change.

---

