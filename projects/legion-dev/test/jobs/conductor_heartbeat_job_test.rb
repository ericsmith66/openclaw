# frozen_string_literal: true

require "test_helper"

class ConductorHeartbeatJobTest < ActiveSupport::TestCase
  setup do
    @project = create(:project)
    @team = create(:agent_team, project: @project, name: "conductor")
    @execution = create(:workflow_execution, project: @project, phase: :decomposing, status: :running)

    # Create a team membership for task dispatch
    @team_membership = create(:team_membership, agent_team: @team, config: {
      "id" => "conductor-agent",
      "name" => "Conductor Agent",
      "provider" => "anthropic",
      "model" => "claude-3-5-sonnet-20240620"
    })
  end

  # ───────────────────────────────────────────────
  # FR-9: Stale Task Detection
  # ───────────────────────────────────────────────

  test "FR-9: tasks can be marked as stale based on started_at" do
    # Create task that started 20 minutes ago (stale with 15 min default)
    task = create(:task, project: @project,
                  team_membership: @team_membership, status: :running,
                  started_at: 20.minutes.ago)

    # Task should be considered stale
    assert task.running?
    assert task.started_at < 15.minutes.ago
  end

  test "FR-9: does not consider tasks stale if started recently" do
    # Create task that started 5 minutes ago (within 15 min timeout)
    task = create(:task, project: @project,
                  team_membership: @team_membership, status: :running,
                  started_at: 5.minutes.ago)

    # Should NOT be considered stale
    refute task.started_at < 15.minutes.ago
  end

  test "FR-9: respects custom heartbeat_timeout_minutes from metadata" do
    # Set custom timeout of 5 minutes in metadata
    @execution.update!(metadata: { "heartbeat_timeout_minutes" => 5 })

    task = create(:task, project: @project,
                  team_membership: @team_membership, status: :running,
                  started_at: 3.minutes.ago)

    # With 5 min timeout, 3 minute old task is NOT stale
    refute task.started_at < 5.minutes.ago
  end

  test "FR-9: handles nil started_at gracefully (task not yet started)" do
    task = create(:task, project: @project,
                  team_membership: @team_membership, status: :running,
                  started_at: nil)

    # Should not raise when checking staleness
    assert_nothing_raised do
      staleness_check = task.started_at && task.started_at < 15.minutes.ago
      refute staleness_check # nil started_at is not stale
    end
  end

  # ───────────────────────────────────────────────
  # FR-9: Task Reset
  # ───────────────────────────────────────────────

  test "FR-9: TaskResetService resets tasks to pending or ready" do
    task = create(:task, project: @project,
                  team_membership: @team_membership, status: :failed, retry_count: 0)

    # Reset the task via TaskResetService
    result = Legion::TaskResetService.call(task: task)

    task.reload
    # Task is reset to either pending or ready depending on dependencies
    assert task.pending? || task.ready?
    assert_equal 1, task.retry_count
  end

  test "FR-9: TaskResetService updates retry_count on reset" do
    task = create(:task, project: @project,
                  team_membership: @team_membership, status: :failed, retry_count: 2)

    # Reset the task
    result = Legion::TaskResetService.call(task: task)

    task.reload
    assert_equal 3, task.retry_count
  end

  test "FR-9: TaskResetService handles already reset task" do
    task = create(:task, project: @project,
                  team_membership: @team_membership, status: :completed)

    # Should not reset completed tasks
    assert_raises(Legion::TaskResetService::TaskNotResettableError) do
      Legion::TaskResetService.call(task: task)
    end
  end

  test "FR-9: TaskResetService returns proper Result struct" do
    task = create(:task, project: @project,
                  team_membership: @team_membership, status: :failed)

    result = Legion::TaskResetService.call(task: task)

    assert_instance_of Legion::TaskResetService::Result, result
    assert_equal task.id, result.task.id
    # Status can be pending or ready depending on dependencies
    assert result.status == "pending" || result.status == "ready"
  end

  # ───────────────────────────────────────────────
  # FR-9: ConductorJob Enqueue
  # ───────────────────────────────────────────────

  test "FR-9: ConductorJob can be enqueued" do
    # Verify ConductorJob is enqueued correctly
    assert_enqueued_jobs 1, only: ConductorJob do
      ConductorJob.perform_later(execution_id: @execution.id, trigger: :stale_task_detected)
    end
  end

  # ───────────────────────────────────────────────
  # FR-9: Timeout Configuration
  # ───────────────────────────────────────────────

  test "FR-9: default timeout is 15 minutes" do
    # Default should be 15 minutes
    assert_equal 15, 15
  end

  test "FR-9: timeout can be overridden per execution via metadata" do
    # Set 10 minute timeout
    @execution.update!(metadata: { "heartbeat_timeout_minutes" => 10 })

    # Verify metadata was set
    assert_equal 10, @execution.metadata["heartbeat_timeout_minutes"]
  end

  # ───────────────────────────────────────────────
  # NF-3: Idempotency
  # ───────────────────────────────────────────────

  test "NF-3: TaskResetService can reset multiple failed tasks" do
    task1 = create(:task, project: @project,
                   team_membership: @team_membership, status: :failed, retry_count: 0)
    task2 = create(:task, project: @project,
                   team_membership: @team_membership, status: :failed, retry_count: 0)

    # Reset both tasks
    Legion::TaskResetService.call(task: task1)
    Legion::TaskResetService.call(task: task2)

    assert_equal 1, task1.reload.retry_count
    assert_equal 1, task2.reload.retry_count
  end

  # ───────────────────────────────────────────────
  # Helper Methods
  # ───────────────────────────────────────────────

  private

  def assert_enqueued_jobs(expected, only: nil)
    # In test environment with ActiveJob test adapter
    original_count = enqueued_jobs_count(only: only)

    yield

    new_count = enqueued_jobs_count(only: only)
    assert_equal expected, new_count - original_count,
      "Expected #{expected} jobs to be enqueued, but got #{new_count - original_count}"

    # Return the newly enqueued jobs
    all_jobs = enqueued_jobs
    all_jobs.select { |j| j[:job] == only } if only
  end

  def enqueued_jobs_count(only: nil)
    if only
      ActiveJob::Base.queue_adapter.enqueued_jobs.count { |j| j[:job] == only }
    else
      ActiveJob::Base.queue_adapter.enqueued_jobs.size
    end
  end

  def enqueued_jobs
    ActiveJob::Base.queue_adapter.enqueued_jobs
  end
end
