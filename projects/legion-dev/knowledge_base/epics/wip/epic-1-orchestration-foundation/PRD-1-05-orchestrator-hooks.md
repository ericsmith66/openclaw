#### PRD-1-05: Orchestrator Hooks

**Log Requirements**
- Create/update a task log under `knowledge_base/task-logs/`.
- In the log, include detailed manual test steps and expected results.
- If asked to review: create a separate document named `PRD-1-05-orchestrator-hooks-feedback-V{{N}}.md` in the same directory as the source document.

---

### Overview

Implement the four orchestrator safety rails that monitor agent execution in real-time and intervene when thresholds are crossed. These hooks use the gem's `HookManager` to observe events during `Runner.run()` and update WorkflowRun status, log warnings, or stop execution when necessary.

The hooks are **rules-based guardrails** — no LLM judgment, just threshold checks. They detect problems (iteration budget, context pressure, handoffs, cost overruns) and record the detection. Epic 2 adds intelligent responses (auto-decomposition, model switching). Epic 1 just ensures the data is captured.

---

### Requirements

#### Functional

**Hook Registration Service (`app/services/legion/orchestrator_hooks_service.rb`):**

`OrchestratorHooksService.call(hook_manager:, workflow_run:, team_membership:)`

Registers 4 hooks on the provided HookManager:

**1. Iteration Budget Monitor (`on_tool_called` hook):**
- Counts tool calls per run (proxy for iterations since each iteration typically includes tool calls)
- Model-specific decomposition thresholds (from benchmark data):
  - Grok 4.1 Fast: warn at 100 iterations
  - Claude Sonnet: warn at 50 iterations
  - Qwen3 Coder: warn at 55 iterations
  - DeepSeek Chat/Reasoner: warn at 30 iterations
- Threshold lookup: `team_membership.config["model"]` → threshold map
- Unknown models default to 50 iterations
- At threshold: Log warning on WorkflowRun metadata (`metadata["iteration_warnings"] << { iteration: N, timestamp: Time.now }`)
- At 2× threshold: Update WorkflowRun status to `iteration_limit`, return `HookResult(blocked: true)` to stop execution
- Does NOT block before 2× threshold — just records warnings

**2. Context Window Pressure (`on_token_budget_warning` hook):**
- The gem fires `on_token_budget_warning` when context approaches limits
- At 60% context usage: Update WorkflowRun status to `at_risk`. Log to metadata.
- At 80% context usage: Update WorkflowRun status to `decomposing`. Return `HookResult(blocked: true)` to prevent default compaction. Log recommendation to decompose.
- Percentage thresholds read from event payload (the gem provides usage data)

**3. Handoff Capture (`on_handoff_created` hook):**
- The gem fires `on_handoff_created` when `HandoffStrategy` creates a continuation task
- Create a new WorkflowRun record for the continuation:
  - Same project and team_membership
  - Status: `queued`
  - Prompt: continuation prompt from handoff event payload
  - Metadata: `{ "handed_off_from": original_workflow_run.id }`
- Update original WorkflowRun: status → `handed_off`, metadata includes `{ "handed_off_to": new_run.id }`
- Log the handoff chain for traceability

**4. Cost Budget Enforcement (`on_cost_budget_exceeded` hook):**
- The gem fires `on_cost_budget_exceeded` when cost ceiling is hit
- Update WorkflowRun status to `budget_exceeded`
- Record cost data in metadata: `metadata["cost_exceeded"] = { total_cost: ..., budget: ..., timestamp: ... }`
- Return `HookResult(blocked: true)` to stop execution

**Model Threshold Configuration:**
- Store in a configuration class or constant: `Legion::OrchestratorHooks::ITERATION_THRESHOLDS`
- Default thresholds based on benchmark data
- Overridable via WorkflowRun metadata or environment variable for testing
- Format:
  ```ruby
  ITERATION_THRESHOLDS = {
    "deepseek-reasoner" => 30,
    "deepseek-chat" => 30,
    "claude-sonnet-4-20250514" => 50,
    "claude-opus-4-20250514" => 50,
    "grok-4-1-fast-non-reasoning" => 100,
    "qwen3-coder-next" => 55
  }.freeze
  DEFAULT_THRESHOLD = 50
  ```

#### Non-Functional

- Hooks must be fast — they execute synchronously during `Runner.run()`. No DB queries except the UPDATE on WorkflowRun.
- Hooks must not raise exceptions that crash the runner — wrap in begin/rescue, log errors.
- Hook registration is idempotent — calling `OrchestratorHooksService` twice doesn't double-register.
- All WorkflowRun status changes via hooks must be logged at `Rails.logger.info` level with context.

#### Rails / Implementation Notes

- Service: `app/services/legion/orchestrator_hooks_service.rb`
- Configuration: `app/services/legion/orchestrator_hooks.rb` (constants and threshold config)
- Integration with PRD-1-04: `AgentAssemblyService` calls `OrchestratorHooksService.call(hook_manager:, workflow_run:, team_membership:)` after creating the HookManager, before passing it to Runner.
- The gem's `HookResult` struct: `HookResult.new(blocked:, event:, result:)`. `blocked: true` stops execution.
- Iteration counting: The hook receives the tool call event. Maintain a counter in a closure or instance variable within the hook registration.

---

### Error Scenarios & Fallbacks

- Model name not found in threshold map → Use DEFAULT_THRESHOLD (50). Log at warn level.
- WorkflowRun update fails during hook → Log error, do NOT block agent execution (hooks are advisory in Epic 1, not mission-critical)
- Token budget warning payload missing percentage → Skip context pressure check, log warning
- Handoff continuation run creation fails → Log error, still mark original as `handed_off`
- Cost data missing from exceeded event → Still block execution, log with available data

---

### Architectural Context

Hooks sit between the AgentAssemblyService and Runner execution:

```
AgentAssemblyService
  → Creates HookManager
  → OrchestratorHooksService registers 4 hooks
  → Runner receives HookManager
  → During Runner.run():
      → on_tool_called fires → iteration counter increments
      → on_token_budget_warning fires → status updated
      → on_handoff_created fires → new WorkflowRun created
      → on_cost_budget_exceeded fires → run stopped
```

**Why rules-based, not LLM-based?**
These are safety rails. They must be deterministic, fast, and predictable. An LLM deciding whether to stop a run introduces latency and unpredictability. Epic 2 adds LLM-driven responses (e.g., "this task is too big, auto-decompose") on top of these deterministic detections.

**Relationship to PRD-1-04:**
PRD-1-04 creates an empty HookManager. This PRD populates it with the 4 orchestrator hooks. The change to AgentAssemblyService is minimal: one additional service call after HookManager creation.

**Non-goals:**
- No auto-decomposition on detection (Epic 2)
- No model switching on detection (Epic 2)
- No user notification via UI (Epic 4)

---

### Acceptance Criteria

- [ ] AC1: Iteration budget hook counts tool calls and warns at model-specific threshold
- [ ] AC2: Iteration budget hook blocks execution at 2× threshold with `iteration_limit` status
- [ ] AC3: Context pressure hook marks WorkflowRun `at_risk` at 60%
- [ ] AC4: Context pressure hook blocks at 80% with `decomposing` status
- [ ] AC5: Handoff hook creates new WorkflowRun with correct prompt and metadata chain
- [ ] AC6: Handoff hook marks original run as `handed_off` with link to continuation
- [ ] AC7: Cost budget hook blocks execution with `budget_exceeded` status
- [ ] AC8: Unknown model names fall back to DEFAULT_THRESHOLD
- [ ] AC9: Hook errors are caught and logged — do not crash the runner
- [ ] AC10: All warnings/interventions recorded in WorkflowRun metadata
- [ ] AC11: AgentAssemblyService integrates hook registration
- [ ] AC12: `rails test` — zero failures for hooks tests

---

### Test Cases

#### Unit (Minitest)

- `test/services/legion/orchestrator_hooks_service_test.rb`:
  - Iteration hook: Fires warning at threshold, records in metadata
  - Iteration hook: Blocks at 2× threshold, sets `iteration_limit` status
  - Iteration hook: Different thresholds for different models (test DeepSeek=30, Grok=100)
  - Iteration hook: Unknown model uses DEFAULT_THRESHOLD (50)
  - Context hook: 60% → `at_risk` status
  - Context hook: 80% → `decomposing` status, blocked
  - Context hook: Below 60% → no action
  - Handoff hook: Creates new WorkflowRun with continuation prompt
  - Handoff hook: Links original and continuation via metadata
  - Handoff hook: Original status → `handed_off`
  - Cost hook: Blocks execution, sets `budget_exceeded`
  - Cost hook: Records cost data in metadata
  - Error resilience: DB failure in hook → logged, not raised
  - Registration idempotency: double-call doesn't double-register

#### Integration (Minitest)

- `test/integration/orchestrator_hooks_integration_test.rb`:
  - Full dispatch with iteration limit set low (5) → verify `iteration_limit` status
  - Full dispatch with hooks registered → verify WorkflowRun metadata contains hook activity
  - Handoff scenario: trigger HandoffStrategy → verify chain of WorkflowRuns

#### System / Smoke

- N/A for automated. Manual verification via `--verbose` flag showing hook activity.

---

### Manual Verification

1. Run `bin/legion execute --team ROR --agent rails-lead --prompt "Create a complex model" --max-iterations 5 --verbose`
   - If model has threshold 30 and max_iterations 5, expect: no warning (under threshold)
2. Set a very low threshold override, run agent → verify `iteration_limit` in WorkflowRun status
3. `rails console`:
   - `WorkflowRun.last.metadata` → check for iteration_warnings, at_risk markers
   - `WorkflowRun.where(status: :handed_off)` → check handoff chain
4. Verify hooks don't break normal execution: Run standard `bin/legion execute` → confirm agent completes normally with hooks registered

**Expected:** Safety rails active during every dispatch, recording warnings and interventions in WorkflowRun metadata without disrupting normal agent execution.

---

### Dependencies

- **Blocked By:** PRD-1-01 (Schema — needs WorkflowRun model), PRD-1-04 (CLI Dispatch — needs AgentAssemblyService to integrate)
- **Blocks:** PRD-1-07 (Plan Execution benefits from hooks), PRD-1-08 (Validation tests hook behavior)

---

### Estimated Complexity

**Low-Medium** — Clear hook points defined by the gem. Main complexity is threshold configuration and ensuring hooks don't crash the runner on errors.

**Effort:** 0.5 week

### Agent Assignment

**Rails Lead** (DeepSeek Reasoner) — primary implementer
