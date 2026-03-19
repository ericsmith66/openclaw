Now let me compile the full report.

---

# Epic 1 — Orchestration Foundation: Deep-Dive Code Review

## PRD-1-01: Schema Foundation

**Files:** 7 models, 8 migrations, 7 factories  
**Verdict: Solid** — Clean models, proper validations, good enum/scope design.

### Issues Found

| # | Severity | Location | Description |
|---|----------|----------|-------------|
| 1 | **Medium** | `TeamMembership#to_profile` L27 | `include_context_files` logic is confusing: `config["includeContextFiles"] != false && config["includeContextFiles"] || false`. This is not equivalent to a simple boolean coercion — it returns `false` for `nil`, `false` for `false`, and the raw value for anything else (including strings, integers). Should be `config["includeContextFiles"] == true` or `config.fetch("includeContextFiles", false) == true`. |
| 2 | **Low** | `Task.ready` scope L44 | Uses `dependencies_tasks` — a Rails auto-generated join table alias. Fragile if the association name `dependencies` is ever renamed. Should document or use an explicit `joins()` with alias control. |
| 3 | **Low** | `Task#dispatchable?` L48 | `pending? || status == "ready"` mixes enum helper (`pending?`) with raw string comparison (`status == "ready"`). Should be `pending? || ready?` for consistency. |
| 4 | **Trivial** | `Task` L37-38 | Double blank line before `scope :by_position`. Style nit. |
| 5 | **Low** | `TaskDependency#no_cycles` | BFS cycle detection issues one DB query per node (`TaskDependency.where(...)`). For small graphs this is fine, but O(n) queries for large DAGs. Consider preloading all edges for the workflow in a single query. |
| 6 | **Low** | `test/factories/lint_test.rb` | Contains only a comment — no actual `FactoryBot.lint` call. The file claims linting is done via individual model tests, but this is not equivalent to a full `FactoryBot.lint` pass that validates all factories build cleanly. |

---

## PRD-1-02: PostgresBus Adapter

**Files:** `app/services/legion/postgres_bus.rb`, unit tests (14), integration test  
**Verdict: Clean** — Best-implemented service in the epic. Good rescue/ensure pattern, proper interface inclusion, clear Solid Cable stub.

### Issues Found

| # | Severity | Location | Description |
|---|----------|----------|-------------|
| — | — | — | No issues found. This is exemplary code. |

---

## PRD-1-03: Team Import Service

**Files:** `app/services/legion/team_import_service.rb`, unit tests (29), integration test  
**Verdict: Solid** — Good 2-phase pattern (validate outside transaction, persist inside).

### Issues Found

| # | Severity | Location | Description |
|---|----------|----------|-------------|
| 1 | **Trivial** | `TeamImportService` L7 | Uses `class << self` pattern while all other services use `def self.call`. Functionally identical but inconsistent with the rest of the codebase. |

---

## PRD-1-04: CLI Dispatch

**Files:** `dispatch_service.rb`, `agent_assembly_service.rb`, `bin/legion`, unit tests (12), integration tests (5)  
**Verdict: Good but has dead code and testability concerns**

### Issues Found

| # | Severity | Location | Description |
|---|----------|----------|-------------|
| 1 | **Medium** | `DispatchService#execute_agent` L135-139 | **Dead rescue blocks.** The inner `rescue Interrupt; raise` and `rescue StandardError => e; raise` do nothing — they just re-raise. The outer rescue in `call` (L38-44) already handles both. These inner rescues should be removed entirely. |
| 2 | **Medium** | `DispatchService#execute_agent` L126-127 | **Fragile event extraction.** `workflow_run.workflow_events.where(...).pluck(:payload).last&.dig(...)` chains are fragile. If no `response.complete` event exists, iterations defaults to `0` and result to `""`, but the chained `pluck().last&.dig()` pattern performs a DB query each time and relies on ordering by implicit ID. Consider a dedicated method or scope. |
| 3 | **Medium** | `DispatchService` L89, L143-147 | **Hardcoded `puts` to `$stdout`.** The service writes directly to stdout, preventing silent/programmatic reuse (e.g., when called from a Solid Queue job or the future web UI). Should accept an `output:` IO parameter (defaulting to `$stdout`). |
| 4 | **Medium** | `AgentAssemblyService#build_model_manager` L93 | **`ENV.fetch("SMART_PROXY_TOKEN", nil)` silently allows nil API key.** This will likely fail deep inside the ModelManager/Faraday call with an unhelpful error. Should raise early with a clear message: `"SMART_PROXY_TOKEN environment variable is required"`. |
| 5 | **Low** | `cli_dispatch_integration_test.rb` L145, L180 | **`assert true` placeholders.** Two tests end with `assert true` — they set up elaborate mocks but don't actually assert anything meaningful. Tests named "verifies system prompt contains rules content" and "verifies SkillLoader discovered skills" assert nothing about their subjects. |
| 6 | **Low** | `DispatchService#find_membership` L61 | **ILIKE with user-provided partial match** — `"%#{@agent_identifier}%"`. While this uses parameterized queries (SQL-injection safe), the `%` wildcards mean a search for `"a"` would match any agent with `"a"` anywhere in its name. Could cause ambiguous matches. Consider exact match first, fall back to ILIKE only if no exact match found. |

---

## PRD-1-05: Orchestrator Hooks

**Files:** `orchestrator_hooks_service.rb`, `orchestrator_hooks.rb`, unit tests (13), integration tests (3)  
**Verdict: Functional but has a latent bug and consistency issues**

### Issues Found

| # | Severity | Location | Description |
|---|----------|----------|-------------|
| 1 | **High** | `OrchestratorHooksService` L48 | **`return nil` inside a stored Proc (latent bug).** Line 48: `return nil unless percentage` is inside a block passed to `@hook_manager.on(...)`. This block is stored as a `Proc` and invoked later via `handler.call(...)`. In Ruby, `return` inside a non-lambda Proc attempts to return from the enclosing method — but that method (`register_context_pressure_hook`) has already returned. This raises `LocalJumpError`. **Currently works by accident**: the `rescue StandardError => e` on L76 catches `LocalJumpError` (which is a subclass of `StandardError`) and logs a misleading error. The fix is simple: replace `return nil unless percentage` with `next nil unless percentage`. |
| 2 | **Medium** | `OrchestratorHooksService` L56, 68, 103, 129, 162, 173 | **`Time.now` used instead of `Time.current` (6 occurrences).** `DispatchService` correctly uses `Time.current` (timezone-aware). The hooks service inconsistently uses `Time.now` (system clock). In a Rails app this can produce incorrect timestamps when `config.time_zone` differs from the system timezone. |
| 3 | **Low** | `OrchestratorHooksService` L13, 17 | **`@hooks_registered` idempotency guard is per-instance only.** Since the service is instantiated fresh via `self.call(...)` each time, `@hooks_registered` is always `false` on entry. The guard would only prevent double-registration if someone called `call` on the same instance twice — which the `self.call` pattern prevents. The guard is dead code. |
| 4 | **Low** | `OrchestratorHooksService` L145 | **`@iteration_count` instance variable used inside a stored Proc.** The proc closes over `self` (the service instance). This works because the service instance stays alive as long as the hook_manager holds the proc reference. However, if the service instance were ever garbage-collected, the iteration counter would be lost. Not a bug today, but the coupling is implicit and undocumented. |
| 5 | **Low** | `OrchestratorHooksService` L155 | **Hard stop at 2× threshold is undocumented.** At `iteration_count >= threshold * 2`, the hook sets status to `iteration_limit` and blocks. This 2× multiplier isn't mentioned in the PRD or code comments. Should be extracted to a named constant (e.g., `HARD_STOP_MULTIPLIER = 2`). |

---

## Cross-Cutting Concerns

| # | Severity | Pattern | Description |
|---|----------|---------|-------------|
| 1 | **Medium** | Gem boundary | **Gem separation is excellent.** The `agent_desk` gem has zero Rails dependencies. All adaptation happens in `app/services/legion/`. The boundary is clean: gem defines interfaces (`MessageBusInterface`, `HookManager`, `HookResult`, `Profile`), Rails implements adapters. No leaks detected. |
| 2 | **Medium** | Stale files | **4 debugging artifacts in gem root:** `test_t05_debug.rb`, `test_serialization.rb`, `BUGFIX-nil-content-tool-calls.md`, `compatibility-results.log`. Should be removed or moved to appropriate locations. |
| 3 | **Medium** | Output coupling | **`puts` throughout services.** Both `DispatchService` and `DecompositionService` write directly to `$stdout`. This couples services to CLI usage and will need refactoring for Epic 2+ (Solid Queue workers, web UI). Extract to an injectable `output:` parameter. |
| 4 | **Low** | Test organization | **`test/lib/agent_desk/` contains 3 Rails-side tests** (`profile_manager_test.rb`, `rules_loader_test.rb`, `skill_loader_test.rb`) that exercise gem classes using Rails fixtures. These are really integration/smoke tests, not unit tests. The location is misleading — they should be in `test/integration/` or `test/smoke/`. |
| 5 | **Low** | `test_helper.rb` L15-16 | **Orphan comment.** Line 15 has a leftover comment about fixtures (`# Setup all fixtures in test/fixtures/*.yml...`) but `fixtures :all` was removed. The comment should be cleaned up. |
| 6 | **Trivial** | Service pattern | **Minor inconsistency** in `self.call` vs `class << self` entry point (only `TeamImportService` differs). |

---

## Summary Scorecard

| PRD | Score | Key Concern |
|-----|-------|-------------|
| 1-01 Schema | 92/100 | `include_context_files` logic confusing; `Task.ready` alias fragile |
| 1-02 PostgresBus | 98/100 | No issues |
| 1-03 Team Import | 96/100 | Minor style inconsistency only |
| 1-04 CLI Dispatch | 85/100 | Dead rescue blocks, hardcoded stdout, `assert true` placeholders, nil API key |
| 1-05 Orchestrator Hooks | 80/100 | `return` vs `next` latent bug, `Time.now` inconsistency, undocumented hard stop |
| Cross-cutting | 90/100 | Gem boundary excellent; stale files and output coupling need attention |

**Overall Epic 1: 88/100**

**Top 3 action items:**
1. Fix `return nil` → `next nil` in orchestrator hooks (silent `LocalJumpError` being swallowed)
2. Remove dead rescue blocks in `DispatchService#execute_agent`
3. Replace `Time.now` with `Time.current` in all 6 hook occurrences