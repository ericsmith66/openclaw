#### PRD-1-07: Plan Execution CLI

**Log Requirements**
- Create/update a task log under `knowledge_base/task-logs/`.
- In the log, include detailed manual test steps and expected results.
- If asked to review: create a separate document named `PRD-1-07-plan-execution-cli-feedback-V{{N}}.md` in the same directory as the source document.

---

### Overview

Build the `bin/legion execute-plan` CLI command that walks a decomposed task list's dependency graph and dispatches each ready task sequentially through the full agent assembly pipeline. This is the command that turns a decomposed PRD into executed code — each task dispatched to the right agent with the right identity, in the right order, with full event persistence.

Epic 1 executes one ready task at a time (sequential). The data model already supports parallel dispatch — Epic 2 adds Solid Queue concurrent execution. The same dependency graph, the same readiness calculation, just a different dispatcher.

---

### Requirements

#### Functional

**CLI Command (`bin/legion execute-plan`):**
```bash
bin/legion execute-plan --workflow-run 42
bin/legion execute-plan --workflow-run 42 --start-from 7
bin/legion execute-plan --workflow-run 42 --continue-on-failure
bin/legion execute-plan --workflow-run 42 --verbose
bin/legion execute-plan --workflow-run 42 --dry-run
```

**Arguments:**
- `--workflow-run ID` (required): The WorkflowRun ID from a decomposition (has associated Tasks)
- `--start-from TASK_ID` (optional): Skip tasks before this ID (resume from a specific point)
- `--continue-on-failure` (optional): Don't halt on task failure; mark failed, continue with next ready task. Default: halt on first failure.
- `--interactive` (optional): Enable terminal-based tool approval for ASK tools
- `--verbose` (optional): Print real-time event stream per task
- `--dry-run` (optional): Show execution plan without running any tasks
- `--max-iterations N` (optional): Override per-task max_iterations

**Plan Execution Service (`app/services/legion/plan_execution_service.rb`):**

`PlanExecutionService.call(workflow_run:, start_from: nil, continue_on_failure: false, interactive: false, verbose: false, max_iterations: nil)`

Execution loop:
1. Load all Tasks for the workflow_run, ordered by position
2. If `start_from`: Skip tasks with position before start_from task; mark skipped tasks as `skipped`
3. **Find ready tasks:** Tasks where:
   - Status is `pending` or `ready`
   - All dependencies (via TaskDependency) have status `completed`
4. If no ready tasks and incomplete tasks remain → deadlock detected (all remaining tasks have unsatisfied dependencies)
5. **Dispatch first ready task** (sequential in Epic 1):
   a. Update Task status → `running`
   b. Look up the task's `team_membership` for agent identity
   c. Create a new WorkflowRun for this task execution (links: `task_id: task.id`)
   d. Dispatch via `DispatchService.call(...)` or directly via `AgentAssemblyService` + `Runner.run`
   e. On success: Task status → `completed`, set `execution_run_id`
   f. On failure: Task status → `failed`, set `execution_run_id`
6. **After task completes:**
   - Re-evaluate ready tasks (completing a task may unblock others)
   - If failed and `continue_on_failure: false` → halt, report failure
   - If failed and `continue_on_failure: true` → mark dependent tasks as `skipped` (they can't run), continue with next ready task that has no failed dependencies
7. **Loop** until:
   - All tasks `completed` → report success
   - All remaining tasks `failed` or `skipped` → report partial completion
   - Deadlock detected → report error
8. Print final summary

**Dry-run output:**
```
Execution Plan for WorkflowRun #42 (12 tasks)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Execution Order (sequential):

Wave 1 (parallel-eligible):
  Task 1: [test] rails-lead — Write tests for Project model (score 4)
  Task 2: [test] rails-lead — Write tests for AgentTeam model (score 4)

Wave 2 (after wave 1):
  Task 3: [code] rails-lead — Create Project model (score 4) ← deps: [1]
  Task 4: [code] rails-lead — Create AgentTeam model (score 4) ← deps: [2]

Wave 3 (after wave 2):
  Task 5: [test] rails-lead — Write tests for TeamMembership (score 6) ← deps: [3,4]
...

DRY RUN — no tasks executed
```

**Progress output during execution:**
```
Executing plan for WorkflowRun #42 (12 tasks)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

[1/12] Task #1: Write tests for Project model — rails-lead (deepseek-reasoner)
       ✅ Completed — 8 iterations, 31.2s, 12 events recorded

[2/12] Task #2: Write tests for AgentTeam model — rails-lead (deepseek-reasoner)
       ✅ Completed — 7 iterations, 28.5s, 10 events recorded

[3/12] Task #3: Create Project model — rails-lead (deepseek-reasoner)
       Depends on: Task 1 ✅
       ✅ Completed — 14 iterations, 52.3s, 18 events recorded

[4/12] Task #4: Create AgentTeam model — rails-lead (deepseek-reasoner)
       Depends on: Task 2 ✅
       ✅ Completed — 11 iterations, 41.1s, 15 events recorded

...

Plan complete: 12/12 tasks succeeded
Total time: 8m 42s | Total iterations: 98 | Total events: 142
```

**Failure output:**
```
[5/12] Task #5: Write tests for TeamMembership — rails-lead (deepseek-reasoner)
       ❌ Failed — iteration limit (30 iterations, 120.0s)
       Error: Agent exceeded iteration limit

Plan halted: 4/12 completed, 1 failed, 7 pending
Use --continue-on-failure to skip failed tasks and continue
Use --start-from 5 to retry from the failed task
```

#### Non-Functional

- SIGINT (Ctrl+C) → Gracefully stop current task, mark as `failed`, report progress, exit
- Each task dispatch creates its own WorkflowRun — full event trail per task
- Task status transitions must be atomic (use `with_lock` or DB transactions)
- No concurrent access concerns in Epic 1 (single-threaded sequential dispatch), but status transitions should be designed for Epic 2's parallel dispatch

#### Rails / Implementation Notes

- CLI: Add `execute-plan` subcommand to `bin/legion`
- Service: `app/services/legion/plan_execution_service.rb`
- Reuses: `DispatchService` or `AgentAssemblyService` from PRD-1-04
- Reuses: `OrchestratorHooksService` from PRD-1-05 (registered per task dispatch)
- Task readiness query: `Task.where(workflow_run: run, status: [:pending, :ready]).select { |t| t.dependencies.all?(&:completed?) }` — or better, use a scope with a subquery
- Consider a `Task.ready_for_run(workflow_run)` scope that does this efficiently
- `--start-from` uses Task ID (not position) to be unambiguous

---

### Error Scenarios & Fallbacks

- WorkflowRun not found → Exit with "WorkflowRun #N not found"
- WorkflowRun has no tasks → Exit with "No tasks found for WorkflowRun #N"
- `--start-from` task not found → Exit with "Task #N not found in WorkflowRun"
- Deadlock: no ready tasks but incomplete tasks remain → Report "Deadlock: N tasks have unsatisfied dependencies" with list of stuck tasks and their missing deps
- Task's team_membership deleted → Skip task, report error: "Agent not found for task #N"
- SmartProxy down during task execution → Task marked `failed`, continue-on-failure decides behavior
- Agent produces no output (empty response) → Task marked `completed` (the agent chose to do nothing), log warning
- WorkflowRun already has all tasks completed → Report "All tasks already completed" and exit
- Task already running (from a previous interrupted run) → Treat as `pending`, re-dispatch

---

### Architectural Context

Plan Execution is the orchestration loop that connects decomposition (PRD-1-06) to agent dispatch (PRD-1-04).

```
bin/legion execute-plan --workflow-run 42
  → PlanExecutionService
    → Load Tasks for WorkflowRun #42
    → Loop:
      → Find ready tasks (all deps completed)
      → Pick first ready task
      → Create WorkflowRun for task execution
      → AgentAssemblyService (full pipeline — rules, skills, etc.)
      → Runner.run(...)
      → Update Task status
      → Re-evaluate ready tasks
    → Report results
```

**The same data model supports sequential (Epic 1) and parallel (Epic 2):**
- Epic 1: Pick first ready task, dispatch, wait, repeat
- Epic 2: Collect ALL ready tasks, dispatch via Solid Queue concurrently, wait for any to complete, re-evaluate

The "wave" concept in dry-run output previews what Epic 2's parallel dispatcher would do.

**Relationship to task-level events:**
Each task dispatch creates its own WorkflowRun, which gets its own PostgresBus, which persists events to WorkflowEvent. The parent WorkflowRun (from decomposition) has Tasks; each Task links to its execution WorkflowRun. This creates a two-level history: plan-level (which tasks, what order) and task-level (what the agent did).

**Non-goals:**
- No automatic retry on failure (Epic 2)
- No parallel dispatch (Epic 2)
- No dynamic re-decomposition during execution
- No cross-task context sharing (each task runs with a fresh conversation)

---

### Acceptance Criteria

- [ ] AC1: `bin/legion execute-plan --workflow-run N` dispatches tasks respecting dependency order
- [ ] AC2: Tasks with no dependencies are dispatched first
- [ ] AC3: Tasks are only dispatched when ALL dependencies have status `completed`
- [ ] AC4: Each task creates its own WorkflowRun with full event trail
- [ ] AC5: Task status updates: pending → running → completed/failed
- [ ] AC6: Task.execution_run_id links to the WorkflowRun that executed it
- [ ] AC7: Default: halt on first task failure with clear error message
- [ ] AC8: `--continue-on-failure`: skip failed task, mark dependents as `skipped`, continue
- [ ] AC9: `--start-from N`: skip tasks before N, resume execution
- [ ] AC10: `--dry-run`: show execution waves without dispatching
- [ ] AC11: Deadlock detection when no ready tasks exist but incomplete tasks remain
- [ ] AC12: SIGINT → graceful stop, mark current task failed, report progress
- [ ] AC13: Final summary shows: completed/failed/skipped counts, total time, total iterations
- [ ] AC14: `rails test` — zero failures for plan execution tests

---

### Test Cases

#### Unit (Minitest)

- `test/services/legion/plan_execution_service_test.rb`:
  - Linear chain (A→B→C): executes in order
  - Parallel-eligible tasks (A, B independent, C depends on both): A first, then B, then C
  - Failure halts: task B fails → C not dispatched
  - Continue-on-failure: B fails → C skipped, D (independent) still dispatched
  - Start-from: skip tasks before start point
  - Deadlock detection: circular or unsatisfiable dependencies
  - All tasks already completed → early exit
  - Running task from previous interrupted run → re-dispatch
  - Dry-run: returns execution waves without dispatching
  - Empty task list → error
  - SIGINT simulation → current task marked failed

#### Integration (Minitest)

- `test/integration/plan_execution_integration_test.rb`:
  - Create tasks with dependencies → execute-plan → verify execution order matches dependency graph
  - Verify each task creates its own WorkflowRun
  - Verify Task.execution_run_id set after execution
  - Verify WorkflowEvents persisted per-task
  - Full cycle with VCR: decompose PRD → execute-plan → verify all tasks completed

#### System / Smoke

- Manual: Decompose + execute a real PRD (see below)

---

### Manual Verification

1. First decompose a PRD: `bin/legion decompose --team ROR --prd PRD-1-01-schema-foundation.md`
   - Note the WorkflowRun ID output
2. Run dry-run: `bin/legion execute-plan --workflow-run <ID> --dry-run`
   - Expected: Execution waves showing dependency-aware ordering
3. Run execution: `bin/legion execute-plan --workflow-run <ID> --verbose`
   - Expected: Tasks dispatched in order, each with full event stream
4. Run `rails console`:
   - `Task.where(workflow_run_id: <ID>).pluck(:status)` → all "completed"
   - `Task.where(workflow_run_id: <ID>).map { |t| [t.position, t.execution_run_id] }` → all have execution runs
   - `WorkflowEvent.where(workflow_run: Task.last.execution_run).count` → events per task
5. Test failure handling: Set `--max-iterations 1` on a complex task
   - Expected: Task fails, plan halts (without --continue-on-failure)
6. Test resume: `bin/legion execute-plan --workflow-run <ID> --start-from <failed_task_id>`
   - Expected: Resumes from the failed task

**Expected:** Decomposed plan executed task-by-task respecting dependencies. Each task with full event trail. Failure handling and resume working.

---

### Dependencies

- **Blocked By:** PRD-1-01 (Schema), PRD-1-04 (CLI Dispatch — AgentAssemblyService), PRD-1-05 (Hooks), PRD-1-06 (Decomposition creates tasks to execute)
- **Blocks:** PRD-1-08 (Validation tests decompose→execute cycle)

---

### Estimated Complexity

**Medium-High** — The dependency graph walking is straightforward (topological sort). The complexity is in the execution loop: status management, failure handling, resume, signal handling, and ensuring each task gets a proper WorkflowRun with full event trail.

**Effort:** 1 week

### Agent Assignment

**Rails Lead** (DeepSeek Reasoner) — primary implementer for service, CLI, and execution loop
