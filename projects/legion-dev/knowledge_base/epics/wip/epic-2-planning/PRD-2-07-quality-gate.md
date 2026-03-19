# PRD 2-07: QualityGate Base Class

**Epic:** [Epic 2 — WorkflowEngine & Quality Gates](0000-epic.md)

## Key Decisions

- D-12: Configurable gate thresholds (default 90)
- D-31: Three-layer testing: (1) tool guard unit tests (deterministic), (2) prompt contract tests (live LLM, on prompt changes), (3) integration tests (VCR, assert state changes not reasoning)
**Log Requirements**
- Create/update task log under `knowledge_base/task-logs/`

---

### Overview

The Score Command (2-03) can dispatch a QA agent and parse a score, but there's no reusable abstraction for quality gates. Each gate (Architect review, QA scoring) would need to duplicate prompt building, agent dispatch, score parsing, artifact creation, and threshold comparison.

PRD 2-07 introduces `QualityGate` — a base class that encapsulates the full gate evaluation flow: build a phase-specific prompt via PromptBuilder, dispatch the appropriate agent via DispatchService, parse the numeric score, create a typed Artifact, and return a `GateResult` with pass/fail status. Subclasses (ArchitectGate, QAGate in PRD 2-08) only need to define the gate name, prompt template phase, agent role, and threshold.

---

### Requirements

#### Functional

- FR-1: Create `Legion::QualityGate` base class with abstract interface
- FR-2: Subclass contract: `gate_name` (string), `prompt_template_phase` (symbol), `agent_role` (string), `default_threshold` (integer)
- FR-3: `QualityGate#evaluate(execution:, workflow_run: nil)` → `GateResult`. ArchitectGate uses the workflow_run (decomposition run); QAGate ignores it (queries tasks from execution).
  - Builds prompt via `PromptBuilder.build(phase: prompt_template_phase, context: gate_context)`
  - Dispatches agent (by role) via `DispatchService`
  - Parses score from output via `ScoreParser` (from 2-03)
  - Creates Artifact (type based on gate: `score_report` for QA, `architect_review` for Architect)
  - Returns `GateResult(passed:, score:, feedback:, artifact:)`
- FR-4: `GateResult` struct: `passed` (boolean), `score` (integer), `feedback` (string), `artifact` (Artifact)
- FR-5: Threshold is configurable per evaluation (passed as option, falls back to `default_threshold`, falls back to 90)
- FR-6: `gate_context` method (overridable by subclasses) — returns the Hash context for PromptBuilder. Base implementation provides: `prd_content`, `acceptance_criteria`, `task_results`, `previous_feedback`
- FR-7: Refactor `ScoreService` (from 2-03) to use `QualityGate` internally (or at minimum, share `ScoreParser`)
- FR-8: `QualityGate.registry` — class-level registry of all gate subclasses (for dynamic lookup by name)

#### Non-Functional

- NF-1: Gate evaluation must be idempotent — evaluating the same execution twice creates a new Artifact (versioned) but doesn't change execution state
- NF-2: Score parsing must be consistent with ScoreParser from 2-03 (single implementation, no duplication)

#### Rails / Implementation Notes

- **Class**: `app/services/legion/quality_gate.rb` (base class)
- **Struct**: `GateResult` defined in same file or `app/models/legion/gate_result.rb`
- **Refactor**: `app/services/legion/score_service.rb` may be simplified to delegate to QualityGate

---

### Error Scenarios & Fallbacks

- **Agent dispatch fails** → GateResult with `passed: false`, `score: 0`, `feedback: "Gate evaluation failed: <error>"`. Artifact created with error content.
- **Score parsing fails** → GateResult with `passed: false`, `score: 0`, `feedback: "Score parsing failed — manual review required"`. Artifact created.
- **Agent role not found in team** → Raise `Legion::AgentNotFoundError` ("No agent with role '<role>' in team")
- **PromptBuilder fails** → Raise `Legion::PromptContextError` (propagated from PromptBuilder)

---

### Architectural Context

QualityGate is a template method pattern: the base class defines the evaluation flow (build prompt → dispatch → parse → artifact → result), and subclasses customize the specific gate behavior (which agent, which prompt, which artifact type, which threshold).

This PRD creates the base class and the GateResult struct. PRD 2-08 creates the concrete subclasses (ArchitectGate, QAGate). The Conductor's `dispatch_scoring` and `dispatch_architect_review` tools (2-06) call QualityGate.evaluate() to perform gate evaluations.

The `ScoreParser` from PRD 2-03 is reused — there's one score parsing implementation shared between the standalone `score` command and the QualityGate evaluations.

---

### Acceptance Criteria

- [ ] AC-1: `QualityGate` base class exists with `evaluate(execution:, workflow_run: nil)` method
- [ ] AC-2: `evaluate` builds prompt via PromptBuilder, dispatches agent, parses score, creates Artifact, returns GateResult
- [ ] AC-3: `GateResult` has `passed`, `score`, `feedback`, `artifact` attributes
- [ ] AC-4: Given score 87 and threshold 90: `GateResult.passed` is false
- [ ] AC-5: Given score 94 and threshold 90: `GateResult.passed` is true
- [ ] AC-6: Artifact created by evaluate has correct `artifact_type` (determined by subclass), `score`, `content`
- [ ] AC-7: Threshold is configurable: `evaluate(execution:, workflow_run:, threshold: 85)` uses 85 instead of default
- [ ] AC-8: `QualityGate.registry` returns registered subclasses
- [ ] AC-9: `gate_context` returns a Hash with PRD content and task results from the execution
- [ ] AC-10: Score parsing uses `ScoreParser` from PRD 2-03 (single implementation)

---

### Test Cases

#### Unit (Minitest)

- `test/services/legion/quality_gate_test.rb`: Test with a mock subclass. Verify evaluate flow: prompt built, agent dispatched (mocked), score parsed, Artifact created, GateResult returned. Threshold comparison (pass/fail). Configurable threshold override. Error handling (dispatch failure, parse failure). Registry lookup.

#### Integration (Minitest)

- `test/integration/quality_gate_integration_test.rb`: Full evaluation with VCR-recorded agent dispatch. Verify Artifact persisted with correct type and score. Verify GateResult matches.

---

### Manual Verification

1. In console, create a test subclass:
   ```ruby
   class TestGate < Legion::QualityGate
     def gate_name; "test"; end
     def prompt_template_phase; :qa_score; end
     def agent_role; "qa"; end
     def default_threshold; 90; end
   end
   ```
2. Run: `result = TestGate.new.evaluate(execution: exec, workflow_run: run)`
3. Verify: `result.score` is an integer, `result.passed` is boolean, `result.artifact` is persisted

**Expected:** Gate evaluates correctly, Artifact created, GateResult populated.

---

### Dependencies

- **Blocked By:** 2-02 (Artifact model), 2-05 (PromptBuilder for prompt rendering)
- **Blocks:** 2-08 (ArchitectGate + QAGate are QualityGate subclasses)

---

