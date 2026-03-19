# PRD-1-08 Manual Testing Guide

**PRD:** PRD-1-08 — Validation & End-to-End Testing  
**Epic:** Epic 1 — Orchestration Foundation  
**Created:** 2026-03-07  
**Purpose:** Step-by-step guide for human manual testing of the E2E test suite

---

## Prerequisites

Before you begin manual testing, ensure:

1. ✅ `chmod +x bin/legion` has been run (you mentioned this is done)
2. ✅ Full test suite passes: `rails test` → 263 runs, 0 failures
3. ✅ ROR team imported: `rake teams:import[~/.aider-desk]` (if not already done)
4. ⚠️ SmartProxy server available (for VCR cassette recording) — **OR** test with existing cassettes if available

---

## Phase 1: Test Without SmartProxy (Offline Testing)

These tests run without needing live SmartProxy access.

### Test 1: Run E2E Validation Command

**Purpose:** Verify the `bin/legion validate` CLI command works.

```bash
cd /Users/ericsmith66/development/legion
bin/legion validate
```

**Expected Output:**
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Legion E2E Validation Suite
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

⚠️  WARNING: No VCR cassettes found in test/vcr_cassettes/e2e/

To record cassettes:
  1. Start SmartProxy server
  2. Run: RECORD_VCR=1 rails test test/e2e/

Running tests anyway (tests will skip scenarios requiring cassettes)...

Running 10 tests in a single process...

# Running:

.SSSSSSSSS.

Finished in X.XXXXXs, XX.XXXX runs/s, XX.XXXX assertions/s.
10 runs, XX assertions, 0 failures, 0 errors, 8 skips
```

**Verification:**
- ✅ Command runs without errors
- ✅ Warning message appears (no VCR cassettes)
- ✅ 2 tests pass (Scenario 1 and 10)
- ✅ 8 tests skip (Scenarios 2-9)
- ✅ Exit code is 0 (success)

---

### Test 2: Verify Scenario 1 (Team Import Round-Trip)

**Purpose:** Verify team import works end-to-end.

```bash
cd /Users/ericsmith66/development/legion
rails test test/e2e/epic_1_validation_test.rb::test_scenario_1_team_import_round_trip -v
```

**Expected Output:**
```
Run options: --seed XXXXX

# Running:

Legion::Epic1ValidationTest#test_scenario_1_team_import_round_trip = 0.XX s = .

Finished in X.XXXXXs, X.XXXX runs/s, XX.XXXX assertions/s.
1 runs, 25 assertions, 0 failures, 0 errors, 0 skips
```

**Verification:**
- ✅ Test passes
- ✅ 25 assertions (verifies 4 agents imported, each with valid profile)
- ✅ No errors or failures

**Manual Verification in Rails Console:**
```bash
rails console
```

```ruby
# Verify 4 agents were imported
project = Project.last
team = project.agent_teams.last
puts "Team: #{team.name}"
puts "Agent count: #{team.team_memberships.count}"

# Verify each agent has valid profile
team.team_memberships.each do |m|
  profile = m.to_profile
  puts "\nAgent: #{profile.name}"
  puts "  Provider: #{profile.provider}"
  puts "  Model: #{profile.model}"
  puts "  Max Iterations: #{profile.max_iterations}"
  puts "  Tool Approvals: #{profile.tool_approvals.keys.count} tools configured"
  puts "  Custom Instructions: #{profile.custom_instructions.length} chars"
end
```

**Expected Console Output:**
```
Team: ROR
Agent count: 4

Agent: Agent A
  Provider: anthropic
  Model: claude-sonnet
  Max Iterations: 100
  Tool Approvals: X tools configured
  Custom Instructions: XX chars

Agent: Agent B
  Provider: openai
  Model: gpt-4
  Max Iterations: XXX
  Tool Approvals: X tools configured
  Custom Instructions: XX chars

Agent: Agent C
  Provider: deepseek
  Model: deepseek-reasoner
  Max Iterations: XXX
  Tool Approvals: X tools configured
  Custom Instructions: XX chars

Agent: Agent D
  Provider: openai
  Model: gpt-4
  Max Iterations: 50
  Tool Approvals: X tools configured
  Custom Instructions: XX chars
```

---

### Test 3: Verify Scenario 10 (Error Handling & Resilience)

**Purpose:** Verify error handling works correctly.

```bash
rails test test/e2e/epic_1_validation_test.rb::test_scenario_10_error_handling_resilience -v
```

**Expected Output:**
```
Executing plan for WorkflowRun #1 (2 tasks)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

[1/2] Task #1: Task 1 will fail — Agent A (claude-sonnet)
       ❌ Failed — Simulated failure

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Plan halted: 0/2 completed, 1 failed, 0 skipped

Executing plan for WorkflowRun #2 (2 tasks)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

[1/2] Task #3: Task 3 will fail — Agent A (claude-sonnet)
       ❌ Failed — Simulated failure

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Plan complete (with failures): 0/2 completed, 1 failed, 1 skipped

Legion::Epic1ValidationTest#test_scenario_10_error_handling_resilience = 0.XX s = .

Finished in X.XXXXXs, X.XXXX runs/s, XX.XXXX assertions/s.
1 runs, 14 assertions, 0 failures, 0 errors, 0 skips
```

**Verification:**
- ✅ Test passes
- ✅ 14 assertions (error messages, halt behavior, skip behavior)
- ✅ Error messages are clear and informative
- ✅ Both halt-on-failure and continue-on-failure modes work

---

### Test 4: Verify Helper Unit Tests

**Purpose:** Verify E2E helper methods work correctly.

```bash
rails test test/support/e2e_helper_test.rb -v
```

**Expected Output:**
```
# Running:

Legion::E2EHelperTest#test_create_test_project_helper_creates_project_with_unique_path = 0.XX s = .
Legion::E2EHelperTest#test_import_ror_team_helper_returns_AgentTeam = 0.XX s = .
Legion::E2EHelperTest#test_verify_event_trail_helper_validates_event_presence_and_ordering = 0.XX s = .
Legion::E2EHelperTest#test_verify_profile_attributes_helper_validates_matching_attributes = 0.XX s = .
Legion::E2EHelperTest#test_verify_task_structure_helper_validates_task_attributes = 0.XX s = .

Finished in X.XXXXXs, X.XXXX runs/s, XX.XXXX assertions/s.
5 runs, 32 assertions, 0 failures, 0 errors, 0 skips
```

**Verification:**
- ✅ All 5 helper tests pass
- ✅ 32 assertions total
- ✅ No errors or failures

---

## Phase 2: Test With SmartProxy (VCR Cassette Recording)

⚠️ **Prerequisites for this phase:**
- SmartProxy server running (e.g., `cd ~/smart-proxy && node server.js`)
- `SMART_PROXY_TOKEN` environment variable set
- ROR team imported with actual agent configs pointing to SmartProxy

---

### Test 5: Record VCR Cassettes

**Purpose:** Record VCR cassettes for the 8 scenarios that require SmartProxy.

**Step 1: Start SmartProxy Server**
```bash
# In a separate terminal
cd ~/smart-proxy
node server.js
```

**Expected Output:**
```
SmartProxy server listening on port 3001
Ready to route requests to LLM providers
```

**Step 2: Set Token**
```bash
export SMART_PROXY_TOKEN=your_actual_token_here
```

**Step 3: Record Cassettes**
```bash
cd /Users/ericsmith66/development/legion
RECORD_VCR=1 rails test test/e2e/epic_1_validation_test.rb -v
```

**Expected Output:**
```
# Running:

Legion::Epic1ValidationTest#test_scenario_1_team_import_round_trip = 0.XX s = .

Legion::Epic1ValidationTest#test_scenario_2_single_agent_full_identity = XX.XX s = .
[VCR] Recording new cassette: e2e/scenario_2_rails_lead_dispatch

Legion::Epic1ValidationTest#test_scenario_3_multi_agent_dispatch = XX.XX s = .
[VCR] Recording new cassette: e2e/scenario_3_multi_agent

Legion::Epic1ValidationTest#test_scenario_4_orchestrator_hook_behavior = XX.XX s = .
[VCR] Recording new cassette: e2e/scenario_4_hook_iteration_limit

Legion::Epic1ValidationTest#test_scenario_5_event_trail_forensics = XX.XX s = .
[VCR] Recording new cassette: e2e/scenario_5_multi_tool_call

Legion::Epic1ValidationTest#test_scenario_6_decomposition_task_creation = XX.XX s = .
[VCR] Recording new cassette: e2e/scenario_6_decompose_prd

Legion::Epic1ValidationTest#test_scenario_7_plan_execution_cycle = XX.XX s = .
[VCR] Recording new cassette: e2e/scenario_7_plan_execution

Legion::Epic1ValidationTest#test_scenario_8_full_decompose_execute_cycle = XX.XX s = .
[VCR] Recording new cassette: e2e/scenario_8_full_cycle

Legion::Epic1ValidationTest#test_scenario_9_dependency_graph_correctness = XX.XX s = .
[VCR] Recording new cassette: e2e/scenario_9_dependency_graph

Legion::Epic1ValidationTest#test_scenario_10_error_handling_resilience = 0.XX s = .

Finished in XX.XXXXXs, X.XXXX runs/s, XXX.XXXX assertions/s.
10 runs, XXX assertions, 0 failures, 0 errors, 0 skips
```

**Verification:**
- ✅ All 10 tests pass
- ✅ VCR cassettes recorded in `test/vcr_cassettes/e2e/`
- ✅ No errors or failures
- ✅ Test execution time < 60 seconds (after first run, when replaying from cassettes)

**Step 4: Verify Cassettes Created**
```bash
ls -lh test/vcr_cassettes/e2e/
```

**Expected Output:**
```
-rw-r--r--  1 user  staff   XXK Mar  7 HH:MM scenario_2_rails_lead_dispatch.yml
-rw-r--r--  1 user  staff   XXK Mar  7 HH:MM scenario_3_multi_agent.yml
-rw-r--r--  1 user  staff   XXK Mar  7 HH:MM scenario_4_hook_iteration_limit.yml
-rw-r--r--  1 user  staff   XXK Mar  7 HH:MM scenario_5_multi_tool_call.yml
-rw-r--r--  1 user  staff   XXK Mar  7 HH:MM scenario_6_decompose_prd.yml
-rw-r--r--  1 user  staff   XXK Mar  7 HH:MM scenario_7_plan_execution.yml
-rw-r--r--  1 user  staff   XXK Mar  7 HH:MM scenario_8_full_cycle.yml
-rw-r--r--  1 user  staff   XXK Mar  7 HH:MM scenario_9_dependency_graph.yml
```

**Verification:**
- ✅ 8 cassette files created
- ✅ Files are non-empty (check file sizes)
- ✅ Files are valid YAML (can open and inspect)

---

### Test 6: Verify Offline Replay (After Recording)

**Purpose:** Verify tests run offline using recorded cassettes.

**Step 1: Stop SmartProxy Server**
(Press Ctrl+C in the SmartProxy terminal)

**Step 2: Run Tests Without SmartProxy**
```bash
rails test test/e2e/epic_1_validation_test.rb -v
```

**Expected Output:**
```
# Running:

Legion::Epic1ValidationTest#test_scenario_1_team_import_round_trip = 0.XX s = .
Legion::Epic1ValidationTest#test_scenario_2_single_agent_full_identity = 0.XX s = .
Legion::Epic1ValidationTest#test_scenario_3_multi_agent_dispatch = 0.XX s = .
Legion::Epic1ValidationTest#test_scenario_4_orchestrator_hook_behavior = 0.XX s = .
Legion::Epic1ValidationTest#test_scenario_5_event_trail_forensics = 0.XX s = .
Legion::Epic1ValidationTest#test_scenario_6_decomposition_task_creation = 0.XX s = .
Legion::Epic1ValidationTest#test_scenario_7_plan_execution_cycle = 0.XX s = .
Legion::Epic1ValidationTest#test_scenario_8_full_decompose_execute_cycle = 0.XX s = .
Legion::Epic1ValidationTest#test_scenario_9_dependency_graph_correctness = 0.XX s = .
Legion::Epic1ValidationTest#test_scenario_10_error_handling_resilience = 0.XX s = .

Finished in XX.XXXXXs, XX.XXXX runs/s, XXX.XXXX assertions/s.
10 runs, XXX assertions, 0 failures, 0 errors, 0 skips
```

**Verification:**
- ✅ All 10 tests pass
- ✅ No skips (all scenarios use VCR cassettes)
- ✅ Test execution is fast (< 60 seconds)
- ✅ No network calls to SmartProxy (offline replay)

---

### Test 7: Validate Command After Cassette Recording

**Purpose:** Verify `bin/legion validate` works with cassettes present.

```bash
bin/legion validate
```

**Expected Output:**
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Legion E2E Validation Suite
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Running 10 tests in a single process...

# Running:

..........

Finished in XX.XXXXXs, XX.XXXX runs/s, XXX.XXXX assertions/s.
10 runs, XXX assertions, 0 failures, 0 errors, 0 skips

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  ✅ All E2E validation tests passed
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

**Verification:**
- ✅ No warning about missing cassettes
- ✅ All 10 tests pass
- ✅ Success message displayed
- ✅ Exit code is 0

---

## Phase 3: Manual Smoke Testing (Optional Deep Verification)

These tests verify the system works end-to-end through the CLI (not just test suite).

---

### Test 8: Manual Agent Dispatch

**Purpose:** Verify each agent runs with its full identity.

**Test 8a: Dispatch Rails Lead**
```bash
bin/legion execute \
  --team ROR \
  --agent rails-lead \
  --prompt "List your available tools" \
  --verbose
```

**Expected Output:**
```
Agent: Rails Lead (deepseek/deepseek-reasoner)
Status: completed
Iterations: X
Duration: XXXXms
Events: XX

[Real-time event stream if --verbose]
agent.started
tool.called (power---file_read)
tool.completed
response.complete
agent.completed
```

**Verification:**
- ✅ Agent runs without errors
- ✅ Model is deepseek-reasoner (from config)
- ✅ Events are logged to database
- ✅ WorkflowRun record created

**Test 8b: Dispatch Architect**
```bash
bin/legion execute \
  --team ROR \
  --agent architect \
  --prompt "What is your role?" \
  --verbose
```

**Expected Output:**
```
Agent: Architect (claude/claude-sonnet)
Status: completed
Iterations: X
Duration: XXXXms
Events: XX
```

**Verification:**
- ✅ Agent runs with different model (claude-sonnet)
- ✅ Different agent identity/config applied

**Test 8c: Verify in Rails Console**
```bash
rails console
```

```ruby
# Check last 2 workflow runs
runs = WorkflowRun.last(2)

runs.each do |run|
  puts "\nWorkflowRun ##{run.id}"
  puts "  Agent: #{run.team_membership.config['name']}"
  puts "  Model: #{run.team_membership.config['model']}"
  puts "  Status: #{run.status}"
  puts "  Iterations: #{run.iterations}"
  puts "  Events: #{run.workflow_events.count}"
  puts "  Event types: #{run.workflow_events.pluck(:event_type).uniq.join(', ')}"
end
```

**Verification:**
- ✅ Two distinct WorkflowRuns
- ✅ Different models for each agent
- ✅ Event trails captured
- ✅ Status is completed

---

### Test 9: Manual Decomposition

**Purpose:** Verify decomposition creates tasks with dependencies.

```bash
bin/legion decompose \
  --team ROR \
  --prd test/fixtures/test-prd-simple.md \
  --verbose
```

**Expected Output:**
```
━━━ Architect Response ━━━
[JSON output from architect]

Decomposition Result:
  3-5 tasks created
  Dependencies: X edges
  Parallel groups: X

Task List:
  Task #1: [test] Write model tests (score: X)
  Task #2: [code] Create Greeting model (score: X) → depends on #1
  Task #3: [test] Write controller tests (score: X)
  ...
```

**Verification:**
- ✅ Tasks created in database
- ✅ Dependencies captured as TaskDependency records
- ✅ Scores assigned (files_score, concepts_score, dependencies_score)
- ✅ Test-first ordering (code tasks depend on test tasks)

**Rails Console Verification:**
```ruby
run = WorkflowRun.last
tasks = run.tasks.order(:position)

puts "Tasks: #{tasks.count}"
tasks.each do |t|
  deps = t.dependencies.pluck(:id).join(", ")
  deps_str = deps.empty? ? "none" : deps
  puts "  Task ##{t.id}: [#{t.task_type}] #{t.prompt.truncate(50)} → deps: #{deps_str}"
end
```

**Verification:**
- ✅ 3-8 tasks created (range is acceptable due to LLM variability)
- ✅ At least one dependency exists
- ✅ Test tasks have no dependencies (can run first)
- ✅ Code tasks depend on test tasks

---

### Test 10: Manual Plan Execution

**Purpose:** Verify tasks execute in dependency order.

**Step 1: Get WorkflowRun ID from Test 9**
```ruby
# In rails console
WorkflowRun.last.id
# => 123 (example)
```

**Step 2: Execute Plan (Dry Run First)**
```bash
bin/legion execute-plan \
  --workflow-run 123 \
  --dry-run
```

**Expected Output:**
```
Execution Plan for WorkflowRun #123 (5 tasks)

Wave 1:
  Task #1: [test] Write model tests — score 6
  Task #3: [test] Write controller tests — score 5

Wave 2 (after wave 1):
  Task #2: [code] Create Greeting model — score 7 ← deps: [1]
  Task #4: [code] Create controller — score 8 ← deps: [3]

Wave 3 (after wave 2):
  Task #5: [test] System test — score 6 ← deps: [2,4]

DRY RUN — no tasks executed
```

**Verification:**
- ✅ Tasks grouped into waves (parallel-eligible grouping)
- ✅ Dependencies respected (wave ordering)
- ✅ No tasks executed (dry run)

**Step 3: Execute Plan (Real Run)**

⚠️ **Warning:** This will dispatch actual agents via SmartProxy. Ensure you have:
- SmartProxy running
- SMART_PROXY_TOKEN set
- Sufficient API credits

```bash
bin/legion execute-plan \
  --workflow-run 123 \
  --verbose
```

**Expected Output:**
```
Executing plan for WorkflowRun #123 (5 tasks)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

[1/5] Task #1: Write model tests — Rails Lead (deepseek-reasoner)
       ✅ Completed — 8 iterations, 25.3s, 42 events

[2/5] Task #3: Write controller tests — Rails Lead (deepseek-reasoner)
       ✅ Completed — 6 iterations, 18.7s, 35 events

[3/5] Task #2: Create Greeting model — Rails Lead (deepseek-reasoner)
       Depends on: Task #1 ✅
       ✅ Completed — 5 iterations, 15.2s, 28 events

[4/5] Task #4: Create controller — Rails Lead (deepseek-reasoner)
       Depends on: Task #3 ✅
       ✅ Completed — 7 iterations, 22.1s, 38 events

[5/5] Task #5: System test — Rails Lead (deepseek-reasoner)
       Depends on: Task #2 ✅, Task #4 ✅
       ✅ Completed — 4 iterations, 12.8s, 25 events

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Plan complete: 5/5 completed, 0 failed, 0 skipped
Total time: 1m 34s
Total iterations: 30
Total events: 168
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

**Verification:**
- ✅ Tasks execute in dependency order (1,3 → 2,4 → 5)
- ✅ Each task creates its own WorkflowRun
- ✅ Each task has execution_run_id set
- ✅ Status updates: pending → running → completed
- ✅ All tasks complete successfully

**Rails Console Verification:**
```ruby
run = WorkflowRun.find(123)
tasks = run.tasks.order(:position)

tasks.each do |t|
  puts "\nTask ##{t.id}: #{t.status}"
  puts "  Execution Run: #{t.execution_run_id}"
  if t.execution_run_id
    exec_run = WorkflowRun.find(t.execution_run_id)
    puts "  Iterations: #{exec_run.iterations}"
    puts "  Events: #{exec_run.workflow_events.count}"
  end
end
```

**Verification:**
- ✅ All tasks have status: completed
- ✅ All tasks have execution_run_id
- ✅ Each execution run has events and iterations

---

## Phase 4: Forensics & Event Trail Verification

### Test 11: Query Event Trail

**Purpose:** Verify complete event trail is queryable.

**Rails Console:**
```ruby
# Get the last plan execution
run = WorkflowRun.joins(:tasks).where(tasks: { status: 'completed' }).last
tasks = run.tasks.order(:position)

# Total events across all tasks
total_events = tasks.sum { |t| t.execution_run_id ? WorkflowRun.find(t.execution_run_id).workflow_events.count : 0 }
puts "Total events: #{total_events}"

# Reconstruct timeline
tasks.each do |task|
  next unless task.execution_run_id
  
  exec_run = WorkflowRun.find(task.execution_run_id)
  events = exec_run.workflow_events.order(:created_at)
  
  puts "\n━━━ Task ##{task.id}: #{task.prompt.truncate(40)} ━━━"
  puts "Events: #{events.count}"
  
  # First 5 events
  events.limit(5).each do |e|
    puts "  #{e.created_at.strftime('%H:%M:%S')} - #{e.event_type}"
  end
end

# Verify chronological ordering
tasks.each do |task|
  next unless task.execution_run_id
  
  exec_run = WorkflowRun.find(task.execution_run_id)
  events = exec_run.workflow_events.order(:created_at)
  timestamps = events.pluck(:created_at)
  
  is_ordered = timestamps == timestamps.sort
  puts "Task ##{task.id} events chronological: #{is_ordered ? '✅' : '❌'}"
end
```

**Expected Output:**
```
Total events: 168

━━━ Task #1: Write model tests ━━━
Events: 42
  10:15:23 - agent.started
  10:15:24 - tool.called
  10:15:25 - tool.completed
  10:15:26 - response.complete
  10:15:27 - agent.completed

━━━ Task #2: Create Greeting model ━━━
Events: 28
  10:15:50 - agent.started
  ...

Task #1 events chronological: ✅
Task #2 events chronological: ✅
Task #3 events chronological: ✅
Task #4 events chronological: ✅
Task #5 events chronological: ✅
```

**Verification:**
- ✅ Events exist for all tasks
- ✅ Event types include: agent.started, tool.called, tool.completed, response.complete, agent.completed
- ✅ Events are chronologically ordered
- ✅ Event data (payloads) contain useful information

---

## Phase 5: Error Path Testing

### Test 12: Verify Error Handling

**Test 12a: Non-existent Team**
```bash
bin/legion execute \
  --team INVALID_TEAM \
  --agent any-agent \
  --prompt "test"
```

**Expected Output:**
```
Team 'INVALID_TEAM' not found in project
```

**Expected Exit Code:** 3

**Verification:**
- ✅ Clear error message
- ✅ Mentions the invalid team name
- ✅ Exit code is 3 (not 0 or 1)

**Test 12b: Non-existent Agent**
```bash
bin/legion execute \
  --team ROR \
  --agent invalid-agent \
  --prompt "test"
```

**Expected Output:**
```
Agent 'invalid-agent' not found in team 'ROR'.
Available agents: rails-lead, architect, qa, debug
```

**Expected Exit Code:** 3

**Verification:**
- ✅ Clear error message
- ✅ Lists available agents
- ✅ Exit code is 3

**Test 12c: Task Failure (Halt Behavior)**

This is tested programmatically in Scenario 10, but you can verify manually:

```ruby
# Rails console
run = WorkflowRun.create!(
  project: Project.last,
  team_membership: TeamMembership.first,
  prompt: "Manual failure test",
  status: :completed
)

task = Task.create!(
  workflow_run: run,
  project: run.project,
  team_membership: run.team_membership,
  prompt: "This will fail",
  task_type: :code,
  position: 1,
  status: :pending,
  files_score: 2,
  concepts_score: 2,
  dependencies_score: 1
)

# Now intentionally cause a failure (e.g., invalid prompt or non-existent file reference)
# The PlanExecutionService should halt and mark task as failed
```

---

## Success Criteria Summary

After completing all manual tests, verify:

### Phase 1 (Offline Testing)
- ✅ `bin/legion validate` runs and reports skipped tests
- ✅ Scenario 1 passes (team import)
- ✅ Scenario 10 passes (error handling)
- ✅ Helper unit tests pass

### Phase 2 (VCR Recording)
- ✅ All 10 scenarios pass with SmartProxy
- ✅ 8 VCR cassettes recorded
- ✅ All 10 scenarios pass offline (cassette replay)
- ✅ Test execution < 60 seconds (offline)

### Phase 3 (Manual Smoke Testing)
- ✅ Individual agent dispatch works
- ✅ Decomposition creates tasks with dependencies
- ✅ Plan execution respects dependency order
- ✅ All tasks complete successfully

### Phase 4 (Forensics)
- ✅ Event trails queryable per task
- ✅ Events chronologically ordered
- ✅ Event payloads contain useful data

### Phase 5 (Error Handling)
- ✅ Non-existent team error is clear
- ✅ Non-existent agent error lists available agents
- ✅ Task failures are handled gracefully

---

## Troubleshooting

### Issue: Tests skip even with cassettes

**Solution:** Verify cassette files exist:
```bash
ls test/vcr_cassettes/e2e/
```

If missing, re-record with `RECORD_VCR=1`.

### Issue: VCR cassette mismatch errors

**Symptom:**
```
VCR::Errors::UnhandledHTTPRequestError: 
An HTTP request has been made that VCR does not know how to handle
```

**Solution:** Re-record cassettes:
```bash
rm -rf test/vcr_cassettes/e2e/
RECORD_VCR=1 rails test test/e2e/
```

### Issue: SmartProxy connection errors

**Symptom:**
```
Connection refused - connect(2) for "localhost" port 3001
```

**Solution:**
1. Verify SmartProxy is running: `curl http://localhost:3001/health`
2. Check SMART_PROXY_TOKEN is set: `echo $SMART_PROXY_TOKEN`
3. Verify agent configs point to correct SmartProxy URL

### Issue: Decomposition produces different task counts

**Expected Behavior:** LLM output is non-deterministic. Task counts may vary between 3-8 for the test PRD.

**Not an Issue:** This is expected and acceptable per the implementation plan.

---

## Final Verification Checklist

After completing all manual tests:

- [ ] All 10 E2E scenarios pass (with cassettes)
- [ ] `bin/legion validate` exits 0
- [ ] No test failures in full suite: `rails test`
- [ ] Team import creates 4 agents with valid profiles
- [ ] Individual agent dispatch works for all 4 agents
- [ ] Decomposition creates tasks with dependencies
- [ ] Plan execution completes all tasks in correct order
- [ ] Event trails are complete and queryable
- [ ] Error messages are clear and helpful
- [ ] VCR cassettes recorded and committed

---

## Commit VCR Cassettes (Final Step)

After successful manual testing and VCR cassette recording:

```bash
git add test/vcr_cassettes/e2e/
git commit -m "E2E: VCR cassettes recorded - all 10 scenarios passing"
git push
```

---

**Manual Testing Status:** Ready for execution  
**Estimated Time:** 30-45 minutes (Phase 1-2), 15-30 minutes (Phase 3-5)  
**Prerequisites:** SmartProxy access for Phase 2 only
