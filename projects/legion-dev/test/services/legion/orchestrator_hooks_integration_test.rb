# frozen_string_literal: true

require "test_helper"

module Legion
  class OrchestratorHooksIntegrationTest < ActiveSupport::TestCase
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
    end

    teardown do
      @workflow_run&.destroy
    end

    def test_full_dispatch_with_low_iteration_limit
      # Set a very low threshold via config override
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

      # Trigger some activity
      threshold = OrchestratorHooks.iteration_threshold_for_model("deepseek-reasoner")
      threshold.times { hook_manager.trigger(:on_tool_called, {}, {}) }

      @workflow_run.reload
      assert @workflow_run.metadata["iteration_warnings"].is_a?(Array)
      assert @workflow_run.metadata.key?("iteration_count")
    end

    def test_hooks_no_warnings_below_threshold
      hook_manager = AgentDesk::Hooks::HookManager.new
      OrchestratorHooksService.call(
        hook_manager: hook_manager,
        workflow_run: @workflow_run,
        team_membership: @team_membership
      )

      # Trigger below threshold
      threshold = OrchestratorHooks.iteration_threshold_for_model("deepseek-reasoner")
      (threshold - 1).times { hook_manager.trigger(:on_tool_called, {}, {}) }

      @workflow_run.reload
      refute @workflow_run.metadata.key?("iteration_warnings")
    end
  end
end
