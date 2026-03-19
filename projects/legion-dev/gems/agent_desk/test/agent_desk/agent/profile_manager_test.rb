# frozen_string_literal: true

require "test_helper"

class ProfileManagerTest < Minitest::Test
  def setup
    @tmpdir = Dir.mktmpdir
    @global_agents_dir = File.join(@tmpdir, ".aider-desk", "agents")
    FileUtils.mkdir_p(@global_agents_dir)
    @manager = AgentDesk::Agent::ProfileManager.new(global_dir: @global_agents_dir)
  end

  def teardown
    FileUtils.remove_entry(@tmpdir)
  end

  def test_load_global_profiles_empty_directory
    @manager.load_global_profiles
    assert_empty @manager.global_profiles
  end

  def test_load_global_profiles_single_profile
    agent_dir = File.join(@global_agents_dir, "test-agent")
    FileUtils.mkdir_p(agent_dir)
    config = {
      id: "test",
      name: "Test Agent",
      provider: "anthropic",
      model: "claude-sonnet-4-5-20250929"
    }
    File.write(File.join(agent_dir, "config.json"), JSON.generate(config))

    @manager.load_global_profiles
    assert_equal 1, @manager.global_profiles.size
    profile = @manager.global_profiles.first
    assert_equal "test", profile.id
    assert_equal "Test Agent", profile.name
    assert_equal "anthropic", profile.provider
    assert_equal "claude-sonnet-4-5-20250929", profile.model
    assert_nil profile.project_dir
  end

  def test_load_global_profiles_multiple_profiles
    %w[agent1 agent2].each do |name|
      agent_dir = File.join(@global_agents_dir, name)
      FileUtils.mkdir_p(agent_dir)
      config = { id: name, name: name.capitalize }
      File.write(File.join(agent_dir, "config.json"), JSON.generate(config))
    end

    @manager.load_global_profiles
    assert_equal 2, @manager.global_profiles.size
    assert_equal %w[agent1 agent2], @manager.global_profiles.map(&:id).sort
  end

  def test_load_global_profiles_skips_missing_config
    agent_dir = File.join(@global_agents_dir, "no-config")
    FileUtils.mkdir_p(agent_dir)
    # no config.json

    @manager.load_global_profiles
    assert_empty @manager.global_profiles
  end

  def test_load_global_profiles_skips_malformed_json
    agent_dir = File.join(@global_agents_dir, "malformed")
    FileUtils.mkdir_p(agent_dir)
    File.write(File.join(agent_dir, "config.json"), "{ invalid json")

    assert_output(nil, /Failed to load profile/) do
      @manager.load_global_profiles
    end
    assert_empty @manager.global_profiles
  end

  def test_load_project_profiles
    project_dir = File.join(@tmpdir, "project")
    agents_dir = File.join(project_dir, ".aider-desk", "agents", "project-agent")
    FileUtils.mkdir_p(agents_dir)
    config = { id: "project", name: "Project Agent" }
    File.write(File.join(agents_dir, "config.json"), JSON.generate(config))

    profiles = @manager.load_project_profiles(project_dir)
    assert_equal 1, profiles.size
    profile = profiles.first
    assert_equal "project", profile.id
    assert_equal project_dir, profile.project_dir
    assert_equal 1, @manager.project_profiles[project_dir].size
  end

  def test_profiles_for_includes_global_and_project
    # Global profile
    agent_dir = File.join(@global_agents_dir, "global")
    FileUtils.mkdir_p(agent_dir)
    File.write(File.join(agent_dir, "config.json"), JSON.generate({ id: "global" }))
    @manager.load_global_profiles

    # Project profile
    project_dir = File.join(@tmpdir, "project")
    agents_dir = File.join(project_dir, ".aider-desk", "agents", "project")
    FileUtils.mkdir_p(agents_dir)
    File.write(File.join(agents_dir, "config.json"), JSON.generate({ id: "project" }))
    @manager.load_project_profiles(project_dir)

    all = @manager.profiles_for(project_dir)
    assert_equal 2, all.size
    assert_equal %w[global project], all.map(&:id).sort
  end

  def test_find_by_id
    agent_dir = File.join(@global_agents_dir, "find")
    FileUtils.mkdir_p(agent_dir)
    File.write(File.join(agent_dir, "config.json"), JSON.generate({ id: "find", name: "Find" }))
    @manager.load_global_profiles

    profile = @manager.find("find")
    assert_equal "find", profile.id
    assert_nil @manager.find("nonexistent")
  end

  def test_find_by_id_with_project_scope
    project_dir = File.join(@tmpdir, "project")
    agents_dir = File.join(project_dir, ".aider-desk", "agents", "project")
    FileUtils.mkdir_p(agents_dir)
    File.write(File.join(agents_dir, "config.json"), JSON.generate({ id: "project" }))
    @manager.load_project_profiles(project_dir)

    assert_nil @manager.find("project") # no project scope
    profile = @manager.find("project", project_dir: project_dir)
    assert_equal "project", profile.id
  end

  def test_find_by_name_case_insensitive
    agent_dir = File.join(@global_agents_dir, "case")
    FileUtils.mkdir_p(agent_dir)
    File.write(File.join(agent_dir, "config.json"), JSON.generate({ id: "case", name: "CaseTest" }))
    @manager.load_global_profiles

    assert_equal "case", @manager.find_by_name("CASETEST")&.id
    assert_equal "case", @manager.find_by_name("casetest")&.id
    assert_equal "case", @manager.find_by_name("CaseTest")&.id
    assert_nil @manager.find_by_name("unknown")
  end

  def test_find_by_name_with_project_scope
    project_dir = File.join(@tmpdir, "project")
    agents_dir = File.join(project_dir, ".aider-desk", "agents", "project")
    FileUtils.mkdir_p(agents_dir)
    File.write(File.join(agents_dir, "config.json"), JSON.generate({ id: "project", name: "Project" }))
    @manager.load_project_profiles(project_dir)

    assert_nil @manager.find_by_name("Project") # global only
    profile = @manager.find_by_name("Project", project_dir: project_dir)
    assert_equal "project", profile.id
  end

  def test_rule_file_discovery_global_only
    agent_dir = File.join(@global_agents_dir, "agent")
    FileUtils.mkdir_p(agent_dir)
    File.write(File.join(agent_dir, "config.json"), JSON.generate({ id: "agent" }))
    rules_dir = File.join(agent_dir, "rules")
    FileUtils.mkdir_p(rules_dir)
    File.write(File.join(rules_dir, "global.md"), "# Global rule")

    @manager.load_global_profiles
    profile = @manager.global_profiles.first
    assert_equal [ File.join(rules_dir, "global.md") ], profile.rule_files
  end

  def test_rule_file_discovery_project_tiers
    # Global agent rules (should be included)
    agent_dir = File.join(@global_agents_dir, "agent")
    FileUtils.mkdir_p(agent_dir)
    File.write(File.join(agent_dir, "config.json"), JSON.generate({ id: "global-agent" }))
    global_rules_dir = File.join(agent_dir, "rules")
    FileUtils.mkdir_p(global_rules_dir)
    File.write(File.join(global_rules_dir, "global.md"), "# Global")

    project_dir = File.join(@tmpdir, "project")
    # Project agent directory with its own config
    project_agent_dir = File.join(project_dir, ".aider-desk", "agents", "agent")
    FileUtils.mkdir_p(project_agent_dir)
    File.write(File.join(project_agent_dir, "config.json"), JSON.generate({ id: "project-agent" }))
    # Project‑level rules
    project_rules_dir = File.join(project_dir, ".aider-desk", "rules")
    FileUtils.mkdir_p(project_rules_dir)
    File.write(File.join(project_rules_dir, "project.md"), "# Project")
    # Project‑agent rules
    project_agent_rules_dir = File.join(project_agent_dir, "rules")
    FileUtils.mkdir_p(project_agent_rules_dir)
    File.write(File.join(project_agent_rules_dir, "agent.md"), "# Agent")

    @manager.load_global_profiles
    profiles = @manager.load_project_profiles(project_dir)
    profile = profiles.first
    expected = [
      File.join(global_rules_dir, "global.md"),
      File.join(project_rules_dir, "project.md"),
      File.join(project_agent_rules_dir, "agent.md")
    ]
    assert_equal expected, profile.rule_files
  end

  def test_rule_file_discovery_missing_directories
    agent_dir = File.join(@global_agents_dir, "agent")
    FileUtils.mkdir_p(agent_dir)
    File.write(File.join(agent_dir, "config.json"), JSON.generate({ id: "agent" }))
    # No rule directories

    @manager.load_global_profiles
    profile = @manager.global_profiles.first
    assert_empty profile.rule_files
  end

  def test_symbolize_keys_camel_case_to_snake_case
    manager = @manager
    # Simulate private method call
    symbolized = manager.send(:deep_symbolize_keys, { "camelCaseKey" => 1, "already_snake" => 2, "ModelID" => 3 })
    assert_equal :camel_case_key, symbolized.keys[0]
    assert_equal :already_snake, symbolized.keys[1]
    assert_equal :model_i_d, symbolized.keys[2]
  end

  def test_load_profile_with_subagent_config
    agent_dir = File.join(@global_agents_dir, "subagent")
    FileUtils.mkdir_p(agent_dir)
    config = {
      id: "sub",
      name: "Sub",
      subagentConfig: {
        enabled: true,
        systemPrompt: "test",
        invocationMode: "on_demand",
        color: "#3368a8",
        description: "test",
        contextMemory: "off"
      }
    }
    File.write(File.join(agent_dir, "config.json"), JSON.generate(config))

    @manager.load_global_profiles
    profile = @manager.global_profiles.first
    assert_kind_of AgentDesk::SubagentConfig, profile.subagent_config
    assert_equal true, profile.subagent_config.enabled
    assert_equal "test", profile.subagent_config.system_prompt
    assert_equal AgentDesk::InvocationMode::ON_DEMAND, profile.subagent_config.invocation_mode
  end

  def test_load_profile_with_tool_approvals_and_settings
    agent_dir = File.join(@global_agents_dir, "tools")
    FileUtils.mkdir_p(agent_dir)
    # Simulate typical AiderDesk JSON with camelCase keys
    config = {
      id: "tools",
      name: "Tools Agent",
      toolApprovals: {
        "power---bash" => "ASK",
        "power---file_read" => "ALWAYS"
      },
      toolSettings: {
        "power---bash" => {
          "allowedPattern" => "ls .*;cat .*",
          "deniedPattern" => "rm .*;del .*"
        }
      },
      compactionStrategy: "tiered"
    }
    File.write(File.join(agent_dir, "config.json"), JSON.generate(config))

    @manager.load_global_profiles
    profile = @manager.global_profiles.first
    # tool_approvals keys should be strings (tool IDs)
    assert_kind_of Hash, profile.tool_approvals
    assert_equal [ "power---bash", "power---file_read" ], profile.tool_approvals.keys.sort
    assert_equal "ASK", profile.tool_approvals["power---bash"]
    assert_equal "ALWAYS", profile.tool_approvals["power---file_read"]
    # tool_settings keys should be strings (tool IDs), nested hash keys should be strings
    assert_kind_of Hash, profile.tool_settings
    assert_equal [ "power---bash" ], profile.tool_settings.keys
    bash_settings = profile.tool_settings["power---bash"]
    assert_kind_of Hash, bash_settings
    assert_equal [ "allowed_pattern", "denied_pattern" ], bash_settings.keys.sort
    assert_equal "ls .*;cat .*", bash_settings["allowed_pattern"]
    assert_equal "rm .*;del .*", bash_settings["denied_pattern"]
    # compaction_strategy should be a Symbol
    assert_equal :tiered, profile.compaction_strategy
  end
end
