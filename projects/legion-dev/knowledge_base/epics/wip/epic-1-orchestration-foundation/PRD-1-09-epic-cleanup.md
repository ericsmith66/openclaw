#### PRD-1-09: Epic 1 Cleanup — Technical Debt & QA Remediation

**Log Requirements**
- Create/update a task log under `knowledge_base/task-logs/`.
- In the log, include detailed manual test steps and expected results.
- If asked to review: create a separate document named `{{source-document}}-feedback-V{{N}}.md` in the same directory as the source document.

---

### Overview

After completing PRDs 1-01 through 1-05, several minor issues were identified across QA reports and a full-codebase review. None are blocking for functionality, but they represent technical debt, test gaps, and housekeeping items that should be resolved before Epic 2 work begins. This PRD consolidates all known cleanup tasks into a single sweep.

**Sources of issues:**
- QA Report PRD-1-01 (96/100): 3 remediation items
- QA Report PRD-1-03 (97/100): 1 remediation item
- QA Report PRD-1-04 (91/100): 3 non-blockers carried forward
- QA Report PRD-1-05 V2 (91/100): 4 remediation items
- Full codebase review (March 7, 2026): 7 additional items

---

### Requirements

#### Functional

No new features. All changes are refactors, test improvements, or dead code removal.

#### Non-Functional

- Zero test regressions — `bundle exec rails test` and `cd gems/agent_desk && bundle exec rake test` must both remain green
- Zero new RuboCop offenses
- All `frozen_string_literal: true` pragmas preserved

---

### Cleanup Tasks

#### Category A: Gem Housekeeping (from codebase review)

- **A1** — Remove stale debugging artifacts from `gems/agent_desk/` root:
  - `test_t05_debug.rb` (ad-hoc debug script)
  - `test_serialization.rb` (serialization investigation)
  - `BUGFIX-nil-content-tool-calls.md` (stale status doc, dated 2026-03-02)
  - `compatibility-results.log` (test run output)
  
  These are not in `spec.files` so they don't ship, but they clutter the gem directory.

- **A2** — Fix gem SimpleCov configuration so coverage actually tracks source files. Currently shows `Line Coverage: 100.0% (0 / 0)`. The gem's `test/test_helper.rb` needs SimpleCov loaded before `require "agent_desk"`.

#### Category B: Code Quality Fixes (from codebase review)

- **B1** — `app/services/legion/dispatch_service.rb` lines 135-139: Remove dead rescue blocks inside `execute_agent` that just re-raise without doing anything. The outer rescue in `call` already handles these.

  ```ruby
  # REMOVE these (lines 135-139):
  rescue Interrupt
    raise
  rescue StandardError => e
    raise
  ```

- **B2** — `app/services/legion/orchestrator_hooks_service.rb` lines 48-49: Replace `return nil` inside block with `next nil`. Using `return` inside a `Proc`/block passed to `hook_manager.on()` can raise `LocalJumpError` in certain Ruby edge cases. Applies to 2 locations within the context pressure hook.

- **B3** — `app/models/agent_team.rb`: Add a comment documenting that `belongs_to :project, optional: true` is intentional (for reusable teams). Currently this looks like an oversight.

#### Category C: Test Quality Improvements (from QA reports)

- **C1** — (PRD-1-01 QA, Remediation #3) Add proper `FactoryBot.lint` test to `test/factories/lint_test.rb`. Currently the file contains only a comment. Should include:
  ```ruby
  test "all factories are valid" do
    FactoryBot.lint
  end
  ```

- **C2** — (PRD-1-01 QA) Remove stale `fixtures :all` comment from `test/test_helper.rb` line 15. The `fixtures :all` call was correctly removed but the comment remains as an orphan.

- **C3** — (PRD-1-04 QA, NB-3) Replace `assert true` placeholder assertions in `test/integration/cli_dispatch_integration_test.rb` tests 4 and 5 (`test_verifies_system_prompt_contains_rules_content` and `test_verifies_SkillLoader_discovered_skills`). These should have real assertions that verify actual behavior.

- **C4** — (PRD-1-05 QA V2, R1) Fix error resilience test `test_hook_errors_do_not_crash_runner` in `test/services/legion/orchestrator_hooks_service_test.rb`. Currently stubs `update!` to raise but only triggers `on_tool_called` once — with `threshold=30` the early-return path is taken so the stub is never hit. Fix: stub `OrchestratorHooks.iteration_threshold_for_model` to return `1` so `update!` is actually called.

- **C5** — (PRD-1-05 QA V2, R2) Add `refute result.blocked` assertion to `test_cost_hook_blocks_and_updates_status` in `test/services/legion/orchestrator_hooks_service_test.rb`. The Architect BLOCKER R2-1 required this but it was not applied to the cost hook test.

- **C6** — (PRD-1-05 QA V2, R3) Add unit test `test_iteration_hook_blocks_at_double_threshold` to `test/services/legion/orchestrator_hooks_service_test.rb`. Currently only covered by integration test. The plan required a unit test.

- **C7** — (PRD-1-05 QA V2, Deduction 4) Add idempotency test for `OrchestratorHooksService` — verify calling `.call` twice on the same instance doesn't double-register hooks.

#### Category D: Design Improvements for Epic 2 Readiness (from PRD-1-04 QA)

- **D1** — (PRD-1-04 QA, NB-1) Change `ENV.fetch("SMART_PROXY_TOKEN", nil)` to `ENV.fetch("SMART_PROXY_TOKEN")` in `app/services/legion/agent_assembly_service.rb` so a missing token raises `KeyError` at boot rather than producing a cryptic downstream auth failure. Add a guard that skips the check when `Rails.env.test?`.

- **D2** — (PRD-1-04 QA, NB-4) Add `output:` parameter to `DispatchService` to support silent mode for future PRD-1-06/1-07 automated pipeline loops. Replace `puts` calls with `@output.puts`.

- **D3** — (PRD-1-03 QA, M1) Replace shared fixture mutation in `test/integration/team_import_integration_test.rb` setup with per-test `with_fixture_copy` isolation, matching the unit test pattern.

#### Category E: Task.ready Scope Fragility (from codebase review)

- **E1** — `app/models/task.rb`: The `Task.ready` scope uses `dependencies_tasks` which is a Rails auto-generated alias for the self-join. Document this alias dependency with a comment, or refactor to use `Arel` for explicit table aliasing to avoid breakage if the association name changes.

---

### Error Scenarios & Fallbacks

No new error scenarios introduced. All changes are refactors within existing error boundaries.

---

### Architectural Context

This PRD is a **maintenance sweep** between Epic 1 implementation and Epic 2 start. It touches no new features, introduces no new dependencies, and changes no public APIs. The goal is to start Epic 2 with a clean, fully-tested baseline.

Key boundaries:
- Gem changes (Category A) are confined to `gems/agent_desk/` and do not affect any Ruby source files
- Code fixes (Category B) are in Rails services only — no gem changes
- Test improvements (Category C) may require minor service refactors to improve testability
- Design improvements (Category D) touch `AgentAssemblyService` and `DispatchService`
- All categories maintain the existing gem/Rails boundary separation

**Non-goals:**
- No new models, migrations, or schema changes
- No CLI changes (bin/legion)
- No new services or controllers
- No Epic 2 scope items

---

### Acceptance Criteria

- [ ] **AC1** — All 4 stale files removed from `gems/agent_desk/` root (A1)
- [ ] **AC2** — Gem SimpleCov reports actual line coverage, not `0 / 0` (A2)
- [ ] **AC3** — Dead rescue blocks removed from `DispatchService#execute_agent` (B1)
- [ ] **AC4** — `return nil` replaced with `next nil` in `OrchestratorHooksService` hook blocks (B2)
- [ ] **AC5** — `AgentTeam#belongs_to :project, optional: true` documented with comment (B3)
- [ ] **AC6** — `FactoryBot.lint` test implemented and passing (C1)
- [ ] **AC7** — Stale `fixtures :all` comment removed from `test_helper.rb` (C2)
- [ ] **AC8** — `assert true` placeholders replaced with real assertions in CLI dispatch integration tests (C3)
- [ ] **AC9** — Error resilience test in orchestrator hooks actually exercises the rescue path (C4)
- [ ] **AC10** — Cost hook test includes `refute result.blocked` assertion (C5)
- [ ] **AC11** — Unit test for iteration hook 2× threshold blocking exists and passes (C6)
- [ ] **AC12** — Idempotency test for `OrchestratorHooksService` exists and passes (C7)
- [ ] **AC13** — `SMART_PROXY_TOKEN` raises `KeyError` when missing in non-test environments (D1)
- [ ] **AC14** — `DispatchService` accepts `output:` parameter, defaults to `$stdout` (D2)
- [ ] **AC15** — Integration test for team import uses per-test fixture isolation (D3)
- [ ] **AC16** — `Task.ready` scope alias documented or refactored (E1)
- [ ] **AC17** — `bundle exec rails test` — zero failures, zero errors, zero skips
- [ ] **AC18** — `cd gems/agent_desk && bundle exec rake test` — zero failures, zero errors
- [ ] **AC19** — `bundle exec rubocop` — zero new offenses across all modified files

---

### Test Cases

#### Unit (Minitest)

- `test/factories/lint_test.rb`: FactoryBot.lint across all factories (C1)
- `test/services/legion/orchestrator_hooks_service_test.rb`: Error resilience test fix (C4), cost hook assertion (C5), 2× threshold unit test (C6), idempotency test (C7)
- `test/services/legion/dispatch_service_test.rb`: Verify `output:` parameter behavior (D2)

#### Integration (Minitest)

- `test/integration/cli_dispatch_integration_test.rb`: Replace `assert true` with real assertions (C3)
- `test/integration/team_import_integration_test.rb`: Fixture isolation (D3)

#### System / Smoke

- N/A — no system tests affected

---

### Manual Verification

1. `bundle exec rails test` — confirm 0 failures
2. `cd gems/agent_desk && bundle exec rake test` — confirm 0 failures and SimpleCov shows non-zero line coverage
3. `ls gems/agent_desk/test_t05_debug.rb gems/agent_desk/test_serialization.rb gems/agent_desk/BUGFIX-nil-content-tool-calls.md gems/agent_desk/compatibility-results.log 2>&1` — confirm all 4 files are gone
4. `bundle exec rubocop --format simple` — confirm 0 offenses

**Expected**
- Full green test suite (both Rails and gem)
- No stale files in gem root
- SimpleCov reports actual coverage percentages

---

### Rollout / Deployment Notes

- No migrations
- No environment variable changes (except `SMART_PROXY_TOKEN` now required in non-test environments — update `.env.example` if it exists)
- No monitoring changes


### Issues & Gaps
1. Streaming is fake. ModelManager#stream_request reads the entire response body into a StringIO then parses SSE lines. It's not real streaming — the client blocks until the full response is done, then gets one big chunk callback. For a coding agent this is probably fine (you want the full response before acting), but it's misleading and could cause timeout issues on long responses.

2. Memory retrieval is keyword-only. MemoryStore#retrieve splits the query on whitespace and counts term matches. There's no semantic/embedding-based retrieval. This means "find memories about authentication" won't match a memory containing "OAuth token handling". Given SmartProxy can route to any provider, it would be worth plugging in a small local embedding model via Ollama for proper retrieval.

3. Profile mentions use_aider_tools but aider is going away. The Profile still has use_aider_tools: true as a default, and AIDER_TOOL_* constants are in the tool set. If you're moving away from AiderDesk, these will become dead weight. Worth a cleanup pass.

4. ModelManager hardcodes :smart_proxy URL as localhost:4567. The default is localhost:4567 but SmartProxy runs on port 3001 in production. This will bite anyone who doesn't explicitly set base_url. Should default to 3001 or be ENV-driven.

5. No retry/circuit-breaker in ModelManager. Faraday has a retry middleware but ModelManager doesn't configure it. A single Faraday TimeoutError raises immediately. Compare to SmartProxy's GrokClient which has 3 retries with exponential backoff. For an agent that runs 250 iterations, a single transient 429 will abort the whole run.

6. CompactStrategy sends the entire conversation to the LLM for summarisation without tools. This works but means compaction is an expensive LLM call that could itself timeout or fail. The rescue path degrades gracefully (continues without compaction), which is correct, but there's no token-count guard before the compaction call — if the conversation is already at 90% context, the compaction call itself might fail.

7. SkillLoader still looks in ~/.aider-desk/skills. The global skills directory defaults to ~/.aider-desk/skills. With the move to legion, this should become ~/.legion/skills or be configurable.
8. 