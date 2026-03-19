# frozen_string_literal: true

require "test_helper"

class TaskTest < ActiveSupport::TestCase
  setup do
    @project = create(:project)
    @team_membership = create(:team_membership)
    @workflow_run = create(:workflow_run, project: @project, team_membership: @team_membership)
  end

  test "factory creates valid record" do
    task = build(:task, project: @project, team_membership: @team_membership, workflow_run: @workflow_run)
    assert task.valid?
  end

  test "prompt validation" do
    task = build(:task, project: @project, team_membership: @team_membership, workflow_run: @workflow_run, prompt: nil)
    assert_not task.valid?
    assert_includes task.errors[:prompt], "can't be blank"
  end

  test "score validations" do
    task = build(:task, project: @project, team_membership: @team_membership, workflow_run: @workflow_run, files_score: 0)
    assert_not task.valid?
    assert_includes task.errors[:files_score], "is not included in the list"

    task = build(:task, project: @project, team_membership: @team_membership, workflow_run: @workflow_run, concepts_score: 5)
    assert_not task.valid?

    task = build(:task, project: @project, team_membership: @team_membership, workflow_run: @workflow_run, dependencies_score: 2)
    assert task.valid?
  end

  test "total score computation" do
    task = build(:task, project: @project, team_membership: @team_membership, workflow_run: @workflow_run, files_score: 2, concepts_score: 3, dependencies_score: 1)
    task.valid?
    assert_equal 6, task.total_score
  end

  test "total score nil when any score missing" do
    task = build(:task, project: @project, team_membership: @team_membership, workflow_run: @workflow_run, files_score: 2, concepts_score: nil)
    task.valid?
    assert_nil task.total_score
  end

  test "status enum" do
    task = create(:task, project: @project, team_membership: @team_membership, workflow_run: @workflow_run)
    assert task.pending?
    task.ready!
    assert task.ready?
    task.running!
    assert task.running?
    task.completed!
    assert task.completed?
    task.failed!
    assert task.failed?
    task.skipped!
    assert task.skipped?
  end

  test "task_type enum" do
    task = create(:task, project: @project, team_membership: @team_membership, workflow_run: @workflow_run, task_type: :code)
    assert task.code?
    task.test!
    assert task.test?
    task.review!
    assert task.review?
    task.debug!
    assert task.debug?
  end

  test "dispatchable method" do
    task = create(:task, project: @project, team_membership: @team_membership, workflow_run: @workflow_run, status: :pending)
    # No dependencies -> dispatchable
    assert task.dispatchable?
    # With dependency not completed
    dep = create(:task, project: @project, team_membership: @team_membership, workflow_run: @workflow_run, status: :pending)
    create(:task_dependency, task: task, depends_on_task: dep)
    task.reload
    assert_not task.dispatchable?
    dep.completed!
    task.reload
    assert task.dispatchable?
    # If task status is ready (already marked ready) but dependencies satisfied
    task.ready!
    assert task.dispatchable?
  end

  test "over_threshold method" do
    task = build(:task, project: @project, team_membership: @team_membership, workflow_run: @workflow_run, files_score: 3, concepts_score: 2, dependencies_score: 2)
    task.valid?
    assert_equal 7, task.total_score
    assert task.over_threshold?
    task = build(:task, project: @project, team_membership: @team_membership, workflow_run: @workflow_run, files_score: 1, concepts_score: 1, dependencies_score: 1)
    task.valid?
    assert_equal 3, task.total_score
    assert_not task.over_threshold?
  end

  test "parallel_eligible method" do
    task = create(:task, project: @project, team_membership: @team_membership, workflow_run: @workflow_run)
    # No dependencies -> eligible
    assert task.parallel_eligible?
    # With dependency not completed
    dep = create(:task, project: @project, team_membership: @team_membership, workflow_run: @workflow_run, status: :pending)
    create(:task_dependency, task: task, depends_on_task: dep)
    task.reload
    assert_not task.parallel_eligible?
    dep.completed!
    task.reload
    assert task.parallel_eligible?
  end

  test "associations" do
    task = create(:task, project: @project, team_membership: @team_membership, workflow_run: @workflow_run)
    # dependencies
    dep = create(:task, project: @project, team_membership: @team_membership, workflow_run: @workflow_run)
    create(:task_dependency, task: task, depends_on_task: dep)
    task.reload
    assert_includes task.dependencies, dep
    # dependents
    dependent = create(:task, project: @project, team_membership: @team_membership, workflow_run: @workflow_run)
    create(:task_dependency, task: dependent, depends_on_task: task)
    task.reload
    assert_includes task.dependents, dependent
    # execution_run
    execution = create(:workflow_run, project: @project, team_membership: @team_membership, task: task)
    task.update(execution_run: execution)
    assert_equal execution, task.execution_run
  end

  test "scopes" do
    task1 = create(:task, project: @project, team_membership: @team_membership, workflow_run: @workflow_run, status: :pending, position: 2)
    task2 = create(:task, project: @project, team_membership: @team_membership, workflow_run: @workflow_run, status: :completed, position: 1)
    assert_equal [ task1 ], Task.pending.to_a
    assert_equal [ task2 ], Task.completed.to_a
    assert_equal [ task2, task1 ], Task.by_position.to_a
  end

  test "ready scope with no dependencies" do
    task = create(:task, project: @project, team_membership: @team_membership, workflow_run: @workflow_run, status: :pending)
    assert_includes Task.ready, task
  end

  test "ready scope with completed dependencies" do
    task = create(:task, project: @project, team_membership: @team_membership, workflow_run: @workflow_run, status: :pending)
    dep = create(:task, project: @project, team_membership: @team_membership, workflow_run: @workflow_run, status: :completed)
    create(:task_dependency, task: task, depends_on_task: dep)
    assert_includes Task.ready, task
  end

  test "ready scope excludes tasks with incomplete dependencies" do
    task = create(:task, project: @project, team_membership: @team_membership, workflow_run: @workflow_run, status: :pending)
    dep = create(:task, project: @project, team_membership: @team_membership, workflow_run: @workflow_run, status: :pending)
    create(:task_dependency, task: task, depends_on_task: dep)
    assert_not_includes Task.ready, task
  end

  test "ready_for_run scope filters by workflow_run" do
    run_a = @workflow_run
    run_b = create(:workflow_run, project: @project, team_membership: @team_membership)

    task_a = create(:task, project: @project, team_membership: @team_membership, workflow_run: run_a, status: :pending)
    task_b = create(:task, project: @project, team_membership: @team_membership, workflow_run: run_b, status: :pending)

    ready_for_a = Task.ready_for_run(run_a).to_a
    ready_for_b = Task.ready_for_run(run_b).to_a

    assert_includes ready_for_a, task_a
    assert_not_includes ready_for_a, task_b
    assert_includes ready_for_b, task_b
    assert_not_includes ready_for_b, task_a
  end

  test "resettable? method returns false when status is not failed" do
    task = build(:task, project: @project, team_membership: @team_membership, workflow_run: @workflow_run, status: :pending, retry_count: 0)
    assert_not task.resettable?

    task.status = "ready"
    assert_not task.resettable?

    task.status = "completed"
    assert_not task.resettable?
  end

  test "resettable? method returns true when status is failed and retry_count < 3" do
    task = build(:task, project: @project, team_membership: @team_membership, workflow_run: @workflow_run, status: :failed, retry_count: 0)
    assert task.resettable?

    task.retry_count = 1
    assert task.resettable?

    task.retry_count = 2
    assert task.resettable?
  end

  test "resettable? method returns false when status is failed but retry_count >= 3" do
    task = build(:task, project: @project, team_membership: @team_membership, workflow_run: @workflow_run, status: :failed, retry_count: 3)
    assert_not task.resettable?

    task.retry_count = 4
    assert_not task.resettable?
  end

  test "error_context returns hash with retry_count and last_error" do
    task = build(:task, project: @project, team_membership: @team_membership, workflow_run: @workflow_run, retry_count: 2, last_error: "Timeout error")
    context = task.error_context

    assert_equal 2, context[:retry_count]
    assert_equal "Timeout error", context[:last_error]

    task.retry_count = 0
    task.last_error = nil
    context = task.error_context
    assert_equal 0, context[:retry_count]
    assert_nil context[:last_error]
  end
end
