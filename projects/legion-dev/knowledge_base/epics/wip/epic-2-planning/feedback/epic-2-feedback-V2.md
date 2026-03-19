# Epic 2 — Architect Review Feedback V2

**Phase:** Φ5 V2 — Architect Review (Post-Expansion)
**Reviewer:** Architect Agent
**Date:** 2026-03-10
**Input:** Consolidated Φ4 document — `0000-epic.md` (epic overview + 10 fully expanded PRDs, 2276 lines)
**Prior Cycle:** V1 produced 18 items → all resolved in V1 Response (D-17 through D-31 locked)

---

## Preamble

The expanded document is a substantial improvement over the V1 skeleton. All 15 locked decisions (D-17 through D-31) are correctly incorporated. The dependency graph reordering (D-28) is clean and eliminates the provisional storage problem. The Conductor prompt template is correctly specified as Liquid, the three-layer testing strategy is present in both the epic overview and PRD 2-06, and the two-tier retry semantics are consistently represented across PRDs 2-06, 2-09, and the data model.

At this fidelity, new issues become visible that weren't in the skeleton. The concerns below fall into two categories: (1) implementation-readiness gaps — places where an implementor would stall waiting for a decision that should have been made here, and (2) cross-PRD consistency gaps — places where two PRDs describe the same interface differently. There are no architectural pivots required. The document is close to Φ7-ready, with a small number of targeted resolutions needed.

---

## Questions      

### Q-V2-1: `retry_with_context` Tool Signature — `task_ids:` Parameter Source

**PRD 2-06, FR-5** specifies the `retry_with_context` tool signature as `retry_with_context(reasoning:, task_ids:)`. **PRD 2-09, FR-1** describes the tool "selecting tasks to retry: tasks cited in QA feedback (file path matching), or all failed tasks, or all tasks if unclear."

There is a tension here: if task selection is determined *inside* the tool (by reading QA feedback and doing file path matching), then the `task_ids:` parameter is redundant — the Conductor doesn't know which tasks to cite. If the `task_ids:` parameter is how the Conductor tells the tool which tasks to retry, then the Conductor must have performed the file path matching itself (from the QA feedback text), which requires the Conductor to parse structured data out of natural language — a fragile dependency on QA output format.

**Which model is intended?**
- **Model A (Tool-decides):** `retry_with_context(reasoning:)` — no `task_ids`. The tool reads the QA score_report Artifact, performs file path matching internally, and selects tasks. The Conductor only says "retry" and why.
- **Model B (Conductor-decides):** `retry_with_context(reasoning:, task_ids: [3, 5])` — the Conductor must identify task IDs from the QA feedback before calling the tool. The prompt would need to instruct the Conductor to parse task file references.

The current spec appears to intend Model A (tool decides task selection in FR-1 of PRD 2-09) but specifies Model B's signature (PRD 2-06 FR-5). This needs resolution before PRD 2-06 is implemented, as the tool interface shapes both the Conductor prompt and the tool implementation.

**Clarification needed before PRD 2-06 implementation.**
EAS: I need a recomendation 
---

### Q-V2-2: `run_retrospective` Tool — Six Categories Undefined

**PRD 2-10, FR-6** specifies the retrospective produces recommendations in "6 categories" and references the "epic overview." The epic overview phase diagram and introduction mention the retrospective but the overview does **not** enumerate the 6 categories anywhere in the 2276-line document. The definition-of-done references "6 recommendation categories (prompts, skills, tools, rules, decomposition, model fit)" — this is the only place they appear, inline in a bulleted list.

PRD 2-10, AC-7 tests: `retrospective_report` Artifact contains "recommendations in 6 categories." But without the 6 categories being formally specified:
- The `retrospective_prompt.md.liquid` template (which the Conductor uses for this phase) doesn't have a defined structure to generate
- The acceptance criterion (AC-7) can't be verified — what format proves "recommendations in 6 categories"?
- The `run_retrospective` tool has no defined output contract

**Clarification needed:** What are the 6 categories and what is the required output structure (free text, JSON, specific headings) of the `retrospective_report` Artifact? This must be specified before `retrospective_prompt.md.liquid` is written.
EAS: I need a recomendation 
---

### Q-V2-3: ConductorJob Failure Retry — Separate from Execution Retry Limits

**PRD 2-06, Error Scenarios** states: "Conductor agent dispatch fails (LLM error) → ConductorJob catches, logs error, enqueues retry ConductorJob with trigger: :error_recovery. Max 2 Conductor dispatch retries."

**PRD 2-06, NF-3** states: "Callback enqueue must be idempotent (duplicate callbacks should not create duplicate ConductorJobs)."

These two requirements interact: if ConductorJob retries are handled by re-enqueueing a new ConductorJob, the idempotency mechanism must distinguish "this is a retry of a failed ConductorJob" from "this is a duplicate callback for the same trigger." Without an idempotency key or deduplication mechanism, a ConductorJob failure + Solid Queue automatic retry + the heartbeat re-trigger could create three competing ConductorJobs for the same execution state.

**Clarification needed:** Is ConductorJob idempotency enforced via Solid Queue's built-in uniqueness (concurrency limits or unique job IDs), via a column on WorkflowExecution (`conductor_lock` or similar), or via the tool preconditions (which would reject a second Conductor trying to execute the same transition)? The answer affects the implementation of ConductorJob significantly.
EAS: I need a recomendation 
---

## Suggestions

### S-V2-1: PRD 2-01 — Concurrency Cap Implementation is Underspecified

**PRD 2-01, FR-11** specifies `--concurrency <N>` flag to limit parallel workers. **AC-3** verifies: "Given `--concurrency 2`, at most 2 tasks run simultaneously." However, the implementation note is silent on *how* this limit is enforced. There are two plausible mechanisms:

1. **Solid Queue queue size limit:** Configure the `task_dispatch` queue with a thread limit matching `--concurrency`. Problem: this is a static config, not per-execution dynamic.
2. **Application-level semaphore:** Before enqueuing each `TaskDispatchJob`, check how many tasks are currently `running` for this execution. Only enqueue if `running_count < concurrency`. Hold remaining ready tasks in `pending`.

Option 2 is the correct approach (it's per-execution, not global), but it introduces a potential race condition: two `TaskDispatchJob`s completing simultaneously could both check `running_count`, both see 1, and both enqueue — briefly exceeding the limit. Suggest specifying that `dispatch_coding` (the Conductor tool) or `PlanExecutionService` uses an optimistic check with acceptable brief over-dispatch, OR uses a database-level semaphore (Solid Queue's concurrency control).

**Suggestion:** The implementation note for FR-11 and FR-6 should specify the concurrency enforcement mechanism explicitly so the implementor doesn't invent it.
EAS : Agree option 2 
---

### S-V2-2: PRD 2-02 — `version` Auto-Increment Race Condition Mitigation Underspecified

**PRD 2-02, FR-4** states: "Auto-increment `version` per `(workflow_execution_id, artifact_type)` on creation." **PRD 2-02, Error Scenarios** mentions: "Race condition on concurrent artifact creation — mitigate with UNIQUE INDEX (workflow_execution_id, artifact_type, version) and retry on conflict."

However, neither the Functional Requirements nor the Implementation Notes specify **how** the version number is computed before insert. The two standard approaches are:

1. **`MAX(version) + 1` query + optimistic lock:** Read current max version, attempt insert. On unique constraint violation: retry. This is correct but requires retry logic in the model.
2. **PostgreSQL sequence per (execution, type):** More complex, no retry needed.

For Epic 2's usage (artifact creation is not extremely high-frequency), approach 1 is fine — but the model needs explicit `with_lock` or `ActiveRecord::Base.transaction` + retry-on-conflict logic documented. Without it, the implementor may use a naive `Artifact.where(...).maximum(:version).to_i + 1` that is not safe under concurrent writes.

**Suggestion:** Add an implementation note to PRD 2-02 specifying the version increment strategy (e.g., "Use `with_lock` on a per-execution sentinel record, or use `INSERT ... SELECT MAX(version)+1` with conflict handling").
EAS:AGREE
---

### S-V2-3: PRD 2-05 — `required_context(phase:)` Implementation is Ambiguous

**PRD 2-05, FR-7** specifies: `PromptBuilder.required_context(phase:)` → returns list of required context keys for a given phase (derived from template variables).

"Derived from template variables" implies either: (a) parsing the Liquid template at runtime to extract `{{ variable_name }}` references, or (b) maintaining a static manifest alongside each template. Option (a) is fragile (Liquid conditionals like `{% if last_feedback %}` make a variable optional, not required — a parser can't know the difference). Option (b) is maintenance overhead but reliable.

**Suggestion:** Specify that `required_context` is implemented as a static manifest (a class method that returns a hardcoded array per phase), not template parsing. Add a note that the static manifest must be kept in sync with the template — and that the Minitest suite for PromptBuilder should include a "manifest completeness" test that renders each template with only the manifest-specified keys and verifies no `Liquid::UndefinedVariable` errors (catching drift between manifest and template).
EAS: A for now. We can note variables by convention so the parser can find them 
---

### S-V2-4: PRD 2-06 — Callback Registration Mechanism Not Specified

**PRD 2-06, FR-8** lists four event-driven callbacks that enqueue `ConductorJob`:
- `DecompositionService` completion → enqueue ConductorJob
- All tasks in terminal state → enqueue ConductorJob
- `ScoreService` completion → enqueue ConductorJob
- `ArchitectGate` completion → enqueue ConductorJob

The "how" is deferred to "Extend OrchestratorHooksService or add new callback hooks in TaskDispatchJob, DecompositionService, ScoreService." This is too vague for an implementor. Specifically:

- **DecompositionService completion:** Does this add a callback to the existing `OrchestratorHooksService` hook chain, or does it call `ConductorJob.perform_later` directly at the end of `DecompositionService#call`?
- **All tasks terminal:** This check lives in `TaskDispatchJob#on_success`/`#on_failure`. The check "are all tasks terminal?" must be atomic with respect to concurrent job completions — two tasks completing simultaneously could both check and both see "not all terminal" if there's a race.
- **ScoreService vs QualityGate:** PRD 2-03 introduces `ScoreService`. PRD 2-07 introduces `QualityGate` which wraps scoring. After PRD 2-07, does the callback come from `ScoreService` or from the `QAGate.evaluate` call in the `dispatch_scoring` tool?

**Suggestion:** PRD 2-06's implementation notes should specify the callback pattern: direct call in service (simplest, but couples services to ConductorJob) vs. ActiveSupport::Notifications vs. hook chain. The "all tasks terminal" check should note that it uses an atomic database count (`Task.where(workflow_execution_id: x, status: TERMINAL_STATUSES).count == Task.where(workflow_execution_id: x).count`) inside a transaction or with advisory lock.
EAS:Agree
---

### S-V2-5: PRD 2-08 — ArchitectGate Context Gap: Which `workflow_run` Is Passed?

**PRD 2-08, FR-2** specifies that `ArchitectGate#gate_context` includes "task list with descriptions, DAG structure, task sizing scores, parallel wave breakdown." The ArchitectGate reviews the *decomposition plan* — but the decomposition is stored in Tasks (on the WorkflowRun from `dispatch_decompose`).

**PRD 2-07, FR-3** specifies the evaluate signature as `evaluate(execution:, workflow_run:)`. For the ArchitectGate, the `workflow_run` passed should be the decomposition WorkflowRun (the run created by `dispatch_decompose`). But for QAGate, the `workflow_run` should be the coding WorkflowRun (or the WorkflowExecution aggregating all coding runs).

The PRD doesn't specify which `workflow_run` is passed to each gate, and they need different things. If QAGate is passed the same WorkflowRun as ArchitectGate, it would have no code output to score.

**Suggestion:** Clarify in PRD 2-08 (and implicitly in PRD 2-07's base class) that:
- `ArchitectGate#evaluate` receives the decomposition `WorkflowRun` (the one created by DecompositionService)
- `QAGate#evaluate` receives either the coding `WorkflowRun` or the `WorkflowExecution` (and queries across all coding runs for code outputs)
- The `gate_context` base implementation in `QualityGate` should document how it sources task results — is it from `workflow_run.tasks` or `execution.tasks`?
EAS:Agree
---

### S-V2-6: PRD 2-10 — `--skip-scoring` Flag Needs Conductor Prompt Consideration

**PRD 2-10, FR-2** lists `--skip-scoring` as an option — "code only, no QA gate." This is a useful escape hatch for development, but it creates an unaddressed interaction with the Conductor:

The Conductor's prompt rules (Rule 6: "After all tasks complete, call dispatch_scoring") are hard-coded in `conductor_prompt.md.liquid`. If `--skip-scoring` is set, the Conductor would still try to call `dispatch_scoring` — unless the prompt template or execution state tells it not to.

**Suggestion:** Either: (a) the `--skip-scoring` flag is reflected in the Conductor prompt context (`{{ skip_scoring }}`), and the prompt includes a rule like "If skip_scoring is true, call run_retrospective directly after all tasks complete", or (b) `--skip-scoring` is an escape hatch that bypasses the Conductor entirely and just calls `dispatch_coding` directly via WorkflowEngine without ever dispatching the Conductor. Clarify which approach is intended in PRD 2-10.
EAS:agree ,--skip-scoring` is an escape hatch that bypasses the Conductor 
---

## Objections

### O-V2-1: PRD 2-06 Non-Goal Creates a Broken Intermediate State

**Problem:** PRD 2-06's non-goal states: "This PRD does not implement QualityGate, ArchitectGate, or QAGate — the tools `dispatch_architect_review` and `dispatch_scoring` call placeholder implementations that PRDs 2-07 and 2-08 will fill in. **For this PRD, scoring returns a mock result and architect review auto-passes.**"

This is functionally correct as an implementation strategy. The problem is with the acceptance criteria: **AC-5** asserts "Given trigger `:start`, Conductor calls `dispatch_decompose` → phase transitions to `decomposing`" and **AC-6** asserts "Given trigger `:decomposition_complete`, Conductor calls `dispatch_architect_review` → phase transitions to `architect_reviewing`." These ACs test real Conductor behavior against real phases.

But **AC-8** asserts: "Each orchestration tool validates preconditions. Given `mark_completed` called with score < threshold → tool returns error." If `dispatch_scoring` uses a mock result for PRD 2-06, the `mark_completed` precondition test can only run with the mocked score — which means the acceptance criteria tests are testing against a mock, not the real gate.

The deeper issue: when PRD 2-07 and 2-08 replace the mocks with real implementations, **the integration tests written for PRD 2-06 become misleading** — they test the Conductor's behavior against mock gate results, but the real gates may take longer, produce different output formats, or fail in ways the mock didn't simulate. The VCR cassettes recorded against mock scoring will not capture the behavior of real gate evaluation.

**This creates technical debt:** Two integration test suites will co-exist — one for PRD 2-06 (mocked gates) and one for PRD 2-10 (real gates). The PRD 2-06 tests will need to be replaced or updated when real gates are connected, but the PRDs don't document this handoff.

**Potential Solution:** Reframe PRD 2-06's testing strategy explicitly:

1. **Unit and prompt contract tests for PRD 2-06** — test the Conductor's decision-making and tool precondition guards with mock gate results. These tests remain valid forever (they test the *Conductor's* behavior, not the gate's).
2. **PRD 2-06 integration tests** — explicitly labeled as "stub integration tests" that verify the callback chain fires correctly and ConductorDecisions are created, using stub gate results. Add a note in the test file: "These tests will be superseded by `implement_full_cycle_test.rb` in PRD 2-10."
3. **No VCR cassettes for PRD 2-06's full-cycle test** until gates are real (PRD 2-10's `implement_full_cycle_test.rb` is where the first real full-cycle VCR recording happens).

Add this explicitly to PRD 2-06's test cases and implementation notes so the coding agent knows which tests are permanent and which are temporary scaffolding.
EAS:Agree
---

### O-V2-2: PRD 2-09 Task Selection Logic Creates a Brittle LLM-Text-Parsing Dependency

**Problem:** **PRD 2-09, FR-1** specifies task selection for retry: "tasks cited in QA feedback (file path matching)." **PRD 2-09, FR-7** specifies `RetryContextBuilder` builds context "reading all prior retry_context and review_feedback Artifacts."

The phrase "file path matching" in the QA feedback implies parsing the QA agent's natural language output to extract file paths that the agent mentioned. This is fragile because:

1. **QA output format is not contractually defined.** The `qa_score_prompt.md.liquid` template (PRD 2-05/2-08) tells the QA agent what to evaluate and return, but does not mandate that the QA agent structure its feedback with file paths in a parseable format (e.g., code fences, specific headers, or structured JSON).
2. **File path matching in prose is unreliable.** "The `UserController` needs better error handling" doesn't contain a file path. "The file `app/controllers/users_controller.rb` is missing..." does. Regex on LLM output for paths is inherently fragile.
3. **AC-2** in PRD 2-09 tests: "Given QA feedback citing files `app/models/user.rb` and `test/models/user_test.rb`, only tasks referencing those files are reset." This test asserts a specific behavior but would only pass if the VCR cassette's recorded QA output happened to contain those exact strings.

This creates a hidden dependency: the retry task selection quality depends entirely on whether the QA agent structures its feedback with parseable file paths — which is a prompt quality concern, not a code concern. If the QA agent gives good qualitative feedback without file paths, **all non-completed tasks get retried** (the fallback in FR-1). This may be acceptable behavior, but the spec presents it as the fallback for an unclear case, not as the common case.

**Potential Solution:** Make task selection deterministic rather than NLP-dependent. Two options:

**Option A (Preferred):** Mandate that the `qa_score_prompt.md.liquid` template instructs the QA agent to output its feedback in a structured format that includes task IDs or file paths in a parseable section. Example:
```
## Failed Tasks
- Task #3 (app/models/user.rb): Missing validation for email uniqueness
- Task #5 (test/models/user_test.rb): Test coverage for email validation missing
```
This moves the parsing challenge to a prompt design choice (solvable, version-controlled) rather than an ad-hoc regex (fragile).

**Option B:** Always retry all non-completed tasks (never attempt file path matching). This is simpler, slightly less efficient (retries tasks that might have passed individually), but deterministic. On complex PRDs, the Conductor prompt can instruct the agent to "be specific in your implementation" — the retry context provides all feedback regardless of which tasks are targeted.

The document should pick one approach and specify it. If Option A, the `qa_score_prompt.md.liquid` template structure must mandate the "Failed Tasks" section. If Option B, eliminate the "file path matching" language from PR 2-09 and PR 2-06.
EAS: Lets not this but we should flag it for future epics I want to try the NLP first before we start putting up gardrails 
---

### O-V2-3: The `dispatch_coding` Tool Has No Guard Against Re-Dispatching Completed Tasks

**Problem:** **PRD 2-06, FR-5** specifies `dispatch_coding(reasoning:)` dispatches "all ready tasks." **PRD 2-06, FR-6** requires each tool to validate preconditions, and the precondition table shows: "Execution in `coding` or `retrying` phase, ready tasks exist."

In the retry flow (PRD 2-09), after `retry_with_context` resets targeted tasks to `pending` and the Conductor calls `dispatch_coding` again, the precondition check is "ready tasks exist." But tasks are `pending` at reset time — they transition to `ready` only after dependency re-evaluation (PRD 2-04, FR-9: "After reset, re-evaluate dependency graph — if all dependencies completed, mark task as ready").

If the Conductor calls `dispatch_coding` before `TaskResetService` has finished re-evaluating dependencies (possible in async execution), the precondition "ready tasks exist" could be `false` momentarily (tasks are `pending`, not `ready` yet), causing the tool to refuse the dispatch. The Conductor would then be stuck — it already called `retry_with_context`, it can't call it again (attempt would increment incorrectly), and `dispatch_coding` is refusing.

More critically: the `dispatch_coding` tool needs to be able to distinguish between:
- "No ready tasks because tasks are still pending after reset" (wait, retry the check)
- "No ready tasks because all tasks are completed or failed" (this is an error state)

The current precondition doesn't make this distinction.

**Potential Solution:** The `dispatch_coding` precondition should check for "ready OR pending (with all dependencies met)" tasks — meaning it proactively runs the dependency re-evaluation if needed, or it waits for `TaskResetService` to complete before `retry_with_context` enqueues `ConductorJob`. The simplest fix: `retry_with_context` should perform the full reset cycle synchronously (reset + dependency re-evaluation) before creating the ConductorDecision and enqueuing the next ConductorJob with `trigger: :retry_ready`. This ensures by the time `dispatch_coding` is called, tasks are already in `ready` state. Document this explicitly in PRD 2-09's `retry_with_context` implementation.
EAS:Agree
---

### O-V2-4: Three-Layer Testing Strategy Is Missing Layer 2 Coverage for ArchitectGate Prompt

**Problem:** The three-layer testing strategy (D-31) is correctly described in the epic overview and PRD 2-06. **PRD 2-06's prompt contract tests** correctly specify 5 Layer 2 scenarios for the Conductor prompt. However, **PRD 2-08** specifies no prompt contract tests (Layer 2) for the `architect_review_prompt.md.liquid` or `qa_score_prompt.md.liquid` templates.

This is a gap: the ArchitectGate prompt is as sensitive to prompt drift as the Conductor prompt. If someone edits `architect_review_prompt.md.liquid` to change the scoring rubric instructions, there is no prompt contract test to catch that the Architect agent still returns a parseable score in the expected format. The same applies to `qa_score_prompt.md.liquid`.

The absence of Layer 2 tests for gate prompts means:
- Prompt edits to either gate template have no regression safety net until the full E2E run (which is slow and may not expose the scoring format issue)
- The VCR-recorded Layer 3 tests for gate evaluation (PRD 2-08's integration tests) are recorded with a specific prompt — if the prompt changes, the cassette is invalid, but there's no lighter-weight Layer 2 test to run first

**Potential Solution:** Add Layer 2 prompt contract tests to PRD 2-08 for both gates. Minimum viable set:
- `test/prompt_contracts/architect_review_prompt_test.rb` (tagged `live_llm: true`):
  - Given a valid task list and DAG → Architect returns a response containing a parseable score (any of the 3 score formats)
  - Given a clearly flawed decomposition (circular dependency, missing test tasks) → Architect score < 90
- `test/prompt_contracts/qa_score_prompt_test.rb` (tagged `live_llm: true`):
  - Given passing code and met acceptance criteria → QA score ≥ 90
  - Given clearly failing code (empty implementation) → QA score < 90

These 4 tests are the behavioral contract for the gate prompts and should run whenever either gate prompt template is modified.
EAS: Agree
---

## Summary Table

| ID | Type | Topic | PRDs Affected | Severity |
|----|------|-------|---------------|----------|
| Q-V2-1 | Question | `retry_with_context` tool signature — `task_ids:` param vs. tool-internal selection | 2-06, 2-09 | **Must resolve before 2-06 implementation** |
| Q-V2-2 | Question | Retrospective 6 categories undefined — no output contract for `retrospective_report` | 2-10 | **Must resolve before 2-10 implementation** |
| Q-V2-3 | Question | ConductorJob idempotency mechanism unspecified — how to prevent duplicate ConductorJobs | 2-06 | **Must resolve before 2-06 implementation** |
| S-V2-1 | Suggestion | `--concurrency <N>` enforcement mechanism underspecified (potential race) | 2-01 | Medium — resolve in implementation plan |
| S-V2-2 | Suggestion | `Artifact.version` auto-increment race condition mitigation should name the strategy | 2-02 | Medium — resolve in implementation plan |
| S-V2-3 | Suggestion | `PromptBuilder.required_context` should be a static manifest, not template parsing | 2-05 | Low — resolve during PRD 2-05 implementation |
| S-V2-4 | Suggestion | Callback registration mechanism underspecified for ConductorJob triggers | 2-06 | Medium — resolve in implementation plan |
| S-V2-5 | Suggestion | Which `workflow_run` is passed to ArchitectGate vs. QAGate is ambiguous | 2-07, 2-08 | Medium — resolve before 2-07 implementation |
| S-V2-6 | Suggestion | `--skip-scoring` interaction with Conductor prompt unaddressed | 2-10 | Low — resolve in 2-10 implementation |
| O-V2-1 | Objection | PRD 2-06 mock gate creates misleading integration tests that need documented handoff | 2-06, 2-07, 2-10 | **Must resolve — affects test architecture** |
| O-V2-2 | Objection | Retry task selection via "file path matching" in LLM prose is brittle — needs structured QA output | 2-09, 2-08, 2-05 | **Must resolve — affects AC-2 verifiability** |
| O-V2-3 | Objection | `dispatch_coding` precondition doesn't handle post-reset `pending` state correctly | 2-06, 2-09 | **Must resolve — potential workflow deadlock** |
| O-V2-4 | Objection | Three-layer testing strategy missing Layer 2 prompt contract tests for gate prompts | 2-08 | **Must resolve — per D-31 testing strategy** |

---

## Closing Assessment

### What Is Ready for Φ7

The following are fully implementation-ready and should proceed directly to Φ7 PRD breakout without further discussion:

- **PRD 2-01 (Parallel Dispatch):** Acceptance criteria are specific and testable. The concurrency concern (S-V2-1) is a suggestion for the implementation plan, not a blocker.
- **PRD 2-02 (Artifact Model):** Data model is complete. The version increment strategy (S-V2-2) is an implementation note improvement, not a design gap.
- **PRD 2-03 (Score Command):** Well-specified. Score parsing patterns are explicit. Exit codes are defined. No blockers.
- **PRD 2-04 (Task Re-Run):** Clean, well-bounded. Dependencies are correct.
- **PRD 2-05 (PromptBuilder):** Solid. The `required_context` suggestion (S-V2-3) is minor. The Liquid choice (D-26) is correctly implemented.
- **PRD 2-07 (QualityGate Base):** Well-specified base class. The `workflow_run` disambiguation (S-V2-5) should be resolved before implementation but doesn't block Φ7 breakout.
- **PRD 2-08 (ArchitectGate + QAGate):** Implementation-ready pending resolution of O-V2-2 (structured QA output) and O-V2-4 (Layer 2 tests). These are scoped additions, not rewrites.

### What Requires Resolution Before Φ7 or Before Implementation

**Three questions require answers before their respective PRDs are implemented:**
- **Q-V2-1** (retry_with_context signature) — before PRD 2-06 starts
- **Q-V2-2** (retrospective 6 categories) — before PRD 2-10 starts  
- **Q-V2-3** (ConductorJob idempotency) — before PRD 2-06 starts

**Three objections require targeted additions to the PRDs:**
- **O-V2-1** — PRD 2-06 needs explicit test lifecycle documentation (permanent vs. temporary scaffolding)
- **O-V2-2** — PRD 2-08/2-09 need either structured QA output mandate in the template or a policy change to always-retry-all
- **O-V2-3** — PRD 2-09/2-06 need explicit sequencing: `retry_with_context` must complete dependency re-evaluation before enqueuing next ConductorJob

### Overall Verdict

**The epic is 85% ready for Φ7.** The architecture is sound, the data model is correct, and the decisions are well-integrated. None of the objections require architectural pivots — all are implementation-scope additions or clarifications. The questions should be resolved in a Φ6 V2 response (likely short — 3 focused answers), and the PRDs should be updated to incorporate the objection solutions before Φ7 PRD breakout begins.

If Eric agrees that the 3 questions are resolvable quickly and the 4 objection solutions are scoped correctly, **Φ7 can begin immediately after Φ6 V2 closes.**
