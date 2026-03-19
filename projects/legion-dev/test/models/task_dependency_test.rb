# frozen_string_literal: true

require "test_helper"

class TaskDependencyTest < ActiveSupport::TestCase
  setup do
    @project = create(:project)
    @team_membership = create(:team_membership)
    @workflow_run = create(:workflow_run, project: @project, team_membership: @team_membership)
    @task1 = create(:task, project: @project, team_membership: @team_membership, workflow_run: @workflow_run)
    @task2 = create(:task, project: @project, team_membership: @team_membership, workflow_run: @workflow_run)
    @task3 = create(:task, project: @project, team_membership: @team_membership, workflow_run: @workflow_run)
  end

  test "factory creates valid record" do
    dependency = build(:task_dependency, task: @task1, depends_on_task: @task2)
    assert dependency.valid?
  end

  test "self reference prevention" do
    dependency = build(:task_dependency, task: @task1, depends_on_task: @task1)
    assert_not dependency.valid?
    assert_includes dependency.errors[:depends_on_task_id], "cannot depend on itself"
  end

  test "uniqueness validation" do
    create(:task_dependency, task: @task1, depends_on_task: @task2)
    duplicate = build(:task_dependency, task: @task1, depends_on_task: @task2)
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:depends_on_task_id], "has already been taken"
  end

  test "direct cycle detection" do
    # A → B
    create(:task_dependency, task: @task1, depends_on_task: @task2)
    # B → A (cycle)
    cycle = build(:task_dependency, task: @task2, depends_on_task: @task1)
    assert_not cycle.valid?
    assert_includes cycle.errors[:base], "would create a dependency cycle"
  end

  test "indirect cycle detection" do
    # A → B
    create(:task_dependency, task: @task1, depends_on_task: @task2)
    # B → C
    create(:task_dependency, task: @task2, depends_on_task: @task3)
    # C → A (cycle)
    cycle = build(:task_dependency, task: @task3, depends_on_task: @task1)
    assert_not cycle.valid?
    assert_includes cycle.errors[:base], "would create a dependency cycle"
  end

  test "valid DAG accepted" do
    # linear chain A → B → C
    assert build(:task_dependency, task: @task1, depends_on_task: @task2).valid?
    assert build(:task_dependency, task: @task2, depends_on_task: @task3).valid?
    # also multiple dependencies on same task
    task4 = create(:task, project: @project, team_membership: @team_membership, workflow_run: @workflow_run)
    assert build(:task_dependency, task: @task1, depends_on_task: task4).valid?
  end

  test "associations" do
    dependency = create(:task_dependency, task: @task1, depends_on_task: @task2)
    assert_equal @task1, dependency.task
    assert_equal @task2, dependency.depends_on_task
  end
end
