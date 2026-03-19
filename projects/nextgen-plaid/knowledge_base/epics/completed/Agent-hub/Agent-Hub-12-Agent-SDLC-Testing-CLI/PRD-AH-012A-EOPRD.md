### Progress update (PRD-AH-012A)

Implemented the CLI base feature on branch `feature/PRD-AH-012A-cli-base`.

#### What’s in place
- New rake task: `rake agent:test_sdlc -- [flags]`
- Options parsing extracted into PORO: `Agents::SdlcTestOptions.parse(argv)`
    - Validates required `--input` unless `--dry-run`
    - Validates model flags against offline allowlist in `config/ai_models.yml`
    - `--help` prints full usage + examples
- Structured JSON logging to:
    - `knowledge_base/logs/cli_tests/<run_id>/cli.log`
- DB + state:
    - Creates `Artifact` in `backlog` (owner SAP) and injects `payload["test_correlation_id"]`
    - Creates `AiWorkflowRun` linked by new `ai_workflow_runs.correlation_id`
    - Added migration `AddCorrelationIdToAiWorkflowRuns`
- `test_mode` support:
    - Added `Ai::TestMode` and suppressed ActionCable broadcasts when enabled
    - `AiWorkflowService` can now resolve runs by either numeric `id` or string `correlation_id`
- `--dry-run` semantics:
    - No LLM/tool calls (does not invoke `AiWorkflowService`)
    - Injects synthetic payloads (`content`, `micro_tasks`, `implementation_notes`)
    - Advances the Artifact through phases to `complete`
- Tests:
    - Minitest unit tests for option parsing
    - Integration test verifying `AiWorkflowRun` resolution via `correlation_id`

### How to run
1. Run migrations:
```bash
bin/rails db:migrate
```

2. Run a dry-run (fast, no LLM/tools):
```bash
USER_EMAIL=ericsmith66@me.com rake agent:test_sdlc -- --dry-run
```

3. Run a real invocation (LLM/tools enabled; still uses `test_mode` to suppress broadcasts):
```bash
USER_EMAIL=ericsmith66@me.com rake agent:test_sdlc -- --input="Run SDLC test"
```

Logs will be under:
- `knowledge_base/logs/cli_tests/<run_id>/cli.log`
- `knowledge_base/logs/cli_tests/<run_id>/run_summary.md`

### Next step
If you want, I can now:
- run the rake task end-to-end locally to confirm AC6 (< 1 minute) for `--dry-run`, and/or
- refine stage fast-forward semantics (if the epic defines a different mapping than repeated `approve` transitions).