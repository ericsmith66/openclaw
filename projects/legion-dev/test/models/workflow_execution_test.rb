# frozen_string_literal: true

require "test_helper"

class WorkflowExecutionTest < ActiveSupport::TestCase
  setup do
    @project = create(:project)
  end

  test "factory creates valid record" do
    execution = build(:workflow_execution, project: @project)
    assert execution.valid?
  end

  test "validations" do
    # Missing project
    execution = build(:workflow_execution, project: nil)
    assert_not execution.valid?
    assert_includes execution.errors[:project], "must exist"

    # Invalid concurrency (zero)
    execution = build(:workflow_execution, project: @project, concurrency: 0)
    assert_not execution.valid?
    assert_includes execution.errors[:concurrency], "must be greater than 0"

    # Invalid concurrency (negative)
    execution = build(:workflow_execution, project: @project, concurrency: -1)
    assert_not execution.valid?
    assert_includes execution.errors[:concurrency], "must be greater than 0"

    # Invalid task_retry_limit (negative)
    execution = build(:workflow_execution, project: @project, task_retry_limit: -1)
    assert_not execution.valid?
    assert_includes execution.errors[:task_retry_limit], "must be greater than or equal to 0"

    # Missing prd_path
    execution = build(:workflow_execution, project: @project, prd_path: nil)
    assert_not execution.valid?
    assert_includes execution.errors[:prd_path], "can't be blank"
  end

  test "status enum" do
    execution = create(:workflow_execution, project: @project, status: :running)
    assert execution.running?
    execution.completed!
    assert execution.completed?
    execution.failed!
    assert execution.failed?
  end

  test "status enum with validation" do
    execution = build(:workflow_execution, project: @project, status: :invalid_status)
    assert_not execution.valid?
    assert_includes execution.errors[:status], "is not included in the list"
  end

  test "phase enum with all 9 values" do
    # All 9 phase values: decomposing, executing, planning, reviewing, validating, synthesizing, iterating, phase_completed, cancelled
    phase_values = %w[decomposing executing planning reviewing validating synthesizing iterating phase_completed cancelled]
    phase_values.each do |phase|
      execution = build(:workflow_execution, project: @project, phase: phase)
      assert execution.valid?, "Phase #{phase} should be valid"
    end

    # Test each phase value
    execution = create(:workflow_execution, project: @project, phase: :decomposing)
    assert execution.decomposing?

    execution.phase = :executing
    assert execution.executing?
    execution.phase = :planning
    assert execution.planning?
    execution.phase = :reviewing
    assert execution.reviewing?
    execution.phase = :validating
    assert execution.validating?
    execution.phase = :synthesizing
    assert execution.synthesizing?
    execution.phase = :iterating
    assert execution.iterating?
    execution.phase = :phase_completed
    assert execution.phase_completed?
    execution.phase = :cancelled
    assert execution.cancelled?
  end

  test "phase enum invalid value" do
    execution = build(:workflow_execution, project: @project, phase: :invalid_phase)
    assert_not execution.valid?
    assert_includes execution.errors[:phase], "is not included in the list"
  end

  test "associations to workflow_runs" do
    execution = create(:workflow_execution, project: @project)
    assert_difference("execution.workflow_runs.count", 1) do
      create(:workflow_run, project: @project, workflow_execution: execution)
    end
  end

  test "associations to artifacts" do
    execution = create(:workflow_execution, project: @project)
    workflow_run = create(:workflow_run, project: @project, workflow_execution: execution)
    assert_difference("execution.artifacts.count", 1) do
      create(:artifact, project: @project, workflow_run: workflow_run, workflow_execution: execution, artifact_type: :plan, content: "Test artifact")
    end
  end

  test "associations to conductor_decisions" do
    execution = create(:workflow_execution, project: @project)
    assert_difference("execution.conductor_decisions.count", 1) do
      create(:conductor_decision, workflow_execution: execution, decision_type: "approve", payload: { test: "data" })
    end
  end

  test "associations to project" do
    execution = create(:workflow_execution, project: @project)
    assert_equal @project, execution.project
  end

  test "prd_snapshot population" do
    snapshot_text = "# PRD Snapshot\n\n## Requirements\n- Test requirement"
    execution = build(:workflow_execution, project: @project, prd_snapshot: snapshot_text)
    assert_equal snapshot_text, execution.prd_snapshot
  end

  test "prd_content_hash computation" do
    snapshot_text = "# PRD Snapshot\n\n## Requirements\n- Test requirement"
    execution = build(:workflow_execution, project: @project, prd_snapshot: snapshot_text)
    execution.prd_content_hash!
    expected_hash = Digest::MD5.hexdigest(snapshot_text)
    assert_equal expected_hash, execution.prd_content_hash
  end

  test "prd_content_hash is nil when prd_snapshot is empty" do
    execution = build(:workflow_execution, project: @project, prd_snapshot: nil)
    execution.prd_content_hash!
    assert_nil execution.prd_content_hash
  end

  test "decomposition_attempt default 0" do
    execution = build(:workflow_execution, project: @project, decomposition_attempt: nil)
    assert_equal 0, execution.decomposition_attempt
  end

  test "task_retry_limit default 3" do
    execution = build(:workflow_execution, project: @project, task_retry_limit: nil)
    assert_equal 3, execution.task_retry_limit
  end

  test "concurrency default 3" do
    execution = build(:workflow_execution, project: @project, concurrency: nil)
    assert_equal 3, execution.concurrency
  end

  test "sequential default false" do
    execution = build(:workflow_execution, project: @project, sequential: nil)
    assert_equal false, execution.sequential
  end

  test "status default" do
    execution = WorkflowExecution.new(project: @project)
    assert_equal "running", execution.status
  end

  test "phase default" do
    execution = WorkflowExecution.new(project: @project)
    assert_equal "decomposing", execution.phase
  end
end
