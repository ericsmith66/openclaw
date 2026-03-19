# PRD-AH-012A: CLI Base Setup and Command Interface

Part of Epic AH-012: Agent SDLC Testing CLI.

---

## Overview

Implement a Rake-based CLI entrypoint to initiate autonomous SDLC test runs, route to `AiWorkflowService`, and persist state via `Artifact` and `ai_workflow_runs`.

This PRD establishes:

- `rake agent:test_sdlc[...]` command surface
- options parsing (extracted to a PORO for unit tests)
- run_id/correlation_id + DB records + filesystem logging
- wall-clock timeout and transactional rollback on failure

---

## Logging requirements

Read: `knowledge_base/prds/prds-junie-log/junie-log-requirement.md`.

All CLI executions MUST write a structured JSON log:

- Path: `knowledge_base/logs/cli_tests/<run_id>/cli.log`
- Log start/end timestamps, argv/parsed args, stage, ids, duration, and errors.

Recommended minimum JSON keys per record:

- `timestamp`
- `level` (`info`/`error`)
- `event`
- `run_id`
- `argv` (array)
- `stage`
- `artifact_id`
- `ai_workflow_run_id`
- `duration_ms`
- `error` (object: `class`, `message`, optional `backtrace` gated by `--debug`)

---

## Problem

There is no existing CLI/test harness to repeatedly execute the full SDLC workflow using the same interfaces as production.

---

## User story

As a developer, I want to run an autonomous SDLC workflow from the command line with configurable overrides, durable logs, and DB-backed state so I can validate agent reliability and iteratively improve prompts/RAG/tools.

---

## Functional requirements

### A) Command

- Add rake task: `rake agent:test_sdlc[options]`
- Parse flags via `OptionParser` (but extracted into a PORO, e.g., `SdlcTestOptions.parse(argv)`)
- Must support `--help` with examples

### B) Core options (initial)

- `--input="<query>"` (string)
- `--stage=<artifact_phase>` (phase-based stage isolation; see Epic for fast-forward semantics)
- per-persona model overrides (initial stubs; expanded in later PRDs):
  - `--model-sap=<model>`
  - `--model-coord=<model>`
  - `--model-cwa=<model>`
- `--sandbox-level=<strict|loose>`
- `--max-tool-calls=<int>`
- `--dry-run` (skip LLM + tool calls; stub responses; validate transitions/logging/reporting only)
- `--run-id=<run_id>` (optional; auto-generate if absent)
- `--debug` (enables verbose traces/backtraces)

#### Option Registry (v1)

Other PRDs may add flags, but 012A is the canonical place to enumerate the full CLI option surface.

| Flag | Type | Default | Introduced | Used by |
| --- | --- | --- | --- | --- |
| `--input` | string | (required unless `--dry-run`) | 012A | SAP prompt seed |
| `--stage` | string (artifact phase) | `backlog` | 012A | stage fast-forward + synthetic payload |
| `--run-id` | string | auto-generate | 012A | filesystem + `AiWorkflowRun.correlation_id` |
| `--model-sap` | string | `llama3.1:70b` | 012A | SAP LLM |
| `--model-coord` | string | `llama3.1:70b` | 012A | Coordinator LLM |
| `--model-cwa` | string | `llama3.1:70b` | 012A | CWA LLM |
| `--sandbox-level` | enum | `strict` | 012A | tool policy (expanded in 012D) |
| `--max-tool-calls` | int | (guardrail default) | 012A | tool call limiter (expanded in 012D) |
| `--dry-run` | bool | false | 012A | stubbed execution (no LLM/tools) |
| `--debug` | bool | false | 012A | backtraces + verbose logs |

### C) Model validation

- Validate model names against a configured allowlist (no live Ollama `/api/tags` query).
- If unspecified, fallback to defaults (e.g., `llama3.1:70b` for Ollama).

Allowlist location (canonical):

- `config/ai_models.yml` (global list of valid model tags)

### D) DB state

- On run start, create an `Artifact` in phase `backlog` with owner SAP.
- Add `payload["test_correlation_id"] = <run_id>`.
- Create `AiWorkflowRun` for the run using `run_id` as `AiWorkflowRun.correlation_id`.

### E) Orchestration invocation

- Invoke `AiWorkflowService.run(..., test_overrides: {...})`.
- `test_overrides` is a per-run hash (no ENV/global registry mutation).

`test_mode` requirements (CLI runs):

- Pass `test_mode: true` (or equivalent) to the service.
- In `test_mode`, the run must:
  - Skip ActionCable broadcasts (no UI updates).
  - Force auto-approve behavior in `finalize_hybrid_handoff!` (no human gating states on success).
  - Bypass tool-execution ENV toggles (treat tools as enabled for the run).
  - Suppress “escalate to human” failures (log as evidence, continue with default/retry behavior).

### F) Timeout + rollback

- Enforce a wall-clock 5 minute timeout for the entire invocation (`Timeout.timeout(300)`).
- Wrap run execution in `ActiveRecord::Base.transaction`.
  - On any exception: rollback DB changes.
  - Filesystem logs/artifacts remain as durable evidence.

---

## RAG tiers (v1 mapping + truncation)

Tier-to-path mapping (v1):

- `foundation` → `knowledge_base/static_docs/`
- `structure` → `knowledge_base/schemas/`
- `history` → `knowledge_base/inventory.json` + recent run summaries/logs (7-day lookback)

Truncation: v1 uses a deterministic **character cap** proxy (100k chars) and logs when truncating.

---

## `--dry-run` semantics

When `--dry-run` is enabled:

- Never call SmartProxy/Ollama (no LLM calls).
- Never execute tools (no git/shell).
- Still create an `Artifact` + `AiWorkflowRun`, fast-forward phases, and inject synthetic payloads required for downstream phases:
  - `payload["content"]` (PRD)
  - `payload["micro_tasks"]` (array)
  - `payload["implementation_notes"]`
- Still write full reporting artifacts (e.g., `run_summary.md` and structured JSON logs) so CI can validate the reporting pipeline.

---

## Non-functional requirements

- Sandbox-safe by default; no real git commits unless sandbox-level is `loose` (expanded in PRD-012D).
- CLI should complete minimal no-op run in under 1 minute.

---

## Acceptance criteria

- AC1: CLI parses and validates args; invalid model errors out.
- AC2: Creates `Artifact` in `backlog` and transitions to `ready_for_analysis` after successful parse.
- AC3: Executes a minimal autonomous run with defaults without crashing interfaces.
- AC4: Creates an `AiWorkflowRun` record and persists IDs in logs.
- AC5: Writes structured JSON logs to `knowledge_base/logs/cli_tests/<run_id>/cli.log`.
- AC6: Full minimal run completes < 1 minute.
- AC7: On errors/exceptions, DB changes rollback; filesystem logs remain.
- AC8: `--help` prints usage and examples.
- AC9: `--dry-run` advances through transitions without any LLM calls.

---

## Test cases

- Unit (RSpec): options parsing PORO
  - Example: `expect(parsed[:model_sap]).to eq("llama3.1:70b")`
- Integration (RSpec): call `AiWorkflowService` directly (avoid invoking rake in specs)
  - Verify Artifact creation + phase updates + AiWorkflowRun linkage
  - Use WebMock/VCR only where strictly needed (later PRDs expand Ollama coverage)

---

## Notes / future migration

Rake + `OptionParser` is acceptable for 012A. If the flag surface grows beyond ~10 flags, plan a migration to a dedicated executable (e.g., `bin/agent_test_sdlc` via Thor) while keeping the same option schema.
