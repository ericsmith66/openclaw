# PRD-AH-012D: CWA Execution and Variation with Development Phases

Part of Epic AH-012: Agent SDLC Testing CLI.

---

## Overview

Integrate CLI for CWA execution in development phases, varying prompts/models/RAG/tools, enforcing guardrails, and storing diffs/notes in DB and filesystem.

---

## Logging requirements

Read: `knowledge_base/prds/prds-junie-log/junie-log-requirement.md`.

Log tool calls and outcomes to:

- `knowledge_base/logs/cli_tests/<run_id>/cwa.log`

---

## Functional requirements

### A) New flags

- `--prompt-cwa=<path/to/custom.md.erb>`
- `--model-cwa=<model>`
- `--rag-cwa=<tiers>`
- `--sandbox-level=<strict|loose>`
- `--max-tool-calls=<int>`

Note: `--stage` is artifact-phase based only (see Epic/PRD-012A). For CWA-focused runs, use `--stage=in_development`.

### B) Sandbox levels

- `strict`:
  - Disable `GitTool` and `SafeShellTool` execution (raise on call).
  - Read-only context.
- `loose`:
  - Allow branch creation/commit/diff in a temp branch.
  - Allow shell execution for tests.

### C) Tool call counting

- Count per run (across all turns).
- Include git and shell invocations.
- Enforce via existing guardrails; allow override via `--max-tool-calls`.

### D) Storage

- Store implementation results in DB: `artifact.payload["implementation_notes"]`.
- Persist evidence to filesystem (paths defined in implementation; must be under `knowledge_base/test_artifacts/<run_id>/`).
- Persist a convenience summary for humans:
  - `knowledge_base/test_artifacts/<run_id>/cwa_summary.md`
  - Generated from `payload["implementation_notes"]` + tool events (high-level actions, tools used, outcomes, test summary, diff summary).

### E) Rollback

- Track temporary branches/files created during the run.
- Ensure cleanup occurs on run end (success or failure).

---

## Acceptance criteria

- AC1: CWA executes tasks with variations and produces files/notes.
- AC2: `strict` mode blocks tool execution.
- AC3: `loose` mode allows temp branch operations.
- AC4: Tool calls are logged and counted; guardrails enforced.
- AC5: Outputs persisted to DB + filesystem.
- AC6: Errors are flagged and logged.
- AC7: CWA-focused runs can start at `in_development` via `--stage=in_development`.

---

## Test cases

- Unit (RSpec): sandbox policy + tool call counter
- Integration: verify phase transitions and payload storage with mocked tools
