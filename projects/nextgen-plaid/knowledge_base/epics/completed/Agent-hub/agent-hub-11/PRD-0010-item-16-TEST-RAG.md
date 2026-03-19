# PRD 0010 (Artifact 16): Persona Setup & Console Handoffs — TEST-RAG Edition

**Artifact Table Anchor**: This PRD applies to `artifacts.id = 16`.

**Why this version exists**: It is generated using `knowledge_base/epics/Agent-hub/agent-hub-11/TEST-RAG.md` so we can compare outcomes against the prior/original PRD(s) (kept unchanged elsewhere).

---

## 1) Overview

### 1.1 Goal

Deliver a spike that validates a **multi-persona / multi-agent runner** with **console-first execution**, durable run artifacts, and explicit **handoffs** between personas. The spike must align with the existing Agent Hub 11 workflow patterns (especially `correlation_id`, `ball_with`, and artifact linkage).

### 1.2 Non-goals (for this spike)

* No new end-user features.
* No new vector database.
* No production-grade permissions beyond existing owner/admin gating patterns.
* No requirement to fully replace the existing Agent Hub orchestration; this spike must be compatible and additive.

---

## 2) Background / Architectural Context (Current App Reality)

The app already has:

* **Agent Hub UI** at `GET /agent_hub`, with conversations stored as `SapRun` + `SapMessage`.
* **sap_collaborate** at `GET /admin/sap_collaborate`, which enqueues `SapAgentJob` and persists chat history.
* **Workflow orchestration** concepts centered on `AiWorkflowService` (and supporting services), including:
  * `correlation_id`
  * `ball_with` and `workflow_state`
  * durable filesystem artifacts under `agent_logs/ai_workflow/<correlation_id>/...`
  * artifact linkage patterns (active artifact id in workflow metadata, plus conversation linkage)

This PRD requires the new runner to **reuse these concepts** and explicitly support linking runs to `artifacts.id = 16`.

---

## 3) User Story

As an owner/developer, I want to run a deterministic multi-agent chain from the console that:

* uses a consistent shared `context`
* performs at least one explicit handoff (e.g., SAP → Coordinator)
* persists outputs in a durable, inspectable format
* links the run to `Artifact(16)` so it can later be surfaced in Agent Hub / Mission Control
* can be executed with **either** local Ollama or Grok via SmartProxy for comparison

---

## 4) Requirements

### R1 — Artifact linkage is explicit and canonical

* The spike must treat **Artifact 16** (`artifacts.id = 16`) as the canonical work anchor.
* Every run must carry:
  * `artifact_id = 16`
  * `correlation_id = SecureRandom.uuid`
* Where applicable, persist the linkage in:
  * conversation: `sap_runs.artifact_id = 16` (so Agent Hub conversation knows which artifact it belongs to)
  * workflow metadata: `AiWorkflowRun.metadata["active_artifact_id"] = "16"` (when using `AiWorkflowRun`)

### R2 — Registry-based persona/agent registration

Implement a minimal registry pattern that defines (at minimum):

* `SAP` (Strategic Analysis Persona)
* `Coordinator` (handoff + assignment)
* `CWA` (implementation persona placeholder for later handoff)

Constraints:

* Persona definitions must be sourced from stable configuration (not parsed from Markdown at runtime).
* Registry should support adding new personas without code changes in multiple locations.

### R3 — Handoff protocol and payload schema

Define and enforce an explicit handoff envelope inside the shared `context`.

Minimum fields:

* `correlation_id`
* `artifact_id` (must be `16` for this spike)
* `workflow_state` (e.g., `draft`, `in_progress`, `awaiting_review`)
* `ball_with` (e.g., `SAP`, `Coordinator`, `CWA`, `Human`)
* `micro_tasks` (array of atomic tasks, even if empty for first pass)
* `events` (append-only event list or NDJSON stream)

Handoff must:

* record an event `agent_handoff` with `{ from, to, correlation_id, artifact_id, at }`
* mutate `ball_with` to the recipient

### R4 — Bridge to existing UI surfaces (no new UI required)

The spike must specify (and implement where minimal):

* How the console runner can later feed **Agent Hub** conversations (via `SapRun` / `SapMessage`).
* How the run can be observable from an existing owner-only surface:
  * either via Agent Hub context inspection (`/agent_hubs/inspect_context`) or
  * via an existing admin workflow screen (`/admin/ai_workflow?artifact_id=16`) if applicable.

No new UI pages are required in this PRD; only the data hooks and linkage should be established.

### R5 — Persistence (filesystem first, DB optional)

Always write filesystem artifacts to:

* `agent_logs/ai_workflow/<correlation_id>/run.json`
* `agent_logs/ai_workflow/<correlation_id>/events.ndjson`

DB usage:

* `SapRun` and `SapMessage` may be used to persist the conversation transcript for later UI display.
* `AiWorkflowRun` may be used if needed for resumability and admin inspection; if used, ensure metadata captures `active_artifact_id`.

### R6 — LLM runtime: SmartProxy + two required model backends

All LLM calls must go through SmartProxy’s OpenAI-compatible endpoint:

* `POST /v1/chat/completions`

The spike must support selecting **two** backends:

1. **Ollama** (local-first default)
2. **Grok** via SmartProxy using model id **`grok-latest`**

Model selection requirements:

* `AI_MODEL` environment variable selects the model id.
* The runner must log `model_used` and include it in `run.json`.
* The runner must behave identically across backends (same request shape), with adapter-level handling of minor response differences.

### R7 — Guardrails (spike-level)

* `max_turns` default (e.g., `3`) to avoid runaway loops.
* Empty/blank prompt must halt with a clear error and must not call the provider.
* Local/dev only by default (require explicit opt-in to run in prod-like environments).

---

## 5) Console / Runner Interface

Provide a single, ergonomic entrypoint for devs:

* A Rake task or script, e.g. `bundle exec rake ai:run_request["..."]`

The runner must:

* initialize `correlation_id` and set `artifact_id=16`
* run SAP first
* perform at least one handoff to Coordinator
* print:
  * `correlation_id`
  * `artifact_id`
  * `model_used`
  * final `ball_with`

---

## 6) Acceptance Criteria

1. Running the console command creates:
   * `agent_logs/ai_workflow/<correlation_id>/run.json`
   * `agent_logs/ai_workflow/<correlation_id>/events.ndjson`
2. `run.json` includes `correlation_id`, `artifact_id: 16`, `workflow_state`, `ball_with`, and `model_used`.
3. `events.ndjson` contains an `agent_handoff` event from `SAP` to `Coordinator`.
4. The run can be executed with:
   * `AI_MODEL=<ollama-model-id>` (local)
   * `AI_MODEL=grok-latest` (Grok)
5. The run is linkable to the application’s artifact system:
   * A `SapRun` created/updated for the run stores `artifact_id = 16` (or, if not used, the PRD must specify how it will be linked when integrated).
6. The implementation can be inspected from existing surfaces without new pages (at minimum via logs/artifacts; ideally via Agent Hub artifact linkage).

---

## 7) Test Strategy

All tests must be deterministic and must not call live networks.

* Unit: runner/service tests verify:
  * handoff event creation
  * context mutation (`ball_with`, `workflow_state`)
  * artifact writes
  * `artifact_id` is always `16`
* Unit: SmartProxy adapter tests via request stubs (`WebMock`) verify:
  * request payload shape to `/v1/chat/completions`
  * parsing of response into a consistent internal format
* Task test: rake task prints required lines (assert output contains `correlation_id`, `artifact_id=16`, and `ball_with=`)

---

## 8) Dev Run Examples

### Ollama (local-first)

```bash
AI_MODEL=llama3.1:8b \
SMART_PROXY_PORT=3001 \
PROXY_AUTH_TOKEN=your_token \
bundle exec rake ai:run_request["Draft PRD requirements for Artifact 16"]
```

### Grok via SmartProxy (`grok-latest`)

```bash
AI_MODEL=grok-latest \
SMART_PROXY_PORT=3001 \
PROXY_AUTH_TOKEN=your_token \
bundle exec rake ai:run_request["Draft PRD requirements for Artifact 16"]
```

---

## 9) Implementation Notes (Constraints)

* Prefer integrating with existing Agent Hub workflow/linkage concepts rather than inventing a new parallel schema.
* Keep the spike narrow: validate the gem/runner + handoff + persistence + multi-model selection.
* Maintain local-first defaults and avoid leaking user data outside the system.

[ACTION: FINALIZE_PRD: 16]
