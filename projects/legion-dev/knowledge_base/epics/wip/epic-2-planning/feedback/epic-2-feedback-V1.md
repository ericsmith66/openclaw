# Epic 2 — Architect Review Feedback V1

**Epic:** Epic 2 — WorkflowEngine & Quality Gates (CLI-First)
**Phase:** Φ5 — Architect Review
**Reviewer:** Architect Agent
**Date:** 2026-03-10
**Document Status:** Epic is at Φ3 (Eric-approved skeleton). PRDs are 2-3 sentence summaries per Φ2 rules. Φ4 full PRD expansion has NOT yet occurred. This review targets architecture and design intent, not missing PRD sections.

---

## Preamble

This is a well-constructed epic. The core Conductor Agent architecture is sound, the data model choices are deliberate and reasoned, and the phased PRD sequence is logical. The decision to replace AASM with an LLM-driven Conductor that calls tool-guarded orchestration actions (D-4, D-6) is the right call for a system designed to evolve through prompt editing rather than code changes. The ConductorDecision audit trail (D-5) is exactly the right solution to the "why did the workflow do that?" problem inherent in LLM-driven orchestration.

The feedback below is organized as required: **Questions** → **Suggestions** → **Objections**. There are 5 questions, 8 suggestions, and 5 objections. All objections include potential solutions.

---

## Questions

**Q-1: Conductor Agent Identity — Which Team Member Plays the Conductor?**

The epic specifies that the Conductor uses the "same agent_desk pipeline as every other agent (assembly, dispatch, tool calling, event persistence)" and that it has a different tool set. But which TeamMembership record is used when ConductorService dispatches the Conductor? Is it the Architect's config (Claude Opus), a new dedicated `conductor` agent config in `.aider-desk/agents/`, or does the ConductorService hard-code a model (e.g., Claude Sonnet for cost efficiency)?

This matters for:
- TeamMembership assembly pipeline selection (which rules and skills load)
- Cost accounting (Conductor runs on every phase transition — the model choice compounds)
- Tool approval config (the Conductor's tools are orchestration tools, not coding tools — a standard agent config's tool approvals would be wrong)
- ConductorDecision's `input_summary` should probably record which model made each decision

Clarification needed before PRD 2-04 expansion.
EAS: A new conductor agent , for convience we would add this to the team, but ultimatly. I see the coordinator outside the scope of a project. It feels like the coordinator is running in a loop. whatching the progression of its tasks , workflows.

---

**Q-2: Heartbeat / Stuck-Task Detection — What Mechanism?**

The risks table mentions "Worker crash = task stays `running` → detect via heartbeat timeout → reset to `pending` for re-dispatch." But:
- What sets the heartbeat? Is it a timestamp on `Task.queued_at` or `Task.started_at`?
- What checks for stale heartbeats? A Solid Queue recurring job? The Conductor on its next dispatch?
- What is the timeout threshold? (Different models have wildly different iteration durations — Qwen3 Coder on a trivial task: ~45s; Claude Opus on a complex task: 10+ minutes)

Without a concrete heartbeat mechanism, the mitigation for the highest-impact risk (partial file edits from a crashed worker) is incomplete. This should be designed explicitly in PRD 2-01 or 2-03.
EAS: See above the coordinator should have a heartbeat.

---

**Q-3: Reasoning Extraction — How Does the Tool See the Conductor's "Pre-Call" Text?**

The spec states: "Reasoning extraction uses the same pattern as score parsing — the Conductor's text before the tool call is captured as the reasoning." But in the agent_desk gem's execution model, the Runner processes tool calls as structured JSON from the LLM response. The "text before the tool call" is the LLM's assistant message content that preceded the tool use block.

- Does the agent_desk Runner currently expose this pre-tool-call assistant text to tool implementations? EAS: I dont know 
- Or does the orchestration tool need to receive it as an explicit parameter (i.e., the Conductor prompt instructs it to call EAS: I dont know  need suggestion `dispatch_decompose(reasoning: "Starting decomposition because...")` with reasoning as a first-class argument)?

If the gem doesn't surface pre-call text to tools, the reasoning capture mechanism needs to either: (a) be built into the Conductor tool interface as an explicit `reasoning:` parameter, or (b) require a gem change. This is a non-trivial implementation question that should be resolved before PRD 2-04 is written.
EAS: Prefer A ( I am guessing thats the path of least resistance )
---

**Q-4: `bin/legion score` Bootstrap Dependency — Artifact Table First or Fallback?**

The PRD table notes that 2-02 (`bin/legion score`) "requires Artifact table from 2-05, or can store as WorkflowRun metadata initially." The dependency graph shows 2-02 depending only on 2-01, with 2-05 depending on 2-04. That means 2-02 is implemented 3 PRDs before the Artifact table exists.

Is the design decision made? Is `bin/legion score` in PRD 2-02 intentionally storing scores in WorkflowRun metadata (a temporary hack), with migration to Artifacts happening in PRD 2-05? Or should 2-02 depend on 2-05 (changing the critical path)? 

The answer affects: (a) whether score data needs a migration when 2-05 arrives, (b) whether `QualityGate.evaluate()` creates Artifacts or WorkflowRun metadata, and (c) whether the score command in 2-02 is the "real" implementation or a provisional one.
EAS : We should reorder the PRD's ( at this point we can renumber them to suite our order) 

---

**Q-5: Solid Queue — Worker Process Management for Development**

The epic specifies Solid Queue with a `threads: 3` configuration. In development on a single machine:
- How does the developer start the Solid Queue worker? Is it added to the Procfile? Is it part of `bin/dev`? EAS:Yes
- The Conductor is described as "short-lived" — does it run synchronously in the web process when dispatched by ConductorService, or does it also run as a Solid Queue job? EAS: Need a suggestion
- If `bin/legion implement` blocks the CLI waiting for parallel tasks to complete, how does the CLI process know when all TaskDispatchJobs are done? Does it poll `WorkflowExecution.phase`? Use an ActiveRecord callback? The "completion detection" mechanism isn't specified. EAS : Need a suggestion 

These are implementation questions, but they affect PRD 2-01's scope significantly.

---

## Suggestions

**S-1: ConductorDecision — Add `duration_ms` Field**

The ConductorDecision model captures `from_phase`, `to_phase`, `tool_called`, `reasoning`, `input_summary`, and `attempt`. Consider adding a `duration_ms` integer field (time from Conductor dispatch to tool execution completion). This enables:
- Identifying which phase transitions are adding latency
- Confirming the "2-5s per decision" latency claim in the risks table
- Retrospective analysis of Conductor overhead per phase

Cost: trivial (one integer column). Value: high for performance monitoring. `Time.current` at dispatch start and tool completion is straightforward to capture.
EAS : Agree , maybe even tokens and cost 
---

**S-2: `artifact_type` — Separate `architect_review` from `score_report`**

The current `artifact_type` enum has `score_report` but does not distinguish between ArchitectGate output (plan review) and QAGate output (code quality scoring). Both are score artifacts, but they:
- Use different scoring rubrics (Φ9 vs Φ11 in RULES.md)
- Come from different agents (Architect vs QA)
- Have different retry implications (plan review failure → back to decomposition; QA failure → retry with context)
- Need to be queried independently ("show me all architect plan reviews")

Suggestion: Add `architect_review` as a distinct `artifact_type`, or add an `agent_role` field to the Artifact model (values: `architect`, `qa`, `conductor`, `rails_lead`). The `score` field is present on Artifact already — `phase` partially disambiguates, but the enum is cleaner.
EAS:AGREE
---

**S-3: WorkflowExecution — Add `prd_content_hash` to Metadata with PRD Snapshot**

`WorkflowExecution.metadata` stores a "PRD content hash" per the spec. Consider making this explicit: store the full PRD content (or a SHA-256 hash with a separate text column) alongside `prd_path`. Rationale:

- PRD files on the filesystem can be edited between `implement` runs. If a PRD is modified mid-retry, the second attempt is working against different requirements than the first — a subtle and hard-to-debug inconsistency.
- A stored hash lets the system detect "PRD changed since last run" and warn (or fail-fast with a clear error).
- In Epic 3, the Conductor will read previous retrospective reports for the same PRD — a content hash is safer than a path comparison (PRDs can be renamed/moved).

Suggested field: `prd_snapshot text` (full content captured at execution start) rather than just a hash. Hash for comparison, snapshot for retrospective analysis.
EAS:Agree
---

**S-4: `--dry-run` for `bin/legion implement` — Specify Output Format**

The `--dry-run` flag is listed for `bin/legion implement` ("Show plan without executing") but the output format isn't specified. Suggestion: dry-run should output:
1. The resolved PRD path and content hash
2. The Conductor prompt that would be sent (rendered from conductor_prompt.md.erb with current execution state)
3. The tool call sequence the Conductor is expected to make (based on current state: "would call dispatch_decompose")
4. Advisory lock status ("project lock available / locked by execution #N")

This gives the developer a way to validate the Conductor prompt before committing LLM tokens. It's also a testable output format for integration tests.
EAS:Agree
---

**S-5: Retrospective Phase — Cap Data Volume Fed to Conductor**

The `run_retrospective` tool gives the Conductor access to "All ConductorDecisions," "All task results," "All QA score reports," "All WorkflowEvents," "Retry history," "Agent configs," and "Previous retrospective reports." On a complex PRD with many tasks, multiple retries, and hundreds of WorkflowEvents, the combined context could easily exceed a model's context window or produce a very expensive LLM call.

Suggestion: Define explicit context limits for retrospective input:
- ConductorDecisions: all (typically 5-12 per execution — small)
- Task results: all (typically 5-15 tasks — small)
- QA score reports: all (typically 1-3 — small)
- WorkflowEvents: **summarized only** — don't pass raw event log (potentially thousands of events). Pass aggregate stats: total events, tool call counts, budget warning counts, handoff counts.
- Retry artifacts: all (typically 0-2 — small)
- Previous retrospective reports: **last 3 only**, not all-time history

This keeps retrospective context manageable and costs predictable. The detailed WorkflowEvent log is in the DB for post-hoc querying; the Conductor doesn't need raw events to produce useful recommendations.
EAS: We need experiance before we build it .
---

**S-6: Parallel File Conflict Validation — Make It Automatic, Not a Warning**

The risks table says: "Add validation: warn if two parallel-eligible tasks reference the same file paths." The word "warn" suggests this is advisory. For the parallel dispatch architecture, a shared-file conflict isn't just a warning — it's a correctness bug that can produce unpredictable merge conflicts in the project's Git working tree.

Suggestion: Elevate this from a warning to a blocking validation in `TaskDispatchJob` (or in `PlanExecutionService` before enqueuing). If two tasks in the same parallel wave reference the same file paths, the second task should be held in `pending` state until the first completes. This is analogous to a database row lock but at the file level. The DAG already handles explicit dependencies — this would catch implicit file-level conflicts not expressed in the DAG.
EAS: Agree

---

**S-7: PromptBuilder — Include a Validation Step for Template Rendering**

The PromptBuilder service renders ERB templates with injected context. ERB templates can fail silently (rendering nil for a missing variable, or raising NoMethodError on nil context). Suggestion: `PromptBuilder.build` should:
1. Validate that all required context keys are present before rendering (raise `ArgumentError` with specific missing keys, not an obscure `nil` error mid-template)
2. Have a `PromptBuilder.validate(phase:, context:)` method that checks context completeness without rendering, usable in tests

This is a quality-of-life improvement for debugging but also makes PromptBuilder unit tests significantly cleaner: test the validation separately from the rendering.
EAS: should this be liquid ( seems like prompts should be liquide based not ERB . Suggestions 
---

**S-8: ConductorService Naming — Consider `WorkflowEngine` as the Outer Service**

The spec mentions "ConductorService" for dispatching the Conductor agent. The epic is named "WorkflowEngine & Quality Gates." Consider introducing `WorkflowEngine` as the public-facing service that owns the `implement` loop (creates WorkflowExecution, acquires advisory lock, dispatches Conductor, monitors completion, handles exit codes). `ConductorService` would then be the inner service responsible for a single Conductor agent dispatch.

This layering avoids having `bin/legion implement` call `ConductorService` directly, and gives Epic 3 a natural extension point (`WorkflowEngine` gains new capabilities without the CLI needing to change). It also matches the "WorkflowEngine" naming in the epic title and the phase diagram.
EAS:Agree
---

## Objections

**O-1: Artifact Model Dependency Creates an Unjustified PRD Sequence Inversion**

**Problem:** The current PRD sequence places Artifact (2-05) *after* Conductor Agent (2-04). But `QualityGate.evaluate()` (2-07), retry context storage (2-09), and retrospective_report (2-10) all require Artifacts. More critically, `bin/legion score` (2-02) acknowledges it "can store as WorkflowRun metadata initially" as a workaround for Artifact not existing yet. This means:
- PRD 2-02 implements a provisional score storage mechanism
- PRD 2-05 implements the real one
- PRD 2-07 must backfill or migrate the 2-02 provisional implementation
- Three PRDs are tangled around one model's timing

This creates technical debt from day one: two score storage paths, a migration step between them, and any tests written in 2-02 testing the provisional mechanism will need updating in 2-07.

**Potential Solution:** Move PRD 2-05 (Artifact Model) before PRD 2-02 (Score Command). The revised sequence:
```
2-01 (Parallel Dispatch)
  ├── 2-05 (Artifact Model)  ← moved here; depends only on 2-01 for WorkflowRun FK
  ├── 2-02 (Score Command)   ← now writes real Artifacts from day one
  └── 2-03 (Task Re-Run)
```

PRD 2-05 (Artifact Model) has no dependency on the Conductor — it only needs WorkflowRun and WorkflowExecution FKs. WorkflowExecution doesn't have to be fully implemented — just the table (a stub migration). Or, alternatively, Artifact's `workflow_execution_id` FK can be nullable and added later. The Artifact model is a pure data model with no behavioral dependencies on the Conductor. Moving it earlier eliminates the provisional storage path entirely.
EAS: Reorder as necessary

---

**O-2: Short-Lived Conductor Dispatch Doesn't Explain How Phase Callbacks Reach It**

**Problem:** The spec describes the Conductor as "short-lived" — dispatched at key moments, makes one decision, exits. The trigger table lists 5 triggers: `bin/legion implement` invoked, decomposition completes, all tasks in terminal state, QA scoring completes, tool error occurs. Each trigger is described as a "callback" from the completing service.

But if the Conductor exits after one decision, how does the *next* trigger dispatch a *new* Conductor with updated state? There are two models here and the spec mixes them without resolving the choice:

**Model A (Event-Driven):** Each phase transition installs a callback (via `OrchestratorHooksService` or a new hook point). When decomposition completes, the callback fires and dispatches a new Conductor instance. The Conductor sees fresh state, makes one decision (`dispatch_coding`), creates a ConductorDecision, and exits.

**Model B (Polling/Blocking):** `bin/legion implement` blocks in a polling loop checking `WorkflowExecution.phase` until completion or escalation. The CLI is the "long-lived loop"; the Conductor is called by the CLI each time a phase completes.

These models have very different implementation implications. Model A is cleaner and more event-driven, but requires the hooks/callback system from OrchestratorHooksService to be extended to fire Conductor dispatches. Model B is simpler but means the CLI process must stay alive for the entire implement run (could be hours for a complex PRD), which is problematic for scripting and CI environments.

**Potential Solution:** Explicitly choose Model A (event-driven callbacks) and specify it in PRD 2-04. Define a new `ConductorCallbackService` (or extend `OrchestratorHooksService`) that: (a) registers a post-completion hook when a phase's WorkflowRuns finish, (b) checks if the WorkflowExecution needs a new Conductor dispatch, (c) dispatches the Conductor as a Solid Queue job (`ConductorJob`). The CLI's `implement` command then either polls `WorkflowExecution.status` with a progress indicator, or uses `ActionCable`/`Solid Cable` to receive a completion signal. This is the correct architecture for a non-blocking background orchestration system.
EAS: Need a suggestion and to better understand the implications 
---

**O-3: `ArchitectGate` in the Automated Loop Mismatches Its Human-Workflow Role**

**Problem:** The epic introduces `ArchitectGate` (plan review ≥ 90) as part of the automated QualityGate framework. But the RULES.md Φ9 specifies: "★ GATE: Plan must be approved before Φ10 proceeds... If plan is fundamentally flawed → return to Coding Agent (Φ8) with specific issues." In RULES.md, the Architect Gate is a **human-facing gate** where the Architect Agent produces a scored review that a human reads and approves before implementation begins.

In Epic 2's automated loop, `ArchitectGate` appears to be an automated gate in the same loop as `QAGate`. But there's a fundamental mismatch:
- The QAGate can auto-retry (re-run the coding agent with more context) because the failure is *fixable by the coding agent*
- The ArchitectGate's failure (plan score < 90) means the *decomposition was wrong* — the fix is to re-decompose, not to retry coding. But re-decomposition in an automated loop could erase work already done and is much more disruptive than a code retry
- Furthermore, the automated Conductor prompt doesn't show an ArchitectGate step in the workflow rules (rules 1-8 only mention QA scoring, not architect review)
- The PRD table says ArchitectGate is "integration with WorkflowEngine phase transitions" but the phase diagram has no explicit architect_review phase

It's unclear whether ArchitectGate is: (a) part of the automated `implement` loop (before coding begins), (b) a standalone gate used only by `bin/legion score` with `--agent architect`, or (c) intentionally deferred to the manual RULES.md workflow and excluded from Epic 2's automated loop.

**Potential Solution:** Clarify ArchitectGate's role explicitly in the epic. Recommended approach: **ArchitectGate belongs in the `implement` loop between decompose and code.** The Conductor should call `dispatch_architect_review` after decomposition, creating an `architect_review` phase. If ArchitectGate fails (score < 90), the Conductor calls `dispatch_decompose` again (re-decompose with architect feedback). This makes the gate meaningful in the automated loop and aligns with RULES.md Φ9. The existing Conductor prompt rules need a new rule: "2b. After decomposition, call dispatch_architect_review. If review score ≥ 90, proceed to dispatch_coding. If < 90 and attempt < max_retries, call dispatch_decompose with architect feedback." This also means the `WorkflowExecution.phase` enum needs an `architect_reviewing` value — and it's likely already needed for PRD 2-08 anyway. If the decision is to intentionally **exclude** ArchitectGate from the automated loop (keep it manual-only), document this explicitly as a design decision (D-17) and defer ArchitectGate to Epic 3.
EAS: If the is the architect approving the PRD plan ? then its part of the overall scoring mechanism . but we should discuss how this fits into the current architecture. If its a differnt phase we still need to discuss
---

**O-4: The Conductor's Retry Scope — Whole-PRD vs. Task-Level is Ambiguous**

**Problem:** The retry logic description contains a conflation between two different retry scopes that isn't resolved:

**The spec says (Quality Gate section):** "If score < threshold and attempt < max_retries: call `retry_with_context`" — the retry counter is on `WorkflowExecution.attempt` (a whole-PRD counter).

**The spec says (Retry Logic section):** "Select tasks to retry: Tasks whose output was cited in QA feedback (via file path matching), or all tasks if unclear" — the retry targets specific tasks, not the whole PRD.

**But `WorkflowExecution.attempt` is PRD-level:** it increments once per QA cycle, not once per task. Meanwhile, `Task.retry_count` is task-level. These are different concepts at different granularities being used in the same counter.

The confusion compounds in the failure condition: "After max_retries exhausted: WorkflowExecution status → escalated." But what if only 1 of 8 tasks keeps failing and 7 are fine? The whole execution is escalated because of one persistently-failing task. Should max_retries be per-task or per-execution?

**Potential Solution:** Make the retry semantics explicit in PRD 2-09 by defining two distinct limits:
- `WorkflowExecution.attempt` (max 3): The number of complete CODE→QA→RETRY cycles. This is the outer loop limit. After 3 full cycles, escalate regardless.
- `Task.retry_count` (max N, configurable): The number of times a specific task has been reset to pending. If a single task hits its retry limit, the task is marked `failed` (not the whole execution). The Conductor must then decide: can it proceed without this task (if other tasks unblock)? Or must it escalate the execution?

This is a design decision that PRD 2-09 needs to make explicit. The current spec implies the simpler model (execution-level limit only) but the task-level tracking infrastructure (`Task.retry_count`) suggests the more nuanced model was intended.
EAS: Agree two disnct limits 

---

**O-5: Testing Strategy Has No LLM Behavior Isolation Plan**

**Problem:** The testing strategy lists integration tests for: "Conductor Agent full cycle: decompose → code → score → retrospective → complete — verify ConductorDecision trail (VCR-recorded)" and multiple other Conductor-related integration tests. VCR cassette recording is the right tool for HTTP-level isolation of SmartProxy interactions. However, the Conductor introduces a qualitatively different testing challenge compared to Epic 1:

**In Epic 1**, VCR cassettes replay deterministic tool call sequences (decompose PRD → returns task list with specific structure). The test verifies the output structure.

**In Epic 2**, the Conductor's *decisions* are driven by LLM reasoning. The VCR cassette records the HTTP responses (including the Conductor's tool call decisions), but:
- If the conductor_prompt.md.erb is edited (the whole point of the flexible architecture), all Conductor VCR cassettes are potentially invalidated because the LLM would reason differently
- The cassettes encode which tool the Conductor decided to call — but this is the Conductor's judgment, not a deterministic parse. A cassette that records "Conductor called retry_with_context for score 87" will fail if the prompt changes enough that the live Conductor would now call `escalate` for the same score
- Integration tests that rely on VCR-recorded Conductor decisions will create false confidence: the cassette always "passes" because it replays the recorded decision, not because the current prompt produces the correct decision

**Potential Solution:** Adopt a two-layer testing strategy for Conductor behavior:

1. **Orchestration tool unit tests** (no LLM, no VCR): Test that each tool's precondition guard works correctly — `mark_completed` refuses score 45, `dispatch_coding` refuses if no ready tasks exist, etc. This is fully deterministic and tests the safety layer.

2. **Conductor prompt integration tests** (live LLM, but scope-limited): A small set of "prompt contract" tests that are explicitly marked as live-LLM tests (no VCR), run against a real model with defined inputs, and verify that the Conductor produces an expected tool call for a given scenario. These tests document the *behavioral contract* of the prompt. They're slow (real LLM calls) but run only when the prompt is changed, acting as a prompt regression suite.

3. **Full cycle integration tests** (VCR): These test the entire implement loop end-to-end — but they record the *service layer* behavior (WorkflowRun created, ConductorDecision persisted, Artifact created) rather than the Conductor's specific reasoning. The assertion is: "given this execution state, a ConductorDecision was created with a valid `to_phase`," not "given this execution state, the Conductor said exactly these words."

This separation ensures the test suite is robust to prompt edits while still providing meaningful integration coverage. Without it, prompt evolution will constantly invalidate the VCR cassette library.
EAS Agree 
---

## Summary

| ID | Type | Topic | Severity |
|----|------|-------|----------|
| Q-1 | Question | Conductor Agent identity / TeamMembership | Needs answer before PRD 2-04 |
| Q-2 | Question | Heartbeat / stuck-task detection mechanism | Needs answer before PRD 2-01/2-03 |
| Q-3 | Question | Reasoning extraction from pre-tool-call text | Needs answer before PRD 2-04 |
| Q-4 | Question | `bin/legion score` Artifact vs. WorkflowRun metadata decision | Needs answer before PRD 2-02 |
| Q-5 | Question | Solid Queue worker startup + CLI completion detection | Needs answer before PRD 2-01 |
| S-1 | Suggestion | Add `duration_ms` to ConductorDecision | Low effort, high value |
| S-2 | Suggestion | Distinguish `architect_review` artifact type from `score_report` | Clarifies query semantics |
| S-3 | Suggestion | Store PRD content snapshot on WorkflowExecution | Prevents PRD-drift bugs |
| S-4 | Suggestion | Specify `--dry-run` output format | Testability + developer UX |
| S-5 | Suggestion | Cap data volume fed to Conductor in retrospective phase | Cost/context control |
| S-6 | Suggestion | Elevate parallel file conflict from warning to blocking validation | Correctness not advisory |
| S-7 | Suggestion | Add context validation to PromptBuilder | Debuggability |
| S-8 | Suggestion | Introduce `WorkflowEngine` service as public outer layer | Clean layering for Epic 3 |
| O-1 | Objection | Artifact model timing creates provisional storage path | Resolve before Φ4 |
| O-2 | Objection | Short-lived Conductor dispatch model ambiguous (event-driven vs polling) | Resolve before Φ4 |
| O-3 | Objection | ArchitectGate role in automated loop is unclear / mismatched | Resolve before Φ4 |
| O-4 | Objection | Retry scope conflates execution-level and task-level counters | Resolve in PRD 2-09 |
| O-5 | Objection | Testing strategy will create VCR cassettes tied to Conductor reasoning | Resolve before Φ8 |

---

## Closing Assessment

The foundational decisions in this epic are architecturally sound: the Conductor Agent over AASM, ConductorDecision as the audit trail, tool-guarded orchestration, and the retrospective phase as a closed-loop improvement mechanism. The parallel execution via Solid Queue is well-reasoned and the advisory lock strategy is appropriate for the PostgreSQL-only stack.

The five objections are all resolvable within the existing design philosophy — none require architectural pivots. O-1 (Artifact timing) and O-2 (Conductor dispatch model) should be resolved before Φ4 PRD expansion begins, as they affect the scope of PRDs 2-01 through 2-05 significantly. O-3 (ArchitectGate) requires a yes/no design decision from Eric. O-4 and O-5 can be addressed during PRD expansion.

The Conductor approach is the right foundation for the stated goal: a WorkflowEngine that evolves through prompt editing rather than code changes. Build it well here, and Epic 3 additions are genuinely just prompt lines and new tools.
