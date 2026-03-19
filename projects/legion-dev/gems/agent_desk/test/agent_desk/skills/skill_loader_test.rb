# frozen_string_literal: true

require "test_helper"
require "benchmark"

class SkillLoaderTest < Minitest::Test
  def setup
    @tmpdir = Dir.mktmpdir
    @global_skills_dir = File.join(@tmpdir, ".aider-desk", "skills")
    FileUtils.mkdir_p(@global_skills_dir)
    @loader = AgentDesk::Skills::SkillLoader.new(global_skills_dir: @global_skills_dir)
  end

  def teardown
    FileUtils.remove_entry(@tmpdir)
  end

  def test_discover_with_no_skills
    skills = @loader.discover(project_dir: nil)
    assert_empty skills
  end

  def test_discover_global_skills
    skill_dir = File.join(@global_skills_dir, "test-skill")
    FileUtils.mkdir_p(skill_dir)
    File.write(File.join(skill_dir, "SKILL.md"), <<~MD)
      ---
      name: Test Skill
      description: A sample skill
      ---
      # Test Skill
    MD

    skills = @loader.discover(project_dir: nil)
    assert_equal 1, skills.size
    skill = skills.first
    assert_equal "Test Skill", skill.name
    assert_equal "A sample skill", skill.description
    assert_equal skill_dir, skill.dir_path
    assert_equal :global, skill.location
  end

  def test_discover_project_skills
    project_dir = File.join(@tmpdir, "project")
    project_skills_dir = File.join(project_dir, ".aider-desk", "skills")
    FileUtils.mkdir_p(project_skills_dir)
    skill_dir = File.join(project_skills_dir, "project-skill")
    FileUtils.mkdir_p(skill_dir)
    File.write(File.join(skill_dir, "SKILL.md"), <<~MD)
      ---
      name: Project Skill
      description: Project specific
      ---
      # Project Skill
    MD

    skills = @loader.discover(project_dir: project_dir)
    assert_equal 1, skills.size
    skill = skills.first
    assert_equal "Project Skill", skill.name
    assert_equal :project, skill.location
  end

  def test_discover_global_and_project_deduplication
    # Global skill
    global_skill_dir = File.join(@global_skills_dir, "duplicate")
    FileUtils.mkdir_p(global_skill_dir)
    File.write(File.join(global_skill_dir, "SKILL.md"), <<~MD)
      ---
      name: Duplicate Skill
      description: Global version
      ---
      # Duplicate Skill
    MD

    # Project skill with same name (different description)
    project_dir = File.join(@tmpdir, "project")
    project_skills_dir = File.join(project_dir, ".aider-desk", "skills")
    FileUtils.mkdir_p(project_skills_dir)
    project_skill_dir = File.join(project_skills_dir, "duplicate")
    FileUtils.mkdir_p(project_skill_dir)
    File.write(File.join(project_skill_dir, "SKILL.md"), <<~MD)
      ---
      name: Duplicate Skill
      description: Project version overrides
      ---
      # Duplicate Skill
    MD

    skills = @loader.discover(project_dir: project_dir)
    assert_equal 1, skills.size
    skill = skills.first
    assert_equal "Duplicate Skill", skill.name
    assert_equal "Project version overrides", skill.description
    assert_equal :project, skill.location
  end

  def test_parse_skill_missing_name_fallback
    skill_dir = File.join(@global_skills_dir, "fallback-skill")
    FileUtils.mkdir_p(skill_dir)
    File.write(File.join(skill_dir, "SKILL.md"), <<~MD)
      ---
      description: No name provided
      ---
      # Skill content
    MD

    skills = @loader.discover(project_dir: nil)
    assert_equal 1, skills.size
    skill = skills.first
    assert_equal "fallback-skill", skill.name
    assert_equal "No name provided", skill.description
  end

  def test_parse_skill_missing_description_empty
    skill_dir = File.join(@global_skills_dir, "empty-desc")
    FileUtils.mkdir_p(skill_dir)
    File.write(File.join(skill_dir, "SKILL.md"), <<~MD)
      ---
      name: Empty Description
      ---
      # Skill content
    MD

    skills = @loader.discover(project_dir: nil)
    assert_equal 1, skills.size
    skill = skills.first
    assert_equal "Empty Description", skill.name
    assert_equal "", skill.description
  end

  def test_parse_skill_malformed_yaml_fallback
    skill_dir = File.join(@global_skills_dir, "bad-yaml")
    FileUtils.mkdir_p(skill_dir)
    File.write(File.join(skill_dir, "SKILL.md"), <<~MD)
      ---
      name: Good Skill
      description: "Unclosed quote
      ---
      # Skill content
    MD

    skills = @loader.discover(project_dir: nil)
    assert_equal 1, skills.size
    skill = skills.first
    assert_equal "bad-yaml", skill.name
    assert_equal "", skill.description
  end

  def test_parse_skill_without_frontmatter
    skill_dir = File.join(@global_skills_dir, "no-frontmatter")
    FileUtils.mkdir_p(skill_dir)
    File.write(File.join(skill_dir, "SKILL.md"), <<~MD)
      # Plain Markdown Skill
      This SKILL.md has no YAML frontmatter delimiters.
      It should still be discovered with name 'no-frontmatter' and empty description.
    MD

    skills = @loader.discover(project_dir: nil)
    assert_equal 1, skills.size
    skill = skills.first
    assert_equal "no-frontmatter", skill.name
    assert_equal "", skill.description
  end

  def test_parse_skill_disallowed_yaml_class_fallback
    skill_dir = File.join(@global_skills_dir, "disallowed-yaml")
    FileUtils.mkdir_p(skill_dir)
    # YAML with a disallowed symbol tag; safe_load should raise Psych::DisallowedClass
    File.write(File.join(skill_dir, "SKILL.md"), <<~MD)
      ---
      name: Disallowed Skill
      sym: !!ruby/sym :foo
      ---
      # Skill content
    MD

    skills = @loader.discover(project_dir: nil)
    assert_equal 1, skills.size
    skill = skills.first
    # Should fallback to directory name due to Psych::DisallowedClass
    assert_equal "disallowed-yaml", skill.name
    assert_equal "", skill.description
  end

  def test_parse_skill_yaml_with_date_permitted
    skill_dir = File.join(@global_skills_dir, "date-yaml")
    FileUtils.mkdir_p(skill_dir)
    File.write(File.join(skill_dir, "SKILL.md"), <<~MD)
      ---
      name: Date Skill
      description: Contains a date
      created_at: 2026-03-01
      ---
      # Skill content
    MD

    skills = @loader.discover(project_dir: nil)
    assert_equal 1, skills.size
    skill = skills.first
    assert_equal "Date Skill", skill.name
    assert_equal "Contains a date", skill.description
  end

  def test_skip_directory_without_skill_md
    skill_dir = File.join(@global_skills_dir, "no-skill-file")
    FileUtils.mkdir_p(skill_dir)
    # No SKILL.md file

    skills = @loader.discover(project_dir: nil)
    assert_empty skills
  end

  def test_read_skill_content
    skill_dir = File.join(@global_skills_dir, "read-test")
    FileUtils.mkdir_p(skill_dir)
    File.write(File.join(skill_dir, "SKILL.md"), "---\nname: Read Test\n---\n# Content")
    skill = AgentDesk::Skills::Skill.new(
      name: "Read Test",
      description: "",
      dir_path: skill_dir,
      location: :global
    )

    content = @loader.read_skill_content(skill)
    assert_includes content, "# Content"
  end

  def test_read_skill_content_nonexistent_file
    skill = AgentDesk::Skills::Skill.new(
      name: "Missing",
      description: "",
      dir_path: "/nonexistent",
      location: :global
    )
    assert_raises(Errno::ENOENT) do
      @loader.read_skill_content(skill)
    end
  end

  def test_path_validation_absolute_path_required
    assert_raises(ArgumentError) do
      @loader.discover(project_dir: "relative/path")
    end
  end

  def test_path_validation_no_dot_dot
    assert_raises(ArgumentError) do
      @loader.discover(project_dir: "/safe/../unsafe")
    end
  end

  def test_path_validation_empty_string
    assert_raises(ArgumentError) do
      @loader.discover(project_dir: "")
    end
  end

  def test_skill_file_path_convenience
    skill = AgentDesk::Skills::Skill.new(
      name: "Test",
      description: "",
      dir_path: "/tmp/test",
      location: :global
    )
    assert_equal "/tmp/test/SKILL.md", skill.skill_file_path
  end

  def test_performance_benchmark_under_100ms
    # Create 50 skill directories with simple SKILL.md files
    base_dir = Dir.mktmpdir
    begin
      50.times do |i|
        skill_dir = File.join(base_dir, "skill-#{i}")
        FileUtils.mkdir_p(skill_dir)
        File.write(File.join(skill_dir, "SKILL.md"), <<~MD)
          ---
          name: Skill #{i}
          description: Skill #{i} description
          ---
          # Content
        MD
      end

      loader = AgentDesk::Skills::SkillLoader.new(global_skills_dir: base_dir)
      elapsed = Benchmark.realtime do
        loader.discover(project_dir: nil)
      end
      assert_operator elapsed, :<, 0.1, "Discovery of 50 skills must take < 100ms (took #{elapsed * 1000}ms)"
    ensure
      FileUtils.remove_entry(base_dir)
    end
  end

  def test_activate_skill_tool_description_format
    skill_dir = File.join(@global_skills_dir, "tool-skill")
    FileUtils.mkdir_p(skill_dir)
    File.write(File.join(skill_dir, "SKILL.md"), <<~MD)
      ---
      name: Tool Skill
      description: For testing tool description
      ---
      # Tool Skill
    MD

    tool = @loader.activate_skill_tool(project_dir: nil)
    description = tool.description
    assert_includes description, "Tool Skill"
    assert_includes description, "For testing tool description"
    assert_match(/Activate a skill by providing its name\./, description)
  end

  def test_activate_skill_tool_execution
    skill_dir = File.join(@global_skills_dir, "exec-skill")
    FileUtils.mkdir_p(skill_dir)
    File.write(File.join(skill_dir, "SKILL.md"), <<~MD)
      ---
      name: Exec Skill
      description: Exec desc
      ---
      # Exec Skill Content
    MD

    tool = @loader.activate_skill_tool(project_dir: nil)
    result = tool.execute({ "skill" => "Exec Skill" }, context: {})
    assert_includes result, "# Exec Skill Content"
  end

  def test_activate_skill_tool_unknown_skill_error
    tool = @loader.activate_skill_tool(project_dir: nil)
    error = assert_raises(ArgumentError) do
      tool.execute({ "skill" => "Unknown" }, context: {})
    end
    assert_includes error.message, "Unknown skill"
  end
end
