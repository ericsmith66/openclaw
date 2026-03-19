# frozen_string_literal: true

module Legion
  class AgentAssemblyService
    def self.call(team_membership:, project_dir:, workflow_run:, interactive: false)
      new(team_membership:, project_dir:, workflow_run:, interactive:).call
    end

    def initialize(team_membership:, project_dir:, workflow_run:, interactive:)
      @team_membership = team_membership
      @project_dir = project_dir
      @workflow_run = workflow_run
      @interactive = interactive
    end

    def call
      profile = @team_membership.to_profile

      rules_content = load_rules(profile)
      system_prompt = build_system_prompt(profile, rules_content)
      tool_set = build_tool_set(profile)
      model_manager = build_model_manager(profile)
      message_bus = build_message_bus
      hook_manager = build_hook_manager
      approval_manager = build_approval_manager(profile)

      runner = AgentDesk::Agent::Runner.new(
        model_manager: model_manager,
        message_bus: message_bus,
        hook_manager: hook_manager,
        approval_manager: approval_manager,
        token_budget_tracker: nil, # TODO: PRD-1-05+ - add TokenBudgetTracker when cost_budget > 0
        usage_logger: nil, # TODO: PRD-1-05+ - add usage logging
        compaction_strategy: profile.compaction_strategy
      )

      {
        runner: runner,
        system_prompt: system_prompt,
        tool_set: tool_set,
        profile: profile,
        message_bus: message_bus
      }
    end

    private

    def load_rules(profile)
      AgentDesk::Rules::RulesLoader.new.load_rules_content(
        profile_dir_name: profile.id,
        project_dir: @project_dir
      )
    end

    def build_system_prompt(profile, rules_content)
      AgentDesk::Prompts::PromptsManager.new.system_prompt(
        profile: profile,
        project_dir: @project_dir,
        rules_content: rules_content,
        custom_instructions: profile.custom_instructions
      )
    end

    def build_tool_set(profile)
      tool_set = AgentDesk::Tools::ToolSet.new

      if profile.use_power_tools
        power_tool_set = AgentDesk::Tools::PowerTools.create(project_dir: @project_dir, profile: profile)
        tool_set.merge!(power_tool_set)
      end

      if profile.use_skills_tools
        skill_loader = AgentDesk::Skills::SkillLoader.new
        skill_tool = skill_loader.activate_skill_tool(project_dir: @project_dir)
        tool_set.add(skill_tool)
      end

      if profile.use_todo_tools
        todo_tool_set = AgentDesk::Tools::TodoTools.create
        tool_set.merge!(todo_tool_set)
      end

      if profile.use_memory_tools
        memory_store = AgentDesk::Memory::MemoryStore.new(storage_path: File.join(@project_dir, "memories.json"))
        memory_tool_set = AgentDesk::Tools::MemoryTools.create(memory_store: memory_store, project_id: profile.id)
        tool_set.merge!(memory_tool_set)
      end

      tool_set
    end

    def build_model_manager(profile)
      api_key = ENV.fetch("SMART_PROXY_TOKEN", nil)
      base_url = ENV.fetch("SMART_PROXY_URL", "http://192.168.4.253:3001")

      AgentDesk::Models::ModelManager.new(
        provider: profile.provider.to_s.to_sym,
        model: profile.model,
        api_key: api_key,
        base_url: base_url,
        timeout: 300,
        default_max_tokens: 16_384
      )
    end

    def build_message_bus
      Legion::PostgresBus.new(workflow_run: @workflow_run)
    end

    def build_hook_manager
      hook_manager = AgentDesk::Hooks::HookManager.new
      Legion::OrchestratorHooksService.call(
        hook_manager: hook_manager,
        workflow_run: @workflow_run,
        team_membership: @team_membership
      )
      hook_manager
    end

    def build_approval_manager(profile)
      if @interactive
        ask_user_block = ->(text, subject) {
          print "#{text} (y/N): "
          response = $stdin.gets&.strip&.downcase
          response == "y"
        }
        AgentDesk::Tools::ApprovalManager.new(
          tool_approvals: profile.tool_approvals,
          auto_approve: false,
          &ask_user_block
        )
      else
        AgentDesk::Tools::ApprovalManager.new(
          tool_approvals: profile.tool_approvals,
          auto_approve: true
        )
      end
    end
  end
end
