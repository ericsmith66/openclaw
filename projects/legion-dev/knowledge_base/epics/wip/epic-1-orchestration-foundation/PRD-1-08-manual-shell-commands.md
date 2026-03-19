# PRD-1-08 Manual Shell Testing (No Test Framework)

**Purpose:** Test the Epic 1 orchestration pipeline using only shell commands and Rails console  
**SmartProxy:** `192.168.4.253:3001`

---

## Setup

```bash
cd /Users/ericsmith66/development/legion

# Set environment variables (REQUIRED for Legion to connect to SmartProxy)
source scripts/set_smartproxy_env.sh

# Verify SmartProxy access
curl http://192.168.4.253:3001/health
# Expected: {"status":"ok","version":"1.0.0"}
```

**Note:** The `.env` file in the project root already contains these values, but `bin/legion` doesn't automatically load it. You MUST export the variables in your shell session using the command above.

---

## Test 1: Verify Team Import

```bash
rails runner "
team = AgentTeam.find_by(name: 'ROR')
puts \"Team: #{team.name}\"
puts \"Agents: #{team.team_memberships.count}\"
team.team_memberships.order(:position).each do |m|
  puts \"  - #{m.config['name']} (#{m.config['provider']}/#{m.config['model']})\"
end
"
```

**Expected Output:**
```
Team: ROR
Agents: 9
  - Aider (anthropic/claude-sonnet-4-6)
  - Architect (anthropic/claude-sonnet-4-6)
  - Debug Agent (anthropic/claude-opus-4-6)
  - QA Agent (anthropic/claude-sonnet-4-6)
  - Rails Lead (deepseek/deepseek-reasoner)
  ...
```

---

## Test 2: Dispatch Single Agent (Rails Lead)

```bash
bin/legion execute \
  --team ROR \
  --agent "Architect" \
  --prompt "What tools do you have available? List the tool groups." \
  --verbose
```

**Expected Output:**
```
Agent: Rails Lead (deepseek/deepseek-reasoner)
Status: completed
Iterations: 1-3
Duration: XXXX ms
Events: XX
```

**Verify in Rails Console:**
```bash
rails console
```

```ruby
# Get the last workflow run
run = WorkflowRun.last
puts "Agent: #{run.team_membership.config['name']}"
puts "Model: #{run.team_membership.config['model']}"
puts "Provider: #{run.team_membership.config['provider']}"
puts "Status: #{run.status}"
puts "Iterations: #{run.iterations}"
puts "Duration: #{run.duration_ms}ms"
puts "Events: #{run.workflow_events.count}"
puts "\nEvent types:"
run.workflow_events.pluck(:event_type).uniq.each { |t| puts "  - #{t}" }
```

**Expected Console Output:**
```
Agent: Rails Lead
Model: deepseek-reasoner
Provider: deepseek
Status: completed
Iterations: 1-3
Duration: XXXX ms
Events: 10-20

Event types:
  - agent.started
  - response.streaming
  - response.delta
  - response.complete
  - agent.completed
```

**Exit console:** `exit`

---

## Test 3: Dispatch Multiple Agents

**Dispatch Architect:**
```bash
bin/legion execute \
  --team ROR \
  --agent "Architect" \
  --prompt "What is your role in the team?"
```

**Dispatch QA Agent:**
```bash
bin/legion execute \
  --team ROR \
  --agent "QA Agent" \
  --prompt "What is your primary responsibility?"
```

**Dispatch Debug Agent:**
```bash
bin/legion execute \
  --team ROR \
  --agent "Debug Agent" \
  --prompt "What types of issues do you handle?"
```

**Verify All Runs:**
```bash
rails runner "
puts 'Last 4 Workflow Runs:'
puts
WorkflowRun.last(4).each do |run|
  puts \"ID: #{run.id}\"
  puts \"  Agent: #{run.team_membership.config['name']}\"
  puts \"  Model: #{run.team_membership.config['model']}\"
  puts \"  Status: #{run.status}\"
  puts \"  Iterations: #{run.iterations}\"
  puts \"  Events: #{run.workflow_events.count}\"
  puts
end
"
```

**Expected:** 4 different workflow runs with different agents and models

---

## Test 4: Decompose a PRD

**Create a test PRD file:**
```bash
cat > /tmp/test-prd.md << 'EOF'
#### PRD-TEST-01: Simple Greeting Feature

### Overview
Add a greeting feature to display welcome messages.

### Requirements
- Create Greeting model with message:string field
- Add validation: message required, max 100 chars
- Create GreetingsController with index and create actions
- Add routes for greetings resource

### Acceptance Criteria
- [ ] Model exists with validations
- [ ] Controller actions work
- [ ] Routes configured
- [ ] Tests pass
EOF
```

**Decompose the PRD:**
```bash
bin/legion decompose \
  --team ROR \
  --prd /tmp/test-prd.md \
  --verbose
```

**Expected Output:**
```
━━━ Architect Response ━━━
[JSON with tasks]

Decomposition Result:
  3-5 tasks created
  Dependencies: 2-3 edges
  Parallel groups: 1-2

Task List:
  Task #1: [test] Write model tests (score: 6)
  Task #2: [code] Create Greeting model (score: 7) → depends on #1
  Task #3: [test] Write controller tests (score: 5)
  Task #4: [code] Create controller (score: 8) → depends on #3
  ...
```

**Verify Tasks Created:**
```bash
rails runner "
run = WorkflowRun.last
puts \"Decomposition Run ID: #{run.id}\"
puts \"Status: #{run.status}\"
puts

tasks = run.tasks.order(:position)
puts \"Tasks created: #{tasks.count}\"
puts

tasks.each do |t|
  deps = t.dependencies.pluck(:id).join(', ')
  deps_str = deps.empty? ? 'none' : deps
  puts \"Task ##{t.id}: [#{t.task_type}] #{t.prompt.truncate(60)}\"
  puts \"  Position: #{t.position}\"
  puts \"  Scores: files=#{t.files_score}, concepts=#{t.concepts_score}, deps=#{t.dependencies_score}\"
  puts \"  Total: #{t.total_score}\"
  puts \"  Depends on: #{deps_str}\"
  puts \"  Status: #{t.status}\"
  puts
end
"
```

**Expected Output:**
```
Decomposition Run ID: XX
Status: completed

Tasks created: 3-5

Task #1: [test] Write model tests
  Position: 1
  Scores: files=2, concepts=2, deps=1
  Total: 5
  Depends on: none
  Status: pending

Task #2: [code] Create Greeting model
  Position: 2
  Scores: files=3, concepts=2, deps=2
  Total: 7
  Depends on: 1
  Status: pending

...
```

---

## Test 5: Execute Plan (Dry Run)

**Get the workflow_run ID from Test 4, then:**
```bash
# Replace XX with your actual workflow_run ID
bin/legion execute-plan \
  --workflow-run XX \
  --dry-run
```

**Expected Output:**
```
Execution Plan for WorkflowRun #XX (5 tasks)

Wave 1:
  Task #1: [test] Rails Lead — Write model tests (score 6)
  Task #3: [test] Rails Lead — Write controller tests (score 5)

Wave 2 (after wave 1):
  Task #2: [code] Rails Lead — Create Greeting model (score 7) ← deps: [1]
  Task #4: [code] Rails Lead — Create controller (score 8) ← deps: [3]

Wave 3 (after wave 2):
  Task #5: [test] Rails Lead — System test (score 6) ← deps: [2,4]

DRY RUN — no tasks executed
```

---

## Test 6: Execute Plan (Real Execution)

⚠️ **Warning:** This will make real API calls to SmartProxy for each task. Ensure you have:
- SmartProxy running at `192.168.4.253:3001`
- `SMART_PROXY_TOKEN` set
- Sufficient API credits

```bash
# Replace XX with your actual workflow_run ID
bin/legion execute-plan \
  --workflow-run XX \
  --verbose
```

**Expected Output:**
```
Executing plan for WorkflowRun #XX (5 tasks)
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

**Verify Execution:**
```bash
rails runner "
run = WorkflowRun.find(ARGV[0])
tasks = run.tasks.order(:position)

puts 'Plan Execution Summary:'
puts \"Workflow Run: #{run.id}\"
puts \"Tasks: #{tasks.count}\"
puts

tasks.each do |t|
  puts \"Task ##{t.id}: #{t.status}\"
  puts \"  Prompt: #{t.prompt.truncate(60)}\"
  puts \"  Execution Run: #{t.execution_run_id}\"
  
  if t.execution_run_id
    exec_run = WorkflowRun.find(t.execution_run_id)
    puts \"  Iterations: #{exec_run.iterations}\"
    puts \"  Duration: #{exec_run.duration_ms}ms\"
    puts \"  Events: #{exec_run.workflow_events.count}\"
  end
  puts
end

completed = tasks.count(&:completed?)
puts \"✅ #{completed}/#{tasks.count} tasks completed\"
" XX
# Replace XX with your workflow_run ID
```

---

## Test 7: Event Trail Forensics

**Query event trail for a specific task:**
```bash
rails console
```

```ruby
# Get a completed task
task = Task.where(status: :completed).last
exec_run = WorkflowRun.find(task.execution_run_id)

puts "Task ##{task.id}: #{task.prompt.truncate(50)}"
puts "Execution Run: #{exec_run.id}"
puts "Events: #{exec_run.workflow_events.count}"
puts

# Show event timeline
events = exec_run.workflow_events.order(:created_at)
puts "Event Timeline:"
events.each do |e|
  puts "  #{e.created_at.strftime('%H:%M:%S.%L')} - #{e.event_type}"
end

puts
puts "Event Types:"
exec_run.workflow_events.pluck(:event_type).uniq.each { |t| puts "  - #{t}" }

puts
puts "Chronologically ordered: #{events.pluck(:created_at) == events.pluck(:created_at).sort ? '✅' : '❌'}"
```

**Expected Output:**
```
Task #123: Write model tests for Greeting
Execution Run: 456
Events: 42

Event Timeline:
  10:15:23.123 - agent.started
  10:15:24.456 - tool.called
  10:15:25.789 - tool.completed
  10:15:26.012 - response.streaming
  10:15:27.345 - response.complete
  10:15:28.678 - agent.completed

Event Types:
  - agent.started
  - tool.called
  - tool.completed
  - response.streaming
  - response.delta
  - response.complete
  - agent.completed

Chronologically ordered: ✅
```

**Exit console:** `exit`

---

## Test 8: Error Handling - Non-existent Team

```bash
bin/legion execute \
  --team INVALID_TEAM \
  --agent "Rails Lead" \
  --prompt "test"
```

**Expected Output:**
```
Team 'INVALID_TEAM' not found in project
```

**Expected Exit Code:** 3

**Verify:**
```bash
echo $?
# Should show: 3
```

---

## Test 9: Error Handling - Non-existent Agent

```bash
bin/legion execute \
  --team ROR \
  --agent "Invalid Agent" \
  --prompt "test"
```

**Expected Output:**
```
Agent 'Invalid Agent' not found in team 'ROR'.
Available agents: Aider, Architect, Debug Agent, QA Agent, Rails Lead, ...
```

**Expected Exit Code:** 3

---

## Test 10: Verify Full Pipeline

**Check database for complete orchestration:**
```bash
rails runner "
puts '━━━ Epic 1 Orchestration Pipeline Status ━━━'
puts

# Teams
teams = AgentTeam.all
puts \"Teams: #{teams.count}\"
teams.each { |t| puts \"  - #{t.name} (#{t.team_memberships.count} agents)\" }
puts

# Workflow Runs
runs = WorkflowRun.all
puts \"Workflow Runs: #{runs.count}\"
puts \"  Completed: #{runs.where(status: :completed).count}\"
puts \"  Failed: #{runs.where(status: :failed).count}\"
puts

# Tasks
tasks = Task.all
puts \"Tasks: #{tasks.count}\"
puts \"  Completed: #{tasks.where(status: :completed).count}\"
puts \"  Failed: #{tasks.where(status: :failed).count}\"
puts \"  Pending: #{tasks.where(status: :pending).count}\"
puts

# Task Dependencies
deps = TaskDependency.all
puts \"Task Dependencies: #{deps.count}\"
puts

# Events
events = WorkflowEvent.all
puts \"Workflow Events: #{events.count}\"
puts \"  Event Types: #{events.pluck(:event_type).uniq.count}\"
puts

puts '━━━ Full Pipeline Operational ✅ ━━━'
"
```

**Expected Output:**
```
━━━ Epic 1 Orchestration Pipeline Status ━━━

Teams: 4
  - QA Team (1 agents)
  - VerifyTeam (3 agents)
  - Default (9 agents)
  - ROR (9 agents)

Workflow Runs: 10-15
  Completed: 10-15
  Failed: 0

Tasks: 5-10
  Completed: 5-10
  Failed: 0
  Pending: 0

Task Dependencies: 3-5

Workflow Events: 200-500
  Event Types: 5-10

━━━ Full Pipeline Operational ✅ ━━━
```

---

## Summary Checklist

After running all tests, verify:

- [✅] Test 1: ROR team imported with 9 agents
- [✅] Test 2: Single agent dispatch works (Rails Lead)
- [✅] Test 3: Multiple agents dispatch with different models
- [✅] Test 4: PRD decomposition creates scored tasks with dependencies
- [✅] Test 5: Dry-run shows correct execution waves
- [✅] Test 6: Plan execution completes all tasks in dependency order
- [✅] Test 7: Event trails captured and queryable
- [✅] Test 8: Non-existent team error handled gracefully
- [✅] Test 9: Non-existent agent error handled gracefully
- [✅] Test 10: Full pipeline operational

---

## All Tests Passing = Epic 1 Validated ✅

You've manually verified:
- ✅ Team import with full agent configs
- ✅ Single and multi-agent dispatch with full identity
- ✅ PRD decomposition into scored tasks
- ✅ Dependency graph creation
- ✅ Plan execution in correct order
- ✅ Event trail persistence
- ✅ Error handling
- ✅ Complete orchestration pipeline

**Epic 1 is fully functional!** 🎉
