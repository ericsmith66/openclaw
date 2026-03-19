# frozen_string_literal: true

require "test_helper"

class WorkflowRunTest < ActiveSupport::TestCase
  setup do
    @project = create(:project)
    @team_membership = create(:team_membership)
  end

  test "factory creates valid record" do
    run = build(:workflow_run, project: @project, team_membership: @team_membership)
    assert run.valid?
  end

  test "prompt validation" do
    run = build(:workflow_run, project: @project, team_membership: @team_membership, prompt: nil)
    assert_not run.valid?
    assert_includes run.errors[:prompt], "can't be blank"
  end

  test "status enum" do
    run = create(:workflow_run, project: @project, team_membership: @team_membership)
    assert run.queued?
    run.running!
    assert run.running?
    run.completed!
    assert run.completed?
    run.failed!
    assert run.failed?
    run.at_risk!
    assert run.at_risk?
    run.decomposing!
    assert run.decomposing?
    run.handed_off!
    assert run.handed_off?
    run.budget_exceeded!
    assert run.budget_exceeded?
    run.iteration_limit!
    assert run.iteration_limit?
  end

  test "status default" do
    run = WorkflowRun.new(project: @project, team_membership: @team_membership, prompt: "test")
    assert_equal "queued", run.status
  end

  test "associations" do
    run = create(:workflow_run, project: @project, team_membership: @team_membership)
    assert_difference("run.workflow_events.count", 1) do
      create(:workflow_event, workflow_run: run)
    end
    assert_difference("run.tasks.count", 1) do
      create(:task, workflow_run: run, project: @project, team_membership: @team_membership)
    end
    # belongs to project and team_membership
    assert_equal @project, run.project
    assert_equal @team_membership, run.team_membership
  end

  test "scopes" do
    run1 = create(:workflow_run, project: @project, team_membership: @team_membership, status: :queued, created_at: 1.day.ago)
    run2 = create(:workflow_run, project: @project, team_membership: @team_membership, status: :running, created_at: Time.current)
    # Scope assertions to this test's team to avoid cross-worker contamination in parallel runs
    team = @team_membership.agent_team
    team_runs = WorkflowRun.for_team(team)
    assert_equal [ run2, run1 ], team_runs.recent.to_a
    assert_equal [ run1 ], team_runs.by_status(:queued).to_a
    # for_team scope
    assert_equal [ run1, run2 ], team_runs.order(:id).to_a
  end
end
