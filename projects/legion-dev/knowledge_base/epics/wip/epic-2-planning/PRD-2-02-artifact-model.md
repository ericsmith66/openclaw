# PRD 2-02: Artifact Model & Structured Output

**Epic:** [Epic 2 — WorkflowEngine & Quality Gates](0000-epic.md)

## Key Decisions

- D-3: Artifact model early in PRD sequence (now 2-02) — Eliminates provisional storage. Score command writes real Artifacts from day one.
- D-5: **ConductorDecision model for reasoning audit trail** — Every transition records *why* — reasoning text, input snapshot, tool called, duration, tokens, cost.
- D-11: **WorkflowExecution separate from WorkflowRun** — WorkflowRun = one agent dispatch. WorkflowExecution = one implement cycle.
- D-15: **Hard phase enum on WorkflowExecution** — DB always knows exactly where the workflow is.
- D-21: ConductorDecision includes `duration_ms` (integer), `tokens_used` (integer), `estimated_cost` (decimal) for performance and cost observability.
- D-22: `architect_review` is a distinct `artifact_type` enum value, separate from `score_report`.
- D-23: WorkflowExecution stores `prd_snapshot` (text, full content) and `prd_content_hash` (string, SHA-256) at creation time.
- D-29: ArchitectGate in automated loop between decompose and code. New `architect_reviewing` phase. New `dispatch_architect_review` tool.
- D-30: Two distinct retry limits: `WorkflowExecution.attempt` (max 3, CODE→QA→RETRY cycles) + `Task.retry_count` (max configurable per-task).
- D-34: ConductorJob idempotency via `conductor_locked_at` datetime column on WorkflowExecution.
- D-36: Artifact version via `MAX(version) + 1` in transaction with retry on unique constraint violation.
**Log Requirements**
- Create/update task log under `knowledge_base/task-logs/`

---

### Overview

Epic 1 stores all agent output as unstructured text in `WorkflowRun.result`. There's no way to distinguish a decomposition plan from a code output from a QA score report. Querying "show me all score reports for this execution" requires parsing text.

PRD 2-02 introduces the Artifact model — typed, versioned, linked output records. Every phase of the workflow produces Artifacts: plans, code outputs, score reports, architect reviews, retry contexts, and retrospective reports. Artifacts have a self-referential parent chain (retry artifacts link to the originals they're fixing), version tracking per type within an execution, and an optional score field for scoring artifacts.

This is the data foundation that the Score Command (2-03), QualityGate (2-07), and Conductor (2-06) all build on.

---

### Requirements

#### Functional

- FR-1: Create `artifacts` table with all fields from the Data Model section (see epic overview)
- FR-2: Create `Artifact` model with validations: `artifact_type` required, `workflow_run_id` required, `content` required
- FR-3: Implement `artifact_type` enum with values: `plan`, `code_output`, `score_report`, `architect_review`, `review_feedback`, `retry_context`, `retrospective_report` (D-22)
- FR-4: Auto-increment `version` per `(workflow_execution_id, artifact_type)` on creation. Version computed as `Artifact.where(workflow_execution_id: x, artifact_type: t).maximum(:version).to_i + 1` inside `ActiveRecord::Base.transaction`. On `ActiveRecord::RecordNotUnique`: retry once (D-36).
- FR-5: Self-referential `parent_artifact_id` FK for retry chains — `belongs_to :parent_artifact, optional: true`
- FR-6: Association: `belongs_to :workflow_run`, `belongs_to :workflow_execution, optional: true`
- FR-7: Scopes: `Artifact.score_reports`, `Artifact.architect_reviews`, `Artifact.plans`, `Artifact.retrospective_reports`, `Artifact.for_execution(execution_id)`
- FR-8: `metadata` JSONB field for additional context (model used, token count, duration, gate threshold)
- FR-9: Create `workflow_executions` table with all fields from the Data Model section (including `prd_snapshot`, `prd_content_hash`, `decomposition_attempt`, `task_retry_limit`, `conductor_locked_at`, D-23, D-29, D-30, D-34)
- FR-10: Create `WorkflowExecution` model with `phase` enum, `status` enum, validations, and associations
- FR-11: Association: `WorkflowExecution has_many :workflow_runs`, `has_many :artifacts`, `has_many :conductor_decisions`
- FR-12: Add `workflow_execution_id` FK to `workflow_runs` table (nullable)
- FR-13: Add `phase` string column to `workflow_runs` table (nullable)
- FR-14: Create `conductor_decisions` table with all fields (including `duration_ms`, `tokens_used`, `estimated_cost`, D-21)
- FR-15: Create `ConductorDecision` model with validations and associations
- FR-16: Indexes per Data Model section on all three new tables

#### Non-Functional

- NF-1: Artifact creation must be atomic (wrapped in transaction if creating with parent references)
- NF-2: Version auto-increment must be race-condition safe (use database-level sequencing or `with_lock`)
- NF-3: `metadata` JSONB queries must be indexed if used in frequent queries

#### Rails / Implementation Notes

- **Migrations**: 3 new tables (`workflow_executions`, `artifacts`, `conductor_decisions`). 2 alterations (add `workflow_execution_id` and `phase` to `workflow_runs`).
- **Models**: `app/models/workflow_execution.rb`, `app/models/artifact.rb`, `app/models/conductor_decision.rb`
- **Existing model changes**: `app/models/workflow_run.rb` (new association + phase field), `app/models/task.rb` (add `workflow_execution_id` FK if not done in 2-01)

---

### Error Scenarios & Fallbacks

- **Duplicate artifact version** → Race condition on concurrent artifact creation for same (execution, type). Mitigate with `UNIQUE INDEX (workflow_execution_id, artifact_type, version)` and retry on conflict.
- **Parent artifact not found** → Validation error if `parent_artifact_id` references non-existent record. FK constraint enforces this.
- **WorkflowExecution created without PRD file** → `prd_snapshot` and `prd_content_hash` are computed from `prd_path`. If file doesn't exist, raise `Legion::PrdNotFoundError` at execution creation time (fail fast).
- **Invalid phase transition** → No state machine enforcement in this PRD (that's the Conductor's job in 2-06). Model allows any phase value from the enum.

---

### Architectural Context

The Artifact model replaces the unstructured `WorkflowRun.result` text with typed, queryable output records. This is a **pure data model** with no behavioral dependencies on the Conductor or WorkflowEngine — it only needs foreign key targets (WorkflowRun from Epic 1, WorkflowExecution created in this same PRD).

WorkflowExecution is created here as the table + model with validations and associations. The behavioral logic (creating executions, transitioning phases) is implemented in PRD 2-06 (WorkflowEngine/ConductorService). This PRD creates the schema and model layer only.

ConductorDecision is created here as the table + model. Behavioral logic (creating decisions from Conductor tool calls) is in PRD 2-06.

**Why all three models in one PRD:** They form a tight data cluster — WorkflowExecution → Artifacts + ConductorDecisions. Splitting them would create FK dependency issues.

---

### Acceptance Criteria

- [ ] AC-1: `Artifact.create!(workflow_run: run, artifact_type: :score_report, content: "Score: 87/100", score: 87)` succeeds and persists
- [ ] AC-2: Given two artifacts of type `score_report` for the same execution, versions are 1 and 2 respectively (auto-incremented)
- [ ] AC-3: `Artifact.score_reports` returns only artifacts with `artifact_type: :score_report`
- [ ] AC-4: `Artifact.architect_reviews` returns only artifacts with `artifact_type: :architect_review` (D-22)
- [ ] AC-5: Given an artifact with `parent_artifact_id` set, `artifact.parent_artifact` returns the parent; `parent.child_artifacts` returns the child
- [ ] AC-6: `WorkflowExecution.create!(project: p, prd_path: "/path/to/prd.md", phase: :decomposing, status: :running)` succeeds. `prd_snapshot` and `prd_content_hash` are populated from the file.
- [ ] AC-7: WorkflowExecution `phase` enum includes all 9 values: `decomposing`, `architect_reviewing`, `coding`, `scoring`, `retrying`, `retrospective`, `completed`, `failed`, `escalated`
- [ ] AC-8: ConductorDecision has `duration_ms`, `tokens_used`, `estimated_cost` fields (D-21) — all nullable
- [ ] AC-9: `execution.artifacts.where(artifact_type: :plan)` returns plan artifacts for that execution
- [ ] AC-10: `execution.conductor_decisions.order(:created_at)` returns chronological decision trail
- [ ] AC-11: WorkflowExecution stores `prd_snapshot` (full file content) and `prd_content_hash` (SHA-256) (D-23)
- [ ] AC-12: WorkflowExecution has `decomposition_attempt` (default 0) and `task_retry_limit` (default 3) fields (D-29, D-30)
- [ ] AC-13: All indexes from Data Model section exist (verified via `db:migrate` and schema inspection)

---

### Test Cases

#### Unit (Minitest)

- `test/models/artifact_test.rb`: Validations (type required, content required), version auto-increment, scopes (score_reports, plans, architect_reviews, retrospective_reports, for_execution), parent chain (parent/child navigation), metadata JSONB storage/retrieval
- `test/models/workflow_execution_test.rb`: Validations, phase enum values (all 9), status enum, associations (has_many runs, artifacts, conductor_decisions), prd_snapshot population, prd_content_hash computation, decomposition_attempt default, task_retry_limit default
- `test/models/conductor_decision_test.rb`: Validations, associations, chronological ordering, duration_ms/tokens_used/estimated_cost fields

#### Integration (Minitest)

- `test/integration/artifact_versioning_test.rb`: Create 3 score_report artifacts for same execution → versions 1, 2, 3. Create plan artifact → version 1 (separate type). Concurrent creation doesn't produce duplicate versions.
- `test/integration/workflow_execution_lifecycle_test.rb`: Create execution with PRD file → verify snapshot and hash. Modify PRD file → verify hash mismatch detectable.

---

### Manual Verification

1. Open Rails console: `bin/rails console`
2. Create a project: `p = Project.first`
3. Create a WorkflowExecution: `exec = WorkflowExecution.create!(project: p, prd_path: "knowledge_base/epics/wip/epic-2-planning/0000-epic.md", phase: :decomposing, status: :running)`
4. Verify: `exec.prd_snapshot.present?` → true, `exec.prd_content_hash.present?` → true
5. Create an Artifact: `a = Artifact.create!(workflow_run: WorkflowRun.first, workflow_execution: exec, artifact_type: :plan, content: "Task list...")`
6. Verify: `a.version` → 1
7. Create second plan: `a2 = Artifact.create!(workflow_run: WorkflowRun.first, workflow_execution: exec, artifact_type: :plan, content: "Revised...")`
8. Verify: `a2.version` → 2
9. Query: `Artifact.plans.count` → 2, `Artifact.score_reports.count` → 0

**Expected:** All commands succeed. Versions auto-increment per type. Scopes filter correctly.

---

### Dependencies

- **Blocked By:** 2-01 (for Task.workflow_execution_id FK and Task timing fields)
- **Blocks:** 2-03 (Score Command needs Artifact to store scores), 2-06 (Conductor needs WorkflowExecution and ConductorDecision), 2-07 (QualityGate needs Artifact)

---

### Rollout / Deployment Notes

- **Migrations:** 3 new tables, 2 table alterations. Run `bin/rails db:migrate`.
- **No data migration needed** — these are new tables with no existing data to backfill.
- **WorkflowRun.result** remains — it's not deprecated yet. Existing commands continue to write to it. Migration to Artifacts happens as each service is updated in subsequent PRDs.


---

