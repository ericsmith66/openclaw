# frozen_string_literal: true

require "test_helper"
require "rake"

class TeamsRakeTest < ActiveSupport::TestCase
  parallelize(workers: 1)

  setup do
    Rails.application.load_tasks if Rake::Task.tasks.empty?
    Rake::Task["teams:import"].reenable

    @fixture_path = Rails.root.join("test/fixtures/aider_desk/valid_team").to_s
    # Ensure agent-a config exists (mirrors integration test setup)
    config_path = File.join(@fixture_path, "agents/agent-a/config.json")
    File.write(
      config_path,
      '{"id":"agent-a-id","name":"Agent A","provider":"anthropic","model":"claude-sonnet",' \
      '"maxIterations":100,"usePowerTools":true,"customInstructions":"Be helpful"}'
    )
  end

  teardown do
    ENV.delete("PROJECT_PATH")
    ENV.delete("TEAM_NAME")
    ENV.delete("DRY_RUN")
  end

  # Without PROJECT_PATH the task defaults to Rails.root
  test "import task defaults project_path to Rails.root when PROJECT_PATH is not set" do
    ENV["TEAM_NAME"] = "RakeDefaultTest_#{SecureRandom.hex(4)}"

    assert_nothing_raised do
      Rake::Task["teams:import"].invoke(@fixture_path)
    end

    project = Project.find_by(path: Rails.root.to_s)
    assert project, "Expected a Project record for Rails.root"
  end

  # With PROJECT_PATH set the task creates a Project record for that path
  test "import task uses PROJECT_PATH env var as project_path when set" do
    custom_path = "/tmp/legion_rake_test_#{SecureRandom.hex(6)}"
    ENV["PROJECT_PATH"] = custom_path
    ENV["TEAM_NAME"]    = "RakeCustomPathTest_#{SecureRandom.hex(4)}"

    assert_nothing_raised do
      Rake::Task["teams:import"].invoke(@fixture_path)
    end

    project = Project.find_by(path: custom_path)
    assert project, "Expected a Project record at the PROJECT_PATH (#{custom_path})"
    assert_equal File.basename(custom_path), project.name
  end

  # PROJECT_PATH with a relative path is expanded to absolute
  test "import task expands relative PROJECT_PATH to absolute" do
    ENV["PROJECT_PATH"] = "relative/path/to/project"
    ENV["TEAM_NAME"]    = "RakeRelPathTest_#{SecureRandom.hex(4)}"
    expected_abs = File.expand_path("relative/path/to/project")

    assert_nothing_raised do
      Rake::Task["teams:import"].invoke(@fixture_path)
    end

    project = Project.find_by(path: expected_abs)
    assert project, "Expected a Project record at the expanded absolute path (#{expected_abs})"
  end
end
