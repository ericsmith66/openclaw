### What we learned from the debug process
#### 1) The SDLC tester is very sensitive to the runtime environment
- The biggest initial blocker was **running under system Ruby (2.6)** instead of the repo’s expected Ruby (`3.3.10`), which cascaded into Bundler/version errors.
- Recommendation: the tester should **self-validate** `ruby -v`, `bundle -v`, and fail fast with a clear message if mismatched.

#### 2) Long CLI invocations are brittle
- The full `rake agent:test_sdlc -- ...` command hit **command-length/truncation** issues in the tool execution context.
- Recommendation: provide a **first-class wrapper script** (or config file input) so users don’t have to pass huge argv strings.

#### 3) Guardrails must align with workflow phases, not just “sandbox level”
- `implementation_notes` was being required while the artifact was still in `ready_for_analysis`, which is too early.
- Recommendation: enforce certain guardrails only after the workflow reaches the phase where the artifact *could reasonably* contain the expected data.

#### 4) Validation/scoring can be accidentally mode-dependent
- `handoffs_present` failed because handoff export was only done in `coordinator_mode`, not end-to-end.
- Recommendation: validation evidence generation should be **mode-independent** (or clearly partitioned by mode).

#### 5) Tool allowlists can make “tests_green” impossible
- `SafeShellTool` did not allow `bundle exec rspec`, so the agent could not produce the “0 failures” signal required by scoring.
- Recommendation: keep safety controls, but ensure the allowlist covers the repo’s real test strategy (RSpec vs Minitest), and make scoring check both.

#### 6) Per-turn limits can block legitimate work even when total limits are fine
- The run failed with `max tool calls exceeded for turn` even though overall `--max-tool-calls` was generous.
- Recommendation: per-turn caps should be **tunable** (especially in `--sandbox-level=loose`) and should fail with guidance on how to increase them.

#### 7) Prompts need to “drive” the multi-agent workflow, not just produce artifacts
- SAP was producing a PRD but not reliably handing off to downstream agents until we explicitly required `handoff_to_coordinator`.
- Recommendation: treat “handoff required” as a **contract** between prompts and the runner.

---

### Recommendations for improving the SDLC tester
1. **Add a preflight check step** (before starting the run)
    - Verify: Ruby version, Bundler version, DB connectivity, required env vars (`AI_TOOLS_EXECUTE`, proxy readiness if needed), and presence/readability of prompt files.

2. **Replace huge argv with a config file option**
    - Example: `--config=knowledge_base/test_runs/admin_ai_workflow_runs.yml`
    - Still allow overrides via flags.

3. **Make guardrails phase-aware and mode-aware**
    - `implementation_notes`: enforce at/after `ready_for_development` (or `in_development`) only.
    - Consider “strict” vs “loose” as *safety* settings, not *progress* assumptions.

4. **Unify evidence collection in teardown**
    - Export handoffs, micro_tasks, and test outputs in one place (the ensure/teardown block) so it works identically in `stage` and `end_to_end`.

5. **Harden “tests green” detection**
    - Accept:
        - RSpec patterns (`examples, 0 failures`)
        - Minitest patterns
        - A structured JSON “test_result” artifact if available

6. **Make tool policies explicit and user-tunable**
    - Allow `bundle exec rspec` (already done)
    - Consider flags/env for:
        - per-turn cap (`MAX_CALLS_PER_TURN`)
        - test timeout (`AI_TOOLS_TEST_TIMEOUT_SECONDS`)

---

### Recommended next steps (practical)
1. **Add regression coverage for the SDLC tester itself**
    - A spec that runs `agent:test_sdlc --dry-run` and asserts:
        - handoff export happens
        - evidence files are produced
        - scoring doesn’t incorrectly depend on run mode

2. **Document a “known good” execution path**
    - A short doc section that says:
        - run `eval "$(rbenv init -)"`
        - run `AI_TOOLS_EXECUTE=true ./script/run_agent_test_sdlc_e2e.sh`
        - where to find `summary.log` / `run_summary.md`

3. **Decide whether “pass=7” is the right threshold**
    - Today it’s achievable, but sensitive to tool policy + test output parsing.
    - If you want higher confidence, consider raising the threshold only after scoring is less brittle.

4. **(Optional) Introduce a structured “handoff contract”**
    - E.g., runner enforces that SAP must emit at least one handoff tool call in end-to-end mode, otherwise auto-retry with a targeted system message.

If you tell me whether this repo is predominantly **RSpec** or **Minitest**, I can suggest the cleanest long-term approach for test execution + “green detection” so scoring is robust.