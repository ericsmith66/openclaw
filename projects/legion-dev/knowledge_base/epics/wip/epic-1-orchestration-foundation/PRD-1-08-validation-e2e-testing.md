#### PRD-1-08: Validation & End-to-End Testing

**Log Requirements**
- Create/update a task log under `knowledge_base/task-logs/`.
- In the log, include detailed manual test steps and expected results.
- If asked to review: create a separate document named `PRD-1-08-validation-e2e-testing-feedback-V{{N}}.md` in the same directory as the source document.

---

### Overview

Validate the complete Epic 1 platform through end-to-end testing: import → dispatch → hooks → decompose → execute-plan. This is the capstone PRD that proves the entire orchestration foundation works as an integrated system. It covers automated integration tests, scripted system tests, and manual verification scenarios.

This PRD also serves as the "acceptance test suite" for Epic 1 — every success criterion from the epic spec gets a concrete test that proves it.

---

### Requirements

#### Functional

**E2E Test Suite (`test/e2e/epic_1_validation_test.rb`):**

The following end-to-end scenarios must be verified:

**Scenario 1: Team Import Round-Trip**
- Import ROR team from `.aider-desk`
- Verify 4 agents in database with full configs
- Verify `to_profile` on each agent returns valid Profile
- Verify profile has correct provider, model, maxIterations, tool_approvals, customInstructions

**Scenario 2: Single Agent Dispatch with Full Identity**
- Dispatch Rails Lead with a simple coding prompt (VCR-recorded)
- Verify agent runs with correct model (from TeamMembership config)
- Verify system prompt contains rules content (rails-base-rules.md)
- Verify SkillLoader discovered skills (agent sees skills---activate_skill tool)
- Verify tool approvals enforced (from config)
- Verify custom instructions present in system prompt
- Verify WorkflowRun created and completed
- Verify WorkflowEvent trail complete: agent.started → tool.* → response.complete → agent.completed

**Scenario 3: Multi-Agent Dispatch**
- Dispatch each of the 4 agents sequentially with a simple prompt (VCR-recorded per agent)
- Verify each runs with its own model, rules, and identity
- Verify 4 separate WorkflowRuns created
- Verify event trails are agent-specific (agent_id matches)

**Scenario 4: Orchestrator Hook Behavior**
- Dispatch agent with very low max_iterations (3) and a complex prompt
- Verify iteration budget hook fires and records warning in metadata
- Verify WorkflowRun status reflects hook intervention (e.g., `iteration_limit`)

**Scenario 5: Event Trail Forensics**
- Run a multi-tool-call agent task (VCR-recorded)
- Query WorkflowEvents and reconstruct the full execution timeline
- Verify: event count > 0, event types include expected set, chronological ordering correct, payload contains useful data (file paths, tool names, etc.)

**Scenario 6: Decomposition → Task Creation**
- Decompose a test PRD using Architect (VCR-recorded)
- Verify Task records created with:
  - Correct task_type (test/code)
  - Valid scores (1-4 per dimension)
  - total_score computed
  - Dependencies as TaskDependency edges
- Verify test-first ordering: implementation tasks depend on test tasks
- Verify at least one parallel group exists (independent test tasks)

**Scenario 7: Plan Execution Cycle**
- Using tasks from Scenario 6, execute the plan (VCR-recorded per task)
- Verify tasks dispatched in dependency order
- Verify each task creates its own WorkflowRun
- Verify Task statuses update: pending → running → completed
- Verify Task.execution_run_id links to correct WorkflowRun

**Scenario 8: Full Cycle (Decompose → Execute)**
- Decompose a small test PRD (2-3 tasks)
- Execute the plan
- Verify all tasks completed
- Verify full event trails for each task
- This is the "happy path" that proves the complete pipeline works

**Scenario 9: Dependency Graph Correctness**
- Create a known task graph (manually, not via decomposition) with:
  - 2 independent tasks (parallel-eligible)
  - 1 task depending on both (fan-in)
  - 2 tasks depending on the fan-in (fan-out)
- Execute plan → verify correct ordering
- Verify `ready` scope returns correct tasks at each step

**Scenario 10: Error Handling & Resilience**
- Dispatch with non-existent team → verify error message and exit code
- Dispatch with non-existent agent → verify error message lists available agents
- Execute plan with a failing task → verify halt behavior
- Execute plan with `--continue-on-failure` → verify skipped dependents

**Validation Script (`bin/legion validate`):**
- Runs automated E2E tests (with VCR cassettes)
- Prints results in a clear summary format
- Exits 0 if all pass, 1 if any fail

**Test PRD for Decomposition/Execution:**
- Create a minimal test PRD: `test/fixtures/test-prd-simple.md`
- A simple PRD (e.g., "Add a Greeting model with message field") that the Architect can decompose into 3-5 tasks
- Used by Scenarios 6, 7, 8 for deterministic testing

#### Non-Functional

- All E2E tests must run offline using VCR cassettes (no live SmartProxy dependency)
- VCR cassettes stored in `test/vcr_cassettes/e2e/`
- First recording requires live SmartProxy — documented in README
- Tests must complete in < 60 seconds (VCR replay is fast)
- Test isolation: each scenario uses its own Project/Team/data (no shared state between scenarios)

#### Rails / Implementation Notes

- Test file: `test/e2e/epic_1_validation_test.rb`
- Validation script: `bin/legion validate` (thin wrapper around `rails test test/e2e/`)
- Test fixtures: `test/fixtures/test-prd-simple.md`
- VCR cassettes: `test/vcr_cassettes/e2e/` (one per scenario that hits SmartProxy)
- Helper: `test/support/e2e_helper.rb` — shared setup (import team, create project, etc.)
- VCR configuration: Match on method + URI + body for SmartProxy requests
- Each scenario should be a separate test method for independent execution

---

### Error Scenarios & Fallbacks

- VCR cassette not recorded → Clear error: "Run `RECORD_VCR=1 rails test test/e2e/` with SmartProxy running to record cassettes"
- SmartProxy response format changed → VCR cassette mismatch. Re-record cassettes.
- Agent produces different output on re-record → Expected. Scenarios should validate structure (tasks exist, events exist) not exact content.
- Test PRD produces different decomposition on re-record → Expected. Validate task count range and dependency structure, not exact prompts.

---

### Architectural Context

This PRD is the acceptance test for the entire Epic 1 platform. It validates that all 7 preceding PRDs integrate correctly:

```
PRD-1-01 (Schema) ─────────────────────────────────── Scenario 1, 9
PRD-1-02 (PostgresBus) ─────────────────────────────── Scenario 2, 5
PRD-1-03 (Team Import) ─────────────────────────────── Scenario 1
PRD-1-04 (CLI Dispatch) ────────────────────────────── Scenario 2, 3, 10
PRD-1-05 (Orchestrator Hooks) ──────────────────────── Scenario 4
PRD-1-06 (Task Decomposition) ──────────────────────── Scenario 6
PRD-1-07 (Plan Execution) ──────────────────────────── Scenario 7, 8
All PRDs ───────────────────────────────────────────── Scenario 8 (full cycle)
```

**Non-goals:**
- Not a performance benchmark (that's done ad-hoc)
- Not testing gem internals (gem has 752 tests)
- Not testing UI (no UI in Epic 1)

---

### Acceptance Criteria

- [ ] AC1: Scenario 1 passes — team import round-trip verified
- [ ] AC2: Scenario 2 passes — single agent dispatch with full identity verified
- [ ] AC3: Scenario 3 passes — multi-agent dispatch verified (4 agents, 4 distinct identities)
- [ ] AC4: Scenario 4 passes — orchestrator hooks fire on threshold breach
- [ ] AC5: Scenario 5 passes — event trail forensics: query, reconstruct, verify
- [ ] AC6: Scenario 6 passes — decomposition produces scored, dependency-aware, test-first tasks
- [ ] AC7: Scenario 7 passes — plan execution dispatches in dependency order
- [ ] AC8: Scenario 8 passes — full decompose → execute cycle completes
- [ ] AC9: Scenario 9 passes — dependency graph correctness (fan-in, fan-out, parallel groups)
- [ ] AC10: Scenario 10 passes — error handling produces correct messages and exit codes
- [ ] AC11: All tests run offline via VCR cassettes in < 60 seconds
- [ ] AC12: `bin/legion validate` exits 0 when all E2E tests pass
- [ ] AC13: Test PRD fixture exists and is usable for decomposition scenarios
- [ ] AC14: `rails test` — zero failures across entire test suite (unit + integration + E2E)

---

### Test Cases

#### Unit (Minitest)

- N/A — this PRD is entirely about integration and E2E tests

#### Integration (Minitest)

- N/A — the E2E tests ARE the integration/system tests for this PRD

#### E2E (Minitest + VCR)

- `test/e2e/epic_1_validation_test.rb`:
  - `test_scenario_1_team_import_round_trip`
  - `test_scenario_2_single_agent_full_identity`
  - `test_scenario_3_multi_agent_dispatch`
  - `test_scenario_4_orchestrator_hook_behavior`
  - `test_scenario_5_event_trail_forensics`
  - `test_scenario_6_decomposition_task_creation`
  - `test_scenario_7_plan_execution_cycle`
  - `test_scenario_8_full_decompose_execute_cycle`
  - `test_scenario_9_dependency_graph_correctness`
  - `test_scenario_10_error_handling_resilience`

---

### Manual Verification

1. Run `bin/legion validate` — expected: all 10 scenarios pass
2. Import team: `rake teams:import[~/.aider-desk]` (if not already imported)
3. Dispatch each agent manually:
   ```bash
   bin/legion execute --team ROR --agent rails-lead --prompt "List your tools" --verbose
   bin/legion execute --team ROR --agent architect --prompt "List your tools" --verbose
   bin/legion execute --team ROR --agent qa --prompt "List your tools" --verbose
   bin/legion execute --team ROR --agent debug --prompt "List your tools" --verbose
   ```
   Expected: Each agent responds, each has different model, events persisted
4. Decompose a real PRD:
   ```bash
   bin/legion decompose --team ROR --prd knowledge_base/epics/wip/epic-1-orchestration-foundation/PRD-1-01-schema-foundation.md
   ```
   Expected: Scored task list with dependencies
5. Execute the plan:
   ```bash
   bin/legion execute-plan --workflow-run <ID> --verbose
   ```
   Expected: Tasks execute in dependency order, all complete
6. Verify forensics:
   ```ruby
   # rails console
   run = WorkflowRun.last
   run.workflow_events.count          # > 0
   run.workflow_events.by_type("tool.called").count  # > 0
   Task.where(workflow_run: decompose_run).all?(&:completed?)  # true
   ```

**Expected:** Complete Epic 1 platform operational. Import → Dispatch → Hooks → Decompose → Execute-Plan — all working as an integrated system.

---

### Dependencies

- **Blocked By:** All preceding PRDs (1-01 through 1-07) — this validates the complete stack
- **Blocks:** Nothing — this is the final PRD in Epic 1

---

### Estimated Complexity

**Medium** — Most code is test code. Main complexity is VCR setup for multi-agent scenarios and crafting deterministic-enough assertions for LLM-generated output.

**Effort:** 1 week

### Agent Assignment

**QA** (Claude Sonnet) — primary: writes and validates all E2E tests
**Rails Lead** (DeepSeek Reasoner) — assists with VCR recording and fixture setup
