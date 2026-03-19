# PRD 2-06: Conductor Agent & WorkflowEngine

**Epic:** [Epic 2 — WorkflowEngine & Quality Gates](0000-epic.md)

## Key Decisions

- D-4: **Conductor Agent over AASM state machine** — Workflow engine is a prompt, not code. Phase transitions driven by LLM calling orchestration tools.
- D-5: **ConductorDecision model for reasoning audit trail** — Every transition records *why* — reasoning text, input snapshot, tool called, duration, tokens, cost.
- D-6: **Orchestration tools as guardrails** — Tools validate preconditions before executing. Prompt guides, tools guard.
- D-7: **Short-lived Conductor dispatches** via ConductorJob — Dispatched at key moments, makes one decision, exits. Event-driven callbacks trigger next dispatch.
- D-15: **Hard phase enum on WorkflowExecution** — DB always knows exactly where the workflow is.
- D-17: Conductor is a new dedicated agent config (`conductor.yml`) imported via TeamImportService.
- D-18: ConductorHeartbeatJob (Solid Queue recurring, 60s interval) detects stale tasks via Task.started_at + configurable timeout (default 15 min).
- D-19: All orchestration tools accept a required `reasoning:` string parameter.
- D-20: ConductorJob runs in Solid Queue (event-driven). Triggers are callbacks from completing services. CLI polls WorkflowExecution.status every 2s with progress output.
- D-21: ConductorDecision includes `duration_ms` (integer), `tokens_used` (integer), `estimated_cost` (decimal) for performance and cost observability.
- D-27: **WorkflowEngine** is the public outer service (lifecycle management). **ConductorService** is the inner service (single Conductor dispatch). CLI calls WorkflowEngine only.
- D-29: ArchitectGate in automated loop between decompose and code. New `architect_reviewing` phase. New `dispatch_architect_review` tool.
- D-31: Three-layer testing: (1) tool guard unit tests (deterministic), (2) prompt contract tests (live LLM, on prompt changes), (3) integration tests (VCR, assert state changes not reasoning).
- D-34: ConductorJob idempotency via `conductor_locked_at` datetime column on WorkflowExecution.
- D-38: Direct call callbacks for ConductorJob triggers. Atomic "all tasks terminal" check via single SQL count query.
- D-41: PRD 2-06 integration tests labeled as stub scaffolding. No VCR for stubs. PRD 2-10 is first real E2E VCR test.
**Log Requirements**
- Create/update task log under `knowledge_base/task-logs/`

---

### Overview

This is the architectural pivot of Epic 2. PRD 2-06 introduces the Conductor Agent — an LLM-powered orchestrator that drives the entire implement cycle by calling orchestration tools. The Conductor reads the current WorkflowExecution state and decides what phase to execute next, recording every decision with its reasoning.

Three key components:
1. **WorkflowEngine** (D-27) — the public outer service that owns the `implement` lifecycle: create execution, acquire lock, capture PRD snapshot, enqueue first ConductorJob
2. **ConductorService** — the inner service that performs a single Conductor dispatch: assemble the Conductor agent from `conductor.yml` (D-17), render the prompt via PromptBuilder, dispatch via agent_desk, process the tool call, create ConductorDecision
3. **ConductorJob** (D-20) — Solid Queue background job that wraps ConductorService. Event-driven: enqueued by callbacks from completing services (DecompositionService, TaskDispatchJob, ScoreService)

The Conductor has 9 orchestration tools (D-29), each accepting a required `reasoning:` parameter (D-19) and validating preconditions before executing (D-6).

---

### Requirements

#### Functional

- FR-1: Create `WorkflowEngine` service: `Legion::WorkflowEngine.call(prd_path:, project:, team:, options:)`
  - Creates WorkflowExecution with `prd_snapshot` and `prd_content_hash` (D-23)
  - Acquires per-project advisory lock (from 2-01's AdvisoryLockService)
  - Enqueues first `ConductorJob(execution_id:, trigger: :start)`
  - Returns WorkflowExecution record
- FR-2: Create `ConductorService` service: `Legion::ConductorService.call(execution:, trigger:)`
  - Resolves Conductor TeamMembership by role name `conductor` (D-17)
  - Renders `conductor_prompt.md.liquid` via PromptBuilder with current execution state
  - Dispatches Conductor agent via `DispatchService` with orchestration tools only
  - Processes the Conductor's tool call response
  - Creates `ConductorDecision` record with `reasoning` (from tool parameter), `duration_ms`, `tokens_used`, `estimated_cost` (D-21)
  - Updates `WorkflowExecution.phase` based on tool called
- FR-3: Create `ConductorJob` (ActiveJob, Solid Queue): `queue_as :conductor`
  - Wraps `ConductorService.call(execution:, trigger:)`
  - On failure: log error, check if retryable, potentially enqueue retry ConductorJob
  - Acquires conductor lock via `conductor_locked_at` column before dispatch. Atomic check-and-set: `WorkflowExecution.where(id: x, conductor_locked_at: nil).or(...where('conductor_locked_at < ?', 5.minutes.ago)).update_all(conductor_locked_at: Time.current)`. If update returns 0, return silently (another ConductorJob holds the lock). Set `conductor_locked_at = nil` after successful completion (D-34).
- FR-4: Create Conductor agent config: `.aider-desk/agents/conductor.yml`
  - Model: Claude Sonnet (cost-efficient routing)
  - Tool approvals: orchestration tools auto-approved
  - Rules: conductor-specific rules
- FR-5: Implement 9 orchestration tools (each as a callable class/module):
  - `dispatch_decompose(reasoning:)` — dispatches Architect, creates plan Artifact
  - `dispatch_architect_review(reasoning:)` — dispatches Architect for plan review (D-29)
  - `dispatch_coding(reasoning:)` — enqueues TaskDispatchJobs for ready tasks
  - `dispatch_scoring(reasoning:)` — dispatches QA agent via ScoreService
  - `retry_with_context(reasoning:)` — calls TaskResetService, accumulates context (task selection via file path matching in QA feedback, falls back to retry-all) (D-32).
  - `run_retrospective(reasoning:)` — triggers retrospective analysis
  - `mark_completed(reasoning:)` — marks execution completed, releases lock
  - `escalate(reasoning:, error_details:)` — marks execution escalated
  - `get_execution_status(reasoning:)` — returns current state (read-only)
- FR-6: Each tool validates preconditions before executing (D-6). Returns error message to Conductor if precondition fails.
- FR-7: Each tool accepts `reasoning:` as a required string parameter (D-19). Stored in ConductorDecision.reasoning.
- FR-8: Event-driven callbacks (D-20):
  - `DecompositionService` completion → enqueues `ConductorJob(trigger: :decomposition_complete)`
  - All tasks in terminal state → enqueues `ConductorJob(trigger: :all_tasks_complete)`
  - ScoreService completion → enqueues `ConductorJob(trigger: :scoring_complete)`
  - ArchitectGate completion → enqueues `ConductorJob(trigger: :architect_review_complete)`
  - Callbacks are direct method calls (not ActiveSupport::Notifications). Atomic 'all tasks terminal' check: `Task.where(workflow_execution_id: x).where.not(status: TERMINAL_STATUSES).count == 0` (D-38).
- FR-9: Create `ConductorHeartbeatJob` (D-18): Solid Queue recurring job, every 60 seconds
  - Finds running WorkflowExecutions with stale tasks (running > 15 min default)
  - Resets stale tasks to pending (via TaskResetService)
  - Enqueues ConductorJob to re-evaluate
  - Timeout configurable via `WorkflowExecution.metadata["heartbeat_timeout_minutes"]`
- FR-10: `WorkflowExecution.phase` updated atomically on each tool execution (D-15)
- FR-11: Duration, tokens, and cost captured per ConductorDecision (D-21):
  - `duration_ms`: `Time.current` difference between dispatch start and tool completion
  - `tokens_used`: from agent_desk Runner response metadata
  - `estimated_cost`: computed from model pricing (stored in config)

#### Non-Functional

- NF-1: Conductor dispatch (one decision) must complete in < 30 seconds (LLM call + tool execution)
- NF-2: ConductorDecision creation must be in same transaction as phase transition (atomicity)
- NF-3: Callback enqueue must be idempotent (duplicate callbacks should not create duplicate ConductorJobs)
- NF-4: WorkflowEngine must handle advisory lock failure gracefully (raise, don't hang)

#### Rails / Implementation Notes

- **Services**: `app/services/legion/workflow_engine.rb`, `app/services/legion/conductor_service.rb`
- **Jobs**: `app/jobs/conductor_job.rb`, `app/jobs/conductor_heartbeat_job.rb`
- **Tools**: `app/tools/legion/orchestration/` — one file per tool (9 tool classes)
- **Config**: `.aider-desk/agents/conductor.yml`, update `config/solid_queue.yml` (add `conductor` queue, add recurring heartbeat)
- **Callbacks**: Extend `OrchestratorHooksService` or add new callback hooks in `TaskDispatchJob`, `DecompositionService`, `ScoreService`

---

### Error Scenarios & Fallbacks

- **Conductor agent dispatch fails (LLM error)** → ConductorJob catches, logs error, enqueues retry ConductorJob with `trigger: :error_recovery`. Max 2 Conductor dispatch retries.
- **Conductor calls invalid tool** → Tool precondition guard returns error. Conductor receives error message and must choose a different action. ConductorDecision recorded with `to_phase: nil` and error in reasoning.
- **Conductor returns no tool call** → ConductorService logs warning, creates ConductorDecision with reasoning "No tool call in response", enqueues retry ConductorJob. After 2 retries: escalate.
- **Callback fails to enqueue ConductorJob** → ConductorHeartbeatJob (60s) detects stale execution and re-triggers. This is the safety net.
- **ConductorJob fails (exception)** → Solid Queue retries per job configuration. After max retries: execution stays in current phase. Heartbeat detects and re-triggers.
- **Advisory lock lost mid-execution** → Check lock status before each phase transition. If lost: log warning, attempt re-acquisition. If contention: escalate.
- **conductor.yml missing from project** → WorkflowEngine raises `Legion::ConductorNotConfiguredError` at startup ("No conductor agent configured. Create .aider-desk/agents/conductor.yml")

---

### Architectural Context

This is the heart of Epic 2. The Conductor Agent replaces what would traditionally be an AASM state machine with an LLM that follows prompt-defined rules (D-4). The architecture has two key safety properties:

1. **The prompt guides**: The Conductor prompt template contains numbered rules that direct the LLM's decisions. These rules are deterministic in intent but flexible in application.
2. **The tools guard**: Even if the Conductor makes a wrong decision, the tool's precondition check prevents invalid state transitions. The system cannot reach an invalid state through the Conductor.

The service layering (D-27) separates concerns:
- `WorkflowEngine` knows about lifecycle (lock, execution, status)
- `ConductorService` knows about agent dispatch (assembly, tools, decisions)
- `ConductorJob` knows about background execution (Solid Queue, retries)

The event-driven architecture (D-20) means the workflow runs entirely in background jobs. The CLI is a thin polling monitor — kill it and the workflow continues. This is essential for long-running PRD implementations (potentially hours).

**Non-goals:** This PRD does not implement QualityGate, ArchitectGate, or QAGate — the tools `dispatch_architect_review` and `dispatch_scoring` call placeholder implementations that PRDs 2-07 and 2-08 will fill in. For this PRD, scoring returns a mock result and architect review auto-passes.

---

### Acceptance Criteria

- [ ] AC-1: `WorkflowEngine.call(prd_path: "path/to/prd.md", project: p, team: t)` creates a WorkflowExecution with `prd_snapshot` populated and `prd_content_hash` computed
- [ ] AC-2: WorkflowEngine acquires advisory lock before first ConductorJob enqueue. If lock held: raises `WorkflowLockError`.
- [ ] AC-3: ConductorJob dispatches Conductor agent and creates ConductorDecision with `reasoning`, `from_phase`, `to_phase`, `tool_called`
- [ ] AC-4: ConductorDecision includes `duration_ms`, `tokens_used`, `estimated_cost` (D-21)
- [ ] AC-5: Given trigger `:start`, Conductor calls `dispatch_decompose` → phase transitions to `decomposing`
- [ ] AC-6: Given trigger `:decomposition_complete`, Conductor calls `dispatch_architect_review` → phase transitions to `architect_reviewing` (D-29)
- [ ] AC-7: Given trigger `:all_tasks_complete`, Conductor calls `dispatch_scoring` → phase transitions to `scoring`
- [ ] AC-8: Each orchestration tool validates preconditions. Given `mark_completed` called with score < threshold → tool returns error, no phase transition.
- [ ] AC-9: All tools accept `reasoning:` parameter (D-19). ConductorDecision.reasoning contains the value passed.
- [ ] AC-10: DecompositionService completion enqueues ConductorJob with `trigger: :decomposition_complete`
- [ ] AC-11: All tasks reaching terminal state enqueues ConductorJob with `trigger: :all_tasks_complete`
- [ ] AC-12: ConductorHeartbeatJob runs every 60s, detects tasks running > 15 min, resets them (D-18)
- [ ] AC-13: `conductor.yml` exists in `.aider-desk/agents/` and is importable via TeamImportService
- [ ] AC-14: `WorkflowExecution.conductor_decisions.order(:created_at)` returns chronological decision trail
- [ ] AC-15: Advisory lock released on execution completion or escalation

---

### Test Cases

#### Unit (Minitest)

- `test/services/legion/workflow_engine_test.rb`: Execution creation with PRD snapshot, lock acquisition, first ConductorJob enqueue, lock error on contention
- `test/services/legion/conductor_service_test.rb`: Conductor assembly, prompt rendering, tool call processing, ConductorDecision creation with all fields, error handling (no tool call, invalid tool)
- `test/tools/legion/orchestration/dispatch_decompose_test.rb`: Precondition validation (must be in decomposing phase), success path, error path
- `test/tools/legion/orchestration/dispatch_architect_review_test.rb`: Precondition (must be in architect_reviewing phase, decomposition_attempt < 2)
- `test/tools/legion/orchestration/dispatch_coding_test.rb`: Precondition (coding/retrying phase, ready tasks exist)
- `test/tools/legion/orchestration/dispatch_scoring_test.rb`: Precondition (scoring phase, all tasks terminal)
- `test/tools/legion/orchestration/retry_with_context_test.rb`: Precondition (score < threshold, attempt < max)
- `test/tools/legion/orchestration/mark_completed_test.rb`: Precondition (score ≥ threshold, retrospective complete)
- `test/tools/legion/orchestration/escalate_test.rb`: Always succeeds, marks escalated
- `test/tools/legion/orchestration/get_execution_status_test.rb`: Returns current state
- `test/tools/legion/orchestration/run_retrospective_test.rb`: Precondition (retrospective phase)
- `test/jobs/conductor_job_test.rb`: Wraps ConductorService, handles failures
- `test/jobs/conductor_heartbeat_job_test.rb`: Detects stale tasks, resets, enqueues ConductorJob

#### Integration (Minitest)

- `test/integration/conductor_stub_cycle_test.rb`: Full cycle decompose → architect_review → code → score → retrospective → complete. Uses stub gate results. Superseded by `implement_full_cycle_test.rb` in PRD 2-10. No VCR cassettes for stubs. Verify ConductorDecision trail has correct from/to phases. (Layer 3 testing per D-31: assert state changes, not reasoning text)
- `test/integration/conductor_callback_chain_test.rb`: Verify callback chain fires correctly: decomposition → ConductorJob → coding → tasks complete → ConductorJob → scoring

#### Prompt Contract Tests (Layer 2, D-31)

- `test/prompt_contracts/conductor_prompt_test.rb`: (Tagged `live_llm: true`, not run in CI)
  - Given `phase: decomposing, tasks: 0` → Conductor calls `dispatch_decompose`
  - Given `phase: architect_reviewing, architect_score: 92` → Conductor calls `dispatch_coding`
  - Given `phase: architect_reviewing, architect_score: 75, decomposition_attempt: 1` → Conductor calls `dispatch_decompose`
  - Given `phase: scoring, score: 87, attempt: 1, max_retries: 3` → Conductor calls `retry_with_context`
  - Given `phase: scoring, score: 94, attempt: 1` → Conductor calls `run_retrospective`

---

### Manual Verification

1. Ensure `conductor.yml` exists in `.aider-desk/agents/` and team is imported
2. Run `bin/legion implement <prd-path> --team ROR --dry-run` (once 2-10 exists; for now test via console)
3. In console: `engine = Legion::WorkflowEngine.call(prd_path: "path/to/prd.md", project: Project.first, team: "ROR")`
4. Observe ConductorJobs being enqueued in Solid Queue logs
5. Query: `WorkflowExecution.last.conductor_decisions.order(:created_at)` — verify decision trail
6. Verify each decision has: reasoning (non-empty), from_phase, to_phase, tool_called, duration_ms

**Expected:** Conductor drives execution through phases. Decisions recorded with reasoning. Callbacks fire correctly between phases.

---

### Dependencies

- **Blocked By:** 2-01 (parallel dispatch, advisory lock), 2-02 (WorkflowExecution, ConductorDecision, Artifact models), 2-04 (TaskResetService for retry tool), 2-05 (PromptBuilder for conductor_prompt)
- **Blocks:** 2-07 (QualityGate integrates with Conductor scoring), 2-09 (Retry logic uses Conductor tools)

---

### Rollout / Deployment Notes

- **Agent config**: Create `conductor.yml` in `.aider-desk/agents/`. Run `bin/legion validate` to import.
- **Solid Queue**: Add `conductor` queue to `config/solid_queue.yml`. Add `conductor_heartbeat` recurring job.
- **OrchestratorHooksService**: Extended with Conductor callbacks. Verify existing hooks still work.


---

