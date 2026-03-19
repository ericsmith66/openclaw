# Epic 1 Implementation Plan — Part 2 (PRDs 1-05 through 1-08)

## PRD-1-05: Orchestrator Hooks (0.5 week)

### What Gets Built

**Service:** `app/services/legion/orchestrator_hooks_service.rb`
**Config:** `app/services/legion/orchestrator_hooks.rb` (constants)

Registers 4 hooks on HookManager:
1. Iteration Budget Monitor (on_tool_called)
2. Context Window Pressure (on_token_budget_warning)
3. Handoff Capture (on_handoff_created)
4. Cost Budget Enforcement (on_cost_budget_exceeded)

### Implementation Steps

#### Step 1: Configuration Constants

**`app/services/legion/orchestrator_hooks.rb`**
```ruby
module Legion
  module OrchestratorHooks
    ITERATION_THRESHOLDS = {
      "deepseek-reasoner" => 30,
      "deepseek-chat" => 30,
      "claude-sonnet-4-20250514" => 50,
      "claude-opus-4-20250514" => 50,
      "grok-4-1-fast-non-reasoning" => 100,
      "qwen3-coder-next" => 55
    }.freeze

    DEFAULT_THRESHOLD = 50

    CONTEXT_WARNING_THRESHOLD = 0.6
    CONTEXT_INTERVENTION_THRESHOLD = 0.8
  end
end
```

#### Step 2: Hooks Service

**`app/services/legion/orchestrator_hooks_service.rb`**
```ruby
module Legion
  class OrchestratorHooksService
    def self.call(hook_manager:, workflow_run:, team_membership:)
      new(hook_manager:, workflow_run:, team_membership:).call
    end

    def initialize(hook_manager:, workflow_run:, team_membership:)
      @hook_manager = hook_manager
      @workflow_run = workflow_run
      @team_membership = team_membership
      @iteration_count = 0
    end

    def call
      register_iteration_budget_hook
      register_context_pressure_hook
      register_handoff_hook
      register_cost_budget_hook
    end

    private

    def register_iteration_budget_hook
      model = @team_membership.config["model"]
      threshold = OrchestratorHooks::ITERATION_THRESHOLDS[model] || OrchestratorHooks::DEFAULT_THRESHOLD

      @hook_manager.on_tool_called do |event|
        @iteration_count += 1

        if @iteration_count >= threshold && @iteration_count < threshold * 2
          # Warning
          log_iteration_warning(threshold)
          AgentDesk::Hooks::HookResult.new(blocked: false)
        elsif @iteration_count >= threshold * 2
          # Block
          @workflow_run.update(status: :iteration_limit)
          Rails.logger.warn("Iteration limit reached for WorkflowRun ##{@workflow_run.id}: #{@iteration_count} >= #{threshold * 2}")
          AgentDesk::Hooks::HookResult.new(blocked: true, result: { reason: "Iteration limit exceeded" })
        else
          AgentDesk::Hooks::HookResult.new(blocked: false)
        end
      rescue StandardError => e
        Rails.logger.error("Iteration budget hook failed: #{e.message}")
        AgentDesk::Hooks::HookResult.new(blocked: false)
      end
    end

    def log_iteration_warning(threshold)
      warnings = @workflow_run.metadata["iteration_warnings"] || []
      warnings << { iteration: @iteration_count, threshold: threshold, timestamp: Time.current }
      @workflow_run.update(metadata: @workflow_run.metadata.merge("iteration_warnings" => warnings))
    end

    def register_context_pressure_hook
      @hook_manager.on_token_budget_warning do |event|
        percentage = event.payload[:percentage] || 0

        if percentage >= OrchestratorHooks::CONTEXT_INTERVENTION_THRESHOLD
          @workflow_run.update(status: :decomposing)
          Rails.logger.warn("Context intervention (#{percentage * 100}%) for WorkflowRun ##{@workflow_run.id}")
          AgentDesk::Hooks::HookResult.new(blocked: true, result: { reason: "Context window pressure" })
        elsif percentage >= OrchestratorHooks::CONTEXT_WARNING_THRESHOLD
          @workflow_run.update(status: :at_risk)
          Rails.logger.info("Context warning (#{percentage * 100}%) for WorkflowRun ##{@workflow_run.id}")
          AgentDesk::Hooks::HookResult.new(blocked: false)
        else
          AgentDesk::Hooks::HookResult.new(blocked: false)
        end
      rescue StandardError => e
        Rails.logger.error("Context pressure hook failed: #{e.message}")
        AgentDesk::Hooks::HookResult.new(blocked: false)
      end
    end

    def register_handoff_hook
      @hook_manager.on_handoff_created do |event|
        continuation_prompt = event.payload[:continuation_prompt]
        
        new_run = WorkflowRun.create!(
          project: @workflow_run.project,
          team_membership: @workflow_run.team_membership,
          prompt: continuation_prompt,
          status: :queued,
          metadata: { "handed_off_from" => @workflow_run.id }
        )

        @workflow_run.update(
          status: :handed_off,
          metadata: @workflow_run.metadata.merge("handed_off_to" => new_run.id)
        )

        Rails.logger.info("Handoff created: WorkflowRun ##{@workflow_run.id} → ##{new_run.id}")
        AgentDesk::Hooks::HookResult.new(blocked: false)
      rescue StandardError => e
        Rails.logger.error("Handoff hook failed: #{e.message}")
        @workflow_run.update(status: :handed_off) rescue nil
        AgentDesk::Hooks::HookResult.new(blocked: false)
      end
    end

    def register_cost_budget_hook
      @hook_manager.on_cost_budget_exceeded do |event|
        cost_data = {
          total_cost: event.payload[:total_cost],
          budget: event.payload[:budget],
          timestamp: Time.current
        }

        @workflow_run.update(
          status: :budget_exceeded,
          metadata: @workflow_run.metadata.merge("cost_exceeded" => cost_data)
        )

        Rails.logger.warn("Cost budget exceeded for WorkflowRun ##{@workflow_run.id}")
        AgentDesk::Hooks::HookResult.new(blocked: true, result: { reason: "Cost budget exceeded" })
      rescue StandardError => e
        Rails.logger.error("Cost budget hook failed: #{e.message}")
        AgentDesk::Hooks::HookResult.new(blocked: true, result: { reason: "Cost budget exceeded" })
      end
    end
  end
end
```

#### Step 3: Integrate with AgentAssemblyService

Update `app/services/legion/agent_assembly_service.rb`:

```ruby
def build_hook_manager
  hook_manager = AgentDesk::Hooks::HookManager.new
  OrchestratorHooksService.call(
    hook_manager: hook_manager,
    workflow_run: @workflow_run,
    team_membership: @team_membership
  )
  hook_manager
end
```

#### Step 4: Tests

**`test/services/legion/orchestrator_hooks_service_test.rb`**

Test cases:
- Iteration hook warns at threshold, blocks at 2× threshold
- Different thresholds for different models (DeepSeek=30, Grok=100)
- Unknown model uses DEFAULT_THRESHOLD
- Context hook: 60% → `at_risk`, 80% → `decomposing` + blocked
- Handoff hook creates new WorkflowRun with continuation, links via metadata
- Cost hook blocks execution, sets `budget_exceeded`
- Hook errors caught and logged, don't crash runner

### Acceptance Criteria

- [ ] Iteration budget hook counts tool calls, warns at model-specific threshold
- [ ] Iteration budget hook blocks at 2× threshold
- [ ] Context pressure hook marks `at_risk` at 60%, `decomposing` at 80%
- [ ] Handoff hook creates new WorkflowRun, links original and continuation
- [ ] Cost budget hook blocks, sets `budget_exceeded`
- [ ] Unknown models fall back to DEFAULT_THRESHOLD
- [ ] Hook errors logged, don't crash runner
- [ ] AgentAssemblyService integrates hook registration
- [ ] `rails test test/services/legion/orchestrator*` — zero failures

---

## PRD-1-06: Task Decomposition (1.5 weeks)

### What Gets Built

**CLI:** `bin/legion decompose` subcommand
**Services:**
- `app/services/legion/decomposition_service.rb` — dispatches Architect, parses output, creates Tasks
- `app/services/legion/decomposition_parser.rb` — validates JSON output, detects cycles
**Prompt Template:** `app/services/legion/prompts/decomposition_prompt.md.erb`

### Implementation Steps

#### Step 1: Decomposition Prompt Template

**`app/services/legion/prompts/decomposition_prompt.md.erb`**
```markdown
## Task: Decompose this PRD into atomic coding tasks

### PRD Content
<prd>
<%= prd_content %>
</prd>

### Instructions

Break this PRD into atomic coding tasks following these rules:

1. **Test-first ordering:** For each feature, produce the test task BEFORE the implementation task. The implementation task depends on its test task. The coding agent will:
   - Run the tests (red — they should fail)
   - Write code to make them pass (green)
   - Iterate via test feedback until green

2. **Atomic task scale:** Score each task on three dimensions (1-4):
   - **Files Touched:** 1=1-2 files, 2=3-4, 3=5-7, 4=8+
   - **Concept Count:** 1=1 concept, 2=2, 3=3-4, 4=5+
   - **Cross-Model Dependencies:** 1=0 deps, 2=1, 3=2-3, 4=4+
   - Total > 6 means the task should be decomposed further.

3. **Dependencies:** List which task numbers each task depends on. Tasks with no dependencies are independent and parallel-eligible.

4. **Agent assignment:** Recommend which agent should execute each task (rails-lead, qa, architect, debug).

5. **Parallel awareness:** Two tasks that edit different files with no shared model dependencies CAN run in parallel.

### Required Output Format

Respond with ONLY a JSON array, no other text:

```json
[
  {
    "position": 1,
    "type": "test",
    "prompt": "Write tests and factory for Project model: name (required), path (required, unique), project_rules (jsonb). Test validations, associations, factory validity.",
    "agent": "rails-lead",
    "files_score": 2,
    "concepts_score": 1,
    "dependencies_score": 1,
    "depends_on": [],
    "notes": "Independent test task — parallel eligible"
  },
  {
    "position": 2,
    "type": "code",
    "prompt": "Create Project model and migration to make tests from Task 1 pass. Fields: name (string, required), path (string, required, unique), project_rules (jsonb, default {}).",
    "agent": "rails-lead",
    "files_score": 2,
    "concepts_score": 1,
    "dependencies_score": 1,
    "depends_on": [1],
    "notes": "Implementation — depends on test task 1"
  }
]
```
```

#### Step 2: Decomposition Parser

**`app/services/legion/decomposition_parser.rb`**
```ruby
module Legion
  class DecompositionParser
    def self.call(response_text:)
      new(response_text:).call
    end

    def initialize(response_text:)
      @response_text = response_text
      @warnings = []
      @errors = []
    end

    def call
      json_array = extract_json
      return error_result("No JSON array found in response") unless json_array

      tasks = parse_tasks(json_array)
      validate_dependencies(tasks)
      detect_cycles(tasks)
      identify_warnings(tasks)

      { tasks: tasks, warnings: @warnings, errors: @errors, success: @errors.empty? }
    end

    private

    def extract_json
      # Try to extract JSON from markdown code fences
      if @response_text =~ /```(?:json)?\s*(\[.*?\])\s*```/m
        JSON.parse($1)
      elsif @response_text =~ /(\[.*\])/m
        JSON.parse($1)
      else
        nil
      end
    rescue JSON::ParserError => e
      @errors << "Failed to parse JSON: #{e.message}"
      nil
    end

    def parse_tasks(json_array)
      json_array.map.with_index do |task_data, idx|
        validate_task_fields(task_data, idx)
        normalize_task(task_data)
      end.compact
    end

    def validate_task_fields(task_data, idx)
      required = %w[position type prompt agent files_score concepts_score dependencies_score depends_on]
      missing = required - task_data.keys
      
      if missing.any?
        @errors << "Task #{idx + 1}: missing required fields: #{missing.join(', ')}"
        return false
      end

      unless %w[test code review debug].include?(task_data["type"])
        @errors << "Task #{idx + 1}: invalid type '#{task_data['type']}'"
      end

      %w[files_score concepts_score dependencies_score].each do |field|
        score = task_data[field]
        unless score.is_a?(Integer) && (1..4).cover?(score)
          @errors << "Task #{idx + 1}: #{field} must be 1-4, got #{score}"
        end
      end

      true
    end

    def normalize_task(task_data)
      {
        position: task_data["position"],
        type: task_data["type"],
        prompt: task_data["prompt"],
        agent: task_data["agent"],
        files_score: task_data["files_score"],
        concepts_score: task_data["concepts_score"],
        dependencies_score: task_data["dependencies_score"],
        total_score: task_data["files_score"] + task_data["concepts_score"] + task_data["dependencies_score"],
        depends_on: task_data["depends_on"] || [],
        notes: task_data["notes"]
      }
    end

    def validate_dependencies(tasks)
      valid_positions = tasks.map { |t| t[:position] }.to_set

      tasks.each do |task|
        task[:depends_on].each do |dep_position|
          unless valid_positions.include?(dep_position)
            @errors << "Task #{task[:position]}: depends on non-existent task #{dep_position}"
          end
        end
      end
    end

    def detect_cycles(tasks)
      adjacency = build_adjacency_list(tasks)

      tasks.each do |task|
        if has_cycle?(task[:position], adjacency, Set.new, Set.new)
          @errors << "Dependency cycle detected involving task #{task[:position]}"
        end
      end
    end

    def build_adjacency_list(tasks)
      adjacency = {}
      tasks.each do |task|
        adjacency[task[:position]] = task[:depends_on]
      end
      adjacency
    end

    def has_cycle?(node, adjacency, visited, rec_stack)
      return true if rec_stack.include?(node)
      return false if visited.include?(node)

      visited << node
      rec_stack << node

      adjacency[node]&.each do |neighbor|
        return true if has_cycle?(neighbor, adjacency, visited, rec_stack)
      end

      rec_stack.delete(node)
      false
    end

    def identify_warnings(tasks)
      tasks.each do |task|
        if task[:total_score] > 6
          @warnings << "Task #{task[:position]}: score #{task[:total_score]} > threshold 6 — consider further decomposition"
        end
      end
    end

    def error_result(message)
      @errors << message
      { tasks: [], warnings: [], errors: @errors, success: false }
    end
  end
end
```

#### Step 3: Decomposition Service

**`app/services/legion/decomposition_service.rb`**
```ruby
module Legion
  class DecompositionService
    def self.call(team_name:, prd_path:, agent_identifier: "architect", project_path: Dir.pwd, dry_run: false)
      new(team_name:, prd_path:, agent_identifier:, project_path:, dry_run:).call
    end

    def initialize(team_name:, prd_path:, agent_identifier:, project_path:, dry_run:)
      @team_name = team_name
      @prd_path = File.expand_path(prd_path)
      @agent_identifier = agent_identifier
      @project_path = File.expand_path(project_path)
      @dry_run = dry_run
    end

    def call
      prd_content = read_prd
      decomposition_prompt = build_prompt(prd_content)
      
      # Dispatch architect agent
      dispatch_result = DispatchService.call(
        team_name: @team_name,
        agent_identifier: @agent_identifier,
        prompt: decomposition_prompt,
        project_path: @project_path,
        interactive: false,
        verbose: false
      )

      workflow_run = dispatch_result[:workflow_run]
      
      # Parse architect's response
      parse_result = DecompositionParser.call(response_text: workflow_run.result)
      
      return dry_run_report(parse_result) if @dry_run
      
      if parse_result[:success]
        create_tasks(workflow_run, parse_result[:tasks])
        print_decomposition_report(workflow_run, parse_result)
        { success: true, workflow_run: workflow_run, parse_result: parse_result }
      else
        print_error_report(workflow_run, parse_result)
        { success: false, workflow_run: workflow_run, parse_result: parse_result }
      end
    end

    private

    def read_prd
      raise "File not found: #{@prd_path}" unless File.exist?(@prd_path)
      content = File.read(@prd_path)
      raise "PRD file is empty" if content.strip.empty?
      content
    end

    def build_prompt(prd_content)
      template = File.read(Rails.root.join("app/services/legion/prompts/decomposition_prompt.md.erb"))
      ERB.new(template).result(binding)
    end

    def dry_run_report(parse_result)
      puts "DRY RUN — no tasks will be saved"
      print_task_list(parse_result[:tasks], parse_result[:warnings])
      parse_result
    end

    def create_tasks(workflow_run, task_list)
      project = workflow_run.project

      ApplicationRecord.transaction do
        task_list.each do |task_data|
          agent_name = task_data[:agent]
          membership = find_agent_membership(workflow_run.team_membership.agent_team, agent_name)

          task = Task.create!(
            project: project,
            workflow_run: workflow_run,
            team_membership: membership,
            position: task_data[:position],
            prompt: task_data[:prompt],
            task_type: task_data[:type],
            status: :pending,
            files_score: task_data[:files_score],
            concepts_score: task_data[:concepts_score],
            dependencies_score: task_data[:dependencies_score],
            metadata: { notes: task_data[:notes] }
          )

          task_data[:depends_on].each do |dep_position|
            dep_task = Task.find_by(workflow_run: workflow_run, position: dep_position)
            TaskDependency.create!(task: task, depends_on_task: dep_task) if dep_task
          end
        end
      end
    end

    def find_agent_membership(team, agent_name)
      membership = team.team_memberships.find do |tm|
        tm.config["name"]&.downcase&.include?(agent_name.downcase) ||
        tm.config["id"]&.downcase&.include?(agent_name.downcase)
      end
      
      membership || team.team_memberships.first # fallback to first member
    end

    def print_decomposition_report(workflow_run, parse_result)
      puts "Decomposing: #{File.basename(@prd_path)}"
      puts "Agent: #{workflow_run.team_membership.config['name']} (#{workflow_run.team_membership.config['model']})"
      puts "━" * 80
      puts ""
      print_task_list(parse_result[:tasks], parse_result[:warnings])
      puts ""
      puts "Saved #{parse_result[:tasks].size} tasks with #{TaskDependency.where(task: Task.where(workflow_run: workflow_run)).count} dependency edges to WorkflowRun ##{workflow_run.id}"
    end

    def print_task_list(tasks, warnings)
      puts "#   Type  Agent        Score    Deps    Status    Prompt"
      tasks.each do |task|
        deps = task[:depends_on].empty? ? "—" : "[#{task[:depends_on].join(',')}]"
        flag = task[:total_score] > 6 ? "⚠️ >6" : "pending"
        puts "#{task[:position].to_s.ljust(3)} #{task[:type].ljust(5)} #{task[:agent].ljust(12)} #{task[:files_score]}+#{task[:concepts_score]}+#{task[:dependencies_score]}=#{task[:total_score].to_s.ljust(2)}  #{deps.ljust(7)} #{flag.ljust(9)} #{task[:prompt][0..60]}"
      end

      if warnings.any?
        puts ""
        puts "⚠️  Warnings:"
        warnings.each { |w| puts "  • #{w}" }
      end
    end

    def print_error_report(workflow_run, parse_result)
      puts "❌ Decomposition failed"
      puts "Errors:"
      parse_result[:errors].each { |e| puts "  - #{e}" }
      puts ""
      puts "Raw response saved to WorkflowRun ##{workflow_run.id}"
    end
  end
end
```

#### Step 4: Add CLI Subcommand

Update `bin/legion`:

```ruby
desc "decompose", "Decompose a PRD into atomic tasks"
option :team, required: true, desc: "Team name"
option :prd, required: true, desc: "Path to PRD file"
option :agent, default: "architect", desc: "Agent to use for decomposition"
option :project, desc: "Project path override"
option :dry_run, type: :boolean, default: false, desc: "Show preview without saving"
option :verbose, type: :boolean, default: false, desc: "Print agent's full response"
def decompose
  result = Legion::DecompositionService.call(
    team_name: options[:team],
    prd_path: options[:prd],
    agent_identifier: options[:agent],
    project_path: options[:project] || Dir.pwd,
    dry_run: options[:dry_run]
  )
  
  exit result[:success] ? 0 : 1
rescue Errno::ENOENT => e
  puts "Error: File not found: #{options[:prd]}"
  exit 2
end
```

#### Step 5: Tests

**Unit:** `test/services/legion/decomposition_parser_test.rb` — test JSON parsing, validation, cycle detection
**Unit:** `test/services/legion/decomposition_service_test.rb` — test PRD reading, prompt building, task creation
**Integration:** `test/integration/decomposition_integration_test.rb` — full decomposition with VCR

### Acceptance Criteria

- [ ] `bin/legion decompose --team ROR --prd <path>` dispatches Architect
- [ ] Tasks created in DB with correct fields
- [ ] TaskDependency edges match Architect output
- [ ] Test tasks appear before implementation tasks
- [ ] Implementation tasks depend on test tasks
- [ ] Parser handles JSON wrapped in code fences
- [ ] Parser validates scores (1-4) and dependencies
- [ ] Tasks with score > 6 flagged with warning
- [ ] Parallel groups detected and displayed
- [ ] `--dry-run` shows preview without saving
- [ ] Decomposition creates its own WorkflowRun
- [ ] Invalid output → error message with raw response preserved
- [ ] Cycle detection prevents circular dependencies
- [ ] `rails test test/services/legion/decomposition*` — zero failures

---

## PRD-1-07: Plan Execution CLI (1 week)

### What Gets Built

**CLI:** `bin/legion execute-plan` subcommand
**Service:** `app/services/legion/plan_execution_service.rb`

Walks task dependency graph, dispatches ready tasks sequentially.

### Implementation Steps

#### Step 1: Plan Execution Service

**`app/services/legion/plan_execution_service.rb`**
```ruby
module Legion
  class PlanExecutionService
    def self.call(workflow_run:, start_from: nil, continue_on_failure: false, interactive: false, verbose: false, max_iterations: nil)
      new(workflow_run:, start_from:, continue_on_failure:, interactive:, verbose:, max_iterations:).call
    end

    def initialize(workflow_run:, start_from:, continue_on_failure:, interactive:, verbose:, max_iterations:)
      @workflow_run = workflow_run
      @start_from = start_from
      @continue_on_failure = continue_on_failure
      @interactive = interactive
      @verbose = verbose
      @max_iterations = max_iterations
      @start_time = Time.now
    end

    def call
      tasks = load_tasks
      return { success: false, message: "No tasks found" } if tasks.empty?

      skip_tasks_before_start_from(tasks) if @start_from
      
      puts "Executing plan for WorkflowRun ##{@workflow_run.id} (#{tasks.size} tasks)"
      puts "━" * 80
      puts ""

      loop do
        ready_tasks = find_ready_tasks(tasks)
        
        if ready_tasks.empty?
          incomplete = tasks.reject { |t| t.completed? || t.skipped? || t.failed? }
          if incomplete.any?
            report_deadlock(incomplete)
            return { success: false, message: "Deadlock detected" }
          else
            break # All tasks done
          end
        end

        task = ready_tasks.first
        dispatch_task(task)
        
        if task.failed? && !@continue_on_failure
          report_halt(tasks)
          return { success: false, message: "Task failed, halting" }
        elsif task.failed? && @continue_on_failure
          mark_dependents_skipped(task, tasks)
        end
      end

      report_completion(tasks)
      { success: all_completed?(tasks), tasks: tasks }
    end

    private

    def load_tasks
      Task.where(workflow_run: @workflow_run).by_position.to_a
    end

    def skip_tasks_before_start_from(tasks)
      start_task = tasks.find { |t| t.id == @start_from }
      return unless start_task

      tasks.each do |task|
        if task.position < start_task.position
          task.update(status: :skipped)
        end
      end
    end

    def find_ready_tasks(tasks)
      tasks.select do |task|
        task.pending? && task.dependencies.all?(&:completed?)
      end
    end

    def dispatch_task(task)
      puts "[#{task.position}/#{Task.where(workflow_run: @workflow_run).count}] Task ##{task.id}: #{task.prompt[0..60]} — #{task.team_membership.config['name']} (#{task.team_membership.config['model']})"
      
      deps = task.dependencies
      if deps.any?
        puts "       Depends on: #{deps.map { |d| "Task #{d.position} #{d.completed? ? '✅' : '⏳'}" }.join(', ')}"
      end

      task.update(status: :running)

      result = DispatchService.call(
        team_name: task.team_membership.agent_team.name,
        agent_identifier: task.team_membership.config["id"],
        prompt: task.prompt,
        project_path: task.project.path,
        max_iterations: @max_iterations,
        interactive: @interactive,
        verbose: @verbose
      )

      execution_run = result[:workflow_run]
      
      if execution_run.completed?
        task.update(status: :completed, execution_run: execution_run)
        puts "       ✅ Completed — #{execution_run.iterations} iterations, #{execution_run.duration_ms}ms, #{execution_run.workflow_events.count} events"
      else
        task.update(status: :failed, execution_run: execution_run)
        puts "       ❌ Failed — #{execution_run.error_message || execution_run.status}"
      end
      puts ""
    end

    def mark_dependents_skipped(failed_task, tasks)
      dependents = tasks.select do |t|
        t.dependencies.include?(failed_task)
      end

      dependents.each do |dep|
        dep.update(status: :skipped)
        mark_dependents_skipped(dep, tasks) # recursive
      end
    end

    def report_deadlock(incomplete_tasks)
      puts "❌ Deadlock detected: #{incomplete_tasks.size} tasks have unsatisfied dependencies"
      incomplete_tasks.each do |task|
        unfinished_deps = task.dependencies.reject(&:completed?)
        puts "  Task #{task.position}: waiting for #{unfinished_deps.map(&:position).join(', ')}"
      end
    end

    def report_halt(tasks)
      completed = tasks.count(&:completed?)
      failed = tasks.count(&:failed?)
      pending = tasks.count(&:pending?)
      
      puts "Plan halted: #{completed}/#{tasks.size} completed, #{failed} failed, #{pending} pending"
      puts "Use --continue-on-failure to skip failed tasks and continue"
    end

    def report_completion(tasks)
      completed = tasks.count(&:completed?)
      failed = tasks.count(&:failed?)
      skipped = tasks.count(&:skipped?)
      total_duration = ((Time.now - @start_time) * 1000).to_i
      total_iterations = tasks.sum { |t| t.execution_run&.iterations || 0 }
      total_events = tasks.sum { |t| t.execution_run&.workflow_events&.count || 0 }

      if failed.zero? && skipped.zero?
        puts "Plan complete: #{completed}/#{tasks.size} tasks succeeded"
      else
        puts "Plan complete: #{completed} completed, #{failed} failed, #{skipped} skipped"
      end
      
      puts "Total time: #{total_duration}ms | Total iterations: #{total_iterations} | Total events: #{total_events}"
    end

    def all_completed?(tasks)
      tasks.all? { |t| t.completed? || t.skipped? }
    end
  end
end
```

#### Step 2: Add CLI Subcommand

Update `bin/legion`:

```ruby
desc "execute-plan", "Execute a decomposed task plan"
option :workflow_run, required: true, type: :numeric, desc: "WorkflowRun ID from decomposition"
option :start_from, type: :numeric, desc: "Task ID to resume from"
option :continue_on_failure, type: :boolean, default: false, desc: "Continue if task fails"
option :interactive, type: :boolean, default: false, desc: "Enable interactive tool approval"
option :verbose, type: :boolean, default: false, desc: "Print real-time event stream per task"
option :max_iterations, type: :numeric, desc: "Override max iterations per task"
option :dry_run, type: :boolean, default: false, desc: "Show execution plan without running"
def execute_plan
  workflow_run = WorkflowRun.find(options[:workflow_run])
  
  if options[:dry_run]
    print_dry_run(workflow_run)
    exit 0
  end

  result = Legion::PlanExecutionService.call(
    workflow_run: workflow_run,
    start_from: options[:start_from],
    continue_on_failure: options[:continue_on_failure],
    interactive: options[:interactive],
    verbose: options[:verbose],
    max_iterations: options[:max_iterations]
  )
  
  exit result[:success] ? 0 : 1
rescue ActiveRecord::RecordNotFound
  puts "Error: WorkflowRun ##{options[:workflow_run]} not found"
  exit 2
end

private

def print_dry_run(workflow_run)
  tasks = Task.where(workflow_run: workflow_run).by_position
  
  puts "Execution Plan for WorkflowRun ##{workflow_run.id} (#{tasks.count} tasks)"
  puts "━" * 80
  puts ""
  puts "DRY RUN — no tasks will be executed"
end
```

#### Step 3: Tests

**Unit:** `test/services/legion/plan_execution_service_test.rb` — test linear chains, parallel groups, failure handling
**Integration:** `test/integration/plan_execution_integration_test.rb` — full cycle with VCR

### Acceptance Criteria

- [ ] `bin/legion execute-plan --workflow-run N` dispatches tasks in dependency order
- [ ] Tasks with no dependencies dispatched first
- [ ] Tasks only dispatched when ALL dependencies completed
- [ ] Each task creates its own WorkflowRun with full event trail
- [ ] Task status updates: pending → running → completed/failed
- [ ] Task.execution_run_id links to WorkflowRun
- [ ] Default: halt on first failure with clear message
- [ ] `--continue-on-failure`: mark dependents skipped, continue
- [ ] `--start-from N`: skip tasks before N, resume
- [ ] `--dry-run`: show execution plan without dispatching
- [ ] Deadlock detection when no ready tasks but incomplete remain
- [ ] Final summary shows counts, time, iterations
- [ ] `rails test test/services/legion/plan_execution*` — zero failures

---

## PRD-1-08: Validation & E2E Testing (1 week)

### What Gets Built

**E2E Test Suite:** `test/e2e/epic_1_validation_test.rb`
**Validation Script:** `bin/legion validate`
**Test Fixtures:** `test/fixtures/test-prd-simple.md`
**VCR Cassettes:** `test/vcr_cassettes/e2e/`

### Implementation Steps

#### Step 1: Test PRD Fixture

**`test/fixtures/test-prd-simple.md`**
```markdown
# Test PRD: Greeting Model

## Overview
Add a simple Greeting model with a message field for E2E testing.

## Requirements
- Model: Greeting
- Fields: message (string, required)
- Validations: presence of message
- Factory: greeting factory
- Tests: model tests for validation

## Acceptance Criteria
- [ ] Greeting model exists with message field
- [ ] Message validation works
- [ ] Factory produces valid records
- [ ] All tests pass
```

#### Step 2: E2E Test Suite

**`test/e2e/epic_1_validation_test.rb`**
```ruby
require "test_helper"

class Epic1ValidationTest < ActiveSupport::TestCase
  setup do
    # Import team before each test
    @import_result = Legion::TeamImportService.call(
      aider_desk_path: Rails.root.join(".aider-desk").to_s,
      project_path: Rails.root.to_s,
      team_name: "ROR",
      dry_run: false
    )
    @team = @import_result[:team]
  end

  test "Scenario 1: Team import round-trip" do
    assert_equal 4, @team.team_memberships.count
    
    @team.team_memberships.each do |tm|
      profile = tm.to_profile
      assert profile.is_a?(AgentDesk::Agent::Profile)
      assert_not_nil profile.provider
      assert_not_nil profile.model
      assert profile.max_iterations > 0
    end
  end

  test "Scenario 2: Single agent dispatch with full identity", :vcr do
    result = Legion::DispatchService.call(
      team_name: "ROR",
      agent_identifier: "rails-lead",
      prompt: "Say hello",
      project_path: Rails.root.to_s,
      interactive: false,
      verbose: false
    )

    run = result[:workflow_run]
    assert run.completed?
    assert run.workflow_events.count > 0
    assert run.workflow_events.exists?(event_type: "agent.started")
    assert run.workflow_events.exists?(event_type: "agent.completed")
  end

  test "Scenario 3: Multi-agent dispatch", :vcr do
    agents = ["rails-lead", "architect", "qa", "debug"]
    runs = []

    agents.each do |agent_id|
      result = Legion::DispatchService.call(
        team_name: "ROR",
        agent_identifier: agent_id,
        prompt: "List your tools",
        project_path: Rails.root.to_s
      )
      runs << result[:workflow_run]
    end

    assert_equal 4, runs.count
    runs.each { |run| assert run.completed? }
    assert_equal 4, runs.map { |r| r.team_membership_id }.uniq.count
  end

  test "Scenario 4: Orchestrator hook behavior", :vcr do
    result = Legion::DispatchService.call(
      team_name: "ROR",
      agent_identifier: "rails-lead",
      prompt: "Complex task",
      project_path: Rails.root.to_s,
      max_iterations: 3
    )

    run = result[:workflow_run]
    assert_includes [:completed, :iteration_limit, :at_risk], run.status
  end

  test "Scenario 5: Event trail forensics", :vcr do
    result = Legion::DispatchService.call(
      team_name: "ROR",
      agent_identifier: "rails-lead",
      prompt: "Create a test file",
      project_path: Rails.root.to_s
    )

    run = result[:workflow_run]
    events = run.workflow_events.chronological

    assert events.count > 0
    assert events.first.recorded_at <= events.last.recorded_at
    assert events.exists?(event_type: "tool.called")
  end

  test "Scenario 6: Decomposition task creation", :vcr do
    prd_path = Rails.root.join("test/fixtures/test-prd-simple.md").to_s
    
    result = Legion::DecompositionService.call(
      team_name: "ROR",
      prd_path: prd_path,
      agent_identifier: "architect",
      project_path: Rails.root.to_s,
      dry_run: false
    )

    assert result[:success]
    tasks = Task.where(workflow_run: result[:workflow_run])
    assert tasks.count >= 2
    
    test_tasks = tasks.where(task_type: :test)
    code_tasks = tasks.where(task_type: :code)
    assert test_tasks.any?
    assert code_tasks.any?
  end

  test "Scenario 7: Plan execution cycle", :vcr do
    # Use decomposition from Scenario 6
    prd_path = Rails.root.join("test/fixtures/test-prd-simple.md").to_s
    decomp_result = Legion::DecompositionService.call(
      team_name: "ROR",
      prd_path: prd_path,
      project_path: Rails.root.to_s
    )

    exec_result = Legion::PlanExecutionService.call(
      workflow_run: decomp_result[:workflow_run],
      continue_on_failure: false
    )

    assert exec_result[:success]
    tasks = Task.where(workflow_run: decomp_result[:workflow_run])
    assert tasks.all? { |t| t.completed? || t.skipped? }
    assert tasks.all? { |t| t.execution_run_id.present? || t.skipped? }
  end

  test "Scenario 8: Full cycle decompose execute", :vcr do
    # Full happy path
    prd_path = Rails.root.join("test/fixtures/test-prd-simple.md").to_s
    
    decomp_result = Legion::DecompositionService.call(
      team_name: "ROR",
      prd_path: prd_path,
      project_path: Rails.root.to_s
    )
    
    exec_result = Legion::PlanExecutionService.call(
      workflow_run: decomp_result[:workflow_run]
    )

    assert decomp_result[:success]
    assert exec_result[:success]
  end

  test "Scenario 9: Dependency graph correctness" do
    project = @team.project
    membership = @team.team_memberships.first
    run = WorkflowRun.create!(project: project, team_membership: membership, prompt: "test")

    # Create known DAG: 2 independent, 1 fan-in, 2 fan-out
    t1 = Task.create!(project: project, workflow_run: run, team_membership: membership, position: 1, prompt: "Task 1", task_type: :test, status: :completed)
    t2 = Task.create!(project: project, workflow_run: run, team_membership: membership, position: 2, prompt: "Task 2", task_type: :test, status: :completed)
    t3 = Task.create!(project: project, workflow_run: run, team_membership: membership, position: 3, prompt: "Task 3", task_type: :code, status: :pending)
    t4 = Task.create!(project: project, workflow_run: run, team_membership: membership, position: 4, prompt: "Task 4", task_type: :code, status: :pending)
    t5 = Task.create!(project: project, workflow_run: run, team_membership: membership, position: 5, prompt: "Task 5", task_type: :code, status: :pending)

    TaskDependency.create!(task: t3, depends_on_task: t1)
    TaskDependency.create!(task: t3, depends_on_task: t2)
    TaskDependency.create!(task: t4, depends_on_task: t3)
    TaskDependency.create!(task: t5, depends_on_task: t3)

    # t1, t2 completed → t3 should be ready
    assert t3.ready?
    assert_not t4.ready?
    assert_not t5.ready?

    t3.update(status: :completed)
    # t3 completed → t4, t5 should be ready (parallel-eligible)
    assert t4.ready?
    assert t5.ready?
  end

  test "Scenario 10: Error handling resilience" do
    # Team not found
    assert_raises(Legion::DispatchService::TeamNotFound) do
      Legion::DispatchService.call(
        team_name: "NONEXISTENT",
        agent_identifier: "foo",
        prompt: "test",
        project_path: Rails.root.to_s
      )
    end

    # Agent not found
    assert_raises(Legion::DispatchService::AgentNotFound) do
      Legion::DispatchService.call(
        team_name: "ROR",
        agent_identifier: "nonexistent",
        prompt: "test",
        project_path: Rails.root.to_s
      )
    end
  end
end
```

#### Step 3: Validation Script

**`bin/legion validate`**
```ruby
#!/usr/bin/env ruby
APP_PATH = File.expand_path("../config/application", __dir__)
require_relative "../config/boot"
require_relative "../config/environment"

puts "Running Epic 1 E2E Validation Suite..."
puts "━" * 80
puts ""

result = system("rails test test/e2e/epic_1_validation_test.rb")

puts ""
puts "━" * 80
if result
  puts "✅ All E2E scenarios passed!"
  exit 0
else
  puts "❌ Some E2E scenarios failed"
  exit 1
end
```

Make executable:
```bash
chmod +x bin/legion validate
```

### Acceptance Criteria

- [ ] All 10 scenarios pass
- [ ] Tests run offline via VCR cassettes in < 60 seconds
- [ ] `bin/legion validate` exits 0 when all pass
- [ ] Test PRD fixture exists and usable
- [ ] `rails test` — zero failures across entire suite (unit + integration + E2E)

---

## Final Notes

**Total Implementation Time:** 8.5 weeks (42.5 days)

**Critical Success Factors:**
1. **Schema first** — Everything depends on PRD-1-01 being perfect
2. **`to_profile` mapping** — Must correctly translate JSONB → Profile (all 20+ fields)
3. **Test-first decomposition** — Architect prompt must enforce test→code ordering
4. **DAG cycle detection** — Must be bulletproof (tested with direct + indirect cycles)
5. **VCR cassettes** — Record once with live SmartProxy, replay offline forever

**After Epic 1:**
- Import team: `rake teams:import[~/.aider-desk]`
- Execute agent: `bin/legion execute --team ROR --agent rails-lead --prompt "..."`
- Decompose PRD: `bin/legion decompose --team ROR --prd <path>`
- Execute plan: `bin/legion execute-plan --workflow-run <id>`
- Validate: `bin/legion validate`

**Next: Epic 2 (WorkflowEngine Core)** — Automatic chaining, parallel dispatch via Solid Queue, auto-decomposition on failure walls, quality gates.
