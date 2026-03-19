# PRD 2-08: ArchitectGate + QAGate

**Epic:** [Epic 2 — WorkflowEngine & Quality Gates](0000-epic.md)

## Key Decisions

- D-12: Configurable gate thresholds (default 90)
- D-22: `architect_review` is a distinct `artifact_type` enum value, separate from `score_report`
- D-29: ArchitectGate in automated loop between decompose and code. New `architect_reviewing` phase. New `dispatch_architect_review` tool.
- D-31: Three-layer testing: (1) tool guard unit tests (deterministic), (2) prompt contract tests (live LLM, on prompt changes), (3) integration tests (VCR, assert state changes not reasoning)
- D-39: ArchitectGate takes decomposition WorkflowRun. QAGate takes WorkflowExecution (queries all tasks). `evaluate()` signature: `workflow_run` is optional.
- D-44: 4 Layer 2 prompt contract tests for gate prompts added to PRD 2-08 (2 per gate). Tagged `live_llm: true`.
**Log Requirements**
- Create/update task log under `knowledge_base/task-logs/`

---

### Overview

PRD 2-07 built the QualityGate base class. PRD 2-08 implements the two concrete gates that enforce quality in the automated loop:

1. **ArchitectGate** (D-29) — evaluates the decomposition plan after the Architect produces it. Sits between `decomposing` and `coding` phases. Dispatches the Architect agent to review the task list, DAG, and sizing. Threshold: ≥ 90. If failed and `decomposition_attempt < 2`, the Conductor re-decomposes with feedback. After 2 failed attempts: escalate.

2. **QAGate** — evaluates the implementation output after coding. Sits between `coding` and `completed` phases. Dispatches the QA agent to score against acceptance criteria. Threshold: ≥ 90. If failed and `attempt < 3`, retry with context. After 3 attempts: escalate.

Both gates integrate with the Conductor's orchestration tools — `dispatch_architect_review` calls ArchitectGate, `dispatch_scoring` calls QAGate.

---

### Requirements

#### Functional

- FR-1: Create `Legion::ArchitectGate` (subclass of QualityGate)
  - `gate_name`: "architect_review"
  - `prompt_template_phase`: `:architect_review`
  - `agent_role`: "architect"
  - `default_threshold`: 90
  - `artifact_type`: `:architect_review` (D-22)
- FR-2: ArchitectGate `gate_context` includes: PRD content, task list with descriptions, DAG structure, task sizing scores, parallel wave breakdown. ArchitectGate receives the decomposition WorkflowRun (D-39).
- FR-3: Create `Legion::QAGate` (subclass of QualityGate)
  - `gate_name`: "qa_score"
  - `prompt_template_phase`: `:qa_score`
  - `agent_role`: "qa"
  - `default_threshold`: 90
  - `artifact_type`: `:score_report`
- FR-4: QAGate `gate_context` includes: PRD content, acceptance criteria, task results (code output), test results, previous QA feedback (if retry). QAGate receives the WorkflowExecution (queries `execution.tasks`), not a single run (D-39).
- FR-5: `architect_review_prompt.md.liquid` template: provides Architect with task list, asks for scored review using RULES.md Φ9 rubric (Completeness, Architecture Alignment, Risk Awareness, Test Strategy, Dependency Ordering)
- FR-6: `qa_score_prompt.md.liquid` template: provides QA with code output and PRD acceptance criteria, asks for scored review using RULES.md Φ11 rubric (AC Compliance, Test Coverage, Code Quality, Plan Adherence)
- FR-7: Integration with Conductor tools:
  - `dispatch_architect_review` tool calls `ArchitectGate.new.evaluate(execution:, workflow_run:)`
  - `dispatch_scoring` tool calls `QAGate.new.evaluate(execution:, workflow_run:)`
- FR-8: Both gates register in `QualityGate.registry` for dynamic lookup

#### Non-Functional

- NF-1: ArchitectGate evaluation should complete in < 60 seconds (Architect reviews a plan, not code)
- NF-2: QAGate evaluation may take 2-5 minutes (QA reviews code diffs and runs tests mentally)
- NF-3: Both gates must produce structured feedback suitable for retry context accumulation

#### Rails / Implementation Notes

- **Gates**: `app/services/legion/architect_gate.rb`, `app/services/legion/qa_gate.rb`
- **Templates**: Update `app/prompts/architect_review_prompt.md.liquid`, `app/prompts/qa_score_prompt.md.liquid` (created in 2-05, fleshed out here)
- **Tool integration**: Update `app/tools/legion/orchestration/dispatch_architect_review.rb` and `dispatch_scoring.rb` to call gates

---

### Error Scenarios & Fallbacks

- **Architect agent unavailable** → ArchitectGate returns `GateResult(passed: false, score: 0, feedback: "Architect agent unavailable")`. Conductor must decide: retry or escalate.
- **QA agent unavailable** → Same pattern as Architect.
- **Architect gives score but no structured feedback** → Score parsed, feedback is the full response text. Retry context may be less specific but still contains the Architect's reasoning.
- **ArchitectGate decomposition_attempt >= 2 and still failing** → Conductor escalates. The gate itself just returns the result — the Conductor makes the escalation decision.

---

### Architectural Context

These are the two quality gates defined in RULES.md:
- **Φ9 (Architect Gate)**: Plan review before implementation — "Is the decomposition sound?"
- **Φ11 (QA Gate)**: Implementation review after coding — "Is the code good enough?"

The ArchitectGate is new to the automated loop (D-29). It was previously a manual step in RULES.md. Adding it to the automated loop means every `implement` run has its plan reviewed before coding begins — this catches bad decompositions early (before expensive coding work).

The QAGate is the primary quality enforcement mechanism. Its score determines whether the Conductor retries (score < 90) or completes (score ≥ 90).

Both gates produce Artifacts that feed into the retry logic (PRD 2-09) and the retrospective (PRD 2-10).

---

### Acceptance Criteria

- [ ] AC-1: `ArchitectGate.new.evaluate(execution: exec, workflow_run: run)` dispatches Architect agent and returns GateResult with score
- [ ] AC-2: ArchitectGate creates Artifact with `artifact_type: :architect_review` (D-22)
- [ ] AC-3: ArchitectGate uses `architect_review_prompt.md.liquid` template
- [ ] AC-4: ArchitectGate `gate_context` includes task list, DAG, sizing scores
- [ ] AC-5: `QAGate.new.evaluate(execution: exec, workflow_run: run)` dispatches QA agent and returns GateResult with score
- [ ] AC-6: QAGate creates Artifact with `artifact_type: :score_report`
- [ ] AC-7: QAGate uses `qa_score_prompt.md.liquid` template
- [ ] AC-8: QAGate `gate_context` includes PRD content, acceptance criteria, code output
- [ ] AC-9: `dispatch_architect_review` orchestration tool calls `ArchitectGate.evaluate` internally
- [ ] AC-10: `dispatch_scoring` orchestration tool calls `QAGate.evaluate` internally
- [ ] AC-11: Both gates registered in `QualityGate.registry`
- [ ] AC-12: Architect review prompt includes RULES.md Φ9 scoring rubric (5 criteria with weights)
- [ ] AC-13: QA scoring prompt includes RULES.md Φ11 scoring rubric (4 criteria with points)

---

### Test Cases

#### Unit (Minitest)

- `test/services/legion/architect_gate_test.rb`: Gate evaluation with mocked Architect dispatch. Verify artifact_type is :architect_review. Verify gate_context includes task list and DAG. Threshold comparison.
- `test/services/legion/qa_gate_test.rb`: Gate evaluation with mocked QA dispatch. Verify artifact_type is :score_report. Verify gate_context includes PRD content and code output. Threshold comparison.

#### Prompt Contract Tests (Layer 2, D-44)

- `test/prompt_contracts/architect_review_prompt_test.rb` (tagged `live_llm: true`):
  - Given valid task list + DAG → Architect returns parseable score
  - Given clearly flawed decomposition (circular dep, no test tasks) → Architect score < 90
- `test/prompt_contracts/qa_score_prompt_test.rb` (tagged `live_llm: true`):
  - Given passing code + met acceptance criteria → QA score ≥ 90
  - Given clearly failing code (empty implementation) → QA score < 90

#### Integration (Minitest)

- `test/integration/architect_gate_integration_test.rb`: Full ArchitectGate evaluation with VCR. Verify Artifact persisted, GateResult correct.
- `test/integration/qa_gate_integration_test.rb`: Full QAGate evaluation with VCR. Verify Artifact persisted, GateResult correct.
- `test/integration/conductor_gate_integration_test.rb`: Conductor calls dispatch_architect_review → ArchitectGate runs → ConductorDecision records result. Conductor calls dispatch_scoring → QAGate runs → ConductorDecision records result.

---

### Manual Verification

1. Complete a decomposition (via `bin/legion decompose`)
2. In console: `result = Legion::ArchitectGate.new.evaluate(execution: exec, workflow_run: run)`
3. Verify: `result.score` is an integer, `result.artifact.artifact_type` is "architect_review"
4. Complete coding tasks (via `bin/legion execute-plan`)
5. In console: `result = Legion::QAGate.new.evaluate(execution: exec, workflow_run: run)`
6. Verify: `result.score` is an integer, `result.artifact.artifact_type` is "score_report"

**Expected:** Both gates produce scored results with appropriate artifact types.

---

### Dependencies

- **Blocked By:** 2-07 (QualityGate base class)
- **Blocks:** 2-09 (Retry logic depends on gate results)


---

