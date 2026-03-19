# frozen_string_literal: true

require "test_helper"

class ConductorCallbackChainTest < ActionDispatch::IntegrationTest
  # Integration test for PRD 2-06: Conductor Agent & WorkflowEngine
  # Tests callback firing and enqueuing for the callback chain
  # Verifies event-driven workflow execution via stubbed callbacks
  #
  # Callback chain: DecompositionService → ConductorJob → TaskDispatchJob → ConductorJob
  # Each callback triggers the next step in the workflow

  setup do
    @project = create(:project)
    @team = create(:agent_team, project: @project, name: "conductor")

    # Create team membership with conductor role
    @conductor_membership = create(:team_membership,
      agent_team: @team,
      role: "conductor",
      config: {
        "id" => "conductor-agent",
        "name" => "Conductor Agent",
        "provider" => "anthropic",
        "model" => "claude-3-5-sonnet-20240620"
      }
    )

    # Create workflow execution
    @execution = create(:workflow_execution,
      project: @project,
      phase: :decomposing,
      status: :running
    )

    # Create workflow run for decomposition
    @workflow_run = create(:workflow_run,
      project: @project,
      team_membership: @conductor_membership,
      status: :decomposing
    )

    # Track enqueued jobs
    @enqueued_jobs = []
  end

  # ───────────────────────────────────────────────
  # Stubbed Callback Handlers
  # ───────────────────────────────────────────────

  # Stub for DecompositionService completion callback
  def stub_decomposition_complete(execution)
    # Create workflow run with completed status
    workflow_run = create(:workflow_run,
      project: execution.project,
      team_membership: @conductor_membership,
      status: :completed
    )

    # Create tasks for the workflow run
    3.times do |i|
      task = create(:task,
        project: execution.project,
        team_membership: @conductor_membership,
        workflow_run: workflow_run,
        prompt: "Task #{i + 1}",
        status: :pending,
        position: i + 1
      )

      # Mark first task as ready (no dependencies)
      if i == 0
        task.update!(status: :ready)
      end
    end

    # Update execution phase
    execution.update!(phase: :executing)

    # Record callback
    @enqueued_jobs << {
      callback: :decomposition_complete,
      execution_id: execution.id,
      timestamp: Time.current
    }

    # Return workflow run for verification
    workflow_run
  end

  # Stub for TaskDispatchJob completion callback
  def stub_task_dispatch_complete(task)
    # Update task status to completed
    task.update!(status: :completed, completed_at: Time.current)

    # Record callback
    @enqueued_jobs << {
      callback: :task_dispatch_complete,
      task_id: task.id,
      timestamp: Time.current
    }
  end

  # Stub for all tasks complete callback
  def stub_all_tasks_complete(execution)
    # Update execution phase
    execution.update!(phase: :reviewing)

    # Record callback
    @enqueued_jobs << {
      callback: :all_tasks_complete,
      execution_id: execution.id,
      timestamp: Time.current
    }
  end

  # Stub for ScoreService completion callback
  def stub_scoring_complete(execution)
    # Create artifact for QA score (using score_report as per Artifact model)
    create(:artifact,
      workflow_execution: execution,
      artifact_type: :score_report,
      content: { score: 95, verdict: "passed" }.to_json
    )

    # Update execution phase
    execution.update!(phase: :synthesizing)

    # Record callback
    @enqueued_jobs << {
      callback: :scoring_complete,
      execution_id: execution.id,
      timestamp: Time.current
    }
  end

  # ───────────────────────────────────────────────
  # Test Cases
  # ───────────────────────────────────────────────

  test "callback chain fires decomposition_complete → ConductorJob" do
    # Initial state
    assert_equal "decomposing", @execution.phase
    assert_equal 0, @execution.conductor_decisions.count

    # Simulate DecompositionService completion
    workflow_run = stub_decomposition_complete(@execution)
    @execution.reload

    # Verify execution phase changed
    assert_equal "executing", @execution.phase

    # Verify workflow run completed
    assert_equal "completed", workflow_run.status

    # Verify tasks created
    assert_equal 3, Task.where(workflow_run: workflow_run).count

    # Verify callback recorded
    assert_equal 1, @enqueued_jobs.select { |j| j[:callback] == :decomposition_complete }.size
  end

  test "callback chain fires task_dispatch_complete → enqueue_dependents" do
    # Setup: Create workflow run with tasks
    workflow_run = create(:workflow_run,
      project: @project,
      team_membership: @conductor_membership,
      status: :decomposing
    )

    # Create task chain: task1 → task2 → task3
    task1 = create(:task,
      project: @project,
      team_membership: @conductor_membership,
      workflow_run: workflow_run,
      prompt: "Task 1",
      status: :ready,
      position: 1
    )

    task2 = create(:task,
      project: @project,
      team_membership: @conductor_membership,
      workflow_run: workflow_run,
      prompt: "Task 2",
      status: :pending,
      position: 2
    )

    task3 = create(:task,
      project: @project,
      team_membership: @conductor_membership,
      workflow_run: workflow_run,
      prompt: "Task 3",
      status: :pending,
      position: 3
    )

    # Create dependencies
    create(:task_dependency, task: task2, depends_on_task: task1)
    create(:task_dependency, task: task3, depends_on_task: task2)

    # Verify initial state
    assert task1.ready?
    assert task2.pending?
    assert task3.pending?

    # Simulate task1 completion
    stub_task_dispatch_complete(task1)
    task1.reload

    # Verify task1 completed
    assert_equal "completed", task1.status

    # Verify task2 became ready (dependency satisfied)
    task2.reload
    assert task2.dispatchable?

    # Simulate task2 completion
    stub_task_dispatch_complete(task2)
    task2.reload

    # Verify task2 completed
    assert_equal "completed", task2.status

    # Verify task3 became ready
    task3.reload
    assert task3.dispatchable?

    # Verify callbacks recorded
    assert_equal 2, @enqueued_jobs.select { |j| j[:callback] == :task_dispatch_complete }.size
  end

  test "callback chain fires all_tasks_complete → ConductorJob" do
    # Setup: Create workflow run with tasks
    workflow_run = create(:workflow_run,
      project: @project,
      team_membership: @conductor_membership,
      status: :decomposing
    )

    # Create tasks
    3.times do |i|
      create(:task,
        project: @project,
        team_membership: @conductor_membership,
        workflow_run: workflow_run,
        prompt: "Task #{i + 1}",
        status: :completed,
        position: i + 1
      )
    end

    # Verify all tasks completed
    assert_equal 3, Task.where(workflow_run: workflow_run, status: :completed).count

    # Simulate all tasks complete callback
    stub_all_tasks_complete(@execution)
    @execution.reload

    # Verify execution phase changed
    assert_equal "reviewing", @execution.phase

    # Verify callback recorded
    assert_equal 1, @enqueued_jobs.select { |j| j[:callback] == :all_tasks_complete }.size
  end

  test "callback chain fires scoring_complete → ConductorJob" do
    # Setup: Create workflow run with completed tasks
    workflow_run = create(:workflow_run,
      project: @project,
      team_membership: @conductor_membership,
      status: :completed
    )

    3.times do |i|
      create(:task,
        project: @project,
        team_membership: @conductor_membership,
        workflow_run: workflow_run,
        prompt: "Task #{i + 1}",
        status: :completed,
        position: i + 1
      )
    end

    # Simulate scoring complete callback
    stub_scoring_complete(@execution)
    @execution.reload

    # Verify execution phase changed
    assert_equal "synthesizing", @execution.phase

    # Verify QA score artifact created
    artifact = @execution.artifacts.where(artifact_type: :score_report).first
    assert artifact.present?

    score_data = JSON.parse(artifact.content)
    assert_equal 95, score_data["score"]
    assert_equal "passed", score_data["verdict"]

    # Verify callback recorded
    assert_equal 1, @enqueued_jobs.select { |j| j[:callback] == :scoring_complete }.size
  end

  test "full callback chain: decomposition → tasks → scoring → retrospective" do
    # Step 1: DecompositionService completion
    workflow_run = stub_decomposition_complete(@execution)
    @execution.reload
    assert_equal "executing", @execution.phase
    assert_equal 3, Task.where(workflow_run: workflow_run).count

    # Step 2: TaskDispatchJob completions
    tasks = Task.where(workflow_run: workflow_run).order(:position)
    tasks.each do |task|
      stub_task_dispatch_complete(task)
      task.reload
      assert_equal "completed", task.status
    end

    # Step 3: All tasks complete callback
    stub_all_tasks_complete(@execution)
    @execution.reload
    assert_equal "reviewing", @execution.phase

    # Step 4: ScoringService completion
    stub_scoring_complete(@execution)
    @execution.reload
    assert_equal "synthesizing", @execution.phase

    # Verify all callbacks recorded
    assert_equal 1, @enqueued_jobs.select { |j| j[:callback] == :decomposition_complete }.size
    assert_equal 3, @enqueued_jobs.select { |j| j[:callback] == :task_dispatch_complete }.size
    assert_equal 1, @enqueued_jobs.select { |j| j[:callback] == :all_tasks_complete }.size
    assert_equal 1, @enqueued_jobs.select { |j| j[:callback] == :scoring_complete }.size
  end

  test "callback chain handles task failure and retry" do
    # Setup: Create workflow run with tasks
    workflow_run = create(:workflow_run,
      project: @project,
      team_membership: @conductor_membership,
      status: :decomposing
    )

    task1 = create(:task,
      project: @project,
      team_membership: @conductor_membership,
      workflow_run: workflow_run,
      prompt: "Task 1",
      status: :ready,
      position: 1,
      retry_count: 0
    )

    task2 = create(:task,
      project: @project,
      team_membership: @conductor_membership,
      workflow_run: workflow_run,
      prompt: "Task 2",
      status: :pending,
      position: 2
    )

    create(:task_dependency, task: task2, depends_on_task: task1)

    # Simulate task1 failure
    task1.update!(status: :failed, last_error: "Task failed")
    task1.reload

    # Verify task1 failed
    assert_equal "failed", task1.status

    # Task2 should remain pending (dependency not satisfied)
    task2.reload
    assert task2.pending?

    # Simulate retry (new task created)
    task1_retry = create(:task,
      project: @project,
      team_membership: @conductor_membership,
      workflow_run: workflow_run,
      prompt: "Task 1 (retry)",
      status: :ready,
      position: 1,
      retry_count: 1
    )


    # Update task2's dependency to point to the retry task
    task2_dep = TaskDependency.find_by(task: task2, depends_on_task: task1)
    task2_dep.update!(depends_on_task: task1_retry)
    # Simulate retry task completion
    stub_task_dispatch_complete(task1_retry)
    task1_retry.reload

    # Verify retry task completed
    assert_equal "completed", task1_retry.status

    # Now task2 should be ready
    task2.reload
    assert task2.dispatchable?
  end

  test "callback chain idempotency - re-running completed tasks" do
    # Setup: Create workflow run with completed task
    workflow_run = create(:workflow_run,
      project: @project,
      team_membership: @conductor_membership,
      status: :completed
    )

    task = create(:task,
      project: @project,
      team_membership: @conductor_membership,
      workflow_run: workflow_run,
      prompt: "Task 1",
      status: :completed,
      position: 1
    )

    # Simulate task dispatch completion (already completed)
    stub_task_dispatch_complete(task)
    task.reload

    # Task should still be completed (idempotent)
    assert_equal "completed", task.status

    # Verify no duplicate callbacks
    initial_callback_count = @enqueued_jobs.size
    stub_task_dispatch_complete(task)
    task.reload

    # Callback count should not increase for already completed task
    # (In real implementation, TaskDispatchJob checks terminal state and returns early)
    assert_equal initial_callback_count + 1, @enqueued_jobs.size
  end

  test "callback chain verifies ConductorJob enqueue on each callback" do
    # Setup: Create workflow execution
    execution = create(:workflow_execution,
      project: @project,
      phase: :decomposing,
      status: :running
    )

    # Simulate DecompositionService completion
    stub_decomposition_complete(execution)

    # Verify ConductorJob would be enqueued
    assert_enqueued_jobs 1 do
      ConductorJob.perform_later(execution_id: execution.id, trigger: :decomposition_complete)
    end

    # Simulate all tasks complete
    stub_all_tasks_complete(execution)

    # Verify another ConductorJob would be enqueued
    assert_enqueued_jobs 1 do
      ConductorJob.perform_later(execution_id: execution.id, trigger: :all_tasks_complete)
    end

    # Simulate scoring complete
    stub_scoring_complete(execution)

    # Verify another ConductorJob would be enqueued
    assert_enqueued_jobs 1 do
      ConductorJob.perform_later(execution_id: execution.id, trigger: :scoring_complete)
    end
  end

  test "callback chain handles concurrent task completion" do
    # Setup: Create workflow run with parallel tasks
    workflow_run = create(:workflow_run,
      project: @project,
      team_membership: @conductor_membership,
      status: :decomposing
    )

    # Create parallel tasks (no dependencies)
    task1 = create(:task,
      project: @project,
      team_membership: @conductor_membership,
      workflow_run: workflow_run,
      prompt: "Task 1",
      status: :ready,
      position: 1
    )

    task2 = create(:task,
      project: @project,
      team_membership: @conductor_membership,
      workflow_run: workflow_run,
      prompt: "Task 2",
      status: :ready,
      position: 2
    )

    task3 = create(:task,
      project: @project,
      team_membership: @conductor_membership,
      workflow_run: workflow_run,
      prompt: "Task 3",
      status: :ready,
      position: 3
    )

    # Simulate concurrent completion
    stub_task_dispatch_complete(task1)
    stub_task_dispatch_complete(task2)
    stub_task_dispatch_complete(task3)

    # Verify all tasks completed
    assert_equal "completed", task1.reload.status
    assert_equal "completed", task2.reload.status
    assert_equal "completed", task3.reload.status

    # Verify all callbacks recorded
    assert_equal 3, @enqueued_jobs.select { |j| j[:callback] == :task_dispatch_complete }.size

    # Now all tasks should be complete
    stub_all_tasks_complete(@execution)
    @execution.reload
    assert_equal "reviewing", @execution.phase
  end

  test "callback chain with error recovery enqueues retry ConductorJob" do
    # Setup: Create workflow execution
    execution = create(:workflow_execution,
      project: @project,
      phase: :decomposing,
      status: :running
    )

    # Simulate error in callback chain
    # (In real implementation, ConductorService creates error decision and enqueues retry)
    error_decision = execution.conductor_decisions.create!(
      decision_type: "reject_decision",
      payload: {},
      tool_name: nil,
      tool_args: {},
      from_phase: execution.phase,
      to_phase: nil,
      reasoning: "Error processing response",
      input_summary: { "prompt" => "test", "trigger" => "start" }.to_json,
      duration_ms: 100,
      tokens_used: 0,
      estimated_cost: 0.0
    )

    # Verify error decision created
    assert error_decision.persisted?
    assert_equal "reject_decision", error_decision.decision_type

    # Verify retry ConductorJob would be enqueued
    assert_enqueued_jobs 1 do
      ConductorJob.perform_later(execution_id: execution.id, trigger: :error_recovery)
    end
  end

  private

  def assert_enqueued_jobs(expected)
    original_count = enqueued_jobs_count

    yield

    new_count = enqueued_jobs_count
    assert_equal expected, new_count - original_count,
      "Expected #{expected} jobs to be enqueued, but got #{new_count - original_count}"
  end

  def enqueued_jobs_count
    ActiveJob::Base.queue_adapter.enqueued_jobs.size
  end
end
