# frozen_string_literal: true

require "test_helper"

class PromptTemplateDataTest < Minitest::Test
  def setup
    @profile = AgentDesk::Agent::Profile.new(
      name: "Test Agent",
      provider: "anthropic",
      model: "claude-sonnet-4-5-20250929",
      max_iterations: 100
    )
    @permissions = AgentDesk::Prompts::ToolPermissions.from_profile(@profile)
    @project_dir = "/home/user/test-project"
    @rules_content = '<File name="RULES.md"><![CDATA[Do not use eval]]></File>'
    @custom_instructions = "Always use Minitest"
  end

  def build_data(**overrides)
    AgentDesk::Prompts::PromptTemplateData.new(
      profile: overrides.fetch(:profile, @profile),
      permissions: overrides.fetch(:permissions, @permissions),
      project_dir: overrides.fetch(:project_dir, @project_dir),
      rules_content: overrides.fetch(:rules_content, @rules_content),
      custom_instructions: overrides.fetch(:custom_instructions, @custom_instructions)
    )
  end

  # --- to_liquid_hash structure ---

  def test_returns_hash_with_string_keys
    hash = build_data.to_liquid_hash

    assert_instance_of Hash, hash
    hash.each_key do |key|
      assert_instance_of String, key, "Expected string key, got #{key.class}: #{key}"
    end
  end

  def test_contains_required_top_level_keys
    hash = build_data.to_liquid_hash

    %w[agent permissions system rules_content custom_instructions constants].each do |key|
      assert hash.key?(key), "Missing top-level key: #{key}"
    end
  end

  # --- Agent hash ---

  def test_agent_hash_contains_profile_info
    hash = build_data.to_liquid_hash
    agent = hash["agent"]

    assert_equal "Test Agent", agent["name"]
    assert_equal "anthropic", agent["provider"]
    assert_equal "claude-sonnet-4-5-20250929", agent["model"]
    assert_equal 100, agent["max_iterations"]
  end

  # --- System hash ---

  def test_system_hash_contains_project_dir
    hash = build_data.to_liquid_hash
    system = hash["system"]

    assert_equal @project_dir, system["project_dir"]
  end

  def test_system_hash_contains_date
    hash = build_data.to_liquid_hash
    system = hash["system"]

    assert_match(/\w+ \w+ \d{2} \d{4}/, system["date"])
  end

  def test_system_hash_contains_os
    hash = build_data.to_liquid_hash
    system = hash["system"]

    assert_instance_of String, system["os"]
    refute_empty system["os"]
  end

  # --- Permissions hash ---

  def test_permissions_hash_matches_tool_permissions
    hash = build_data.to_liquid_hash

    assert_equal @permissions.to_liquid_hash, hash["permissions"]
  end

  # --- Rules content ---

  def test_rules_content_injected
    hash = build_data.to_liquid_hash

    assert_equal @rules_content, hash["rules_content"]
  end

  def test_empty_rules_content
    hash = build_data(rules_content: "").to_liquid_hash

    assert_equal "", hash["rules_content"]
  end

  def test_nil_rules_content_becomes_empty_string
    hash = build_data(rules_content: nil).to_liquid_hash

    assert_equal "", hash["rules_content"]
  end

  # --- Custom instructions ---

  def test_custom_instructions_injected
    hash = build_data.to_liquid_hash

    assert_equal @custom_instructions, hash["custom_instructions"]
  end

  def test_empty_custom_instructions
    hash = build_data(custom_instructions: "").to_liquid_hash

    assert_equal "", hash["custom_instructions"]
  end

  def test_nil_custom_instructions_becomes_empty_string
    hash = build_data(custom_instructions: nil).to_liquid_hash

    assert_equal "", hash["custom_instructions"]
  end

  # --- Constants hash ---

  def test_constants_hash_contains_tool_group_separator
    hash = build_data.to_liquid_hash
    constants = hash["constants"]

    assert_equal AgentDesk::TOOL_GROUP_NAME_SEPARATOR, constants["tool_group_name_separator"]
  end

  def test_constants_hash_contains_all_tool_group_names
    hash = build_data.to_liquid_hash
    constants = hash["constants"]

    assert_equal AgentDesk::POWER_TOOL_GROUP_NAME, constants["power_tool_group_name"]
    assert_equal AgentDesk::AIDER_TOOL_GROUP_NAME, constants["aider_tool_group_name"]
    assert_equal AgentDesk::TODO_TOOL_GROUP_NAME, constants["todo_tool_group_name"]
    assert_equal AgentDesk::MEMORY_TOOL_GROUP_NAME, constants["memory_tool_group_name"]
    assert_equal AgentDesk::SKILLS_TOOL_GROUP_NAME, constants["skills_tool_group_name"]
    assert_equal AgentDesk::SUBAGENTS_TOOL_GROUP_NAME, constants["subagents_tool_group_name"]
    assert_equal AgentDesk::TASKS_TOOL_GROUP_NAME, constants["tasks_tool_group_name"]
    assert_equal AgentDesk::HELPERS_TOOL_GROUP_NAME, constants["helpers_tool_group_name"]
  end
end
