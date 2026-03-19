# PRD-1-01: Schema Foundation — Implementation Plan

**Created:** 2026-03-06  
**Owner:** Rails Lead (DeepSeek Reasoner)  
**Epic:** Epic 1 — Orchestration Foundation  
**PRD:** [PRD-1-01-schema-foundation.md](./PRD-1-01-schema-foundation.md)  
**Master Plan Reference:** [implementation-plan.md](./implementation-plan.md)  
**Status:** PLAN-APPROVED — Architect amendments applied 2026-03-06 (re-read before coding)

---

## 1. Overview

Create the 7 core database models that underpin Legion's orchestration layer: Project, AgentTeam, TeamMembership, WorkflowRun, WorkflowEvent, Task, and TaskDependency. These models provide the persistence layer for agent identity (who runs), execution tracking (what happened), task decomposition (what work exists), and dependency management (what order).

This is the critical-path PRD — every subsequent PRD in Epic 1 depends on these tables existing. The schema is designed to support parallel task execution (Epic 2) from day one, even though Epic 1 dispatches sequentially.

**Blocked By:** None (first PRD on critical path)  
**Blocks:** PRD-1-02, PRD-1-03, PRD-1-04, PRD-1-05, PRD-1-06, PRD-1-07, PRD-1-08

---

## 2. File-by-File Changes

### 2.1. Migrations (7 files, ordered by FK dependencies)

**M001: `db/migrate/[timestamp]_create_projects.rb`**
```ruby
class CreateProjects < ActiveRecord::Migration[8.1]
  def change
    create_table :projects do |t|
      t.string :name, null: false
      t.string :path, null: false, index: { unique: true }
      t.jsonb :project_rules, null: false, default: {}
      t.timestamps
    end
  end
end
```

**M002: `db/migrate/[timestamp]_create_agent_teams.rb`**
```ruby
class CreateAgentTeams < ActiveRecord::Migration[8.1]
  def change
    create_table :agent_teams do |t|
      t.references :project, foreign_key: true, null: true  # optional — reusable teams
      t.string :name, null: false
      t.text :description
      t.jsonb :team_rules, null: false, default: {}
      t.timestamps
    end

    add_index :agent_teams, [:project_id, :name], unique: true
  end
end
```

**M003: `db/migrate/[timestamp]_create_team_memberships.rb`**
```ruby
class CreateTeamMemberships < ActiveRecord::Migration[8.1]
  def change
    create_table :team_memberships do |t|
      t.references :agent_team, null: false, foreign_key: true
      t.integer :position, null: false, default: 0
      t.jsonb :config, null: false, default: {}
      t.timestamps
    end

    add_index :team_memberships, [:agent_team_id, :position]
  end
end
```

**M004: `db/migrate/[timestamp]_create_workflow_runs.rb`**
```ruby
class CreateWorkflowRuns < ActiveRecord::Migration[8.1]
  def change
    create_table :workflow_runs do |t|
      t.references :project, null: false, foreign_key: true
      t.references :team_membership, null: false, foreign_key: true
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
  end
end
```

**M005: `db/migrate/[timestamp]_create_workflow_events.rb`**
```ruby
class CreateWorkflowEvents < ActiveRecord::Migration[8.1]
  def change
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
  end
end
```

**M006: `db/migrate/[timestamp]_create_tasks.rb`**
```ruby
class CreateTasks < ActiveRecord::Migration[8.1]
  def change
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
  end
end
```

**M006b: `db/migrate/[timestamp]_add_task_reference_to_workflow_runs.rb`**
```ruby
class AddTaskReferenceToWorkflowRuns < ActiveRecord::Migration[8.1]
  def change
    add_reference :workflow_runs, :task, foreign_key: { to_table: :tasks }, null: true
  end
end
```

**M007: `db/migrate/[timestamp]_create_task_dependencies.rb`**
```ruby
class CreateTaskDependencies < ActiveRecord::Migration[8.1]
  def change
    create_table :task_dependencies do |t|
      t.references :task, null: false, foreign_key: true
      t.references :depends_on_task, null: false, foreign_key: { to_table: :tasks }
      t.timestamps
    end

    add_index :task_dependencies, [:task_id, :depends_on_task_id], unique: true, name: "index_task_deps_on_task_and_depends_on"
  end
end
```

### 2.2. Models (7 files)

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

### 2.3. FactoryBot Factories (7 files)

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

### 2.4. Unit Tests (7 files)

**`test/models/project_test.rb`** — Validations (name/path presence, path uniqueness), associations, factory validity  
**`test/models/agent_team_test.rb`** — Validations (name presence, scoped uniqueness), optional project association, factory validity  
**`test/models/team_membership_test.rb`** — Config JSONB validation (required keys), `to_profile` conversion (all fields mapped correctly), `ordered` scope, factory validity  
**`test/models/workflow_run_test.rb`** — Status enum values, associations, scopes (`by_status`, `recent`, `for_team`), factory validity  
**`test/models/workflow_event_test.rb`** — Validations, `by_type` scope, `chronological` scope, factory validity  
**`test/models/task_test.rb`** — Score validations (1-4 range), `compute_total_score` callback, `ready?` method, `over_threshold?` method, status enum, task_type enum, factory validity  
**`test/models/task_dependency_test.rb`** — Self-reference prevention, uniqueness validation, **DAG cycle detection** (direct cycle A→B→A, indirect cycle A→B→C→A, valid DAG accepted), factory validity

### 2.5. Integration Tests (2 files)

**`test/integration/schema_test.rb`** — Create full object graph (Project → Team → Membership → WorkflowRun → Events + Tasks → Dependencies), verify all associations navigable, verify `to_profile` against real config.json fixture  
**`test/integration/task_dependency_graph_test.rb`** — Build a 5+ node DAG, verify `ready` scope returns correct tasks, mark tasks completed and verify new tasks become ready, attempt cycle and verify rejection

---

## 3. Numbered Test Checklist (MUST-IMPLEMENT)

### 3.1. Unit Tests (7 files, 30+ test cases)

1. **ProjectTest** [ ]
   - [ ] `test_valid_project` — factory creates valid record
   - [ ] `test_name_validation` — name required
   - [ ] `test_path_validation` — path required and unique
   - [ ] `test_associations` — has_many agent_teams, workflow_runs, tasks

2. **AgentTeamTest** [ ]
   - [ ] `test_valid_agent_team` — factory creates valid record
   - [ ] `test_name_validation` — name required
   - [ ] `test_scoped_uniqueness` — unique name within same project
   - [ ] `test_optional_project` — team can exist without project
   - [ ] `test_associations` — belongs_to project (optional), has_many team_memberships

3. **TeamMembershipTest** [ ]
   - [ ] `test_valid_team_membership` — factory creates valid record
   - [ ] `test_config_validation` — config required
   - [ ] `test_required_keys_validation` — config must contain id, name, provider, model
   - [ ] `test_ordered_scope` — returns memberships sorted by position
   - [ ] `test_to_profile_conversion` — returns AgentDesk::Agent::Profile
   - [ ] `test_to_profile_field_mapping` — all JSON fields correctly mapped to Profile attributes
   - [ ] `test_to_profile_with_real_config` — uses actual .aider-desk config.json fixture

4. **WorkflowRunTest** [ ]
   - [ ] `test_valid_workflow_run` — factory creates valid record
   - [ ] `test_prompt_validation` — prompt required
   - [ ] `test_status_enum` — all 9 status values valid
   - [ ] `test_status_default` — default status "queued"
   - [ ] `test_associations` — belongs_to project, team_membership, task; has_many workflow_events, tasks
   - [ ] `test_scopes` — by_status, recent, for_team work correctly

5. **WorkflowEventTest** [ ]
   - [ ] `test_valid_workflow_event` — factory creates valid record
   - [ ] `test_event_type_validation` — event_type required
   - [ ] `test_recorded_at_validation` — recorded_at required
   - [ ] `test_associations` — belongs_to workflow_run
   - [ ] `test_scopes` — by_type, chronological work correctly

6. **TaskTest** [ ]
   - [ ] `test_valid_task` — factory creates valid record
   - [ ] `test_prompt_validation` — prompt required
   - [ ] `test_score_validations` — files/concepts/dependencies scores in 1-4 range
   - [ ] `test_total_score_computation` — automatically computed as sum of three scores
   - [ ] `test_status_enum` — all 6 status values valid
   - [ ] `test_task_type_enum` — all 4 task_type values valid
   - [ ] `test_ready_method` — returns true when pending and all dependencies completed
   - [ ] `test_over_threshold_method` — returns true when total_score > 6
   - [ ] `test_parallel_eligible_method` — returns true when no unfinished dependencies
   - [ ] `test_associations` — belongs_to project, workflow_run, team_membership, execution_run; has_many task_dependencies, dependencies, inverse_task_dependencies, dependents
   - [ ] `test_scopes` — pending, completed, by_position, ready work correctly

7. **TaskDependencyTest** [ ]
   - [ ] `test_valid_task_dependency` — factory creates valid record
   - [ ] `test_self_reference_prevention` — task cannot depend on itself
   - [ ] `test_uniqueness_validation` — duplicate edges rejected
   - [ ] `test_direct_cycle_detection` — A→B→A rejected
   - [ ] `test_indirect_cycle_detection` — A→B→C→A rejected
   - [ ] `test_valid_dag_accepted` — linear chain A→B→C accepted
   - [ ] `test_associations` — belongs_to task, depends_on_task

### 3.2. Integration Tests (2 files, 10+ test cases)

8. **SchemaIntegrationTest** [ ]
   - [ ] `test_full_object_graph` — create Project → AgentTeam → TeamMembership → WorkflowRun → WorkflowEvent + Task → TaskDependency
   - [ ] `test_associations_navigable` — all has_many/belongs_to relationships work
   - [ ] `test_to_profile_real_config` — use actual .aider-desk config.json to verify mapping

9. **TaskDependencyGraphTest** [ ]
   - [ ] `test_5_node_dag` — build 5-task DAG with various dependency patterns
   - [ ] `test_ready_scope` — returns tasks with all dependencies completed
   - [ ] `test_status_propagation` — mark tasks completed, verify dependents become ready
   - [ ] `test_cycle_rejection` — attempt to create cycle, verify validation error

---

## 4. Error Path Matrix

| Error Scenario | Validation / Guard | User Message | Status / Result |
|----------------|-------------------|--------------|-----------------|
| Project path duplicate | `uniqueness: true` | Validation failed: Path has already been taken | Record not saved |
| TeamMembership config missing required keys | `validate :config_has_required_keys` | Config missing required keys: id, name | Validation error |
| Task score outside 1-4 range | `inclusion: { in: 1..4 }` | Files score is not included in the list | Validation error |
| TaskDependency self-reference | `validate :no_self_reference` | Depends on task cannot depend on itself | Validation error |
| TaskDependency duplicate edge | `uniqueness: { scope: :task_id }` | Depends on task has already been taken | Validation error |
| TaskDependency creates cycle | `validate :no_cycles` | Would create a dependency cycle | Validation error |
| WorkflowRun missing prompt | `presence: true` | Prompt can't be blank | Validation error |
| TeamMembership#to_profile with malformed config | `rescue StandardError` in conversion | Returns nil/default values, logs error | Graceful degradation |
| JSONB config malformed JSON | ActiveRecord JSONB column | ActiveRecord::SerializationTypeMismatch | DB-level error |

---

## 5. Migration Steps

### 5.1. Migration Order & FK Handling

1. **Projects** — independent
2. **AgentTeams** — references projects (optional FK)
3. **TeamMemberships** — references agent_teams
4. **WorkflowRuns** — references projects, team_memberships
5. **WorkflowEvents** — references workflow_runs
6. **Tasks** — references projects, workflow_runs, team_memberships, execution_run (FK to workflow_runs)
7. **Add task_id to workflow_runs** — circular FK handled after tasks table exists
8. **TaskDependencies** — references tasks twice

**Circular FK Resolution:** The circular reference between `workflow_runs.task_id` and `tasks.execution_run_id` is resolved by:
- Creating `tasks` table with `execution_run_id` FK to `workflow_runs`
- Adding `task_id` column to `workflow_runs` in a separate migration **after** `tasks` table exists
- Both FKs are optional (`null: true`) to allow creation order flexibility

### 5.2. Reversibility

All 8 migrations must be reversible:
- `create_table` ↔ `drop_table`
- `add_reference` ↔ `remove_reference`  
- `add_index` ↔ `remove_index`
- JSONB columns default to `{}` not `nil`

### 5.3. Database-Level Constraints

- All FK constraints at database level (`foreign_key: true`)
- All NOT NULL constraints match model validations
- Unique indexes enforce uniqueness at DB level

---

## 6. Pre-QA Checklist Acknowledgment

**Before requesting QA scoring, the following mandatory Pre-QA checks must pass:**

- [ ] **Rubocop offenses**: Zero offenses in new/changed files
- [ ] **Frozen string literal**: All Ruby files include `# frozen_string_literal: true`
- [ ] **Test coverage**: All new code has corresponding tests
- [ ] **Test execution**: `rails test test/models/ test/integration/` passes with zero failures/errors
- [ ] **Migration rollback**: `rails db:rollback STEP=8` reverses all 8 migrations cleanly
- [ ] **Migration re-apply**: `rails db:migrate` re-applies cleanly
- [ ] **Factory validity**: All 7 factories create valid records
- [ ] **Console validation**: Manual verification in Rails console succeeds

**Pre-QA Checklist Location:** `knowledge_base/epics/wip/epic-1-orchestration-foundation/feedback/pre-qa-checklist-PRD-1-01.md`

---

## 7. Acceptance Criteria (from PRD)

- [ ] **AC1**: All 8 migrations run successfully (`rails db:migrate`) and are reversible (`rails db:rollback STEP=8`)
- [ ] **AC2**: Project model — name/path required, path unique, has_many teams and runs
- [ ] **AC3**: AgentTeam model — name required, unique scoped to project, has_many memberships
- [ ] **AC4**: TeamMembership model — config JSONB validated for required keys, `to_profile` returns valid `AgentDesk::Agent::Profile`
- [ ] **AC5**: WorkflowRun model — status enum with 9 values, all associations correct, scopes work
- [ ] **AC6**: WorkflowEvent model — composite index on (workflow_run_id, event_type), chronological scope
- [ ] **AC7**: Task model — status enum with 6 values, score auto-computation, `dispatchable?` checks dependencies, `over_threshold?` flags score > 6
- [ ] **AC8**: TaskDependency model — no self-references, no duplicates, **DAG cycle detection prevents cycles**
- [ ] **AC9**: Task `ready` scope returns only tasks where all dependencies are completed
- [ ] **AC10**: All 7 FactoryBot factories produce valid records
- [ ] **AC11**: `TeamMembership#to_profile` correctly maps a real `.aider-desk` config.json fixture to a Profile with provider, model, max_iterations, tool_approvals, custom_instructions, use_* flags
- [ ] **AC12**: `rails test` — zero failures, zero errors, zero skips for all schema tests
- [ ] **AC13**: All foreign key constraints exist at database level

---

## 8. Implementation Notes

### 8.1. Critical Path Items

1. **`TeamMembership#to_profile`** — Must correctly map all 20+ fields from JSONB config to `AgentDesk::Agent::Profile`. Test with real `.aider-desk` config.json fixtures.
2. **DAG Cycle Detection** — Must prevent cycles via BFS/DFS validation. Performance acceptable for 5-20 node graphs.
3. **Circular FK Handling** — `workflow_runs.task_id` ↔ `tasks.execution_run_id` resolved via migration order and optional FKs.

### 8.2. Testing Strategy

- **Test-first**: Write tests before implementation
- **Fixture-based**: Use actual `.aider-desk` configs for `to_profile` validation
- **DAG validation**: Test direct and indirect cycles, valid DAGs accepted
- **Factory validity**: All factories must pass `FactoryBot.lint`

### 8.3. Rails 8.1 Conventions

- Use string-backed enums for readability
- JSONB columns default to `{}` not `nil`
- Database-level constraints match model validations
- All associations have `dependent` options specified

---

## 9. Manual Verification Steps

1. Run migrations:
   ```bash
   rails db:migrate
   ```

2. Verify reversibility:
   ```bash
   rails db:rollback STEP=8
   rails db:migrate
   ```

3. Rails console validation:
   ```ruby
   # Create full object graph
   project = Project.create!(name: "Legion", path: "/tmp/test")
   team = AgentTeam.create!(name: "ROR", project: project)
   tm = team.team_memberships.create!(config: { "id" => "test", "name" => "Test", "provider" => "openai", "model" => "gpt-4" })
   profile = tm.to_profile
   # Verify profile is AgentDesk::Agent::Profile with correct attributes
   ```

4. Run tests:
   ```bash
   rails test test/models/ test/integration/
   ```

---

## 10. Next Steps After Plan Approval

1. **Architect Review** — Submit this plan to `architect` subagent
2. **Plan Amendments** — Incorporate architect feedback
3. **Implementation** — Create all files per this plan
4. **Pre-QA Checklist** — Complete all mandatory checks
5. **QA Scoring** — Submit to `qa` agent for quality score ≥ 90
6. **Debug if needed** — If score < 90, delegate to `ror-debug` agent

---

**Plan Status:** PLAN-APPROVED (with mandatory amendments — re-read plan before coding)
**Estimated Effort:** 1.5 weeks  
**Risk Level:** Medium (complex DAG, circular FK, critical `to_profile` conversion)

---

## Architect Review & Amendments

**Reviewer:** Architect Agent (Claude Opus)
**Date:** 2026-03-06
**Verdict:** APPROVED (with mandatory amendments applied below)

The plan is structurally sound, well-organized, and covers all four mandatory sections (numbered test checklist, error path matrix, migration steps, pre-QA acknowledgment). The circular FK resolution strategy is correct, DAG cycle detection via BFS is acceptable, and the `to_profile` fixture-based testing approach is exactly right.

However, **seven correctness issues** were found — three are blockers that would cause runtime failures. All amendments have been applied inline in the sections that follow. Re-read each amended section before writing code.

---

### Amendments Made (tracked for retrospective)

#### BLOCKER 1 — [ADDED] `factory_bot_rails` gem is not in Gemfile

The plan defines 7 FactoryBot factories but `factory_bot_rails` is not present in the Gemfile or Gemfile.lock. The test suite uses Minitest with `fixtures :all` in `test/test_helper.rb`. FactoryBot will fail silently (undefined constant `FactoryBot`).

**Required action:** Add `factory_bot_rails` to the Gemfile `:test` group and configure `test/test_helper.rb` to include FactoryBot:

```ruby
# Gemfile (in group :test)
gem "factory_bot_rails"
```

```ruby
# test/test_helper.rb — add after existing require lines:
require "factory_bot_rails"

module ActiveSupport
  class TestCase
    include FactoryBot::Syntax::Methods
    # ...
  end
end
```

Also note: `fixtures :all` in `test/test_helper.rb` conflicts with FactoryBot in some setups. The plan must explicitly state whether Minitest fixtures or FactoryBot factories are the test data strategy. **Decision: Use FactoryBot only (no `.yml` fixtures for these models).** Remove `fixtures :all` from the base TestCase or it will attempt to load non-existent fixture files for every test.

The test checklist item `test/models/X_test.rb` — `test_valid_X` — must use `build(:factory_name)` / `create(:factory_name)` syntax, not `FactoryBot.build`.

---

#### BLOCKER 2 — [CHANGED] `TeamMembership#to_profile` has 8 missing Profile fields and wrong subagent mapping

After comparing the plan's `to_profile` against the actual `AgentDesk::Agent::Profile` class and the live `.aider-desk/agents/ror-rails-legion/config.json`, the following gaps were found:

**Missing Profile attributes not mapped in the plan:**
1. `reasoning_effort` — JSON key `"reasoningEffort"`, default `AgentDesk::ReasoningEffort::NONE`
2. `max_tokens` — JSON key `"maxTokens"`, default `nil`
3. `temperature` — JSON key `"temperature"`, default `nil`
4. `min_time_between_tool_calls` — JSON key `"minTimeBetweenToolCalls"`, default `0`
5. `enabled_servers` — JSON key `"enabledServers"`, default `[]`
6. `include_context_files` — JSON key `"includeContextFiles"`, default `false`
7. `include_repo_map` — JSON key `"includeRepoMap"`, default `false`
8. `compaction_strategy` — JSON key `"compactionStrategy"`, default `:tiered` (stored as symbol, JSON as string)
9. `context_window` — JSON key `"contextWindow"`, default `128_000`
10. `cost_budget` — JSON key `"costBudget"`, default `0.0`
11. `context_compacting_threshold` — JSON key `"contextCompactingThreshold"`, default `0.7`

**Incorrect subagent mapping.** The plan's `build_subagent_config` returns a raw hash. The actual gem uses `AgentDesk::SubagentConfig` (a `Data.define` class) with these keyword arguments:
- `enabled:`, `system_prompt:`, `invocation_mode:`, `color:`, `description:`, `context_memory:`

The live config.json uses camelCase: `"systemPrompt"`, `"invocationMode"`, `"contextMemory"`. The plan's `build_subagent_config` does **not** perform camelCase → snake_case conversion, so `SubagentConfig.new(**subagent_data)` will fail with `ArgumentError: unknown keyword: systemPrompt`.

**The `to_profile` method must be rewritten** to handle all fields and correct SubagentConfig construction. The corrected implementation pattern (for guidance — Lead writes the actual code):

```ruby
def to_profile
  AgentDesk::Agent::Profile.new(
    id:                           config["id"],
    name:                         config["name"],
    provider:                     config["provider"],
    model:                         config["model"],
    reasoning_effort:             config["reasoningEffort"] || AgentDesk::ReasoningEffort::NONE,
    max_iterations:               config["maxIterations"] || 250,
    max_tokens:                   config.fetch("maxTokens", nil),
    temperature:                  config.fetch("temperature", nil),
    min_time_between_tool_calls:  config["minTimeBetweenToolCalls"] || 0,
    enabled_servers:              config["enabledServers"] || [],
    include_context_files:        config["includeContextFiles"] != false && config["includeContextFiles"] || false,
    include_repo_map:             config["includeRepoMap"] || false,
    use_power_tools:              config["usePowerTools"] != false,
    use_aider_tools:              config["useAiderTools"] != false,
    use_todo_tools:               config["useTodoTools"] != false,
    use_memory_tools:             config["useMemoryTools"] != false,
    use_skills_tools:             config["useSkillsTools"] != false,
    use_subagents:                config["useSubagents"] != false,
    use_task_tools:               config["useTaskTools"] == true,
    custom_instructions:          config["customInstructions"] || "",
    tool_approvals:               normalize_tool_approvals(config["toolApprovals"]),
    tool_settings:                normalize_tool_settings(config["toolSettings"]),
    subagent_config:              build_subagent_config(config["subagent"]),
    compaction_strategy:          (config["compactionStrategy"] || "tiered").to_sym,
    context_window:               config["contextWindow"] || 128_000,
    cost_budget:                  config["costBudget"] || 0.0,
    context_compacting_threshold: config["contextCompactingThreshold"] || 0.7
  )
end
```

Note `config["includeContextFiles"]` and similar boolean fields: the live config has `false` as an explicit value, not a missing key — use `config.fetch("key", nil) != false` for presence-first booleans, or simply `config["key"] || false` if the default should be false.

**`build_subagent_config` must be corrected:**
```ruby
def build_subagent_config(subagent_data)
  return nil unless subagent_data.is_a?(Hash) && subagent_data["enabled"]
  AgentDesk::SubagentConfig.new(
    enabled:         subagent_data["enabled"],
    system_prompt:   subagent_data["systemPrompt"] || "",
    invocation_mode: subagent_data["invocationMode"] || AgentDesk::InvocationMode::ON_DEMAND,
    color:           subagent_data["color"] || "#3368a8",
    description:     subagent_data["description"] || "",
    context_memory:  subagent_data["contextMemory"] || AgentDesk::ContextMemoryMode::OFF
  )
end
```

**`normalize_tool_settings` is missing from the plan.** `tool_settings` in the live config is a nested hash (`{ "power---bash" => { "allowedPattern" => "...", "deniedPattern" => "..." } }`). The gem's `Profile.default_tool_settings` uses `"allowed_pattern"` (snake_case) as the key. The live config.json uses `"allowedPattern"` (camelCase). The `normalize_tool_settings` method must convert inner keys from camelCase to snake_case to match the gem's expectation. Add:

```ruby
def normalize_tool_settings(settings)
  return {} unless settings.is_a?(Hash)
  settings.transform_keys(&:to_s).transform_values do |tool_opts|
    next tool_opts unless tool_opts.is_a?(Hash)
    tool_opts.transform_keys { |k| k.to_s.gsub(/([A-Z])/, '_\1').downcase }
  end
end
```

**Test checklist amendment for `to_profile`:** Items 15 and 16 in the checklist are correct in principle but must be expanded. Add:
- `test_to_profile_includes_reasoning_effort` — verify `reasoning_effort` maps correctly
- `test_to_profile_subagent_config_is_subagent_config_instance` — verify result is `AgentDesk::SubagentConfig`, not a Hash
- `test_to_profile_tool_settings_snake_case_keys` — verify inner tool_settings keys are snake_case after conversion
- `test_to_profile_compaction_strategy_is_symbol` — verify `compaction_strategy` is `:tiered` (Symbol), not `"tiered"` (String)

These 4 tests are added to checklist item 3 (TeamMembershipTest) and are MUST-IMPLEMENT.

---

#### BLOCKER 3 — [CHANGED] `Task#ready?` instance method has infinite recursion

In `app/models/task.rb`, the `ready?` method calls `ready?` on itself:

```ruby
# BROKEN — self-recursive:
def ready?
  (pending? || ready?) && dependencies.all?(&:completed?)
end
```

`ready?` is both the custom method name AND a method generated by `enum :status` (Rails generates `pending?`, `ready?`, `running?`, etc. predicate methods for each enum value). The second `ready?` call invokes the enum predicate (checks `status == "ready"`), which is correct — but the method NAME `ready?` shadows the enum predicate with itself, causing infinite recursion.

**Corrected method name:**

```ruby
def all_dependencies_completed?
  dependencies.all?(&:completed?)
end
```

Or if the instance method name `ready?` is intentionally meant to check dispatch eligibility (broader than the status enum value), it must not conflict. Two options:

**Option A (rename to avoid conflict):**
```ruby
def dispatchable?
  (pending? || status == "ready") && dependencies.all?(&:completed?)
end
```

**Option B (use status enum predicate directly, different name):**
```ruby
def dependencies_satisfied?
  dependencies.all?(&:completed?)
end
```

The PRD specifies `#ready?` as the method name. The plan must choose a non-conflicting implementation. **Recommended: rename the custom method to `dispatchable?`** since `ready?` is correctly reserved for the enum status predicate. Update the PRD acceptance criteria AC7 accordingly, and update all test checklist items that reference `ready?`.

Update test checklist item 6.7 to: `test_dispatchable_method` — returns true when status is pending/ready AND all dependencies completed.

---

#### ISSUE 4 — [CHANGED] Task `ready` scope SQL references non-existent alias `tasks_depends_on`

The `ready` scope uses a raw SQL fragment:

```ruby
scope :ready, -> {
  where(status: [:pending, :ready])
    .left_joins(:task_dependencies)
    .group(:id)
    .having("COUNT(CASE WHEN tasks_depends_on.status != 'completed' THEN 1 END) = 0")
}
```

The `left_joins(:task_dependencies)` joins to the `task_dependencies` table, not to `tasks` (the `depends_on_task`). The `tasks_depends_on` alias doesn't exist. To check whether the dependency task is completed, you need to join through to the actual task being depended on.

**Corrected scope using explicit JOIN:**

```ruby
scope :ready, -> {
  where(status: [:pending, :ready])
    .left_joins(:dependencies)
    .group("tasks.id")
    .having("COUNT(CASE WHEN dependencies_tasks.status != 'completed' THEN 1 END) = 0")
}
```

`left_joins(:dependencies)` uses the `has_many :dependencies, through: :task_dependencies, source: :depends_on_task` association, which Rails aliases as `dependencies_tasks` in the SQL. Alternatively, write the explicit SQL join to control the alias:

```ruby
scope :ready, -> {
  where(status: [:pending, :ready])
    .joins(
      "LEFT JOIN task_dependencies td ON td.task_id = tasks.id
       LEFT JOIN tasks dep_tasks ON dep_tasks.id = td.depends_on_task_id"
    )
    .group("tasks.id")
    .having("COUNT(CASE WHEN dep_tasks.status != 'completed' THEN 1 END) = 0")
}
```

The integration test `test_ready_scope` must verify both tasks-with-zero-deps (always ready) and tasks-where-all-deps-are-completed (ready) vs tasks-where-at-least-one-dep-is-not-completed (not ready). This test will catch incorrect SQL.

---

#### ISSUE 5 — [CHANGED] Migration rollback count discrepancy in AC1 and Pre-QA checklist

There are **8 migrations** (M001–M007 plus M006b `add_task_reference_to_workflow_runs`), but:
- AC1 says `rails db:rollback STEP=7`
- Pre-QA checklist says `rails db:rollback STEP=8`

These must be consistent. The correct count is **8 migrations**. Update AC1 to:
> AC1: All 8 migrations run successfully (`rails db:migrate`) and are reversible (`rails db:rollback STEP=8`)

Also confirm migration file naming: `M006b` is an implicit naming — clarify that this is a separate migration file with its own timestamp, not an appendix to M006. The Lead should name it `[timestamp]_add_task_reference_to_workflow_runs.rb` with timestamp strictly after M006's timestamp.

---

#### ISSUE 6 — [ADDED] Missing `null: false` constraints on critical migration columns

Several columns that have model-level presence validations are missing `null: false` at the DB level (violating Non-Functional Requirement: "Database-level NOT NULL constraints matching model validations"):

- `M003 team_memberships` — `config` should be `null: false, default: {}` (already correct for default, but `null: false` should be explicit on the column itself via `t.jsonb :config, null: false, default: {}`)
- `M006 tasks` — `task_type` has presence validation but no `null: false` in migration. Add `null: false` to `task_type` column.
- `M004 workflow_runs` — `status` column should have `null: false` to match `validates :status, presence: true`. The migration shows `t.string :status, null: false, default: "queued"` — this is correct. Verify it is actually present.

Add the following checks to the Pre-QA checklist (section 6, item i):
```
i) Verify DB schema matches model validations: for every `validates :X, presence: true`, 
   confirm db/schema.rb shows `null: false` on column X.
```

---

#### ISSUE 7 — [ADDED] Error Path Matrix missing `to_profile` error handling and test

The Error Path Matrix (Section 4) states: "TeamMembership#to_profile with malformed config → Returns nil/default values, logs error | Graceful degradation." However:

1. There is no `rescue` block in the plan's `to_profile` implementation
2. There is no test for this error path in the numbered checklist
3. The proposed behavior (return nil) is dangerous — callers in PRD-1-04 would call `profile.id` on nil and crash

**Decision:** `to_profile` should **raise** a descriptive exception on malformed config rather than silently returning nil. This matches the gem's own `load_profile` behavior (which returns nil at the loader level but raises `ArgumentError` from the Profile constructor for invalid attributes).

**Recommended approach:** Add a private `validate_config_for_profile!` guard before Profile construction that raises `ArgumentError` with a descriptive message if required keys are absent. The existing `validates :config_has_required_keys` prevents invalid configs from being saved, so `to_profile` should be able to assume valid config — but add a guard anyway for defensive programming.

Update the Error Path Matrix row to: "TeamMembership#to_profile with missing required config key → `ArgumentError` raised | Caller handles or re-raises"

Add to numbered test checklist item 3: `test_to_profile_raises_on_missing_required_key` — MUST-IMPLEMENT.

---

### Summary of Mandatory Changes Before Coding

| # | Category | Action Required | Risk if Skipped |
|---|----------|----------------|-----------------|
| 1 | Gemfile | Add `factory_bot_rails` + configure test_helper.rb | FactoryBot undefined — all factory tests crash |
| 2 | `to_profile` | Map all 11 missing Profile fields + fix SubagentConfig + add normalize_tool_settings | Profile construction incomplete; CLI dispatch fails with wrong model |
| 3 | `Task#ready?` | Rename to `dispatchable?` or fix infinite recursion with enum predicate | Stack overflow on any `ready?` call |
| 4 | `Task.ready` scope | Fix SQL alias `tasks_depends_on` → correct join | `ready` scope always returns all pending tasks |
| 5 | AC1 / Pre-QA | Change rollback step count from 7 to 8 (both places) | Incorrect manual verification steps |
| 6 | Migrations | Add `null: false` to `task_type` column in M006 | DB/model constraint mismatch |
| 7 | Error Path Matrix | Raise `ArgumentError` in `to_profile` on bad config | Silent failure → nil profile → crash at CLI dispatch |

---

### Items Requiring Lead Attention (Not Blocking Approval)

- **DAG performance note:** The BFS cycle detection iterates over `TaskDependency.where(task_id: current_id).pluck(:depends_on_task_id)` — this fires one DB query per graph node. For 5-20 nodes this is acceptable (confirmed by Epic spec). No change needed, but note this in a code comment for Epic 2 awareness.

- **WorkflowRun `for_team` scope:** The scope joins `team_memberships` but the join condition `where(team_memberships: { agent_team: team })` passes an `AgentTeam` object. Verify that Rails correctly resolves this to `WHERE team_memberships.agent_team_id = ?`. If the scope receives a team ID instead of an object, it will silently fail. Add a test that passes an actual `AgentTeam` object.

- **`parallel_eligible?` in Task model:** This is defined but not fully implemented (`dependencies.empty? || dependencies.all?(&:completed?)`). This is essentially the same logic as the corrected `dispatchable?` method minus the status check. This is intentional per the PRD (tasks with zero unfinished dependencies can be dispatched in parallel). Clarify in code comments that this method is for Epic 2 parallelism detection, distinct from `dispatchable?` which checks dispatch readiness for Epic 1.

- **Task `pending` and `completed` scopes shadow enum predicates:** `scope :pending, -> { where(status: :pending) }` and `scope :completed, -> { where(status: :completed) }` will shadow the ActiveRecord enum class methods `.pending` and `.completed` (which Rails generates automatically). This is redundant but not harmful — however, if you define them explicitly, they must match the enum backing values exactly. Consider removing these two scopes and using the Rails-generated enum scopes instead.

PLAN-APPROVED