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

    teardown do
      @workflow_run&.destroy
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

    def test_iteration_hook_uses_model_specific_threshold
      @team_membership.config["model"] = "deepseek-chat"
      @team_membership.save!

      threshold = OrchestratorHooks::ITERATION_THRESHOLDS["deepseek-chat"]
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

      threshold = OrchestratorHooks::DEFAULT_THRESHOLD
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

    # Context Pressure Hook Tests
    def test_context_hook_at_60_percent_marks_at_risk
      OrchestratorHooksService.call(
        hook_manager: @hook_manager,
        workflow_run: @workflow_run,
        team_membership: @team_membership
      )

      @workflow_run.update!(status: :running)
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

      @workflow_run.update!(status: :running)
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

      # Hook returns nil (skips handler), so result reflects no blocking
      refute result.blocked
      assert_equal "running", @workflow_run.reload.status
    end

    # Handoff Capture Hook Tests
    def test_handoff_hook_creates_new_workflow_run
      # Register hooks fresh for this test
      @hook_manager = AgentDesk::Hooks::HookManager.new

      # Debug: check handlers before call
      OrchestratorHooksService.call(
        hook_manager: @hook_manager,
        workflow_run: @workflow_run,
        team_membership: @team_membership
      )

      before_count = WorkflowRun.count
      handoff_prompt = "Continue with next task"

      result = @hook_manager.trigger(
        :on_handoff_created,
        { handoff_prompt: handoff_prompt, new_task_id: "task-123" },
        {}
      )

      after_count = WorkflowRun.count
      assert_equal before_count + 1, after_count, "Should have created one new WorkflowRun"

      # Find the new run by ID range (newer runs have higher IDs)
      new_run = WorkflowRun.where("id > ?", @workflow_run.id).first
      assert new_run, "Expected a new WorkflowRun to be created"
      assert_equal handoff_prompt, new_run.prompt
      assert_equal "queued", new_run.status

      # Verify original run was updated
      @workflow_run.reload
      assert_equal "handed_off", @workflow_run.status
    end

    def test_handoff_hook_links_original_and_continuation
      # Register hooks fresh for this test
      @hook_manager = AgentDesk::Hooks::HookManager.new
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
      assert @workflow_run.metadata.key?("handed_off_to")

      # Find the new run by ID range (newer runs have higher IDs)
      new_run = WorkflowRun.where("id > ?", @workflow_run.id).first
      assert new_run, "Expected a new WorkflowRun to be created"

      assert_equal @workflow_run.id.to_s, new_run.reload.metadata["handed_off_from"]
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
    def test_cost_hook_blocks_and_updates_status
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

      assert_equal "budget_exceeded", @workflow_run.reload.status
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
      assert cost_data.is_a?(Hash), "cost_exceeded should be a Hash"
      assert_equal 10.50, cost_data["cumulative_cost"].to_f
      assert_equal 10.00, cost_data["cost_budget"].to_f
      assert_equal 0.50, cost_data["last_message_cost"].to_f
    end

    # Error Resilience Tests
    def test_hook_errors_do_not_crash_runner
      # Simulate DB failure during hook
      @workflow_run.stubs(:update!).raises(ActiveRecord::StatementInvalid)

      OrchestratorHooksService.call(
        hook_manager: @hook_manager,
        workflow_run: @workflow_run,
        team_membership: @team_membership
      )

      # Hook should not raise exception (returns nil)
      result = @hook_manager.trigger(:on_tool_called, {}, {})
      assert result.is_a?(AgentDesk::Hooks::HookResult)
    end
  end
end
