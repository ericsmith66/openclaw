# PRD 2-10: `bin/legion implement` Full Loop

**Epic:** [Epic 2 — WorkflowEngine & Quality Gates](0000-epic.md)

## Key Decisions

- D-16: **Mandatory retrospective on every run**, human-gated changes
- D-20: ConductorJob runs in Solid Queue (event-driven). Triggers are callbacks from completing services. CLI polls WorkflowExecution.status every 2s with progress output.
- D-23: WorkflowExecution stores `prd_snapshot` (text, full content) and `prd_content_hash` (string, SHA-256) at creation time.
- D-24: `--dry-run` outputs: PRD path + hash, rendered Conductor prompt, expected first tool call, advisory lock status, concurrency mode.
- D-27: **WorkflowEngine** (outer) / **ConductorService** (inner) service layering with event-driven ConductorJob
- D-31: Three-layer testing: (1) tool guard unit tests (deterministic), (2) prompt contract tests (live LLM, on prompt changes), (3) integration tests (VCR, assert state changes not reasoning)
- D-33: Retrospective has 6 named categories with markdown heading structure. `retrospective_prompt.md.liquid` added to PromptBuilder (7th template).
- D-40: `--skip-scoring` bypasses Conductor entirely — direct service calls for decompose + execute. No gates, no retry, no retrospective.
**Log Requirements**
- Create/update task log under `knowledge_base/task-logs/`

---

### Overview

This is the capstone PRD. All prior PRDs built individual components: parallel dispatch, artifacts, scoring, task re-run, prompts, conductor, gates, retry. PRD 2-10 wires them together into `bin/legion implement <prd-path>` — a single command that runs the full automated implementation cycle: decompose → architect review → code → QA score → (retry if needed) → retrospective → complete/escalate.

The CLI creates a WorkflowExecution via WorkflowEngine, which enqueues the first ConductorJob. The Conductor drives the entire cycle through event-driven callbacks. The CLI polls execution status every 2 seconds, printing progress as phases change. When the execution reaches terminal state (completed, failed, escalated), the CLI prints a final summary including the retrospective recommendations and exits with the appropriate code.

---

### Requirements

#### Functional

- FR-1: New CLI command: `bin/legion implement <prd-path> --team <name>`
- FR-2: Options:
  - `--max-retries <N>` (default 3) — execution-level retry limit
  - `--threshold <N>` (default 90) — QA gate threshold
  - `--sequential` — force sequential task dispatch
  - `--concurrency <N>` (default 3) — parallel worker limit
  - `--dry-run` — show plan without executing (D-24)
  - `--skip-scoring` — code only, no QA gate
  - `--format json` — machine-readable output (for `--dry-run`)
  - `--heartbeat-timeout <N>` — stale task timeout in minutes (default 15)
  - `--task-retry-limit <N>` — per-task retry limit (default 3) (D-30)
  - When `--skip-scoring` is set, WorkflowEngine skips ConductorJob entirely. Direct service calls: DecompositionService → PlanExecutionService. No gates, no retry, no retrospective. Status set to `completed` when all tasks finish (D-40).
- FR-3: Implement `--dry-run` output (D-24):
  - Resolved PRD path and content hash
  - Rendered Conductor prompt (from PromptBuilder)
  - Expected first tool call (dispatch_decompose)
  - Advisory lock status (available / locked by execution #N)
  - Concurrency mode (parallel/sequential with count)
  - `--format json` returns JSON object with same fields
- FR-4: Normal execution flow:
  - Validate PRD file exists and is readable
  - Call `WorkflowEngine.call(prd_path:, project:, team:, options:)`
  - Enter polling loop: check `WorkflowExecution.reload.status` every 2 seconds
  - Print progress as phases change (see CLI output format in epic overview)
  - On terminal status: print final summary, exit
- FR-5: Progress output shows:
  - Phase transitions with timing
  - Parallel wave execution (which tasks in each wave)
  - Score results with verdict
  - Retry information (which tasks, accumulated context summary)
  - Retrospective recommendations summary
- FR-6: Retrospective integration — `run_retrospective` tool full implementation:
  - Conductor analyzes full execution: all ConductorDecisions, task results, QA scores, WorkflowEvents, retry history
  - Produces `retrospective_report` Artifact with 6 recommendation categories (### 1. Prompt Tweaks, ### 2. Skill Gaps, ### 3. Tool Improvements, ### 4. Rule Changes, ### 5. Decomposition Patterns, ### 6. Model Fit) plus ### Overall Assessment and ### Summary (D-33).
  - Recommendations are advisory only (D-16) — printed to CLI, stored as Artifact
  - Known concern: data volume caps deferred (S-5). PRD documents this — implementor monitors actual volumes.
- FR-7: Exit codes:
  - 0: completed successfully (score ≥ threshold)
  - 3: escalated (max retries exceeded or unrecoverable error)
  - 4: advisory lock unavailable
  - 1: command error (bad arguments, file not found, etc.)
- FR-8: `bin/legion status --execution <id>` — reconnect to a running execution's progress output (for when CLI was killed and restarted)
- FR-9: `bin/legion unlock --project <path>` — manually release advisory lock (escape hatch)
- FR-10: PRD drift detection: if PRD file has been modified since execution started (`prd_content_hash` mismatch), print warning during retry but don't block

#### Non-Functional

- NF-1: CLI polling must not consume significant CPU (2-second sleep between checks)
- NF-2: Progress output must be readable in a terminal (colored, structured, with timing)
- NF-3: `--dry-run` must complete in < 5 seconds (no LLM calls)
- NF-4: Full `implement` run on a moderate PRD (8 tasks, 1 retry) should complete in < 30 minutes

#### Rails / Implementation Notes

- **CLI**: New Thor command `implement` in `bin/legion`. Also `status` and `unlock` subcommands.
- **Progress**: CLI polling loop in command class. Uses `WorkflowExecution.reload` to detect phase changes.
- **Dry-run**: Uses PromptBuilder to render Conductor prompt, AdvisoryLockService to check lock status.
- **Retrospective**: Full implementation of `run_retrospective` tool. Uses existing execution data (ConductorDecisions, Artifacts, Tasks, WorkflowEvents).

---

### Error Scenarios & Fallbacks

- **PRD file not found** → Exit code 1, "PRD file not found: <path>"
- **Team not found** → Exit code 1, "Team '<name>' not found"
- **Conductor agent not configured** → Exit code 1, "No conductor agent configured. Create .aider-desk/agents/conductor.yml"
- **Advisory lock held** → Exit code 4, "Project locked by execution #<id>. Use `bin/legion unlock --project <path>` to force release."
- **CLI killed mid-execution** → Workflow continues in background (event-driven). Reconnect with `bin/legion status --execution <id>`.
- **All retries exhausted** → Retrospective runs → escalation. Exit code 3 with specific issues and suggested manual steps.
- **Conductor dispatch fails repeatedly** → ConductorJob retries (Solid Queue). After max job retries: execution stuck. Heartbeat detects and re-triggers. If still failing: manual intervention needed.
- **Retrospective LLM call fails** → Log error, create minimal retrospective_report Artifact ("Retrospective failed: <error>"). Execution still completes/escalates — retrospective failure doesn't block completion.
- **PRD drift detected during retry** → Warning printed: "⚠️ PRD has been modified since execution started. Current hash: <new>, original: <old>. Retry is using the original PRD snapshot."

---

### Architectural Context

This PRD is pure integration — no new architectural components. It connects:
- `WorkflowEngine` (2-06) for execution lifecycle
- `ConductorJob` (2-06) for background orchestration
- `TaskDispatchJob` (2-01) for parallel task execution
- `QAGate` and `ArchitectGate` (2-08) for quality enforcement
- `RetryContextBuilder` (2-09) for retry logic
- `PromptBuilder` (2-05) for all prompts
- `AdvisoryLockService` (2-01) for project locking

The CLI is a thin layer: create execution, poll status, print progress, exit. All work happens in background jobs.

The retrospective is the final phase of every execution. It produces advisory-only intelligence that compounds across runs (see epic overview for detailed retrospective format). This is the self-healing mechanism for budget models.

**Known concern (S-5):** Retrospective data volume is not capped in this PRD. If context exceeds model limits during testing, add caps (summarize WorkflowEvents, limit previous retrospectives to last 3). This is documented for the implementor.

---

### Acceptance Criteria

- [ ] AC-1: `bin/legion implement path/to/prd.md --team ROR` creates WorkflowExecution and runs full cycle
- [ ] AC-2: CLI prints progress for each phase transition with timing
- [ ] AC-3: Parallel task waves are visible in progress output ("Wave 1: Tasks #1, #2 — 2m 15s")
- [ ] AC-4: QA score displayed with verdict (PASSED ✅ / BELOW THRESHOLD ⚠️)
- [ ] AC-5: If score < 90 and retries available: retry happens automatically with accumulated context
- [ ] AC-6: Retrospective runs at the end of every execution (success and failure)
- [ ] AC-7: Given a completed execution, the `retrospective_report` Artifact contains all 6 section headings (`### 1. Prompt Tweaks` through `### 6. Model Fit`) with non-empty content under each (D-33).
- [ ] AC-8: Exit code 0 on success, 3 on escalation, 4 on lock contention, 1 on command error
- [ ] AC-9: `--dry-run` outputs: PRD path+hash, rendered Conductor prompt, expected tool call, lock status, concurrency mode (D-24)
- [ ] AC-10: `--dry-run --format json` returns valid JSON
- [ ] AC-11: `--sequential` forces sequential task dispatch (no parallel)
- [ ] AC-12: `--concurrency 2` limits parallel workers to 2
- [ ] AC-13: `bin/legion status --execution <id>` shows current execution progress
- [ ] AC-14: `bin/legion unlock --project <path>` releases advisory lock
- [ ] AC-15: CLI can be killed and restarted — workflow continues in background, reconnectable
- [ ] AC-16: PRD drift detected during retry prints warning (D-23)
- [ ] AC-17: Full E2E: decompose → architect review (D-29) → parallel code → QA score → retrospective → complete

---

### Test Cases

#### Unit (Minitest)

- `test/commands/implement_command_test.rb`: Argument parsing (all flags), dry-run output generation, exit code mapping, PRD file validation
- `test/commands/status_command_test.rb`: Reconnect to running execution, display progress
- `test/commands/unlock_command_test.rb`: Lock release, error if no lock held

#### Integration (Minitest)

- `test/integration/implement_full_cycle_test.rb`: Full cycle E2E: decompose → architect review → code → score → retrospective → complete. Verify: WorkflowExecution.status=completed, ConductorDecision trail has all phases, retrospective_report Artifact exists with content. (VCR-recorded — Layer 3 per D-31)
- `test/integration/implement_retry_cycle_test.rb`: Full cycle with retry: score < 90 → retry → score ≥ 90 → retrospective → complete. Verify: attempt=2, retry_context Artifact exists, accumulated feedback in retry prompt.
- `test/integration/implement_escalation_test.rb`: Full cycle with max retries exhausted: 3 QA cycles all < 90 → retrospective → escalated. Verify: status=escalated, exit code 3.
- `test/integration/implement_dry_run_test.rb`: Dry-run output contains all 5 sections (D-24). JSON format is valid.

#### System / Smoke

- E2E validation against a real PRD (not VCR):
  1. `bin/legion implement <simple-prd-path> --team ROR` → verify complete cycle
  2. Force a QA failure → verify retry with context → verify score improves
  3. Run two `implement` on same project → verify lock contention
  4. Kill CLI mid-execution → reconnect with `status` → verify workflow completed

---

### Manual Verification

1. Run `bin/legion implement knowledge_base/epics/wip/epic-2-planning/PRD-2-01.md --team ROR --dry-run`
2. Verify: output shows PRD hash, Conductor prompt, "would call dispatch_decompose", lock status
3. Run `bin/legion implement knowledge_base/epics/wip/epic-2-planning/PRD-2-01.md --team ROR`
4. Observe: phase-by-phase progress output
5. After completion: verify `WorkflowExecution.last.status` is "completed"
6. Verify: `WorkflowExecution.last.artifacts.where(artifact_type: :retrospective_report).count` ≥ 1
7. Verify: `WorkflowExecution.last.conductor_decisions.count` ≥ 5 (at least: decompose, architect_review, code, score, retrospective, complete)
8. Run `bin/legion status --execution <id>` — verify it shows completed status
9. Open second terminal, run `bin/legion implement <same-prd> --team ROR` — verify lock error

**Expected:** Full automated cycle completes. Retrospective generated. Audit trail complete. Lock prevents concurrent runs.

---

### Dependencies

- **Blocked By:** 2-09 (Retry Logic — the last piece before full integration)
- **Blocks:** Nothing — this is the capstone PRD

---

### Rollout / Deployment Notes

- **CLI additions**: `implement`, `status`, `unlock` subcommands
- **No new migrations** — all tables created in prior PRDs
- **E2E validation**: Run against a real (simple) PRD before marking complete. Recommended: use a PRD from Epic 1 as the test target.
- **Documentation**: Create `docs/implement-command-guide.md` with usage, flags, troubleshooting

---

