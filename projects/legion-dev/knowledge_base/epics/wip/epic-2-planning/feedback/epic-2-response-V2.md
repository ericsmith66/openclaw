# Epic 2 — Feedback Response V2

**Epic:** Epic 2 — WorkflowEngine & Quality Gates (CLI-First)
**Phase:** Φ6 V2 — Feedback Response
**Respondents:** Eric Smith + High-Reasoning AI
**Date:** 2026-03-10
**Input:** `epic-2-feedback-V2.md` (3 Questions, 6 Suggestions, 4 Objections)

---

## Questions

### Q-V2-1: `retry_with_context` Tool Signature — `task_ids:` Parameter Source

**Architect asked:** Model A (tool-decides, no `task_ids` param) vs Model B (Conductor-decides, passes `task_ids`)? PRD 2-06 and 2-09 conflict.

**EAS:** Need a recommendation.

**Response — Adopt Model A (tool-decides):**

`retry_with_context(reasoning:)` — no `task_ids` parameter. The tool itself reads the most recent `score_report` Artifact, attempts file path matching to identify affected tasks, and falls back to retrying all non-completed tasks if matching fails.

**Why Model A:**
- The Conductor is a routing agent, not a data parser. Asking it to extract task IDs from QA prose adds fragile NLP to the prompt.
- The tool has direct DB access — it can read the `score_report` Artifact content, scan for file paths, cross-reference `Task.metadata` for referenced files, and make a deterministic selection.
- If file path matching fails (no paths in feedback), the tool retries all non-completed tasks — this is the safe fallback and per O-V2-2 we're trying NLP first without guardrails.
- The Conductor's `reasoning:` parameter explains *why* it decided to retry (e.g., "Score 87 < 90, attempt 1/3") — the tool decides *which* tasks.

**PRD changes:**
- PRD 2-06 FR-5: Change `retry_with_context(reasoning:, task_ids:)` → `retry_with_context(reasoning:)`
- PRD 2-09 FR-1: No change needed (already describes tool-internal task selection)
- PRD 2-09 AC-2: Rephrase — "Given QA feedback containing file paths, the tool selects tasks referencing those files" (tested via unit test with controlled Artifact content, not LLM output)

**Decision locked: D-32 — `retry_with_context` uses Model A (tool-decides). No `task_ids` parameter. Tool reads score_report Artifact for file path matching. Falls back to retry-all.**

---

### Q-V2-2: `run_retrospective` Tool — Six Categories Undefined

**Architect asked:** What are the 6 categories and the output structure of `retrospective_report`?

**EAS:** Need a recommendation.

**Response — Define the 6 categories with markdown heading structure:**

The 6 recommendation categories (already named once in the DoD) are formalized with a required output structure. The `retrospective_prompt.md.liquid` template instructs the Conductor to produce a markdown document with these exact headings:

```markdown
## Retrospective Report — WorkflowExecution #{{ execution_id }}
PRD: {{ prd_path }} | Score: {{ final_score }}/100 | Attempts: {{ attempt }}

### Overall Assessment
(1-2 paragraphs: what happened, total time, cost, root cause of any failures)

### 1. Prompt Tweaks
(Specific wording changes to task/scoring/decomposition prompts)

### 2. Skill Gaps
(Skills that should activate but didn't, skills that weren't useful, NEW skills to create)

### 3. Tool Gaps
(Tool approval changes, NEW tools to create)

### 4. Rule Changes
(Rules too strict/loose, NEW rules to write)

### 5. Decomposition Quality
(Task sizing, dependency accuracy, parallel wave optimization)

### 6. Model Fit
(Model appropriateness per task type, model-switch suggestions)

### Summary
(Bullet list of top 3 actionable recommendations)
```

**Verification:** PRD 2-10 AC-7 becomes: "Given a completed execution, the `retrospective_report` Artifact contains all 6 section headings (`### 1. Prompt Tweaks` through `### 6. Model Fit`) with non-empty content under each."

**Template:** A new `retrospective_prompt.md.liquid` template is added to the PromptBuilder template set (PRD 2-05 FR-5 gains a 7th template). This template injects execution data and instructs the Conductor to produce the above structure.

**Decision locked: D-33 — Retrospective has 6 named categories with markdown heading structure. `retrospective_prompt.md.liquid` added to PromptBuilder. AC-7 updated to verify heading presence.**

---

### Q-V2-3: ConductorJob Failure Retry — Idempotency Mechanism

**Architect asked:** How to prevent duplicate ConductorJobs from heartbeat, Solid Queue retry, and explicit re-enqueue competing?

**EAS:** Need a recommendation.

**Response — Use a `conductor_lock` column on WorkflowExecution:**

Add a `conductor_locked_at` datetime column to WorkflowExecution. The idempotency mechanism:

1. **Before dispatching:** `ConductorJob#perform` attempts to acquire the conductor lock:
   ```ruby
   # Atomic check-and-set
   updated = WorkflowExecution.where(id: execution_id, conductor_locked_at: nil)
                              .or(WorkflowExecution.where(id: execution_id)
                              .where("conductor_locked_at < ?", 5.minutes.ago))
                              .update_all(conductor_locked_at: Time.current)
   return if updated == 0  # Another ConductorJob already holds the lock — skip silently
   ```

2. **After completing:** ConductorJob sets `conductor_locked_at = nil` after successfully creating the ConductorDecision and enqueuing any follow-up work.

3. **Stale lock protection:** The `5.minutes.ago` clause ensures a crashed ConductorJob's lock doesn't permanently block the execution. The heartbeat job (D-18) naturally clears stale locks by re-triggering.

**Why this approach:**
- No Solid Queue-specific configuration needed (works with any job backend)
- Atomic DB operation — no race conditions between competing jobs
- The losing ConductorJob simply returns early (no error, no retry) — it's not a failure, it's deduplication
- The 5-minute stale threshold is well above the expected Conductor dispatch time (< 30 seconds per NF-1 in PRD 2-06)

**PRD changes:**
- PRD 2-02: Add `conductor_locked_at` (datetime, nullable) to WorkflowExecution table
- PRD 2-06 FR-3: Add "ConductorJob acquires conductor lock before dispatch. If lock held by another job, return silently."
- PRD 2-06 NF-3: Resolved by this mechanism

**Decision locked: D-34 — ConductorJob idempotency via `conductor_locked_at` column on WorkflowExecution. Atomic check-and-set before dispatch. 5-minute stale threshold. Losing job returns silently.**

---

## Suggestions

### S-V2-1: PRD 2-01 — Concurrency Cap Implementation

**Architect suggested:** Specify the concurrency enforcement mechanism (Option 1: Solid Queue config vs Option 2: application-level semaphore).

**EAS:** Agree — Option 2.

**Response:** Accepted. Application-level semaphore. Before enqueuing each `TaskDispatchJob`, check `Task.where(workflow_execution_id: x, status: [:queued, :running]).count`. Only enqueue if count < `concurrency`. Hold remaining ready tasks in `pending`. Brief over-dispatch is acceptable (two completions racing) — the concurrency limit is a soft cap, not a hard mutex.

Add implementation note to PRD 2-01 FR-6/FR-11.

**Decision locked: D-35 — Concurrency enforcement via application-level count check (soft cap). Not Solid Queue queue config.**

---

### S-V2-2: PRD 2-02 — `version` Auto-Increment Strategy

**Architect suggested:** Specify the version increment strategy explicitly.

**EAS:** Agree.

**Response:** Accepted. Use `MAX(version) + 1` inside a transaction with retry on unique constraint violation. Add implementation note to PRD 2-02 FR-4: "Version computed as `Artifact.where(workflow_execution_id: x, artifact_type: t).maximum(:version).to_i + 1` inside `ActiveRecord::Base.transaction`. On `ActiveRecord::RecordNotUnique`: retry once."

**Decision locked: D-36 — Artifact version via MAX+1 in transaction with retry on unique violation.**

---

### S-V2-3: PRD 2-05 — `required_context` as Static Manifest

**Architect suggested:** Static manifest vs template parsing.

**EAS:** Option A (static manifest) for now. Note variables by convention so the parser can find them later.

**Response:** Accepted. `required_context(phase:)` returns a hardcoded array per phase. Add a convention comment in templates: `{# REQUIRED: prd_content, project_path #}` at the top of each `.md.liquid` file. This enables future automated parsing without blocking current implementation.

Add a "manifest completeness" test: render each template with only manifest-specified keys → verify no `Liquid::UndefinedVariable`.

**Decision locked: D-37 — Static manifest for required_context. Convention comment `{# REQUIRED: ... #}` in templates for future parsing. Manifest completeness test.**

---

### S-V2-4: PRD 2-06 — Callback Registration Pattern

**Architect suggested:** Specify callback pattern (direct call vs ActiveSupport::Notifications vs hook chain). Specify atomic "all tasks terminal" check.

**EAS:** Agree.

**Response:** Accepted. Use **direct call** (simplest, explicit):
- `DecompositionService#call` ends with `ConductorJob.perform_later(execution_id:, trigger: :decomposition_complete)` if `workflow_execution_id` is present
- `TaskDispatchJob#on_complete` checks `Task.where(workflow_execution_id: x).where.not(status: TERMINAL_STATUSES).count == 0` (atomic count) → if true, `ConductorJob.perform_later(trigger: :all_tasks_complete)`
- Gate evaluation (in orchestration tool) ends with `ConductorJob.perform_later(trigger: :scoring_complete)` or `:architect_review_complete`

The "all tasks terminal" check uses a single atomic query, not multiple attribute checks. Add to PRD 2-06 implementation notes.

**Decision locked: D-38 — Direct call callbacks. Atomic "all tasks terminal" check via single SQL count query.**

---

### S-V2-5: PRD 2-08 — Which `workflow_run` for Each Gate

**Architect suggested:** Clarify which workflow_run goes to ArchitectGate vs QAGate.

**EAS:** Agree.

**Response:** Accepted.
- **ArchitectGate** receives the decomposition `WorkflowRun` (created by `dispatch_decompose`). The `gate_context` reads tasks from this run.
- **QAGate** receives the `WorkflowExecution` (not a single run). The `gate_context` queries `execution.tasks` and their associated `WorkflowRun` results for code output. This handles multi-wave parallel coding runs.

The `QualityGate#evaluate` signature becomes `evaluate(execution:, workflow_run: nil)` — `workflow_run` is optional. ArchitectGate uses it; QAGate ignores it and queries from execution.

Add to PRD 2-07 FR-3 and PRD 2-08 FR-2/FR-4.

**Decision locked: D-39 — ArchitectGate takes decomposition WorkflowRun. QAGate takes WorkflowExecution (queries all tasks). evaluate() signature: workflow_run is optional.**

---

### S-V2-6: PRD 2-10 — `--skip-scoring` Bypasses Conductor

**Architect suggested:** Clarify `--skip-scoring` interaction with Conductor prompt.

**EAS:** Agree — `--skip-scoring` bypasses the Conductor entirely.

**Response:** Accepted. When `--skip-scoring` is set, `WorkflowEngine` skips ConductorJob entirely. Instead:
1. WorkflowEngine calls DecompositionService directly
2. WorkflowEngine calls PlanExecutionService directly (parallel or sequential per flags)
3. No ArchitectGate, no QAGate, no retry, no retrospective
4. Execution status set to `completed` when all tasks finish (no scoring)

This is a development escape hatch — the Conductor is not involved at all. Add to PRD 2-10 FR-2 implementation note.

**Decision locked: D-40 — `--skip-scoring` bypasses Conductor entirely. Direct service calls for decompose + execute. No gates, no retry, no retrospective.**

---

## Objections

### O-V2-1: PRD 2-06 Mock Gate Integration Tests

**Architect objected:** Mock gate tests in 2-06 become misleading when real gates arrive. No documented handoff.

**EAS:** Agree.

**Response:** Accepted. PRD 2-06 test cases updated:
- **Unit tests + prompt contract tests:** Permanent (test Conductor behavior, not gates)
- **Integration tests:** Explicitly labeled "stub integration" in file name and comments: `test/integration/conductor_stub_cycle_test.rb`. Header comment: "Uses stub gate results. Superseded by `implement_full_cycle_test.rb` in PRD 2-10."
- **No VCR cassettes** for the stub cycle test (recording mock behavior is pointless)
- PRD 2-10 `implement_full_cycle_test.rb` is the first real full-cycle VCR recording

Add to PRD 2-06 test cases section and implementation notes.

**Decision locked: D-41 — PRD 2-06 integration tests labeled as stub scaffolding. No VCR for stubs. PRD 2-10 is first real E2E VCR test.**

---

### O-V2-2: Retry Task Selection via NLP

**Architect objected:** File path matching in QA prose is brittle. Suggested structured output mandate or always-retry-all.

**EAS:** Don't add guardrails now. Try the NLP first. Flag for future epics.

**Response:** Accepted — keep the current NLP approach (file path matching in QA output). The fallback (retry all non-completed tasks) handles the case where matching fails. This is explicitly a design choice to try the lightweight approach first.

**What we do now:**
- Keep PRD 2-09 FR-1 as-is (file path matching with fallback to retry-all)
- PRD 2-09 AC-2 uses controlled Artifact content in unit tests (not dependent on LLM output)
- Document in PRD 2-09: "Known limitation: file path matching in QA output is best-effort. If QA feedback doesn't contain parseable paths, all non-completed tasks are retried. Future epics may mandate structured QA output (see Architect feedback O-V2-2)."

**Decision: D-42 — NLP-based task selection kept as-is. Best-effort with retry-all fallback. Flag for future structured output mandate in Epic 3+.**

---

### O-V2-3: `dispatch_coding` Precondition After Retry Reset

**Architect objected:** Tasks may be `pending` (not `ready`) after reset. `dispatch_coding` precondition could refuse, causing deadlock.

**EAS:** Agree.

**Response:** Accepted. `retry_with_context` performs the full reset cycle synchronously before enqueuing the next ConductorJob:

1. Reset targeted tasks to `pending` (via TaskResetService)
2. Run dependency re-evaluation synchronously (check all dependencies, promote `pending` → `ready` where deps are met)
3. Create `retry_context` Artifact
4. Create ConductorDecision
5. THEN enqueue `ConductorJob(trigger: :retry_ready)`

By the time `dispatch_coding` is called by the next ConductorJob, tasks are already in `ready` state. No timing gap.

Add to PRD 2-09 FR-1 and PRD 2-06 tool precondition notes.

**Decision locked: D-43 — `retry_with_context` completes reset + dependency re-evaluation synchronously before enqueuing ConductorJob. No async gap between reset and dispatch.**

---

### O-V2-4: Missing Layer 2 Prompt Contract Tests for Gate Prompts

**Architect objected:** No prompt contract tests for `architect_review_prompt.md.liquid` or `qa_score_prompt.md.liquid`.

**EAS:** Agree.

**Response:** Accepted. Add 4 Layer 2 prompt contract tests to PRD 2-08:

**`test/prompt_contracts/architect_review_prompt_test.rb`** (tagged `live_llm: true`):
- Given valid task list + DAG → Architect returns parseable score (any of 3 formats)
- Given clearly flawed decomposition (circular dep, no test tasks) → Architect score < 90

**`test/prompt_contracts/qa_score_prompt_test.rb`** (tagged `live_llm: true`):
- Given passing code + met acceptance criteria → QA score ≥ 90
- Given clearly failing code (empty implementation) → QA score < 90

Add to PRD 2-08 test cases section.

**Decision locked: D-44 — 4 Layer 2 prompt contract tests added to PRD 2-08 (2 per gate). Tagged `live_llm: true`. Run on gate prompt changes.**

---

## Summary of Locked Decisions

| # | Decision | Source |
|---|----------|--------|
| D-32 | `retry_with_context` Model A — tool-decides task selection, no `task_ids` param | Q-V2-1 |
| D-33 | Retrospective 6 categories with markdown heading structure, `retrospective_prompt.md.liquid` added | Q-V2-2 |
| D-34 | ConductorJob idempotency via `conductor_locked_at` column, atomic check-and-set, 5-min stale | Q-V2-3 |
| D-35 | Concurrency enforcement via application-level count check (soft cap) | S-V2-1 |
| D-36 | Artifact version via MAX+1 in transaction with retry on unique violation | S-V2-2 |
| D-37 | Static manifest for `required_context`, convention comment `{# REQUIRED #}` in templates | S-V2-3 |
| D-38 | Direct call callbacks, atomic "all tasks terminal" SQL count check | S-V2-4 |
| D-39 | ArchitectGate takes WorkflowRun, QAGate takes WorkflowExecution, `workflow_run` optional in evaluate() | S-V2-5 |
| D-40 | `--skip-scoring` bypasses Conductor entirely — direct service calls | S-V2-6 |
| D-41 | PRD 2-06 stub integration tests labeled as scaffolding, no VCR for stubs | O-V2-1 |
| D-42 | NLP-based retry task selection kept — best-effort with retry-all fallback, flagged for Epic 3+ | O-V2-2 |
| D-43 | `retry_with_context` completes reset + dependency re-eval synchronously before ConductorJob enqueue | O-V2-3 |
| D-44 | 4 Layer 2 prompt contract tests for gate prompts added to PRD 2-08 | O-V2-4 |

---

## Items for Architect V3 Review

No items are expected to require a V3 cycle. All objections resolved, all questions answered. The Architect confirmed the document is "85% ready" with the remaining 15% being these targeted resolutions — all now addressed.

**Recommendation:** Proceed to Φ7 (PRD Breakout) after incorporating D-32 through D-44 into the epic document.
