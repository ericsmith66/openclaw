# frozen_string_literal: true

# Profile data structure matching AiderDesk's AgentProfile interface.
# Defines agent configuration loaded from JSON files on disk.
#
# @see AgentDesk::Agent::ProfileManager
module AgentDesk
  module Agent
    class Profile
      # @!attribute [rw] id
      #   @return [String] unique identifier (UUID)
      # @!attribute [rw] name
      #   @return [String] human-readable name
      # @!attribute [rw] provider
      #   @return [String] LLM provider (e.g., "anthropic")
      # @!attribute [rw] model
      #   @return [String] model name (e.g., "claude-sonnet-4-5-20250929")
      # @!attribute [rw] reasoning_effort
      #   @return [String] reasoning effort level (see AgentDesk::ReasoningEffort)
      # @!attribute [rw] max_iterations
      #   @return [Integer] maximum number of agent loop iterations
      # @!attribute [rw] max_tokens
      #   @return [Integer, nil] maximum tokens for LLM response
      # @!attribute [rw] temperature
      #   @return [Float, nil] temperature for LLM sampling
      # @!attribute [rw] min_time_between_tool_calls
      #   @return [Float] minimum seconds between tool calls
      # @!attribute [rw] enabled_servers
      #   @return [Array<String>] list of enabled MCP server names
      # @!attribute [rw] include_context_files
      #   @return [Boolean] whether to include context files
      # @!attribute [rw] include_repo_map
      #   @return [Boolean] whether to include repository map
      # @!attribute [rw] use_power_tools
      #   @return [Boolean] whether power tool group is enabled
      # @!attribute [rw] use_aider_tools
      #   @return [Boolean] whether aider tool group is enabled
      # @!attribute [rw] use_todo_tools
      #   @return [Boolean] whether todo tool group is enabled
      # @!attribute [rw] use_memory_tools
      #   @return [Boolean] whether memory tool group is enabled
      # @!attribute [rw] use_skills_tools
      #   @return [Boolean] whether skills tool group is enabled
      # @!attribute [rw] use_subagents
      #   @return [Boolean] whether subagents tool group is enabled
      # @!attribute [rw] use_task_tools
      #   @return [Boolean] whether tasks tool group is enabled
      # @!attribute [rw] custom_instructions
      #   @return [String] custom instructions for the agent
      # @!attribute [rw] tool_approvals
      #   @return [Hash{String => String}] map of tool IDs to approval states
      # @!attribute [rw] tool_settings
      #   @return [Hash{String => Hash}] tool-specific settings
      # @!attribute [rw] subagent_config
      #   @return [AgentDesk::SubagentConfig, nil] subagent configuration
      # @!attribute [rw] compaction_strategy
      #   @return [Symbol] compaction strategy (:tiered, :none, etc.)
      # @!attribute [rw] context_window
      #   @return [Integer] context window size in tokens
      # @!attribute [rw] cost_budget
      #   @return [Float] maximum cost allowed (0.0 = unlimited)
      # @!attribute [rw] context_compacting_threshold
      #   @return [Float] threshold for context compacting (0.0–1.0)
      # @!attribute [rw] rule_files
      #   @return [Array<String>] discovered rule file paths (runtime-only)
      # @!attribute [rw] project_dir
      #   @return [String, nil] project directory for project-level profiles
      attr_accessor :id, :name, :provider, :model,
                    :reasoning_effort,
                    :max_iterations, :max_tokens, :temperature,
                    :min_time_between_tool_calls,
                    :enabled_servers,
                    :include_context_files, :include_repo_map,
                    :use_power_tools, :use_aider_tools, :use_todo_tools,
                    :use_memory_tools, :use_skills_tools, :use_subagents, :use_task_tools,
                    :custom_instructions,
                    :tool_approvals, :tool_settings,
                    :subagent_config,
                    :compaction_strategy, :context_window, :cost_budget, :context_compacting_threshold,
                    :rule_files, :project_dir

      # Create a new profile with default values.
      #
      # @example
      #   Profile.new
      #   Profile.new(name: "QA Agent", use_power_tools: false)
      #
      # @param attrs [Hash] attribute overrides
      def initialize(**attrs)
        self.class.default_attributes.merge(attrs).each do |key, value|
          send("#{key}=", value) if respond_to?("#{key}=")
        end
      end

      # Default attribute values matching AiderDesk's DEFAULT_AGENT_PROFILE.
      #
      # @return [Hash{Symbol => Object}]
      def self.default_attributes
        {
          id: "default",
          name: "Default Agent",
          provider: "anthropic",
          model: "claude-sonnet-4-5-20250929",
          reasoning_effort: ReasoningEffort::NONE,
          max_iterations: 250,
          max_tokens: nil,
          temperature: nil,
          min_time_between_tool_calls: 0,
          enabled_servers: [],
          include_context_files: false,
          include_repo_map: false,
          use_power_tools: true,
          use_aider_tools: true,
          use_todo_tools: true,
          use_memory_tools: true,
          use_skills_tools: false,
          use_subagents: true,
          use_task_tools: false,
          custom_instructions: "",
          tool_approvals: default_tool_approvals,
          tool_settings: default_tool_settings,
          subagent_config: nil,
          compaction_strategy: :tiered,
          context_window: 128_000,
          cost_budget: 0.0,
          context_compacting_threshold: 0.7,
          rule_files: [],
          project_dir: nil
        }
      end

      # Default tool approval states for all known tools.
      #
      # @return [Hash{String => String}] mapping fully‑qualified tool IDs to approval state constants
      def self.default_tool_approvals
        {
          # Power tools
          AgentDesk.tool_id(POWER_TOOL_GROUP_NAME, POWER_TOOL_FILE_READ) => ToolApprovalState::ALWAYS,
          AgentDesk.tool_id(POWER_TOOL_GROUP_NAME, POWER_TOOL_FILE_EDIT) => ToolApprovalState::ASK,
          AgentDesk.tool_id(POWER_TOOL_GROUP_NAME, POWER_TOOL_FILE_WRITE) => ToolApprovalState::ASK,
          AgentDesk.tool_id(POWER_TOOL_GROUP_NAME, POWER_TOOL_GLOB) => ToolApprovalState::ALWAYS,
          AgentDesk.tool_id(POWER_TOOL_GROUP_NAME, POWER_TOOL_GREP) => ToolApprovalState::ALWAYS,
          AgentDesk.tool_id(POWER_TOOL_GROUP_NAME, POWER_TOOL_SEMANTIC_SEARCH) => ToolApprovalState::ALWAYS,
          AgentDesk.tool_id(POWER_TOOL_GROUP_NAME, POWER_TOOL_BASH) => ToolApprovalState::ASK,
          AgentDesk.tool_id(POWER_TOOL_GROUP_NAME, POWER_TOOL_FETCH) => ToolApprovalState::ALWAYS,
          # Aider tools
          AgentDesk.tool_id(AIDER_TOOL_GROUP_NAME, AIDER_TOOL_GET_CONTEXT_FILES) => ToolApprovalState::ALWAYS,
          AgentDesk.tool_id(AIDER_TOOL_GROUP_NAME, AIDER_TOOL_ADD_CONTEXT_FILES) => ToolApprovalState::ALWAYS,
          AgentDesk.tool_id(AIDER_TOOL_GROUP_NAME, AIDER_TOOL_DROP_CONTEXT_FILES) => ToolApprovalState::ALWAYS,
          AgentDesk.tool_id(AIDER_TOOL_GROUP_NAME, AIDER_TOOL_RUN_PROMPT) => ToolApprovalState::ASK,
          # Skills
          AgentDesk.tool_id(SKILLS_TOOL_GROUP_NAME, SKILLS_TOOL_ACTIVATE_SKILL) => ToolApprovalState::ALWAYS,
          # Memory
          AgentDesk.tool_id(MEMORY_TOOL_GROUP_NAME, MEMORY_TOOL_STORE) => ToolApprovalState::ALWAYS,
          AgentDesk.tool_id(MEMORY_TOOL_GROUP_NAME, MEMORY_TOOL_RETRIEVE) => ToolApprovalState::ALWAYS,
          AgentDesk.tool_id(MEMORY_TOOL_GROUP_NAME, MEMORY_TOOL_DELETE) => ToolApprovalState::NEVER,
          AgentDesk.tool_id(MEMORY_TOOL_GROUP_NAME, MEMORY_TOOL_LIST) => ToolApprovalState::NEVER,
          AgentDesk.tool_id(MEMORY_TOOL_GROUP_NAME, MEMORY_TOOL_UPDATE) => ToolApprovalState::NEVER,
          # Todo tools
          AgentDesk.tool_id(TODO_TOOL_GROUP_NAME, TODO_TOOL_SET_ITEMS) => ToolApprovalState::ALWAYS,
          AgentDesk.tool_id(TODO_TOOL_GROUP_NAME, TODO_TOOL_GET_ITEMS) => ToolApprovalState::ALWAYS,
          AgentDesk.tool_id(TODO_TOOL_GROUP_NAME, TODO_TOOL_UPDATE_ITEM_COMPLETION) => ToolApprovalState::ALWAYS,
          AgentDesk.tool_id(TODO_TOOL_GROUP_NAME, TODO_TOOL_CLEAR_ITEMS) => ToolApprovalState::ALWAYS,
          # Subagents
          AgentDesk.tool_id(SUBAGENTS_TOOL_GROUP_NAME, SUBAGENTS_TOOL_RUN_TASK) => ToolApprovalState::ALWAYS,
          # Tasks
          AgentDesk.tool_id(TASKS_TOOL_GROUP_NAME, TASKS_TOOL_LIST_TASKS) => ToolApprovalState::ALWAYS,
          AgentDesk.tool_id(TASKS_TOOL_GROUP_NAME, TASKS_TOOL_GET_TASK) => ToolApprovalState::ALWAYS,
          AgentDesk.tool_id(TASKS_TOOL_GROUP_NAME, TASKS_TOOL_GET_TASK_MESSAGE) => ToolApprovalState::ALWAYS,
          AgentDesk.tool_id(TASKS_TOOL_GROUP_NAME, TASKS_TOOL_CREATE_TASK) => ToolApprovalState::ALWAYS,
          AgentDesk.tool_id(TASKS_TOOL_GROUP_NAME, TASKS_TOOL_DELETE_TASK) => ToolApprovalState::ALWAYS,
          AgentDesk.tool_id(TASKS_TOOL_GROUP_NAME, TASKS_TOOL_SEARCH_TASK) => ToolApprovalState::ALWAYS,
          AgentDesk.tool_id(TASKS_TOOL_GROUP_NAME, TASKS_TOOL_SEARCH_PARENT_TASK) => ToolApprovalState::ALWAYS,
          # Helpers (internal tools)
          AgentDesk.tool_id(HELPERS_TOOL_GROUP_NAME, HELPERS_TOOL_NO_SUCH_TOOL) => ToolApprovalState::NEVER,
          AgentDesk.tool_id(HELPERS_TOOL_GROUP_NAME, HELPERS_TOOL_INVALID_TOOL_ARGUMENTS) => ToolApprovalState::NEVER
        }
      end

      # Default tool‑specific settings.
      #
      # @return [Hash{String => Hash}]
      def self.default_tool_settings
        {
          AgentDesk.tool_id(POWER_TOOL_GROUP_NAME, POWER_TOOL_BASH) => {
            "allowed_pattern" => "ls .*;cat .*;git status;git show;git log",
            "denied_pattern"  => "rm .*;del .*;chown .*;chgrp .*;chmod .*"
          }
        }
      end

      # Serialize to a JSON‑compatible hash, excluding runtime‑only fields.
      #
      # @return [Hash{String => Object}]
      def to_json_hash
        hash = {
          "id" => id,
          "name" => name,
          "provider" => provider,
          "model" => model,
          "reasoning_effort" => reasoning_effort,
          "max_iterations" => max_iterations,
          "min_time_between_tool_calls" => min_time_between_tool_calls,
          "enabled_servers" => enabled_servers,
          "include_context_files" => include_context_files,
          "include_repo_map" => include_repo_map,
          "use_power_tools" => use_power_tools,
          "use_aider_tools" => use_aider_tools,
          "use_todo_tools" => use_todo_tools,
          "use_memory_tools" => use_memory_tools,
          "use_skills_tools" => use_skills_tools,
          "use_subagents" => use_subagents,
          "use_task_tools" => use_task_tools,
          "custom_instructions" => custom_instructions,
          "tool_approvals" => tool_approvals,
          "tool_settings" => tool_settings,
          "subagent_config" => subagent_config&.to_h&.transform_keys(&:to_s),
          "compaction_strategy" => compaction_strategy,
          "context_window" => context_window,
          "cost_budget" => cost_budget,
          "context_compacting_threshold" => context_compacting_threshold
        }
        hash["max_tokens"] = max_tokens unless max_tokens.nil?
        hash["temperature"] = temperature unless temperature.nil?
        hash
      end
    end
  end
end
