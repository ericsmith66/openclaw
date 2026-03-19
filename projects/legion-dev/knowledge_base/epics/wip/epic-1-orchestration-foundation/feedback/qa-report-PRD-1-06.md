# QA Scoring Report: PRD-1-06 Task Decomposition

**PRD:** knowledge_base/epics/wip/epic-1-orchestration-foundation/PRD-1-06-task-decomposition.md
**Date:** 2026-03-07
**QA Agent:** Claude Sonnet (QA Specialist)
**Implementer:** Rails Lead (DeepSeek Reasoner)

---

## Final Score: 94/100 ✅ PASS

> **Production-ready.** All 14 acceptance criteria met. All tests pass. Minor deductions for missing TODO comment, missing scope unit test, and VCR deviation in integration tests.

---

## Per-Criteria Breakdown

| Criterion | Max | Score | Notes |
|-----------|-----|-------|-------|
| Acceptance Criteria Compliance | 30 | 30 | All 14 ACs verified met |
| Test Coverage | 30 | 28 | 39/39 tests pass; minor gaps in by_identifier scope test and parallel groups parser test quality |
| Code Quality | 20 | 18 | Clean, well-structured; missing --force TODO comment; by_identifier scope untested |
| Plan Adherence | 20 | 18 | All 11 amendments incorporated; VCR not used in integration test; TODO comment missing |

---

## AC Compliance: 30/30

All 14 acceptance criteria were verified **PASS**:

| AC | Description | Status | Evidence |
|----|-------------|--------|---------|
| AC1 | `bin/legion decompose --team ROR --prd <path>` dispatches Architect | ✅ | `bin/legion` decompose command; DispatchService.call invoked with architect |
| AC2 | Tasks created with correct fields (prompt, type, agent, scores, position) | ✅ | `test_creates_task_records_from_parsed_output` asserts position, task_type, workflow_run |
| AC3 | TaskDependency edges created matching Architect's output | ✅ | `test_creates_task_dependency_records` and integration test `task_dependency_edges_match_architect_output` |
| AC4 | Test tasks appear before implementation tasks | ✅ | `test_test_first_ordering_verified` in integration tests |
| AC5 | Implementation tasks depend on their test tasks | ✅ | Same test; dependency graph verified in integration test |
| AC6 | Parser handles JSON wrapped in markdown code fences | ✅ | `test_handles_json_wrapped_in_code_fences` (parser test) |
| AC7 | Parser validates score ranges (1-4) and dependency references | ✅ | `test_validates_score_ranges_out_of_bounds`, `test_detects_invalid_dependency_references` |
| AC8 | Tasks with total_score > 6 flagged with warning | ✅ | `test_flags_tasks_over_threshold` — warns but does not error |
| AC9 | Parallel groups detected and displayed in console output | ✅ | `test_console_output_includes_parallel_groups`; `detect_parallel_groups` method confirmed working |
| AC10 | `--dry-run` shows parsed output without saving to DB | ✅ | `test_dry_run_mode_parses_but_does_not_save` — Task.count unchanged |
| AC11 | Decomposition creates its own WorkflowRun (status: `decomposing`) | ✅ | `workflow_run.update!(status: :decomposing)` in service; `test_creates_workflow_run_with_decomposing_status` |
| AC12 | Invalid Architect output → error message with raw response preserved | ✅ | `test_unparseable_output_preserves_raw_response` — status=failed, error_message contains raw |
| AC13 | Cycle detection prevents circular dependency creation | ✅ | Kahn's algorithm in parser; `test_detects_dependency_cycles_simple` and `_complex` |
| AC14 | `rails test` — zero failures for decomposition tests | ✅ | 39 runs, 0 failures, 0 errors, 0 skips |

---

## Test Coverage: 28/30

**Deductions:**
- **-1 pt**: `test_identifies_parallel_groups` (parser test #13) is a weak test. It only verifies that `tasks[0][:depends_on] == []` and `tasks[1][:depends_on] == [1]` — it does **not** test that the parser returns parallel group data (because the parser doesn't — parallel group detection is in the service). The test comment even says "This is tested via integration." The test passes but mismatch between plan intent and actual assertion strength is a coverage concern.
- **-1 pt**: `TeamMembership.by_identifier` scope was added per Amendment #7 as a shared, reusable component used by both `DispatchService` and `DecompositionService`. There is **no standalone unit test** for this scope in `test/models/team_membership_test.rb`. The scope is exercised transitively through service tests (mocked), but the scope's own query logic (`config->>'id' = ?` vs `ILIKE`) is never directly tested against the database.

**Verified passing tests:**

| File | Tests | Assertions | Result |
|------|-------|-----------|--------|
| `test/services/legion/decomposition_parser_test.rb` | 17 | 48 | ✅ 0 failures |
| `test/services/legion/decomposition_service_test.rb` | 16 | 51 | ✅ 0 failures |
| `test/integration/decomposition_integration_test.rb` | 6 | 23 | ✅ 0 failures |
| **Full suite** | **222** | **793** | ✅ **0 failures, 0 errors, 0 skips** |

**All 45 planned tests implemented** (39 automated + 6 manual documented in task log).

---

## Code Quality: 18/20

**Strengths:**
- Clean separation of concerns: `DecompositionParser` (validation/parsing) vs `DecompositionService` (orchestration/persistence)
- Kahn's algorithm (O(V+E)) for cycle detection — correctly implemented with Topological Sort + DFS fallback for cycle path reporting
- Two-phase transaction (Phase 1: all Tasks, Phase 2: all TaskDependencies) prevents FK constraint violations during batch creation
- Result struct pattern (`Struct.new(:workflow_run, :tasks, :warnings, :errors, :parallel_groups, keyword_init: true)`) matches TeamImportService pattern
- Parser handles 4 LLM output variations: code fences, trailing commas, preamble text, raw JSON
- All error classes are named exceptions (`PrdNotFoundError`, `EmptyPrdError`, `ParseError`)
- Console output format matches PRD specification exactly

**Deductions:**
- **-1 pt** (`decomposition_service.rb`): Missing `# TODO: PRD-1-06 --force flag for partial saves (deferred)` comment. Amendment #3 explicitly required this comment. The `--force` flag behavior described in PRD line 192 ("save valid tasks only (with `--force` flag)") has no indicator in code that it was intentionally deferred. A future developer might not realize this was evaluated and deferred.
- **-1 pt** (`by_identifier` scope, `team_membership.rb:11`): The scope uses ILIKE on `id` in addition to exact match (`config->>'id' = ? OR config->>'id' ILIKE ?`). Amendment #7 explicitly said "Don't use ILIKE on `id` (IDs should be exact matches)." The implemented scope has THREE conditions — exact match AND ILIKE on id, plus ILIKE on name — slightly deviating from the specified pattern. The ILIKE on `id` is also more permissive than intended and matches the Issue #2 workaround from the task log rather than the cleaner amendment-specified approach.

  **Specified (Amendment #7):** `config->>'id' = ? OR config->>'name' ILIKE ?`
  **Implemented:** `config->>'id' = ? OR config->>'id' ILIKE ? OR config->>'name' ILIKE ?`

---

## Plan Adherence: 18/20

**All 11 Architect amendments incorporated:**
1. ✅ DispatchService returns WorkflowRun (`print_summary` returns `workflow_run`)
2. ✅ DecompositionService uses Result struct
3. ⚠️ WorkflowRun status handling implemented (decomposing→completed) **but `--force` TODO comment missing**
4. ✅ Kahn's algorithm implemented
5. ⚠️ `TeamMembership.by_identifier` scope created and used, but ILIKE-on-id deviation from spec
6. ✅ Two-phase transaction (create Tasks first, then TaskDependencies)
7. ✅ 6 additional tests implemented (#40-#45)
8. ✅ `--force` flag deferred (**code comment missing however**)
9. ✅ `test_empty_prd_file_raises_error` (#40) implemented
10. ✅ `test_handles_non_json_preamble_and_suffix` (#41) implemented
11. ✅ Console output tests (#43, #44) implemented

**Deductions:**
- **-1 pt**: Missing `# TODO: PRD-1-06 --force flag for partial saves (deferred)` comment (Amendment #3 explicitly required it in DecompositionService source)
- **-1 pt**: Integration test `test_full_decomposition_with_vcr` does not use VCR cassettes. The plan and Amendment #6 specified: "Cassette: `test/vcr_cassettes/decomposition_architect_response.yml`; Record mode: once; Match on: method, uri, body." The test uses a plain mock (`DispatchService.stubs(:call).returns(mock_workflow_run)`). While the test logic correctly validates the pipeline, it does not test actual LLM response parsing against a recorded real response. The test is even named "with vcr" but has a comment "In real scenario, this would use VCR" — the intent was clear but the implementation cut a corner.

  **Impact:** Low risk (full pipeline logic IS tested), but the VCR requirement was architectural (demonstrates resilience of parsing against real LLM output variance).

---

## Itemized Deductions Summary

| # | Deduction | Points | File:Line | Category |
|---|-----------|--------|-----------|----------|
| 1 | `test_identifies_parallel_groups` weak assertion (tests task structure only, not group detection) | -1 | `test/services/legion/decomposition_parser_test.rb:258` | Test Coverage |
| 2 | No unit test for `TeamMembership.by_identifier` scope in model tests | -1 | `test/models/team_membership_test.rb` (missing test) | Test Coverage |
| 3 | Missing `# TODO: PRD-1-06 --force flag for partial saves (deferred)` comment | -1 | `app/services/legion/decomposition_service.rb` | Code Quality + Plan Adherence |
| 4 | `by_identifier` scope uses ILIKE on `id` — Amendment #7 specified exact match only on id | -1 | `app/models/team_membership.rb:11-14` | Code Quality |
| 5 | Integration test uses mock instead of VCR cassette (test named "with_vcr" but no VCR) | -1 | `test/integration/decomposition_integration_test.rb:27,88` | Plan Adherence |
| 6 | Missing `--force` TODO comment counted in Plan Adherence | -1 | (same as #3 from plan angle) | Plan Adherence |

> **Note:** Deductions #3 and #6 overlap (same root issue counted in two criteria). Net unique deductions = 5 distinct issues = -6 points total.

---

## Remediation Steps (Not Required for PASS — Recommended)

### REM-1: Add `by_identifier` unit test to TeamMembershipTest
```ruby
# test/models/team_membership_test.rb
test "by_identifier scope finds by exact id match" do
  m = create(:team_membership, agent_team: @team, config: { "id" => "rails-lead", "name" => "Rails Lead", "provider" => "deepseek", "model" => "deepseek-reasoner" })
  assert_includes TeamMembership.by_identifier("rails-lead"), m
end

test "by_identifier scope finds by partial name match" do
  m = create(:team_membership, agent_team: @team, config: { "id" => "rails-lead", "name" => "Rails Lead Agent", "provider" => "deepseek", "model" => "deepseek-reasoner" })
  assert_includes TeamMembership.by_identifier("Rails"), m
end

test "by_identifier scope does not match partial id" do
  m = create(:team_membership, agent_team: @team, config: { "id" => "rails-lead-test", "name" => "Rails Lead Agent", "provider" => "deepseek", "model" => "deepseek-reasoner" })
  # Exact id match only: "rails" should NOT match "rails-lead-test" on id
  # (only name ILIKE is allowed for partial)
end
```

### REM-2: Add `--force` TODO comment to DecompositionService
```ruby
# In app/services/legion/decomposition_service.rb, around line 47-50:
# TODO: PRD-1-06 --force flag for partial saves (deferred)
# PRD line 192: "JSON valid but missing required fields → save valid tasks only (with --force flag)"
# Currently: any task errors cause full rejection. --force would allow partial saves.
if parse_result.errors.any?
```

### REM-3: Fix `by_identifier` scope to align with Amendment #7
```ruby
# In app/models/team_membership.rb:
scope :by_identifier, ->(identifier) {
  where("config->>'id' = ? OR config->>'name' ILIKE ?", identifier, "%#{identifier}%")
}
```
Note: This removes ILIKE on `id`. If the "Issue #2" workaround for partial id matching is needed, document it explicitly.

### REM-4 (Optional): Replace mock with VCR in integration test
Record a real decomposition response cassette for `test/vcr_cassettes/decomposition_architect_response.yml` and use `VCR.use_cassette("decomposition_architect_response")` in `test_full_decomposition_with_vcr`. This ensures the parser is validated against actual LLM output variance.

---

## Verification Commands Run

```bash
# 1. RuboCop on implementation files
rubocop --format simple app/services/legion/decomposition_parser.rb \
  app/services/legion/decomposition_service.rb \
  app/models/team_membership.rb bin/legion
# Result: 4 files inspected, no offenses detected ✅

# 2. RuboCop on test files
rubocop --format simple test/services/legion/decomposition_parser_test.rb \
  test/services/legion/decomposition_service_test.rb \
  test/integration/decomposition_integration_test.rb
# Result: 3 files inspected, no offenses detected ✅

# 3. Frozen string literal check
grep -rL 'frozen_string_literal' app/services/legion/decomposition_parser.rb \
  app/services/legion/decomposition_service.rb \
  test/services/legion/decomposition_parser_test.rb \
  test/services/legion/decomposition_service_test.rb \
  test/integration/decomposition_integration_test.rb
# Result: (empty — all files have frozen_string_literal) ✅

# 4. Parser tests
rails test test/services/legion/decomposition_parser_test.rb
# Result: 17 runs, 48 assertions, 0 failures, 0 errors, 0 skips ✅

# 5. Service tests
rails test test/services/legion/decomposition_service_test.rb
# Result: 16 runs, 51 assertions, 0 failures, 0 errors, 0 skips ✅

# 6. Integration tests
rails test test/integration/decomposition_integration_test.rb
# Result: 6 runs, 23 assertions, 0 failures, 0 errors, 0 skips ✅

# 7. Full test suite
rails test
# Result: 222 runs, 793 assertions, 0 failures, 0 errors, 0 skips ✅

# 8. rescue/raise coverage check
grep -n "rescue|raise" app/services/legion/decomposition_service.rb app/services/legion/decomposition_parser.rb
# Result: 4 raise sites — all have corresponding test coverage ✅

# 9. Test count verification
grep -c 'test "' test/services/legion/decomposition_parser_test.rb  # 17
grep -c 'test "' test/services/legion/decomposition_service_test.rb  # 16
grep -c 'test "' test/integration/decomposition_integration_test.rb  # 6
# Total: 39 automated tests ✅

# 10. by_identifier scope usage check
grep -n "by_identifier" app/models/team_membership.rb \
  app/services/legion/dispatch_service.rb \
  app/services/legion/decomposition_service.rb
# Result: scope defined in model; used in both services ✅

# 11. TODO/force flag check
grep -ri "TODO|force" app/services/legion/decomposition_service.rb
# Result: MISSING — --force TODO comment not present ⚠️

# 12. VCR check in integration test
grep -n "VCR|vcr|cassette" test/integration/decomposition_integration_test.rb
# Result: comment only ("In real scenario, this would use VCR") — no actual VCR ⚠️
```

---

## Notable Implementation Highlights

The implementation exceeds expectations in several areas:

1. **Kahn's algorithm** (O(V+E)) is correctly implemented with topological sort + DFS fallback for cycle path reporting — more sophisticated than the BFS-per-node approach that was rejected by Amendment #4.

2. **Parser resilience** handles all 4 specified LLM output variations (code fences, trailing commas, preamble text, raw JSON array) — verified by tests #2, #3, #41.

3. **Two-phase transaction** correctly creates all Task records first (building `task_map`), then all TaskDependency records — avoiding FK violations during batch creation.

4. **Result struct** follows TeamImportService pattern with `keyword_init: true` — consistent with established service patterns.

5. **Console output** matches PRD specification format including the task table, parallel groups section, and warning display.

---

*Report generated: 2026-03-07*
*QA Agent: Claude Sonnet (QA Specialist)*
*Retrospective reference: Φ14*
