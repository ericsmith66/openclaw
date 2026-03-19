# frozen_string_literal: true

require "test_helper"

class ProfileTest < Minitest::Test
  def test_initialize_with_defaults
    profile = AgentDesk::Agent::Profile.new
    assert_equal "default", profile.id
    assert_equal "Default Agent", profile.name
    assert_equal "anthropic", profile.provider
    assert_equal "claude-sonnet-4-5-20250929", profile.model
    assert_equal AgentDesk::ReasoningEffort::NONE, profile.reasoning_effort
    assert_equal 250, profile.max_iterations
    assert_nil profile.max_tokens
    assert_nil profile.temperature
    assert_equal 0, profile.min_time_between_tool_calls
    assert_equal [], profile.enabled_servers
    assert_equal false, profile.include_context_files
    assert_equal false, profile.include_repo_map
    assert_equal true, profile.use_power_tools
    assert_equal true, profile.use_aider_tools
    assert_equal true, profile.use_todo_tools
    assert_equal true, profile.use_memory_tools
    assert_equal false, profile.use_skills_tools
    assert_equal true, profile.use_subagents
    assert_equal false, profile.use_task_tools
    assert_equal "", profile.custom_instructions
    assert_equal AgentDesk::Agent::Profile.default_tool_approvals, profile.tool_approvals
    assert_equal AgentDesk::Agent::Profile.default_tool_settings, profile.tool_settings
    assert_nil profile.subagent_config
    assert_equal :tiered, profile.compaction_strategy
    assert_equal 128_000, profile.context_window
    assert_equal 0.0, profile.cost_budget
    assert_equal 0.7, profile.context_compacting_threshold
    assert_equal [], profile.rule_files
    assert_nil profile.project_dir
  end

  def test_attribute_overrides
    profile = AgentDesk::Agent::Profile.new(
      name: "QA Agent",
      use_power_tools: false,
      max_iterations: 10
    )
    assert_equal "QA Agent", profile.name
    assert_equal false, profile.use_power_tools
    assert_equal 10, profile.max_iterations
    # Other attributes remain default
    assert_equal "default", profile.id
    assert_equal true, profile.use_aider_tools
  end

  def test_to_json_hash_excludes_runtime_fields
    profile = AgentDesk::Agent::Profile.new
    hash = profile.to_json_hash
    refute_includes hash.keys, "rule_files"
    refute_includes hash.keys, "project_dir"
    assert_includes hash.keys, "id"
    assert_includes hash.keys, "name"
    assert_includes hash.keys, "provider"
    assert_includes hash.keys, "model"
    assert_includes hash.keys, "reasoning_effort"
    assert_includes hash.keys, "max_iterations"
    assert_includes hash.keys, "min_time_between_tool_calls"
    assert_includes hash.keys, "enabled_servers"
    assert_includes hash.keys, "include_context_files"
    assert_includes hash.keys, "include_repo_map"
    assert_includes hash.keys, "use_power_tools"
    assert_includes hash.keys, "use_aider_tools"
    assert_includes hash.keys, "use_todo_tools"
    assert_includes hash.keys, "use_memory_tools"
    assert_includes hash.keys, "use_skills_tools"
    assert_includes hash.keys, "use_subagents"
    assert_includes hash.keys, "use_task_tools"
    assert_includes hash.keys, "custom_instructions"
    assert_includes hash.keys, "tool_approvals"
    assert_includes hash.keys, "tool_settings"
    assert_includes hash.keys, "subagent_config"
    assert_includes hash.keys, "compaction_strategy"
    assert_includes hash.keys, "context_window"
    assert_includes hash.keys, "cost_budget"
    assert_includes hash.keys, "context_compacting_threshold"
  end

  def test_to_json_hash_subagent_config_to_h
    subagent = AgentDesk::SubagentConfig.new(
      enabled: true,
      system_prompt: "test",
      invocation_mode: AgentDesk::InvocationMode::ON_DEMAND,
      color: "#3368a8",
      description: "test",
      context_memory: AgentDesk::ContextMemoryMode::OFF
    )
    profile = AgentDesk::Agent::Profile.new(subagent_config: subagent)
    hash = profile.to_json_hash
    assert_kind_of Hash, hash["subagent_config"]
    assert_equal true, hash["subagent_config"]["enabled"]
    assert_equal "test", hash["subagent_config"]["system_prompt"]
    assert_equal AgentDesk::InvocationMode::ON_DEMAND, hash["subagent_config"]["invocation_mode"]
  end

  def test_default_tool_approvals_includes_all_tools
    approvals = AgentDesk::Agent::Profile.default_tool_approvals
    # Spot‑check a few critical tools
    assert_equal AgentDesk::ToolApprovalState::ALWAYS,
                 approvals[AgentDesk.tool_id(AgentDesk::POWER_TOOL_GROUP_NAME, AgentDesk::POWER_TOOL_FILE_READ)]
    assert_equal AgentDesk::ToolApprovalState::ASK,
                 approvals[AgentDesk.tool_id(AgentDesk::POWER_TOOL_GROUP_NAME, AgentDesk::POWER_TOOL_BASH)]
    assert_equal AgentDesk::ToolApprovalState::ALWAYS,
                 approvals[AgentDesk.tool_id(AgentDesk::AIDER_TOOL_GROUP_NAME, AgentDesk::AIDER_TOOL_GET_CONTEXT_FILES)]
    assert_equal AgentDesk::ToolApprovalState::ASK,
                 approvals[AgentDesk.tool_id(AgentDesk::AIDER_TOOL_GROUP_NAME, AgentDesk::AIDER_TOOL_RUN_PROMPT)]
    assert_equal AgentDesk::ToolApprovalState::NEVER,
                 approvals[AgentDesk.tool_id(AgentDesk::MEMORY_TOOL_GROUP_NAME, AgentDesk::MEMORY_TOOL_DELETE)]
    # Ensure all tool groups are represented
    tool_groups = approvals.keys.map { |k| k.split("---").first }.uniq
    expected_groups = %w[power aider skills memory todo subagents tasks helpers]
    assert_equal expected_groups.sort, tool_groups.sort
  end

  def test_default_tool_settings
    settings = AgentDesk::Agent::Profile.default_tool_settings
    bash_key = AgentDesk.tool_id(AgentDesk::POWER_TOOL_GROUP_NAME, AgentDesk::POWER_TOOL_BASH)
    assert_includes settings.keys, bash_key
    bash_settings = settings[bash_key]
    assert_equal "ls .*;cat .*;git status;git show;git log", bash_settings["allowed_pattern"]
    assert_equal "rm .*;del .*;chown .*;chgrp .*;chmod .*", bash_settings["denied_pattern"]
  end

  def test_to_json_hash_compacts_nil_values
    profile = AgentDesk::Agent::Profile.new(max_tokens: nil, temperature: nil)
    hash = profile.to_json_hash
    # nil values should be omitted (compact)
    refute_includes hash.keys, "max_tokens"
    refute_includes hash.keys, "temperature"
  end

  def test_to_json_hash_includes_max_tokens_and_temperature_when_set
    profile = AgentDesk::Agent::Profile.new(max_tokens: 4096, temperature: 0.7)
    hash = profile.to_json_hash
    assert_equal 4096, hash["max_tokens"]
    assert_equal 0.7, hash["temperature"]
  end
end
