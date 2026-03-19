# frozen_string_literal: true

require "test_helper"

class TaskDependencyGraphTest < ActiveSupport::TestCase
  setup do
    @project = create(:project)
    @team_membership = create(:team_membership)
    @workflow_run = create(:workflow_run, project: @project, team_membership: @team_membership)
  end

  test "5 node DAG" do
    # Create 5 tasks
    tasks = 5.times.map do |i|
      create(:task, project: @project, team_membership: @team_membership, workflow_run: @workflow_run, position: i, prompt: "Task #{i}")
    end
    # Build DAG: 0 → 1 → 2, 0 → 3 → 4, 2 → 4
    create(:task_dependency, task: tasks[1], depends_on_task: tasks[0])
    create(:task_dependency, task: tasks[2], depends_on_task: tasks[1])
    create(:task_dependency, task: tasks[3], depends_on_task: tasks[0])
    create(:task_dependency, task: tasks[4], depends_on_task: tasks[3])
    create(:task_dependency, task: tasks[4], depends_on_task: tasks[2])

    # Verify dependencies
    assert_equal [], tasks[0].dependencies
    assert_equal [ tasks[0] ], tasks[1].dependencies
    assert_equal [ tasks[1] ], tasks[2].dependencies
    assert_equal [ tasks[0] ], tasks[3].dependencies
    assert_equal [ tasks[2], tasks[3] ], tasks[4].dependencies.sort_by(&:id)

    # Verify dependents
    assert_equal [ tasks[1], tasks[3] ], tasks[0].dependents.sort_by(&:id)
    assert_equal [ tasks[2] ], tasks[1].dependents
    assert_equal [ tasks[4] ], tasks[2].dependents
    assert_equal [ tasks[4] ], tasks[3].dependents
    assert_equal [], tasks[4].dependents
  end

  test "ready scope" do
    # Create tasks
    t0 = create(:task, project: @project, team_membership: @team_membership, workflow_run: @workflow_run, status: :pending)
    t1 = create(:task, project: @project, team_membership: @team_membership, workflow_run: @workflow_run, status: :pending)
    t2 = create(:task, project: @project, team_membership: @team_membership, workflow_run: @workflow_run, status: :pending)
    # t1 depends on t0, t2 depends on t1
    create(:task_dependency, task: t1, depends_on_task: t0)
    create(:task_dependency, task: t2, depends_on_task: t1)

    # Initially only t0 is ready (no dependencies)
    assert_includes Task.ready, t0
    assert_not_includes Task.ready, t1
    assert_not_includes Task.ready, t2

    # Complete t0, now t1 becomes ready
    t0.completed!
    assert_includes Task.ready, t1
    assert_not_includes Task.ready, t2

    # Complete t1, now t2 becomes ready
    t1.completed!
    assert_includes Task.ready, t2
  end

  test "status propagation" do
    t0 = create(:task, project: @project, team_membership: @team_membership, workflow_run: @workflow_run, status: :pending)
    t1 = create(:task, project: @project, team_membership: @team_membership, workflow_run: @workflow_run, status: :pending)
    t2 = create(:task, project: @project, team_membership: @team_membership, workflow_run: @workflow_run, status: :pending)
    create(:task_dependency, task: t1, depends_on_task: t0)
    create(:task_dependency, task: t2, depends_on_task: t1)

    # t0 not ready? because pending but no dependencies, dispatchable? true
    assert t0.dispatchable?
    # t1 not ready because t0 not completed
    assert_not t1.dispatchable?
    # mark t0 completed
    t0.completed!
    t1.reload
    assert t1.dispatchable?
    # t2 still not ready
    assert_not t2.dispatchable?
    t1.completed!
    t2.reload
    assert t2.dispatchable?
  end

  test "cycle rejection" do
    t0 = create(:task, project: @project, team_membership: @team_membership, workflow_run: @workflow_run)
    t1 = create(:task, project: @project, team_membership: @team_membership, workflow_run: @workflow_run)
    t2 = create(:task, project: @project, team_membership: @team_membership, workflow_run: @workflow_run)
    # t0 → t1
    create(:task_dependency, task: t1, depends_on_task: t0)
    # t1 → t2
    create(:task_dependency, task: t2, depends_on_task: t1)
    # attempt t2 → t0 (cycle)
    cycle = build(:task_dependency, task: t0, depends_on_task: t2)
    assert_not cycle.valid?
    assert_includes cycle.errors[:base], "would create a dependency cycle"
  end
end
