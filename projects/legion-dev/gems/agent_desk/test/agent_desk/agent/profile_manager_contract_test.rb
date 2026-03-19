# frozen_string_literal: true

require "test_helper"

class ProfileManagerContractTest < Minitest::Test
  # Contract tests for the public API of AgentDesk::Agent::ProfileManager.
  # These tests ensure the class adheres to the interface defined in PRD‑0040.

  def setup
    @tmpdir = Dir.mktmpdir
    @global_agents_dir = File.join(@tmpdir, ".aider-desk", "agents")
    FileUtils.mkdir_p(@global_agents_dir)
    @manager = AgentDesk::Agent::ProfileManager.new(global_dir: @global_agents_dir)
  end

  def teardown
    FileUtils.remove_entry(@tmpdir)
  end

  def test_load_global_profiles_reads_from_global_directory
    # Create a profile in the global directory
    agent_dir = File.join(@global_agents_dir, "test")
    FileUtils.mkdir_p(agent_dir)
    File.write(File.join(agent_dir, "config.json"), JSON.generate({ id: "test", name: "Test" }))

    @manager.load_global_profiles
    assert_equal 1, @manager.global_profiles.size
    profile = @manager.global_profiles.first
    assert_equal "test", profile.id
    assert_equal "Test", profile.name
  end

  def test_load_project_profiles_reads_from_project_directory
    project_dir = File.join(@tmpdir, "project")
    agents_dir = File.join(project_dir, ".aider-desk", "agents", "project")
    FileUtils.mkdir_p(agents_dir)
    File.write(File.join(agents_dir, "config.json"), JSON.generate({ id: "project", name: "Project" }))

    profiles = @manager.load_project_profiles(project_dir)
    assert_equal 1, profiles.size
    profile = profiles.first
    assert_equal "project", profile.id
    assert_equal project_dir, profile.project_dir
  end

  def test_profiles_for_returns_global_and_project_profiles
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
    ids = all.map(&:id).sort
    assert_equal %w[global project], ids
  end

  def test_find_by_id
    agent_dir = File.join(@global_agents_dir, "find")
    FileUtils.mkdir_p(agent_dir)
    File.write(File.join(agent_dir, "config.json"), JSON.generate({ id: "find", name: "Find" }))
    @manager.load_global_profiles

    profile = @manager.find("find")
    assert_equal "find", profile.id
    assert_equal "Find", profile.name

    assert_nil @manager.find("nonexistent")
  end

  def test_find_by_id_with_project_scope
    project_dir = File.join(@tmpdir, "project")
    agents_dir = File.join(project_dir, ".aider-desk", "agents", "project")
    FileUtils.mkdir_p(agents_dir)
    File.write(File.join(agents_dir, "config.json"), JSON.generate({ id: "project" }))
    @manager.load_project_profiles(project_dir)

    # Without project scope, not found
    assert_nil @manager.find("project")
    # With project scope, found
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

    # Without project scope, not found
    assert_nil @manager.find_by_name("Project")
    # With project scope, found
    profile = @manager.find_by_name("Project", project_dir: project_dir)
    assert_equal "project", profile.id
  end
end
