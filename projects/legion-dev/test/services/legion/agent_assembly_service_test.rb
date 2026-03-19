# frozen_string_literal: true

require "test_helper"

module Legion
  class AgentAssemblyServiceTest < ActiveSupport::TestCase
    setup do
      @project = create(:project)
      @team = create(:agent_team, project: @project)
      @membership = create(:team_membership, agent_team: @team)
      @workflow_run = create(:workflow_run, project: @project, team_membership: @membership)
      @project_dir = @project.path

      # Stub external gem calls
      AgentDesk::Rules::RulesLoader.any_instance.stubs(:load_rules_content).returns("rules content")
      AgentDesk::Prompts::PromptsManager.any_instance.stubs(:system_prompt).returns("rendered prompt")
      AgentDesk::Tools::PowerTools.stubs(:create).returns(AgentDesk::Tools::ToolSet.new)
      AgentDesk::Skills::SkillLoader.any_instance.stubs(:activate_skill_tool).returns(stub(full_name: "skills---activate_skill"))
      AgentDesk::Tools::TodoTools.stubs(:create).returns(AgentDesk::Tools::ToolSet.new)
      AgentDesk::Tools::MemoryTools.stubs(:create).returns(AgentDesk::Tools::ToolSet.new)
      AgentDesk::Models::ModelManager.stubs(:new).returns(mock)
      Legion::PostgresBus.stubs(:new).returns(mock)
      AgentDesk::Hooks::HookManager.stubs(:new).returns(mock)
      AgentDesk::Tools::ApprovalManager.stubs(:new).returns(mock)
      AgentDesk::Agent::Runner.stubs(:new).returns(mock)
      Legion::OrchestratorHooksService.stubs(:call)
    end

    test "assembles Profile from TeamMembership config" do
      result = AgentAssemblyService.call(
        team_membership: @membership,
        project_dir: @project_dir,
        workflow_run: @workflow_run
      )

      assert_instance_of AgentDesk::Agent::Profile, result[:profile]
      assert_equal @membership.config["id"], result[:profile].id
    end

    test "loads rules via RulesLoader" do
      AgentDesk::Rules::RulesLoader.any_instance.expects(:load_rules_content).with(
        profile_dir_name: @membership.config["id"],
        project_dir: @project_dir
      ).returns("rules content")

      result = AgentAssemblyService.call(
        team_membership: @membership,
        project_dir: @project_dir,
        workflow_run: @workflow_run
      )

      assert result.key?(:system_prompt)
    end

    test "renders system prompt via PromptsManager" do
      rules_content = "test rules"
      AgentDesk::Rules::RulesLoader.any_instance.stubs(:load_rules_content).returns(rules_content)
      AgentDesk::Prompts::PromptsManager.any_instance.expects(:system_prompt).with(
        profile: instance_of(AgentDesk::Agent::Profile),
        project_dir: @project_dir,
        rules_content: rules_content,
        custom_instructions: @membership.config["customInstructions"]
      ).returns("rendered prompt")

      result = AgentAssemblyService.call(
        team_membership: @membership,
        project_dir: @project_dir,
        workflow_run: @workflow_run
      )

      assert_equal "rendered prompt", result[:system_prompt]
    end

    test "creates ToolSet with correct tools based on use_* flags" do
      @membership.config["usePowerTools"] = true
      @membership.config["useSkillsTools"] = true
      @membership.config["useTodoTools"] = true
      @membership.config["useMemoryTools"] = true
      @membership.save!

      AgentDesk::Tools::PowerTools.expects(:create).with(project_dir: @project_dir, profile: instance_of(AgentDesk::Agent::Profile)).returns(AgentDesk::Tools::ToolSet.new)
      AgentDesk::Skills::SkillLoader.any_instance.expects(:activate_skill_tool).with(project_dir: @project_dir).returns(stub(full_name: "skills---activate_skill"))
      AgentDesk::Tools::TodoTools.expects(:create).returns(AgentDesk::Tools::ToolSet.new)
      AgentDesk::Tools::MemoryTools.expects(:create).with(memory_store: instance_of(AgentDesk::Memory::MemoryStore), project_id: @membership.config["id"]).returns(AgentDesk::Tools::ToolSet.new)

      result = AgentAssemblyService.call(
        team_membership: @membership,
        project_dir: @project_dir,
        workflow_run: @workflow_run
      )

      assert_instance_of AgentDesk::Tools::ToolSet, result[:tool_set]
    end

    test "creates ModelManager with correct provider/model" do
      ENV["SMART_PROXY_TOKEN"] = "test_token"
      ENV["SMART_PROXY_URL"] = "http://test.com"

      AgentDesk::Models::ModelManager.expects(:new).with(
        has_entries(
          provider: @membership.config["provider"].to_sym,
          model: @membership.config["model"],
          api_key: "test_token",
          base_url: "http://test.com",
          timeout: 300
        )
      )

      AgentAssemblyService.call(
        team_membership: @membership,
        project_dir: @project_dir,
        workflow_run: @workflow_run
      )
    ensure
      ENV.delete("SMART_PROXY_TOKEN")
      ENV.delete("SMART_PROXY_URL")
    end

    test "creates PostgresBus with workflow_run" do
      Legion::PostgresBus.expects(:new).with(workflow_run: @workflow_run)

      AgentAssemblyService.call(
        team_membership: @membership,
        project_dir: @project_dir,
        workflow_run: @workflow_run
      )
    end

    test "creates ApprovalManager with tool_approvals from config" do
      @membership.config["toolApprovals"] = { "test_tool" => "ask" }
      @membership.save!

      AgentDesk::Tools::ApprovalManager.expects(:new).with(
        tool_approvals: @membership.config["toolApprovals"],
        auto_approve: true
      )

      AgentAssemblyService.call(
        team_membership: @membership,
        project_dir: @project_dir,
        workflow_run: @workflow_run
      )
    end

    test "returns all components needed for Runner" do
      result = AgentAssemblyService.call(
        team_membership: @membership,
        project_dir: @project_dir,
        workflow_run: @workflow_run
      )

      assert result.key?(:runner)
      assert result.key?(:system_prompt)
      assert result.key?(:tool_set)
      assert result.key?(:profile)
      assert result.key?(:message_bus)
    end

    test "passes compaction_strategy to Runner" do
      @membership.config["compactionStrategy"] = "handoff"
      @membership.save!

      AgentDesk::Agent::Runner.expects(:new).with(
        has_entry(compaction_strategy: :handoff)
      )

      AgentAssemblyService.call(
        team_membership: @membership,
        project_dir: @project_dir,
        workflow_run: @workflow_run
      )
    end

    test "interactive mode sets ask_user_block for ApprovalManager" do
      AgentDesk::Tools::ApprovalManager.expects(:new).with(
        tool_approvals: @membership.config["toolApprovals"],
        auto_approve: false
      )

      AgentAssemblyService.call(
        team_membership: @membership,
        project_dir: @project_dir,
        workflow_run: @workflow_run,
        interactive: true
      )
    end

    test "non-interactive mode auto-approves ASK tools" do
      AgentDesk::Tools::ApprovalManager.expects(:new).with(
        tool_approvals: @membership.config["toolApprovals"],
        auto_approve: true
      )

      AgentAssemblyService.call(
        team_membership: @membership,
        project_dir: @project_dir,
        workflow_run: @workflow_run,
        interactive: false
      )
    end
  end
end
