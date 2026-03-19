# frozen_string_literal: true

require "test_helper"

class SkillsToolsTest < Minitest::Test
  def setup
    @tmpdir = Dir.mktmpdir
    @global_skills_dir = File.join(@tmpdir, ".aider-desk", "skills")
    FileUtils.mkdir_p(@global_skills_dir)
  end

  def teardown
    FileUtils.remove_entry(@tmpdir)
  end

  def test_create_returns_tool_set
    tool_set = AgentDesk::Tools::SkillsTools.create(project_dir: @tmpdir)
    assert_instance_of AgentDesk::Tools::ToolSet, tool_set
    assert_equal 1, tool_set.size
    tool = tool_set.each.first
    assert_equal AgentDesk::SKILLS_TOOL_ACTIVATE_SKILL, tool.name
    assert_equal AgentDesk::SKILLS_TOOL_GROUP_NAME, tool.group_name
  end

  def test_create_with_custom_skill_loader
    skill_loader = AgentDesk::Skills::SkillLoader.new(global_skills_dir: @global_skills_dir)
    tool_set = AgentDesk::Tools::SkillsTools.create(project_dir: @tmpdir, skill_loader: skill_loader)
    assert_equal 1, tool_set.size
  end

  def test_create_without_skills
    tool_set = AgentDesk::Tools::SkillsTools.create(project_dir: @tmpdir)
    tool = tool_set.each.first
    description = tool.description
    assert_includes description, "No skills available."
  end

  def test_create_with_skills
    skill_dir = File.join(@global_skills_dir, "test-skill")
    FileUtils.mkdir_p(skill_dir)
    File.write(File.join(skill_dir, "SKILL.md"), <<~MD)
      ---
      name: Test Skill
      description: A sample skill
      ---
      # Test Skill
    MD

    tool_set = AgentDesk::Tools::SkillsTools.create(project_dir: @tmpdir)
    tool = tool_set.each.first
    description = tool.description
    assert_includes description, "Test Skill"
    assert_includes description, "A sample skill"
  end

  def test_tool_execution
    skill_dir = File.join(@global_skills_dir, "exec-skill")
    FileUtils.mkdir_p(skill_dir)
    File.write(File.join(skill_dir, "SKILL.md"), <<~MD)
      ---
      name: Exec Skill
      description: Exec desc
      ---
      # Exec Skill Content
    MD

    tool_set = AgentDesk::Tools::SkillsTools.create(project_dir: @tmpdir)
    tool = tool_set.each.first
    result = tool.execute({ "skill" => "Exec Skill" }, context: {})
    assert_includes result, "# Exec Skill Content"
  end
end
