# PRD-1-08: Validation & End-to-End Testing — Implementation Plan

**PRD:** PRD-1-08 — Validation & End-to-End Testing  
**Epic:** Epic 1 — Orchestration Foundation  
**Plan Owner:** Rails Lead (DeepSeek Reasoner)  
**Created:** 2026-03-07  
**Status:** Awaiting Architect Approval

---

## Executive Summary

This is the capstone PRD for Epic 1. It creates a comprehensive E2E test suite that validates the complete orchestration pipeline (import → dispatch → hooks → decompose → execute-plan) and serves as the acceptance test suite proving all 7 preceding PRDs integrate correctly.

**Key Deliverables:**
1. E2E test suite with 10 scenarios covering the full integration stack
2. VCR cassettes for offline SmartProxy replay (no live API dependency)
3. Test PRD fixture for deterministic decomposition testing
4. E2E helper for shared test setup
5. `bin/legion validate` command wrapping the E2E tests
6. Complete test coverage proving the platform works end-to-end

**Complexity:** Medium — Mostly test code. Complexity is in VCR setup, multi-agent scenario orchestration, and crafting deterministic assertions for LLM output.

---

## File-by-File Changes

### 1. `test/e2e/epic_1_validation_test.rb` (NEW)

**Purpose:** Main E2E test file with 10 scenario tests proving Epic 1 integration.

**Implementation:**
```ruby
# frozen_string_literal: true

require "test_helper"

module Legion
  class Epic1ValidationTest < ActiveSupport::TestCase
    # Disable parallel tests for E2E — scenarios need isolation
    self.use_transactional_tests = false

    setup do
      # Clean slate per test
      DatabaseCleaner.clean_with(:truncation)
    end

    # ══════════════════════════════════════════════════════════════════════════
    # SCENARIO 1: Team Import Round-Trip
    # ══════════════════════════════════════════════════════════════════════════
    test "scenario_1_team_import_round_trip" do
      # Import ROR team from fixtures
      # Verify 4 agents in database with full configs
      # Verify to_profile on each agent returns valid Profile
      # Verify profile has correct provider, model, maxIterations, tool_approvals, customInstructions
    end

    # ══════════════════════════════════════════════════════════════════════════
    # SCENARIO 2: Single Agent Dispatch with Full Identity
    # ══════════════════════════════════════════════════════════════════════════
    test "scenario_2_single_agent_full_identity" do
      VCR.use_cassette("e2e/scenario_2_rails_lead_dispatch") do
        # Import team
        # Dispatch Rails Lead with simple coding prompt
        # Verify agent runs with correct model (from config)
        # Verify system prompt contains rules content
        # Verify SkillLoader discovered skills
        # Verify tool approvals enforced
        # Verify custom instructions present
        # Verify WorkflowRun created and completed
        # Verify WorkflowEvent trail complete
      end
    end

    # ══════════════════════════════════════════════════════════════════════════
    # SCENARIO 3: Multi-Agent Dispatch
    # ══════════════════════════════════════════════════════════════════════════
    test "scenario_3_multi_agent_dispatch" do
      # Dispatch each of 4 agents sequentially
      # Use separate VCR cassette per agent
      # Verify each runs with its own model, rules, identity
      # Verify 4 separate WorkflowRuns created
      # Verify event trails are agent-specific
    end

    # ══════════════════════════════════════════════════════════════════════════
    # SCENARIO 4: Orchestrator Hook Behavior
    # ══════════════════════════════════════════════════════════════════════════
    test "scenario_4_orchestrator_hook_behavior" do
      VCR.use_cassette("e2e/scenario_4_hook_iteration_limit") do
        # Dispatch agent with very low max_iterations (3)
        # Verify iteration budget hook fires
        # Verify warning in metadata
        # Verify WorkflowRun status reflects hook intervention
      end
    end

    # ══════════════════════════════════════════════════════════════════════════
    # SCENARIO 5: Event Trail Forensics
    # ══════════════════════════════════════════════════════════════════════════
    test "scenario_5_event_trail_forensics" do
      VCR.use_cassette("e2e/scenario_5_multi_tool_call") do
        # Run multi-tool-call agent task
        # Query WorkflowEvents and reconstruct timeline
        # Verify event count > 0
        # Verify event types include expected set
        # Verify chronological ordering
        # Verify payload contains useful data
      end
    end

    # ══════════════════════════════════════════════════════════════════════════
    # SCENARIO 6: Decomposition → Task Creation
    # ══════════════════════════════════════════════════════════════════════════
    test "scenario_6_decomposition_task_creation" do
      VCR.use_cassette("e2e/scenario_6_decompose_prd") do
        # Decompose test PRD using Architect
        # Verify Task records created with:
        #   - Correct task_type (test/code)
        #   - Valid scores (1-4 per dimension)
        #   - total_score computed
        #   - Dependencies as TaskDependency edges
        # Verify test-first ordering
        # Verify at least one parallel group exists
      end
    end

    # ══════════════════════════════════════════════════════════════════════════
    # SCENARIO 7: Plan Execution Cycle
    # ══════════════════════════════════════════════════════════════════════════
    test "scenario_7_plan_execution_cycle" do
      # Use tasks from scenario 6 OR create manually
      # Use separate VCR cassettes per task execution
      # Verify tasks dispatched in dependency order
      # Verify each task creates its own WorkflowRun
      # Verify Task statuses update: pending → running → completed
      # Verify Task.execution_run_id links to correct WorkflowRun
    end

    # ══════════════════════════════════════════════════════════════════════════
    # SCENARIO 8: Full Cycle (Decompose → Execute)
    # ══════════════════════════════════════════════════════════════════════════
    test "scenario_8_full_decompose_execute_cycle" do
      VCR.use_cassette("e2e/scenario_8_full_cycle") do
        # Decompose a small test PRD (2-3 tasks)
        # Execute the plan
        # Verify all tasks completed
        # Verify full event trails for each task
        # This is the happy path proving the complete pipeline
      end
    end

    # ══════════════════════════════════════════════════════════════════════════
    # SCENARIO 9: Dependency Graph Correctness
    # ══════════════════════════════════════════════════════════════════════════
    test "scenario_9_dependency_graph_correctness" do
      # Create known task graph manually:
      #   - 2 independent tasks (parallel-eligible)
      #   - 1 task depending on both (fan-in)
      #   - 2 tasks depending on fan-in (fan-out)
      # Execute plan
      # Verify correct ordering
      # Verify ready scope returns correct tasks at each step
    end

    # ══════════════════════════════════════════════════════════════════════════
    # SCENARIO 10: Error Handling & Resilience
    # ══════════════════════════════════════════════════════════════════════════
    test "scenario_10_error_handling_resilience" do
      # Test 1: Dispatch with non-existent team → verify error message
      # Test 2: Dispatch with non-existent agent → verify error lists available agents
      # Test 3: Execute plan with failing task → verify halt behavior
      # Test 4: Execute plan with --continue-on-failure → verify skipped dependents
    end

    private

    def setup_test_project
      # Helper to create project with imported team
    end

    def import_ror_team
      # Helper to import ROR team from fixtures
    end

    def verify_agent_identity(profile, expected)
      # Helper to verify profile attributes
    end

    def verify_event_trail(workflow_run, expected_types)
      # Helper to verify event trail completeness
    end
  end
end
```

**Test Count:** 10 test methods (one per scenario)

---

### 2. `test/support/e2e_helper.rb` (NEW)

**Purpose:** Shared helper methods for E2E test setup (import team, create project, verify profiles).

**Implementation:**
```ruby
# frozen_string_literal: true

module Legion
  module E2EHelper
    # Creates a test project with a unique path
    def create_test_project(name: "test-project")
      Project.create!(
        name: name,
        path: Rails.root.join("tmp/test_projects/#{name}_#{SecureRandom.hex(4)}")
      )
    end

    # Imports the ROR team from fixtures
    # Returns the AgentTeam record
    def import_ror_team(project)
      fixture_path = Rails.root.join("test/fixtures/aider_desk/valid_team")
      result = TeamImportService.call(
        aider_desk_path: fixture_path.to_s,
        project: project,
        team_name: "ROR",
        dry_run: false
      )
      
      raise "Team import failed" unless result.success?
      
      result.team
    end

    # Verifies agent profile has expected attributes
    def verify_profile_attributes(profile, expected)
      assert_equal expected[:provider], profile.provider
      assert_equal expected[:model], profile.model
      assert_equal expected[:max_iterations], profile.max_iterations if expected[:max_iterations]
      
      # Verify tool_approvals structure
      if expected[:tool_approvals]
        expected[:tool_approvals].each do |tool, approval|
          assert_equal approval, profile.tool_approvals[tool]
        end
      end
      
      # Verify custom instructions present
      if expected[:custom_instructions_contains]
        assert_includes profile.custom_instructions, expected[:custom_instructions_contains]
      end
    end

    # Verifies event trail completeness
    def verify_event_trail(workflow_run, expected_event_types: [])
      events = workflow_run.workflow_events.order(:created_at)
      
      assert_operator events.count, :>, 0, "Expected at least one event"
      
      expected_event_types.each do |type|
        assert events.exists?(event_type: type), "Expected event type #{type}"
      end
      
      # Verify chronological ordering
      timestamps = events.pluck(:created_at)
      assert_equal timestamps, timestamps.sort, "Events should be chronologically ordered"
    end

    # Verifies task attributes and dependencies
    def verify_task_structure(tasks)
      tasks.each do |task|
        assert_includes %w[test code], task.task_type
        assert_operator task.complexity_score, :>=, 1
        assert_operator task.complexity_score, :<=, 4
        assert_operator task.risk_score, :>=, 1
        assert_operator task.risk_score, :<=, 4
        assert_not_nil task.total_score
      end
    end
  end
end
```

---

### 3. `test/fixtures/test-prd-simple.md` (NEW)

**Purpose:** Minimal test PRD for decomposition scenarios. Must be simple enough to produce deterministic task count.

**Content:**
```markdown
#### PRD-TEST-01: Simple Greeting Model

### Overview
Add a basic Greeting model with a message field for testing the decomposition pipeline.

### Requirements

#### Functional
- Create Greeting model with message:string field
- Add validation: message must be present, max 100 characters
- Create controller with index and create actions
- Add routes for greetings resource

#### Testing
- Model tests: validation coverage
- Controller tests: index and create actions
- System test: create greeting via UI

### Acceptance Criteria
- [ ] AC1: Greeting model exists with message field
- [ ] AC2: Validations enforce presence and length
- [ ] AC3: Controller actions work correctly
- [ ] AC4: All tests pass

### Complexity
**Simple** — Basic CRUD model for testing purposes.
```

---

### 4. `bin/legion validate` (NEW)

**Purpose:** Thin wrapper around `rails test test/e2e/` with clear output formatting.

**Implementation:**
```bash
#!/usr/bin/env ruby
# frozen_string_literal: true

require "fileutils"

# Run E2E validation tests
puts "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
puts "  Legion E2E Validation Suite"
puts "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
puts ""

# Check if VCR cassettes exist
cassette_dir = File.join(__dir__, "../test/vcr_cassettes/e2e")
unless Dir.exist?(cassette_dir) && !Dir.empty?(cassette_dir)
  puts "⚠️  WARNING: No VCR cassettes found in #{cassette_dir}"
  puts ""
  puts "To record cassettes:"
  puts "  1. Start SmartProxy server"
  puts "  2. Run: RECORD_VCR=1 rails test test/e2e/"
  puts ""
  puts "Running tests anyway (may fail or require live SmartProxy)..."
  puts ""
end

# Run tests
system("rails test test/e2e/") || exit(1)

puts ""
puts "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
puts "  ✅ All E2E validation tests passed"
puts "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
```

**Permissions:** Make executable with `chmod +x bin/legion`

---

### 5. `test/support/vcr_setup.rb` (MODIFIED)

**Current VCR Configuration:**
```ruby
# frozen_string_literal: true

require "vcr"
require "webmock/minitest"

VCR.configure do |config|
  config.cassette_library_dir = File.join(Rails.root, "test", "vcr_cassettes")
  config.hook_into :webmock
  config.allow_http_connections_when_no_cassette = false

  # Filter sensitive tokens from recorded cassettes
  config.filter_sensitive_data("<SMART_PROXY_TOKEN>") { ENV.fetch("SMART_PROXY_TOKEN", "changeme") }

  # Default cassette options
  config.default_cassette_options = {
    record: :once,
    match_requests_on: %i[method uri]
  }
end
```

**Changes Needed:**
Add E2E-specific configuration for better determinism:

```ruby
# frozen_string_literal: true

require "vcr"
require "webmock/minitest"

VCR.configure do |config|
  config.cassette_library_dir = File.join(Rails.root, "test", "vcr_cassettes")
  config.hook_into :webmock
  config.allow_http_connections_when_no_cassette = false

  # Filter sensitive tokens from recorded cassettes
  config.filter_sensitive_data("<SMART_PROXY_TOKEN>") { ENV.fetch("SMART_PROXY_TOKEN", "changeme") }

  # Default cassette options
  config.default_cassette_options = {
    record: :once,
    match_requests_on: %i[method uri]
  }

  # E2E tests: Match on method + URI + body for more deterministic replay
  # Body matching ensures same prompt = same cassette
  config.before_record do |interaction|
    if interaction.request.uri.include?("smart-proxy") || interaction.request.uri.include?("openai")
      # Remove dynamic fields that change per run
      if interaction.request.body
        body = JSON.parse(interaction.request.body) rescue {}
        body.delete("stream")
        body.delete("stream_options")
        interaction.request.body = body.to_json
      end
      
      # Remove dynamic headers
      interaction.request.headers.delete("X-Correlation-Id")
      interaction.request.headers.delete("User-Agent")
    end
  end
end
```

**Rationale:** E2E tests need deterministic cassette matching. Body matching ensures same prompt replays same cassette. Dynamic fields (stream, correlation ID) are stripped before recording.

---

### 6. `test/test_helper.rb` (MODIFIED)

**Current:**
```ruby
# frozen_string_literal: true

ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require "factory_bot_rails"
require_relative "support/vcr_setup"
require "mocha/minitest"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    include FactoryBot::Syntax::Methods

    # Add more helper methods to be used by all tests here...
  end
end
```

**Changes Needed:**
Include E2E helper and add DatabaseCleaner for E2E test isolation:

```ruby
# frozen_string_literal: true

ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require "factory_bot_rails"
require_relative "support/vcr_setup"
require_relative "support/e2e_helper"
require "mocha/minitest"
require "database_cleaner/active_record"

# Configure DatabaseCleaner for E2E tests
DatabaseCleaner.strategy = :truncation

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    # E2E tests override this with self.use_transactional_tests = false
    parallelize(workers: :number_of_processors)

    include FactoryBot::Syntax::Methods
    include Legion::E2EHelper

    # Add more helper methods to be used by all tests here...
  end
end
```

---

### 7. `Gemfile` (MODIFIED)

**Add DatabaseCleaner gem for E2E test isolation:**

```ruby
group :test do
  # ... existing test gems ...
  gem "database_cleaner-active_record"
end
```

**Run:** `bundle install` after adding

---

### 8. `test/fixtures/aider_desk/valid_team/` (VERIFY)

**Purpose:** Ensure ROR team fixture exists for E2E testing.

**Required Files:**
- `agents/agent-a/config.json` (rails-lead)
- `agents/agent-b/config.json` (architect)
- `agents/agent-c/config.json` (qa)
- `agents/agent-d/config.json` (debug)
- `agents/order.json`

**Verification Step:** Check if these exist. If not, copy from `.aider-desk/agents/` and adapt IDs.

---

### 9. VCR Cassettes (TO BE RECORDED)

**Location:** `test/vcr_cassettes/e2e/`

**Cassettes to Record:**
1. `scenario_2_rails_lead_dispatch.yml`
2. `scenario_3_architect_dispatch.yml`
3. `scenario_3_qa_dispatch.yml`
4. `scenario_3_debug_dispatch.yml`
5. `scenario_4_hook_iteration_limit.yml`
6. `scenario_5_multi_tool_call.yml`
7. `scenario_6_decompose_prd.yml`
8. `scenario_7_task_1_execution.yml`
9. `scenario_7_task_2_execution.yml`
10. `scenario_8_full_cycle.yml`

**Recording Process:**
1. Start SmartProxy server
2. Set `SMART_PROXY_TOKEN` environment variable
3. Run: `RECORD_VCR=1 rails test test/e2e/epic_1_validation_test.rb`
4. Cassettes will be recorded in `test/vcr_cassettes/e2e/`
5. Commit cassettes to repo

**Note:** First recording requires live SmartProxy. Subsequent runs replay offline.

---

## Implementation Notes

### Test Isolation Strategy

**Problem:** E2E tests need clean database state per scenario (no shared data between tests).

**Solution:**
1. Disable parallel tests for E2E: `self.use_transactional_tests = false`
2. Use DatabaseCleaner with truncation strategy in setup
3. Each scenario creates its own Project/Team/data
4. No fixtures loaded automatically

### VCR Configuration for Determinism

**Problem:** LLM output is non-deterministic. Same prompt may produce different output on re-record.

**Solution:**
1. Match on method + URI (not body) for initial recording
2. Test structure (tasks exist, events exist, dependency graph valid) not exact content
3. Task count assertions use ranges (3-5 tasks) not exact numbers
4. VCR cassettes provide deterministic replay once recorded

**Trade-off:** Re-recording cassettes will change test behavior slightly. This is expected and acceptable.

### Error Path Testing (Scenario 10)

**Problem:** Error scenarios (non-existent team, failing task) don't hit SmartProxy.

**Solution:** No VCR cassettes needed for scenario 10. These are pure unit-style tests within E2E suite.

### Execution Time

**Target:** < 60 seconds for full E2E suite (via VCR replay)

**Strategy:**
1. VCR replay is fast (no actual HTTP calls)
2. DatabaseCleaner truncation is reasonably fast
3. 10 scenarios × ~5 seconds each = ~50 seconds

---

## Numbered Test Checklist (MUST-IMPLEMENT)

All tests must be implemented — no stubs, no placeholders, no skips.

### E2E Tests (10 scenarios)

1. ✅ `test_scenario_1_team_import_round_trip`
   - Import ROR team from fixtures
   - Verify 4 agents in database with full configs
   - Verify `to_profile` on each agent returns valid Profile
   - Verify profile attributes (provider, model, max_iterations, tool_approvals, custom_instructions)

2. ✅ `test_scenario_2_single_agent_full_identity`
   - VCR cassette: `e2e/scenario_2_rails_lead_dispatch`
   - Dispatch Rails Lead with simple prompt
   - Verify agent runs with correct model
   - Verify system prompt contains rules content
   - Verify SkillLoader discovered skills (skills---activate_skill tool present)
   - Verify tool approvals enforced
   - Verify custom instructions present
   - Verify WorkflowRun created and completed
   - Verify WorkflowEvent trail complete (agent.started, tool.*, response.complete, agent.completed)

3. ✅ `test_scenario_3_multi_agent_dispatch`
   - VCR cassettes: one per agent (4 total)
   - Dispatch Rails Lead, Architect, QA, Debug sequentially
   - Verify each runs with its own model and identity
   - Verify 4 separate WorkflowRuns created
   - Verify event trails are agent-specific (agent_id matches)

4. ✅ `test_scenario_4_orchestrator_hook_behavior`
   - VCR cassette: `e2e/scenario_4_hook_iteration_limit`
   - Dispatch agent with max_iterations: 3 and complex prompt
   - Verify iteration budget hook fires
   - Verify warning in WorkflowRun metadata
   - Verify WorkflowRun status reflects hook intervention

5. ✅ `test_scenario_5_event_trail_forensics`
   - VCR cassette: `e2e/scenario_5_multi_tool_call`
   - Run multi-tool-call agent task
   - Query WorkflowEvents and reconstruct timeline
   - Verify event count > 0
   - Verify event types include: agent.started, tool.called, tool.completed, response.complete, agent.completed
   - Verify chronological ordering (timestamps ascending)
   - Verify payload contains useful data (tool names, file paths, etc.)

6. ✅ `test_scenario_6_decomposition_task_creation`
   - VCR cassette: `e2e/scenario_6_decompose_prd`
   - Decompose test-prd-simple.md using Architect
   - Verify Task records created with:
     - Correct task_type (test or code)
     - Valid scores: complexity_score, risk_score, interdependency_score (1-4 each)
     - total_score computed
     - Dependencies as TaskDependency edges
   - Verify test-first ordering: implementation tasks depend on test tasks
   - Verify at least one parallel group exists (independent test tasks)

7. ✅ `test_scenario_7_plan_execution_cycle`
   - Create 3 tasks manually with dependencies
   - VCR cassettes: one per task execution (3 total)
   - Execute plan
   - Verify tasks dispatched in dependency order
   - Verify each task creates its own WorkflowRun
   - Verify Task statuses update: pending → running → completed
   - Verify Task.execution_run_id links to correct WorkflowRun

8. ✅ `test_scenario_8_full_decompose_execute_cycle`
   - VCR cassette: `e2e/scenario_8_full_cycle` (covers decompose + execute)
   - Decompose test-prd-simple.md
   - Execute the plan
   - Verify all tasks completed
   - Verify full event trails for each task
   - This is the "happy path" proving the complete pipeline

9. ✅ `test_scenario_9_dependency_graph_correctness`
   - Create known task graph manually:
     - Task A (independent)
     - Task B (independent)
     - Task C (depends on A and B) — fan-in
     - Task D (depends on C)
     - Task E (depends on C) — fan-out
   - VCR cassettes: one per task (5 total)
   - Execute plan
   - Verify execution order respects dependencies
   - Verify `ready_for_run` scope returns correct tasks at each step

10. ✅ `test_scenario_10_error_handling_resilience`
    - No VCR cassettes (pure error path testing)
    - Subtest 1: Dispatch with non-existent team → verify error message
    - Subtest 2: Dispatch with non-existent agent → verify error lists available agents
    - Subtest 3: Execute plan with failing task → verify halt behavior (stub DispatchService to raise error)
    - Subtest 4: Execute plan with `--continue-on-failure` → verify skipped dependents

### Helper Tests

11. ✅ `test_create_test_project_helper` (in e2e_helper_test.rb)
    - Verify create_test_project creates project with unique path

12. ✅ `test_import_ror_team_helper` (in e2e_helper_test.rb)
    - Verify import_ror_team returns AgentTeam

13. ✅ `test_verify_profile_attributes_helper` (in e2e_helper_test.rb)
    - Verify helper correctly validates profile attributes

14. ✅ `test_verify_event_trail_helper` (in e2e_helper_test.rb)
    - Verify helper correctly validates event trails

15. ✅ `test_verify_task_structure_helper` (in e2e_helper_test.rb)
    - Verify helper correctly validates task structure

### Validation Script Tests

16. ✅ `bin/legion validate` exits 0 when all tests pass (manual verification)
17. ✅ `bin/legion validate` exits 1 when tests fail (manual verification)
18. ✅ `bin/legion validate` prints warning if no VCR cassettes (manual verification)

---

## Error Path Matrix

| Error Scenario | Error Class/Type | Test Coverage | Expected Behavior |
|----------------|------------------|---------------|-------------------|
| Non-existent team in dispatch | Legion::TeamNotFoundError | Scenario 10 subtest 1 | Clear error message: "Team 'INVALID' not found in project" |
| Non-existent agent in dispatch | Legion::AgentNotFoundError | Scenario 10 subtest 2 | Error lists available agents: "Agent 'invalid' not found. Available: rails-lead, architect, qa, debug" |
| Task execution failure (halt) | StandardError propagation | Scenario 10 subtest 3 | PlanExecutionService halts, task marked failed, error message in task |
| Task execution failure (continue) | StandardError caught | Scenario 10 subtest 4 | PlanExecutionService continues, failed task marked failed, dependents skipped |
| VCR cassette not found | VCR::Errors::UnhandledHTTPRequestError | Validation script warning | Clear error message with recording instructions |
| SmartProxy token missing | AgentDesk::ConfigurationError | N/A (caught by DispatchService) | Error: "SMART_PROXY_TOKEN not set" (not E2E test responsibility) |

**Note:** All rescue blocks in E2E test code have corresponding tests. No dead code.

---

## Migration Steps

**N/A** — No migrations required. This PRD is test-only.

---

## Pre-QA Checklist Acknowledgment

I acknowledge that before submitting for QA scoring, I will:

1. ✅ Run `rubocop -A` on all modified/new files → 0 offenses
2. ✅ Verify every `.rb` file has `# frozen_string_literal: true` on line 1
3. ✅ Run full test suite: `rails test` → 0 failures, 0 errors, 0 skips (on PRD-specific tests)
4. ✅ Verify all 18 planned tests implemented (no stubs, no placeholders)
5. ✅ Verify all error paths have tests (see error path matrix)
6. ✅ Save completed checklist to `knowledge_base/epics/wip/epic-1-orchestration-foundation/feedback/pre-qa-checklist-PRD-1-08.md`

**Or run automated checks:**
```bash
bash scripts/pre-qa-validate.sh
```

---

## Architect Review Section

_This section will be populated by the Architect during plan approval (Phase 2 of Blueprint Workflow)._

---

## Implementation Sequence

1. Create directory structure: `test/e2e/`, `test/vcr_cassettes/e2e/`
2. Add DatabaseCleaner gem to Gemfile → `bundle install`
3. Create `test/support/e2e_helper.rb` with shared helpers
4. Update `test/test_helper.rb` to include E2E helper and DatabaseCleaner
5. Update `test/support/vcr_setup.rb` for E2E-specific configuration
6. Create `test/fixtures/test-prd-simple.md` test PRD
7. Verify `test/fixtures/aider_desk/valid_team/` has 4 agent configs
8. Create `test/e2e/epic_1_validation_test.rb` with 10 scenario tests
9. Create `bin/legion validate` script → make executable
10. Record VCR cassettes (requires live SmartProxy):
    - Start SmartProxy
    - Run: `RECORD_VCR=1 rails test test/e2e/`
    - Commit cassettes
11. Run full test suite: `rails test` → verify all pass
12. Run `bin/legion validate` → verify exit 0
13. Pre-QA checklist → all items pass
14. Submit for QA scoring

---

## Success Criteria

- [ ] All 10 E2E scenarios pass
- [ ] All VCR cassettes recorded and committed
- [ ] `bin/legion validate` exits 0 when tests pass
- [ ] Test suite completes in < 60 seconds (VCR replay)
- [ ] Full test suite: 0 failures, 0 errors, 0 skips
- [ ] RuboCop: 0 offenses
- [ ] Pre-QA checklist: all items pass
- [ ] QA score ≥ 90/100

---

## Notes

### VCR Recording Instructions

**First Time Setup:**
1. Start SmartProxy server: `cd ~/smart-proxy && node server.js`
2. Set token: `export SMART_PROXY_TOKEN=your_token`
3. Record: `RECORD_VCR=1 rails test test/e2e/`
4. Cassettes saved to `test/vcr_cassettes/e2e/`
5. Commit cassettes: `git add test/vcr_cassettes/e2e/ && git commit -m "E2E: VCR cassettes"`

**Subsequent Runs:**
- Just run: `rails test test/e2e/` (no SmartProxy needed)
- VCR replays from cassettes

**Re-recording:**
- Delete cassettes: `rm -rf test/vcr_cassettes/e2e/`
- Follow first-time setup

### Test Isolation

E2E tests disable parallel execution and use DatabaseCleaner truncation for isolation. This is slower than transactional tests but necessary for true E2E scenarios where multiple services interact.

### Assertion Strategy for LLM Output

Since LLM output is non-deterministic, assertions focus on structure and presence rather than exact content:
- ✅ "Task count is 3-5" (not "exactly 4")
- ✅ "At least one test task exists" (not "test task #2 has prompt X")
- ✅ "Event types include tool.called" (not "exactly 5 tool.called events")
- ✅ "Total score is computed" (not "total score equals 12")

This strategy allows cassette re-recording without test brittleness.

---

**Plan Status:** APPROVED
**Next Step:** Implement per approved plan with amendments

---

## Architect Review & Amendments
**Reviewer:** Architect Agent  
**Date:** 2026-03-08  
**Verdict:** APPROVED (with mandatory amendments below)

### Overall Assessment

This is a well-structured capstone plan. The 10-scenario coverage maps directly to the PRD's acceptance criteria and the PRD-to-scenario cross-reference is clear. The VCR strategy, assertion philosophy (structure-over-content), and test isolation approach are all sound. The numbered test checklist and error path matrix meet plan review standards.

However, there are several factual errors against the actual codebase that would cause implementation failures if not corrected. All amendments below are mandatory.

### Amendments Made (tracked for retrospective)

1. **[CHANGED] E2E helper `import_ror_team` — wrong TeamImportService API signature**
   - Plan passes `project:` as keyword arg to `TeamImportService.call` — this parameter does not exist
   - Actual signature: `TeamImportService.call(aider_desk_path:, project_path:, team_name:, dry_run:)`
   - Also calls `result.success?` — no such method on the Result struct. Use `result.errors.empty?` instead
   - Also accesses `result.team` which IS valid (it's on the Result struct), but the project must already exist at the path for the service to find_or_create it
   - **Fix:** Change to:
     ```ruby
     def import_ror_team(project)
       fixture_path = Rails.root.join("test/fixtures/aider_desk/valid_team")
       result = TeamImportService.call(
         aider_desk_path: fixture_path.to_s,
         project_path: project.path.to_s,
         team_name: "ROR",
         dry_run: false
       )
       raise "Team import failed: #{result.errors.join(', ')}" unless result.errors.empty?
       result.team
     end
     ```

2. **[CHANGED] Valid team fixture has 3 agents, not 4**
   - Plan references "4 agents" throughout (Scenarios 1, 3, fixture verification step 8)
   - Actual `valid_team/agents/order.json`: `{"agent-a": 0, "agent-b": 1, "agent-c": 2}` — only 3 agents
   - There is no `agent-d` directory in the fixture
   - **Fix:** Either (a) add an `agent-d` fixture with a 4th config to match the PRD's "4 agents", or (b) change all references from "4" to "3". Since the PRD says "4 agents" (matching the real ROR team: rails-lead, architect, qa, debug), option (a) is correct — **add an `agent-d` directory** with a 4th agent config to the `valid_team` fixture and update `order.json` to include it. Document this in Implementation Sequence step 7.

3. **[CHANGED] Scenario 3 VCR cassette names mismatch actual agent identifiers**
   - Plan lists cassettes `scenario_3_architect_dispatch.yml`, `scenario_3_qa_dispatch.yml`, `scenario_3_debug_dispatch.yml` (section 9, item 2-4)
   - But actual fixture agent IDs are `agent-a-id`, `agent-b-id`, `agent-c-id` (and `agent-d-id` after amendment 2)
   - Cassette names should match the fixture identifiers, not production agent names
   - **Fix:** Name cassettes after fixture agents or use generic names: `scenario_3_agent_a_dispatch.yml`, `scenario_3_agent_b_dispatch.yml`, etc. OR use a VCR cassette per-test (single cassette for Scenario 3 is simpler).

4. **[CHANGED] `bin/legion validate` — must integrate with existing Thor CLI, not be a separate script**
   - `bin/legion` already exists as a Thor CLI with `execute`, `execute-plan`, and `decompose` subcommands
   - The plan proposes replacing or creating a separate script — this conflicts with the existing structure
   - **Fix:** Add `validate` as a new Thor subcommand within the existing `bin/legion` CLI:
     ```ruby
     desc "validate", "Run E2E validation test suite"
     def validate
       cassette_dir = Rails.root.join("test/vcr_cassettes/e2e")
       unless Dir.exist?(cassette_dir) && !Dir.empty?(cassette_dir)
         puts "⚠️  WARNING: No VCR cassettes found in #{cassette_dir}"
         puts "To record: RECORD_VCR=1 rails test test/e2e/"
       end
       system("rails test test/e2e/") || exit(1)
     end
     ```
   - This preserves `bin/legion execute`, `bin/legion decompose`, etc. and adds `bin/legion validate`

5. **[CHANGED] VCR `before_record` hook modifies request body with `JSON.parse` — fragile for non-JSON bodies**
   - The `rescue {}` silently swallows parse errors, which is OK, but removing `stream` and `stream_options` from the body then re-serializing could alter JSON key order or formatting
   - More importantly, modifying the request body in `before_record` changes what's stored in the cassette, so the cassette body won't match the actual request on replay if body-matching is enabled
   - The plan's VCR section contradicts itself: section 5 adds body-matching hooks, but the Implementation Notes say "Match on method + URI (not body)"
   - **Fix:** Keep the default matching strategy (method + URI only) for E2E cassettes. Remove the `before_record` body-modification hook — it adds complexity without benefit when not body-matching. Only keep the header-stripping if desired for cassette cleanliness.

6. **[CHANGED] `verify_task_structure` helper checks `complexity_score` and `risk_score` — model has `files_score`, `concepts_score`, `dependencies_score`**
   - The Task model has: `files_score`, `concepts_score`, `dependencies_score`, `total_score`
   - There is no `complexity_score` or `risk_score` column
   - **Fix:** Change `verify_task_structure` to validate `files_score`, `concepts_score`, `dependencies_score` (each 1-4) and `total_score` (computed, 3-12):
     ```ruby
     def verify_task_structure(tasks)
       tasks.each do |task|
         assert_includes %w[test code], task.task_type
         assert_operator task.files_score, :>=, 1
         assert_operator task.files_score, :<=, 4
         assert_operator task.concepts_score, :>=, 1
         assert_operator task.concepts_score, :<=, 4
         assert_operator task.dependencies_score, :>=, 1
         assert_operator task.dependencies_score, :<=, 4
         assert_not_nil task.total_score
       end
     end
     ```

7. **[CHANGED] Scenario 9 test checklist references `ready_for_run` scope — but plan test code uses `ready` scope**
   - Test checklist item 9 says "Verify `ready_for_run` scope returns correct tasks at each step"
   - The actual model has both `scope :ready` and `scope :ready_for_run` (which is `where(workflow_run:).ready`)
   - For E2E scenario testing against a specific workflow_run, `Task.ready_for_run(workflow_run)` is the correct scope
   - **Fix:** Use `Task.ready_for_run(workflow_run)` in Scenario 9 assertions, not just `.ready`

8. **[CHANGED] Error path matrix references `Legion::TeamNotFoundError` and `Legion::AgentNotFoundError` — actual classes are nested**
   - Actual classes: `Legion::DispatchService::TeamNotFoundError`, `Legion::DispatchService::AgentNotFoundError`
   - **Fix:** Update error path matrix to reference correct class names

9. **[ADDED] DatabaseCleaner strategy should be scoped to E2E tests only**
   - Plan sets `DatabaseCleaner.strategy = :truncation` globally in `test_helper.rb` — this affects ALL tests
   - Non-E2E tests use transactional fixtures (faster) — truncation would slow them down significantly
   - **Fix:** Do NOT set global DatabaseCleaner strategy. Instead, configure it in the E2E test class only:
     ```ruby
     # In test/test_helper.rb — only require the gem, don't configure strategy
     require "database_cleaner/active_record"
     
     # In test/e2e/epic_1_validation_test.rb — configure per-class
     setup do
       DatabaseCleaner.strategy = :truncation
       DatabaseCleaner.clean
     end
     ```
   - Also: do NOT include `Legion::E2EHelper` in `ActiveSupport::TestCase` globally. Include it only in the E2E test class to avoid polluting all tests with E2E-specific helpers.

10. **[ADDED] Scenario 10 subtest 4 references `--continue-on-failure` flag — verify PlanExecutionService supports this**
    - Confirmed: `PlanExecutionService.call` accepts `continue_on_failure:` parameter and has `mark_dependents_skipped` logic
    - Scenario 10 subtest 3 (halt behavior) and subtest 4 (continue-on-failure) should stub `DispatchService.call` to raise, then verify PlanExecutionService behavior
    - This is correctly described in the plan but should use `mocha` stubs since it's already in the test dependencies
    - **Fix:** No code change needed — just confirming the approach is valid. Use `DispatchService.stubs(:call).raises(StandardError, "simulated failure")` for error path testing.

11. **[ADDED] Task model has `review` and `debug` task_types — not just `test` and `code`**
    - Plan's `verify_task_structure` and test checklist item 6 assert `task_type` is only "test" or "code"
    - Actual Task model enum: `test, code, review, debug`
    - The decomposition prompt may produce `review` or `debug` types
    - **Fix:** Change assertion to `assert_includes %w[test code review debug], task.task_type`

12. **[ADDED] Scenario 8 single VCR cassette won't work — decompose + execute involves multiple HTTP calls**
    - Scenario 8 wraps everything in one cassette `e2e/scenario_8_full_cycle`
    - But decompose dispatches the architect agent (1 HTTP call), then execute-plan dispatches N tasks (N HTTP calls)
    - A single VCR cassette CAN handle multiple requests in sequence (VCR plays them back in order), but only if the exact same number of requests happen in the exact same order
    - **Fix:** This is acceptable IF the test is deterministic. Add a comment noting that re-recording this cassette requires the exact same task count from decomposition. Alternatively, consider splitting into two cassettes (`scenario_8_decompose.yml` and `scenario_8_execute.yml`) for more resilience.

13. **[ADDED] Missing RECORD_VCR env var integration in VCR config**
    - Plan references `RECORD_VCR=1` for re-recording but never changes VCR config to honor it
    - Current config uses `record: :once` which means VCR records once and never again — `RECORD_VCR=1` has no effect
    - **Fix:** Add conditional record mode to VCR setup:
      ```ruby
      config.default_cassette_options = {
        record: ENV["RECORD_VCR"] ? :all : :once,
        match_requests_on: %i[method uri]
      }
      ```

14. **[ADDED] `test/e2e/` directory must be added to test autoload path**
    - By default, `rails test` discovers tests in `test/` subdirectories, but the `test/e2e/` path should be verified
    - `rails test test/e2e/` will work explicitly, but `rails test` (no path) discovers `test/**/*_test.rb` by default
    - **Fix:** Verify that `rails test` without arguments picks up `test/e2e/` files. If not, add to test paths in `config/application.rb`.

### Items NOT Changed (Approved As-Is)
- 10-scenario structure and PRD-to-scenario mapping — excellent coverage
- LLM assertion strategy (ranges, structure, presence) — correct approach
- Test isolation via `self.use_transactional_tests = false` — correct for E2E
- E2E helper test file (`e2e_helper_test.rb`) with 5 helper verification tests — good practice
- Implementation sequence order — logical and correct
- Test PRD fixture (`test-prd-simple.md`) content — appropriate for decomposition testing
- Error path matrix coverage — comprehensive (with class name correction per amendment 8)
- Pre-QA checklist acknowledgment — complete
- Success criteria — achievable and measurable

### Summary of Mandatory Changes
| # | Type | Impact | Risk if Ignored |
|---|------|--------|-----------------|
| 1 | API mismatch | `import_ror_team` will crash | 🔴 Test failure |
| 2 | Fixture count | 3 agents ≠ 4 agents assertions | 🔴 Test failure |
| 3 | Cassette names | Minor naming inconsistency | 🟡 Cosmetic |
| 4 | CLI structure | Breaks existing `bin/legion` | 🔴 Regression |
| 5 | VCR config contradiction | Body matching vs no-body matching | 🟡 Config confusion |
| 6 | Wrong column names | `complexity_score`/`risk_score` don't exist | 🔴 Test failure |
| 7 | Scope name | Minor — both work | 🟡 Correctness |
| 8 | Error class names | Incorrect rescue/match | 🟡 Documentation |
| 9 | Global DatabaseCleaner | Slows all tests | 🔴 Performance regression |
| 10 | Stub approach | Confirmed valid | ✅ No change |
| 11 | Task types | Assertion too restrictive | 🟡 False failures on re-record |
| 12 | Single cassette | Fragile on re-record | 🟡 Maintenance |
| 13 | RECORD_VCR unused | Re-recording workflow broken | 🔴 Workflow broken |
| 14 | Test path discovery | E2E tests may not run | 🟡 Verify at implementation |

PLAN-APPROVED
