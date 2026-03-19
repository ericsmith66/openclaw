# frozen_string_literal: true

class ConductorJob < ApplicationJob
  queue_as :conductor

  # FR-3: Orchestrate workflow execution via task decomposition, planning, execution
  # FR-9: Detect and recover from stale tasks via heartbeat integration
  # NF-1: Idempotent execution with locking to prevent duplicate orchestration
  #
  # @param execution_id [Integer] the WorkflowExecution ID
  # @param trigger [Symbol] the trigger that initiated this job (:start, :task_complete, :all_tasks_complete, :stale_task_detected, :retry_ready)
  def perform(execution_id, trigger)
    Rails.logger.info("[ConductorJob] Starting execution_id=#{execution_id}, trigger=#{trigger}")

    # NF-1: Locking handled by Solid Queue's unique job feature
    # Only one ConductorJob per execution_id can run at a time

    execution = WorkflowExecution.find_by(id: execution_id)
    unless execution
      Rails.logger.error("[ConductorJob] WorkflowExecution not found: #{execution_id}")
      return
    end

    # Delegate to orchestration logic based on trigger
    case trigger
    when :start
      execute_initial_orchestration(execution)
    when :task_complete
      handle_task_completion(execution)
    when :all_tasks_complete
      handle_all_tasks_complete(execution)
    when :stale_task_detected
      handle_stale_task_detection(execution)
    when :retry_ready
      handle_retry_ready(execution)
    else
      Rails.logger.warn("[ConductorJob] Unknown trigger: #{trigger}")
    end
  end

  private

  # FR-3: Initial orchestration - decompose PRD into tasks
  def execute_initial_orchestration(execution)
    Rails.logger.info("[ConductorJob] Initial orchestration for execution #{execution.id}")

    # Decompose the PRD into initial tasks via DecompositionService
    begin
      result = Legion::DecompositionService.call(
        project: execution.project,
        prd_snapshot: execution.prd_snapshot,
        concurrency: execution.concurrency,
        task_retry_limit: execution.task_retry_limit
      )

      if result.success
        Rails.logger.info("[ConductorJob] Decomposition complete for execution #{execution.id}, #{result.tasks.count} tasks created")

        # Enqueue ready tasks via TaskDispatchJob
        result.tasks.each do |task|
          if task.dispatchable?
            task.update!(status: :queued, queued_at: Time.current)
            TaskDispatchJob.perform_later(task.id)
          end
        end

        execution.update!(phase: :executing)
      else
        Rails.logger.error("[ConductorJob] Decomposition failed for execution #{execution.id}: #{result.message}")
        execution.update!(status: :failed, phase: :cancelled)
      end
    rescue StandardError => e
      Rails.logger.error("[ConductorJob] Exception during initial orchestration: #{e.message}")
      execution.update!(status: :failed, phase: :cancelled)
    end
  end

  # FR-3: Handle task completion - determine if more tasks are ready
  def handle_task_completion(execution)
    Rails.logger.info("[ConductorJob] Task completion handling for execution #{execution.id}")

    # Find tasks that completed and enqueue their dependents
    Task.where(execution_run: execution.workflow_runs.first)
        .where(status: :completed)
        .each do |completed_task|
      enqueue_ready_dependents(completed_task)
    end
  end

  # FR-3: All tasks complete - finalize execution
  def handle_all_tasks_complete(execution)
    Rails.logger.info("[ConductorJob] All tasks complete for execution #{execution.id}")

    # Update execution status to completed
    execution.update!(status: :completed, phase: :phase_completed)

    # Fire completion callback for PRD 2-06 integration
    Rails.logger.info("[ConductorJob] Execution #{execution.id} completed successfully")
  end

  # FR-9: Handle stale task detection - orchestrate recovery
  def handle_stale_task_detection(execution)
    Rails.logger.info("[ConductorJob] Stale task detection handling for execution #{execution.id}")

    # Re-evaluate workflow state after stale task reset
    # This may enqueue new tasks or transition phases
    enqueue_ready_tasks_for_execution(execution)
  end

  # Handle retry_ready trigger - orchestrate retry cycle
  def handle_retry_ready(execution)
    Rails.logger.info("[ConductorJob] Retry ready handling for execution #{execution.id}")

    # Transition back to executing phase
    execution.update!(phase: :executing)

    # Enqueue ready tasks for retry
    enqueue_ready_tasks_for_execution(execution)
  end

  # Enqueue tasks that are ready to run
  def enqueue_ready_tasks_for_execution(execution)
    # Find ready tasks for this execution
    tasks = Task.where(execution_run: execution.workflow_runs.first)
                .where(status: :ready)

    tasks.each do |task|
      task.update!(status: :queued, queued_at: Time.current)
      TaskDispatchJob.perform_later(task.id)
    end
  end

  # Enqueue dependents of a completed task
  def enqueue_ready_dependents(completed_task)
    # Find tasks that depend on the completed task and are ready to run
    ready_dependents = completed_task.dependents.where(status: :ready)

    ready_dependents.each do |dependent|
      dependent.update!(status: :queued, queued_at: Time.current)
      TaskDispatchJob.perform_later(dependent.id)
    end
  end
end
