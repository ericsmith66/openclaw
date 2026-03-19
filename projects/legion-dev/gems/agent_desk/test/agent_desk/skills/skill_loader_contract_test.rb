# frozen_string_literal: true

require "test_helper"

class SkillLoaderContractTest < Minitest::Test
  def setup
    @tmpdir = Dir.mktmpdir
    @global_skills_dir = File.join(@tmpdir, ".aider-desk", "skills")
    FileUtils.mkdir_p(@global_skills_dir)
    @loader = AgentDesk::Skills::SkillLoader.new(global_skills_dir: @global_skills_dir)
  end

  def teardown
    FileUtils.remove_entry(@tmpdir)
  end

  def test_discover
    # Place fixture skill in global tier
    skill_dir = File.join(@global_skills_dir, "test-skill")
    FileUtils.mkdir_p(skill_dir)
    fixture_source = File.join(__dir__, "..", "..", "fixtures", "skills", "test-skill", "SKILL.md")
    FileUtils.cp(fixture_source, File.join(skill_dir, "SKILL.md"))

    skills = @loader.discover(project_dir: nil)
    assert_equal 1, skills.size
    skill = skills.first
    assert_equal "Test Skill", skill.name
    assert_equal "A sample skill for testing", skill.description
    assert_equal skill_dir, skill.dir_path
    assert_equal :global, skill.location

    # With project directory (no project skills yet)
    skills = @loader.discover(project_dir: @tmpdir)
    assert_equal 1, skills.size
    assert_equal "Test Skill", skills.first.name
  end

  def test_parse_skill_md
    skill_dir = File.join(@global_skills_dir, "test-skill")
    FileUtils.mkdir_p(skill_dir)
    fixture_source = File.join(__dir__, "..", "..", "fixtures", "skills", "test-skill", "SKILL.md")
    FileUtils.cp(fixture_source, File.join(skill_dir, "SKILL.md"))

    content = @loader.read_skill_content(AgentDesk::Skills::Skill.new(
      name: "Test Skill",
      description: "A sample skill for testing",
      dir_path: skill_dir,
      location: :global
    ))
    assert_includes content, "# Test Skill"
    assert_includes content, "This is a sample skill for contract tests."
  end

  def test_activate_skill_tool
    # Place fixture skill in global tier
    skill_dir = File.join(@global_skills_dir, "test-skill")
    FileUtils.mkdir_p(skill_dir)
    fixture_source = File.join(__dir__, "..", "..", "fixtures", "skills", "test-skill", "SKILL.md")
    FileUtils.cp(fixture_source, File.join(skill_dir, "SKILL.md"))

    tool = @loader.activate_skill_tool(project_dir: nil)
    assert_equal AgentDesk::SKILLS_TOOL_ACTIVATE_SKILL, tool.name
    assert_equal AgentDesk::SKILLS_TOOL_GROUP_NAME, tool.group_name

    # Tool description should list the skill
    description = tool.description
    assert_includes description, "Test Skill"
    assert_includes description, "A sample skill for testing"

    # Tool execution returns skill content
    result = tool.execute({ "skill" => "Test Skill" }, context: {})
    assert_includes result, "# Test Skill"
    assert_includes result, "This is a sample skill for contract tests."

    # Unknown skill raises ArgumentError
    error = assert_raises(ArgumentError) do
      tool.execute({ "skill" => "Nonexistent" }, context: {})
    end
    assert_includes error.message, "Unknown skill"
  end
end
