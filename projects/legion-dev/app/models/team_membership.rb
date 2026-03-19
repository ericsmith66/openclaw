# frozen_string_literal: true

class TeamMembership < ApplicationRecord
  belongs_to :agent_team
  has_many :workflow_runs, dependent: :destroy

  validates :config, presence: true
  validate :config_has_required_keys

  scope :ordered, -> { order(position: :asc) }
  scope :by_identifier, ->(identifier) {
    where("config->>'id' = ? OR config->>'id' ILIKE ? OR config->>'name' ILIKE ?",
          identifier, "%#{identifier}%", "%#{identifier}%")
  }

  # Critical method: converts JSONB config → AgentDesk::Agent::Profile
  def to_profile
    validate_config_for_profile!

    AgentDesk::Agent::Profile.new(
      id:                           config["id"],
      name:                         config["name"],
      provider:                     config["provider"],
      model:                         config["model"],
      reasoning_effort:             config["reasoningEffort"] || AgentDesk::ReasoningEffort::NONE,
      max_iterations:               config["maxIterations"] || 250,
      max_tokens:                   config.fetch("maxTokens", nil),
      temperature:                  config.fetch("temperature", nil),
      min_time_between_tool_calls:  config["minTimeBetweenToolCalls"] || 0,
      enabled_servers:              config["enabledServers"] || [],
      include_context_files:        config["includeContextFiles"] != false && config["includeContextFiles"] || false,
      include_repo_map:             config["includeRepoMap"] || false,
      use_power_tools:              config["usePowerTools"] != false,
      use_aider_tools:              config["useAiderTools"] != false,
      use_todo_tools:               config["useTodoTools"] != false,
      use_memory_tools:             config["useMemoryTools"] != false,
      use_skills_tools:             config["useSkillsTools"] != false,
      use_subagents:                config["useSubagents"] != false,
      use_task_tools:               config["useTaskTools"] == true,
      custom_instructions:          config["customInstructions"] || "",
      tool_approvals:               normalize_tool_approvals(config["toolApprovals"]),
      tool_settings:                normalize_tool_settings(config["toolSettings"]),
      subagent_config:              build_subagent_config(config["subagent"]),
      compaction_strategy:          (config["compactionStrategy"] || "tiered").to_sym,
      context_window:               config["contextWindow"] || 128_000,
      cost_budget:                  config["costBudget"] || 0.0,
      context_compacting_threshold: config["contextCompactingThreshold"] || 0.7
    )
  end

  private

  def config_has_required_keys
    return if config.nil?
    required = %w[id name provider model]
    missing = required - config.keys
    errors.add(:config, "missing required keys: #{missing.join(', ')}") if missing.any?
  end

  def validate_config_for_profile!
    raise ArgumentError, "Config is nil" if config.nil?
    required = %w[id name provider model]
    missing = required - config.keys
    raise ArgumentError, "Config missing required keys: #{missing.join(', ')}" if missing.any?
  end

  def normalize_tool_approvals(approvals)
    return {} unless approvals.is_a?(Hash)
    approvals.transform_keys(&:to_s).transform_values(&:to_s)
  end

  def normalize_tool_settings(settings)
    return {} unless settings.is_a?(Hash)
    settings.transform_keys(&:to_s).transform_values do |tool_opts|
      next tool_opts unless tool_opts.is_a?(Hash)
      tool_opts.transform_keys { |k| k.to_s.gsub(/([A-Z])/, '_\1').downcase }
    end
  end

  def build_subagent_config(subagent_data)
    return nil unless subagent_data.is_a?(Hash) && subagent_data["enabled"]
    AgentDesk::SubagentConfig.new(
      enabled:         subagent_data["enabled"],
      system_prompt:   subagent_data["systemPrompt"] || "",
      invocation_mode: subagent_data["invocationMode"] || AgentDesk::InvocationMode::ON_DEMAND,
      color:           subagent_data["color"] || "#3368a8",
      description:     subagent_data["description"] || "",
      context_memory:  subagent_data["contextMemory"] || AgentDesk::ContextMemoryMode::OFF
    )
  end
end
