# frozen_string_literal: true

require "test_helper"

class RulesLoaderTest < Minitest::Test
  def setup
    @tmpdir = Dir.mktmpdir
    @global_agents_dir = File.join(@tmpdir, ".aider-desk", "agents")
    FileUtils.mkdir_p(@global_agents_dir)
    @loader = AgentDesk::Rules::RulesLoader.new(global_agents_dir: @global_agents_dir)
  end

  def teardown
    FileUtils.remove_entry(@tmpdir)
  end

  def test_3_tier_discovery
    # Create global agent rule
    global_agent_dir = File.join(@global_agents_dir, "default", "rules")
    FileUtils.mkdir_p(global_agent_dir)
    File.write(File.join(global_agent_dir, "global_rule.md"), "# Global rule")

    # Create project directory
    project_dir = File.join(@tmpdir, "project")
    # Project-wide rule
    project_rules_dir = File.join(project_dir, ".aider-desk", "rules")
    FileUtils.mkdir_p(project_rules_dir)
    File.write(File.join(project_rules_dir, "project_rule.md"), "# Project rule")
    # Project agent rule
    project_agent_dir = File.join(project_dir, ".aider-desk", "agents", "default", "rules")
    FileUtils.mkdir_p(project_agent_dir)
    File.write(File.join(project_agent_dir, "agent_rule.md"), "# Agent rule")

    paths = @loader.rule_file_paths(profile_dir_name: "default", project_dir: project_dir)
    assert_equal 3, paths.size
    # Order: global → project → project agent
    assert paths[0].end_with?("global_rule.md")
    assert paths[1].end_with?("project_rule.md")
    assert paths[2].end_with?("agent_rule.md")
  end

  def test_empty_when_no_rules
    paths = @loader.rule_file_paths(profile_dir_name: "default", project_dir: nil)
    assert_empty paths

    paths = @loader.rule_file_paths(profile_dir_name: "default", project_dir: "/nonexistent")
    assert_empty paths
  end

  def test_cdata_xml_format
    project_dir = File.join(@tmpdir, "project")
    rules_dir = File.join(project_dir, ".aider-desk", "rules")
    FileUtils.mkdir_p(rules_dir)
    File.write(File.join(rules_dir, "conventions.md"), "# Use snake_case")

    content = @loader.load_rules_content(profile_dir_name: "default", project_dir: project_dir)
    assert_match(/<File name="project\/conventions\.md"><!\[CDATA\[# Use snake_case\]\]><\/File>/, content)
  end

  def test_cdata_escaping
    project_dir = File.join(@tmpdir, "project")
    rules_dir = File.join(project_dir, ".aider-desk", "rules")
    FileUtils.mkdir_p(rules_dir)
    File.write(File.join(rules_dir, "danger.md"), "Some ]]> dangerous content")

    content = @loader.load_rules_content(profile_dir_name: "default", project_dir: project_dir)
    # Should escape ]]> as ]]]]><![CDATA[>
    assert_includes content, "Some ]]]]><![CDATA[> dangerous content"
    # Ensure CDATA sections are still well-formed
    assert_match(/<!\[CDATA\[.*\]\]>/m, content)
  end

  def test_unreadable_file_skipped
    project_dir = File.join(@tmpdir, "project")
    rules_dir = File.join(project_dir, ".aider-desk", "rules")
    FileUtils.mkdir_p(rules_dir)
    unreadable = File.join(rules_dir, "secret.md")
    File.write(unreadable, "# Secret")
    File.chmod(0, unreadable) # remove all permissions

    # Expect warning
    assert_output(nil, /Failed to read rule file/) do
      content = @loader.load_rules_content(profile_dir_name: "default", project_dir: project_dir)
      assert_empty content
    end
  ensure
    File.chmod(0644, unreadable) if File.exist?(unreadable)
  end

  def test_global_only_profile
    global_agent_dir = File.join(@global_agents_dir, "global-only", "rules")
    FileUtils.mkdir_p(global_agent_dir)
    File.write(File.join(global_agent_dir, "global.md"), "# Global only")

    paths = @loader.rule_file_paths(profile_dir_name: "global-only", project_dir: nil)
    assert_equal 1, paths.size
    assert paths.first.end_with?("global.md")
  end

  def test_rule_name_from_path
    # This is a unit test for the private method; we need to send
    loader = @loader
    # Mock paths
    global_base = File.join(@global_agents_dir, "default", "rules")
    project_dir = File.join(@tmpdir, "project")
    project_base = File.join(project_dir, ".aider-desk", "rules")
    project_agent_base = File.join(project_dir, ".aider-desk", "agents", "default", "rules")

    # Simulate global rule
    global_path = File.join(global_base, "subdir", "rule.md")
    name = loader.send(:rule_name_from_path, global_path, "default", project_dir)
    assert_equal "global/subdir/rule.md", name

    # Project rule
    project_path = File.join(project_base, "project_rule.md")
    name = loader.send(:rule_name_from_path, project_path, "default", project_dir)
    assert_equal "project/project_rule.md", name

    # Project agent rule
    agent_path = File.join(project_agent_base, "agent_rule.md")
    name = loader.send(:rule_name_from_path, agent_path, "default", project_dir)
    assert_equal "project-agent/agent_rule.md", name

    # Unknown path (fallback)
    unknown = "/some/other/file.md"
    name = loader.send(:rule_name_from_path, unknown, "default", project_dir)
    assert_equal "file.md", name
  end

  def test_validation_rejects_invalid_profile_dir_name
    assert_raises(ArgumentError) { @loader.rule_file_paths(profile_dir_name: "") }
    assert_raises(ArgumentError) { @loader.rule_file_paths(profile_dir_name: "a/b") }
    assert_raises(ArgumentError) { @loader.rule_file_paths(profile_dir_name: "..") }
    if File::SEPARATOR == "\\"
      assert_raises(ArgumentError) { @loader.rule_file_paths(profile_dir_name: "a\\b") }
    end
  end

  def test_symlinked_rule_directories
    # Create a real rule directory
    real_dir = File.join(@tmpdir, "real_rules")
    FileUtils.mkdir_p(real_dir)
    File.write(File.join(real_dir, "real.md"), "# Real rule")

    # Symlink to it from global agent rules
    global_agent_dir = File.join(@global_agents_dir, "default", "rules")
    FileUtils.mkdir_p(File.dirname(global_agent_dir))
    FileUtils.ln_s(real_dir, global_agent_dir)

    paths = @loader.rule_file_paths(profile_dir_name: "default", project_dir: nil)
    assert_equal 1, paths.size
    assert paths.first.end_with?("real.md")
  end
end
