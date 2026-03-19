# PRD-AH-012E: Validation, Scoring, and QA/Completion Phases

Part of Epic AH-012: Agent SDLC Testing CLI.

---

## Overview

Add post-processing validation and scoring for end-to-end CLI runs, persisting results to filesystem and finalizing DB state.

---

## Logging requirements

Read: `knowledge_base/prds/prds-junie-log/junie-log-requirement.md`.

Aggregate a summary to:

- `knowledge_base/logs/cli_tests/<run_id>/summary.log`

Also write run outputs under:

- Primary human-readable report (Markdown): `knowledge_base/test_artifacts/<run_id>/run_summary.md`
- Machine-readable scoring/validation details (JSON): `knowledge_base/test_artifacts/<run_id>/validation.json`

---

## Functional requirements

### A) Validation

- Validate communications/handoffs against simple schemas.
- Define schemas under:
  - `knowledge_base/schemas/`
  - examples:
    - `micro_tasks.json_schema`
    - `handoff.json_schema`
- Validation approach can be `JSON::Validator` gem or simple deterministic hash checks.

### B) Deterministic rubric + optional LLM scoring

- Compute a base score using a deterministic checklist (example signals):
  - micro_tasks present and minimally valid
  - tests reported green (if tools enabled)
  - implementation_notes populated
- Optionally request a justification/adjustment from Ollama.
- Threshold: score `>= 7` is a pass.

### C) Persistence

- Persist summary and validation/scoring artifacts under `<run_id>` directories.

Required filesystem outputs under `knowledge_base/test_artifacts/<run_id>/`:

- `run_summary.md` (primary report; see required structure below)
- `validation.json` (machine-readable scoring + validation details)

Note: phase-specific artifacts remain owned by their PRDs (e.g., `prd.md`, `micro_tasks.json`, `handoffs/`, `code_diffs/`).

#### Required structure for `run_summary.md`

`run_summary.md` MUST be a Markdown document with (at minimum) the following sections:

- Run metadata (run_id, timestamps, duration, final phase/status)
- CLI arguments / variations used
- Phase progression timeline
- Generated PRD (either embedded in full OR linked to `prd.md` if too long)
- Coordinator plan (micro_tasks) summary and completion counts
- CWA execution summary (tools used, outcomes, test results summary, diff summary)
- Scoring + suggestions (overall score and rubric breakdown)
- LLM usage stats (models used, approximate turns/calls)

Failure readability requirement:

- Include an **Errors / Escalations / Failure Evidence** section containing:
  - last phase reached
  - last exception class/message (if any)
  - pointers/links to the most relevant log files (at minimum `logs/cli.log` and `summary.log`)

If the PRD content is extremely large, prefer linking to `prd.md` and include a short excerpt instead.

- Append scoring attempts to DB payload:
  - `artifact.payload["score_attempts"]` is an array
  - each attempt includes timestamp, score, rubric breakdown, model (if used)
- Do not mutate/overwrite prior attempts.

### D) Phase finalization

- On pass: transition to `complete`.
- On fail: do not mark complete; log errors and keep evidence.

### E) Re-run support

- Support rescoring without rerunning the full workflow:
  - read existing filesystem/DB evidence for `<run_id>`
  - append a new score_attempt

---

## Acceptance criteria

- AC1: Validates handoffs/micro_tasks.
- AC2: Produces a score (0-10) and passes when `>= 7`.
- AC3: Writes `run_summary.md`, `validation.json`, and `summary.log` in `<run_id>` dirs.
- AC4: Persists score_attempts to artifact payload.
- AC5: Can re-run scoring without re-running agents.
- AC6: Errors are logged and do not erase prior evidence.

---

## Test cases

- Unit (RSpec): rubric scoring + schema validation
- Integration: run CLI flow (or simulate via service) and assert summary artifacts + phase updates
