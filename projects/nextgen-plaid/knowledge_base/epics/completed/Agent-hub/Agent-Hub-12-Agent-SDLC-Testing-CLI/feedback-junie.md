# Junie Feedback: AH-012 Agent SDLC Testing CLI (Consistency + Gaps)

This document is a consistency review of:

- `0000-Epic.md`
- `PRD-AH-012A-cli-base.md`
- `PRD-AH-012B-sap-variation.md`
- `PRD-AH-012C-coordinator-analysis.md`
- `PRD-AH-012D-cwa-execution.md`
- `PRD-AH-012E-validation-scoring.md`

It also checks whether my prior “de-risking” questions are now answered in the docs, and calls out any remaining ambiguities.

---

## 1) Overall consistency check (what looks good)

- **Autonomous success definition is now consistent** across the Epic and PRDs: advancement is “no unhandled exceptions + `transition_to(\"approve\", <persona>)`”, with additive validation signals captured for PRD-012E.
- **Persistence model is consistent**: DB persists on success; rollback on exception; filesystem artifacts/logs always persist.
- **Run identity is consistent**: a single `run_id` used for filesystem directories + correlation.
- **Markdown-first reporting is consistent**: `run_summary.md` is now the primary human-readable output; `validation.json` is the machine-readable scoring detail.
- **Override scoping is consistent**: overrides must be per-run via `test_overrides` (no ENV / no global registry mutation).

---

## 2) Remaining questions / ambiguities (should be clarified in-docs)

### Q1: `--stage` meaning is currently ambiguous (phase vs persona)

The Epic defines `--stage=<phase>` where `<phase>` means Artifact phase (e.g., `in_analysis`).

But PRDs 012B/012C/012D use values like:

- `--stage=sap`
- `--stage=coord`
- `--stage=cwa`

These are **persona**-oriented selectors, not Artifact phases.

**Suggestion**: pick one of these approaches and make it explicit across all docs:

1. **Two flags**:
   - `--stage-phase=<artifact_phase>` (e.g., `in_analysis`, `ready_for_qa`)
   - `--stage-agent=<sap|coord|cwa|validate>` (agent segment isolation)

2. **Single `--stage` but typed**:
   - `--stage=phase:in_analysis`
   - `--stage=agent:sap`

3. **Single `--stage` (phase only)** and introduce `--isolate-agent=<sap|coord|cwa|validate>` for the persona isolation PRDs.

Without this clarification, implementers will likely “guess” and tests will encode the wrong behavior.

### Q2: Which DB column is the `run_id` actually stored in?

Epic/PRD-012A says `AiWorkflowRun.correlation_id (or equivalent)`.

**Question**:

- Is there an actual `correlation_id` column on `ai_workflow_runs`, or is the correlation currently `AiWorkflowRun.id` (integer/uuid) or `context[\"correlation_id\"]`?

**Suggestion**: update docs to the concrete field name(s) used in this repo (or call out that 012A will add a `correlation_id` column if absent).

### Q3: “Rollback on exception” vs. filesystem evidence is clear; but what about git side effects?

PRD-012D requires temp branches / commits in `loose` mode and cleanup “on run end (success or failure)”.

**Potential gotcha**: DB rollback does not roll back git changes. This is fine, but we should specify the cleanup semantics more concretely:

- Are commits allowed on a temp branch only (never main)?
- Do we delete the branch even on success (as PRD-012D states), or do we keep it as durable evidence?
- If we delete the branch, do we still persist diffs under `knowledge_base/test_artifacts/<run_id>/code_diffs/` so evidence remains?

### Q4: “Bypass human gates” should specify what gets bypassed (broadcasts vs. confirm_action vs. escalation)

Epic/012A says `test_mode: true` can “bypass human gates and optionally skip broadcasts”.

**Questions**:

- Do we always skip ActionCable broadcasts during CLI runs, or should we keep them (for parity / debugging)?
- Which human-gated states are explicitly bypassed in CLI runs (e.g., `awaiting_review`, `awaiting_feedback`)?
- On failure, do we transition to an explicit phase (or set an `ai_workflow_runs.status`), or just log and raise?

### Q5: Model allowlist location is not specified

PRD-012A mandates model validation against an allowlist, but does not specify the canonical file path.

**Suggestion**: choose one and write it down now to prevent implementation drift:

- `config/ai_models.yml` (recommended)
- or `knowledge_base/ai_models.yml` (if you want it editable without deploy)

Also specify whether allowlists are per persona (`sap`, `coord`, `cwa`) or global.

### Q6: `--dry-run` semantics need a little more precision

012A says: “advance through transitions without any LLM calls” and “validate transitions/logging only”.

Given the Epic’s `--stage` fast-forward + “inject minimal synthetic payload”, dry-run likely overlaps.

**Suggestion**: define a single consistent behavior:

- In `--dry-run`, *always* inject synthetic payloads needed for downstream phases (content, micro_tasks, implementation_notes) and *never* call SmartProxy/Ollama or tools.
- Ensure it still writes `run_summary.md` and relevant per-run logs to prove the reporting pipeline works.

---

## 3) Objections / risks (things that can cause churn if not addressed)

### R1: Option surface is split across PRDs but not centrally enumerated

012A defines a baseline set of flags. Later PRDs add more flags. This is fine, but it’s easy to lose track.

**Suggestion**: add an “Option Registry” section either in the Epic or 012A that lists:

- flag name
- type
- default
- which PRD introduces it
- which agent/phase uses it

This will also make `--help` spec much easier to implement.

### R2: RAG tier mapping is deferred (“defined in implementation”), which risks inconsistency

012B/012C/012D mention RAG tiers but defer tier→path mapping.

**Suggestion**: declare a minimal v1 mapping in-docs now (even if subject to change), e.g.:

- `foundation` → `knowledge_base/static_docs/`
- `structure` → `knowledge_base/schemas/`
- `history` (future) → `agent_logs/` or prior `test_artifacts/` summaries

Otherwise SAP/Coord/CWA will implement subtly different RAG behavior.

### R3: Token cap “~100k tokens” is not enforceable without a tokenizer choice

The docs specify a ~100k token cap; but implementation needs:

- which tokenizer to use (model-dependent), or
- a deterministic proxy (e.g., char/byte length)

**Suggestion**: for v1, specify a deterministic cap by bytes/chars (e.g., 400k chars) and log when truncating.

---

## 4) Suggestions / improvements (low cost, high leverage)

### S1: Add a dedicated “run directory contract” section in the Epic

Right now, outputs are described across PRDs. Consider one canonical section in the Epic that lists the **full directory structure**:

- `knowledge_base/test_artifacts/<run_id>/run_summary.md`
- `knowledge_base/test_artifacts/<run_id>/prd.md`
- `knowledge_base/test_artifacts/<run_id>/micro_tasks.json`
- `knowledge_base/test_artifacts/<run_id>/plan_summary.md`
- `knowledge_base/test_artifacts/<run_id>/cwa_summary.md`
- `knowledge_base/test_artifacts/<run_id>/handoffs/`
- `knowledge_base/test_artifacts/<run_id>/code_diffs/`
- `knowledge_base/test_artifacts/<run_id>/validation.json`
- `knowledge_base/logs/cli_tests/<run_id>/*.log`

This reduces “where should X live?” questions during implementation.

### S2: Add a “failure evidence” section to `run_summary.md`

PRD-012E defines success scoring, but failure readability is also important.

**Suggestion**: require a section:

- “Errors / Escalations”
  - last exception class/message
  - last phase reached
  - pointers to relevant log files

This makes triage faster.

### S3: Standardize event naming early (for later validation)

Several PRDs mention reusing `ArtifactWriter` callbacks/events.

**Suggestion**: define a minimal event vocabulary now (even if only in docs), e.g.:

- `phase.started`, `phase.completed`
- `llm.request`, `llm.response`
- `handoff.created`
- `tool.invoked`, `tool.succeeded`, `tool.failed`

PRD-012E’s validation becomes much simpler if this is consistent.

---

## 5) Confirming prior questions are answered (checkbox)

- [x] Autonomous success definition per phase (core + additive validation)
- [x] Ground truth for transitions (`AiWorkflowService#finalize_hybrid_handoff!` + `Artifact#transition_to`)
- [x] Persistence model clarified (DB persists on success; rollback on exception; filesystem always persists)
- [x] Run identity format specified
- [x] Variations are single-run overrides only
- [x] `--stage` from scratch behavior specified (fast-forward + synthetic payload)
- [x] Overrides live in `test_overrides` hash (no ENV/registry mutation)

The only remaining *meaningful* unresolved area is the **`--stage` value namespace** (phase vs agent) and the **exact storage field** for `run_id` in DB.

---

## 6) Responses / resolutions (attributed)

### GROK_ERIC

Below are point-by-point answers resolving the remaining ambiguities (Q1–Q6), objections/risks (R1–R3), and suggestions (S1–S3).

#### Remaining Questions / Ambiguities

**Q1: `--stage` ambiguous (phase vs persona)**

- Use **phase-based only** (e.g., `--stage=in_analysis`) to align with Artifact phases.
- Drop persona selectors (`sap/coord/cwa`) from `--stage` values. Overrides remain per-agent via `--model-sap`, `--prompt-coord`, etc.
- If isolation is needed, the service can fast-forward to a target phase with synthetic payload.

**Q2: Which DB column stores `run_id`?**

- Use `AiWorkflowRun#correlation_id` (string) as the canonical `run_id`.
- Associate `Artifact` via `payload["test_correlation_id"]` (defer any migration).

**Q3: Git side effects during testing (temp branches, commits) cleanup**

- In `loose` sandbox:
  - Create temp branch `test-run-<run_id>`
  - Commit changes
  - Preserve evidence by copying diffs/logs to filesystem under `knowledge_base/test_artifacts/<run_id>/code_diffs/`
  - Cleanup by deleting the branch post-run (success/failure) via a GitTool wrapper in an `ensure/after` block
- In `strict` sandbox: no GitTool execution.

**Q4: “Bypass human gates” in test mode detail**

- In `test_mode` (flag in `AiWorkflowService`):
  - Skip ActionCable broadcasts
  - Force auto-approve in `finalize_hybrid_handoff!` (ignore `awaiting_feedback` / `escalated` on success)
  - Bypass `ENV["AI_TOOLS_EXECUTE"]` checks (treat as enabled)
  - Suppress human escalation errors (log + continue with default/retry)

**Q5: Model allowlist location**

- Canonical config file: `config/ai_models.yml` (array of valid model tags).

**Q6: `--dry-run` semantics**

- `--dry-run`:
  - Skip all LLM calls (stub responses)
  - Skip all tool execution (log “would call”)
  - Still generate full reports and logs (including `run_summary.md`) with synthetic data
  - Fast transitions (mock/assume `finalize_hybrid_handoff!` success)

#### Objections / Risks

**R1: CLI flags scattered across PRDs**

- Centralize in PRD-012A as an “Option Registry” (PORO like `SdlcTestOptions` defines all flags).

**R2: RAG tier mappings deferred**

- Define v1 mapping in docs:
  - `foundation`: `knowledge_base/static_docs/*`
  - `structure`: `knowledge_base/schemas/*`
  - `history`: `knowledge_base/inventory.json` + recent logs (7-day)
- Concatenate in order; truncate with warning at ~100k chars as a deterministic proxy.

**R3: Token cap not enforceable without tokenizer**

- Use a char-limit proxy for v1; defer tokenizer selection.

#### Suggestions / Improvements

**S1: Add “run directory contract” to Epic**

- Explicitly list expected files under `knowledge_base/test_artifacts/<run_id>/`.

**S2: Enhance `run_summary.md` with failure evidence**

- Add a section containing last phase/error and pointers to logs.

**S3: Standardize event naming**

- Adopt/reuse `ArtifactWriter` events:
  - `phase.started`, `phase.completed`
  - `llm.request`, `llm.response`
  - `handoff.created`
  - `tool.invoked`, `tool.completed`
