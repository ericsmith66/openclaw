# frozen_string_literal: true

require "test_helper"

class RulesLoaderTest < ActiveSupport::TestCase
  LEGION_DIR = Rails.root.to_s

  setup do
    @loader = AgentDesk::Rules::RulesLoader.new
  end

  test "project-wide rules directory contains rails-base-rules.md" do
    rules_dir = File.join(LEGION_DIR, ".aider-desk", "rules")
    assert File.directory?(rules_dir), ".aider-desk/rules/ directory not found"

    rules_file = File.join(rules_dir, "rails-base-rules.md")
    assert File.exist?(rules_file), "rails-base-rules.md not found"
  end

  test "rails-base-rules.md has non-empty content" do
    rules_file = File.join(LEGION_DIR, ".aider-desk", "rules", "rails-base-rules.md")
    content = File.read(rules_file)
    refute_empty content
    assert_match(/Rails 8 Base Rules/, content)
  end

  test "rails-base-rules.md has no Junie references" do
    rules_file = File.join(LEGION_DIR, ".aider-desk", "rules", "rails-base-rules.md")
    content = File.read(rules_file)
    refute_match(/junie/i, content, "rails-base-rules.md still contains Junie reference")
  end

  test "rule_file_paths discovers project-wide rules for any agent" do
    # Project-wide rules apply to all agents via the .aider-desk/rules/ directory
    paths = @loader.rule_file_paths(profile_dir_name: "ror-rails-legion", project_dir: LEGION_DIR)
    md_basenames = paths.map { |p| File.basename(p) }
    assert_includes md_basenames, "rails-base-rules.md"
  end
end
