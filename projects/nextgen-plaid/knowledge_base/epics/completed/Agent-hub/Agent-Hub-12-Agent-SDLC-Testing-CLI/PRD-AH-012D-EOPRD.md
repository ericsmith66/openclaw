### What I did for `PRD-AH-012D-cwa-execution.md`

#### Feature branch
- Created and worked on branch: `ah-012d-cwa-execution`
- Latest commit: `f00adb6` (`PRD-AH-012D: CWA execution guardrails, logs, and sandbox rollback`)

#### Implemented (core PRD-AH-012D behavior)
- **New CLI flags** (parsed + validated):
    - `--prompt-cwa=<path>`
    - `--rag-cwa=none|tier-1|tier-2`
- **Sandbox enforcement**:
    - `sandbox_level=strict` blocks `GitTool` and `SafeShellTool` (returns `{ action: "blocked", reason: "sandbox_strict" }`).
    - `sandbox_level=loose` allows tool usage (as before).
- **Per-run tool-call guardrail**:
    - Implemented `max_tool_calls_total` (wired from `--max-tool-calls`).
    - Enforced in both `GitTool` and `SafeShellTool`.
- **CWA execution logging + summary**:
    - `knowledge_base/logs/cli_tests/<run_dir>/cwa.log` (NDJSON tool start/complete events)
    - `knowledge_base/test_artifacts/<run_id>/cwa_summary.md` (markdown snapshot generated from `Ai::CwaTaskLogService`)
- **Rollback / cleanup**:
    - Added `AgentSandboxRunner.cleanup_worktree!`.
    - `agent:test_sdlc` calls cleanup in an `ensure` block to avoid leaving sandbox worktrees behind.

#### Key files changed
- `lib/agents/sdlc_test_options.rb` (added `--prompt-cwa`, `--rag-cwa`)
- `lib/tasks/agent_test_sdlc.rake` (passes `cwa.log`/`cwa_summary.md` paths + CWA overrides; ensures cleanup)
- `app/services/ai_workflow_service.rb` (uses `prompt_cwa`/`rag_cwa`; emits cwa log + summary)
- `app/tools/git_tool.rb`, `app/tools/safe_shell_tool.rb` (strict sandbox blocking + per-run tool-call cap)
- `app/services/agent_sandbox_runner.rb` (added cleanup helper)

#### Tests
- Updated/added:
    - `test/tools/git_tool_test.rb`
    - `test/tools/safe_shell_tool_test.rb`
- Also ran (green):
    - `test/services/ai_workflow_service_test.rb`
    - `test/services/ai_workflow_service_broadcast_test.rb`
    - `test/services/ai_workflow_service_planner_test.rb`

### About the requested `PRD-AH-012C-EOPRD.md`
`knowledge_base/epics/Agent-hub/Agent-Hub-12-Agent-SDLC-Testing-CLI/PRD-AH-012C-EOPRD.md` already exists and appears complete (includes branch, implemented requirements, run commands, and tests). I did not overwrite it.

### Next steps (to open the PR)
```bash
cd /Users/ericsmith66/Development/nextgen-plaid
git push -u origin ah-012d-cwa-execution
```
Then open a PR targeting your main branch.

### How to test (using `Artifact` 45)

#### Prerequisites

1) Start SmartProxy (required; the CLI expects `http://localhost:3002`)
```bash
cd smart_proxy
SMART_PROXY_PORT=3002 bundle exec rackup -o 0.0.0.0 -p 3002
```

Health check:
```bash
curl http://localhost:3002/health
```

2) Enable tool execution (otherwise tools return `dry_run` and `cwa.log` may not be created)
```bash
export AI_TOOLS_EXECUTE=true
```

3) Recommended CWA model for tool calling

For CWA execution runs, use `--model-cwa=grok-4-latest` (tool-calling-capable via SmartProxy).

#### Option A: Analysis-only run (Coordinator; validates `--artifact-id` wiring)
```bash
rake agent:test_sdlc -- \
  --stage=in_analysis \
  --input="Analyze PRD and break into micro-tasks" \
  --artifact-id=45 \
  --model-coord="llama3.1:70b" \
  --rag-coord="foundation,structure" \
  --model-sap="llama3.1:70b"
```

Expected outputs:
- `knowledge_base/logs/cli_tests/<run_dir>/coordinator.log`
- `knowledge_base/logs/cli_tests/<run_dir>/test_artifacts/plan_summary.md`

#### Option B: Full run with CWA logging enabled (PRD-AH-012D)
> Note: `sandbox_level=strict` will block `GitTool`/`SafeShellTool`. Use `--sandbox-level=loose` if you want to allow tool execution.

```bash
rake agent:test_sdlc -- \
  --start-agent=CWA \
  --artifact-id=45 \
  --input="Execute micro_tasks T-001 through T-003. For each: implement code changes and run relevant tests. Provide progress updates." \
  --sandbox-level=loose \
  --max-tool-calls=250 \
  --rag-cwa=tier-1 \
  --model-cwa=grok-4-latest
```

Notes:
- `--start-agent=CWA` forces the workflow to begin at CWA (development execution) instead of the default SAP PRD-generation route.
- When `--start-agent=CWA` is used, the CLI expects the target artifact to already have:
  - `payload["content"]` (the PRD)
  - `payload["micro_tasks"]` (an array with at least 1 task)
- The CLI will attempt to fast-forward the artifact to `in_development` (via `approve` transitions) so the standard CWA loopback transition is valid.

Expected outputs (in addition to `cli.log`, `sap.log`, etc.):
- `knowledge_base/logs/cli_tests/<run_dir>/cwa.log`
- `knowledge_base/test_artifacts/<run_id>/cwa_summary.md`

#### CWA prompt template

The default CWA execution prompt is now externalized to:
- `knowledge_base/prompts/cwa_execution.md.erb`

Override it with:
- `--prompt-cwa=path/to/custom_cwa_execution.md.erb`
### Done: CWA prompt is now externalized + Artifact 45 can run to successful output

#### 1) Externalized CWA prompt
- Added default CWA execution prompt template:
  - `knowledge_base/prompts/cwa_execution.md.erb`
- Added renderer:
  - `lib/agents/sdlc_cwa_prompt_builder.rb`
- `rake agent:test_sdlc` now uses that template automatically for `--start-agent=CWA` (and still supports `--prompt-cwa=...` override).

#### 2) Ran Artifact 45 until a successful output
I reran Artifact 45 with SmartProxy running and tool execution enabled and got a clean run:
- Run dir: `knowledge_base/logs/cli_tests/260113-144105.421-verify-45-grok5-1768336864`
- `run_summary.md` shows:
  - `Errors: (none)`
  - `tool_start` / `tool_complete` events present
  - Plan artifacts written: `test_artifacts/plan_summary.md`, `test_artifacts/micro_tasks.json`
  - CWA summary written: `knowledge_base/test_artifacts/verify-45-grok5-1768336864/cwa_summary.md`

#### 3) Critical hardening to make CWA execution actually work
To get to a working run, I also had to:
- Seed workflow context with `micro_tasks` (not just include them in prompt)
- Allow `ProjectSearchTool` to search `config/` + `db/`
- Increase per-turn tool-call cap to 30 across tools used by CWA to avoid `max tool calls exceeded for turn 0`
- Allow tool-call-capable CWA model tags in `config/ai_models.yml`:
  - `grok-4`, `grok-4-latest`

#### 4) Docs updated
- Updated `knowledge_base/epics/Agent-hub/Agent-Hub-12-Agent-SDLC-Testing-CLI/PRD-AH-012D-EOPRD.md` with:
  - SmartProxy prerequisites + health check
  - `AI_TOOLS_EXECUTE=true`
  - Recommended command for Artifact 45 including `--model-cwa=grok-4-latest`
  - Default prompt path (`knowledge_base/prompts/cwa_execution.md.erb`)

#### 5) Commit
All changes are committed on `ah-012d-cwa-execution`:
- Commit: `ce2692d` (`PRD-AH-012D: externalize CWA prompt and harden CWA execution`)

### How you can run Artifact 45 now (exact command)
Start SmartProxy:
```bash
cd smart_proxy
SMART_PROXY_PORT=3002 bundle exec rackup -o 0.0.0.0 -p 3002
curl http://localhost:3002/health
```

Run:
```bash
AI_TOOLS_EXECUTE=true rake agent:test_sdlc -- \
  --run-id=$(ruby -e 'require "securerandom"; puts SecureRandom.uuid') \
  --start-agent=CWA \
  --artifact-id=45 \
  --input="Execute micro_tasks T-001 through T-003. For each: implement code changes and run relevant tests. Provide progress updates." \
  --sandbox-level=loose \
  --max-tool-calls=250 \
  --rag-cwa=tier-1 \
  --model-cwa=grok-4-latest
```

If you want, I can also add a **SmartProxy preflight** in `agent:test_sdlc` that fails fast with a clear message when `localhost:3002` is down (instead of Faraday’s raw connection error).
If you want the branch named to a specific convention (e.g., `feature/PRD-AH-012D-cwa-execution`), tell me the desired name and I can rename it using the proper refactoring tool/workflow.