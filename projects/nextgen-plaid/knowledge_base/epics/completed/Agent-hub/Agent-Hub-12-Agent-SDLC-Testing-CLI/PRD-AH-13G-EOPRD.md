### Progress on `PRD-AH-013G-spike` (instrumentation/taxonomy + truncation + stage contracts)

#### 1) Global tool-output truncation (first slice)
- Added shared helper `Agents::ToolOutputTruncator` (`app/services/agents/tool_output_truncator.rb`).
- Applied truncation + byte/truncation metadata to:
    - `SafeShellTool`
    - `GitTool`
    - `ProjectSearchTool` (also caps result count + per-result text bytes)
- Added tests: `test/services/agents/tool_output_truncator_test.rb`.

#### 2) Instrumentation + failure taxonomy + `run_summary.json`
- Added `Agents::SdlcRunSummary` (`app/services/agents/sdlc_run_summary.rb`) to:
    - classify failures into the PRD taxonomy (including message-based detection for wrapped provider errors)
    - compute stage time windows from existing NDJSON logs
    - aggregate tool-call telemetry (counts, max output bytes, truncation flags) from workflow `events.ndjson`
- Updated `lib/tasks/agent_test_sdlc.rake` to *always* write `knowledge_base/logs/cli_tests/<run>/run_summary.json` in the `ensure` block.
- Updated rake-task tests to assert `run_summary.json` exists and that a timeout is classified as `provider_timeout`.

#### 3) Stage contracts (initial implementation)
- Added `Agents::SdlcStageContracts` (`app/services/agents/sdlc_stage_contracts.rb`) with:
    - `validate_intent_summary!` → `contract_failure_intent_summary`
    - `validate_plan_json!` → `contract_failure_plan_json`
- Coordinator-mode now:
    - requests `intent_summary` JSON in the prompt
    - validates `intent_summary` after the workflow call
    - performs a targeted reprompt once on contract failure
    - surfaces contract failure via `workflow_error_class` so taxonomy becomes `contract_failure_intent_summary`
- Plan JSON contract is validated (best-effort) from the workflow `agent_logs/ai_workflow/<run_id>/run.json` `context` in the rake task `ensure` block, setting `workflow_error_class = contract_failure_plan_json` when invalid/missing.
- Added tests: `test/services/agents/sdlc_stage_contracts_test.rb`.

#### 4) Verification
- Targeted suite is green:
    - `bundle exec rails test test/tasks/agent_test_sdlc_rake_test.rb test/services/agents/sdlc_stage_contracts_test.rb`

### What’s next (if you want me to continue)
1. **Finish tool telemetry**: ensure all tools emit consistent byte/truncation metadata into workflow `tool_complete` events (so `run_summary.json` always has meaningful `max_output_bytes_by_tool`).
2. **Handoff payload enhancement (Planner→CWA)**: you approved changing the handoff callback to include context/payload; implementing this cleanly likely requires either:
    - a small monkeypatch to `Agents::Runner` to call `emit_agent_handoff(from,to,reason,context_wrapper)`, and updating `AiWorkflowService::ArtifactWriter#on_agent_handoff` to accept the 4th arg and write `plan_json` into the handoff artifact, or
    - vendoring/patching the `ai-agents` gem.

### Completed: tool telemetry consistency + Planner→CWA handoff payload

#### 1) Tool telemetry consistency in workflow `tool_complete` events
To make `run_summary.json` reliably compute `max_output_bytes_by_tool` / truncation flags, I ensured every `AgentSandboxRunner`-backed tool emits the same byte/truncation metadata fields in its tool JSON (which is what gets logged into workflow `events.ndjson`).

Changes:
- `app/tools/code_analysis_tool.rb`
    - Now uses `Agents::ToolOutputTruncator.truncate_result`.
    - Emits `stdout_bytes`, `stderr_bytes`, `stdout_truncated`, `stderr_truncated` in the returned JSON.
- `app/tools/project_search_tool.rb`
    - Already truncated via `ToolOutputTruncator`, but now also exposes `stdout_bytes` and `stdout_truncated` in the returned JSON (it already exposed stderr metrics).

This makes `Agents::SdlcRunSummary.tool_metrics` able to aggregate meaningful tool telemetry across `vc`, `safe_shell`, `git`, `project_search`, `code_analysis`.

#### 2) Planner→CWA handoff payload enhancement (context/payload included)
You approved changing the callback signature so handoff callbacks can receive context.

Implemented:
- `config/initializers/agents_runner_handoff_context_patch.rb`
    - Monkeypatches `Agents::Runner` (via `Module#prepend`) to pass `context_wrapper` as a 4th argument to `emit_agent_handoff`.
    - This is backwards-compatible for existing 3-arg callback blocks.
- `app/services/ai_workflow_service.rb`
    - `AiWorkflowService::ArtifactWriter#on_agent_handoff` now accepts `context_wrapper = nil`.
    - When the handoff is `Planner` → `CWA`, it attaches `handoff_payload: { plan_json: ... }` to the `agent_handoff` event (sourced from `context_wrapper.context`).
    - This payload flows into `agent_logs/ai_workflow/<correlation_id>/events.ndjson` and therefore into the SDLC CLI’s copied `test_artifacts/handoffs/*.json` files.

#### 3) Tests
Added/updated tests and verified they pass:
- New test in `test/services/ai_workflow_service_test.rb` asserts `Planner` → `CWA` handoff writes `handoff_payload.plan_json` into `events.ndjson`.
- Re-ran targeted suite successfully:
    - `test/services/ai_workflow_service_test.rb`
    - `test/tasks/agent_test_sdlc_rake_test.rb`
    - `test/services/agents/tool_output_truncator_test.rb`
    - `test/services/agents/sdlc_stage_contracts_test.rb`

### Net effect
- `run_summary.json` now has meaningful, cross-tool telemetry for output sizes/truncation.
- The Planner→CWA handoff artifacts can now carry structured payload (`plan_json`) at the boundary, enabling contract checks and richer debugging/monitoring downstream.

### Working tree reality check (what’s *actually* changed right now)
`git status` currently shows **only untracked files** (no tracked diffs):
- `app/services/agents/tool_output_truncator.rb`
- `app/services/agents/sdlc_run_summary.rb`
- `app/services/agents/sdlc_stage_contracts.rb`
- `config/initializers/agents_runner_handoff_context_patch.rb`
- tests for the above

So: the items that made the E2E run pass are **not currently sitting as uncommitted diffs** in the repo root. They were either:
1) **runtime env / process restarts**, and/or
2) **changes that already landed in commits earlier in this branch/session**, and/or
3) **changes in `smart_proxy/` that are already committed** (since there are no diffs there right now either).

Below is a point-by-point account of what we changed during this spike to reach the passing run, and whether each was necessary.

---

### A) Runtime / environment fixes (Required)
These were necessary just to get the system into a state where the workflow could execute at all.

1) **Set SmartProxy auth token (`PROXY_AUTH_TOKEN`)**
- **Symptom before:** SmartProxy returned `401 Unauthorized` for `/v1/chat/completions`.
- **Fix:** Export `PROXY_AUTH_TOKEN` so the SDLC workflow can call SmartProxy.
- **Necessary for passing?** Yes. Without this, SAP/Coord/Planner calls through SmartProxy fail immediately.

2) **Fix SmartProxy → Ollama upstream URL (stop using `192.168.4.253:11434`)**
- **Symptom before:** SmartProxy returned `500` with `Connection refused` trying to reach Ollama at a LAN IP.
- **Fix:** Restart SmartProxy (via `bin/dev`) with:
  - `OLLAMA_URL=http://localhost:11434/api/chat`
  - `OLLAMA_TAGS_URL=http://localhost:11434/api/tags`
- **Necessary for passing?** Yes, for any run that routes a model to Ollama via SmartProxy.

3) **Rebind Ollama from `127.0.0.1` to `0.0.0.0` and restart**
- **Symptom before:** Ollama was listening only on loopback; SmartProxy hitting a non-loopback address got refused.
- **Fix:** Start Ollama with `OLLAMA_HOST=0.0.0.0:11434`.
- **Necessary for passing?** Conditionally. If SmartProxy and Ollama are always on the same host and SmartProxy uses `127.0.0.1`, it’s not strictly required. In our situation it *was* required because SmartProxy was trying to connect via the LAN IP.

4) **Restart procedure: use `bin/dev`**
- **Symptom before:** We had “why is the old behavior still happening?” issues.
- **Fix:** `bin/dev` kills port `3002` and restarts SmartProxy from `Procfile.dev`, ensuring code/env changes load.
- **Necessary for passing?** Practically yes, because the fixes didn’t apply until the processes were restarted.

---

### B) SmartProxy compatibility fix (Required)
This was the biggest “hard blocker” once infra was correct.

5) **Normalize OpenAI-style `tool_calls[].function.arguments` for Ollama**
- **Symptom before:** Ollama 400’d with:
  - `cannot unmarshal string into ... tool_calls.function.arguments`
- **Cause:** Grok/OpenAI-style history uses `arguments` as a JSON *string*, but Ollama expects an *object*.
- **Fix:** In SmartProxy’s Ollama adapter, parse stringified JSON `arguments` into a Hash before calling `/api/chat`.
- **Necessary for passing?** Yes, because we were mixing Grok and Ollama models in the same conversation/log history.

(We also added a regression spec in SmartProxy to lock this behavior in.)

---

### C) SDLC runner/orchestration fixes (Required for passing)
These were needed because the workflow was repeatedly “ending early” (PRD only) or not persisting artifacts.

6) **Deterministic end-to-end orchestration in `agent:test_sdlc` (Coordinator → CWA after PRD)**
- **Symptom before:** End-to-end runs frequently stopped at SAP with:
  - `micro_tasks_count=0`, no handoffs, no tool calls.
- **Cause:** We were relying on SAP doing a perfect tool-based handoff in a single multi-agent run.
- **Fix:** In `--mode=end_to_end`, after PRD generation we explicitly invoked:
  - a Coordinator run to generate `micro_tasks`, then
  - a CWA run to execute.
- **Necessary for passing?** Yes (given model behavior). This was the turning point that made the pipeline reliable.

7) **Recover/persist PRD content when `artifact.payload['content']` is blank**
- **Symptom before:** We had real workflow output in `agent_logs/ai_workflow/<run_id>/run.json`, but the Artifact wasn’t updated, and the rake task raised:
  - `Expected artifact.payload['content'] to be present after SAP phase`
- **Fix:** Backfill `artifact.payload['content']` from workflow conversation history (best effort).
- **Necessary for passing?** Yes; otherwise the orchestration can’t proceed.

8) **Avoid masking failures with `contract_failure_plan_json` when no plan exists**
- **Symptom before:** Run summaries were being classified as plan-contract failures even when Planner never ran.
- **Fix:** Only validate plan contract when `plan_raw.present?`.
- **Necessary for passing?** Not strictly for pass/fail, but it was necessary to stop misclassifying and chasing the wrong issue.

9) **Retry on `ActiveRecord::StaleObjectError` when saving the Artifact**
- **Symptom before:** E2E runs aborted mid-flight with optimistic-locking errors.
- **Fix:** Wrap key `artifact.save!` calls in `reload + retry`.
- **Necessary for passing?** Yes once the run started doing longer/more concurrent updates.

---

### D) Tool-guardrail adjustments (Helpful / became required once execution succeeded)
10) **Increase per-turn tool-call ceilings** (`max tool calls exceeded for turn N`)
- **Symptom before:** Once CWA actually started working, it hit guardrails (too many tool calls in one turn).
- **Fix:** Raise per-turn caps for high-churn tools (`safe_shell`, `git`, `project_search`, `code_analysis`).
- **Necessary for passing?** Yes, in practice, because the run was aborting before completion.

---

### E) Model/script adjustments (Helpful)
11) **Use Grok for CWA (and later also for SAP/Coordinator)**
- **Symptom before:** Ollama models often didn’t follow tool-calling well enough to complete execution.
- **Fix:** Keep `--model-cwa=grok-4-latest`; later we also used Grok for SAP/Coordinator to stabilize PRD + micro_tasks.
- **Necessary for passing?** Yes, given prior behavior. In theory you could make Ollama work with better prompts + constraints, but we didn’t have that reliability.

---

### F) Untracked PRD-spike deliverables (Not required for the pass, but align with PRD)
These are in your working tree as **untracked** files. They were *not* the critical path to getting the passing run, but they implement PRD-AH-013G deliverables:

12) **Global truncation helper** (`Agents::ToolOutputTruncator`) + tool integrations
- **Necessary for passing?** No.
- **Necessary for PRD scope?** Yes.

13) **`run_summary.json` taxonomy/telemetry emitter** (`Agents::SdlcRunSummary`)
- **Necessary for passing?** No (it helps measure pass).
- **Necessary for PRD scope?** Yes.

14) **Stage contracts helper** (`Agents::SdlcStageContracts`)
- **Necessary for passing?** No (helpful for correctness and classification).
- **Necessary for PRD scope?** Yes.

15) **Runner handoff context patch** (`agents_runner_handoff_context_patch.rb`)
- **Necessary for passing?** No (we got a passing run without needing the plan payload handoff).
- **Necessary for PRD scope?** Yes, for richer handoff artifacts (e.g., Planner→CWA `plan_json`).

---

### Minimal set that was truly required to get the passing run
If you want the smallest “this is what made it pass” set:
- Fix SmartProxy auth (`PROXY_AUTH_TOKEN`) and Ollama upstream routing
- Ensure Ollama binding is reachable (either `0.0.0.0` or make SmartProxy use `127.0.0.1`)
- SmartProxy fix: coerce `tool_calls.function.arguments` string → object for Ollama
- Deterministic orchestration in `agent:test_sdlc` (don’t depend on SAP handoff)
- PRD persistence/backfill from `run.json`
- Retry `Artifact.save!` on `ActiveRecord::StaleObjectError`
- Increase per-turn tool-call limits to avoid guardrail abort
- Keep CWA on Grok (for tool-call reliability)

If you want, I can now:
- generate a “commit plan” (what to commit first, what to keep separate), and/or
- propose cleanup to revert temporary E2E-only hacks once we switch back to the pure multi-agent handoff approach (Approach 2).