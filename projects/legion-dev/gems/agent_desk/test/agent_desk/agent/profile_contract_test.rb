# frozen_string_literal: true

require "test_helper"

class ProfileContractTest < Minitest::Test
  # Contract tests for the public API of AgentDesk::Agent::Profile.
  # These tests ensure the class adheres to the interface defined in PRD‑0040.

  def test_initialize_with_defaults
    profile = AgentDesk::Agent::Profile.new
    # Check a subset of critical defaults
    assert_equal "default", profile.id
    assert_equal "Default Agent", profile.name
    assert_equal true, profile.use_power_tools
    assert_equal true, profile.use_aider_tools
    assert_equal true, profile.use_todo_tools
    assert_equal true, profile.use_memory_tools
    assert_equal false, profile.use_skills_tools
    assert_equal true, profile.use_subagents
    assert_equal false, profile.use_task_tools
    assert_equal AgentDesk::Agent::Profile.default_tool_approvals, profile.tool_approvals
    assert_equal AgentDesk::Agent::Profile.default_tool_settings, profile.tool_settings
    assert_nil profile.subagent_config
    assert_equal [], profile.rule_files
  end

  def test_initialize_with_overrides
    profile = AgentDesk::Agent::Profile.new(
      name: "Custom",
      use_power_tools: false,
      custom_instructions: "Be careful"
    )
    assert_equal "Custom", profile.name
    assert_equal false, profile.use_power_tools
    assert_equal "Be careful", profile.custom_instructions
    # Unspecified attributes remain default
    assert_equal "default", profile.id
    assert_equal true, profile.use_aider_tools
  end

  def test_to_json_hash_excludes_rule_files
    profile = AgentDesk::Agent::Profile.new
    profile.rule_files = [ "/some/path" ]
    hash = profile.to_json_hash
    refute_includes hash.keys, "rule_files"
    refute_includes hash.values, [ "/some/path" ]
  end

  def test_default_tool_approvals_includes_all_tools
    approvals = AgentDesk::Agent::Profile.default_tool_approvals
    # Verify presence of at least one tool from each group
    assert_includes approvals, AgentDesk.tool_id(AgentDesk::POWER_TOOL_GROUP_NAME, AgentDesk::POWER_TOOL_FILE_READ)
    assert_includes approvals, AgentDesk.tool_id(AgentDesk::AIDER_TOOL_GROUP_NAME, AgentDesk::AIDER_TOOL_GET_CONTEXT_FILES)
    assert_includes approvals, AgentDesk.tool_id(AgentDesk::SKILLS_TOOL_GROUP_NAME, AgentDesk::SKILLS_TOOL_ACTIVATE_SKILL)
    assert_includes approvals, AgentDesk.tool_id(AgentDesk::MEMORY_TOOL_GROUP_NAME, AgentDesk::MEMORY_TOOL_STORE)
    assert_includes approvals, AgentDesk.tool_id(AgentDesk::TODO_TOOL_GROUP_NAME, AgentDesk::TODO_TOOL_SET_ITEMS)
    assert_includes approvals, AgentDesk.tool_id(AgentDesk::SUBAGENTS_TOOL_GROUP_NAME, AgentDesk::SUBAGENTS_TOOL_RUN_TASK)
    assert_includes approvals, AgentDesk.tool_id(AgentDesk::TASKS_TOOL_GROUP_NAME, AgentDesk::TASKS_TOOL_LIST_TASKS)
    # Helpers tools should be NEVER
    helpers_key = AgentDesk.tool_id(AgentDesk::HELPERS_TOOL_GROUP_NAME, AgentDesk::HELPERS_TOOL_NO_SUCH_TOOL)
    assert_equal AgentDesk::ToolApprovalState::NEVER, approvals[helpers_key]
  end

  def test_default_tool_settings_includes_bash_patterns
    settings = AgentDesk::Agent::Profile.default_tool_settings
    bash_key = AgentDesk.tool_id(AgentDesk::POWER_TOOL_GROUP_NAME, AgentDesk::POWER_TOOL_BASH)
    assert_includes settings.keys, bash_key
    bash_setting = settings[bash_key]
    assert_includes bash_setting.keys, "allowed_pattern"
    assert_includes bash_setting.keys, "denied_pattern"
  end
end
