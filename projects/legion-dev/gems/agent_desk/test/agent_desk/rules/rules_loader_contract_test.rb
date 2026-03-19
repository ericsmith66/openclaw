# frozen_string_literal: true

require "test_helper"

class RulesLoaderContractTest < Minitest::Test
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
    # Place fixture rule in global agent tier
    global_agent_dir = File.join(@global_agents_dir, "default", "rules")
    FileUtils.mkdir_p(global_agent_dir)
    fixture_source = File.join(__dir__, "..", "..", "fixtures", "rules", "test-rule.md")
    FileUtils.cp(fixture_source, File.join(global_agent_dir, "test-rule.md"))

    paths = @loader.rule_file_paths(profile_dir_name: "default", project_dir: nil)
    assert_equal 1, paths.size
    assert paths.first.end_with?("test-rule.md")

    # Ensure file is readable
    content = @loader.load_rules_content(profile_dir_name: "default", project_dir: nil)
    assert_includes content, "# Test Rule"
    assert_includes content, "<![CDATA["
  end

  def test_content_formatting
    # Place fixture rule in project tier
    project_dir = File.join(@tmpdir, "project")
    project_rules_dir = File.join(project_dir, ".aider-desk", "rules")
    FileUtils.mkdir_p(project_rules_dir)
    fixture_source = File.join(__dir__, "..", "..", "fixtures", "rules", "test-rule.md")
    FileUtils.cp(fixture_source, File.join(project_rules_dir, "test-rule.md"))

    content = @loader.load_rules_content(profile_dir_name: "default", project_dir: project_dir)
    # Must contain CDATA wrapper
    assert_match(/<File name="project\/test-rule\.md"><!\[CDATA\[.*\]\]><\/File>/m, content)
    # Must contain fixture content
    assert_includes content, "# Test Rule"
    assert_includes content, "This is a sample rule for contract tests."
  end
end
