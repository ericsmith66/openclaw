# frozen_string_literal: true

require "test_helper"

class SkillLoaderTest < ActiveSupport::TestCase
  LEGION_DIR = Rails.root.to_s

  EXPECTED_SKILLS = %w[
    agent-forge-logging
    rails-best-practices
    rails-capybara-system-testing
    rails-daisyui-components
    rails-error-handling-logging
    rails-minitest-vcr
    rails-service-patterns
    rails-tailwind-ui
    rails-turbo-hotwire
    rails-view-components
  ].freeze

  setup do
    @loader = AgentDesk::Skills::SkillLoader.new
  end

  test "discovers exactly 10 project skills" do
    skills = @loader.discover(project_dir: LEGION_DIR)
    project_skills = skills.select { |s| s.location == :project }
    assert_equal 10, project_skills.size,
      "Expected 10 project skills, found #{project_skills.size}: #{project_skills.map(&:name).join(', ')}"
  end

  test "all expected skill directories exist" do
    skills_dir = File.join(LEGION_DIR, ".aider-desk", "skills")
    EXPECTED_SKILLS.each do |skill_name|
      skill_path = File.join(skills_dir, skill_name)
      assert File.directory?(skill_path), "Skill directory missing: #{skill_name}"
    end
  end

  test "each skill directory contains a SKILL.md file" do
    skills_dir = File.join(LEGION_DIR, ".aider-desk", "skills")
    EXPECTED_SKILLS.each do |skill_name|
      skill_file = File.join(skills_dir, skill_name, "SKILL.md")
      assert File.exist?(skill_file), "#{skill_name}/SKILL.md missing"
    end
  end

  test "skill content is readable and non-empty" do
    skills = @loader.discover(project_dir: LEGION_DIR)
    skills.select { |s| s.location == :project }.each do |skill|
      content = @loader.read_skill_content(skill)
      refute_empty content, "#{skill.name} SKILL.md is empty"
    end
  end
end
