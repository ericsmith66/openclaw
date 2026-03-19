# frozen_string_literal: true

require "test_helper"
require "json"

class TeamMembershipTest < ActiveSupport::TestCase
  setup do
    @team = create(:agent_team)
  end

  test "factory creates valid record" do
    membership = build(:team_membership, agent_team: @team)
    assert membership.valid?
  end

  test "config validation" do
    membership = build(:team_membership, agent_team: @team, config: nil)
    assert_not membership.valid?
    assert_includes membership.errors[:config], "can't be blank"
  end

  test "required keys validation" do
    membership = build(:team_membership, agent_team: @team, config: {})
    assert_not membership.valid?
    assert_includes membership.errors[:config], "missing required keys: id, name, provider, model"
  end

  test "ordered scope" do
    membership1 = create(:team_membership, agent_team: @team, position: 2)
    membership2 = create(:team_membership, agent_team: @team, position: 1)
    assert_equal [ membership2, membership1 ], TeamMembership.ordered.to_a
  end

  test "to_profile returns AgentDesk::Agent::Profile" do
    membership = create(:team_membership, agent_team: @team)
    profile = membership.to_profile
    assert_instance_of AgentDesk::Agent::Profile, profile
  end

  test "to_profile field mapping" do
    membership = create(:team_membership, agent_team: @team)
    profile = membership.to_profile
    config = membership.config

    assert_equal config["id"], profile.id
    assert_equal config["name"], profile.name
    assert_equal config["provider"], profile.provider
    assert_equal config["model"], profile.model
    assert_equal config["maxIterations"] || 250, profile.max_iterations
    assert_equal config["usePowerTools"] != false, profile.use_power_tools
    assert_equal config["useAiderTools"] != false, profile.use_aider_tools
    assert_equal config["useTodoTools"] != false, profile.use_todo_tools
    assert_equal config["useMemoryTools"] != false, profile.use_memory_tools
    assert_equal config["useSkillsTools"] != false, profile.use_skills_tools
    assert_equal config["useSubagents"] != false, profile.use_subagents
    assert_equal config["useTaskTools"] == true, profile.use_task_tools
    assert_equal config["customInstructions"] || "", profile.custom_instructions
    assert_equal config["compactionStrategy"] || "tiered", profile.compaction_strategy.to_s
    assert_equal config["contextWindow"] || 128_000, profile.context_window
    assert_equal config["costBudget"] || 0.0, profile.cost_budget
    assert_equal config["contextCompactingThreshold"] || 0.7, profile.context_compacting_threshold
  end

  test "to_profile includes reasoning_effort" do
    membership = create(:team_membership, agent_team: @team, config: { "id" => "test", "name" => "Test", "provider" => "openai", "model" => "gpt-4", "reasoningEffort" => "high" })
    profile = membership.to_profile
    assert_equal "high", profile.reasoning_effort
  end

  test "to_profile subagent config is SubagentConfig instance" do
    membership = create(:team_membership, agent_team: @team, config: { "id" => "test", "name" => "Test", "provider" => "openai", "model" => "gpt-4", "subagent" => { "enabled" => true, "systemPrompt" => "test", "invocationMode" => "on_demand", "color" => "#ff0000", "description" => "desc", "contextMemory" => "off" } })
    profile = membership.to_profile
    assert_instance_of AgentDesk::SubagentConfig, profile.subagent_config
    assert_equal "test", profile.subagent_config.system_prompt
  end

  test "to_profile tool settings snake case keys" do
    membership = create(:team_membership, agent_team: @team, config: { "id" => "test", "name" => "Test", "provider" => "openai", "model" => "gpt-4", "toolSettings" => { "power---bash" => { "allowedPattern" => "^ls$", "deniedPattern" => "^rm" } } })
    profile = membership.to_profile
    tool_settings = profile.tool_settings
    assert tool_settings["power---bash"].is_a?(Hash)
    assert tool_settings["power---bash"].key?("allowed_pattern")
    assert tool_settings["power---bash"].key?("denied_pattern")
  end

  test "to_profile compaction strategy is symbol" do
    membership = create(:team_membership, agent_team: @team, config: { "id" => "test", "name" => "Test", "provider" => "openai", "model" => "gpt-4", "compactionStrategy" => "aggressive" })
    profile = membership.to_profile
    assert_equal :aggressive, profile.compaction_strategy
  end

  test "to_profile raises on missing required key" do
    membership = build(:team_membership, agent_team: @team, config: { "id" => "test", "name" => "Test" }) # missing provider, model
    assert_raises(ArgumentError) do
      membership.to_profile
    end
  end

  test "to_profile with real config fixture" do
    config_path = Rails.root.join(".aider-desk/agents/ror-rails-legion/config.json")
    config_data = JSON.parse(File.read(config_path))
    membership = create(:team_membership, agent_team: @team, config: config_data)
    profile = membership.to_profile
    assert_instance_of AgentDesk::Agent::Profile, profile
    # Ensure mapping matches
    assert_equal config_data["id"], profile.id
    assert_equal config_data["provider"], profile.provider
    assert_equal config_data["model"], profile.model
    # Check that subagent config is built if present
    if config_data["subagent"] && config_data["subagent"]["enabled"]
      assert_instance_of AgentDesk::SubagentConfig, profile.subagent_config
    end
  end

  test "associations" do
    membership = create(:team_membership, agent_team: @team)
    assert_difference("membership.workflow_runs.count", 1) do
      create(:workflow_run, team_membership: membership)
    end
  end
end
