# PRD-AH-012C: Coordinator Orchestration Testing and Analysis Phases

Part of Epic AH-012: Agent SDLC Testing CLI.

---

## Overview

Add CLI support for Coordinator sequencing in analysis-related phases, varying prompts/models/RAG, validating handoffs, and persisting micro-tasks to DB.

---

## Logging requirements

Read: `knowledge_base/prds/prds-junie-log/junie-log-requirement.md`.

Log traces to:

- `knowledge_base/logs/cli_tests/<run_id>/coordinator.log`

---

## Functional requirements

### A) New flags

- `--prompt-coord=<path/to/custom.md.erb>`
- `--model-coord=<model>`
- `--rag-coord=<tiers>`
- `--debug`

Note: `--stage` is artifact-phase based only (see Epic/PRD-012A). For Coordinator-focused runs, use `--stage=in_analysis`.

### B) Micro-tasks persistence

- Store micro-tasks in `artifact.payload["micro_tasks"]`.
- Persist a convenience plan view for humans:
  - `knowledge_base/test_artifacts/<run_id>/plan_summary.md`
  - Format: Markdown checklist derived from `payload["micro_tasks"]` and any plan broadcast logic.
- Minimal schema per task:
  - `id` (string)
  - `title` (string)
  - `estimate` (string)
  - `description` (optional string)
  - `acceptance_criteria` (optional array)

### C) Handoff capture

- Reuse existing `ArtifactWriter` callbacks (e.g., `on_agent_handoff`).
- Persist handoff payloads as JSON for inspection:
  - `knowledge_base/test_artifacts/<run_id>/handoffs/<timestamp>-<from>_to_<to>.json`

### D) Override scoping

- No registry mutation/global overrides.
- Apply overrides only via `AiWorkflowService.run(..., test_overrides: {...})`.

---

## Acceptance criteria

- AC1: Coordinator breaks PRD into micro-tasks with overrides applied.
- AC2: `payload["micro_tasks"]` is non-empty and meets minimal schema.
- AC3: Handoff JSON payloads are recorded to filesystem.
- AC4: Logs show a coherent communication chain.
- AC5: Coordinator-focused runs can start at `in_analysis` via `--stage=in_analysis`.
- AC6: No cross-run override leakage.

---

## Test cases

- Unit (RSpec): override parsing + micro-task schema validation
- Integration: mock agents; assert payload updates + handoff capture
