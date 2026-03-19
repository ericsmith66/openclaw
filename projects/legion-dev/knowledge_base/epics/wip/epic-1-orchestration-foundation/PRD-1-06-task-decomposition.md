#### PRD-1-06: Task Decomposition — Model & CLI

**Log Requirements**
- Create/update a task log under `knowledge_base/task-logs/`.
- In the log, include detailed manual test steps and expected results.
- If asked to review: create a separate document named `PRD-1-06-task-decomposition-feedback-V{{N}}.md` in the same directory as the source document.

---

### Overview

Build the task decomposition pipeline: the `bin/legion decompose` CLI command dispatches the Architect agent to read a PRD and produce a scored, dependency-aware, test-first task list. The Architect's structured output is parsed into Task and TaskDependency records in the database.

This is where the "human is the orchestrator" meets "AI does the planning." The Architect understands code dependencies, the test-first methodology, and the atomic task scale. It produces a plan; the human reviews it; then `execute-plan` (PRD-1-07) runs it. The decomposition is the bridge between a PRD document and an executable sequence of agent dispatches.

---

### Requirements

#### Functional

**CLI Command (`bin/legion decompose`):**
```bash
bin/legion decompose --team ROR --prd path/to/PRD.md
bin/legion decompose --team ROR --prd path/to/PRD.md --dry-run
bin/legion decompose --team ROR --prd path/to/PRD.md --agent architect
```

**Arguments:**
- `--team NAME` (required): AgentTeam name
- `--prd PATH` (required): Path to the PRD markdown file to decompose
- `--agent NAME` (optional): Override which agent does the decomposition (default: "architect")
- `--dry-run` (optional): Show parsed output without saving to database
- `--project PATH` (optional): Project path override
- `--verbose` (optional): Print agent's full response (not just parsed tasks)

**Decomposition Service (`app/services/legion/decomposition_service.rb`):**

`DecompositionService.call(team_name:, prd_path:, agent_identifier: "architect", project_path:, dry_run: false)`

Process:
1. Read PRD file content
2. Find team and agent (same lookup as PRD-1-04)
3. Build decomposition prompt (see below)
4. Dispatch agent via `DispatchService.call(...)` — creates WorkflowRun for the decomposition itself
5. Extract structured output from agent's response (see output format below)
6. Parse into task list with scores and dependencies
7. Validate:
   - All dependency references point to valid task numbers in the list
   - No circular dependencies
   - Score dimensions are 1-4
   - Flag tasks with total_score > 6 (warning, not error)
8. If not dry-run: Create Task records + TaskDependency edges within a transaction
9. Return parsed task list and any warnings

**Decomposition Prompt Template:**

The prompt sent to the Architect agent includes:
- The full PRD content
- Instructions for test-first ordering
- The atomic task scale definitions
- Required output format
- Examples of good decomposition

```markdown
## Task: Decompose this PRD into atomic coding tasks

### PRD Content
<prd>
{PRD_CONTENT}
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

**Output Parser (`app/services/legion/decomposition_parser.rb`):**

`DecompositionParser.call(response_text:)`

1. Extract JSON array from agent response (may be wrapped in markdown code fences)
2. Parse each task object
3. Validate required fields: position, type, prompt, agent, files_score, concepts_score, dependencies_score, depends_on
4. Validate type is one of: `test`, `code`, `review`, `debug`
5. Validate scores are 1-4
6. Compute total_score
7. Validate dependency references (all depends_on values must reference existing positions)
8. Detect cycles in dependency graph
9. Return: `{ tasks: [...], warnings: [...], errors: [...] }`
   - Warnings: tasks with score > 6, unusual patterns
   - Errors: invalid references, cycles, missing fields (these prevent saving)

**Console Output:**
```
Decomposing: PRD-1-01 (Schema Foundation)
Agent: Architect (claude-opus-4-...)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

#   Type  Agent        Score    Deps    Status    Prompt
1   test  rails-lead   2+1+1=4  —      pending   Write tests + factory for Project model
2   test  rails-lead   2+1+1=4  —      pending   Write tests + factory for AgentTeam model
3   code  rails-lead   2+1+1=4  [1]    pending   Create Project model + migration (make pass)
4   code  rails-lead   2+1+1=4  [2]    pending   Create AgentTeam model + migration (make pass)
...

Parallel groups:
  • Tasks 1, 2 — independent (parallel-eligible)
  • Tasks 3, 4 — parallel after respective tests pass

⚠️  Warnings:
  • Task 11: score 7 > threshold 6 — consider further decomposition

Saved 12 tasks with 9 dependency edges to WorkflowRun #42
```

**Parallel Group Detection:**
- After parsing all tasks and dependencies, identify groups of tasks that can run simultaneously
- A parallel group = set of tasks where ALL members have all dependencies completed (or no dependencies)
- Display parallel groups in the console output for human review

#### Non-Functional

- Decomposition prompt must be < 4000 tokens (excluding PRD content) to leave room for the PRD and response
- Parser must be resilient to LLM output variations: extra whitespace, markdown code fences around JSON, trailing commas
- Timeout: If Architect takes > 5 minutes, abort and report
- Invalid output: If parser can't extract valid JSON, report the raw response and suggest manual task creation

#### Rails / Implementation Notes

- CLI: Add `decompose` subcommand to `bin/legion`
- Services: `app/services/legion/decomposition_service.rb`, `app/services/legion/decomposition_parser.rb`
- Prompt template: `app/services/legion/prompts/decomposition_prompt.md.erb` (ERB template for the decomposition prompt)
- The decomposition itself runs as a regular agent dispatch (creates its own WorkflowRun with status `decomposing`)
- Tasks created are associated with the decomposition WorkflowRun via `Task.workflow_run_id`
- Agent matching for task assignment: the parser maps `"rails-lead"` → TeamMembership lookup within the team

---

### Error Scenarios & Fallbacks

- PRD file not found → Exit with "File not found: #{path}"
- Architect agent returns non-JSON response → Log raw response, report "Could not parse decomposition output. Raw response saved to WorkflowRun #N result field."
- JSON valid but missing required fields → Report which tasks have errors, save valid tasks only (with `--force` flag)
- Dependency references invalid position numbers → Report error: "Task N depends on non-existent task M"
- Cycle in dependencies → Report error: "Dependency cycle detected: A → B → C → A"
- Score > 6 → Warning only (not error). Tasks are still created. Human decides whether to further decompose.
- Agent identifier for task assignment not found in team → Default to rails-lead with warning
- Empty PRD file → Exit with error: "PRD file is empty"
- Architect hits iteration limit during decomposition → WorkflowRun marked `iteration_limit`, report partial results if any

---

### Architectural Context

Decomposition sits between PRD documents (human-written plans) and Task records (machine-executable work items).

```
PRD file (markdown)
  → bin/legion decompose
    → DecompositionService
      → Reads PRD content
      → Builds decomposition prompt (with test-first instructions, atomic scale)
      → Dispatches Architect via DispatchService (full assembly — rules, skills, etc.)
      → Architect returns structured JSON output
      → DecompositionParser validates + parses
      → Creates Task + TaskDependency records
    → Console output: scored task list with dependency graph
```

**Why the Architect agent, not a rules-based parser?**
PRDs are natural language with inconsistent structure. The Architect understands code dependencies, can reason about which files will be touched, and can make judgment calls about task boundaries. Rules-based parsing would be brittle and miss the nuance. The Architect + strict output format + aggressive validation is more robust.

**Test-first ordering (Design Decision D-9):**
For each feature, the Architect produces:
1. A test task (write tests that define the contract)
2. An implementation task that depends on the test task (make the tests pass)

This gives the coding agent a tight feedback loop: run tests → red → write code → run tests → green. This is what agentic coding excels at — the iterative self-correction loop driven by tool feedback.

**Non-goals:**
- No automatic re-decomposition of high-score tasks (Epic 2)
- No learning from past decompositions
- No multi-PRD decomposition in a single run

---

### Acceptance Criteria

- [ ] AC1: `bin/legion decompose --team ROR --prd <path>` dispatches Architect and produces task list
- [ ] AC2: Tasks are created in database with correct fields (prompt, type, agent, scores, position)
- [ ] AC3: TaskDependency edges created matching Architect's dependency output
- [ ] AC4: Test tasks appear before their corresponding implementation tasks
- [ ] AC5: Implementation tasks depend on their test tasks
- [ ] AC6: Parser handles JSON wrapped in markdown code fences
- [ ] AC7: Parser validates score ranges (1-4) and dependency references
- [ ] AC8: Tasks with total_score > 6 are flagged with warning
- [ ] AC9: Parallel groups detected and displayed in console output
- [ ] AC10: `--dry-run` shows parsed output without saving to database
- [ ] AC11: Decomposition creates its own WorkflowRun (status: `decomposing`)
- [ ] AC12: Invalid Architect output → error message with raw response preserved in WorkflowRun.result
- [ ] AC13: Cycle detection prevents circular dependency creation
- [ ] AC14: `rails test` — zero failures for decomposition tests

---

### Test Cases

#### Unit (Minitest)

- `test/services/legion/decomposition_parser_test.rb`:
  - Parses valid JSON array → correct task objects
  - Handles JSON wrapped in ```json code fences
  - Handles JSON with trailing commas (lenient parsing)
  - Validates required fields — reports missing fields
  - Validates score ranges (1-4) — reports out-of-range
  - Computes total_score correctly
  - Detects invalid dependency references
  - Detects dependency cycles
  - Flags tasks with score > 6 as warnings
  - Identifies parallel groups (tasks with no/satisfied dependencies)
  - Returns errors for completely unparseable output
  - Handles empty JSON array

- `test/services/legion/decomposition_service_test.rb`:
  - Reads PRD file content
  - Builds decomposition prompt with PRD content embedded
  - Dispatches Architect via DispatchService (stub)
  - Passes agent response to parser
  - Creates Task records from parsed output
  - Creates TaskDependency records from parsed dependencies
  - Maps agent names to TeamMembership records
  - Dry-run mode: parses but does not save
  - PRD file not found → raises with message
  - Unparseable output → preserves raw response, reports error

#### Integration (Minitest)

- `test/integration/decomposition_integration_test.rb`:
  - Full decomposition with VCR-recorded Architect response
  - Verify Task records created with correct scores and dependencies
  - Verify TaskDependency edges match Architect's output
  - Verify test-first ordering: for each code task, a test task exists in its dependencies
  - Verify parallel groups detected correctly
  - Verify WorkflowRun for decomposition itself has status `completed` (or `decomposing` → `completed`)

#### System / Smoke

- Manual: Decompose a real PRD and review output (see below)

---

### Manual Verification

1. Run `bin/legion decompose --team ROR --prd knowledge_base/epics/wip/epic-1-orchestration-foundation/PRD-1-01-schema-foundation.md --verbose`
   - Expected: Architect produces task list, console shows scored tasks with dependencies
2. Run `rails console`:
   - `Task.where(workflow_run: WorkflowRun.last).count` → expected: 8-15 tasks
   - `Task.where(workflow_run: WorkflowRun.last).where(task_type: :test).count` → expected: roughly half
   - `TaskDependency.count` → expected: > 0
   - `Task.where(workflow_run: WorkflowRun.last).ready.count` → expected: >= 1 (independent test tasks)
3. Run `bin/legion decompose --team ROR --prd PRD-1-01.md --dry-run`
   - Expected: Same output but "DRY RUN — no records saved"
4. Verify test-first: For each code-type task, confirm it depends on a test-type task

**Expected:** PRD decomposed into scored, dependency-aware, test-first task list. Tasks saved to database with DAG edges. Parallel groups identified.

---

### Dependencies

- **Blocked By:** PRD-1-01 (Schema — Task/TaskDependency models), PRD-1-04 (CLI Dispatch — DispatchService for Architect)
- **Blocks:** PRD-1-07 (Plan Execution needs tasks to execute), PRD-1-08 (Validation tests decompose→execute cycle)

---

### Estimated Complexity

**High** — LLM output parsing is inherently fragile. The decomposition prompt must be carefully crafted to produce consistent structured output. The parser must be resilient to variations. Integration testing requires VCR-recorded Architect responses.

**Effort:** 1.5 weeks

### Agent Assignment

**Rails Lead** (DeepSeek Reasoner) — service implementation, parser, CLI
**Architect** (Claude Opus) — the agent that actually performs decomposition during execution
**QA** (Claude Sonnet) — verify parser handles edge cases
