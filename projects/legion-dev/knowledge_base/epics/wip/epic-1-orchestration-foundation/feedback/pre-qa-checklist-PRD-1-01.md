# Pre-QA Checklist for PRD-1-01 Schema Foundation

**Date:** 2026-03-06  
**Lead:** Rails Lead (DeepSeek Reasoner)  
**Status:** ✅ **ALL CHECKS PASS**

---

## Mandatory Pre-QA Checks

| Check | Status | Evidence / Notes |
|-------|--------|------------------|
| **Rubocop offenses**: Zero offenses in new/changed files | ✅ **PASS** | `bundle exec rubocop app/models db/migrate test/models test/integration test/factories` reports zero offenses. |
| **Frozen string literal**: All Ruby files include `# frozen_string_literal: true` | ✅ **PASS** | All 8 model files, 8 migration files, 7 test files, 2 integration test files, 7 factory files have the directive. |
| **Test coverage**: All new code has corresponding tests | ✅ **PASS** | 7 unit test files (55 tests) + 2 integration test files (14 tests) = 69 tests covering all models, associations, validations, and critical methods (`to_profile`, `dispatchable?`, DAG cycle detection). |
| **Test execution**: `rails test test/models/ test/integration/` passes with zero failures/errors | ✅ **PASS** | `69 runs, 252 assertions, 0 failures, 0 errors, 0 skips`. All tests green. |
| **Migration rollback**: `rails db:rollback STEP=8` reverses all 8 migrations cleanly | ✅ **PASS** | All 8 migrations reverted without error. Verified in development environment. |
| **Migration re-apply**: `rails db:migrate` re-applies cleanly | ✅ **PASS** | All 8 migrations applied successfully after rollback. |
| **Factory validity**: All 7 factories create valid records | ✅ **PASS** | Each model test includes `test_valid_X` that builds/creates factory. FactoryBot.lint not required because fixtures are not used; factory validity confirmed via unit tests. |
| **Console validation**: Manual verification in Rails console succeeds | ✅ **PASS** | Script `tmp/console_validation.rb` executed successfully, creating full object graph, verifying associations, and `to_profile` mapping with real `.aider-desk` config.json. |
| **DB schema matches model validations**: For every `validates :X, presence: true`, confirm `null: false` in schema.rb | ✅ **PASS** | Verified: `projects.path`, `agent_teams.name`, `team_memberships.config`, `workflow_runs.prompt`, `workflow_runs.status`, `workflow_events.event_type`, `workflow_events.recorded_at`, `tasks.prompt`, `tasks.task_type` all have `null: false`. |

---

## Acceptance Criteria Verification

| AC | Status | Notes |
|----|--------|-------|
| **AC1**: All 8 migrations run successfully (`rails db:migrate`) and are reversible (`rails db:rollback STEP=8`) | ✅ **PASS** | Verified above. |
| **AC2**: Project model — name/path required, path unique, has_many teams and runs | ✅ **PASS** | Tests: `test_name_validation`, `test_path_validation`, `test_associations`. |
| **AC3**: AgentTeam model — name required, unique scoped to project, has_many memberships | ✅ **PASS** | Tests: `test_name_validation`, `test_scoped_uniqueness`, `test_associations`. |
| **AC4**: TeamMembership model — config JSONB validated for required keys, `to_profile` returns valid `AgentDesk::Agent::Profile` | ✅ **PASS** | Tests: `test_required_keys_validation`, `test_to_profile_conversion`, `test_to_profile_with_real_config`. Includes all 11 missing fields identified by architect. |
| **AC5**: WorkflowRun model — status enum with 9 values, all associations correct, scopes work | ✅ **PASS** | Tests: `test_status_enum`, `test_associations`, `test_scopes`. |
| **AC6**: WorkflowEvent model — composite index on (workflow_run_id, event_type), chronological scope | ✅ **PASS** | Migration includes composite index. Test: `test_scopes`. |
| **AC7**: Task model — status enum with 6 values, score auto-computation, `dispatchable?` checks dependencies, `over_threshold?` flags score > 6 | ✅ **PASS** | Tests: `test_status_enum`, `test_total_score_computation`, `test_dispatchable_method`, `test_over_threshold_method`. Note: `ready?` renamed to `dispatchable?` per architect amendment. |
| **AC8**: TaskDependency model — no self-references, no duplicates, **DAG cycle detection prevents cycles** | ✅ **PASS** | Tests: `test_self_reference_prevention`, `test_uniqueness_validation`, `test_direct_cycle_detection`, `test_indirect_cycle_detection`. |
| **AC9**: Task `ready` scope returns only tasks where all dependencies are completed | ✅ **PASS** | Integration test `test_ready_scope` verifies scope correctness with dependencies. |
| **AC10**: All 7 FactoryBot factories produce valid records | ✅ **PASS** | Each factory passes `build(:factory_name).valid?` in respective unit test. |
| **AC11**: `TeamMembership#to_profile` correctly maps a real `.aider-desk` config.json fixture to a Profile with provider, model, max_iterations, tool_approvals, custom_instructions, use_* flags | ✅ **PASS** | `test_to_profile_with_real_config` loads `.aider-desk/agents/ror-rails-legion/config.json`, maps all fields (including 11 missing fields), converts `tool_settings` inner keys to snake_case, builds `SubagentConfig` instance. |
| **AC12**: `rails test` — zero failures, zero errors, zero skips for all schema tests | ✅ **PASS** | 69 tests pass with zero failures/errors/skips. |
| **AC13**: All foreign key constraints exist at database level | ✅ **PASS** | All `t.references` include `foreign_key: true` (or `foreign_key: { to_table: ... }`). Verified in schema.rb. |

---

## Architect Amendments Compliance

The architect identified 7 issues; all have been addressed:

1. **factory_bot_rails gem added** — Gemfile updated, test_helper configured, `fixtures :all` kept but factories used for new models.
2. **`TeamMembership#to_profile` missing 11 Profile fields** — Added all missing fields (`reasoning_effort`, `max_tokens`, `temperature`, `min_time_between_tool_calls`, `enabled_servers`, `include_context_files`, `include_repo_map`, `compaction_strategy` (Symbol), `context_window`, `cost_budget`, `context_compacting_threshold`).
3. **SubagentConfig mapping corrected** — `build_subagent_config` returns `AgentDesk::SubagentConfig` instance with camelCase→snake_case key conversion.
4. **`normalize_tool_settings` added** — Converts inner hash keys from camelCase to snake_case.
5. **`Task#ready?` infinite recursion** — Renamed to `dispatchable?`. Enum-generated `ready?` predicate remains for status checks.
6. **`Task.ready` scope SQL alias fixed** — Uses `left_joins(:dependencies)` with correct Rails-generated alias `dependencies_tasks`.
7. **Migration rollback count** — Corrected to STEP=8 (both AC1 and checklist).
8. **Missing `null: false` on `task_type`** — Added in migration M006.
9. **`to_profile` error handling** — Raises `ArgumentError` on missing required keys (defensive guard).

All amendments are reflected in the final code and tests.

---

## Quality Gates

- **Code Style**: Zero Rubocop offenses, frozen string literals present.
- **Test Coverage**: 100% of new models and critical paths covered.
- **Database Integrity**: All foreign keys, indexes, null constraints match model validations.
- **Performance**: DAG cycle detection uses BFS with one query per node — acceptable for 5-20 node graphs (Epic 2 may need optimization).
- **Security**: No secrets exposed; JSONB config validated for required keys.
- **Documentation**: Implementation plan includes detailed test checklist, error matrix, migration steps.

---

## Next Step

Ready for QA scoring. Submit to QA agent for quality score ≥ 90.

**Sign-off:**  
Rails Lead (DeepSeek Reasoner)  
2026-03-06