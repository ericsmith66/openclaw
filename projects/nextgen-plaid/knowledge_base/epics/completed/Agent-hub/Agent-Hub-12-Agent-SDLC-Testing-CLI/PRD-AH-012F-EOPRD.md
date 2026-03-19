### What I did for `PRD-AH-012F-end-to-end-autonomous-run.md`

#### Feature branch
- Created and worked on branch: `PRD-AH-012F-end-to-end-autonomous-run`
- Latest commit (code): `65b359d` (`PRD-AH-012F: end-to-end mode + planner overrides`)

#### Implemented (core PRD-AH-012F behavior)

##### New CLI flags (parsed + validated)
- `--mode=end_to_end|stage`
  - Default: `end_to_end`
  - `stage` mode preserves prior “single-stage / forced start-agent” behaviors
- Planner overrides:
  - `--prompt-planner=<path>` (markdown/plain text)
  - `--rag-planner=<tiers>` (comma-separated: `foundation,structure,history`)
  - `--model-planner=<model>`

##### End-to-end run semantics
- `--mode=end_to_end` runs the **normal autonomous** workflow (SAP → Coordinator → Planner → CWA) and relies on real handoffs/routing.
- Guardrails added for end-to-end runs:
  - `micro_tasks` must exist once the artifact reaches (or passes) `in_analysis`.
  - When `--sandbox-level=loose`, `implementation_notes` must be present.

##### Required outputs / artifacts
Per-run log directory: `knowledge_base/logs/cli_tests/<run_dir>/`

- Logs:
  - `cli.log`
  - `sap.log`
  - `coordinator.log`
  - `planner.log` (new)
  - `cwa.log` (when CWA runs)

- Test artifacts:
  - `test_artifacts/prd.md`
  - `test_artifacts/prd_versions/` (created when `prd.md` is rewritten)
  - `test_artifacts/micro_tasks.json` (written for `--mode=end_to_end`)
  - `test_artifacts/plan_summary.md` (written for `--mode=end_to_end` when tasks exist)
  - `test_artifacts/execution_summary.md` (written for `--mode=end_to_end` when `cwa_summary.md` exists)

- Validation + scoring (PRD-AH-012E):
  - `knowledge_base/test_artifacts/<run_id>/validation.json`
  - `knowledge_base/test_artifacts/<run_id>/run_summary.md`
  - `knowledge_base/logs/cli_tests/<run_dir>/summary.log`
  - Artifact DB payload append-only: `artifact.payload["score_attempts"] << { timestamp, score, pass, rubric, ... }`

#### Key files changed
- `lib/agents/sdlc_test_options.rb` (added `--mode`, Planner flags)
- `lib/tasks/agent_test_sdlc.rake` (end-to-end mode wiring, new logs/artifacts, guardrails)
- `app/services/ai_workflow_service.rb` (per-agent model overrides; Planner prompt/RAG injection)

#### Prompt templates referenced
Defaults and suggested overrides live in `knowledge_base/prompts/`:
- SAP PRD prompt (ERB): `knowledge_base/prompts/sap_prd.md.erb`
- Coordinator analysis prompt (ERB): `knowledge_base/prompts/coord_analysis.md.erb`
- CWA execution prompt (ERB): `knowledge_base/prompts/cwa_execution.md.erb`
- Planner prompt (new for 012F examples): `knowledge_base/prompts/planner_breakdown.md`

> Note: Planner’s default prompt is built in-code, but `--prompt-planner` lets you append/override additional instructions.

---

### How to run an end-to-end autonomous test (recommended example)

#### Prerequisites

1) Start SmartProxy (required; tool-capable models route via `http://localhost:3002`)
```bash
cd smart_proxy
SMART_PROXY_PORT=3002 bundle exec rackup -o 0.0.0.0 -p 3002
curl http://localhost:3002/health
```

2) Enable tool execution
```bash
export AI_TOOLS_EXECUTE=true
```

#### A realistic input string that should *actually build*

This request is intentionally scoped so the agent can likely implement it inside this repo:

```
Add an admin page at /admin/ai_workflow_runs that lists the 50 most recent AiWorkflowRuns with columns: correlation_id, status, created_at, updated_at, and active_artifact_id. Add filters for status and a text search for correlation_id. Include a show page at /admin/ai_workflow_runs/:id showing metadata JSON and linked_artifact_ids. Add request specs or system tests to cover the index and show pages.
```

Why this is a good end-to-end test:
- It forces PRD generation (SAP), planning (Coordinator/Planner), and concrete code changes + tests (CWA).
- It touches typical Rails primitives: routes/controllers/views, queries, and tests.

#### Recommended command (end-to-end mode; explicit prompts referenced)
```bash
AI_TOOLS_EXECUTE=true rake agent:test_sdlc -- \
  --run-id=$(ruby -e 'require "securerandom"; puts SecureRandom.uuid') \
  --mode=end_to_end \
  --input="Add an admin page at /admin/ai_workflow_runs that lists the 50 most recent AiWorkflowRuns with columns: correlation_id, status, created_at, updated_at, and active_artifact_id. Add filters for status and a text search for correlation_id. Include a show page at /admin/ai_workflow_runs/:id showing metadata JSON and linked_artifact_ids. Add request specs or system tests to cover the index and show pages." \
  --prompt-sap=knowledge_base/prompts/sap_prd.md.erb \
  --prompt-coord=knowledge_base/prompts/coord_analysis.md.erb \
  --prompt-planner=knowledge_base/prompts/planner_breakdown.md \
  --prompt-cwa=knowledge_base/prompts/cwa_execution.md.erb \
  --rag-sap=foundation,structure \
  --rag-coord=foundation,structure \
  --rag-planner=foundation,structure \
  --rag-cwa=tier-1 \
  --sandbox-level=loose \
  --max-tool-calls=250 \
  --model-sap=llama3.1:70b \
  --model-coord=llama3.1:70b \
  --model-planner=llama3.1:70b \
  --model-cwa=grok-4-latest
```

Expected outputs:
- `knowledge_base/logs/cli_tests/<run_dir>/planner.log`
- `knowledge_base/logs/cli_tests/<run_dir>/test_artifacts/micro_tasks.json`
- `knowledge_base/test_artifacts/<run_id>/validation.json`
- `knowledge_base/test_artifacts/<run_id>/run_summary.md`

---

### How to score it (example)

Scoring is computed in `Agents::SdlcValidationScoring` and written to:
- `knowledge_base/test_artifacts/<run_id>/validation.json`

#### Scoring rubric (current)
Total score is capped to `10` and pass threshold is `>= 7`.

Points:
- `micro_tasks_valid`: `2` if valid (array, each task has `id/title/estimate`)
- `prd_present`: `1` if `test_artifacts/prd.md` exists
- `handoffs_present`: `1` if handoff evidence exists
- `implementation_notes_present`: `2` if `artifact.payload["implementation_notes"]` present
- `tests_green`: `3` if `cwa_summary.md` excerpt indicates tests are green
- `no_errors`: `1` if no error was recorded

#### Example `validation.json` excerpt (what “passing” looks like)
```json
{
  "run_id": "my_run_003",
  "validation": {
    "micro_tasks": { "valid": true, "errors": [] },
    "handoffs": { "valid": true, "errors": [] }
  },
  "scoring": {
    "score": 10,
    "pass": true,
    "rubric": {
      "micro_tasks_valid": 2,
      "prd_present": 1,
      "handoffs_present": 1,
      "implementation_notes_present": 2,
      "tests_green": 3,
      "no_errors": 1
    },
    "notes": []
  }
}
```

#### Example of a “barely passing” score
If tests didn’t run (or didn’t look green), you might still pass if the rest is good:

```json
{
  "scoring": {
    "score": 7,
    "pass": true,
    "rubric": {
      "micro_tasks_valid": 2,
      "prd_present": 1,
      "handoffs_present": 1,
      "implementation_notes_present": 2,
      "tests_green": 0,
      "no_errors": 1
    },
    "notes": ["tests did not appear green"]
  }
}
```

#### Where the score is stored in the DB (append-only)
The same attempt is appended into the artifact:
- `artifact.payload["score_attempts"]` (array)

Example element:
```json
{
  "timestamp": "2026-01-13T18:22:10Z",
  "score": 10,
  "pass": true,
  "rubric": {
    "micro_tasks_valid": 2,
    "prd_present": 1,
    "handoffs_present": 1,
    "implementation_notes_present": 2,
    "tests_green": 3,
    "no_errors": 1
  }
}
```
