# Agent Task Log — PRD-1-07: Plan Execution CLI

Date: 2026-03-07  
Branch: master  
Owner: Rails Lead (DeepSeek Reasoner)

## 1. Goal
- Implement `bin/legion execute-plan` CLI command that walks a decomposed task dependency graph and dispatches each task sequentially with full event persistence.

## 2. Context
- Epic 1, PRD-1-07 — the orchestration loop connecting decomposition (PRD-1-06) to agent dispatch (PRD-1-04)
- All prior PRDs (1-01 through 1-06) are complete; schema, DispatchService, AgentAssemblyService, and Task model all exist
- No new migrations required — `tasks.execution_run_id` and `workflow_runs.task_id` FKs already exist
- Implementation plan: `knowledge_base/epics/wip/epic-1-orchestration-foundation/PRD-1-07-implementation-plan.md`

## 3. Plan
1. `app/services/legion/plan_execution_service.rb` — core orchestration service
2. `app/models/task.rb` — add `ready_for_run` scope
3. `bin/legion` — add `execute-plan` subcommand
4. `test/services/legion/plan_execution_service_test.rb` — 17+3 unit tests
5. `test/integration/plan_execution_integration_test.rb` — 6 integration tests
6. `test/models/task_test.rb` — add `ready_for_run` scope test

## 4. Execution Log

### Phase 1: Implementation
- Created `PlanExecutionService` with dependency graph loop, failure handling, SIGINT, dry-run
- Added `Task.ready_for_run` scope to Task model
- Added `execute-plan` subcommand to `bin/legion`
- Implemented 26 tests (17 unit + 6 integration + 1 model + 2 architect amendments)

## 5. Test Results

**Full suite:** 248 runs, 901 assertions, 0 failures, 0 errors, 0 skips  
**PRD-1-07 specific:** 26 tests (19 unit + 6 integration + 1 model), all passing  
**QA Score:** 97/100 PASS (initial 88/100, fixed and re-scored)

## 6. Manual Verification Steps
1. Decompose PRD: `bin/legion decompose --team ROR --prd PRD-1-01-schema-foundation.md`
2. Dry-run: `bin/legion execute-plan --workflow-run <ID> --dry-run`
3. Execute: `bin/legion execute-plan --workflow-run <ID> --verbose`
4. Check console: `Task.where(workflow_run_id: <ID>).pluck(:status)` → all "completed"
5. Verify execution_run_id: `Task.where(workflow_run_id: <ID>).map { |t| [t.position, t.execution_run_id] }`
6. Test failure: `bin/legion execute-plan --workflow-run <ID> --max-iterations 1`
7. Test resume: `bin/legion execute-plan --workflow-run <ID> --start-from <task_id>`

## 7. Decisions Made
- `@interrupted` flag approach for SIGINT (checked between tasks, not mid-dispatch)
- Re-dispatch `:running` tasks by resetting status to `:pending` at load time (clean semantics)
- `mark_dependents_skipped` uses BFS for full transitive closure
- `Task.ready_for_run` reuses existing `Task.ready` SQL scope with `.where(workflow_run:)` chaining

## 8. Issues & Resolutions

1. **Task.error_message missing** — Task model has no `error_message` column. Resolved: store in `task.metadata["error_message"]` JSONB field.
2. **Mocha `.returns do...end` block** — Mocha's `returns` doesn't accept dynamic blocks; requires `.then.returns(value)` chaining for sequential returns. Fixed in integration tests.
3. **Dead variables** — `task_map`, `dep_statuses`, `duration_s` identified by QA as unused. Removed in debug pass.
4. **Amendment #7 (exit code 3 with continue_on_failure)** — Original condition `result.halted && halt_reason != "interrupted"` was false when `continue_on_failure=true` (halted=false). Added `elsif result.failed_count > 0; exit 3` to cover this case.
5. **Reverse WorkflowRun.task_id link** — `DispatchService` doesn't accept task_id. Fixed: after dispatch, call `execution_run.update!(task: task)` to set reverse link.
