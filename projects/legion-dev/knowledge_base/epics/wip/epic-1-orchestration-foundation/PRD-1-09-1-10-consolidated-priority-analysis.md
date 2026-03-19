# Consolidated Priority Analysis: PRD-1-09 (Epic Cleanup) & PRD-1-10 (SmartProxy Recommendations)

**Author:** Principal Architect  
**Date:** 2026-03-09  
**Status:** ANALYSIS COMPLETE — Ready for implementation planning

---

## Purpose

This document merges all tasks from PRD-1-09 (Epic 1 Cleanup) and PRD-1-10 (SmartProxy Recommendations) into a single ranked list, ordered by effort and complexity (lowest first). Overlapping items between the two PRDs are consolidated into single entries. This serves as the execution roadmap for the Lead Developer when building implementation plans.

---

## Overlap Resolution

The following items appear in both PRDs and are merged into single entries:

| PRD-1-09 ID | PRD-1-10 ID | Merged ID | Description |
|---|---|---|---|
| IG4 | SP2 | **M1** | ModelManager hardcodes wrong SmartProxy port (4567→3001) |
| IG5 | SP3 | **M2** | No retry/circuit-breaker in ModelManager |
| IG3 | SP6 | **M3** | Profile default `use_aider_tools: true` is dead weight |
| IG7 | SP4 | **M4** | SkillLoader/PromptsManager hardcoded to `.aider-desk` paths |
| IG2 | SP7 | **M5** | Memory retrieval is keyword-only (no semantic) |
| IG1 | SP8 | **M6** | Streaming is buffered, not real-time |

Items IG6 (CompactStrategy no token-count guard) from PRD-1-09 has no PRD-1-10 counterpart — retained as standalone.

---

## Consolidated Ranked List

### Tier 1: Quick Wins (< 5 minutes each, Trivial effort)

These are single-line or delete-only changes with zero risk. Do them all in one commit.

| Rank | ID | Source | Description | Effort | Complexity | Impact | Dependencies |
|---|---|---|---|---|---|---|---|
| 1 | **A1** | PRD-1-09 | Delete 4 stale debug files from `gems/agent_desk/` root (`test_t05_debug.rb`, `test_serialization.rb`, `BUGFIX-nil-content-tool-calls.md`, `compatibility-results.log`) | Trivial | Low | Low — declutter only | None |
| 2 | **C2** | PRD-1-09 | Remove orphan `# Setup all fixtures...` comment from `test/test_helper.rb` line 18 | Trivial | Low | Low — hygiene | None |
| 3 | **B3** | PRD-1-09 | Add comment above `belongs_to :project, optional: true` in `AgentTeam` documenting it's intentional for reusable teams | Trivial | Low | Low — clarity | None |
| 4 | **B1** | PRD-1-09 | Remove dead `rescue Interrupt; raise` / `rescue StandardError => e; raise` block at lines 135-139 in `DispatchService#execute_agent` (outer rescue at line 38-43 already handles both) | Trivial | Low | Low — dead code | None |
| 5 | **B2** | PRD-1-09 | Replace `return nil` with `next nil` in `OrchestratorHooksService` line 48 (context pressure hook). Note: line 121 uses a comment mentioning "return nil" but the actual code is `@workflow_run.update!` — verify only line 48 needs the fix | Trivial | Low | Medium — prevents potential `LocalJumpError` at runtime | None |
| 6 | **C5** | PRD-1-09 | Add `refute result.blocked` assertion to `test_cost_hook_blocks_and_updates_status` test | Trivial | Low | Low — test completeness | None |

**Tier 1 Total: 6 items, ~15-20 minutes combined**

---

### Tier 2: Low Effort (15-30 minutes each)

These require small but deliberate code changes with targeted test updates.

| Rank | ID | Source | Description | Effort | Complexity | Impact | Dependencies |
|---|---|---|---|---|---|---|---|
| 7 | **SP1** | PRD-1-10 | Extend `ResponseNormalizer.normalize_usage` to forward cache token fields (`prompt_cache_hit_tokens`, `cached_prompt_tokens`, `cache_read_input_tokens`, `prompt_cache_miss_tokens`, `cache_creation_input_tokens`). Plumbing already exists in `TokenBudgetTracker` and `CostCalculator` — just the normalizer mapping is missing. ~8 lines + test update. | Low | Low | **High** — unlocks real cost tracking for DeepSeek/Grok/Claude caching | None |
| 8 | **M1** | PRD-1-09 IG4 + PRD-1-10 SP2 | Fix `ModelManager#default_base_url` to return `ENV.fetch("SMART_PROXY_URL", "http://localhost:3001")` instead of hardcoded `localhost:4567`. Update 2 existing tests that assert `localhost:4567`. Note: `AgentAssemblyService` already uses ENV-driven URL (`http://192.168.4.253:3001`) so the gem default just needs to match. | Low | Low | **High** — wrong default causes silent connection failure | None |
| 9 | **D1** | PRD-1-09 | Change `ENV.fetch("SMART_PROXY_TOKEN", nil)` → `ENV.fetch("SMART_PROXY_TOKEN")` in `AgentAssemblyService#build_model_manager` with `Rails.env.test?` guard. Raises `KeyError` on missing token in dev/prod instead of cryptic downstream auth errors. | Low | Low | Medium — fail-fast in development | None |
| 10 | **M3** | PRD-1-09 IG3 + PRD-1-10 SP6 | Set `use_aider_tools: false` in `Profile#default_attributes`. Strip `AIDER_TOOL_*` entries from `default_tool_approvals`. Keep constants/implementations for backward compatibility. | Low | Low | Medium — removes dead-weight tool registration from every agent | None |
| 11 | **C1** | PRD-1-09 | Implement `FactoryBot.lint` test in `test/factories/lint_test.rb`. File currently contains only a comment. Add proper test class with `FactoryBot.lint` call. May need to handle factories requiring specific attributes (e.g., `TaskDependency` needs valid DAG). | Low | Medium | Medium — catches factory drift early | None |
| 12 | **C4** | PRD-1-09 | Fix `test_hook_errors_do_not_crash_runner` — currently stubs `update!` to raise but the `threshold=30` early-return means the stub is never hit. Stub `OrchestratorHooks.iteration_threshold_for_model` to return `1` so `update!` is actually exercised. | Low | Medium | Medium — test currently doesn't test what it claims | None |
| 13 | **C6** | PRD-1-09 | Add `test_iteration_hook_blocks_at_double_threshold` unit test to `orchestrator_hooks_service_test.rb`. Currently only covered by integration test. Trigger `on_tool_called` at 2× threshold iterations and assert `blocked: true`. | Low | Medium | Medium — unit test coverage gap | None |
| 14 | **E1** | PRD-1-09 | Document `Task.ready` scope's reliance on Rails auto-generated `dependencies_tasks` alias. The scope uses `left_joins(:dependencies)` which generates the alias. Add a comment block explaining the alias derivation and the `HAVING` logic. Alternatively, refactor to explicit `Arel` table aliasing, but comment-only is lower risk. | Low | Medium | Medium — prevents breakage if association renamed | None |
| 15 | **SP5** | PRD-1-10 | Make `X-LLM-Base-Dir` header configurable in `ModelManager` constructor (add `llm_base_dir:` parameter, default to `Dir.pwd`). Have `Runner` pass through `project_dir` from `run()`. Currently sends wrong directory for Rails-embedded usage. | Low | Medium | Medium — affects artifact dump location | None |

**Tier 2 Total: 9 items, ~3-4 hours combined**

---

### Tier 3: Medium Effort (30-90 minutes each)

These require multi-file changes, new test files, or architectural considerations.

| Rank | ID | Source | Description | Effort | Complexity | Impact | Dependencies |
|---|---|---|---|---|---|---|---|
| 16 | **M2** | PRD-1-09 IG5 + PRD-1-10 SP3 | Add `faraday-retry` gem to `agent_desk.gemspec` and configure retry middleware in `ModelManager#faraday_connection` (max: 3, backoff_factor: 2, retry_statuses: [429, 500, 502, 503, 504]). Requires gemspec change, implementation, and new tests for retry behavior. SmartProxy's own clients already use this pattern — follow that convention. | Medium | Medium | **High** — single transient 500 currently aborts entire 250-iteration agent run | None |
| 17 | **A2** | PRD-1-09 | Fix gem SimpleCov configuration. Currently shows `100.0% (0/0)`. SimpleCov must be loaded before `require "agent_desk"` in the gem's `test/test_helper.rb`. May need to adjust filters and groups to track the right files. Verify with `cd gems/agent_desk && bundle exec rake test` that coverage reports non-zero values. | Medium | Low | Low — tooling/DX only | None |
| 18 | **C3** | PRD-1-09 | Replace `assert true` placeholders in CLI dispatch integration tests 4 (`test_verifies_system_prompt_contains_rules_content`) and 5 (`test_verifies_SkillLoader_discovered_skills`). Need real assertions: test 4 should assert rules content appears in the system prompt; test 5 should assert skills were discovered. Requires understanding the mock/stub setup in those tests. | Medium | Medium | Medium — placeholder tests hide real bugs | None |
| 19 | **C7** | PRD-1-09 | Add idempotency test for `OrchestratorHooksService` — call `.call` twice on the same hook_manager and verify hooks aren't double-registered. Requires understanding hook_manager's internal registration mechanics to write a meaningful assertion (e.g., fire an event and check it only triggers once). | Medium | Medium | Medium — prevents subtle double-fire bugs | None |
| 20 | **D2** | PRD-1-09 | Add `output:` parameter to `DispatchService` (default `$stdout`). Replace 6 `puts` calls with `@output.puts`. Add test verifying silent mode with `StringIO`. This is prep for PRD-1-07 automated pipeline loops that need suppressed console output. | Medium | Low | Medium — required for Epic 2 automation | None |
| 21 | **D3** | PRD-1-09 | Replace shared fixture mutation in `team_import_integration_test.rb`. Currently writes to `@fixture_path` in `setup` and restores in `ensure` — fragile and prevents parallelization. Refactor to `with_fixture_copy` pattern (already used in unit tests). Requires `Dir.mktmpdir` + fixture copy per test. | Medium | Medium | Medium — removes test isolation hazard | None |
| 22 | **M4** | PRD-1-09 IG7 + PRD-1-10 SP4 | Extract `.aider-desk` from hardcoded strings in `SkillLoader`, `PromptsManager`, `RulesLoader`, and `ProfileManager` to a single configurable constant (`AgentDesk::CONFIG_DIR = ENV.fetch("AGENT_DESK_CONFIG_DIR", ".aider-desk")`). 6+ files reference the literal string. Needs coordinated search-and-replace + test updates for all loaders. | Medium | Medium | Medium — blocks migration to `.legion/` directory | Touches multiple gem files; coordinate with M3 |
| 23 | **IG6** | PRD-1-09 | Add token-count guard before CompactStrategy's compaction LLM call. If conversation is already at 90%+ context, the compaction call itself may fail. Add a check that the conversation leaves enough headroom for the compaction request. Requires understanding the token budget tracker's current state. | Medium | High | Medium — prevents compaction-induced context overflow | None |

**Tier 3 Total: 8 items, ~6-10 hours combined**

---

### Tier 4: High Effort (half-day+ each, potentially multi-PRD scope)

These are significant features that should be their own PRDs or deferred to Epic 2+.

| Rank | ID | Source | Description | Effort | Complexity | Impact | Dependencies |
|---|---|---|---|---|---|---|---|
| 24 | **M5** | PRD-1-09 IG2 + PRD-1-10 SP7 | Improve `MemoryStore` retrieval beyond keyword matching. Phase 1: TF-IDF scoring (pure Ruby, no new deps). Phase 2: optional `embedding_fn` parameter for semantic retrieval via Ollama. Phase 1 alone is Medium effort; full Phase 2 is High. | High | High | Medium — semantic queries fail silently today | None (but Phase 2 needs Ollama running) |
| 25 | **M6** | PRD-1-09 IG1 + PRD-1-10 SP8 | Replace buffered streaming with real SSE streaming. `ModelManager#stream_request` reads full response into `StringIO` before parsing. Requires switching Faraday adapter or using `Net::HTTP` with `response_block`. Low practical impact for agent loop (needs full response for tool calls anyway). **Recommend deferring to UI epic (Epic 4).** | High | High | Low-Medium — mostly affects UI responsiveness | SSE parser already works; adapter layer change only |

**Tier 4 Total: 2 items, ~2-4 days combined**

---

## Summary Table

| Rank | ID | Source(s) | Brief Description | Effort | Complexity | Impact | Tier |
|---|---|---|---|---|---|---|---|
| 1 | A1 | PRD-1-09 | Delete 4 stale gem files | Trivial | Low | Low | 1 |
| 2 | C2 | PRD-1-09 | Remove orphan fixtures comment | Trivial | Low | Low | 1 |
| 3 | B3 | PRD-1-09 | Comment `optional: true` intent | Trivial | Low | Low | 1 |
| 4 | B1 | PRD-1-09 | Remove dead rescue blocks | Trivial | Low | Low | 1 |
| 5 | B2 | PRD-1-09 | `return nil` → `next nil` in hooks | Trivial | Low | Medium | 1 |
| 6 | C5 | PRD-1-09 | Add `refute result.blocked` assertion | Trivial | Low | Low | 1 |
| 7 | SP1 | PRD-1-10 | Forward cache tokens in normalizer | Low | Low | **High** | 2 |
| 8 | M1 | Both | Fix SmartProxy default port 4567→3001 | Low | Low | **High** | 2 |
| 9 | D1 | PRD-1-09 | `SMART_PROXY_TOKEN` fail-fast | Low | Low | Medium | 2 |
| 10 | M3 | Both | Default `use_aider_tools: false` | Low | Low | Medium | 2 |
| 11 | C1 | PRD-1-09 | Implement `FactoryBot.lint` test | Low | Medium | Medium | 2 |
| 12 | C4 | PRD-1-09 | Fix error resilience test stub | Low | Medium | Medium | 2 |
| 13 | C6 | PRD-1-09 | Add 2× threshold blocking unit test | Low | Medium | Medium | 2 |
| 14 | E1 | PRD-1-09 | Document `Task.ready` scope alias | Low | Medium | Medium | 2 |
| 15 | SP5 | PRD-1-10 | Make `X-LLM-Base-Dir` configurable | Low | Medium | Medium | 2 |
| 16 | M2 | Both | Add faraday-retry middleware | Medium | Medium | **High** | 3 |
| 17 | A2 | PRD-1-09 | Fix gem SimpleCov config | Medium | Low | Low | 3 |
| 18 | C3 | PRD-1-09 | Replace `assert true` placeholders | Medium | Medium | Medium | 3 |
| 19 | C7 | PRD-1-09 | Idempotency test for hooks service | Medium | Medium | Medium | 3 |
| 20 | D2 | PRD-1-09 | `output:` parameter for silent mode | Medium | Low | Medium | 3 |
| 21 | D3 | PRD-1-09 | Per-test fixture isolation | Medium | Medium | Medium | 3 |
| 22 | M4 | Both | Extract `.aider-desk` to constant | Medium | Medium | Medium | 3 |
| 23 | IG6 | PRD-1-09 | Token-count guard for compaction | Medium | High | Medium | 3 |
| 24 | M5 | Both | TF-IDF / embedding memory retrieval | High | High | Medium | 4 |
| 25 | M6 | Both | Real SSE streaming | High | High | Low-Med | 4 |

---

## Execution Recommendations

### What to include in PRD-1-09 implementation plan (23 items):
- **All Tier 1** (6 items) — batch into a single commit
- **All Tier 2** (9 items) — 2-3 commits by category
- **All Tier 3** (8 items) — individual commits per item

### What to defer:
- **M5 (Memory retrieval)** → Defer to Epic 2 or a dedicated PRD. Phase 1 (TF-IDF) could fit in PRD-1-09 but Phase 2 (embeddings) is Epic 2+ scope.
- **M6 (Real streaming)** → Defer to Epic 4 (UI). No practical impact for CLI agent loop.

### Critical path (highest impact, should be done first):
1. **M1** (wrong port) — agents silently fail without explicit `base_url`
2. **SP1** (cache tokens) — cost tracking is broken for all cached requests
3. **M2** (retry middleware) — single transient error aborts entire agent run
4. **B2** (next nil) — potential runtime `LocalJumpError`

### Dependency notes:
- M4 (config dir extraction) should be coordinated with M3 (aider tools default) since both touch `Profile`/`ProfileManager`
- D2 (output parameter) is a prerequisite for PRD-1-07 plan execution automation
- C4 (error resilience fix) and C6 (threshold test) both touch the same test file — do them together
- SP1 and M1 are both in `gems/agent_desk/` — batch gem changes

---

## Counts by Source

| Source | Items | After Merge |
|---|---|---|
| PRD-1-09 only | 19 | 19 |
| PRD-1-10 only | 2 (SP1, SP5) | 2 |
| Merged (both) | 6 pairs → 6 items | 6 |
| **Total unique** | | **25** (was 31 raw, 6 merged) |
