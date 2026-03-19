### Remaining work for the `PRD-AH-013G-spike` (actionable next steps)

You pushed the branch and (critically) we already proved the system can produce a **passing SDLC E2E run**. The remaining spike work is mainly **hardening + correctness + documentation**, so the spike is stable and repeatable.

#### 1) Post-push verification (quick but important)
1. Run the new unit tests that shipped with the spike commits:
    - `bundle exec rails test test/services/agents/tool_output_truncator_test.rb`
    - `bundle exec rails test test/services/agents/sdlc_stage_contracts_test.rb`
2. Run the existing rake-task test that should assert `run_summary.json` exists:
    - `bundle exec rails test test/tasks/agent_test_sdlc_rake_test.rb`

**Why:** ensures the spike additions (truncation/contracts/run summary emission) are green in CI.

#### 2) Gate the risky monkeypatch (recommended hardening)
File: `config/initializers/agents_runner_handoff_context_patch.rb`
- Add an env guard so it only applies when explicitly enabled, e.g.:
    - `AI_ENABLE_HANDOFF_CONTEXT_PATCH=true`
- Default should be **off**.

**Why:** this patch replaces core runner behavior; gating reduces risk outside SDLC test runs.

#### 3) Fix `run_summary.json` classification for successful runs
File: `app/services/agents/sdlc_run_summary.rb`
- Right now `classify(...)` returns `provider_bad_request_other` as a default even when there is **no error**.
- Update classification to return something explicit like:
    - `success` (preferred) or `none`
      when `error_class/error_message/workflow_error_class/workflow_error` are all blank.

**Why:** it prevents analytics from treating successful runs as failures.

#### 4) Tighten “global truncation” consistency
We added `Agents::ToolOutputTruncator` and applied it to several tools.
Actionable check:
- Ensure every tool that returns stdout/stderr (and ends up in `tool_complete` events) includes the same fields:
    - `stdout_bytes`, `stderr_bytes`, `stdout_truncated`, `stderr_truncated`
- If any tool is missing these fields, patch it and add a small unit test.

**Why:** ensures `run_summary.json` telemetry (`max_output_bytes_by_tool`) is trustworthy.

#### 5) Add a short runbook entry (so others can reproduce)
Add a short doc (even a section in the spike PRD or `knowledge_base/...`) covering:
- Required env vars for local SDLC runs:
    - `PROXY_AUTH_TOKEN`
    - `OLLAMA_URL`, `OLLAMA_TAGS_URL`
    - `OLLAMA_HOST` if needed
- Restart procedure:
    - `bin/dev` (since it controls SmartProxy)
- “Known scoring caveat”:
    - a run can pass at `7/10` with `tests_green: 0` (current state)

**Why:** makes the spike actually usable by another engineer without tribal knowledge.

#### 6) Re-assessment checkpoint (baseline)
Run one representative E2E SDLC run and record:
- `run_summary.json`
- `run_summary.md`
- the score + any rubric misses

**Why:** establishes a baseline for future improvements (out of scope) like Ollama tool parity.

---

### If you want the “minimum remaining” list
If you want the smallest set that I’d still consider necessary to call the spike “done”:
1) Gate the runner monkeypatch
2) Fix `run_summary.json` classification on success
3) Add the runbook snippet
4) Run the 3 tests above

If you want, I can implement (2) + (3) + (4) as a small follow-up commit on the spike branch.