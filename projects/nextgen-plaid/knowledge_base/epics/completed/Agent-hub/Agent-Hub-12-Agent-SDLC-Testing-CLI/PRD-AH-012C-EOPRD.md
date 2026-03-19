### Feature branch created
- Branch: `feature/PRD-AH-012C-coordinator-analysis`
- Commit: `7783f8f`

### Implemented requirements from `PRD-AH-012C-coordinator-analysis.md`

#### New CLI flags
- Added:
  - `--prompt-coord=<path/to/custom.md.erb>`
  - `--rag-coord=<tiers>` (comma-separated)
  - `--artifact-id=<id>` (use an existing `Artifact` record as the PRD source; uses `payload["content"]`)
- Coordinator model selection (already supported / used):
  - `--model-coord=<model>`
- Existing and used:
  - `--input="<query>"`
  - `--stage=<artifact_phase>` (Coordinator-focused runs use `--stage=in_analysis`)
  - `--debug`

#### Logging (`coordinator.log`)
- Per-run coordinator log is written to:
  - `knowledge_base/logs/cli_tests/<run_dir>/coordinator.log`
- Includes:
  - resolved coordinator prompt
  - model
  - rag tiers + truncation metadata
  - errors (when present)

#### Coordinator analysis behavior (`--stage=in_analysis`)
- Stage isolation support:
  - when starting directly at `in_analysis`, injects a PRD into `artifact.payload["content"]` if it is missing:
    - preferred: `--artifact-id=<id>` (loads the PRD from `Artifact.find(id).payload["content"]`)
    - fallback: `--prd-path=<path/to/prd.md>` (loads PRD markdown from disk)
    - else: injects a minimal synthetic PRD stub
- Runs the workflow using the Coordinator model/prompt for analysis-task generation.

#### Micro-tasks persistence
- Stores micro-tasks into:
  - `artifact.payload["micro_tasks"]`
- Micro-tasks are captured from `result.context["micro_tasks"]` / `result.context[:micro_tasks]` when not already present on the artifact.
- Writes a human-friendly plan view:
  - `knowledge_base/logs/cli_tests/<run_dir>/test_artifacts/plan_summary.md`
  - Format: Markdown checklist derived from `payload["micro_tasks"]`.

#### Handoff capture
- Reads workflow evidence from:
  - `agent_logs/ai_workflow/<run_id>/events.ndjson`
- Snapshots `agent_handoff` events as JSON files under:
  - `knowledge_base/logs/cli_tests/<run_dir>/test_artifacts/handoffs/<timestamp>-<from>_to_<to>.json`

#### Override scoping
- Overrides are applied per-run via `AiWorkflowService.run(..., test_overrides: {...})`.
- No registry mutation / global override leakage.

### Run summary improvements
- `run_summary.md` now includes Coordinator events (from `coordinator.log`) and will surface coordinator errors when present.

### How to run
Example:
```bash
rake agent:test_sdlc -- \
  --stage=in_analysis \
  --input="Analyze PRD and break into micro-tasks" \
  --artifact-id=45 \
  --model-coord="llama3.1:70b" \
  --rag-coord="foundation,structure" \
  --prompt-coord="knowledge_base/prompts/coord_analysis.md.erb" \
  --model-sap="llama3.1:70b"
```

Fallback (when you only have a file on disk, not an Artifact id):
```bash
rake agent:test_sdlc -- \
  --stage=in_analysis \
  --input="Analyze PRD and break into micro-tasks" \
  --prd-path="knowledge_base/logs/cli_tests/<run_dir>/test_artifacts/prd.md" \
  --model-coord="llama3.1:70b" \
  --rag-coord="foundation,structure" \
  --prompt-coord="<path/to/coord_prompt.md.erb>" \
  --model-sap="llama3.1:70b"
```

Outputs:
- `knowledge_base/logs/cli_tests/<run_dir>/cli.log`
- `knowledge_base/logs/cli_tests/<run_dir>/coordinator.log`
- `knowledge_base/logs/cli_tests/<run_dir>/run_summary.md`
- `knowledge_base/logs/cli_tests/<run_dir>/test_artifacts/plan_summary.md`
- `knowledge_base/logs/cli_tests/<run_dir>/test_artifacts/handoffs/*.json` (when handoffs occur)

### Tests added/updated
- Updated:
  - `test/services/agents/sdlc_test_options_test.rb`
  - `test/tasks/agent_test_sdlc_rake_test.rb`

Run:
```bash
bin/rails test \
  test/services/agents/sdlc_test_options_test.rb \
  test/tasks/agent_test_sdlc_rake_test.rb
```

### Next step
- Push and open PR:
  - `git push -u origin feature/PRD-AH-012C-coordinator-analysis`
