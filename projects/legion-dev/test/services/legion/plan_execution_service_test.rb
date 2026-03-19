# frozen_string_literal: true

require "test_helper"

module Legion
  class PlanExecutionServiceTest < ActiveSupport::TestCase
    setup do
      @project = create(:project)
      @team = create(:agent_team, project: @project, name: "ROR")
      @membership = create(:team_membership, agent_team: @team, config: {
        "id" => "rails-lead-test",
        "name" => "Rails Lead",
        "provider" => "deepseek",
        "model" => "deepseek-reasoner"
      })

      # Parent workflow_run (from decomposition)
      @workflow_run = create(:workflow_run,
        project: @project,
        team_membership: @membership,
        status: :completed
      )

      # Stub DispatchService to return a mock execution WorkflowRun
      @mock_execution_run = create(:workflow_run,
        project: @project,
        team_membership: @membership,
        status: :completed,
        iterations: 5,
        duration_ms: 12000
      )

      DispatchService.stubs(:call).returns(@mock_execution_run)
    end

    # ───────────────────────────────────────────────
    # Group A — Happy Path
    # ───────────────────────────────────────────────

    test "linear chain executes in order" do
      task_a = create_task(position: 1)
      task_b = create_task(position: 2)
      task_c = create_task(position: 3)
      create_dep(task_b, depends_on: task_a)
      create_dep(task_c, depends_on: task_b)

      dispatch_order = []
      DispatchService.stubs(:call).with do |args|
        dispatch_order << args[:prompt]
        true
      end.returns(@mock_execution_run)

      PlanExecutionService.call(workflow_run: @workflow_run)

      assert_equal [ task_a.prompt, task_b.prompt, task_c.prompt ], dispatch_order
    end

    test "parallel eligible tasks dispatch first ready task in position order" do
      task_a = create_task(position: 1)
      task_b = create_task(position: 2)
      task_c = create_task(position: 3)
      create_dep(task_c, depends_on: task_a)
      create_dep(task_c, depends_on: task_b)

      dispatch_order = []
      DispatchService.stubs(:call).with do |args|
        dispatch_order << args[:prompt]
        true
      end.returns(@mock_execution_run)

      PlanExecutionService.call(workflow_run: @workflow_run)

      # A and B are both independent, A dispatched first (lower position), then B, then C
      assert_equal task_a.prompt, dispatch_order[0]
      assert_equal task_b.prompt, dispatch_order[1]
      assert_equal task_c.prompt, dispatch_order[2]
    end

    test "all tasks already completed exits early without dispatch" do
      create_task(position: 1, status: :completed)
      create_task(position: 2, status: :completed)

      DispatchService.expects(:call).never

      result = PlanExecutionService.call(workflow_run: @workflow_run)

      assert_equal 2, result.completed_count
      assert_equal 0, result.failed_count
      assert_equal false, result.halted
    end

    test "returns result struct with correct counts and duration" do
      create_task(position: 1)
      create_task(position: 2)

      result = PlanExecutionService.call(workflow_run: @workflow_run)

      assert_instance_of PlanExecutionService::Result, result
      assert_equal 2, result.completed_count
      assert_equal 0, result.failed_count
      assert_equal 0, result.skipped_count
      assert_equal 2, result.total_count
      assert_predicate result.duration_ms, :positive?
      assert_equal false, result.halted
    end

    # ───────────────────────────────────────────────
    # Group B — Failure Handling
    # ───────────────────────────────────────────────

    test "halt on first failure does not dispatch dependent tasks" do
      task_a = create_task(position: 1)
      task_b = create_task(position: 2)
      create_dep(task_b, depends_on: task_a)

      DispatchService.stubs(:call).raises(StandardError, "agent failed")

      result = PlanExecutionService.call(workflow_run: @workflow_run)

      assert result.halted
      assert_match(/Task ##{task_a.id} failed/, result.halt_reason)

      task_a.reload
      task_b.reload
      assert_predicate task_a, :failed?
      assert_predicate task_b, :pending?
    end

    test "continue on failure marks direct dependents as skipped and dispatches independent tasks" do
      task_a = create_task(position: 1)
      task_b = create_task(position: 2)  # depends on A
      task_d = create_task(position: 4)  # independent
      create_dep(task_b, depends_on: task_a)

      call_count = 0
      DispatchService.stubs(:call).with do |args|
        call_count += 1
        raise StandardError, "failed" if args[:prompt] == task_a.prompt
        true
      end.returns(@mock_execution_run)

      result = PlanExecutionService.call(workflow_run: @workflow_run, continue_on_failure: true)

      assert_equal false, result.halted

      task_a.reload
      task_b.reload
      task_d.reload
      assert_predicate task_a, :failed?
      assert_predicate task_b, :skipped?
      assert_predicate task_d, :completed?
    end

    test "continue on failure marks direct and transitive dependents as skipped" do
      task_a = create_task(position: 1)
      task_b = create_task(position: 2)
      task_c = create_task(position: 3)
      task_d = create_task(position: 4)
      create_dep(task_b, depends_on: task_a)
      create_dep(task_c, depends_on: task_b)
      create_dep(task_d, depends_on: task_c)

      DispatchService.stubs(:call).raises(StandardError, "failed")

      PlanExecutionService.call(workflow_run: @workflow_run, continue_on_failure: true)

      task_a.reload
      task_b.reload
      task_c.reload
      task_d.reload
      assert_predicate task_a, :failed?
      assert_predicate task_b, :skipped?
      assert_predicate task_c, :skipped?
      assert_predicate task_d, :skipped?
    end

    test "running task from interrupted run is re-dispatched" do
      task_a = create_task(position: 1, status: :running)

      dispatched = false
      DispatchService.stubs(:call).with do |args|
        dispatched = true
        true
      end.returns(@mock_execution_run)

      PlanExecutionService.call(workflow_run: @workflow_run)

      assert dispatched
      task_a.reload
      assert_predicate task_a, :completed?
    end

    # ───────────────────────────────────────────────
    # Group C — Start-From
    # ───────────────────────────────────────────────

    test "start from skips tasks before start task" do
      task_1 = create_task(position: 1)
      task_2 = create_task(position: 2)
      task_3 = create_task(position: 3)

      dispatched_prompts = []
      DispatchService.stubs(:call).with do |args|
        dispatched_prompts << args[:prompt]
        true
      end.returns(@mock_execution_run)

      PlanExecutionService.call(workflow_run: @workflow_run, start_from: task_2.id)

      task_1.reload
      task_2.reload
      task_3.reload
      assert_predicate task_1, :skipped?
      assert_includes dispatched_prompts, task_2.prompt
      assert_includes dispatched_prompts, task_3.prompt
      refute_includes dispatched_prompts, task_1.prompt
    end

    test "start from task not found raises error" do
      create_task(position: 1)

      assert_raises(PlanExecutionService::StartFromTaskNotFoundError) do
        PlanExecutionService.call(workflow_run: @workflow_run, start_from: 9_999_999)
      end
    end

    # ───────────────────────────────────────────────
    # Group D — Deadlock
    # ───────────────────────────────────────────────

    test "deadlock detection raises error when no tasks are ready but incomplete remain" do
      # All tasks pending but no dependencies are ever satisfied
      task_a = create_task(position: 1)
      task_b = create_task(position: 2)

      # Make task_a depend on task_b and vice-versa via DB manipulation (skip model validation)
      # Instead, directly set all tasks to failed so none have satisfied deps after one loop:
      # Simulate deadlock by making task_a depend on a non-existent/failed task via a stub
      DispatchService.stubs(:call).raises(StandardError, "failed")

      # Force a deadlock scenario: create task that depends on task_b, but task_b never dispatches
      # We'll directly manipulate statuses: set A to failed, then B depends on A
      # The simplest deadlock test: B depends on A. A fails. continue_on_failure=false so we halt.
      # For a TRUE deadlock: all remaining tasks have unsatisfied deps and none are dispatchable.
      # We simulate this by having task_b depend on a phantom task_id that never completes.

      # Reset: fresh workflow_run to avoid side effects from A/B above
      run2 = create(:workflow_run, project: @project, team_membership: @membership, status: :completed)
      phantom_task = create_task(position: 1, workflow_run: run2, status: :failed)
      # task_b depends on phantom_task (different workflow_run) — won't be in the task list
      # Instead: create a cycle-like situation using raw DB insert bypass

      # Simplest approach: create a pending task with a dependency on a task that doesn't exist
      # in the workflow_run. We achieve this by having task_c depend on task_a which is :failed,
      # and task_d depend on task_c — with continue_on_failure=true (skips C and D).
      # True deadlock: tasks pending with deps on :pending tasks that themselves have no ready deps.
      # Build it: task_x (no deps) and task_y depends on a task that is NOT in the run.

      run3 = create(:workflow_run, project: @project, team_membership: @membership, status: :completed)
      # Create task that depends on a completed task from ANOTHER run (so it's satisfied) — not deadlock
      # Instead, directly set task to :pending but update its dep's status to :pending to create deadlock
      dead_task = create(:task,
        project: @project,
        team_membership: @membership,
        workflow_run: run3,
        position: 1,
        status: :pending,
        prompt: "deadlock task"
      )

      # Create a fake dep to a task in another run — won't be visible in current run
      # Instead: have dead_task depend on dead_task (self-dep blocked by validation)
      # Final approach: create 2 tasks in run3; each depends on the other (use raw SQL)
      dead_task_2 = create(:task,
        project: @project,
        team_membership: @membership,
        workflow_run: run3,
        position: 2,
        status: :pending,
        prompt: "deadlock task 2"
      )

      # Use raw SQL to create circular dep bypassing model validation
      ActiveRecord::Base.connection.execute(
        "INSERT INTO task_dependencies (task_id, depends_on_task_id, created_at, updated_at) " \
        "VALUES (#{dead_task.id}, #{dead_task_2.id}, NOW(), NOW())"
      )
      ActiveRecord::Base.connection.execute(
        "INSERT INTO task_dependencies (task_id, depends_on_task_id, created_at, updated_at) " \
        "VALUES (#{dead_task_2.id}, #{dead_task.id}, NOW(), NOW())"
      )

      assert_raises(PlanExecutionService::DeadlockError) do
        PlanExecutionService.call(workflow_run: run3)
      end
    end

    # ───────────────────────────────────────────────
    # Group E — Dry Run
    # ───────────────────────────────────────────────

    test "dry run returns result without dispatching any tasks" do
      create_task(position: 1)
      create_task(position: 2)

      DispatchService.expects(:call).never

      result = PlanExecutionService.call(workflow_run: @workflow_run, dry_run: true)

      assert_instance_of PlanExecutionService::Result, result
      assert_equal 0, result.completed_count
      assert_equal false, result.halted
    end

    test "dry run prints wave output to stdout" do
      task_a = create_task(position: 1)
      task_b = create_task(position: 2)
      create_dep(task_b, depends_on: task_a)

      output = capture_output do
        PlanExecutionService.call(workflow_run: @workflow_run, dry_run: true)
      end

      assert_match(/Wave 1/, output)
      assert_match(/Wave 2/, output)
      assert_match(/DRY RUN/, output)
    end

    # ───────────────────────────────────────────────
    # Group F — Special Cases
    # ───────────────────────────────────────────────

    test "empty task list raises no tasks found error" do
      empty_run = create(:workflow_run, project: @project, team_membership: @membership, status: :completed)

      assert_raises(PlanExecutionService::NoTasksFoundError) do
        PlanExecutionService.call(workflow_run: empty_run)
      end
    end

    test "workflow run not found raises error" do
      assert_raises(PlanExecutionService::WorkflowRunNotFoundError) do
        PlanExecutionService.call(workflow_run: 9_999_999)
      end
    end

    test "each dispatched task creates its own execution workflow run" do
      task_a = create_task(position: 1)
      task_b = create_task(position: 2)
      task_c = create_task(position: 3)

      execution_run_a = create(:workflow_run, project: @project, team_membership: @membership, status: :completed, iterations: 3)
      execution_run_b = create(:workflow_run, project: @project, team_membership: @membership, status: :completed, iterations: 5)
      execution_run_c = create(:workflow_run, project: @project, team_membership: @membership, status: :completed, iterations: 7)

      call_count = 0
      DispatchService.stubs(:call).returns(execution_run_a).then.returns(execution_run_b).then.returns(execution_run_c)

      PlanExecutionService.call(workflow_run: @workflow_run)

      task_a.reload
      task_b.reload
      task_c.reload

      assert_equal execution_run_a.id, task_a.execution_run_id
      assert_equal execution_run_b.id, task_b.execution_run_id
      assert_equal execution_run_c.id, task_c.execution_run_id
    end

    test "sigint simulation marks loop as interrupted and halts" do
      task_a = create_task(position: 1)

      service = PlanExecutionService.new(
        workflow_run: @workflow_run,
        start_from: nil,
        continue_on_failure: false,
        interactive: false,
        verbose: false,
        max_iterations: nil,
        dry_run: false
      )

      # Simulate SIGINT by setting @interrupted before the loop executes
      service.instance_variable_set(:@interrupted, true)

      # task_a has no dependencies so it would normally be ready
      # But since @interrupted is set before dispatch, we need to check behavior
      # The service checks @interrupted at the TOP of each loop iteration
      # With @interrupted pre-set, after loading tasks it should halt immediately
      # However, the service only checks @interrupted AFTER finding ready tasks
      # So we stub DispatchService to not be called
      DispatchService.expects(:call).never

      result = assert_raises(Interrupt) do
        service.call
      end
    end

    test "all tasks in terminal states exits without dispatch" do
      create_task(position: 1, status: :completed)
      create_task(position: 2, status: :failed)
      create_task(position: 3, status: :skipped)

      DispatchService.expects(:call).never

      result = PlanExecutionService.call(workflow_run: @workflow_run)

      assert_equal 1, result.completed_count
      assert_equal 1, result.failed_count
      assert_equal 1, result.skipped_count
      assert_equal false, result.halted
    end

    test "verbose flag passes through to dispatch service" do
      create_task(position: 1)

      captured_args = nil
      DispatchService.stubs(:call).with do |args|
        captured_args = args
        true
      end.returns(@mock_execution_run)

      PlanExecutionService.call(workflow_run: @workflow_run, verbose: true)

      assert_equal true, captured_args[:verbose]
    end

    private

    def create_task(position:, status: :pending, workflow_run: nil, **attrs)
      prompt = attrs.delete(:prompt) || "Task #{position} prompt (#{SecureRandom.hex(4)})"
      create(:task,
        project: @project,
        team_membership: @membership,
        workflow_run: workflow_run || @workflow_run,
        position: position,
        status: status,
        prompt: prompt,
        **attrs
      )
    end

    def create_dep(task, depends_on:)
      TaskDependency.create!(task: task, depends_on_task: depends_on)
    end

    def capture_output(&block)
      original_stdout = $stdout
      $stdout = StringIO.new
      block.call
      $stdout.string
    ensure
      $stdout = original_stdout
    end
  end
end
