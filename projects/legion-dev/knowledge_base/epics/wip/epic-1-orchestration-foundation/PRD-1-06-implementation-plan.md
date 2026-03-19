# PRD-1-06: Task Decomposition — Implementation Plan

## Overview
Implement the task decomposition pipeline where the Architect agent reads a PRD and produces a scored, dependency-aware, test-first task list. Tasks are persisted to the database with dependency edges.

## File-by-File Changes

### 1. app/services/legion/decomposition_service.rb (New)
**Purpose:** Orchestrates the decomposition process — reads PRD, dispatches Architect, parses output, creates Task records.

**Key Methods:**
- `.call(team_name:, prd_path:, agent_identifier: "architect", project_path:, dry_run: false)`
- `#call` — main orchestration
- `#read_prd_content` — reads and validates PRD file
- `#find_team_and_agent` — looks up AgentTeam and TeamMembership
- `#build_decomposition_prompt` — constructs prompt from template + PRD content
- `#dispatch_architect` — calls DispatchService to run Architect agent
- `#parse_response` — delegates to DecompositionParser
- `#validate_and_save_tasks` — validates parsed tasks, creates Task + TaskDependency records
- `#detect_parallel_groups` — identifies tasks that can run in parallel
- `#print_output` — formats console output with task table and parallel groups

**Error Handling:**
- PRD file not found → raise with clear message
- Team/agent not found → raise (handled by DispatchService)
- Unparseable output → log raw response to WorkflowRun.result, raise with message
- Invalid dependencies → raise with details
- Cycle detection → raise with cycle path

**Transaction:** Task and TaskDependency creation must be atomic (ActiveRecord transaction)

### 2. app/services/legion/decomposition_parser.rb (New)
**Purpose:** Parses Architect's JSON output into structured task objects, validates all constraints.

**Key Methods:**
- `.call(response_text:)`
- `#call` — returns `{ tasks: [...], warnings: [...], errors: [...] }`
- `#extract_json` — handles markdown code fences, trailing commas
- `#parse_json` — JSONable parsing with error handling
- `#validate_tasks` — checks required fields, score ranges, dependency references
- `#detect_cycles` — BFS/DFS cycle detection in dependency graph
- `#identify_warnings` — flags tasks with total_score > 6

**Validation Rules:**
- Required fields: position, type, prompt, agent, files_score, concepts_score, dependencies_score, depends_on
- Task type: one of `test`, `code`, `review`, `debug`
- Scores: 1-4 (inclusive)
- Total score: computed as sum of 3 scores
- Dependencies: all values in `depends_on` array must reference existing positions
- Cycles: no circular dependency chains

**Output Structure:**
```ruby
{
  tasks: [
    {
      position: 1,
      type: "test",
      prompt: "...",
      agent: "rails-lead",
      files_score: 2,
      concepts_score: 1,
      dependencies_score: 1,
      total_score: 4,
      depends_on: [],
      notes: "..."
    },
    # ...
  ],
  warnings: ["Task 5: total_score 7 > threshold 6"],
  errors: [] # empty if valid
}
```

### 3. app/services/legion/prompts/decomposition_prompt.md.erb (New)
**Purpose:** ERB template for the decomposition prompt sent to Architect.

**Variables:**
- `prd_content` — full PRD markdown text
- `team_name` — for context

**Template Structure:**
- Task description (decompose PRD into atomic tasks)
- Test-first ordering instructions
- Atomic task scale definitions (files, concepts, dependencies 1-4)
- Dependency and parallel awareness rules
- Required JSON output format with examples
- Agent assignment guidelines

**Content:** Full prompt text as specified in PRD Requirements section

### 4. bin/legion (Modified)
**Purpose:** Add `decompose` subcommand to CLI.

**Changes:**
- Add `decompose` command with Thor
- Options: `--team`, `--prd`, `--agent`, `--dry-run`, `--project`, `--verbose`
- Validate required options (team, prd)
- Call `Legion::DecompositionService.call(...)`
- Handle errors: file not found, team/agent not found, parse errors
- Exit codes: 0=success, 1=error, 2=invalid args, 3=not found

**Example:**
```ruby
desc "decompose", "Decompose a PRD into tasks"
method_option :team, type: :string, required: true, desc: "Agent team name"
method_option :prd, type: :string, required: true, desc: "Path to PRD file"
method_option :agent, type: :string, default: "architect", desc: "Agent identifier"
method_option :dry_run, type: :boolean, default: false, desc: "Show output without saving"
method_option :project, type: :string, desc: "Project path (default: current directory)"
method_option :verbose, type: :boolean, default: false, desc: "Print agent's full response"
def decompose
  # implementation
end
```

### 5. test/services/legion/decomposition_parser_test.rb (New)
**Purpose:** Unit tests for DecompositionParser.

**Tests (16 total):**
1. `test_parses_valid_json_array` — returns structured tasks
2. `test_handles_json_wrapped_in_code_fences` — strips ```json markers
3. `test_handles_trailing_commas` — lenient parsing
4. `test_validates_required_fields_missing` — reports missing prompt
5. `test_validates_required_fields_all_present` — passes
6. `test_validates_score_ranges_within_bounds` — accepts 1-4
7. `test_validates_score_ranges_out_of_bounds` — rejects 0 or 5
8. `test_computes_total_score_correctly` — sum of 3 scores
9. `test_detects_invalid_dependency_references` — task depends on non-existent position
10. `test_detects_dependency_cycles_simple` — A→B→A
11. `test_detects_dependency_cycles_complex` — A→B→C→A
12. `test_flags_tasks_over_threshold` — total_score > 6 in warnings
13. `test_identifies_parallel_groups` — tasks with no/satisfied deps
14. `test_returns_errors_for_unparseable_json` — malformed JSON
15. `test_handles_empty_json_array` — valid but empty
16. `test_validates_task_type_enum` — only test/code/review/debug

### 6. test/services/legion/decomposition_service_test.rb (New)
**Purpose:** Unit tests for DecompositionService.

**Tests (12 total):**
1. `test_reads_prd_file_content` — loads file text
2. `test_builds_decomposition_prompt_with_prd_embedded` — ERB rendering
3. `test_dispatches_architect_via_dispatch_service` — calls DispatchService.call
4. `test_passes_agent_response_to_parser` — DecompositionParser.call invoked
5. `test_creates_task_records_from_parsed_output` — Task.count increases
6. `test_creates_task_dependency_records` — TaskDependency edges match
7. `test_maps_agent_names_to_team_memberships` — "rails-lead" → TeamMembership lookup
8. `test_dry_run_mode_parses_but_does_not_save` — Task.count unchanged
9. `test_prd_file_not_found_raises_error` — clear error message
10. `test_unparseable_output_preserves_raw_response` — WorkflowRun.result contains raw text
11. `test_creates_workflow_run_with_decomposing_status` — initial status
12. `test_transaction_rollback_on_validation_error` — atomic save

### 7. test/integration/decomposition_integration_test.rb (New)
**Purpose:** Integration test with VCR-recorded Architect response.

**Tests (5 total):**
1. `test_full_decomposition_with_vcr` — end-to-end with cassette
2. `test_task_records_created_with_correct_scores` — verify DB state
3. `test_task_dependency_edges_match_architect_output` — dependency graph
4. `test_test_first_ordering_verified` — code tasks depend on test tasks
5. `test_parallel_groups_detected_correctly` — independent tasks identified

**VCR Setup:**
- Cassette: `test/vcr_cassettes/decomposition_architect_response.yml`
- Record mode: once
- Match on: method, uri, body (full request matching)

### 8. test/fixtures/sample_prd.md (New)
**Purpose:** Sample PRD file for testing decomposition.

**Content:**
- Minimal but realistic PRD (e.g., "Create User model with name and email")
- 2-3 features requiring test-first decomposition
- Used in both unit and integration tests

### 9. knowledge_base/task-logs/2026-03-07__prd-1-06-task-decomposition.md (New)
**Purpose:** Task log per requirements.

**Sections:**
- Implementation Summary
- Changes Made (file by file)
- Manual Testing Steps
- Expected Results
- Issues Encountered (if any)

## Numbered Test Checklist (MUST-IMPLEMENT)

### Unit Tests: DecompositionParser (16 tests)
1. ✓ test_parses_valid_json_array
2. ✓ test_handles_json_wrapped_in_code_fences
3. ✓ test_handles_trailing_commas
4. ✓ test_validates_required_fields_missing
5. ✓ test_validates_required_fields_all_present
6. ✓ test_validates_score_ranges_within_bounds
7. ✓ test_validates_score_ranges_out_of_bounds
8. ✓ test_computes_total_score_correctly
9. ✓ test_detects_invalid_dependency_references
10. ✓ test_detects_dependency_cycles_simple
11. ✓ test_detects_dependency_cycles_complex
12. ✓ test_flags_tasks_over_threshold
13. ✓ test_identifies_parallel_groups
14. ✓ test_returns_errors_for_unparseable_json
15. ✓ test_handles_empty_json_array
16. ✓ test_validates_task_type_enum

### Unit Tests: DecompositionService (12 tests)
17. ✓ test_reads_prd_file_content
18. ✓ test_builds_decomposition_prompt_with_prd_embedded
19. ✓ test_dispatches_architect_via_dispatch_service
20. ✓ test_passes_agent_response_to_parser
21. ✓ test_creates_task_records_from_parsed_output
22. ✓ test_creates_task_dependency_records
23. ✓ test_maps_agent_names_to_team_memberships
24. ✓ test_dry_run_mode_parses_but_does_not_save
25. ✓ test_prd_file_not_found_raises_error
26. ✓ test_unparseable_output_preserves_raw_response
27. ✓ test_creates_workflow_run_with_decomposing_status
28. ✓ test_transaction_rollback_on_validation_error

### Integration Tests (5 tests)
29. ✓ test_full_decomposition_with_vcr
30. ✓ test_task_records_created_with_correct_scores
31. ✓ test_task_dependency_edges_match_architect_output
32. ✓ test_test_first_ordering_verified
33. ✓ test_parallel_groups_detected_correctly

### System/Smoke Tests (Manual)
34. ✓ bin/legion decompose --team ROR --prd <path> (creates tasks)
35. ✓ bin/legion decompose --dry-run (no DB changes)
36. ✓ bin/legion decompose --verbose (prints full response)
37. ✓ Verify test-first ordering in console output
38. ✓ Verify parallel groups displayed
39. ✓ Verify task scores and dependencies in DB

**Total: 39 tests (33 automated + 6 manual)**

## Error Path Matrix

| Error Scenario | Handler | Test Coverage | Expected Behavior |
|----------------|---------|---------------|-------------------|
| PRD file not found | DecompositionService | test_prd_file_not_found_raises_error | Raise with message "File not found: {path}", exit 2 |
| Empty PRD file | DecompositionService | (add test) | Raise "PRD file is empty", exit 2 |
| Team not found | DispatchService (existing) | (inherited) | TeamNotFoundError, exit 3 |
| Agent not found | DispatchService (existing) | (inherited) | AgentNotFoundError, exit 3 |
| Unparseable JSON | DecompositionParser | test_returns_errors_for_unparseable_json | Errors array populated, service logs to WorkflowRun.result |
| Missing required fields | DecompositionParser | test_validates_required_fields_missing | Errors array with field names |
| Invalid score range | DecompositionParser | test_validates_score_ranges_out_of_bounds | Errors array with task position + field |
| Invalid dependency ref | DecompositionParser | test_detects_invalid_dependency_references | Errors: "Task N depends on non-existent M" |
| Dependency cycle | DecompositionParser | test_detects_dependency_cycles_simple/complex | Errors: "Cycle detected: A→B→A" |
| Score > 6 | DecompositionParser | test_flags_tasks_over_threshold | Warning (not error), tasks still created |
| Agent identifier not in team | DecompositionService | test_maps_agent_names_to_team_memberships | Default to first available agent with warning |
| Architect iteration limit | DispatchService (existing) | (inherited) | WorkflowRun status=iteration_limit, partial results |
| Transaction failure | DecompositionService | test_transaction_rollback_on_validation_error | Rollback all tasks, raise error |

## Migration Steps
None — uses existing Task and TaskDependency tables from PRD-1-01.

## Pre-QA Checklist Acknowledgment
I acknowledge that before requesting QA scoring I must:
1. Run `rubocop -A` on all new/modified .rb files → 0 offenses
2. Verify all .rb files have `# frozen_string_literal: true`
3. Run full test suite → 0 failures, 0 errors, 0 skips on PRD-1-06 tests
4. Verify all 39 tests from checklist implemented (no stubs/placeholders)
5. Verify all rescue/raise blocks have corresponding error path tests
6. Complete manual verification steps
7. Save completed checklist to `knowledge_base/epics/wip/epic-1-orchestration-foundation/feedback/pre-qa-checklist-PRD-1-06.md`

## Implementation Notes

### Decomposition Prompt Template Design
The prompt must be carefully crafted to produce consistent JSON output. Key elements:
- Clear JSON schema with examples
- Emphasis on test-first ordering (test task must have lower position than implementation task)
- Atomic scale definitions with concrete examples
- Instruction to respond with ONLY JSON (no preamble/explanation)

### Parser Resilience
LLM output can vary. Parser must handle:
- JSON wrapped in markdown code fences (```json ... ```)
- Trailing commas (use lenient JSON parser or strip)
- Extra whitespace, newlines
- Non-JSON preamble (extract JSON block)

Strategy: Use regex to extract JSON block, then parse with error handling.

### Cycle Detection Algorithm
Use BFS with visited set:
1. For each task, start BFS from that task
2. Track visited nodes in current path
3. If we encounter a node already in current path → cycle
4. Report cycle path for human debugging

### Parallel Group Detection
After all tasks parsed:
1. Identify tasks with zero dependencies → Group 1 (parallel-eligible)
2. For remaining tasks, group by "all dependencies completed" status
3. Tasks in same group with different file sets → parallel-eligible

Display in console: "Parallel groups: Tasks 1, 2 (independent)"

### Console Output Format
Use simple ASCII table (not a gem — keep it lightweight):
```
#   Type  Agent        Score    Deps    Status    Prompt
1   test  rails-lead   2+1+1=4  —       pending   Write tests for...
2   code  rails-lead   2+1+1=4  [1]     pending   Create model to...
```

### Agent Name Mapping
In parsed output, agent field is a string like "rails-lead". Map to TeamMembership:
1. Search TeamMembership where `config->>'id' ILIKE '%rails-lead%'` OR `config->>'name' ILIKE '%rails-lead%'`
2. If not found, default to team.team_memberships.first with warning
3. Store TeamMembership reference in Task.team_membership_id

### WorkflowRun for Decomposition
The decomposition itself is an agent dispatch (Architect runs). Create WorkflowRun with:
- status: `decomposing` (new enum value — already exists per PRD-1-01)
- prompt: "Decompose PRD: {prd_path}"
- Result field: contains Architect's raw response (for debugging if parse fails)

After successful parse and save, update status to `completed`.

### Dry-Run Mode
When `--dry-run` flag set:
- Parse and validate as normal
- Print console output
- Do NOT create Task or TaskDependency records
- Print "DRY RUN — no records saved"
- Exit 0

### Verbose Mode
When `--verbose` flag set:
- Print Architect's full response before parsing
- Useful for debugging prompt/output issues
- Format: "━━━ Architect Response ━━━\n{response}\n━━━"

## Dependencies
- **Blocked By:** PRD-1-01 (Task/TaskDependency models), PRD-1-04 (DispatchService)
- **Blocks:** PRD-1-07 (Plan Execution needs decomposed tasks)

## Estimated Effort
**High Complexity** — LLM output parsing, dependency graph validation, console formatting
**1.5 weeks**

## Next Steps After Plan Approval
1. Submit to Architect for review
2. Incorporate amendments
3. Implement per approved plan
4. Complete Pre-QA checklist
5. Request QA scoring ≥ 90
6. Debug if needed

---

## Architect Review & Amendments
**Reviewer:** Architect Agent
**Date:** 2026-03-07
**Verdict:** APPROVED

### Overall Assessment

This is a well-structured plan. The service decomposition (DecompositionService orchestrates, DecompositionParser validates) follows the established separation pattern. Test coverage at 39 items is thorough. The error path matrix covers the critical failure modes. The plan correctly identifies all 14 acceptance criteria from the PRD.

The following amendments are **mandatory** and must be incorporated during implementation. They address correctness issues, missing coverage gaps, and architectural alignment with existing services.

### Amendments Made (tracked for retrospective)

#### 1. [ADDED] DecompositionService must return a Result struct — not rely on DispatchService return value

**Why:** `DispatchService.call` currently returns `nil` (it ends with `print_summary` which calls `puts`). The plan says DecompositionService will "dispatch Architect via DispatchService.call(...)" and "pass agent response to parser" — but there is no return value from DispatchService to pass.

**Required approach:** DecompositionService must NOT call `DispatchService.call` directly as a black box. Instead, it should:
- Either (a) call `DispatchService.call(...)`, then read the response from `workflow_run.result` after dispatch completes (DispatchService stores it in `WorkflowRun#result` via `execute_agent`), OR
- (b) Refactor to accept the WorkflowRun and read `workflow_run.result` after dispatch.

**Recommended pattern:** Option (a) — DecompositionService should pass its own prompt to DispatchService, let it create the WorkflowRun, then retrieve the WorkflowRun to get the response. However, DecompositionService needs the `workflow_run` reference. Two sub-options:
- Have DispatchService return the WorkflowRun (cleanest — add `workflow_run` to its return), or
- Have DecompositionService look up the most recent WorkflowRun after dispatch.

**Decision:** Modify `DispatchService.call` to return the `WorkflowRun` record. This is a minimal, non-breaking change (current callers in `bin/legion execute` ignore the return value). DecompositionService then does:
```ruby
workflow_run = DispatchService.call(team_name:, agent_identifier:, prompt:, project_path:)
response_text = workflow_run.result
```

Add a **Result struct** to DecompositionService (following TeamImportService pattern):
```ruby
Result = Struct.new(:workflow_run, :tasks, :warnings, :errors, :parallel_groups, keyword_init: true)
```

Additionally, the plan states DecompositionService creates a WorkflowRun with status `decomposing` — but DispatchService already creates its own WorkflowRun with status `running`. The DecompositionService should NOT create a second WorkflowRun. Instead, it should update the DispatchService-created WorkflowRun's status to `decomposing` before dispatch, and `completed` after. This requires either (a) creating the WorkflowRun externally and passing it to DispatchService, or (b) post-hoc updating the status.

**Simplest correct approach:** Let DispatchService create the WorkflowRun as `running` (existing behavior), then DecompositionService updates it to `decomposing` right after getting the reference back, then to `completed` after task creation. This avoids modifying DispatchService's internal WorkflowRun creation logic. The `decomposing` status is set AFTER the agent run completes but BEFORE task parsing/saving — it signals "we have a response, now parsing."

Alternatively, if the intent is that the WorkflowRun shows `decomposing` during the agent run itself, DecompositionService will need to create the WorkflowRun itself and pass it to a lower-level dispatch method. This is a bigger refactor — defer to the simpler approach unless the PRD strictly requires `decomposing` during the LLM call.

#### 2. [ADDED] Missing test: empty PRD file

The error path matrix correctly lists "Empty PRD file" as a scenario but marks its test as `(add test)`. This must be a numbered test.

**Add to test checklist as test #40:**
- `test_empty_prd_file_raises_error` in `decomposition_service_test.rb` — MUST-IMPLEMENT

#### 3. [ADDED] Missing test: `--force` flag for partial saves (PRD requirement)

The PRD states (line 192): "JSON valid but missing required fields → Report which tasks have errors, save valid tasks only (with `--force` flag)." The plan does not address the `--force` flag at all. Two options:
- (a) Implement `--force` as specified in PRD, OR
- (b) Explicitly defer it as a non-goal with a comment.

**Decision:** Defer `--force` flag. The plan's current behavior (reject all tasks if any have errors) is safer for v1. Add a code comment `# TODO: PRD-1-06 --force flag for partial saves (deferred)` in DecompositionService. No test needed, but add a note in the plan.

#### 4. [CHANGED] Cycle detection algorithm — use Kahn's algorithm (topological sort), not BFS from each node

**Why:** The plan proposes "For each task, start BFS from that task" — this is O(V × (V + E)) and conceptually awkward for detecting cycles in a parsed task list (not yet in DB). The existing `TaskDependency#no_cycles` model validation uses BFS on persisted records (acceptable for single-edge validation). But DecompositionParser operates on **in-memory parsed data** — it has the full graph upfront.

**Better approach:** Use Kahn's algorithm (topological sort attempt):
1. Build adjacency list + in-degree count from parsed `depends_on` arrays
2. Initialize queue with nodes having in_degree 0
3. Process queue: for each node, decrement in_degree of its dependents
4. If processed count < total tasks → cycle exists
5. To report the cycle path: do a DFS on remaining unprocessed nodes to find the actual cycle

**Benefits:** O(V + E), single pass, naturally produces topological order (useful for verifying test-first ordering), and reports which nodes are in cycles.

#### 5. [CHANGED] Parser resilience — add handling for non-JSON preamble text

The plan mentions "Non-JSON preamble (extract JSON block)" under Parser Resilience but doesn't have a dedicated test. LLMs frequently emit "Here is the decomposition:" before the JSON.

**Required:** The `extract_json` method must handle:
1. JSON wrapped in ```json...``` code fences (test #2 covers)
2. JSON preceded by text preamble like "Here is the task breakdown:\n" (NOT covered)
3. JSON followed by trailing text like "\nLet me know if you'd like changes"
4. Multiple JSON blocks (take the first valid array)

**Add test #41:** `test_handles_non_json_preamble_and_suffix` — MUST-IMPLEMENT (in parser tests)

#### 6. [ADDED] Missing test: DispatchService returns WorkflowRun (per Amendment #1)

Since we're modifying DispatchService to return the WorkflowRun, add:

**Add test #42:** `test_dispatch_service_returns_workflow_run` — MUST-IMPLEMENT (in decomposition_service_test.rb, stub DispatchService.call to return a mock workflow_run with result text)

Note: This test belongs in the DecompositionService test file as a stub/mock assertion. The actual DispatchService return-value change should be tested in the existing DispatchService tests (if they exist), but that's a minor addition.

#### 7. [CHANGED] Agent name mapping — align with existing `find_membership` pattern in DispatchService

The plan says: `config->>'id' ILIKE '%rails-lead%' OR config->>'name' ILIKE '%rails-lead%'`. DispatchService uses exact match on `id` and ILIKE on `name`:
```ruby
team.team_memberships.find_by("config->>'id' = ? OR config->>'name' ILIKE ?", identifier, "%#{identifier}%")
```

**Use the same query pattern** — exact match on `id`, ILIKE on `name`. Don't use ILIKE on `id` (IDs should be exact matches). Extract this into a shared scope or class method on TeamMembership to avoid duplication:
```ruby
# In TeamMembership model:
scope :by_identifier, ->(identifier) {
  where("config->>'id' = ? OR config->>'name' ILIKE ?", identifier, "%#{identifier}%")
}
```

Then both DispatchService and DecompositionService use `team.team_memberships.by_identifier(agent_name).first`.

#### 8. [ADDED] Console output test coverage

The PRD has AC9 (parallel groups displayed in console output) and the plan lists parallel group detection, but there's no test that verifies the actual console output format. Console output is user-facing and should be tested.

**Add test #43:** `test_console_output_includes_task_table` in `decomposition_service_test.rb` — capture $stdout, verify table headers and task rows present. MUST-IMPLEMENT.

**Add test #44:** `test_console_output_includes_parallel_groups` in `decomposition_service_test.rb` — verify "Parallel groups:" section in output. MUST-IMPLEMENT.

#### 9. [CHANGED] Transaction boundary clarification

The plan correctly states "Task and TaskDependency creation must be atomic (ActiveRecord transaction)" but doesn't specify what happens with the existing `TaskDependency#no_cycles` validation during batch creation.

**Important:** When creating tasks in a transaction, the cycle detection in `TaskDependency#no_cycles` does BFS queries against already-persisted TaskDependency rows within the same transaction. This means:
- Task creation order matters — earlier tasks must exist before their dependents' TaskDependency records are created
- Create ALL Task records first (without dependencies), THEN create all TaskDependency records
- This ensures `depends_on_task_id` references valid Task records

The DecompositionParser's in-memory cycle detection (Amendment #4) is the **primary** cycle check. The model validation is a **secondary** safety net. They are complementary — one operates on parsed data, the other on DB records.

**Required implementation pattern:**
```ruby
ApplicationRecord.transaction do
  # Phase 1: Create all Task records (position → Task mapping)
  task_map = {}
  parsed_tasks.each do |t|
    task = Task.create!(...)
    task_map[t[:position]] = task
  end

  # Phase 2: Create all TaskDependency records
  parsed_tasks.each do |t|
    t[:depends_on].each do |dep_position|
      TaskDependency.create!(task: task_map[t[:position]], depends_on_task: task_map[dep_position])
    end
  end
end
```

#### 10. [ADDED] WorkflowRun association for decomposed tasks

The PRD states (line 183): "Tasks created are associated with the decomposition WorkflowRun via `Task.workflow_run_id`". The plan mentions this in the WorkflowRun section but doesn't have a dedicated test.

This is already partially covered by test #21 (`test_creates_task_records_from_parsed_output`) and test #27 (`test_creates_workflow_run_with_decomposing_status`). Verify that test #21 asserts `Task.workflow_run_id == workflow_run.id` — not just count.

#### 11. [ADDED] Integration test must verify WorkflowRun status transition

The PRD's AC11 states: "Decomposition creates its own WorkflowRun (status: `decomposing`)." The integration test section in the plan lists test_full_decomposition_with_vcr but doesn't verify the final WorkflowRun status.

The PRD test cases (line 293) mention: "Verify WorkflowRun for decomposition itself has status `completed` (or `decomposing` → `completed`)."

**Add test #45:** `test_workflow_run_status_transitions_to_completed` in integration tests — verify the WorkflowRun ends with status `completed` after successful decomposition. MUST-IMPLEMENT.

### Updated Test Count

Original: 39 (33 automated + 6 manual)
Added: 6 automated tests (#40-#45)
**New total: 45 (39 automated + 6 manual)**

### Updated Numbered Test Checklist Additions

40. ✓ test_empty_prd_file_raises_error — MUST-IMPLEMENT (service test)
41. ✓ test_handles_non_json_preamble_and_suffix — MUST-IMPLEMENT (parser test)
42. ✓ test_dispatch_service_returns_workflow_run — MUST-IMPLEMENT (service test)
43. ✓ test_console_output_includes_task_table — MUST-IMPLEMENT (service test)
44. ✓ test_console_output_includes_parallel_groups — MUST-IMPLEMENT (service test)
45. ✓ test_workflow_run_status_transitions_to_completed — MUST-IMPLEMENT (integration test)

### Updated Error Path Matrix Additions

| Error Scenario | Handler | Test Coverage | Expected Behavior |
|----------------|---------|---------------|-------------------|
| Empty PRD file | DecompositionService | test_empty_prd_file_raises_error (#40) | Raise "PRD file is empty", exit 2 |
| Non-JSON preamble in response | DecompositionParser | test_handles_non_json_preamble_and_suffix (#41) | Extract JSON array, ignore surrounding text |

### Items NOT Requiring Revision (Lead Did Well)

- ✅ Parser resilience strategy (regex extraction, code fence handling, trailing commas) is sound
- ✅ Dry-run mode design is clean and follows TeamImportService's pattern
- ✅ Exit code scheme (0/1/2/3) is consistent with existing `bin/legion execute`
- ✅ ERB prompt template approach is appropriate
- ✅ VCR integration test strategy is correct
- ✅ Test-first ordering verification in integration tests aligns with PRD's core value proposition
- ✅ Task type enum matches existing Task model (`test`, `code`, `review`, `debug`)
- ✅ Score validation (1-4) matches existing Task model validations
- ✅ Dependency tracking correctly identifies PRD-1-01 and PRD-1-04 as blockers
- ✅ Pre-QA checklist acknowledgment is complete

### Summary of Mandatory Changes

1. **DispatchService must return WorkflowRun** — minimal change, non-breaking
2. **DecompositionService needs Result struct** — follows TeamImportService pattern
3. **WorkflowRun status handling** — update after dispatch, not create duplicate
4. **Kahn's algorithm for cycle detection** in parser (not BFS per-node)
5. **TeamMembership.by_identifier scope** — shared with DispatchService
6. **Two-phase transaction** — create Tasks first, then TaskDependencies
7. **6 additional tests** — empty PRD, preamble handling, return value, console output (×2), status transition
8. **Defer `--force` flag** with TODO comment

PLAN-APPROVED
