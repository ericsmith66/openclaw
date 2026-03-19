# frozen_string_literal: true

class TaskDispatchJob < ApplicationJob
  queue_as :default

  # FR-1: Dispatch a single task via DispatchService
  # FR-2: Set timing fields and status transitions
  # FR-3: Enqueue dependent tasks on completion
  # FR-4: Handle failures with error storage
  # FR-5: Fire completion callback when all tasks are terminal
  # NF-3: Idempotent re-runs (no-op for completed/failed tasks)
  def perform(task_id)
    task = Task.find_by(id: task_id)
    return if task.nil? # Task was deleted

    # NF-3: Idempotency - if task is already in terminal state, do nothing
    return if task.completed? || task.failed? || task.skipped?

    # FR-2: Set started_at when job begins execution
    task.update!(started_at: Time.current) if task.queued? || task.pending?

    # FR-2: Update status from queued/ready/pending to running
    if task.queued? || task.pending?
      task.update!(status: :running)
    end

    begin
      # FR-1: Dispatch the task via DispatchService
      execution_run = dispatch_task(task)

      # FR-2: Set completed_at on success and update status
      task.update!(status: :completed, completed_at: Time.current)

      # FR-3: Check for newly-ready tasks and enqueue them
      enqueue_ready_dependents(task)

      # FR-5: Check if all tasks are terminal and fire completion callback
      fire_completion_callback(task.workflow_run)

    rescue Interrupt
      # Re-raise interrupt to allow graceful shutdown
      task.update!(status: :failed, completed_at: Time.current, last_error: "interrupted by user")
      raise

    rescue StandardError => e
      # FR-4: Handle task failure
      task.update!(status: :failed, completed_at: Time.current, last_error: e.message)
    end
  end

  private

  # FR-1: Dispatch a single task via DispatchService
  def dispatch_task(task)
    project_path = task.project.path

    # Enrich prompt with file context if needed
    enriched_prompt = enrich_prompt_with_file_context(task.error_context_enriched_prompt, project_path)

    Legion::DispatchService.call(
      team_name: task.team_membership.agent_team.name,
      agent_identifier: task.team_membership.config["id"],
      prompt: enriched_prompt,
      project_path: project_path,
      max_iterations: nil
    )
  end

  # Scans the task prompt for file paths referenced in backticks and appends their contents
  def enrich_prompt_with_file_context(prompt, project_path)
    # Extract backtick-quoted paths that look like source files
    file_refs = prompt.scan(/`([^`]+\.[a-z]{1,4})`/).flatten.uniq

    # Filter to files that actually exist, limit to 5 to avoid prompt bloat
    existing_files = file_refs.select do |ref|
      path = File.join(project_path, ref)
      File.exist?(path) && File.file?(path) && File.size(path) < 50_000
    end.first(5)

    return prompt if existing_files.empty?

    context_blocks = existing_files.map do |ref|
      path = File.join(project_path, ref)
      content = File.read(path)
      "### File: `#{ref}` (#{content.lines.count} lines)\n```\n#{content}\n```"
    end

    "#{prompt}\n\n---\n## Reference Files (pre-loaded — do NOT re-read these)\n\n#{context_blocks.join("\n\n")}"
  end

  # FR-3: Enqueue TaskDispatchJob for tasks that become ready
  def enqueue_ready_dependents(completed_task)
    # Find tasks that depend on the completed task and are ready to run
    ready_dependents = completed_task.dependents.ready

    ready_dependents.each do |dependent|
      # Update status to queued
      dependent.update!(status: :queued, queued_at: Time.current)

      # Enqueue TaskDispatchJob for this dependent
      TaskDispatchJob.perform_later(dependent.id)
    end
  end

  # FR-5: Fire completion callback when all tasks are terminal
  def fire_completion_callback(workflow_run)
    # Check if all tasks in this workflow_run are in terminal state
    non_terminal_count = Task.where(workflow_run: workflow_run)
                            .where.not(status: [ :completed, :failed, :skipped ])
                            .count

    return if non_terminal_count.positive?

    # All tasks are terminal - fire completion callback
    Rails.logger.info("[TaskDispatchJob] All tasks for WorkflowRun ##{workflow_run.id} are terminal. Enqueuing ConductorJob...")

    # Enqueue ConductorJob for orchestrating next steps
    ConductorJob.perform_later(
      workflow_run_id: workflow_run.id,
      trigger: :all_tasks_complete
    )
  end
end
