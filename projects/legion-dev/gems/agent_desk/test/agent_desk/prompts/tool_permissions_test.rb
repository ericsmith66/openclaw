# frozen_string_literal: true

require "test_helper"

class ToolPermissionsTest < Minitest::Test
  def setup
    @all_enabled_profile = AgentDesk::Agent::Profile.new(
      use_power_tools: true,
      use_aider_tools: true,
      use_todo_tools: true,
      use_memory_tools: true,
      use_skills_tools: true,
      use_subagents: true,
      use_task_tools: true
    )

    @all_disabled_profile = AgentDesk::Agent::Profile.new(
      use_power_tools: false,
      use_aider_tools: false,
      use_todo_tools: false,
      use_memory_tools: false,
      use_skills_tools: false,
      use_subagents: false,
      use_task_tools: false
    )

    @partial_profile = AgentDesk::Agent::Profile.new(
      use_power_tools: true,
      use_aider_tools: false,
      use_todo_tools: true,
      use_memory_tools: false,
      use_skills_tools: false,
      use_subagents: true,
      use_task_tools: false
    )
  end

  # --- from_profile ---

  def test_from_profile_all_enabled
    perms = AgentDesk::Prompts::ToolPermissions.from_profile(@all_enabled_profile)

    assert perms.power_tools?
    assert perms.aider_tools?
    assert perms.todo_tools?
    assert perms.memory_tools?
    assert perms.skills_tools?
    assert perms.subagents?
    assert perms.task_tools?
  end

  def test_from_profile_all_disabled
    perms = AgentDesk::Prompts::ToolPermissions.from_profile(@all_disabled_profile)

    refute perms.power_tools?
    refute perms.aider_tools?
    refute perms.todo_tools?
    refute perms.memory_tools?
    refute perms.skills_tools?
    refute perms.subagents?
    refute perms.task_tools?
  end

  def test_from_profile_partial
    perms = AgentDesk::Prompts::ToolPermissions.from_profile(@partial_profile)

    assert perms.power_tools?
    refute perms.aider_tools?
    assert perms.todo_tools?
    refute perms.memory_tools?
    refute perms.skills_tools?
    assert perms.subagents?
    refute perms.task_tools?
  end

  # --- Boolean accessors match reader attributes ---

  def test_boolean_accessors_match_readers
    perms = AgentDesk::Prompts::ToolPermissions.from_profile(@partial_profile)

    assert_equal perms.power_tools, perms.power_tools?
    assert_equal perms.aider_tools, perms.aider_tools?
    assert_equal perms.todo_tools, perms.todo_tools?
    assert_equal perms.memory_tools, perms.memory_tools?
    assert_equal perms.skills_tools, perms.skills_tools?
    assert_equal perms.subagents, perms.subagents?
    assert_equal perms.task_tools, perms.task_tools?
  end

  # --- to_liquid_hash ---

  def test_to_liquid_hash_all_enabled
    perms = AgentDesk::Prompts::ToolPermissions.from_profile(@all_enabled_profile)
    hash = perms.to_liquid_hash

    assert_instance_of Hash, hash
    assert_equal true, hash["power_tools"]
    assert_equal true, hash["aider_tools"]
    assert_equal true, hash["todo_tools"]
    assert_equal true, hash["memory_tools"]
    assert_equal true, hash["skills_tools"]
    assert_equal true, hash["subagents"]
    assert_equal true, hash["task_tools"]
  end

  def test_to_liquid_hash_all_disabled
    perms = AgentDesk::Prompts::ToolPermissions.from_profile(@all_disabled_profile)
    hash = perms.to_liquid_hash

    assert_equal false, hash["power_tools"]
    assert_equal false, hash["aider_tools"]
    assert_equal false, hash["todo_tools"]
    assert_equal false, hash["memory_tools"]
    assert_equal false, hash["skills_tools"]
    assert_equal false, hash["subagents"]
    assert_equal false, hash["task_tools"]
  end

  def test_to_liquid_hash_keys_are_strings
    perms = AgentDesk::Prompts::ToolPermissions.from_profile(@all_enabled_profile)
    hash = perms.to_liquid_hash

    hash.each_key do |key|
      assert_instance_of String, key, "Expected string key, got #{key.class}: #{key}"
    end
  end

  def test_to_liquid_hash_partial
    perms = AgentDesk::Prompts::ToolPermissions.from_profile(@partial_profile)
    hash = perms.to_liquid_hash

    assert_equal true, hash["power_tools"]
    assert_equal false, hash["aider_tools"]
    assert_equal true, hash["todo_tools"]
    assert_equal false, hash["memory_tools"]
    assert_equal false, hash["skills_tools"]
    assert_equal true, hash["subagents"]
    assert_equal false, hash["task_tools"]
  end

  # --- Default profile ---

  def test_from_default_profile
    perms = AgentDesk::Prompts::ToolPermissions.from_profile(AgentDesk::Agent::Profile.new)

    assert perms.power_tools?
    assert perms.aider_tools?
    assert perms.todo_tools?
    assert perms.memory_tools?
    refute perms.skills_tools?
    assert perms.subagents?
    refute perms.task_tools?
  end
end
