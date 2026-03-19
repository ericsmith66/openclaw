#### PRD-1-01: Schema Foundation

**Log Requirements**
- Create/update a task log under `knowledge_base/task-logs/`.
- In the log, include detailed manual test steps and expected results.
- If asked to review: create a separate document named `PRD-1-01-schema-foundation-feedback-V{{N}}.md` in the same directory as the source document.

---

### Overview

Create the 7 core database models that underpin Legion's orchestration layer: Project, AgentTeam, TeamMembership, WorkflowRun, WorkflowEvent, Task, and TaskDependency. These models provide the persistence layer for agent identity (who runs), execution tracking (what happened), task decomposition (what work exists), and dependency management (what order).

This is the critical-path PRD — every subsequent PRD in Epic 1 depends on these tables existing. The schema is designed to support parallel task execution (Epic 2) from day one, even though Epic 1 dispatches sequentially.

---

### Requirements

#### Functional

**Project model:**
- Fields: `name` (string, required), `path` (string, required, unique), `project_rules` (jsonb, default `{}`)
- Validations: presence of name and path, uniqueness of path
- Associations: `has_many :agent_teams`, `has_many :workflow_runs`

**AgentTeam model:**
- Fields: `name` (string, required), `description` (text), `team_rules` (jsonb, default `{}`), `project_id` (fk, optional — teams can be reusable or project-specific)
- Validations: presence of name, uniqueness of name scoped to project_id
- Associations: `belongs_to :project, optional: true`, `has_many :team_memberships, dependent: :destroy`

**TeamMembership model:**
- Fields: `agent_team_id` (fk, required), `position` (integer, default 0), `config` (jsonb, required, default `{}`)
- The `config` JSONB stores the **full agent identity**: id, name, provider, model, maxIterations, use_* flags (usePowerTools, useSkillsTools, useTodoTools, useMemoryTools, useSubagents, useTaskTools), toolApprovals hash, toolSettings hash, customInstructions text, subagent config
- Validations: presence of agent_team_id and config, config must contain `id`, `name`, `provider`, `model` keys
- Associations: `belongs_to :agent_team`, `has_many :workflow_runs`
- Instance method: `#to_profile` — converts JSONB config to `AgentDesk::Agent::Profile` object. Maps camelCase JSON keys to snake_case Profile attributes. Returns a fully-constructed Profile suitable for the gem's Runner.
- Scope: `ordered` — orders by position ascending

**WorkflowRun model:**
- Fields: `project_id` (fk, required), `team_membership_id` (fk, required), `task_id` (fk, optional — only set when run is dispatched for a specific Task), `prompt` (text, required), `status` (enum, required, default `queued`), `iterations` (integer, default 0), `duration_ms` (integer), `result` (text), `error_message` (text), `metadata` (jsonb, default `{}`)
- Status enum values: `queued`, `running`, `completed`, `failed`, `at_risk`, `decomposing`, `handed_off`, `budget_exceeded`, `iteration_limit`
- Validations: presence of project, team_membership, prompt, status
- Associations: `belongs_to :project`, `belongs_to :team_membership`, `belongs_to :task, optional: true`, `has_many :workflow_events, dependent: :destroy`, `has_many :tasks` (decomposed tasks created by this run)
- Scopes: `by_status(status)`, `recent` (ordered by created_at desc), `for_team(team)` (joins team_memberships)

**WorkflowEvent model:**
- Fields: `workflow_run_id` (fk, required), `event_type` (string, required), `channel` (string), `agent_id` (string), `task_id` (string), `payload` (jsonb, default `{}`), `recorded_at` (datetime, required)
- Validations: presence of workflow_run, event_type, recorded_at
- Associations: `belongs_to :workflow_run`
- Index: composite on `(workflow_run_id, event_type)` for event trail queries
- Index: on `recorded_at` for time-range queries
- Scope: `by_type(type)`, `chronological` (ordered by recorded_at asc)

**Task model:**
- Fields: `project_id` (fk, required), `workflow_run_id` (fk, optional — parent workflow that created the decomposition), `team_membership_id` (fk, required — which agent should execute), `execution_run_id` (fk, optional — the WorkflowRun that actually executed this task), `position` (integer, default 0), `prompt` (text, required), `task_type` (enum: `test`, `code`, `review`, `debug`), `status` (enum, required, default `pending`), `files_score` (integer, 1-4), `concepts_score` (integer, 1-4), `dependencies_score` (integer, 1-4), `total_score` (integer, computed), `estimated_iterations` (integer), `metadata` (jsonb, default `{}`)
- Status enum values: `pending`, `ready`, `running`, `completed`, `failed`, `skipped`
- Validations: presence of project, team_membership, prompt, status. Score fields validated as 1-4 when present. `total_score` auto-computed as sum of three dimension scores before validation.
- Associations: `belongs_to :project`, `belongs_to :workflow_run, optional: true`, `belongs_to :team_membership`, `belongs_to :execution_run, class_name: "WorkflowRun", optional: true`, `has_many :task_dependencies, dependent: :destroy`, `has_many :dependencies, through: :task_dependencies, source: :depends_on_task`, `has_many :inverse_task_dependencies, class_name: "TaskDependency", foreign_key: :depends_on_task_id, dependent: :destroy`, `has_many :dependents, through: :inverse_task_dependencies, source: :task`
- Scopes: `ready` (status pending + all dependencies completed), `pending`, `completed`, `by_position`
- Instance methods: `#ready?` (all dependencies completed?), `#over_threshold?` (total_score > 6), `#parallel_eligible?` (no unfinished dependencies and no shared dependencies with other ready tasks)
- Callback: `before_validation :compute_total_score` — sets `total_score = files_score + concepts_score + dependencies_score` when all three are present

**TaskDependency model (join table):**
- Fields: `task_id` (fk, required — the task that is blocked), `depends_on_task_id` (fk, required — the task that must complete first)
- Validations: presence of task and depends_on_task, no self-references (`task_id != depends_on_task_id`), uniqueness of `[task_id, depends_on_task_id]`, **DAG cycle detection** (adding this edge must not create a cycle)
- Associations: `belongs_to :task`, `belongs_to :depends_on_task, class_name: "Task"`
- Index: unique composite on `(task_id, depends_on_task_id)`
- DAG cycle detection: On create/update, traverse from `depends_on_task` following its own dependencies to verify `task_id` is not reachable (DFS/BFS). Raise validation error if cycle detected. Performance is acceptable — task graphs are 5-20 nodes per PRD.

#### Non-Functional

- All migrations must be reversible
- JSONB columns must have default `{}` to avoid nil-handling throughout the codebase
- Enum columns use Rails 7+ `enum` syntax with string backing (not integer) for readability in raw SQL
- Database-level foreign key constraints on all associations
- Database-level NOT NULL constraints matching model validations
- All indexes defined in migrations (not separate migration files)

#### Rails / Implementation Notes

- Models: `app/models/project.rb`, `app/models/agent_team.rb`, `app/models/team_membership.rb`, `app/models/workflow_run.rb`, `app/models/workflow_event.rb`, `app/models/task.rb`, `app/models/task_dependency.rb`
- Migrations: One migration per model (7 total), ordered by dependency:
  1. `create_projects`
  2. `create_agent_teams` (references projects)
  3. `create_team_memberships` (references agent_teams)
  4. `create_workflow_runs` (references projects, team_memberships)
  5. `create_workflow_events` (references workflow_runs)
  6. `create_tasks` (references projects, workflow_runs, team_memberships)
  7. `create_task_dependencies` (references tasks twice)
- Note: `tasks.execution_run_id` FK to `workflow_runs` and `workflow_runs.task_id` FK to `tasks` creates a circular reference at DB level. Handle by: adding `workflow_runs.task_id` FK via a separate migration after tasks table exists, OR deferring the FK constraint. Recommended: add `task_id` column to workflow_runs in the tasks migration (migration 6) as an `add_reference` with `foreign_key: { to_table: :tasks }`.
- FactoryBot factories for all 7 models in `test/factories/`
- `TeamMembership#to_profile` should be tested against actual `.aider-desk` config.json fixtures to verify correct mapping

---

### Error Scenarios & Fallbacks

- TaskDependency cycle detected → Raise `ActiveRecord::RecordInvalid` with message "would create a dependency cycle"
- TeamMembership config missing required keys (id, name, provider, model) → Validation error, record not saved
- Score fields outside 1-4 range → Validation error on Task
- Circular FK between WorkflowRun.task_id and Task.execution_run_id → Both are optional; only set after the related record exists
- Large JSONB config on TeamMembership → No concern; agent configs are ~2KB. No indexing needed on JSONB internals in Epic 1.

---

### Architectural Context

This PRD creates the persistence layer that all other Epic 1 PRDs build upon:
- **PRD 1-02** (PostgresBus) writes to `WorkflowEvent` via `workflow_run_id`
- **PRD 1-03** (Team Import) creates `Project`, `AgentTeam`, `TeamMembership` records
- **PRD 1-04** (CLI Dispatch) creates `WorkflowRun` records and reads `TeamMembership` for assembly
- **PRD 1-06** (Decomposition) creates `Task` and `TaskDependency` records
- **PRD 1-07** (Plan Execution) reads `Task` dependency graph and updates statuses

The `TeamMembership#to_profile` method is the bridge between database storage and the `agent_desk` gem's runtime Profile object. It must correctly map all config fields — this is the single most important method in the schema layer.

The `TaskDependency` DAG is designed for Epic 2's parallel dispatch: tasks with zero unfinished dependencies are "ready" and can be dispatched simultaneously. Epic 1 dispatches them one at a time, but the data model is parallel-ready.

**Non-goals:**
- No API endpoints (CLI-only in Epic 1)
- No UI concerns
- No WorkflowEngine state machine logic

---

### Acceptance Criteria

- [ ] AC1: All 7 migrations run successfully (`rails db:migrate`) and are reversible (`rails db:rollback` × 7)
- [ ] AC2: Project model — name/path required, path unique, has_many teams and runs
- [ ] AC3: AgentTeam model — name required, unique scoped to project, has_many memberships
- [ ] AC4: TeamMembership model — config JSONB validated for required keys, `to_profile` returns valid `AgentDesk::Agent::Profile`
- [ ] AC5: WorkflowRun model — status enum with 9 values, all associations correct, scopes work
- [ ] AC6: WorkflowEvent model — composite index on (workflow_run_id, event_type), chronological scope
- [ ] AC7: Task model — status enum with 6 values, score auto-computation, `ready?` checks dependencies, `over_threshold?` flags score > 6
- [ ] AC8: TaskDependency model — no self-references, no duplicates, **DAG cycle detection prevents cycles**
- [ ] AC9: Task `ready` scope returns only tasks where all dependencies are completed
- [ ] AC10: All 7 FactoryBot factories produce valid records
- [ ] AC11: `TeamMembership#to_profile` correctly maps a real `.aider-desk` config.json fixture to a Profile with provider, model, max_iterations, tool_approvals, custom_instructions, use_* flags
- [ ] AC12: `rails test` — zero failures, zero errors, zero skips for all schema tests
- [ ] AC13: All foreign key constraints exist at database level

---

### Test Cases

#### Unit (Minitest)

- `test/models/project_test.rb`: Validations (name/path presence, path uniqueness), associations, factory validity
- `test/models/agent_team_test.rb`: Validations (name presence, scoped uniqueness), optional project association, factory validity
- `test/models/team_membership_test.rb`: Config JSONB validation (required keys), `to_profile` conversion (all fields mapped correctly), `ordered` scope, factory validity
- `test/models/workflow_run_test.rb`: Status enum values, associations, scopes (`by_status`, `recent`, `for_team`), factory validity
- `test/models/workflow_event_test.rb`: Validations, `by_type` scope, `chronological` scope, factory validity
- `test/models/task_test.rb`: Score validations (1-4 range), `compute_total_score` callback, `ready?` method, `over_threshold?` method, status enum, task_type enum, factory validity
- `test/models/task_dependency_test.rb`: Self-reference prevention, uniqueness validation, **DAG cycle detection** (direct cycle A→B→A, indirect cycle A→B→C→A, valid DAG accepted), factory validity

#### Integration (Minitest)

- `test/integration/schema_test.rb`: Create full object graph (Project → Team → Membership → WorkflowRun → Events + Tasks → Dependencies), verify all associations navigable, verify `to_profile` against real config.json fixture
- `test/integration/task_dependency_graph_test.rb`: Build a 5+ node DAG, verify `ready` scope returns correct tasks, mark tasks completed and verify new tasks become ready, attempt cycle and verify rejection

#### System / Smoke

- N/A — schema PRD has no user-facing CLI commands

---

### Manual Verification

1. Run `rails db:migrate` — expected: 7 migrations execute without error
2. Run `rails db:rollback STEP=7` — expected: all migrations reverse cleanly
3. Run `rails db:migrate` again — expected: re-applies cleanly
4. Open `rails console`:
   - `Project.create!(name: "Legion", path: "/tmp/test")` — expected: success
   - `team = AgentTeam.create!(name: "ROR", project: Project.last)` — expected: success
   - `tm = team.team_memberships.create!(config: { "id" => "test", "name" => "Test", "provider" => "openai", "model" => "gpt-4" })` — expected: success
   - `tm.to_profile` — expected: returns `AgentDesk::Agent::Profile` with correct attributes
   - `tm.update!(config: {})` — expected: validation error (missing required keys)
5. Run `rails test test/models/` — expected: all tests pass

**Expected:** All 7 models created with correct validations, associations, and indexes. DAG cycle detection working. `to_profile` conversion verified.

---

### Dependencies

- **Blocked By:** None (first PRD on critical path)
- **Blocks:** PRD-1-02, PRD-1-03, PRD-1-04, PRD-1-05, PRD-1-06, PRD-1-07, PRD-1-08

---

### Estimated Complexity

**High** — 7 models, complex associations (circular FK, DAG), JSONB validation, `to_profile` conversion with comprehensive field mapping

**Effort:** 1.5 weeks

### Agent Assignment

**Rails Lead** (DeepSeek Reasoner) — primary implementer for all models, migrations, and tests
