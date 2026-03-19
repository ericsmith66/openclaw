# Epic 2 — Feedback Response V1

**Epic:** Epic 2 — WorkflowEngine & Quality Gates (CLI-First)
**Phase:** Φ6 — Feedback Response
**Respondents:** Eric Smith + High-Reasoning AI
**Date:** 2026-03-10
**Input:** `epic-2-feedback-V1.md` (Architect Review, 5 Questions, 8 Suggestions, 5 Objections)

---

## Format

Each item reproduces the Architect's point (abbreviated), followed by Eric's inline comment (prefixed `EAS:`), then the synthesized response and locked-in decision.

---

## Questions

### Q-1: Conductor Agent Identity — Which Team Member Plays the Conductor?

**Architect asked:** Which TeamMembership record is used for the Conductor? The Architect's config, a new dedicated config, or a hard-coded model? Affects assembly pipeline selection, cost accounting, tool approvals, and which model makes each decision.

**EAS:** A new conductor agent, for convenience we would add this to the team, but ultimately I see the coordinator outside the scope of a project. It feels like the coordinator is running in a loop, watching the progression of its tasks and workflows.

**Response:**

The Conductor is a **new, dedicated agent identity** — a `conductor` entry in `.aider-desk/agents/` with its own model config, tool approvals (orchestration tools only), and rules. For Epic 2, it lives inside the project's team like any other agent (imported via `TeamImportService`). This keeps it compatible with the existing assembly pipeline.

However, Eric's long-term vision is important to capture: the Conductor is conceptually **above** a single project. In Epic 3+, the Conductor could manage multiple projects or operate at a workspace level. Epic 2 doesn't need to solve this — but the design should not hard-couple the Conductor to a single project's TeamMembership.

**Practical design for Epic 2:**
- New agent config: `.aider-desk/agents/conductor.yml` with model (recommend Claude Sonnet for cost efficiency — Conductor decisions are lightweight routing, not creative work), orchestration-only tool approvals, and conductor-specific rules
- `TeamImportService` imports it alongside other agents
- `ConductorDecision.input_summary` includes `"model": "claude-sonnet-4-..."` to record which model made each decision
- `ConductorService` resolves the Conductor's TeamMembership by role name (`conductor`), not by hard-coded model

**Decision locked: D-17 — Conductor is a new dedicated agent config (`conductor.yml`) imported via TeamImportService. Model choice recorded in ConductorDecision.input_summary. Long-term Conductor-above-project vision noted for Epic 3+ but not designed in Epic 2.**

---

### Q-2: Heartbeat / Stuck-Task Detection — What Mechanism?

**Architect asked:** What sets the heartbeat? What checks for stale heartbeats? What's the timeout threshold?

**EAS:** See above — the Conductor should have a heartbeat.

**Response:**

The Conductor's loop-watching nature (from Q-1) naturally solves this. The Conductor is re-dispatched after phase transitions and can be re-dispatched on a **periodic schedule** to check for stuck tasks. This makes the Conductor the heartbeat mechanism itself:

**Heartbeat design:**
1. **`Task.started_at`** is set when `TaskDispatchJob#perform` begins execution. `Task.queued_at` is set when the job is enqueued.
2. **`ConductorHeartbeatJob`** — a Solid Queue recurring job (every 60 seconds) that:
   - Finds all `running` WorkflowExecutions
   - For each, checks for tasks that have been `running` longer than the **stale threshold**
   - Stale threshold: configurable per execution, default **15 minutes** (accommodates Claude Opus on complex tasks; Qwen3 tasks that take >15 minutes are almost certainly stuck)
   - Stale tasks are reset to `pending` (incrementing `retry_count`, storing "Stale task detected — exceeded heartbeat timeout" in `last_error`)
   - Dispatches the Conductor to re-evaluate (the Conductor sees the reset tasks and decides the next action)
3. **Threshold is configurable:** `WorkflowExecution.metadata["heartbeat_timeout_minutes"]` with default 15. Can override via `--heartbeat-timeout` on `bin/legion implement`.

This approach uses the Conductor as both the decision-maker AND the watchdog. The recurring job is just the trigger; the Conductor makes the actual decisions about what to do with stale tasks.

**Decision locked: D-18 — ConductorHeartbeatJob (Solid Queue recurring, 60s interval) detects stale tasks via Task.started_at + configurable timeout (default 15 min). Stale tasks reset to pending. Conductor re-dispatched to decide next action.**

---

### Q-3: Reasoning Extraction — How Does the Tool See the Conductor's "Pre-Call" Text?

**Architect asked:** Does agent_desk expose pre-tool-call assistant text to tools? Or does the tool need an explicit `reasoning:` parameter?

**EAS:** I don't know if the gem exposes it. Prefer A (explicit reasoning parameter) — guessing that's the path of least resistance.

**Response:**

**Option A adopted: all orchestration tools accept a `reasoning:` string parameter.** The Conductor prompt's "Decision Format" section already instructs it to explain reasoning before calling a tool. With option A, we formalize this: the prompt instructs the Conductor to pass its reasoning as a tool argument:

```
Before calling any tool, include your reasoning as the `reasoning` parameter:
- dispatch_decompose(reasoning: "Starting implementation because...")
- retry_with_context(reasoning: "Score 87 < 90, attempt 1/3, retrying tasks #3 and #5 because...")
```

**Why this is the right call:**
- Zero gem changes required — tools receive reasoning as a standard parameter
- Reasoning is always captured (it's a required field, not a parsing heuristic)
- If the Conductor omits reasoning, the tool can default to `"No reasoning provided"` rather than silently having a null audit trail
- Works with any LLM provider — no dependency on message structure or pre-tool-call text extraction

**Decision locked: D-19 — All orchestration tools accept a required `reasoning:` string parameter. Conductor prompt instructs LLM to always include reasoning. No gem changes needed.**

---

### Q-4: `bin/legion score` Bootstrap Dependency — Artifact Table First or Fallback?

**Architect asked:** Is score storage in WorkflowRun metadata a temporary hack, or should we reorder PRDs?

**EAS:** We should reorder the PRDs (at this point we can renumber them to suit our order).

**Response:**

Accepted — see **O-1 response** below for the full reordering. The Artifact model moves before the Score Command, eliminating the provisional storage path entirely. PRDs will be renumbered during Φ4 expansion to reflect the new sequence.

**Decision locked: PRDs renumbered per O-1 response. No provisional score storage — Artifact is available from the start.**

---

### Q-5: Solid Queue — Worker Process Management for Development

**Architect asked:** How does the developer start Solid Queue? Does the Conductor run synchronously or as a job? How does the CLI detect completion?

**EAS:** Yes (Procfile/bin/dev). Need suggestions for Conductor sync/async and completion detection.

**Response:**

**Worker startup:** Solid Queue worker is added to `Procfile.dev` and starts via `bin/dev`. This is standard Rails 8 convention:

```
# Procfile.dev
web: bin/rails server
worker: bundle exec rake solid_queue:start
```

**Conductor dispatch model — Recommendation: Hybrid (Event-Driven Background + CLI Polling):**

This also addresses **O-2** (the Architect's objection about dispatch model ambiguity). Here's the concrete recommendation:

1. **The Conductor runs as a Solid Queue job (`ConductorJob`)** — not synchronously in the web/CLI process. When a trigger fires (decomposition completes, all tasks done, QA scoring done), a `ConductorJob` is enqueued. The job loads the WorkflowExecution, assembles the Conductor agent, dispatches it, and the Conductor makes one decision (one tool call).

2. **Triggers are event-driven callbacks via `OrchestratorHooksService`:**
   - `TaskDispatchJob` completion → checks if all tasks in terminal state → if yes, enqueues `ConductorJob`
   - `DecompositionService` completion → enqueues `ConductorJob`
   - `DispatchService` completion for QA scoring run → enqueues `ConductorJob`
   - This is Model A from the Architect's analysis — event-driven, not polling

3. **CLI completion detection — polling with progress output:**
   - `bin/legion implement` creates the WorkflowExecution, enqueues the first `ConductorJob`, then enters a **polling loop** (every 2 seconds) checking `WorkflowExecution.reload.status`
   - The polling loop prints progress as phases change (phase transitions are visible in real-time)
   - When `status` reaches `completed`, `failed`, or `escalated`, the CLI exits with the appropriate code
   - This is simple, reliable, and works in CI environments (no ActionCable/WebSocket dependency)
   - The CLI process is lightweight (just polling a DB column) — it's fine to keep alive for the full run

**Why hybrid:** The actual work (Conductor decisions, task dispatch, scoring) all happens in Solid Queue background jobs — this is non-blocking and event-driven. The CLI is just a thin progress monitor. If the CLI is killed, the workflow continues in the background (the Conductor is driven by callbacks, not by the CLI). The CLI can reconnect later: `bin/legion status --execution <id>`.

**Decision locked: D-20 — Conductor runs as ConductorJob (Solid Queue). Triggers are event-driven callbacks (OrchestratorHooksService). CLI polls WorkflowExecution.status every 2s with progress output. Workflow continues in background if CLI disconnects. Solid Queue started via Procfile.dev.**

---

## Suggestions

### S-1: ConductorDecision — Add `duration_ms` Field

**Architect suggested:** Add `duration_ms` integer field for performance monitoring.

**EAS:** Agree, maybe even tokens and cost.

**Response:** Accepted and expanded. ConductorDecision gains three fields:

| Field | Type | Notes |
|-------|------|-------|
| `duration_ms` | integer | Time from Conductor dispatch to tool execution completion |
| `tokens_used` | integer | Total tokens consumed by this Conductor dispatch (prompt + completion) |
| `estimated_cost` | decimal(10,6) | Estimated cost in USD for this dispatch |

These are populated from the agent_desk Runner's response metadata (token counts are available in LLM API responses). Cost is estimated from model pricing tables stored in config.

**Decision locked: D-21 — ConductorDecision includes duration_ms, tokens_used, estimated_cost for full performance and cost observability.**

---

### S-2: `artifact_type` — Separate `architect_review` from `score_report`

**Architect suggested:** Add `architect_review` as a distinct artifact type or add an `agent_role` field.

**EAS:** Agree.

**Response:** Accepted. `architect_review` added as a distinct `artifact_type` enum value. The full enum becomes:

`plan`, `code_output`, `score_report`, `architect_review`, `review_feedback`, `retry_context`, `retrospective_report`

This is cleaner than adding an `agent_role` field — the artifact type itself disambiguates. Queries like `Artifact.where(artifact_type: :architect_review)` are self-explanatory.

**Decision locked: D-22 — `architect_review` is a distinct artifact_type. No separate agent_role field needed.**

---

### S-3: WorkflowExecution — Add `prd_content_hash` to Metadata with PRD Snapshot

**Architect suggested:** Store full PRD content or SHA-256 hash alongside `prd_path` to detect PRD drift.

**EAS:** Agree.

**Response:** Accepted. WorkflowExecution gains:

| Field | Type | Notes |
|-------|------|-------|
| `prd_snapshot` | text | Full PRD content captured at execution start |
| `prd_content_hash` | string | SHA-256 of PRD content for quick comparison |

At execution start, `WorkflowEngine` reads the PRD file, stores both fields. On any subsequent access (retry, re-scoring), the system can compare the current file hash against the stored hash and warn if the PRD has been modified mid-execution.

**Decision locked: D-23 — WorkflowExecution stores prd_snapshot (full text) and prd_content_hash (SHA-256) at creation time. PRD drift detection available for retries.**

---

### S-4: `--dry-run` for `bin/legion implement` — Specify Output Format

**Architect suggested:** Define what dry-run outputs: PRD path + hash, Conductor prompt, expected first tool call, advisory lock status.

**EAS:** Agree.

**Response:** Accepted as specified. `--dry-run` outputs:

1. Resolved PRD path and content hash
2. Rendered Conductor prompt (from `conductor_prompt.md.erb` with initial execution state)
3. Expected first tool call based on current state (e.g., "would call dispatch_decompose")
4. Advisory lock status ("lock available" / "locked by execution #N")
5. Concurrency mode ("parallel, concurrency: 3" / "sequential")

Output is human-readable by default. Add `--dry-run --format json` for machine-parseable output (useful for integration tests).

**Decision locked: D-24 — --dry-run output format specified with 5 sections. JSON format available via --format flag.**

---

### S-5: Retrospective Phase — Cap Data Volume Fed to Conductor

**Architect suggested:** Define explicit context limits for retrospective input to control cost and context window.

**EAS:** We need experience before we build it.

**Response:** Deferred to implementation time. The Architect's concern is valid — unbounded context for retrospective could be expensive. But we don't yet know the actual data volumes from real runs. The recommendation:

- **Epic 2 implementation:** Start without explicit caps. Build the retrospective and observe real data volumes in E2E testing.
- **If context exceeds 80% of model window during testing:** Implement the Architect's suggested caps (summarize WorkflowEvents, limit previous retrospectives to last 3).
- **Document as a known design consideration** in PRD 2-10 so the implementor is aware.

This avoids over-engineering a solution for a problem we haven't measured yet, while ensuring the team knows to watch for it.

**Decision: Deferred — caps not designed upfront. PRD 2-10 documents the concern. Implementation team monitors actual data volumes and adds caps if needed.**

---

### S-6: Parallel File Conflict Validation — Make It Automatic, Not a Warning

**Architect suggested:** Elevate file conflict detection from warning to blocking validation.

**EAS:** Agree.

**Response:** Accepted. File conflict detection becomes a **blocking precondition** in the parallel dispatch path:

- Before enqueuing a parallel wave, `PlanExecutionService` (or `WorkflowEngine`) checks if any two ready tasks reference overlapping file paths
- If overlap detected: the conflicting tasks are serialized — one dispatches now, the other waits for the first to complete before dispatching
- This is a file-level dependency that supplements the explicit DAG dependencies from decomposition
- Log the serialization decision: "Tasks #3 and #5 both reference `app/models/user.rb` — serializing to prevent file conflict"

**Decision locked: D-25 — Parallel file conflict is a blocking validation, not a warning. Conflicting tasks are automatically serialized. Decision logged for transparency.**

---

### S-7: PromptBuilder — Include a Validation Step for Template Rendering

**Architect suggested:** Add context validation before rendering to catch missing variables early.

**EAS:** Should this be Liquid (seems like prompts should be Liquid-based, not ERB). Need suggestions.

**Response:** This is a good question that affects the template engine choice for `PromptBuilder`. Here's the analysis:

**ERB (current approach in Epic spec):**
- ✅ Already used in Rails views, no additional dependency
- ✅ Full Ruby power — can call methods, iterate, conditionals
- ❌ Full Ruby power — templates can execute arbitrary code, which is a security concern if templates ever become user-editable
- ❌ Fails silently on nil (renders empty string for `<%= nil_var %>`)
- ❌ Error messages are cryptic (`undefined method 'foo' for nil:NilClass` with a line number in the template)

**Liquid:**
- ✅ Sandboxed — templates cannot execute arbitrary code (safe for user-editable prompts in Epic 4+)
- ✅ Explicit variable access — `{{ variable }}` raises a clear error if variable is undefined (when strict mode is enabled)
- ✅ Battle-tested for templating (Shopify, Jekyll, many prompt engineering tools use it)
- ✅ Filters for common transforms: `{{ content | truncate: 2000 }}`, `{{ score | divided_by: 100.0 }}`
- ✅ Strict mode (`Liquid::Template.error_mode = :strict`) catches typos and missing variables at render time
- ❌ Additional gem dependency (`liquid` gem)
- ❌ Less powerful than ERB — no arbitrary Ruby (but that's the point for prompts)
- ❌ Team must learn Liquid syntax (minor — it's simpler than ERB)

**Recommendation: Use Liquid for prompt templates.** The arguments are:

1. **Prompts are data, not code.** The Conductor prompt is the workflow engine — it should be safe to edit without fear of breaking Ruby. ERB templates can accidentally call methods that don't exist in the rendering context, producing runtime crashes. Liquid templates fail predictably.

2. **Prompt templates will become user-editable.** In Epic 4+, users may customize prompts. Liquid's sandboxing prevents a prompt template from running `system("rm -rf /")`. ERB has no such protection.

3. **Strict mode solves the Architect's validation concern.** `Liquid::Template.error_mode = :strict` raises on undefined variables — which is exactly the validation step the Architect suggested. No separate `PromptBuilder.validate` method needed; the render itself validates.

4. **Filters are natural for prompt engineering.** `{{ context | truncate: 4000 }}` to cap context length, `{{ score | default: "not yet scored" }}` for optional values — these are first-class Liquid features, not hacks.

**Implementation:**
- Add `gem 'liquid'` to Gemfile
- `PromptBuilder.build(phase:, context:)` renders Liquid templates with strict mode
- Template files use `.md.liquid` extension (e.g., `conductor_prompt.md.liquid`)
- Context is passed as a flat hash (Liquid doesn't support arbitrary Ruby objects — this is a feature, forcing explicit context preparation)

**Decision locked: D-26 — Prompt templates use Liquid (not ERB) for sandboxing, strict variable validation, and safe user-editability in future epics. Template extension: `.md.liquid`. `liquid` gem added to Gemfile.**

---

### S-8: ConductorService Naming — Consider `WorkflowEngine` as the Outer Service

**Architect suggested:** `WorkflowEngine` as the public-facing outer service, `ConductorService` as the inner single-dispatch service.

**EAS:** Agree.

**Response:** Accepted. Service layering:

| Service | Responsibility | Called By |
|---------|---------------|-----------|
| `WorkflowEngine` | Owns the `implement` lifecycle: create WorkflowExecution, acquire advisory lock, enqueue first ConductorJob, provide status API | `bin/legion implement`, CLI status commands |
| `ConductorService` | Single Conductor dispatch: assemble Conductor agent, dispatch with current execution state, process tool call, create ConductorDecision | `ConductorJob` (called by Solid Queue) |

`bin/legion implement` calls `WorkflowEngine.call(prd_path:, team:, options:)`. The engine creates the execution record and enqueues the first `ConductorJob`. From there, event-driven callbacks enqueue subsequent `ConductorJob`s (via `ConductorService`).

**Decision locked: D-27 — WorkflowEngine is the public outer service (lifecycle management). ConductorService is the inner service (single Conductor dispatch). CLI calls WorkflowEngine, never ConductorService directly.**

---

## Objections

### O-1: Artifact Model Dependency Creates an Unjustified PRD Sequence Inversion

**Architect objected:** Artifact (2-05) placed after Conductor (2-04) creates a provisional storage path for scores. Three PRDs tangled around one model's timing.

**EAS:** Reorder as necessary.

**Response:** Accepted. The PRD sequence is reordered. Artifact becomes the **second** PRD (after Parallel Dispatch), eliminating the provisional storage path. New sequence:

| New # | Old # | Title | Depends On |
|-------|-------|-------|------------|
| **2-01** | 2-01 | Parallel Task Dispatch via Solid Queue | Epic 1 |
| **2-02** | 2-05 | Artifact Model & Structured Output | 2-01 |
| **2-03** | 2-02 | `bin/legion score` Command | 2-01, 2-02 |
| **2-04** | 2-03 | Task Re-Run & Error Recovery | 2-01 |
| **2-05** | 2-06 | PromptBuilder Service (Liquid) | 2-01 |
| **2-06** | 2-04 | Conductor Agent & WorkflowEngine | 2-01, 2-02, 2-04, 2-05 |
| **2-07** | 2-07 | QualityGate Base Class | 2-02, 2-05 |
| **2-08** | 2-08 | ArchitectGate + QAGate | 2-07 |
| **2-09** | 2-09 | Retry Logic with Context Accumulation | 2-06, 2-08 |
| **2-10** | 2-10 | `bin/legion implement` Full Loop | 2-09 |

**Key changes:**
- Artifact (now 2-02) moves to second position — only needs WorkflowRun FK from Epic 1
- Score Command (now 2-03) writes real Artifacts from day one — no provisional storage
- PromptBuilder (now 2-05) moves earlier — Conductor (2-06) depends on it
- Conductor (now 2-06) depends on Artifact, Task Re-Run, and PromptBuilder — all available

**Updated dependency graph:**

```
Epic 1 (complete)
    │
    ├── 2-01 (Parallel Dispatch)
    │     │
    │     ├── 2-02 (Artifact Model) ← moved early
    │     │     │
    │     │     └── 2-03 (Score Command) ← now uses real Artifacts
    │     │
    │     ├── 2-04 (Task Re-Run)
    │     │
    │     └── 2-05 (PromptBuilder)
    │
    2-01 + 2-02 + 2-04 + 2-05 ─┐
                                │
                         2-06 (Conductor Agent)
                                │
                         2-07 (QualityGate Base)
                                │
                         2-08 (ArchitectGate + QAGate)
                                │
                         2-09 (Retry Logic)
                                │
                         2-10 (Implement Command)
```

**New critical path:** 2-01 → 2-02 → 2-06 → 2-07 → 2-08 → 2-09 → 2-10

**Parallel opportunities:**
- 2-02, 2-04, 2-05 can all proceed in parallel (all depend only on 2-01)
- 2-03 can proceed after 2-02 completes (parallel with 2-04 and 2-05)

**Decision locked: D-28 — PRDs renumbered. Artifact (2-02) before Score (2-03). PromptBuilder (2-05) before Conductor (2-06). No provisional storage paths.**

---

### O-2: Short-Lived Conductor Dispatch Doesn't Explain How Phase Callbacks Reach It

**Architect objected:** The spec mixes event-driven (Model A) and polling/blocking (Model B) dispatch models without resolving the choice.

**EAS:** Need a suggestion and to better understand the implications.

**Response:** This is addressed in **Q-5** above. The recommendation is **Model A (event-driven) for the Conductor, with CLI polling for progress monitoring**. Here's the concrete architecture:

**How it works end-to-end:**

```
bin/legion implement PRD-2-01.md
  │
  ├── WorkflowEngine creates WorkflowExecution (status: running, phase: decomposing)
  ├── WorkflowEngine enqueues ConductorJob(execution_id, trigger: :start)
  ├── CLI enters polling loop (check execution.status every 2s, print progress)
  │
  │   [BACKGROUND — Solid Queue]
  │   ConductorJob runs → ConductorService dispatches Conductor agent
  │     → Conductor calls dispatch_decompose(reasoning: "...")
  │     → ConductorDecision created
  │     → DecompositionService runs (creates tasks + DAG)
  │     → DecompositionService completion callback → enqueues ConductorJob(trigger: :decomposition_complete)
  │
  │   ConductorJob runs → ConductorService dispatches Conductor agent
  │     → Conductor calls dispatch_coding(reasoning: "...")
  │     → ConductorDecision created
  │     → TaskDispatchJob enqueued for each ready task
  │     → Each TaskDispatchJob completion checks: all tasks terminal?
  │       → YES: enqueues ConductorJob(trigger: :all_tasks_complete)
  │
  │   ConductorJob runs → Conductor calls dispatch_scoring(reasoning: "...")
  │     → QA agent dispatched, score parsed
  │     → Completion callback → enqueues ConductorJob(trigger: :scoring_complete)
  │
  │   ConductorJob runs → Conductor reads score, decides...
  │     → (continue retry/retrospective/complete flow)
  │
  ├── CLI polling sees execution.status = "completed" → print final summary → exit 0
  └── (or "escalated" → print issues → exit 3)
```

**Key implications:**
- **The CLI is optional.** The workflow runs entirely in background jobs. Kill the CLI → workflow continues. Reconnect with `bin/legion status --execution 7`.
- **No long-running process needed.** Each ConductorJob is short-lived (one LLM call, one decision). Solid Queue manages the job lifecycle.
- **Event-driven, not polling.** Callbacks enqueue the next ConductorJob — there's no timer-based checking. The Conductor runs exactly when it needs to.
- **ConductorHeartbeatJob (from Q-2)** is the safety net: if a callback fails to fire (bug, crash), the heartbeat detects stale state and re-triggers the Conductor.
- **CI-friendly.** The CLI polling loop works in CI (it's just a process waiting for a DB column to change). Or CI can fire-and-forget: `bin/legion implement ... --background` (enqueue and exit immediately, check status later).

**Decision locked: See D-20 (from Q-5). Model A (event-driven) adopted. ConductorJob as the dispatch mechanism. Callbacks from completing services enqueue next ConductorJob. CLI polls for progress. Workflow independent of CLI process.**

---

### O-3: `ArchitectGate` in the Automated Loop Mismatches Its Human-Workflow Role

**Architect objected:** Unclear whether ArchitectGate is in the automated loop (between decompose and code), a standalone gate, or deferred. The automated Conductor prompt rules don't mention architect review.

**EAS:** If this is the architect approving the PRD plan, then it's part of the overall scoring mechanism. But we should discuss how this fits into the current architecture. If it's a different phase we still need to discuss.

**Response:**

The ArchitectGate serves a different purpose than the QAGate, and this difference determines where it fits:

- **QAGate** (Φ11 in RULES.md): Scores the **output of coding** — "Is the code good?" This is naturally automated because the fix is mechanical (retry coding with feedback).
- **ArchitectGate** (Φ9 in RULES.md): Scores the **implementation plan** — "Is the decomposition sound?" This is harder to automate because the fix is more disruptive (re-decompose, potentially erasing all coding work).

**Recommendation: Include ArchitectGate in the automated loop, between decompose and code.** Here's why and how:

**The phase flow becomes:**

```
decomposing → architect_reviewing → coding → scoring → (retrying | retrospective)
```

**How it works:**
1. After decomposition, the Conductor calls `dispatch_architect_review` (new tool)
2. The Architect agent reviews the task decomposition (not the code — there is no code yet)
3. ArchitectGate parses the score. If ≥ 90: proceed to coding. If < 90: the Conductor calls `dispatch_decompose` again with the Architect's feedback (re-decompose)
4. Max 2 decomposition attempts (not 3 — decomposition is cheaper to redo than coding, but infinite loops are still bad). After 2 failed decompositions: escalate.

**Why this works in the automated loop:**
- Re-decomposition is **safe** — it happens BEFORE coding. No code is erased.
- The Architect scores the PLAN (task list, DAG, sizing), not the code. This is a quick evaluation.
- It aligns with RULES.md Φ9 (plan must be approved before implementation)
- The ArchitectGate uses a different artifact type (`architect_review`) per S-2

**Changes to the epic:**
- New phase enum value: `architect_reviewing`
- New orchestration tool: `dispatch_architect_review`
- Conductor prompt gets a new rule: "1b. After decomposition, call dispatch_architect_review. If review score ≥ 90, proceed to coding. If < 90 and decomposition_attempt < 2, call dispatch_decompose with architect feedback."
- PRD 2-08 (ArchitectGate + QAGate) implements both gates

**Decision locked: D-29 — ArchitectGate is in the automated loop between decompose and code. New `architect_reviewing` phase. New `dispatch_architect_review` orchestration tool. Max 2 decomposition attempts before escalation. ArchitectGate scores the plan (pre-coding), QAGate scores the code (post-coding).**

---

### O-4: The Conductor's Retry Scope — Whole-PRD vs. Task-Level is Ambiguous

**Architect objected:** `WorkflowExecution.attempt` (PRD-level) and `Task.retry_count` (task-level) are conflated. If 1 of 8 tasks keeps failing, the whole execution is escalated.

**EAS:** Agree — two distinct limits.

**Response:** Accepted. Two distinct retry scopes:

**Execution-level (outer loop):**
- `WorkflowExecution.attempt` — counts complete CODE → QA → RETRY cycles
- Max 3 (default, configurable via `--max-retries`)
- After 3 full cycles: enter retrospective, then escalate regardless of individual task status

**Task-level (inner granularity):**
- `Task.retry_count` — counts how many times a specific task has been reset to pending
- Max configurable per execution (default 3, stored in `WorkflowExecution.metadata["task_retry_limit"]`)
- If a single task exceeds its retry limit: task is marked `failed` permanently
- The Conductor must then decide: can the execution proceed without this task? (check if downstream tasks can still run) Or must the execution be escalated?

**Interaction between the two:**
- A single QA cycle might retry 2 of 8 tasks. Each of those tasks gets `retry_count += 1`.
- If the QA cycle passes (score ≥ 90) after the retry, the execution-level attempt still incremented, but we're done.
- If a task hits its task-level limit within a cycle, it's marked `failed`. The Conductor sees this and decides whether to continue (if other tasks are independent) or escalate.
- The execution-level limit is the hard cap — even if individual tasks have retries remaining, after 3 full QA cycles we stop.

**Decision locked: D-30 — Two distinct retry limits. WorkflowExecution.attempt (max 3, CODE→QA→RETRY cycles). Task.retry_count (max configurable, per-task). Task exceeding its limit is marked failed; Conductor decides whether to continue or escalate. Execution limit is the hard outer cap.**

---

### O-5: Testing Strategy Has No LLM Behavior Isolation Plan

**Architect objected:** VCR cassettes for Conductor decisions create false confidence because they replay recorded decisions, not current prompt behavior. Prompt edits invalidate cassettes.

**EAS:** Agree.

**Response:** Accepted. Three-layer testing strategy adopted:

**Layer 1 — Orchestration Tool Unit Tests (deterministic, no LLM, no VCR):**
- Test each tool's precondition guards in isolation
- `mark_completed` refuses score 45 → returns error
- `dispatch_coding` refuses if no ready tasks → returns error
- `retry_with_context` refuses if attempt ≥ max_retries → returns error
- Fast, fully deterministic, run on every CI build

**Layer 2 — Conductor Prompt Contract Tests (live LLM, no VCR):**
- Small set of scenario-based tests (~5-8 tests) that verify the prompt's behavioral contract
- Each test presents a specific execution state to a real Conductor agent and asserts the tool it calls
- Example: "Given score=87, threshold=90, attempt=1, max_retries=3 → Conductor should call retry_with_context"
- Example: "Given score=94, threshold=90 → Conductor should call run_retrospective"
- Marked as `live_llm: true` — run manually or in a dedicated CI step when the prompt changes
- Not run on every CI build (too slow, costs money)
- Purpose: regression suite for prompt edits — "did my prompt change break a behavioral contract?"

**Layer 3 — Full Cycle Integration Tests (VCR-recorded):**
- Record the service layer behavior, not the Conductor's specific reasoning
- Assertions on state changes: "WorkflowExecution.phase changed from `decomposing` to `coding`" + "ConductorDecision was created with valid `to_phase`"
- Do NOT assert on `ConductorDecision.reasoning` text (that's LLM output, will vary)
- DO assert on structural outcomes: Artifacts created, phases transitioned, tasks dispatched
- VCR cassettes are stable as long as the service layer contract doesn't change (which is much more stable than the Conductor's reasoning)

**Decision locked: D-31 — Three-layer testing strategy. Layer 1: tool guard unit tests (deterministic). Layer 2: prompt contract tests (live LLM, run on prompt changes). Layer 3: integration tests (VCR, assert state changes not reasoning text).**

---

## Summary of Locked Decisions

| # | Decision | Source |
|---|----------|--------|
| D-17 | Conductor is a new dedicated agent config (`conductor.yml`) | Q-1 |
| D-18 | ConductorHeartbeatJob for stale task detection (60s, 15min timeout) | Q-2 |
| D-19 | Orchestration tools accept required `reasoning:` parameter | Q-3 |
| D-20 | ConductorJob (event-driven) + CLI polling for progress | Q-5, O-2 |
| D-21 | ConductorDecision includes duration_ms, tokens_used, estimated_cost | S-1 |
| D-22 | `architect_review` is a distinct artifact_type | S-2 |
| D-23 | WorkflowExecution stores prd_snapshot + prd_content_hash | S-3 |
| D-24 | --dry-run output format specified (5 sections, JSON option) | S-4 |
| D-25 | Parallel file conflict is a blocking validation (auto-serialize) | S-6 |
| D-26 | Prompt templates use Liquid (not ERB) for sandboxing + validation | S-7 |
| D-27 | WorkflowEngine (outer) / ConductorService (inner) service layering | S-8 |
| D-28 | PRDs renumbered — Artifact (2-02) before Score (2-03) | O-1, Q-4 |
| D-29 | ArchitectGate in automated loop between decompose and code | O-3 |
| D-30 | Two distinct retry limits (execution-level + task-level) | O-4 |
| D-31 | Three-layer testing strategy (unit/prompt contract/integration) | O-5 |
| — | S-5 (retrospective data caps) deferred to implementation time | S-5 |

---

## Items Requiring Second-Cycle Review

The following items may warrant further Architect scrutiny in V2:

1. **D-29 (ArchitectGate in loop):** The new `architect_reviewing` phase and `dispatch_architect_review` tool add scope to PRDs 2-06 and 2-08. The Architect should confirm the max 2 decomposition attempts limit is appropriate and review the updated phase diagram.

2. **D-26 (Liquid templates):** This is a technology change from the original ERB spec. The Architect should assess whether Liquid's limitations (no arbitrary Ruby in templates) create any blockers for the Conductor prompt or phase-specific templates.

3. **D-28 (PRD reorder):** The new dependency graph changes the critical path. The Architect should verify that parallel opportunities (2-02, 2-04, 2-05 in parallel) don't create integration risks.

4. **D-20 (Event-driven Conductor):** The ConductorJob + callback architecture is a significant design choice. The Architect should review the callback chain for potential failure modes (what if a callback fails to enqueue the next ConductorJob?).
