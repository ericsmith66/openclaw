# frozen_string_literal: true

class ConductorHeartbeatJob < ApplicationJob
  queue_as :default
  sidekiq_options lock: :until_executing, on_conflict: :log

  # FR-9: Perform periodic heartbeat to detect and reset stale tasks
  # NF-1: Idempotent execution with locking to prevent duplicate heartbeat checks
  #
  # A task is considered stale if it has been running longer than the configured
  # heartbeat timeout (default: 15 minutes). Stale tasks are reset to pending
  # via TaskResetService to allow re-execution.
  #
  # @see ConductorJob This job enqueues ConductorJob after resetting stale tasks
  # @see TaskResetService Handles the actual task reset logic
  #
  # @example
  #   # Runs automatically via Solid Queue recurring job (every 60 seconds)
  #   # No manual invocation needed
  def perform
    Rails.logger.info("[ConductorHeartbeatJob] Starting heartbeat check")

    # NF-1: Locking handled by sidekiq_options lock: :until_executing
    # Only one heartbeat check runs at a time

    # Find all running workflow executions
    running_executions = WorkflowExecution.where(status: :running)

    running_executions.each do |execution|
      reset_stale_tasks_for_execution(execution)
    end

    Rails.logger.info("[ConductorHeartbeatJob] Heartbeat check complete")
  end

  private

  def reset_stale_tasks_for_execution(execution)
    return unless execution

    # Get timeout from metadata or use default (15 minutes)
    timeout_minutes = execution.metadata&.[]("heartbeat_timeout_minutes") || 15
    timeout_threshold = timeout_minutes.minutes.ago

    Rails.logger.info("[ConductorHeartbeatJob] Checking execution #{execution.id} with #{timeout_minutes}min timeout")

    # Find running tasks associated with this execution that are stale
    # Tasks are associated via execution_run (WorkflowRun)
    stale_tasks = Task.where(status: :running)
                      .where("started_at < ?", timeout_threshold)
                      .where(project: execution.project)

    if stale_tasks.empty?
      Rails.logger.info("[ConductorHeartbeatJob] No stale tasks found for execution #{execution.id}")
      return
    end

    Rails.logger.info("[ConductorHeartbeatJob] Found #{stale_tasks.count} stale tasks for execution #{execution.id}")

    stale_tasks.each do |task|
      Rails.logger.info("[ConductorHeartbeatJob] Resetting stale task #{task.id}")

      # Reset the task via TaskResetService
      begin
        Legion::TaskResetService.call(task: task, reason: "heartbeat timeout reset")

        # Enqueue ConductorJob to re-evaluate workflow state
        ConductorJob.perform_later(execution_id: execution.id, trigger: :stale_task_detected)
      rescue StandardError => e
        Rails.logger.error("[ConductorHeartbeatJob] Failed to reset task #{task.id}: #{e.message}")
      end
    end

    Rails.logger.info("[ConductorHeartbeatJob] Completed reset of #{stale_tasks.count} tasks for execution #{execution.id}")
  end
end
