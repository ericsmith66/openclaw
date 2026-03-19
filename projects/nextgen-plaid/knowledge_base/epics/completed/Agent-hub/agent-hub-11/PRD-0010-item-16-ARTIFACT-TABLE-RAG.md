# PRD 0010 (Artifact 16): Persona Setup & Console Handoffs — Artifact-Table-Only Edition

**Artifact Table Anchor**: This PRD applies to `artifacts.id = 16`.

**Why this version exists**: It is intentionally generated with **minimal context** (the `artifacts` table schema + the Artifact 16 row identifiers) so we can compare PRD quality against richer RAG variants.

**RAG scope used for this PRD (deliberately narrow)**

* Table schema available:
  * `artifacts(id, artifact_type, name, owner_persona, phase, payload, created_at, updated_at, lock_version)`
* Artifact 16 identifiers (known):
  * `id = 16`
  * `name = "Agent-05 PRD 0010: Persona Setup & Console Handoffs"`
  * Other columns (`artifact_type`, `phase`, `owner_persona`, `payload`) are **not provided** in this prompt and are treated as unknown.

---

## 1) Overview

### 1.1 Goal

Deliver a spike that establishes a foundation for **persona setup** and **console-driven handoffs** between personas/agents, and stores its primary outputs in a way that can be attached to `Artifact(16)`.

### 1.2 Non-goals

* No new end-user UI requirements (console-first spike).
* No assumption of a specific agent framework/gem unless already chosen by the codebase.
* No new persistence layer beyond what’s required to demonstrate the spike.

---

## 2) Problem Statement

We need to validate that:

1. Personas can be registered/configured in a stable way.
2. A console runner can execute a small multi-agent chain.
3. Handoffs between personas are explicit and durable.
4. Outputs can be stored and linked back to an `Artifact` record (id `16`) for later inspection.

---

## 3) Assumptions / Constraints (due to minimal context)

Because this PRD is generated with **only** the `artifacts` table schema and limited Artifact 16 identifiers:

* Existing orchestration systems, jobs, and UI surfaces are unknown.
* Existing run/conversation tables (if any) are unknown.
* Existing LLM provider patterns are unknown.

This PRD therefore defines requirements in a framework-agnostic way and focuses on **interfaces, persistence shape, and artifact linkage**.

---

## 4) Requirements

### R1 — Artifact linkage is explicit and canonical

* Every run MUST record that it is working on `artifact_id = 16`.
* Every run MUST generate a `correlation_id` (UUID) to associate events and outputs.
* The system MUST persist a link between the run and `artifacts.id = 16` in at least one durable location:
  * Option A (DB-first): a `runs`/`workflow_runs` table (if it exists) stores `artifact_id`.
  * Option B (filesystem-first): a run folder includes `artifact_id` in its `run.json`.

### R2 — Persona registry / configuration

* Provide a stable, centralized way to define personas/agents (e.g., YAML config or Ruby registry).
* Must support at minimum:
  * `SAP` (analysis/PRD persona)
  * `Coordinator` (handoff / assignment persona)
  * `CWA` (implementation persona placeholder)
* Must be easy to extend with new personas without scattered code edits.

### R3 — Handoff protocol

Define a standard handoff envelope, stored in the shared run context.

Minimum required fields:

* `artifact_id` (integer; for this spike always `16`)
* `correlation_id` (string UUID)
* `ball_with` (string; who “owns” the next action)
* `workflow_state` (string; e.g., `draft`, `in_progress`, `awaiting_review`)
* `events` (append-only list)

Handoff behavior:

* When handing off from Persona A to Persona B, the system MUST:
  * append an event of type `agent_handoff` with at least `{ from, to, artifact_id, correlation_id, at }`
  * set `ball_with = <Persona B>`

### R4 — Console-first runner

* Provide a single entry point for local execution (e.g., rake task or script).
* Runner MUST:
  * accept a prompt string
  * error clearly on blank/empty prompt (no external calls)
  * initialize `artifact_id=16` and a new `correlation_id`
  * run at least a 2-step chain (SAP then Coordinator)
  * demonstrate at least one handoff event
  * print a short summary including `correlation_id`, `artifact_id`, and final `ball_with`

### R5 — Persistence of outputs

To support later inspection and comparison, always write:

* `run.json`: final context snapshot (includes `artifact_id=16`, `correlation_id`, state, and summary outputs)
* `events.ndjson` (or equivalent): append-only event stream including the handoff

Location can be either DB-backed or filesystem-backed, but MUST be deterministic and easy to find given a `correlation_id`.

### R6 — Guardrails

* Limit turns (e.g., `max_turns=3`) to avoid runaway loops.
* Fail fast on invalid input.
* Clearly log any exceptions and include them in `run.json` if the run fails.

---

## 5) Acceptance Criteria

1. A developer can run a console command to execute a 2-persona chain.
2. The run persists durable outputs including:
   * `artifact_id = 16`
   * `correlation_id`
   * at least one `agent_handoff` event
3. The run can be located and inspected later by referencing `correlation_id`.

---

## 6) Test Strategy

* Add deterministic unit tests for:
  * prompt validation (blank prompt fails without provider calls)
  * handoff envelope creation and event emission
  * persistence writer (creates `run.json` and `events.ndjson`)
  * artifact linkage (always `artifact_id=16` for this spike)

---

## 7) Open Questions (expected given minimal context)

1. What is the canonical agent framework/gem (if any) already selected?
2. Where should run artifacts live (DB vs filesystem) given existing patterns?
3. Are there existing UI surfaces that should display run history for Artifact 16?

[ACTION: FINALIZE_PRD: 16]
