# PRD-1-05: Orchestrator Hooks — Implementation Plan

**Created:** 2026-03-06  
**Owner:** Rails Lead (DeepSeek Reasoner)  
**Epic:** Epic 1 — Orchestration Foundation  
**PRD:** [PRD-1-05-orchestrator-hooks.md](./PRD-1-05-orchestrator-hooks.md)  
**Status:** PLAN — Awaiting Architect Review

---

## 1. Overview

Implement 4 orchestrator safety rails (hooks) that monitor agent execution in real-time:
1. Iteration Budget Monitor (`on_tool_called`)
2. Context Window Pressure (`on_token_budget_warning`)
3. Handoff Capture (`on_handoff_created`)
4. Cost Budget Enforcement (`on_cost_budget_exceeded`)

---

## 2. File-by-File Changes

### New Files

#### 1. `app/services/legion/orchestrator_hooks.rb`
**Purpose:** Configuration constants for iteration thresholds

```ruby
# frozen_string_literal: true

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

    def self.iteration_threshold_for_model(model_name)
      ITERATION_THRESHOLDS.fetch(model_name, DEFAULT_THRESHOLD)
    end
  end
end
```

#### 2. `app/services/legion/orchestrator_hooks_service.rb`
**Purpose:** Register all 4 hooks on HookManager

```ruby
# frozen_string_literal: true

module Legion
  class OrchestratorHooksService
    def self.call(hook_manager:, workflow_run:, team_membership:)
      new(hook_manager:, workflow_run:, team_membership:).call
    end

    def initialize(hook_manager:, workflow_run:, team_membership:)
      @hook_manager = hook_manager
      @workflow_run = workflow_run
      @team_membership = team_membership
      @hooks_registered = false
    end

    def call
      return if @hooks_registered

      register_iteration_budget_hook
      register_context_pressure_hook
      register_handoff_capture_hook
      register_cost_budget_hook

      @hooks_registered = true
    end

    private

    def register_iteration_budget_hook
      threshold = OrchestratorHooks.iteration_threshold_for_model(
        @team_membership.config["model"]
      )

      @hook_manager.on(:on_tool_called) do |event_data, context|
        begin
          # Track iterations in workflow run metadata
          current_count = (@workflow_run.metadata["iteration_count"] || 0) + 1
          @workflow_run.metadata["iteration_count"] = current_count
          @workflow_run.save!

          # Warn at threshold
          if current_count >= threshold && current_count < threshold * 2
            Rails.logger.warn(
              "[OrchestratorHooks] Iteration warning: count=#{current_count}, " \
              "threshold=#{threshold}, workflow_run_id=#{@workflow_run.id}"
            )
            @workflow_run.metadata["iteration_warnings"] ||= []
            @workflow_run.metadata["iteration_warnings"] << {
              iteration: current_count,
              timestamp: Time.now.to_s
            }
            @workflow_run.save!
          end

          # Block at double threshold
          if current_count >= threshold * 2
            Rails.logger.warn(
              "[OrchestratorHooks] Iteration limit reached: count=#{current_count}, " \
              "threshold=#{threshold * 2}, workflow_run_id=#{@workflow_run.id}"
            )
            @workflow_run.update!(
              status: :iteration_limit,
              metadata: @workflow_run.metadata.merge({
                "iteration_limit" => {
                  iteration: current_count,
                  timestamp: Time.now.to_s
                }
              })
            )
            # Block individual tool call (runner will continue but tool calls will be blocked)
            AgentDesk::Hooks::HookResult.new(blocked: true)
          else
            nil  # Not blocking
          end
        rescue StandardError => e
          Rails.logger.error("[OrchestratorHooks] on_tool_called error: #{e.message}")
          nil  # Return nil to avoid blocking tool execution
        end
      end
    end

    def register_context_pressure_hook
      @hook_manager.on(:on_token_budget_warning) do |event_data, context|
        begin
          usage_percentage = event_data[:usage_percentage]
          next unless usage_percentage

          if usage_percentage >= 80
            @workflow_run.update!(
              status: :decomposing,
              metadata: @workflow_run.metadata.merge({
                "context_warning" => {
                  usage_percentage: usage_percentage,
                  timestamp: Time.now.to_s,
                  recommendation: "Decompose task to reduce context pressure"
                }
              })
            )
            # Block default compaction (we're handling decomposition)
            AgentDesk::Hooks::HookResult.new(blocked: true)
          elsif usage_percentage >= 60
            @workflow_run.update!(
              status: :at_risk,
              metadata: @workflow_run.metadata.merge({
                "context_warning" => {
                  usage_percentage: usage_percentage,
                  timestamp: Time.now.to_s
                }
              })
            )
            # Allow default compaction to run
            AgentDesk::Hooks::HookResult.new(blocked: false)
          else
            AgentDesk::Hooks::HookResult.new(blocked: false)
          end
        rescue StandardError => e
          Rails.logger.error("[OrchestratorHooks] on_token_budget_warning error: #{e.message}")
          nil
        end
      end
    end

    def register_handoff_capture_hook
      @hook_manager.on(:on_handoff_created) do |event_data, context|
        begin
          handoff_prompt = event_data[:handoff_prompt]
          new_task_id = event_data[:new_task_id]

          # Create new WorkflowRun for continuation
          new_run = @workflow_run.class.create!(
            project: @workflow_run.project,
            team_membership: @workflow_run.team_membership,
            prompt: handoff_prompt,
            status: :queued,
            metadata: { "handed_off_from" => @workflow_run.id }
          )

          # Update original run
          @workflow_run.update!(
            status: :handed_off,
            metadata: @workflow_run.metadata.merge({
              "handed_off_to" => new_run.id,
              "handed_off_at" => Time.now.to_s
            })
          )

          AgentDesk::Hooks::HookResult.new(
            blocked: false,
            result: { new_run_id: new_run.id }
          )
        rescue StandardError => e
          Rails.logger.error("[OrchestratorHooks] on_handoff_created error: #{e.message}")
          nil
        end
      end
    end

    def register_cost_budget_hook
      @hook_manager.on(:on_cost_budget_exceeded) do |event_data, context|
        begin
          @workflow_run.update!(
            status: :budget_exceeded,
            metadata: @workflow_run.metadata.merge({
              "cost_exceeded" => {
                cumulative_cost: event_data[:cumulative_cost],
                cost_budget: event_data[:cost_budget],
                last_message_cost: event_data[:last_message_cost],
                timestamp: Time.now.to_s
              }
            })
          )
          # Return nil (or blocked: false) to allow runner's default :stop
          nil
        rescue StandardError => e
          Rails.logger.error("[OrchestratorHooks] on_cost_budget_exceeded error: #{e.message}")
          nil
        end
      end
    end
  end
end
```

### Modified Files

#### 3. `app/services/legion/agent_assembly_service.rb`
**Change:** Call `OrchestratorHooksService` after creating HookManager

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

### Test Files

#### 4. `test/services/legion/orchestrator_hooks_service_test.rb`
**Purpose:** Unit tests for all 4 hooks

```ruby
# frozen_string_literal: true

require "test_helper"

module Legion
  class OrchestratorHooksServiceTest < ActiveSupport::TestCase
    def setup
      @project = create(:project)
      @agent_team = create(:agent_team, project: @project)
      @team_membership = create(:team_membership, agent_team: @agent_team)
      @team_membership.config["model"] = "deepseek-reasoner"
      @team_membership.save!
      @workflow_run = create(
        :workflow_run,
        project: @project,
        team_membership: @team_membership,
        prompt: "Test prompt",
        status: :running,
        metadata: {}
      )
      @hook_manager = AgentDesk::Hooks::HookManager.new
    end

    # Iteration Budget Hook Tests
    def test_iteration_hook_warns_at_threshold
      threshold = OrchestratorHooks.iteration_threshold_for_model("deepseek-reasoner")
      OrchestratorHooksService.call(
        hook_manager: @hook_manager,
        workflow_run: @workflow_run,
        team_membership: @team_membership
      )

      # Trigger threshold-1 calls (no warning)
      (threshold - 1).times { @hook_manager.trigger(:on_tool_called, {}, {}) }
      @workflow_run.reload
      assert_nil @workflow_run.metadata["iteration_warnings"]

      # Trigger threshold call (should warn)
      @hook_manager.trigger(:on_tool_called, {}, {})

      warnings = @workflow_run.reload.metadata["iteration_warnings"]
      assert warnings.is_a?(Array), "Should have iteration_warnings array"
      assert_equal 1, warnings.length
      assert_equal threshold, warnings[0]["iteration"]
    end

    def test_iteration_hook_blocks_at_double_threshold
      threshold = OrchestratorHooks.iteration_threshold_for_model("deepseek-reasoner")
      OrchestratorHooksService.call(
        hook_manager: @hook_manager,
        workflow_run: @workflow_run,
        team_membership: @team_membership
      )

      # Trigger 2*threshold calls
      (threshold * 2).times { @hook_manager.trigger(:on_tool_called, {}, {}) }

      @workflow_run.reload
      assert_equal "iteration_limit", @workflow_run.status
      assert @workflow_run.metadata["iteration_limit"]
    end

    def test_iteration_hook_uses_model_specific_threshold
      @team_membership.config["model"] = "grok-4-1-fast-non-reasoning"
      @team_membership.save!

      threshold = OrchestratorHooks::ITERATION_THRESHOLDS["grok-4-1-fast-non-reasoning"]
      OrchestratorHooksService.call(
        hook_manager: @hook_manager,
        workflow_run: @workflow_run,
        team_membership: @team_membership
      )

      # Trigger threshold-1 calls
      (threshold - 1).times { @hook_manager.trigger(:on_tool_called, {}, {}) }

      # Trigger threshold call (should warn)
      @hook_manager.trigger(:on_tool_called, {}, {})

      warnings = @workflow_run.reload.metadata["iteration_warnings"]
      assert_equal 1, warnings.length
      assert_equal threshold, warnings[0]["iteration"]
    end

    def test_iteration_hook_fallback_to_default_threshold
      @team_membership.config["model"] = "unknown-model"
      @team_membership.save!

      OrchestratorHooksService.call(
        hook_manager: @hook_manager,
        workflow_run: @workflow_run,
        team_membership: @team_membership
      )

      threshold = OrchestratorHooks::DEFAULT_THRESHOLD

      # Trigger threshold-1 calls
      (threshold - 1).times { @hook_manager.trigger(:on_tool_called, {}, {}) }

      # Trigger threshold call (should warn)
      @hook_manager.trigger(:on_tool_called, {}, {})

      warnings = @workflow_run.reload.metadata["iteration_warnings"]
      assert_equal 1, warnings.length
      assert_equal threshold, warnings[0]["iteration"]
    end

    # Context Pressure Hook Tests
    def test_context_hook_at_60_percent_marks_at_risk
      OrchestratorHooksService.call(
        hook_manager: @hook_manager,
        workflow_run: @workflow_run,
        team_membership: @team_membership
      )

      result = @hook_manager.trigger(:on_token_budget_warning, { usage_percentage: 60 }, {})

      assert_equal "at_risk", @workflow_run.reload.status
      refute result.blocked, "Should not block default compaction at 60%"
    end

    def test_context_hook_at_80_percent_marks_decomposing_and_blocks
      OrchestratorHooksService.call(
        hook_manager: @hook_manager,
        workflow_run: @workflow_run,
        team_membership: @team_membership
      )

      result = @hook_manager.trigger(:on_token_budget_warning, { usage_percentage: 80 }, {})

      assert_equal "decomposing", @workflow_run.reload.status
      assert result.blocked, "Should block default compaction at 80%"
    end

    def test_context_hook_below_60_percent_no_action
      OrchestratorHooksService.call(
        hook_manager: @hook_manager,
        workflow_run: @workflow_run,
        team_membership: @team_membership
      )

      @workflow_run.update!(status: :running)
      result = @hook_manager.trigger(:on_token_budget_warning, { usage_percentage: 50 }, {})

      assert_equal "running", @workflow_run.reload.status
      refute result.blocked
    end

    def test_context_hook_with_missing_usage_percentage_no_action
      OrchestratorHooksService.call(
        hook_manager: @hook_manager,
        workflow_run: @workflow_run,
        team_membership: @team_membership
      )

      @workflow_run.update!(status: :running)
      result = @hook_manager.trigger(:on_token_budget_warning, { other_key: 100 }, {})

      assert_equal "running", @workflow_run.reload.status
      # Hook returns nil (no result) when skipping due to missing percentage
      assert_nil result
    end

    # Handoff Capture Hook Tests
    def test_handoff_hook_creates_new_workflow_run
      OrchestratorHooksService.call(
        hook_manager: @hook_manager,
        workflow_run: @workflow_run,
        team_membership: @team_membership
      )

      handoff_prompt = "Continue with next task"
      @hook_manager.trigger(
        :on_handoff_created,
        { handoff_prompt: handoff_prompt, new_task_id: "task-123" },
        {}
      )

      new_run = WorkflowRun.where("metadata->>'handed_off_from' = ?", @workflow_run.id.to_s).first
      assert new_run
      assert_equal handoff_prompt, new_run.prompt
      assert_equal "queued", new_run.status
    end

    def test_handoff_hook_links_original_and_continuation
      OrchestratorHooksService.call(
        hook_manager: @hook_manager,
        workflow_run: @workflow_run,
        team_membership: @team_membership
      )

      @hook_manager.trigger(
        :on_handoff_created,
        { handoff_prompt: "test", new_task_id: "task-123" },
        {}
      )

      @workflow_run.reload
      assert_equal "handed_off", @workflow_run.status
      new_run = WorkflowRun.where("metadata->>'handed_off_from' = ?", @workflow_run.id.to_s).first
      assert_equal new_run.id.to_s, @workflow_run.metadata["handed_off_to"]
    end

    def test_handoff_hook_updates_original_status
      OrchestratorHooksService.call(
        hook_manager: @hook_manager,
        workflow_run: @workflow_run,
        team_membership: @team_membership
      )

      @hook_manager.trigger(
        :on_handoff_created,
        { handoff_prompt: "test", new_task_id: "task-123" },
        {}
      )

      assert_equal "handed_off", @workflow_run.reload.status
    end

    # Cost Budget Hook Tests
    def test_cost_hook_updates_status_and_returns_nil_to_stop
      OrchestratorHooksService.call(
        hook_manager: @hook_manager,
        workflow_run: @workflow_run,
        team_membership: @team_membership
      )

      result = @hook_manager.trigger(
        :on_cost_budget_exceeded,
        { cumulative_cost: 10.50, cost_budget: 10.00, last_message_cost: 0.50 },
        {}
      )

      assert_equal "budget_exceeded", @workflow_run.reload.status
      # Should return nil (or blocked: false) to allow runner's default :stop
      assert_nil result
    end

    def test_cost_hook_records_cost_data_in_metadata
      OrchestratorHooksService.call(
        hook_manager: @hook_manager,
        workflow_run: @workflow_run,
        team_membership: @team_membership
      )

      @hook_manager.trigger(
        :on_cost_budget_exceeded,
        { cumulative_cost: 10.50, cost_budget: 10.00, last_message_cost: 0.50 },
        {}
      )

      cost_data = @workflow_run.reload.metadata["cost_exceeded"]
      assert cost_data
      assert_equal 10.50, cost_data["cumulative_cost"].to_f
      assert_equal 10.00, cost_data["cost_budget"].to_f
      assert_equal 0.50, cost_data["last_message_cost"].to_f
    end

    # Error Resilience Tests
    def test_hook_errors_are_captured_and_logged
      # Simulate DB failure during hook
      @workflow_run.stubs(:update!).raises(ActiveRecord::StatementInvalid)

      OrchestratorHooksService.call(
        hook_manager: @hook_manager,
        workflow_run: @workflow_run,
        team_membership: @team_membership
      )

      # Hook should not raise exception
      result = @hook_manager.trigger(:on_tool_called, {}, {})
      # Should return nil (error rescued)
      assert_nil result
    end

    # Idempotency Test
    def test_registration_is_idempotent
      service = OrchestratorHooksService.new(
        hook_manager: @hook_manager,
        workflow_run: @workflow_run,
        team_membership: @team_membership
      )

      service.call
      # Trigger a tool call, should increment iteration count
      @hook_manager.trigger(:on_tool_called, {}, {})
      first_count = @workflow_run.reload.metadata["iteration_count"] || 0

      # Call again (should be no-op)
      service.call
      # Trigger another tool call
      @hook_manager.trigger(:on_tool_called, {}, {})
      second_count = @workflow_run.reload.metadata["iteration_count"] || 0

      # Should have incremented only once per trigger, not double
      assert_equal first_count + 1, second_count
    end
  end
end
```

#### 5. `test/services/legion/orchestrator_hooks_integration_test.rb`
**Purpose:** Integration tests

```ruby
# frozen_string_literal: true

require "test_helper"

module Legion
  class OrchestratorHooksIntegrationTest < ActiveSupport::TestCase
    def setup
      @project = create(:project)
      @agent_team = create(:agent_team, project: @project)
      @team_membership = create(:team_membership, agent_team: @agent_team)
      @workflow_run = create(
        :workflow_run,
        project: @project,
        team_membership: @team_membership,
        prompt: "Test prompt",
        status: :running,
        metadata: {}
      )
    end

    def test_full_dispatch_with_low_iteration_limit
      # Set a very low threshold via config override (in real impl, use env var)
      threshold = 5
      OrchestratorHooks.stubs(:iteration_threshold_for_model).returns(threshold)

      hook_manager = AgentDesk::Hooks::HookManager.new
      OrchestratorHooksService.call(
        hook_manager: hook_manager,
        workflow_run: @workflow_run,
        team_membership: @team_membership
      )

      # Trigger more than threshold calls
      (threshold * 2).times { hook_manager.trigger(:on_tool_called, {}, {}) }

      assert_equal "iteration_limit", @workflow_run.reload.status
    end

    def test_hooks_record_activity_in_metadata
      hook_manager = AgentDesk::Hooks::HookManager.new
      OrchestratorHooksService.call(
        hook_manager: hook_manager,
        workflow_run: @workflow_run,
        team_membership: @team_membership
      )

      # Trigger exactly threshold calls to get warnings
      threshold = OrchestratorHooks::DEFAULT_THRESHOLD
      threshold.times { hook_manager.trigger(:on_tool_called, {}, {}) }

      @workflow_run.reload
      assert @workflow_run.metadata["iteration_warnings"].is_a?(Array)
      assert_equal 1, @workflow_run.metadata["iteration_warnings"].length
    end

    def test_hooks_no_warnings_below_threshold
      hook_manager = AgentDesk::Hooks::HookManager.new
      OrchestratorHooksService.call(
        hook_manager: hook_manager,
        workflow_run: @workflow_run,
        team_membership: @team_membership
      )

      # Trigger below threshold calls (no warnings)
      threshold = OrchestratorHooks::DEFAULT_THRESHOLD
      (threshold - 1).times { hook_manager.trigger(:on_tool_called, {}, {}) }

      @workflow_run.reload
      # No warnings should be recorded
      assert_nil @workflow_run.metadata["iteration_warnings"]
    end
  end
end
```

---

## 3. Numbered Test Checklist (MUST-IMPLEMENT)

### Unit Tests (`test/services/legion/orchestrator_hooks_service_test.rb`)

1. [ ] Iteration hook warns at threshold, records in metadata
2. [ ] Iteration hook blocks at 2× threshold, sets `iteration_limit` status
3. [ ] Iteration hook uses model-specific threshold (DeepSeek=30, Grok=100)
4. [ ] Iteration hook unknown model uses DEFAULT_THRESHOLD (50)
5. [ ] Context hook 60% → `at_risk` status
6. [ ] Context hook 80% → `decomposing` status, blocked
7. [ ] Context hook below 60% → no action
8. [ ] Context hook with missing usage_percentage → no action, no error
9. [ ] Handoff hook creates new WorkflowRun with continuation prompt
10. [ ] Handoff hook links original and continuation via metadata
11. [ ] Handoff hook original status → `handed_off`
12. [ ] Cost hook updates status and returns nil to stop execution
13. [ ] Cost hook records cost data in metadata
14. [ ] Hook errors caught and logged — do not raise
15. [ ] Registration idempotency — double-call doesn't double-register

### Integration Tests (`test/services/legion/orchestrator_hooks_integration_test.rb`)

16. [ ] Full dispatch with iteration limit set low (5) → verify `iteration_limit` status
17. [ ] Full dispatch with hooks registered → verify WorkflowRun metadata contains hook activity
18. [ ] Hooks no warnings below threshold

---

## 4. Error Path Matrix

| Error Scenario | Fallback/Recovery | Log Level |
|---------------|-------------------|-----------|
| Model name not found in threshold map | Use DEFAULT_THRESHOLD (50) | Warn |
| WorkflowRun update fails during hook | Log error, do NOT block agent execution | Error |
| Token budget warning payload missing percentage | Skip context pressure check | Warn |
| Handoff continuation run creation fails | Log error, still mark original as `handed_off` | Error |
| Cost data missing from exceeded event | Still block execution, log with available data | Error |
| Hook raises exception | Wrapped in begin/rescue, logged, does NOT crash runner | Error |

---

## 5. Migration Steps

**None required** — No database schema changes. All data stored in existing `workflow_runs.metadata` JSONB column.

---

## 6. Pre-QA Checklist Acknowledgment

**MUST be completed before submitting to QA (Φ11):**

- [ ] **Zero RuboCop offenses** on all modified files (source + tests)
- [ ] **All planned tests implemented** (15 unit tests, 3 integration tests)
- [ ] **Full test suite passes** — `rails test` returns 0 failures
- [ ] **Every `.rb` file has `# frozen_string_literal: true`** on line 1
- [ ] **Every `rescue` block and error class has a test** (error resilience tests)
- [ ] **Manual verification steps executed** (see PRD section 3.3)

**Blockers:** None known at plan submission. May discover during implementation.

---

## 7. Acceptance Criteria Verification

| AC | Description | Implementation Status |
|----|-------------|----------------------|
| AC1 | Iteration budget hook warns at model-specific threshold | ✅ `warn_at_threshold` |
| AC2 | Iteration budget hook blocks at 2× threshold | ✅ `block_at_double_threshold` |
| AC3 | Context hook marks WorkflowRun `at_risk` at 60% | ✅ Context hook |
| AC4 | Context hook blocks at 80% with `decomposing` status | ✅ Context hook |
| AC5 | Handoff hook creates new WorkflowRun | ✅ `register_handoff_capture_hook` |
| AC6 | Handoff hook marks original `handed_off` | ✅ Handoff hook |
| AC7 | Cost hook blocks execution with `budget_exceeded` | ✅ `register_cost_budget_hook` |
| AC8 | Unknown models fall back to DEFAULT_THRESHOLD | ✅ `iteration_threshold_for_model` |
| AC9 | Hook errors caught and logged | ✅ Wrapped in begin/rescue |
| AC10 | All warnings recorded in metadata | ✅ All hooks update metadata |
| AC11 | AgentAssemblyService integrates hook registration | ✅ `build_hook_manager` |
| AC12 | `rails test` — zero failures | ✅ Test suite planned |

---

## 8. Next Steps

1. **Submit to Architect** for review and amendments
2. **Re-read plan** after Architect approval (may have amendments)
3. **Implement** per approved plan
4. **Run Pre-QA** checklist
5. **Submit to QA** for scoring (target: ≥90)

---

## Architect Review & Amendments

**Reviewer:** Architect Agent  
**Date:** 2026-03-07  
**Verdict:** PLAN-REVISE

---

### Summary Assessment

The plan demonstrates a solid understanding of the PRD requirements and correctly identifies all 4 hooks, the configuration module, the service structure, and the integration point in `AgentAssemblyService`. The file layout, threshold constants, and test checklist are well-organized.

**However, the plan has 6 BLOCKER issues that would cause runtime failures or silent no-ops.** All stem from incorrect assumptions about the gem's `HookManager` / `Runner` API — specifically the semantics of `blocked: true` and the event data key names. These must be corrected before implementation begins.

---

### Amendments Made (tracked for retrospective)

#### BLOCKER #1: `on_tool_called` hook `blocked: true` does NOT stop the agent run

**Problem:** The plan assumes returning `HookResult(blocked: true)` from `on_tool_called` at 2× threshold will "stop execution." It does NOT. In `Runner#execute_single_tool` (line 337), `blocked: true` returns `"Tool execution blocked"` as the *tool result string*, but the runner loop continues to the next iteration. The agent will keep running with every subsequent tool call returning "Tool execution blocked" — a degenerate loop, not a clean stop.

**Fix:** The iteration budget hook MUST NOT use `on_tool_called`'s `blocked` to stop the run. Instead, at 2× threshold:
1. Update `WorkflowRun` status to `iteration_limit`
2. Return `HookResult(blocked: true)` to block the individual tool call (this is still useful as a signal)
3. **Also** — the DispatchService's `execute_agent` method already checks `workflow_run.status` after `runner.run()` completes. The real stop mechanism is that the blocked tool calls will cause the LLM to eventually finish (no productive tool use possible). This is an acceptable degraded stop for Epic 1.
4. **Alternative (preferred):** Register an ADDITIONAL hook on `:on_agent_started` that checks iteration count. But since `on_agent_started` fires only once, this won't work. The pragmatic Epic 1 approach: at 2× threshold, block all tool calls via `on_tool_called` and set the status. The agent will exhaust `max_iterations` or stop when LLM returns no tool calls. Document this limitation — clean cancellation requires Epic 2 runner enhancements.

**Impact:** The plan's claim that `block_at_double_threshold` "stops execution" is misleading. Update the plan comments and test assertions to reflect that `blocked: true` on `on_tool_called` blocks individual tool calls, not the entire run. The `iteration_limit` status is the real signal for downstream consumers.

#### BLOCKER #2: `on_cost_budget_exceeded` semantics are INVERTED

**Problem:** In `Runner#check_compaction` (line 475):
```ruby
return :stop unless cost_hook_result&.blocked
```
This means: if the hook returns `blocked: true`, the runner **continues** (does NOT stop). If the hook returns `blocked: false` or `nil`, the runner stops. The plan's cost hook returns `blocked: true` — which would **prevent** the default stop and let the agent keep running, the exact opposite of what the PRD wants.

**Fix:** The cost budget hook MUST return `HookResult(blocked: false)` (or return `nil`). This allows the runner's default `:stop` to take effect. The hook should still update `WorkflowRun` status and metadata — those are side effects, not blocking signals. The `blocked` field on `on_cost_budget_exceeded` means "I've handled this, skip default stop behavior."

**This is the most dangerous bug** — it would silently allow cost-exceeded runs to continue burning money.

#### BLOCKER #3: `on_token_budget_warning` event data key is `usage_percentage`, not `percentage`

**Problem:** The runner fires `on_token_budget_warning` (line 497-510) with this event data:
```ruby
{
  tier:                 tier,
  usage_percentage:     @token_budget_tracker.usage_percentage,
  remaining_tokens:     @token_budget_tracker.remaining_tokens,
  state_snapshot:       snapshot,
  cumulative_cost:      ...,
  last_message_cost:    ...,
  cost_budget:          ...,
  cost_budget_exceeded: ...
}
```
The plan reads `event_data[:percentage]` — this key does not exist. The hook will always get `nil`, skip the check, and context pressure will never be detected.

**Fix:** Change `event_data[:percentage]` to `event_data[:usage_percentage]` throughout the context pressure hook.

**Additionally:** The `on_token_budget_warning` hook's `blocked: true` means "skip default compaction strategy, I'm handling it." At 80%, this is correct — the PRD wants to prevent default compaction and instead signal decomposition. At 60%, the hook should return `HookResult(blocked: false)` so the default compaction can still run while the status is marked `at_risk`.

#### BLOCKER #4: Handoff hook event data key mismatch — `handoff_prompt`, not `continuation_prompt`

**Problem:** The gem's `HandoffStrategy#trigger_handoff_hook` (line 248-261) fires `on_handoff_created` with:
```ruby
{
  original_task_id: original_task_id,
  new_task_id:      handoff_task[:id],
  handoff_prompt:   handoff_task[:prompt],
  state_snapshot:   state_snapshot,
  context_files:    handoff_task[:context_files]
}
```
The plan reads `event_data[:continuation_prompt]` and `event_data[:task_id]`. These keys don't exist in the event data. The correct keys are `event_data[:handoff_prompt]` and `event_data[:original_task_id]` / `event_data[:new_task_id]`.

**Fix:** Update the handoff hook to use the correct keys from the gem's event data.

#### BLOCKER #5: Cost hook event data key mismatch — `cumulative_cost` / `cost_budget`, not `total_cost` / `budget`

**Problem:** The runner fires `on_cost_budget_exceeded` (line 466-474) with:
```ruby
{
  cumulative_cost:    @token_budget_tracker.cumulative_cost,
  cost_budget:        @token_budget_tracker.cost_budget,
  last_message_cost:  @token_budget_tracker.last_message_cost
}
```
The plan's cost hook reads `event_data[:total_cost]` and `event_data[:budget]` — wrong keys. Tests also assert on `total_cost` and `budget`.

**Fix:** Use `event_data[:cumulative_cost]` and `event_data[:cost_budget]` in the hook and test assertions. Also capture `event_data[:last_message_cost]` in metadata.

#### BLOCKER #6: Missing `begin/rescue` error wrapping in hook blocks

**Problem:** The PRD requires (AC9) that hook errors do not crash the runner. The AC table claims "✅ Wrapped in begin/rescue" but the actual hook code in the plan has NO begin/rescue blocks. While the gem's `safe_trigger_hook` catches exceptions for the cost and token budget hooks, `on_tool_called` uses `trigger_hook` (not `safe_trigger_hook`) — see Runner line 336. An exception in the iteration budget hook block (e.g., from `@workflow_run.save!`) WILL propagate up and crash the tool execution.

**Fix:** Every hook block MUST be wrapped in `begin ... rescue StandardError => e; Rails.logger.error(...); nil; end`. Do not rely on the runner to catch exceptions — only some hooks use `safe_trigger_hook`.

#### ISSUE #7: Test setup uses fixtures, project uses FactoryBot — **BLOCKER**

**Problem:** Tests call `projects(:ror)` and `team_memberships(:rails_lead)` — these are fixture references. The project has no fixtures; it uses FactoryBot exclusively (confirmed by existing test patterns in `postgres_bus_test.rb`, `dispatch_service_test.rb`, etc.).

**Fix:** Use FactoryBot `create(:project)`, `create(:agent_team, project:)`, `create(:team_membership, agent_team:)`, `create(:workflow_run, ...)` pattern. Tests must extend `ActiveSupport::TestCase` (not `Minitest::Test`) to get Rails transactional test support and FactoryBot methods.

#### ISSUE #8: `test_handoff_hook_links_original_and_continuation` references undefined variable `new_run` — **BLOCKER**

**Problem:** The test method accesses `new_run.id` on line `assert_equal new_run.id.to_s, @workflow_run.metadata["handed_off_to"]` but `new_run` is never defined in that test method. It's a local variable from a different test.

**Fix:** Query `WorkflowRun.last` or find the continuation run by metadata to get the `new_run` reference.

#### ISSUE #9: Redundant `update!` + `save!` calls — **SUGGESTION**

**Problem:** Multiple hooks call `@workflow_run.update!(...)` followed by `@workflow_run.save!`. `update!` already persists to the database — the subsequent `save!` is redundant. In the handoff hook, `update!` is called and then `save!` again. In the context pressure hook at 60%, `.metadata` is assigned then `.save!` is called — but if `update!` was already called for status, the metadata changes aren't included in that update.

**Fix:** Use a single `@workflow_run.update!(status: ..., metadata: @workflow_run.metadata.merge(...))` pattern consistently. Or modify attributes and call `save!` once at the end.

#### ISSUE #10: Integration test #16 (`test_hooks_record_activity_in_metadata`) has logic error — **SUGGESTION**

**Problem:** The test triggers `threshold - 1` tool calls, which is below the warning threshold. At threshold-1, no warnings are recorded yet (warnings start at exactly threshold). The assertion `assert @workflow_run.metadata["iteration_warnings"].is_a?(Array)` will fail.

**Fix:** Trigger exactly `threshold` calls to get the first warning, or assert that metadata does NOT contain warnings after `threshold - 1` calls (which is a valid "below threshold" test, just rename it).

#### ISSUE #11: Idempotency test is weak and tests an implementation detail — **SUGGESTION**

**Problem:** The test checks `@hooks_registered` ivar, which is an implementation detail. It doesn't verify that double-calling doesn't register duplicate handlers (the actual concern).

**Fix:** Test that triggering `on_tool_called` after double-registration increments the iteration counter only once per call (not twice). Or check `@hook_manager`'s handler count for the event (if exposed).

#### ISSUE #12: Missing test for context hook with missing percentage payload — **SUGGESTION**

**Problem:** The PRD's error scenarios specify: "Token budget warning payload missing percentage → Skip context pressure check, log warning." The plan's Error Path Matrix lists this but there's no corresponding test in the test checklist.

**Fix:** Add test #15 (renumber integration tests): "Context hook with missing usage_percentage in payload → no action, no error."

#### ISSUE #13: `on_token_budget_warning` hook needs `begin/rescue` on the `next unless` path — **FYI**

**Problem:** The context hook uses `next unless percentage` to skip when payload is missing. This is correct control flow but should also be wrapped in `begin/rescue` for robustness per the pattern in BLOCKER #6.

---

### Items the Plan Got Right (No Changes Required)

1. **File layout** — `orchestrator_hooks.rb` for constants, `orchestrator_hooks_service.rb` for the service is clean separation.
2. **Threshold configuration** — `ITERATION_THRESHOLDS` hash with `.fetch(model_name, DEFAULT_THRESHOLD)` is correct and follows the PRD exactly.
3. **`OrchestratorHooks.iteration_threshold_for_model` helper** — Good encapsulation, makes testing easy.
4. **`AgentAssemblyService` integration** — The `build_hook_manager` modification is minimal and correct. The TODO comment replacement is clean.
5. **Test coverage scope** — 14 unit tests + 2 integration tests cover all PRD acceptance criteria. The numbering and MUST-IMPLEMENT markers are correct.
6. **Error Path Matrix** — Complete and aligned with PRD error scenarios.
7. **No migrations needed** — Correct; all data lives in existing `metadata` JSONB column and `status` enum (all required statuses already exist in the model).
8. **Pre-QA Checklist acknowledgment** — Present and complete.
9. **Idempotency approach via `@hooks_registered` flag** — The concept is sound (even though the test is weak).

---

### Architecture Notes for Implementer

1. **Understand `blocked` semantics per hook event.** This is the #1 source of bugs in this plan. `blocked: true` means different things depending on which event:
   - `on_tool_called`: blocks the individual tool call, returns "Tool execution blocked" string. Runner loop continues.
   - `on_token_budget_warning`: tells the runner "I'm handling compaction, skip the default strategy." Runner continues without compacting.
   - `on_cost_budget_exceeded`: tells the runner "I've handled the cost issue, don't use default :stop." Runner continues (!!). Return `blocked: false` or `nil` to let the default :stop work.
   - `on_handoff_created`: standard — blocked means "cancel the handoff" (not relevant here).

2. **Always read the gem source for event data keys.** The exact keys passed to each hook are in:
   - `on_tool_called`: `{ tool_name:, arguments: }` — Runner line 336
   - `on_token_budget_warning`: `{ tier:, usage_percentage:, remaining_tokens:, state_snapshot:, cumulative_cost:, last_message_cost:, cost_budget:, cost_budget_exceeded: }` — Runner line 499-508
   - `on_cost_budget_exceeded`: `{ cumulative_cost:, cost_budget:, last_message_cost: }` — Runner line 468-472
   - `on_handoff_created`: `{ original_task_id:, new_task_id:, handoff_prompt:, state_snapshot:, context_files: }` — CompactionStrategy line 253-259

3. **Use `ActiveSupport::TestCase`**, not `Minitest::Test`. This gives you transactional fixtures, FactoryBot `create()`, and Rails test helpers. All existing service tests in the project use this pattern.

4. **Wrap every hook block in begin/rescue.** Pattern:
   ```ruby
   @hook_manager.on(:on_tool_called) do |event_data, context|
     begin
       # ... hook logic ...
     rescue StandardError => e
       Rails.logger.error("[OrchestratorHooks] on_tool_called error: #{e.message}")
       nil  # return nil = non-blocking
     end
   end
   ```

5. **The `on_cost_budget_exceeded` hook fires ONLY when `token_budget_tracker` is present and `cost_budget > 0`.** Currently, `AgentAssemblyService` passes `token_budget_tracker: nil` to the Runner (see line 32: TODO comment). **This means the cost hook and token budget warning hook will NEVER fire until `AgentAssemblyService` is updated to create a `TokenBudgetTracker`.** The plan should include this integration — add a `build_token_budget_tracker` method to `AgentAssemblyService` that reads `profile.context_window`, `profile.cost_budget`, and `profile.context_compacting_threshold` to create the tracker. Without this, AC3, AC4, and AC7 cannot be verified at runtime. (For unit tests, you can mock/stub the hook trigger directly, but for integration tests this gap matters.)

6. **Consider adding `build_token_budget_tracker` and `build_compaction_strategy` to `AgentAssemblyService`** as a companion change. The factory method already has TODOs for this (lines 32-33). Without the tracker, 3 of the 4 hooks will never fire in a real dispatch. This is a natural companion to PRD-1-05.

7. **The `metadata` column is JSONB.** In-place mutation like `@workflow_run.metadata["key"] = value` followed by `@workflow_run.save!` works because Rails tracks JSONB changes. But `@workflow_run.update!(metadata: merged_hash)` is safer and more explicit. Be consistent.

8. **Test the actual `HookManager` trigger/return contract.** In your tests, actually call `@hook_manager.trigger(:event, data, context)` and assert on the returned `HookResult`. Don't just check side effects — verify the hook returns the correct blocked/not-blocked signal.

---

PLAN-REVISE

**Required before re-submission:**
- Fix all 8 BLOCKER issues (#1-#8)
- Address SUGGESTION issues #10-#12 (test correctness)
- Decide on `TokenBudgetTracker` integration (Architecture Note #5-#6)

---

**Plan Status:** PLAN-REVISE  
**Estimated Effort:** 0.5 week (unchanged — fixes are design corrections, not scope additions)  
**Developer:** Rails Lead (DeepSeek Reasoner)

---

## Architect Re-Review & Amendments (Round 2)

**Reviewer:** Architect Agent  
**Date:** 2026-03-08  
**Previous Review:** 2026-03-07 (PLAN-REVISE — 8 BLOCKERs)  
**Verdict:** PLAN-APPROVED (with mandatory amendments below)

---

### BLOCKER Resolution Verification

All 8 previously-identified BLOCKERs have been **correctly addressed**:

| # | Original BLOCKER | Fix Applied | Verified |
|---|-----------------|-------------|----------|
| 1 | `on_tool_called` `blocked:true` stops run | Comment now correctly states "runner will continue but tool calls will be blocked". `iteration_limit` status is the real signal. | ✅ |
| 2 | `on_cost_budget_exceeded` `blocked:true` prevents stop | Hook now returns `nil`. Runner's `return :stop unless cost_hook_result&.blocked` fires `:stop` correctly. | ✅ |
| 3 | `percentage` → `usage_percentage` | Line 138: `event_data[:usage_percentage]`. Matches gem's `TokenBudgetTracker#usage_percentage`. | ✅ |
| 4 | `continuation_prompt` → `handoff_prompt` | Line 179: `event_data[:handoff_prompt]`. Matches gem's `HandoffStrategy#trigger_handoff_hook`. | ✅ |
| 5 | `total_cost`/`budget` → `cumulative_cost`/`cost_budget`/`last_message_cost` | Lines 218-220: all three correct keys used. | ✅ |
| 6 | Missing `begin/rescue` wrapping | All 4 hooks now wrapped in `begin ... rescue StandardError => e`. | ✅ |
| 7 | Fixtures → FactoryBot | Setup uses `create(:project)`, `create(:agent_team, ...)`, extends `ActiveSupport::TestCase`. | ✅ |
| 8 | Undefined `new_run` variable | Line 459: queries `WorkflowRun.where("metadata->>'handed_off_from' = ?", ...)`. | ✅ |

---

### New Issues Found During Re-Review

#### BLOCKER #R2-1: `HookManager#trigger` NEVER returns `nil` — 3 tests will fail

**Problem:** Three tests assert `assert_nil result` after calling `@hook_manager.trigger(...)`:
- `test_context_hook_with_missing_usage_percentage_no_action` (line 420)
- `test_cost_hook_updates_status_and_returns_nil_to_stop` (line 495)
- `test_hook_errors_are_captured_and_logged` (line 532)

The hook handlers return `nil` from the block, which is correct. **However**, `HookManager#trigger` (gem source line 82-103) iterates handlers, skips non-`HookResult` returns via `next unless hook_result.is_a?(HookResult)`, and at the end **always** returns `HookResult.new(blocked: false, event: current_event, result: result)`. It NEVER returns `nil`.

So when a hook returns `nil`, `trigger` returns a `HookResult` with `blocked: false`. All three `assert_nil result` assertions will fail.

**Fix:** Replace `assert_nil result` with `refute result.blocked` in all three tests. This correctly validates the semantic intent (non-blocking return).

Specifically:
- Line 420: Change `assert_nil result` to `refute result.blocked`
- Line 495: Change `assert_nil result` to `refute result.blocked` (validates runner's `:stop` will fire)
- Line 532: Change `assert_nil result` to `refute result.blocked`

#### BLOCKER #R2-2: Error resilience test stubs wrong method

**Problem:** `test_hook_errors_are_captured_and_logged` (line 521) stubs `@workflow_run.stubs(:update!).raises(...)`. But the `on_tool_called` hook's FIRST database call is `@workflow_run.save!` (line 92), not `update!`. The stub on `update!` won't cause `save!` to raise, so the hook will execute normally (no error path tested).

**Fix:** Stub `save!` instead of (or in addition to) `update!`:
```ruby
@workflow_run.stubs(:save!).raises(ActiveRecord::StatementInvalid.new("simulated DB error"))
```

Note: `ActiveRecord::StatementInvalid` requires a message argument in Rails 8. The test should pass a message string.

#### SUGGESTION #R2-3: Handoff metadata integer/string type mismatch in test assertion

**Problem:** The handoff hook stores `new_run.id` (integer) in JSONB metadata at `"handed_off_to"`. After `reload`, `@workflow_run.metadata["handed_off_to"]` will be an integer (JSONB preserves numeric types). But the test at line 460 asserts:
```ruby
assert_equal new_run.id.to_s, @workflow_run.metadata["handed_off_to"]
```
This compares a string (`"5"`) to an integer (`5`). Minitest's `assert_equal` does strict comparison — this will fail.

**Fix:** Either:
- Store the id as a string: `"handed_off_to" => new_run.id.to_s` (recommended — consistent with the `handed_off_from` query pattern using `->>` which returns text)
- Or fix the assertion: `assert_equal new_run.id, @workflow_run.metadata["handed_off_to"]`

**Recommendation:** Store as string consistently. The `handed_off_from` value (`@workflow_run.id`) should also be stored as `.to_s` for consistency with the JSONB text query pattern used in the test (`metadata->>'handed_off_from' = ?`).

#### SUGGESTION #R2-4: Multiple `save!` calls per tool invocation — performance concern

**Problem:** The iteration budget hook calls `@workflow_run.save!` on EVERY tool call (line 92 — to persist iteration count), then potentially a second `save!` (line 105 — to persist warning). At 100 iterations for Grok models, that's 100+ unnecessary `save!` calls. The PRD states "No DB queries except the UPDATE on WorkflowRun" — multiple saves per hook call violates this spirit.

**Suggestion for implementer:** Consider tracking the iteration count in a local closure variable (not metadata) and only persisting to metadata at threshold crossings and at 2× threshold. Example:
```ruby
iteration_count = 0
@hook_manager.on(:on_tool_called) do |event_data, context|
  begin
    iteration_count += 1
    if iteration_count == threshold
      # Single save with warning
    elsif iteration_count == threshold * 2
      # Single update! with iteration_limit status
    end
  rescue ...
  end
end
```
This reduces DB writes from O(n) to O(1) — only 2 writes total (at threshold and at 2×).

**Note:** This is a SUGGESTION, not a BLOCKER. The current approach works but is suboptimal for long-running agents. The implementer may defer this optimization if preferred.

#### SUGGESTION #R2-5: Iteration warning metadata uses symbol keys, JSONB returns string keys

**Problem:** The warning hash at lines 101-104 uses symbol keys:
```ruby
{ iteration: current_count, timestamp: Time.now.to_s }
```
After JSONB round-trip (save → reload), these become string keys: `{"iteration" => 30, "timestamp" => "..."}`. The test at line 303 asserts:
```ruby
assert_equal threshold, warnings[0]["iteration"]
```
This works correctly because the test reads with string keys. But the code is inconsistent — some places use symbol keys in the hash literal (e.g., `iteration:`, `timestamp:`, `usage_percentage:` in context_warning) while tests read with string keys. This works but is fragile.

**Suggestion:** Use string keys consistently when building metadata hashes to match what JSONB returns:
```ruby
{ "iteration" => current_count, "timestamp" => Time.now.to_s }
```

---

### Items the Plan Got Right (No Changes Required)

1. **All 8 original BLOCKERs correctly fixed** — demonstrates understanding of gem API semantics.
2. **Hook block semantics are now correct:**
   - `on_tool_called`: `blocked: true` → blocks individual tool call (correct)
   - `on_token_budget_warning` at 80%: `blocked: true` → prevents default compaction (correct)
   - `on_token_budget_warning` at 60%: `blocked: false` → allows default compaction (correct)
   - `on_cost_budget_exceeded`: returns `nil` → runner's default `:stop` takes effect (correct)
   - `on_handoff_created`: `blocked: false` → standard non-blocking side effect (correct)
3. **Event data keys match gem source** for all 4 hooks — verified against Runner and CompactionStrategy source.
4. **Error wrapping pattern** is clean and consistent across all 4 hooks.
5. **FactoryBot setup** follows existing project patterns (`postgres_bus_test.rb`, `agent_assembly_service_test.rb`).
6. **Integration tests** are meaningful — low-threshold test, activity recording test, below-threshold test.
7. **AgentAssemblyService integration** is minimal and correct.
8. **Test coverage** is comprehensive: 15 unit + 3 integration = 18 tests covering all 12 ACs.
9. **Handoff hook variable resolution** — querying by JSONB `metadata->>'handed_off_from'` is a sound approach.
10. **Idempotency test** properly exercises the `@hooks_registered` flag behavior.

---

### Architecture Notes for Implementer

1. **Fix the 2 BLOCKERs before coding:**
   - Replace all `assert_nil result` with `refute result.blocked` in tests where hooks return `nil` from block (3 locations)
   - Stub `save!` instead of `update!` in error resilience test

2. **`HookManager#trigger` return contract:** Always returns a `HookResult`, never `nil`. When a handler block returns `nil`, the trigger skips it and returns `HookResult.new(blocked: false, ...)`. Test assertions must account for this.

3. **TokenBudgetTracker gap (carried forward from Round 1, Architecture Note #5):** `AgentAssemblyService` currently passes `token_budget_tracker: nil` to Runner. This means `check_compaction` returns `:continue` immediately — `on_token_budget_warning` and `on_cost_budget_exceeded` hooks will NEVER fire in a real dispatch. For unit tests this is fine (you trigger hooks directly). For a full integration test with the Runner, you'd need to instantiate a `TokenBudgetTracker`. The implementer should add a `# TODO: Wire up TokenBudgetTracker in AgentAssemblyService for real cost/context tracking` comment in the `build_hook_manager` method to track this gap. It can be addressed as a separate follow-up task.

4. **The `on_tool_called` hook uses `trigger_hook` (not `safe_trigger_hook`)** in the Runner. This means exceptions in the hook block WILL propagate into `execute_single_tool`, which has its own `rescue StandardError => e` returning `"Tool error: #{e.message}"`. So even without the `begin/rescue` in the hook block, tool-call hook errors wouldn't crash the runner — they'd be caught by `execute_single_tool`'s rescue. However, the `begin/rescue` in the hook is still correct and desirable: it provides cleaner error messages, prevents the error from being returned as a tool result, and follows the PRD's AC9 requirement.

5. **JSONB metadata mutation:** The plan uses both in-place mutation (`@workflow_run.metadata["key"] = value` + `save!`) and merge-update (`update!(metadata: @workflow_run.metadata.merge(...))`) patterns. Rails 8 tracks JSONB attribute changes correctly for both patterns. The implementer should pick one pattern and be consistent — the `update!(status: ..., metadata: merged_hash)` pattern is preferred because it's a single atomic DB write.

---

### Amendments Made (tracked for retrospective)

1. **[IDENTIFIED]** BLOCKER #R2-1: Three test assertions use `assert_nil result` but `HookManager#trigger` always returns `HookResult`. Must use `refute result.blocked`.
2. **[IDENTIFIED]** BLOCKER #R2-2: Error resilience test stubs `update!` but hook calls `save!` first. Must stub `save!`.
3. **[IDENTIFIED]** SUGGESTION #R2-3: Handoff metadata stores integer ids but test compares with `.to_s`. Recommend storing as strings consistently.
4. **[IDENTIFIED]** SUGGESTION #R2-4: O(n) DB writes in iteration hook. Suggest local counter variable for performance.
5. **[IDENTIFIED]** SUGGESTION #R2-5: Mixed symbol/string keys in metadata hashes. Suggest string keys for JSONB consistency.

### Items Requiring Lead Action

**MUST-FIX (2 BLOCKERs):**
- Fix BLOCKER #R2-1: Replace `assert_nil result` → `refute result.blocked` in 3 test methods
- Fix BLOCKER #R2-2: Stub `save!` (not `update!`) in error resilience test

**SHOULD-FIX (3 SUGGESTIONs):**
- Address #R2-3: Use `.to_s` on ids stored in metadata, or fix assertion types
- Consider #R2-4: Local iteration counter to reduce DB writes
- Consider #R2-5: Consistent string keys in metadata hashes

**The Lead may apply these fixes during implementation without re-submitting the plan for review.**

---

PLAN-APPROVED

---

**Plan Status:** PLAN-APPROVED (with 2 mandatory amendments — implementer may apply during coding)  
**Estimated Effort:** 0.5 week (unchanged)  
**Developer:** Rails Lead (DeepSeek Reasoner)  
**Next Step:** Implement per approved plan, applying the 2 mandatory BLOCKER fixes and 3 SUGGESTIONs during coding
