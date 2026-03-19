# PRD-AH-012F: End-to-End Autonomous SDLC Run (SAP → Coordinator → Planner → CWA → Validation)

Part of Epic AH-012: Agent SDLC Testing CLI.

---

## Overview

Add a **single-command** CLI mode that runs the full SDLC workflow **end-to-end** using the real agent **routing and handoffs**:

- SAP produces a PRD (and hands off when appropriate)
- Coordinator orchestrates and assigns work
- Planner breaks down into micro-tasks (when used)
- CWA executes implementation tasks (when tools are enabled)
- Validation + scoring finalize the run

This PRD complements (does not replace) the stage-isolated test modes from `PRD-AH-012B`/`PRD-AH-012C`/`PRD-AH-012D`.

---

## Goals

- Provide a repeatable **end-to-end** autonomous run that exercises the actual orchestration logic and agent handoffs.
- Persist durable evidence (DB + filesystem) for later inspection and scoring in the same directory.
- Do not overwrite existing evidence.
- Make runs **actionable and diagnosable**: logs, run summary, validation details, clear failure evidence.
- Keep stage-isolated modes for prompt/agent tuning, but add a first-class full pipeline mode.

---

## Non-Goals

- Building a full “matrix runner” that enumerates prompt/model permutations (users can script multiple runs externally).
- Guaranteeing that models always make perfect routing decisions without guardrails.
- Replacing UI-driven workflow controls in Agent Hub.

---

## Key Concepts

### A) End-to-end mode vs stage-isolated mode

- **End-to-end mode**: prefer real routing and handoffs to test orchestration realism.
  - Guardrails prevent “SAP answered directly” from skipping required phases.
- **Stage-isolated mode**: start-at-agent determinism (entry agent matches stage owner) to maximize reliability for phase-specific testing.

### B) Guardrails in end-to-end mode

End-to-end mode must still produce consistent artifacts for evaluation. Guardrails must:

- Detect missing expected outputs (PRD content, micro_tasks, etc.) and attempt a bounded recovery.
- Fail fast with high-quality evidence if recovery fails.
- Avoid infinite retry loops.

---

## Logging requirements

Read: `knowledge_base/prds/prds-junie-log/junie-log-requirement.md`.

Required logs and evidence under the run directory:

- `knowledge_base/logs/cli_tests/<run_dir>/cli.log`
- `knowledge_base/logs/cli_tests/<run_dir>/sap.log`
- `knowledge_base/logs/cli_tests/<run_dir>/coordinator.log`
- `knowledge_base/logs/cli_tests/<run_dir>/planner.log` (new)
- `knowledge_base/logs/cli_tests/<run_dir>/cwa.log` (from `012D`)
- `knowledge_base/logs/cli_tests/<run_dir>/summary.log` (from `012E`)

Primary human-readable output:

- `knowledge_base/logs/cli_tests/<run_dir>/run_summary.md`

Run artifacts output directory (within run dir):

- `knowledge_base/logs/cli_tests/<run_dir>/test_artifacts/`
- if prd is modifed allong the way store multiple versions in this directory

---

## Functional requirements

### A) New CLI flags / run mode

Add a concept of run mode or flow selection:

- `--mode=end_to_end` (new; default for this PRD)
- `--mode=stage` (existing behavior; phase-based entry)

Defaults:

- In `end_to_end` mode, default `--stage=backlog`.
- In `stage` mode, continue to respect `--stage=<artifact_phase>`.

Compatibility:

- Existing flags for prompts/models/RAG remain and apply per agent:
  - SAP: `--prompt-sap`, `--model-sap`, `--rag-sap`
  - Coordinator: `--prompt-coord`, `--model-coord`, `--rag-coord`
  - Planner: `--prompt-planner`, `--model-planner`, `--rag-planner` (new)
  - CWA: `--prompt-cwa`, `--model-cwa`, `--rag-cwa` (from `012D`)

### B) End-to-end phase progression

The end-to-end run should:

1. Create a new `Artifact` and `AiWorkflowRun`.
2. Start at backlog using SAP as initial entry.
3. Allow real routing/handoffs to proceed:
   - SAP → Coordinator
   - Coordinator → Planner (recommended for micro-task breakdown)
   - Planner → CWA
4. Ensure the artifact transitions and payload updates occur via existing orchestration (preferred path: `AgentHub::WorkflowBridge` / `Artifact#transition_to` as already used).

### C) Guardrails to prevent skipping phases

End-to-end mode must include **bounded guardrails** when expected outputs are missing.

Required checks (minimum viable):

- **PRD guardrail**: After SAP completes initial response(s), require `artifact.payload["content"]` to be present and shaped as a PRD.
  - If missing/invalid: retry once with strict format lock (minimized RAG) as already implemented in the SAP runner.

- **Analysis guardrail**: When phase reaches `in_analysis`, require `artifact.payload["micro_tasks"]` to be a non-empty array with minimal schema.
  - If missing/empty:
    - allow one additional turn/attempt prompting Coordinator/Planner to produce `micro_tasks`
    - if still missing: fail with explicit error `micro_tasks_missing_after_guardrail`

- **Development guardrail** (when tools are enabled / `sandbox-level=loose`): require `artifact.payload["implementation_notes"]` to be present and include evidence of tests/diff summary.
  - If missing: fail with explicit error `implementation_notes_missing`

Boundaries:

- Each guardrail may retry at most once.
- Guardrails must log:
  - check name
  - observed state
  - action taken
  - final outcome

### D) Output artifacts written under run directory

Required files under `knowledge_base/logs/cli_tests/<run_dir>/test_artifacts/`:

- `prd.md` (from `012B`)
- `plan_summary.md` (from `012C`)
- `handoffs/*.json` (from `012C`)
- `cwa_summary.md` (from `012D`)
- `validation.json` (from `012E`)

### E) Validation and scoring integration

End-to-end mode must invoke the `012E` validation/scoring after the workflow run completes (or fails).

- On pass (score `>= 7`): transition artifact to `complete`.
- On fail: preserve evidence, do not mark complete, surface failure evidence in summary.
- Append score attempts to `artifact.payload["score_attempts"]` without overwriting prior attempts.

### F) Failure readability requirements

Even when the run fails, produce:

- `run_summary.md` with:
  - last phase reached
  - last error class/message
  - links to the most relevant logs (`cli.log`, `summary.log`, plus agent logs)
  - list of events triggered

---

## Acceptance criteria

- AC1: A single CLI invocation in `end_to_end` mode runs the workflow using real routing/handoffs (SAP → Coordinator → Planner → CWA when applicable).
- AC2: End-to-end mode produces durable evidence (DB + filesystem outputs) in the run directory.
- AC3: Guardrails prevent silent “phase skipping”; missing PRD/micro_tasks/implementation_notes fail with clear errors and evidence.
- AC4: Validation/scoring runs and writes `validation.json` and updates `artifact.payload["score_attempts"]`.
- AC5: On score pass (`>= 7`) the artifact transitions to `complete`; on fail it does not.
- AC6: Failure runs still produce readable `run_summary.md` and preserve logs.

---

## Test strategy

- Integration tests:
  - Stub `AiWorkflowService.run` to simulate a realistic handoff chain and payload updates.
  - Assert end-to-end mode writes expected logs and files.
  - Assert guardrails trigger when missing micro_tasks and fail with the right error.
- Unit tests:
  - Validate option parsing for `--mode` and Planner flags.
  - Validate schema checks for `micro_tasks` and handoff payloads (as needed by `012E`).

---

## Open questions

1. Should Planner be mandatory for end-to-end runs, or optional if Coordinator can produce `micro_tasks` directly?
2. What is the minimal deterministic definition of “CWA success” when tools are disabled (`sandbox-level=strict`)?
3. Should end-to-end mode allow a configurable max-turns budget distinct from stage runs?

---

## Preferred CLI syntax (end-to-end run for a PRD)

Preferred approach: start from a PRD already stored in the `artifacts` table and run the full SDLC flow end-to-end.

```bash
rake agent:test_sdlc -- \
  --mode=end_to_end \
  --stage=backlog \
  --artifact-id=<PRD_ARTIFACT_ID> \
  --input="Run end-to-end SDLC for the linked PRD" \
  --model-sap="llama3.1:70b" \
  --rag-sap="foundation,structure" \
  --prompt-sap="knowledge_base/prompts/sap_prd.md.erb" \
  --model-coord="llama3.1:70b" \
  --rag-coord="foundation,structure" \
  --prompt-coord="knowledge_base/prompts/coord_analysis.md.erb" \
  --sandbox-level=loose
```

Notes:

- `--artifact-id=<PRD_ARTIFACT_ID>` references an existing PRD record in the `artifacts` table and uses `payload["content"]` as the PRD source of truth.
- `--sandbox-level=loose` is required for any run that expects CWA tool execution (git/tests). Use `--sandbox-level=strict` for orchestration-only validation.
- All run evidence is written under:
  - `knowledge_base/logs/cli_tests/<run_dir>/`
  - `knowledge_base/logs/cli_tests/<run_dir>/test_artifacts/`
