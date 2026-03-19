# Epic 1 — Orchestration Foundation — Implementation Plan

**Created:** 2026-03-06
**Owner:** Rails Lead (DeepSeek Reasoner) + QA (Claude Sonnet) for validation
**Epic:** Legion Orchestration Foundation
**Branch Strategy:** 
- `epic-1/prd-01-schema` (PRD-1-01: Schema Foundation)
- `epic-1/prd-02-postgres-bus` (PRD-1-02: PostgresBus Adapter)
- `epic-1/prd-03-team-import` (PRD-1-03: Team Import)
- `epic-1/prd-04-cli-dispatch` (PRD-1-04: CLI Dispatch)
- `epic-1/prd-05-hooks` (PRD-1-05: Orchestrator Hooks)
- `epic-1/prd-06-decompose` (PRD-1-06: Task Decomposition)
- `epic-1/prd-07-execute-plan` (PRD-1-07: Plan Execution CLI)
- `epic-1/prd-08-validation` (PRD-1-08: Validation & E2E)

---

## Overview

Epic 1 transforms Legion from a Rails app with an embedded gem into a complete agent orchestration platform. The implementation is **strictly sequential** — each PRD depends on all previous PRDs being complete and merged to `main`.

**What we're building:**
1. Database schema for agent identity, execution tracking, task decomposition, and dependency management
2. Event persistence layer (PostgresBus) bridging the gem to PostgreSQL
3. Team import pipeline from `.aider-desk` to database
4. CLI dispatch with full agent assembly (rules, skills, tools, system prompt, model, event bus, hooks)
5. Orchestrator safety rails (iteration budget, context pressure, handoff capture, cost limits)
6. Task decomposition (Architect agent reads PRD, produces scored dependency graph)
7. Plan execution (walks dependency graph, dispatches tasks sequentially)
8. End-to-end validation (10 scenarios proving the complete pipeline works)

**What doesn't exist yet in Legion:**
- No models (clean slate)
- No migrations
- No services
- No rake tasks (except defaults)
- No `bin/legion` CLI
- No factories
- No E2E tests

**What does exist:**
- Rails 8.1.2 app structure
- `agent_desk` gem (752 tests green, 2022 assertions)
- `.aider-desk/` with 4 agent configs (not yet imported to DB)
- SmartProxy running at `http://192.168.4.253:3001`
- Test infrastructure (Minitest, VCR configured)

---

## Execution Order & Dependencies

**Critical path (all sequential):**

```
PRD-1-01 (Schema Foundation)           1.5 weeks
    │ Creates: 7 models, migrations, factories
    │ Blocks: Everything — no DB = no persistence
    ▼
PRD-1-02 (PostgresBus Adapter)         1 week
    │ Creates: Legion::PostgresBus service
    │ Blocks: PRD-1-04 (CLI needs event persistence)
    ▼
PRD-1-03 (Team Import)                 0.5 week
    │ Creates: TeamImportService, rake task
    │ Blocks: PRD-1-04 (CLI needs agents in DB)
    ▼
PRD-1-04 (CLI Dispatch)                1.5 weeks
    │ Creates: bin/legion, AgentAssemblyService, DispatchService
    │ Blocks: Everything downstream — no dispatch = no execution
    ▼
PRD-1-05 (Orchestrator Hooks)          0.5 week
    │ Creates: OrchestratorHooksService
    │ Enhances: PRD-1-04 (adds safety rails)
    │ Blocks: PRD-1-07, PRD-1-08 (hooks needed for validation)
    ▼
PRD-1-06 (Task Decomposition)          1.5 weeks
    │ Creates: DecompositionService, DecompositionParser, bin/legion decompose
    │ Blocks: PRD-1-07 (execute-plan needs tasks to execute)
    ▼
PRD-1-07 (Plan Execution CLI)          1 week
    │ Creates: PlanExecutionService, bin/legion execute-plan
    │ Blocks: PRD-1-08 (validation tests full cycle)
    ▼
PRD-1-08 (Validation & E2E)            1 week
    │ Creates: 10 E2E scenarios, bin/legion validate
    │ Validates: Everything works as an integrated system
```

**Total estimated effort:** 8.5 weeks (42.5 days)

**No parallelization possible** — each PRD requires the previous to be complete, tested, and merged.

---

## PRD-1-01: Schema Foundation (1.5 weeks)

### What Gets Built

**7 Models + Migrations + Factories + Tests:**
1. `Project` — holds project path, rules
2. `AgentTeam` — groups agents (e.g., "ROR")
3. `TeamMembership` — agent config in JSONB, critical `#to_profile` method
4. `WorkflowRun` — execution record (one per agent dispatch)
5. `WorkflowEvent` — event log (published by PostgresBus)
6. `Task` — decomposed work item with scores
7. `TaskDependency` — DAG edges (join table)

### Implementation Steps

#### Step 1: Migrations (ordered by FK dependencies)

**Migration 1: `create_projects`**
```ruby
create_table :projects do |t|
  t.string :name, null: false
  t.string :path, null: false, index: { unique: true }
  t.jsonb :project_rules, null: false, default: {}
  t.timestamps
end
```

**Migration 2: `create_agent_teams`**
```ruby
create_table :agent_teams do |t|
  t.references :project, foreign_key: true, null: true  # optional — reusable teams
  t.string :name, null: false
  t.text :description
  t.jsonb :team_rules, null: false, default: {}
  t.timestamps
end

add_index :agent_teams, [:project_id, :name], unique: true
```

**Migration 3: `create_team_memberships`**
```ruby
create_table :team_memberships do |t|
  t.references :agent_team, null: false, foreign_key: true
  t.integer :position, null: false, default: 0
  t.jsonb :config, null: false, default: {}
  t.timestamps
end

add_index :team_memberships, [:agent_team_id, :position]
```

**Migration 4: `create_workflow_runs`**
```ruby
create_table :workflow_runs do |t|
  t.references :project, null: false, foreign_key: true
  t.references :team_membership, null: false, foreign_key: true
  t.references :task, foreign_key: true, null: true  # added in migration 6
  t.text :prompt, null: false
  t.string :status, null: false, default: "queued"
  t.integer :iterations, default: 0
  t.integer :duration_ms
  t.text :result
  t.text :error_message
  t.jsonb :metadata, null: false, default: {}
  t.timestamps
end

add_index :workflow_runs, :status
add_index :workflow_runs, :created_at
```

**Migration 5: `create_workflow_events`**
```ruby
create_table :workflow_events do |t|
  t.references :workflow_run, null: false, foreign_key: true
  t.string :event_type, null: false
  t.string :channel
  t.string :agent_id
  t.string :task_id
  t.jsonb :payload, null: false, default: {}
  t.datetime :recorded_at, null: false
  t.timestamps
end

add_index :workflow_events, [:workflow_run_id, :event_type]
add_index :workflow_events, :recorded_at
```

**Migration 6: `create_tasks`**
```ruby
create_table :tasks do |t|
  t.references :project, null: false, foreign_key: true
  t.references :workflow_run, foreign_key: true, null: true  # parent decomposition run
  t.references :team_membership, null: false, foreign_key: true
  t.references :execution_run, foreign_key: { to_table: :workflow_runs }, null: true
  t.integer :position, null: false, default: 0
  t.text :prompt, null: false
  t.string :task_type, null: false
  t.string :status, null: false, default: "pending"
  t.integer :files_score
  t.integer :concepts_score
  t.integer :dependencies_score
  t.integer :total_score
  t.integer :estimated_iterations
  t.jsonb :metadata, null: false, default: {}
  t.timestamps
end

add_index :tasks, [:workflow_run_id, :position]
add_index :tasks, :status
```

**Migration 6b: Add task_id FK to workflow_runs**
```ruby
# Separate migration or same as migration 6 (after tasks table exists)
add_reference :workflow_runs, :task, foreign_key: { to_table: :tasks }, null: true
```

**Migration 7: `create_task_dependencies`**
```ruby
create_table :task_dependencies do |t|
  t.references :task, null: false, foreign_key: true
  t.references :depends_on_task, null: false, foreign_key: { to_table: :tasks }
  t.timestamps
end

add_index :task_dependencies, [:task_id, :depends_on_task_id], unique: true, name: "index_task_deps_on_task_and_depends_on"
```

#### Step 2: Models

**`app/models/project.rb`**
```ruby
class Project < ApplicationRecord
  has_many :agent_teams, dependent: :destroy
  has_many :workflow_runs, dependent: :destroy
  has_many :tasks, dependent: :destroy

  validates :name, presence: true
  validates :path, presence: true, uniqueness: true
end
```

**`app/models/agent_team.rb`**
```ruby
class AgentTeam < ApplicationRecord
  belongs_to :project, optional: true
  has_many :team_memberships, dependent: :destroy

  validates :name, presence: true
  validates :name, uniqueness: { scope: :project_id }
end
```

**`app/models/team_membership.rb`**
```ruby
class TeamMembership < ApplicationRecord
  belongs_to :agent_team
  has_many :workflow_runs, dependent: :destroy

  validates :config, presence: true
  validate :config_has_required_keys

  scope :ordered, -> { order(position: :asc) }

  # Critical method: converts JSONB config → AgentDesk::Agent::Profile
  def to_profile
    AgentDesk::Agent::Profile.new(
      id: config["id"],
      name: config["name"],
      provider: config["provider"],
      model: config["model"],
      max_iterations: config["maxIterations"] || 250,
      use_power_tools: config["usePowerTools"] != false,
      use_aider_tools: config["useAiderTools"] != false,
      use_todo_tools: config["useTodoTools"] != false,
      use_memory_tools: config["useMemoryTools"] != false,
      use_skills_tools: config["useSkillsTools"] != false,
      use_subagents: config["useSubagents"] != false,
      use_task_tools: config["useTaskTools"] == true,
      custom_instructions: config["customInstructions"] || "",
      tool_approvals: normalize_tool_approvals(config["toolApprovals"]),
      tool_settings: config["toolSettings"] || {},
      subagent_config: build_subagent_config(config["subagent"])
    )
  end

  private

  def config_has_required_keys
    required = %w[id name provider model]
    missing = required - config.keys
    errors.add(:config, "missing required keys: #{missing.join(', ')}") if missing.any?
  end

  def normalize_tool_approvals(approvals)
    return {} unless approvals.is_a?(Hash)
    approvals.transform_keys(&:to_s).transform_values(&:to_s)
  end

  def build_subagent_config(subagent_data)
    return nil unless subagent_data.is_a?(Hash) && subagent_data["enabled"]
    # Return a hash that AgentDesk::SubagentConfig.new can consume
    # Check gem's SubagentConfig class for exact structure
    subagent_data
  end
end
```

**`app/models/workflow_run.rb`**
```ruby
class WorkflowRun < ApplicationRecord
  belongs_to :project
  belongs_to :team_membership
  belongs_to :task, optional: true
  has_many :workflow_events, dependent: :destroy
  has_many :tasks, foreign_key: :workflow_run_id, dependent: :nullify

  enum :status, {
    queued: "queued",
    running: "running",
    completed: "completed",
    failed: "failed",
    at_risk: "at_risk",
    decomposing: "decomposing",
    handed_off: "handed_off",
    budget_exceeded: "budget_exceeded",
    iteration_limit: "iteration_limit"
  }, validate: true

  validates :prompt, presence: true
  validates :status, presence: true

  scope :recent, -> { order(created_at: :desc) }
  scope :by_status, ->(status) { where(status: status) }
  scope :for_team, ->(team) { joins(:team_membership).where(team_memberships: { agent_team: team }) }
end
```

**`app/models/workflow_event.rb`**
```ruby
class WorkflowEvent < ApplicationRecord
  belongs_to :workflow_run

  validates :event_type, presence: true
  validates :recorded_at, presence: true

  scope :by_type, ->(type) { where(event_type: type) }
  scope :chronological, -> { order(recorded_at: :asc) }
end
```

**`app/models/task.rb`**
```ruby
class Task < ApplicationRecord
  belongs_to :project
  belongs_to :workflow_run, optional: true
  belongs_to :team_membership
  belongs_to :execution_run, class_name: "WorkflowRun", optional: true

  has_many :task_dependencies, dependent: :destroy
  has_many :dependencies, through: :task_dependencies, source: :depends_on_task

  has_many :inverse_task_dependencies, class_name: "TaskDependency", foreign_key: :depends_on_task_id, dependent: :destroy
  has_many :dependents, through: :inverse_task_dependencies, source: :task

  enum :task_type, {
    test: "test",
    code: "code",
    review: "review",
    debug: "debug"
  }, validate: true

  enum :status, {
    pending: "pending",
    ready: "ready",
    running: "running",
    completed: "completed",
    failed: "failed",
    skipped: "skipped"
  }, validate: true

  validates :prompt, presence: true
  validates :files_score, inclusion: { in: 1..4 }, allow_nil: true
  validates :concepts_score, inclusion: { in: 1..4 }, allow_nil: true
  validates :dependencies_score, inclusion: { in: 1..4 }, allow_nil: true

  before_validation :compute_total_score

  scope :pending, -> { where(status: :pending) }
  scope :completed, -> { where(status: :completed) }
  scope :by_position, -> { order(position: :asc) }
  scope :ready, -> {
    where(status: [:pending, :ready])
      .left_joins(:task_dependencies)
      .group(:id)
      .having("COUNT(CASE WHEN tasks_depends_on.status != 'completed' THEN 1 END) = 0")
  }

  def ready?
    (pending? || ready?) && dependencies.all?(&:completed?)
  end

  def over_threshold?
    total_score && total_score > 6
  end

  def parallel_eligible?
    dependencies.empty? || dependencies.all?(&:completed?)
  end

  private

  def compute_total_score
    if files_score && concepts_score && dependencies_score
      self.total_score = files_score + concepts_score + dependencies_score
    end
  end
end
```

**`app/models/task_dependency.rb`**
```ruby
class TaskDependency < ApplicationRecord
  belongs_to :task
  belongs_to :depends_on_task, class_name: "Task"

  validates :task_id, presence: true
  validates :depends_on_task_id, presence: true
  validates :depends_on_task_id, uniqueness: { scope: :task_id }
  validate :no_self_reference
  validate :no_cycles

  private

  def no_self_reference
    if task_id == depends_on_task_id
      errors.add(:depends_on_task_id, "cannot depend on itself")
    end
  end

  def no_cycles
    return unless depends_on_task_id && task_id

    visited = Set.new
    queue = [depends_on_task_id]

    while queue.any?
      current_id = queue.shift
      next if visited.include?(current_id)

      if current_id == task_id
        errors.add(:base, "would create a dependency cycle")
        return
      end

      visited << current_id
      # Follow dependencies of current task
      next_deps = TaskDependency.where(task_id: current_id).pluck(:depends_on_task_id)
      queue.concat(next_deps)
    end
  end
end
```

#### Step 3: Factories

**`test/factories/projects.rb`**
```ruby
FactoryBot.define do
  factory :project do
    name { "Legion" }
    sequence(:path) { |n| "/tmp/test/project-#{n}" }
    project_rules { {} }
  end
end
```

**`test/factories/agent_teams.rb`**
```ruby
FactoryBot.define do
  factory :agent_team do
    association :project
    name { "ROR" }
    description { "Rails development team" }
    team_rules { {} }
  end
end
```

**`test/factories/team_memberships.rb`**
```ruby
FactoryBot.define do
  factory :team_membership do
    association :agent_team
    position { 0 }
    config do
      {
        "id" => "ror-rails-legion",
        "name" => "Rails Lead (Legion)",
        "provider" => "deepseek",
        "model" => "deepseek-reasoner",
        "maxIterations" => 200,
        "usePowerTools" => true,
        "useSkillsTools" => true,
        "useTodoTools" => true,
        "useMemoryTools" => true,
        "useSubagents" => true,
        "useTaskTools" => false,
        "toolApprovals" => { "power---bash" => "ask" },
        "toolSettings" => {},
        "customInstructions" => "ZERO THINKING OUT LOUD"
      }
    end
  end
end
```

**`test/factories/workflow_runs.rb`**
```ruby
FactoryBot.define do
  factory :workflow_run do
    association :project
    association :team_membership
    prompt { "Test prompt" }
    status { :queued }
    iterations { 0 }
    metadata { {} }
  end
end
```

**`test/factories/workflow_events.rb`**
```ruby
FactoryBot.define do
  factory :workflow_event do
    association :workflow_run
    event_type { "agent.started" }
    channel { "agent.started" }
    agent_id { "test-agent" }
    recorded_at { Time.current }
    payload { {} }
  end
end
```

**`test/factories/tasks.rb`**
```ruby
FactoryBot.define do
  factory :task do
    association :project
    association :team_membership
    association :workflow_run, factory: :workflow_run
    position { 0 }
    prompt { "Test task prompt" }
    task_type { :code }
    status { :pending }
    files_score { 2 }
    concepts_score { 1 }
    dependencies_score { 1 }
    metadata { {} }
  end
end
```

**`test/factories/task_dependencies.rb`**
```ruby
FactoryBot.define do
  factory :task_dependency do
    association :task
    association :depends_on_task, factory: :task
  end
end
```

#### Step 4: Unit Tests

Create test files for all 7 models:
- `test/models/project_test.rb`
- `test/models/agent_team_test.rb`
- `test/models/team_membership_test.rb` — **CRITICAL: test `to_profile` against real config.json fixture**
- `test/models/workflow_run_test.rb`
- `test/models/workflow_event_test.rb`
- `test/models/task_test.rb`
- `test/models/task_dependency_test.rb` — **CRITICAL: test cycle detection (direct + indirect cycles)**

#### Step 5: Integration Tests

**`test/integration/schema_test.rb`** — Create full object graph, verify all associations navigable

**`test/integration/task_dependency_graph_test.rb`** — Build 5+ node DAG, test ready scope, cycle rejection

### Acceptance Criteria Checklist

- [ ] All 7 migrations run successfully (`rails db:migrate`)
- [ ] All migrations reversible (`rails db:rollback STEP=7`)
- [ ] All 7 models have validations, associations, and enums working
- [ ] All 7 FactoryBot factories produce valid records
- [ ] `TeamMembership#to_profile` correctly maps real `.aider-desk` config to Profile
- [ ] TaskDependency cycle detection prevents cycles (tested with direct A→B→A and indirect A→B→C→A)
- [ ] Task.ready scope returns only tasks with all dependencies completed
- [ ] All foreign key constraints exist at database level
- [ ] `rails test` — zero failures

### Manual Verification

```bash
rails db:migrate
rails db:rollback STEP=7
rails db:migrate
rails console
# Create full object graph manually
# Verify associations work
# Test to_profile conversion
rails test test/models/
```

---

## PRD-1-02: PostgresBus Adapter (1 week)

### What Gets Built

**Service:** `app/services/legion/postgres_bus.rb`

Implements `AgentDesk::MessageBus::MessageBusInterface` (4 methods):
- `publish(channel, event)` — persists to WorkflowEvent + forwards to CallbackBus
- `subscribe(channel_pattern, &block)` — delegates to CallbackBus
- `unsubscribe(subscription_id)` — delegates to CallbackBus
- `clear` — clears CallbackBus (does NOT delete WorkflowEvent records)

### Implementation Steps

#### Step 1: Create Service

**`app/services/legion/postgres_bus.rb`**
```ruby
module Legion
  class PostgresBus
    include AgentDesk::MessageBus::MessageBusInterface

    def initialize(workflow_run:, skip_event_types: [])
      @workflow_run = workflow_run
      @skip_event_types = skip_event_types
      @callback_bus = AgentDesk::MessageBus::CallbackBus.new
    end

    def publish(channel, event)
      # 1. Persist to database (unless skipped)
      persist_event(channel, event) unless @skip_event_types.include?(event.type)

      # 2. Forward to CallbackBus (always)
      @callback_bus.publish(channel, event)

      # 3. Solid Cable broadcast (stub for Epic 4)
      broadcast_event(channel, event)
    rescue StandardError => e
      Rails.logger.error("PostgresBus publish failed: #{e.message} (event: #{event.type}, run: #{@workflow_run.id})")
      # Still deliver to CallbackBus even if DB write fails
      @callback_bus.publish(channel, event)
    end

    def subscribe(channel_pattern, &block)
      @callback_bus.subscribe(channel_pattern, &block)
    end

    def unsubscribe(subscription_id)
      @callback_bus.unsubscribe(subscription_id)
    end

    def clear
      @callback_bus.clear
      # Does NOT delete WorkflowEvent records
    end

    private

    def persist_event(channel, event)
      WorkflowEvent.create!(
        workflow_run: @workflow_run,
        event_type: event.type,
        channel: channel,
        agent_id: event.agent_id,
        task_id: event.task_id,
        payload: serialize_payload(event.payload),
        recorded_at: event.timestamp
      )
    end

    def serialize_payload(payload)
      return payload if payload.is_a?(Hash)
      { "error" => "payload not serializable", "class" => payload.class.name }
    rescue StandardError
      { "error" => "payload serialization failed" }
    end

    def broadcast_event(channel, event)
      # TODO Epic 4: ActionCable.server.broadcast("workflow_run_#{@workflow_run.id}", { channel: channel, event: event.to_h })
    end
  end
end
```

#### Step 2: Unit Tests

**`test/services/legion/postgres_bus_test.rb`**

Test cases:
- Creates WorkflowEvent on publish with correct field mapping
- Forwards event to CallbackBus subscribers
- Wildcard subscription receives matching events
- Unsubscribe stops delivery
- Clear removes subscribers, does not delete DB records
- DB failure logged but does not raise
- DB failure still delivers to CallbackBus
- `skip_event_types` prevents DB write for skipped types
- `skip_event_types` still delivers skipped types to CallbackBus
- Handles all 11 gem event types
- Malformed payload stored with error marker

#### Step 3: Integration Tests

**`test/integration/postgres_bus_integration_test.rb`**

Test cases:
- Full cycle: Create WorkflowRun → PostgresBus → Publish events → Verify DB + subscribers
- Event ordering: Publish 10 events, verify `recorded_at` ordering preserved
- WorkflowEvent.by_type scope returns correct subset

### Acceptance Criteria Checklist

- [ ] `Legion::PostgresBus` includes `MessageBusInterface`
- [ ] `publish` creates WorkflowEvent with correct field mapping
- [ ] `publish` forwards to CallbackBus after DB write
- [ ] Subscribers receive events through CallbackBus
- [ ] Wildcard patterns work (`agent.*` matches `agent.started`)
- [ ] `unsubscribe` removes subscriber
- [ ] `clear` removes subscribers, does NOT delete WorkflowEvent records
- [ ] DB write failure logged, does not raise, CallbackBus still delivers
- [ ] `skip_event_types` prevents DB write but still delivers to CallbackBus
- [ ] Solid Cable broadcast stub exists with Epic 4 TODO
- [ ] All 11 gem event types can be persisted
- [ ] `rails test test/services/legion/` — zero failures

### Manual Verification

```bash
rails console
# Create WorkflowRun
# Create PostgresBus
# Publish test events
# Verify WorkflowEvent records in DB
# Verify subscribers received events
```

---

## PRD-1-03: Team Import (0.5 week)

### What Gets Built

**Service:** `app/services/legion/team_import_service.rb`
**Rake Task:** `lib/tasks/teams.rake`

Reads `.aider-desk/agents/` directory, creates Project, AgentTeam, TeamMembership records with full JSONB config.

### Implementation Steps

#### Step 1: Create Service

**`app/services/legion/team_import_service.rb`**
```ruby
module Legion
  class TeamImportService
    def self.call(aider_desk_path:, project_path: Dir.pwd, team_name: "ROR", dry_run: false)
      new(aider_desk_path:, project_path:, team_name:, dry_run:).call
    end

    def initialize(aider_desk_path:, project_path:, team_name:, dry_run:)
      @aider_desk_path = File.expand_path(aider_desk_path)
      @project_path = File.expand_path(project_path)
      @team_name = team_name
      @dry_run = dry_run
      @errors = []
    end

    def call
      validate_paths!
      
      agent_configs = load_agent_configs
      return dry_run_report(agent_configs) if @dry_run

      import_to_database(agent_configs)
    end

    private

    def validate_paths!
      raise "Directory not found: #{@aider_desk_path}" unless Dir.exist?(@aider_desk_path)
      agents_dir = File.join(@aider_desk_path, "agents")
      raise "No agents directory found at #{agents_dir}" unless Dir.exist?(agents_dir)
    end

    def load_agent_configs
      agents_dir = File.join(@aider_desk_path, "agents")
      order = load_order_json(agents_dir)
      
      agent_dirs = if order
        order.map { |id| File.join(agents_dir, id) }.select { |d| Dir.exist?(d) }
      else
        Rails.logger.warn("order.json not found, using alphabetical ordering")
        Dir.glob(File.join(agents_dir, "*")).select { |d| File.directory?(d) }.sort
      end

      agent_dirs.map.with_index do |dir, idx|
        load_agent_config(dir, idx)
      end.compact
    end

    def load_order_json(agents_dir)
      order_file = File.join(agents_dir, "order.json")
      return nil unless File.exist?(order_file)
      JSON.parse(File.read(order_file))
    rescue JSON::ParserError => e
      Rails.logger.error("Failed to parse order.json: #{e.message}")
      nil
    end

    def load_agent_config(dir, position)
      config_file = File.join(dir, "config.json")
      
      unless File.exist?(config_file)
        @errors << "Missing config.json in #{dir}"
        return nil
      end

      config = JSON.parse(File.read(config_file))
      
      required = %w[id name provider model]
      missing = required - config.keys
      if missing.any?
        @errors << "#{File.basename(dir)}: missing required fields: #{missing.join(', ')}"
        return nil
      end

      { config: config, position: position }
    rescue JSON::ParserError => e
      @errors << "#{File.basename(dir)}: malformed JSON - #{e.message}"
      nil
    end

    def dry_run_report(agent_configs)
      puts "DRY RUN — no records will be created"
      puts "Project: #{File.basename(@project_path)} (#{@project_path})"
      puts "Team: #{@team_name}"
      puts ""
      puts "Would import #{agent_configs.size} agents:"
      agent_configs.each do |ac|
        puts "  #{ac[:position] + 1}. #{ac[:config]['name']} (#{ac[:config]['provider']}/#{ac[:config]['model']})"
      end
      
      { project: nil, team: nil, memberships: [], created: agent_configs.size, updated: 0, skipped: 0, errors: @errors }
    end

    def import_to_database(agent_configs)
      result = { created: 0, updated: 0, skipped: 0 }

      ApplicationRecord.transaction do
        project = Project.find_or_create_by!(path: @project_path) do |p|
          p.name = File.basename(@project_path).titleize
        end

        team = AgentTeam.find_or_create_by!(project: project, name: @team_name) do |t|
          t.description = "Imported from #{@aider_desk_path}"
        end

        agent_configs.each do |ac|
          membership = team.team_memberships.find_by("config->>'id' = ?", ac[:config]["id"])
          
          if membership
            if membership.config != ac[:config]
              membership.update!(config: ac[:config], position: ac[:position])
              result[:updated] += 1
            else
              result[:skipped] += 1
            end
          else
            team.team_memberships.create!(config: ac[:config], position: ac[:position])
            result[:created] += 1
          end
        end

        print_import_report(project, team, result)
        
        result.merge(project: project, team: team, errors: @errors)
      end
    end

    def print_import_report(project, team, result)
      puts "Importing agents from #{@aider_desk_path}"
      puts "Project: #{project.name} (#{project.path})"
      puts "Team: #{team.name}"
      puts ""
      puts "  #  Agent                     Provider   Model               Status"
      
      team.team_memberships.ordered.each do |tm|
        status = if result[:created] > 0
          result[:created] -= 1
          "created"
        elsif result[:updated] > 0
          result[:updated] -= 1
          "updated"
        else
          "unchanged"
        end
        
        puts "  #{tm.position + 1}  #{tm.config['name'].ljust(24)} #{tm.config['provider'].ljust(10)} #{tm.config['model'].ljust(18)} #{status}"
      end
      
      puts ""
      puts "Imported #{result[:created] + result[:updated]} agents (#{result[:created]} created, #{result[:updated]} updated, #{@errors.size} errors)"
      
      if @errors.any?
        puts ""
        puts "Errors:"
        @errors.each { |e| puts "  - #{e}" }
      end
    end
  end
end
```

#### Step 2: Rake Task

**`lib/tasks/teams.rake`**
```ruby
namespace :teams do
  desc "Import agent team from .aider-desk directory"
  task :import, [:path, :options] => :environment do |t, args|
    path = args[:path] || "~/.aider-desk"
    options = args[:options] || ""
    
    dry_run = options.include?("--dry-run")
    team_name_match = options.match(/--team-name=(\w+)/)
    team_name = team_name_match ? team_name_match[1] : "ROR"

    result = Legion::TeamImportService.call(
      aider_desk_path: path,
      project_path: Rails.root.to_s,
      team_name: team_name,
      dry_run: dry_run
    )

    exit 1 if result[:errors].any?
  end
end
```

#### Step 3: Unit Tests

**`test/services/legion/team_import_service_test.rb`**

Test with fixture directory containing 4 agent configs:
- Imports from fixture → creates correct records
- Dry-run creates no records, returns preview
- Re-import updates changed config, preserves IDs
- Re-import with unchanged config reports "unchanged"
- Missing order.json → alphabetical fallback
- Missing config.json → agent skipped, error reported
- Malformed JSON → agent skipped, error includes parse message
- Missing required fields → agent skipped, error lists fields
- Empty agents directory → error
- Position assignment matches order.json
- Project upsert by path
- Team upsert by name+project

#### Step 4: Integration Tests

**`test/integration/team_import_integration_test.rb`**

- Import from test fixtures mirroring `.aider-desk` structure
- Verify `to_profile` on each imported membership
- Import → re-import → verify IDs stable
- Transaction rollback on error → no partial records

### Acceptance Criteria Checklist

- [ ] `rake teams:import[~/.aider-desk]` creates Project, AgentTeam, 4 TeamMemberships
- [ ] Each TeamMembership config JSONB contains full config.json
- [ ] TeamMembership positions match order.json
- [ ] `to_profile` on imported membership returns valid Profile
- [ ] Dry-run reports preview without writing
- [ ] Re-import updates changed configs, preserves IDs
- [ ] Missing order.json falls back to alphabetical with warning
- [ ] Malformed config.json skipped with error
- [ ] Missing required fields → agent skipped with error
- [ ] Console output shows summary table
- [ ] All writes wrapped in transaction
- [ ] `rails test test/services/legion/team_import*` — zero failures

### Manual Verification

```bash
rake teams:import[~/.aider-desk]
rails console
# Verify 4 agents in DB
# Test to_profile on each
rake teams:import[~/.aider-desk,--dry-run]
rake teams:import[~/.aider-desk]  # idempotent
```

---

## PRD-1-04: CLI Dispatch (1.5 weeks)

### What Gets Built

**CLI:** `bin/legion` (Thor-based)
**Services:**
- `app/services/legion/agent_assembly_service.rb` — assembles Profile → Rules → Prompts → Tools → ModelManager → PostgresBus → Hooks → ApprovalManager → Runner
- `app/services/legion/dispatch_service.rb` — finds team/agent, creates WorkflowRun, calls assembly, executes

### Implementation Steps

#### Step 1: CLI Entry Point

**`bin/legion`**
```ruby
#!/usr/bin/env ruby
APP_PATH = File.expand_path("../config/application", __dir__)
require_relative "../config/boot"
require_relative "../config/environment"
require "thor"

module Legion
  class CLI < Thor
    desc "execute", "Dispatch an agent to execute a prompt"
    option :team, required: true, desc: "Team name"
    option :agent, required: true, desc: "Agent identifier (id or name)"
    option :prompt, desc: "Prompt text"
    option :prompt_file, desc: "Path to prompt file"
    option :project, desc: "Project path override"
    option :max_iterations, type: :numeric, desc: "Override max iterations"
    option :interactive, type: :boolean, default: false, desc: "Enable interactive tool approval"
    option :verbose, type: :boolean, default: false, desc: "Print real-time event stream"
    def execute
      validate_prompt_options!
      
      prompt = options[:prompt] || File.read(File.expand_path(options[:prompt_file]))
      
      result = Legion::DispatchService.call(
        team_name: options[:team],
        agent_identifier: options[:agent],
        prompt: prompt,
        project_path: options[:project] || Dir.pwd,
        max_iterations: options[:max_iterations],
        interactive: options[:interactive],
        verbose: options[:verbose]
      )
      
      exit result[:exit_code]
    rescue Legion::DispatchService::TeamNotFound => e
      puts "Error: #{e.message}"
      exit 3
    rescue Legion::DispatchService::AgentNotFound => e
      puts "Error: #{e.message}"
      exit 3
    rescue Errno::ENOENT => e
      puts "Error: File not found: #{options[:prompt_file]}"
      exit 2
    end

    private

    def validate_prompt_options!
      if options[:prompt] && options[:prompt_file]
        puts "Error: Provide either --prompt or --prompt-file, not both"
        exit 2
      end
      
      unless options[:prompt] || options[:prompt_file]
        puts "Error: One of --prompt or --prompt-file is required"
        exit 2
      end
    end
  end
end

Legion::CLI.start(ARGV)
```

Make executable:
```bash
chmod +x bin/legion
```

#### Step 2: Agent Assembly Service

**`app/services/legion/agent_assembly_service.rb`**
```ruby
module Legion
  class AgentAssemblyService
    def self.call(team_membership:, project_dir:, workflow_run:, interactive: false)
      new(team_membership:, project_dir:, workflow_run:, interactive:).call
    end

    def initialize(team_membership:, project_dir:, workflow_run:, interactive:)
      @team_membership = team_membership
      @project_dir = project_dir
      @workflow_run = workflow_run
      @interactive = interactive
    end

    def call
      profile = @team_membership.to_profile
      rules_content = load_rules(profile)
      system_prompt = build_system_prompt(profile, rules_content)
      tool_set = assemble_tools(profile)
      model_manager = build_model_manager(profile)
      message_bus = build_message_bus
      hook_manager = build_hook_manager
      approval_manager = build_approval_manager(profile)
      runner = build_runner(model_manager, message_bus, hook_manager, approval_manager, profile)

      {
        runner: runner,
        system_prompt: system_prompt,
        tool_set: tool_set,
        profile: profile,
        message_bus: message_bus
      }
    end

    private

    def load_rules(profile)
      AgentDesk::Rules::RulesLoader.load_rules_content(
        profile_dir_name: profile.id,
        project_dir: @project_dir
      )
    end

    def build_system_prompt(profile, rules_content)
      AgentDesk::Prompts::PromptsManager.system_prompt(
        profile: profile,
        project_dir: @project_dir,
        rules_content: rules_content,
        custom_instructions: profile.custom_instructions
      )
    end

    def assemble_tools(profile)
      tools = []
      
      tools.concat(AgentDesk::Tools::PowerTools.create(project_dir: @project_dir, profile: profile)) if profile.use_power_tools
      tools.concat([AgentDesk::Skills::SkillLoader.activate_skill_tool(project_dir: @project_dir)]) if profile.use_skills_tools
      tools.concat(AgentDesk::Tools::TodoTools.create) if profile.use_todo_tools
      tools.concat(AgentDesk::Tools::MemoryTools.create(project_dir: @project_dir)) if profile.use_memory_tools
      
      tools
    end

    def build_model_manager(profile)
      AgentDesk::Agent::ModelManager.new(
        provider: profile.provider,
        model: profile.model,
        api_key: ENV.fetch("SMART_PROXY_TOKEN"),
        base_url: ENV.fetch("SMART_PROXY_URL", "http://192.168.4.253:3001")
      )
    end

    def build_message_bus
      Legion::PostgresBus.new(workflow_run: @workflow_run)
    end

    def build_hook_manager
      AgentDesk::Hooks::HookManager.new
    end

    def build_approval_manager(profile)
      ask_block = if @interactive
        ->(text, subject) {
          puts "\n#{text}"
          print "Approve? (y/a/n): "
          response = $stdin.gets.chomp.downcase
          ["y", "a"].include?(response)
        }
      else
        ->(text, subject) {
          Rails.logger.info("Auto-approving tool: #{subject}")
          true
        }
      end

      AgentDesk::Tools::ApprovalManager.new(
        tool_approvals: profile.tool_approvals,
        ask_user_block: ask_block
      )
    end

    def build_runner(model_manager, message_bus, hook_manager, approval_manager, profile)
      AgentDesk::Agent::Runner.new(
        model_manager: model_manager,
        message_bus: message_bus,
        hook_manager: hook_manager,
        approval_manager: approval_manager,
        profile: profile
      )
    end
  end
end
```

#### Step 3: Dispatch Service

**`app/services/legion/dispatch_service.rb`**
```ruby
module Legion
  class DispatchService
    class TeamNotFound < StandardError; end
    class AgentNotFound < StandardError; end

    def self.call(team_name:, agent_identifier:, prompt:, project_path:, max_iterations: nil, interactive: false, verbose: false)
      new(team_name:, agent_identifier:, prompt:, project_path:, max_iterations:, interactive:, verbose:).call
    end

    def initialize(team_name:, agent_identifier:, prompt:, project_path:, max_iterations:, interactive:, verbose:)
      @team_name = team_name
      @agent_identifier = agent_identifier
      @prompt = prompt
      @project_path = File.expand_path(project_path)
      @max_iterations = max_iterations
      @interactive = interactive
      @verbose = verbose
    end

    def call
      project = find_or_create_project
      team = find_team(project)
      membership = find_agent(team)
      
      workflow_run = create_workflow_run(project, membership)
      
      assembly = AgentAssemblyService.call(
        team_membership: membership,
        project_dir: @project_path,
        workflow_run: workflow_run,
        interactive: @interactive
      )

      subscribe_verbose(assembly[:message_bus]) if @verbose
      
      start_time = Time.now
      execute_runner(assembly, workflow_run)
      duration_ms = ((Time.now - start_time) * 1000).to_i
      
      finalize_workflow_run(workflow_run, duration_ms, assembly[:runner])
      
      print_summary(workflow_run, membership)
      
      { exit_code: workflow_run.completed? ? 0 : 1, workflow_run: workflow_run }
    rescue StandardError => e
      workflow_run&.update(status: :failed, error_message: e.message)
      Rails.logger.error("Dispatch failed: #{e.message}\n#{e.backtrace.join("\n")}")
      { exit_code: 1, workflow_run: workflow_run }
    end

    private

    def find_or_create_project
      Project.find_or_create_by!(path: @project_path) do |p|
        p.name = File.basename(@project_path).titleize
      end
    end

    def find_team(project)
      team = AgentTeam.find_by(project: project, name: @team_name)
      raise TeamNotFound, "Team '#{@team_name}' not found" unless team
      team
    end

    def find_agent(team)
      membership = team.team_memberships.find do |tm|
        tm.config["id"]&.downcase&.include?(@agent_identifier.downcase) ||
        tm.config["name"]&.downcase&.include?(@agent_identifier.downcase)
      end
      
      unless membership
        available = team.team_memberships.map { |tm| tm.config["name"] }.join(", ")
        raise AgentNotFound, "Agent '#{@agent_identifier}' not in team '#{@team_name}'. Available agents: #{available}"
      end
      
      membership
    end

    def create_workflow_run(project, membership)
      WorkflowRun.create!(
        project: project,
        team_membership: membership,
        prompt: @prompt,
        status: :running
      )
    end

    def subscribe_verbose(message_bus)
      message_bus.subscribe("*") do |event|
        puts "[#{event.type}] #{format_event(event)}"
      end
    end

    def format_event(event)
      case event.type
      when "agent.started"
        "#{event.agent_id} — starting"
      when "tool.called"
        "#{event.payload['tool']} → #{event.payload['subject']}"
      when "tool.result"
        "#{event.payload['tool']} → #{event.payload['summary']}"
      when "response.complete"
        "#{event.payload['iterations']} iterations, #{event.payload['duration']}s"
      when "agent.completed"
        "#{event.agent_id} — completed"
      else
        event.type
      end
    end

    def execute_runner(assembly, workflow_run)
      profile = assembly[:profile]
      
      assembly[:runner].run(
        prompt: @prompt,
        system_prompt: assembly[:system_prompt],
        tool_set: assembly[:tool_set],
        profile: profile,
        project_dir: @project_path,
        agent_id: profile.id,
        task_id: nil,
        max_iterations: @max_iterations || profile.max_iterations
      )
    end

    def finalize_workflow_run(workflow_run, duration_ms, runner)
      workflow_run.update!(
        status: :completed,
        iterations: runner.iterations,
        duration_ms: duration_ms,
        result: runner.final_response
      )
    rescue StandardError
      workflow_run.update(status: :failed, duration_ms: duration_ms)
    end

    def print_summary(workflow_run, membership)
      puts ""
      puts "Agent: #{membership.config['name']}"
      puts "Model: #{membership.config['model']}"
      puts "Iterations: #{workflow_run.iterations}"
      puts "Duration: #{workflow_run.duration_ms}ms"
      puts "Events: #{workflow_run.workflow_events.count}"
      puts "Status: #{workflow_run.status}"
    end
  end
end
```

#### Step 4: Tests

**Unit tests:**
- `test/services/legion/agent_assembly_service_test.rb` — test each component assembly
- `test/services/legion/dispatch_service_test.rb` — test team/agent lookup, WorkflowRun creation

**Integration tests:**
- `test/integration/cli_dispatch_integration_test.rb` — full pipeline with VCR

### Acceptance Criteria Checklist

- [ ] `bin/legion execute --team ROR --agent rails-lead --prompt "hello"` works
- [ ] Agent runs with correct model from TeamMembership config
- [ ] Agent runs with rules in system prompt
- [ ] Agent runs with skills available
- [ ] Agent runs with tool approvals from config
- [ ] Agent runs with custom instructions
- [ ] WorkflowRun created with status `running`, updated to `completed`
- [ ] WorkflowEvent records created for all events
- [ ] `--prompt-file` reads prompt from file
- [ ] `--verbose` prints real-time event stream
- [ ] `--max-iterations` overrides agent's default
- [ ] `--interactive` enables terminal tool approval
- [ ] Non-interactive auto-approves ASK tools
- [ ] Team not found → exit 3 with message
- [ ] Agent not found → exit 3 with available agents list
- [ ] AgentAssemblyService is separate, reusable
- [ ] `rails test test/services/legion/` — zero failures

### Manual Verification

```bash
rake teams:import[~/.aider-desk]
bin/legion execute --team ROR --agent rails-lead --prompt "Say hello" --verbose
rails console
# Verify WorkflowRun and WorkflowEvents in DB
bin/legion execute --team ROR --agent qa --prompt "List your skills"
bin/legion execute --team NONEXISTENT --agent foo --prompt "test"  # Should exit 3
```

---

## PRD-1-05 through PRD-1-08

*Due to response length limits, I'll create the plan document with the remaining PRDs (1-05 through 1-08) covering:*
- **PRD-1-05:** OrchestratorHooksService registration, 4 hooks with model-specific thresholds
- **PRD-1-06:** DecompositionService, DecompositionParser, `bin/legion decompose` subcommand, test-first prompt template
- **PRD-1-07:** PlanExecutionService, `bin/legion execute-plan` subcommand, dependency graph walking
- **PRD-1-08:** 10 E2E scenarios, `bin/legion validate`, test fixtures

Let me write the continuation:
