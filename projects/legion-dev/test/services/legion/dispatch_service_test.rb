# frozen_string_literal: true

require "test_helper"

module Legion
  class DispatchServiceTest < ActiveSupport::TestCase
    setup do
      @project = create(:project)
      @team = create(:agent_team, project: @project)
      @membership = create(:team_membership, agent_team: @team)
      @prompt = "Test prompt"
      @project_path = @project.path

      # Stub external gem calls
      AgentDesk::Rules::RulesLoader.stubs(:load_rules_content).returns("rules content")
      AgentDesk::Prompts::PromptsManager.stubs(:system_prompt).returns("system prompt")
      AgentDesk::Tools::PowerTools.stubs(:create).returns(AgentDesk::Tools::ToolSet.new)
      AgentDesk::Skills::SkillLoader.any_instance.stubs(:activate_skill_tool).returns(stub(full_name: "skills---activate_skill"))
      AgentDesk::Tools::TodoTools.stubs(:create).returns(AgentDesk::Tools::ToolSet.new)
      AgentDesk::Tools::MemoryTools.stubs(:create).returns(AgentDesk::Tools::ToolSet.new)
      AgentDesk::Models::ModelManager.stubs(:new).returns(mock)
      Legion::PostgresBus.stubs(:new).returns(mock)
      AgentDesk::Hooks::HookManager.stubs(:new).returns(mock)
      AgentDesk::Tools::ApprovalManager.stubs(:new).returns(mock)
      AgentDesk::Agent::Runner.stubs(:new).returns(mock)

      # Default stub for AgentAssemblyService.call to prevent real assembly in tests that don't stub it
      default_runner = mock
      default_runner.stubs(:run)
      default_profile = mock
      default_profile.stubs(:id).returns("default")
      default_profile.stubs(:name).returns("default")
      default_profile.stubs(:provider).returns("default")
      default_profile.stubs(:model).returns("default")
      default_profile.stubs(:max_iterations).returns(100)
      Legion::AgentAssemblyService.stubs(:call).returns({
        runner: default_runner,
        system_prompt: "default",
        tool_set: mock,
        profile: default_profile,
        message_bus: mock
      })
    end

    test "finds team and agent by name" do
      DispatchService.call(
        team_name: @team.name,
        agent_identifier: @membership.config["name"],
        prompt: @prompt,
        project_path: @project_path
      )

      assert WorkflowRun.last
    end

    test "creates WorkflowRun with correct initial status" do
      assert_difference "WorkflowRun.count", 1 do
        DispatchService.call(
          team_name: @team.name,
          agent_identifier: @membership.config["id"],
          prompt: @prompt,
          project_path: @project_path
        )
      end

      run = WorkflowRun.last
      assert_equal @project, run.project
      assert_equal @membership, run.team_membership
      assert_equal @prompt, run.prompt
      assert_equal "completed", run.status
    end

    test "calls AgentAssemblyService" do
      mock_profile = mock
      mock_profile.stubs(:id).returns("test")
      mock_profile.stubs(:name).returns("test")
      mock_profile.stubs(:provider).returns("test")
      mock_profile.stubs(:model).returns("test")
      mock_profile.stubs(:max_iterations).returns(100)

      mock_runner = mock
      mock_runner.expects(:run).returns(nil)

      mock_result = {
        runner: mock_runner,
        system_prompt: "prompt",
        tool_set: mock,
        profile: mock_profile,
        message_bus: mock
      }

      AgentAssemblyService.stubs(:call).returns(mock_result)

      DispatchService.call(
        team_name: @team.name,
        agent_identifier: @membership.config["id"],
        prompt: @prompt,
        project_path: @project_path
      )
    end

    test "calls Runner.run with correct arguments" do
      mock_profile = mock
      mock_profile.stubs(:id).returns(@membership.config["id"])
      mock_profile.stubs(:name).returns("test")
      mock_profile.stubs(:provider).returns("test")
      mock_profile.stubs(:model).returns("test")
      mock_profile.stubs(:max_iterations).returns(@membership.config["maxIterations"])

      mock_runner = mock
      mock_runner.expects(:run).with(
        prompt: @prompt,
        system_prompt: "test prompt",
        tool_set: anything,
        profile: mock_profile,
        project_dir: @project_path,
        agent_id: @membership.config["id"],
        task_id: nil,
        max_iterations: @membership.config["maxIterations"]
      )

      AgentAssemblyService.stubs(:call).returns({
        runner: mock_runner,
        system_prompt: "test prompt",
        tool_set: mock,
        profile: mock_profile,
        message_bus: mock
      })

      DispatchService.call(
        team_name: @team.name,
        agent_identifier: @membership.config["id"],
        prompt: @prompt,
        project_path: @project_path
      )
    end

    test "updates WorkflowRun on success" do
      mock_runner = mock
      mock_runner.stubs(:run)

      mock_profile = mock
      mock_profile.stubs(:id).returns("test")
      mock_profile.stubs(:name).returns("test")
      mock_profile.stubs(:provider).returns("test")
      mock_profile.stubs(:model).returns("test")
      mock_profile.stubs(:max_iterations).returns(100)

      AgentAssemblyService.stubs(:call).returns({
        runner: mock_runner,
        system_prompt: "prompt",
        tool_set: mock,
        profile: mock_profile,
        message_bus: mock
      })

      DispatchService.call(
        team_name: @team.name,
        agent_identifier: @membership.config["id"],
        prompt: @prompt,
        project_path: @project_path
      )

      run = WorkflowRun.last
      assert_equal "completed", run.status
      assert run.duration_ms
      assert_equal 0, run.iterations # mocked
    end

    test "updates WorkflowRun on failure" do
      mock_runner = mock
      mock_runner.expects(:run).raises(StandardError.new("test error"))

      mock_profile = mock
      mock_profile.stubs(:id).returns("test")
      mock_profile.stubs(:name).returns("test")
      mock_profile.stubs(:provider).returns("test")
      mock_profile.stubs(:model).returns("test")
      mock_profile.stubs(:max_iterations).returns(100)

      AgentAssemblyService.stubs(:call).returns({
        runner: mock_runner,
        system_prompt: "prompt",
        tool_set: mock,
        profile: mock_profile,
        message_bus: mock
      })

      assert_raises StandardError do
        DispatchService.call(
          team_name: @team.name,
          agent_identifier: @membership.config["id"],
          prompt: @prompt,
          project_path: @project_path
        )
      end

      run = WorkflowRun.last
      assert_equal "failed", run.status
      assert_equal "test error", run.error_message
    end

    test "agent identifier matching by id" do
      DispatchService.call(
        team_name: @team.name,
        agent_identifier: @membership.config["id"],
        prompt: @prompt,
        project_path: @project_path
      )

      assert WorkflowRun.last
    end

    test "agent identifier matching by name case-insensitive partial" do
      partial_name = @membership.config["name"][0..2].downcase
      DispatchService.call(
        team_name: @team.name,
        agent_identifier: partial_name,
        prompt: @prompt,
        project_path: @project_path
      )

      assert WorkflowRun.last
    end

    test "raises TeamNotFoundError when team not found" do
      assert_raises DispatchService::TeamNotFoundError do
        DispatchService.call(
          team_name: "nonexistent",
          agent_identifier: @membership.config["id"],
          prompt: @prompt,
          project_path: @project_path
        )
      end
    end

    test "raises AgentNotFoundError when agent not found" do
      assert_raises DispatchService::AgentNotFoundError do
        DispatchService.call(
          team_name: @team.name,
          agent_identifier: "nonexistent",
          prompt: @prompt,
          project_path: @project_path
        )
      end
    end

    test "handles Interrupt and updates WorkflowRun" do
      mock_runner = mock
      mock_runner.expects(:run).raises(Interrupt)

      mock_profile = mock
      mock_profile.stubs(:id).returns("test")
      mock_profile.stubs(:name).returns("test")
      mock_profile.stubs(:provider).returns("test")
      mock_profile.stubs(:model).returns("test")
      mock_profile.stubs(:max_iterations).returns(100)

      AgentAssemblyService.stubs(:call).returns({
        runner: mock_runner,
        system_prompt: "prompt",
        tool_set: mock,
        profile: mock_profile,
        message_bus: mock
      })

      assert_raises Interrupt do
        DispatchService.call(
          team_name: @team.name,
          agent_identifier: @membership.config["id"],
          prompt: @prompt,
          project_path: @project_path
        )
      end

      run = WorkflowRun.last
      assert_equal "failed", run.status
      assert_equal "interrupted by user", run.error_message
    end

    test "overrides max_iterations when provided" do
      mock_runner = mock
      mock_runner.expects(:run).with(
        has_entry(max_iterations: 5)
      )

      mock_profile = mock
      mock_profile.stubs(:id).returns("test")
      mock_profile.stubs(:name).returns("test")
      mock_profile.stubs(:provider).returns("test")
      mock_profile.stubs(:model).returns("test")
      mock_profile.stubs(:max_iterations).returns(100)

      AgentAssemblyService.stubs(:call).returns({
        runner: mock_runner,
        system_prompt: "prompt",
        tool_set: mock,
        profile: mock_profile,
        message_bus: mock
      })

      DispatchService.call(
        team_name: @team.name,
        agent_identifier: @membership.config["id"],
        prompt: @prompt,
        project_path: @project_path,
        max_iterations: 5
      )
    end
  end
end
