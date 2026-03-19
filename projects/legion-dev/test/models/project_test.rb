# frozen_string_literal: true

require "test_helper"

class ProjectTest < ActiveSupport::TestCase
  test "factory creates valid record" do
    project = build(:project)
    assert project.valid?
  end

  test "name validation" do
    project = build(:project, name: nil)
    assert_not project.valid?
    assert_includes project.errors[:name], "can't be blank"
  end

  test "path validation" do
    project = create(:project, path: "/unique/path")
    duplicate = build(:project, path: "/unique/path")
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:path], "has already been taken"
  end

  test "associations" do
    project = create(:project)
    assert_difference("project.agent_teams.count", 1) do
      create(:agent_team, project: project)
    end
    assert_difference("project.workflow_runs.count", 1) do
      create(:workflow_run, project: project)
    end
    assert_difference("project.tasks.count", 1) do
      create(:task, project: project)
    end
  end
end
