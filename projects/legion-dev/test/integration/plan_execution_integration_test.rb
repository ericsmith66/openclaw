# frozen_string_literal: true

require "test_helper"

module Legion
  class PlanExecutionIntegrationTest < ActiveSupport::TestCase
    setup do
      @project = create(:project)
      @team = create(:agent_team, project: @project, name: "ROR")
      @membership = create(:team_membership, agent_team: @team, config: {
        "id" => "rails-lead-test",
        "name" => "Rails Lead",
        "provider" => "deepseek",
        "model" => "deepseek-reasoner"
      })

      # Parent WorkflowRun (the decomposition run)
      @workflow_run = create(:workflow_run,
        project: @project,
        team_membership: @membership,
        status: :completed
      )

      # Default stub: DispatchService returns a pre-built execution WorkflowRun
      @default_exec_run = create(:workflow_run,
        project: @project,
        team_membership: @membership,
        status: :completed,
        iterations: 8,
        duration_ms: 25_000
      )
      DispatchService.stubs(:call).returns(@default_exec_run)
    end

    test "executes tasks in dependency order" do
      task_1 = create_task(position: 1)
      task_2 = create_task(position: 2)
      task_3 = create_task(position: 3)
      create_dep(task_2, depends_on: task_1)
      create_dep(task_3, depends_on: task_2)

      completed_at_dispatch = []
      exec_run_1 = create(:workflow_run, project: @project, team_membership: @membership, status: :completed)
      exec_run_2 = create(:workflow_run, project: @project, team_membership: @membership, status: :completed)
      exec_run_3 = create(:workflow_run, project: @project, team_membership: @membership, status: :completed)

      DispatchService.stubs(:call).with do |_args|
        completed_at_dispatch << Task.where(workflow_run: @workflow_run, status: :completed).count
        true
      end.returns(exec_run_1).then.returns(exec_run_2).then.returns(exec_run_3)

      PlanExecutionService.call(workflow_run: @workflow_run)

      # When task_1 dispatched, 0 completed; when task_2 dispatched, 1 completed; etc.
      assert_equal [ 0, 1, 2 ], completed_at_dispatch

      task_1.reload
      task_2.reload
      task_3.reload
      assert_predicate task_1, :completed?
      assert_predicate task_2, :completed?
      assert_predicate task_3, :completed?
    end

    test "each task creates its own execution workflow run linked to the task" do
      task_1 = create_task(position: 1)
      task_2 = create_task(position: 2)

      exec_run_1 = create(:workflow_run, project: @project, team_membership: @membership, status: :completed)
      exec_run_2 = create(:workflow_run, project: @project, team_membership: @membership, status: :completed)

      DispatchService.stubs(:call).returns(exec_run_1).then.returns(exec_run_2)

      PlanExecutionService.call(workflow_run: @workflow_run)

      task_1.reload
      task_2.reload
      assert_not_nil task_1.execution_run_id
      assert_not_nil task_2.execution_run_id
      assert_not_equal task_1.execution_run_id, task_2.execution_run_id
      assert_equal exec_run_1.id, task_1.execution_run_id
      assert_equal exec_run_2.id, task_2.execution_run_id
    end

    test "execution run id set on task after completion" do
      task_1 = create_task(position: 1)
      exec_run = create(:workflow_run, project: @project, team_membership: @membership, status: :completed)

      DispatchService.stubs(:call).returns(exec_run)

      PlanExecutionService.call(workflow_run: @workflow_run)

      task_1.reload
      assert_equal exec_run.id, task_1.execution_run_id
    end

    test "workflow events queryable per task via execution run" do
      task_1 = create_task(position: 1)

      exec_run = create(:workflow_run, project: @project, team_membership: @membership, status: :completed)
      create(:workflow_event, workflow_run: exec_run, event_type: "agent.started", payload: {})
      create(:workflow_event, workflow_run: exec_run, event_type: "agent.completed", payload: {})

      DispatchService.stubs(:call).returns(exec_run)

      PlanExecutionService.call(workflow_run: @workflow_run)

      task_1.reload
      assert_not_nil task_1.execution_run
      assert_equal 2, task_1.execution_run.workflow_events.count
    end

    test "full cycle mock decompose then execute verifies all tasks completed" do
      # Simulate a decomposition result: 3 tasks with a linear dependency chain
      task_1 = create_task(position: 1)
      task_2 = create_task(position: 2)
      task_3 = create_task(position: 3)
      create_dep(task_2, depends_on: task_1)
      create_dep(task_3, depends_on: task_2)

      PlanExecutionService.call(workflow_run: @workflow_run)

      statuses = Task.where(workflow_run: @workflow_run).pluck(:status)
      assert_equal [ "completed", "completed", "completed" ], statuses
    end

    test "continue on failure integration leaves independent tasks completed" do
      task_a = create_task(position: 1, prompt: "failing task A")
      task_b = create_task(position: 2, prompt: "dependent task B")  # depends on A
      task_c = create_task(position: 3, prompt: "independent task C")  # independent

      create_dep(task_b, depends_on: task_a)

      exec_run_c = create(:workflow_run, project: @project, team_membership: @membership, status: :completed)

      DispatchService.stubs(:call).with do |args|
        raise StandardError, "agent failed" if args[:prompt] == "failing task A"
        true
      end.returns(exec_run_c)

      result = PlanExecutionService.call(workflow_run: @workflow_run, continue_on_failure: true)

      task_a.reload
      task_b.reload
      task_c.reload

      assert_predicate task_a, :failed?
      assert_predicate task_b, :skipped?
      assert_predicate task_c, :completed?

      assert_equal 1, result.completed_count
      assert_equal 1, result.failed_count
      assert_equal 1, result.skipped_count
      assert_equal false, result.halted
    end

    private

    def create_task(position:, status: :pending, prompt: nil, **attrs)
      create(:task,
        project: @project,
        team_membership: @membership,
        workflow_run: @workflow_run,
        position: position,
        status: status,
        prompt: prompt || "Task #{position} prompt (#{SecureRandom.hex(4)})",
        **attrs
      )
    end

    def create_dep(task, depends_on:)
      TaskDependency.create!(task: task, depends_on_task: depends_on)
    end
  end
end
