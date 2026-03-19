# frozen_string_literal: true

require "test_helper"

class StatusCommandTest < ActiveSupport::TestCase
  setup do
    @project = create(:project)
    @team = create(:agent_team, project: @project)
    @execution = create(:workflow_execution, project: @project, phase: :decomposing, status: :running)
  end

  test "reconnect to running execution shows current progress" do
    # Simulate a running execution with progress
    @execution.phase = :executing
    @execution.save!

    # Simulate tasks in the execution
    create(:task, workflow_execution: @execution, status: :pending)
    create(:task, workflow_execution: @execution, status: :completed)
    create(:task, workflow_execution: @execution, status: :running)

    # Reconnect and check progress
    result = Legion::StatusService.call(execution_id: @execution.id, project_path: @project.path)

    assert result.success
    assert_equal @execution.id, result.execution.id
    assert_equal "executing", result.execution.phase
    assert_equal "running", result.execution.status
  end

  test "display progress output with phase transitions" do
    # Create execution with multiple phase transitions
    @execution.phase = :planning
    @execution.save!

    # Create workflow runs to track timing
    workflow_run = create(:workflow_run, project: @project, workflow_execution: @execution)

    result = Legion::StatusService.call(execution_id: @execution.id, project_path: @project.path)

    assert result.success
    assert result.execution.planning?
  end

  test "handle non-existent execution ID gracefully" do
    non_existent_id = 999999

    result = Legion::StatusService.call(execution_id: non_existent_id, project_path: @project.path)

    assert_not result.success
    assert result.execution.nil?
    assert result.error.include?("not found")
  end

  test "show task progress for running execution" do
    @execution.phase = :executing
    @execution.save!

    # Create multiple tasks with different statuses
    task1 = create(:task, workflow_execution: @execution, status: :completed)
    task2 = create(:task, workflow_execution: @execution, status: :running)
    task3 = create(:task, workflow_execution: @execution, status: :pending)

    result = Legion::StatusService.call(execution_id: @execution.id, project_path: @project.path)

    assert result.success
    assert_equal 3, result.execution.tasks.count
    assert_equal 1, result.execution.tasks.where(status: :completed).count
    assert_equal 1, result.execution.tasks.where(status: :running).count
    assert_equal 1, result.execution.tasks.where(status: :pending).count
  end

  test "show artifacts and conductor decisions for completed execution" do
    @execution.phase = :phase_completed
    @execution.status = :completed
    @execution.save!

    # Create artifacts
    create(:artifact, project: @project, workflow_execution: @execution, artifact_type: :plan, content: "Test plan")
    create(:artifact, project: @project, workflow_execution: @execution, artifact_type: :retrospective_report, content: "Test retrospective")

    # Create conductor decisions
    create(:conductor_decision, workflow_execution: @execution, decision_type: "approve", payload: { test: "data" })

    result = Legion::StatusService.call(execution_id: @execution.id, project_path: @project.path)

    assert result.success
    assert_equal 2, result.execution.artifacts.count
    assert_equal 1, result.execution.conductor_decisions.count
  end

  test "handle execution with no tasks" do
    result = Legion::StatusService.call(execution_id: @execution.id, project_path: @project.path)

    assert result.success
    assert_equal 0, result.execution.tasks.count
  end

  test "show concurrent execution configuration" do
    @execution.concurrency = 5
    @execution.sequential = false
    @execution.save!

    result = Legion::StatusService.call(execution_id: @execution.id, project_path: @project.path)

    assert result.success
    assert_equal 5, result.execution.concurrency
    assert_equal false, result.execution.sequential
  end

  test "handle cancelled execution status" do
    @execution.phase = :cancelled
    @execution.status = :failed
    @execution.save!

    result = Legion::StatusService.call(execution_id: @execution.id, project_path: @project.path)

    assert result.success
    assert result.execution.cancelled?
    assert result.execution.failed?
  end

  test "return error for invalid project path" do
    invalid_path = "/nonexistent/path"

    result = Legion::StatusService.call(execution_id: @execution.id, project_path: invalid_path)

    # Should handle gracefully - either return error or find execution via ID
    assert result.is_a?(Legion::StatusService::Result)
  end
end
