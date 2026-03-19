# frozen_string_literal: true

module Legion
  module OrchestrationTools
    # RetryWithContext orchestration tool
    #
    # Called when QA gate returns a score below threshold and attempt <= max_retries.
    # Accumulates feedback, resets targeted tasks, increments execution attempt.
    #
    # FR-1: Full implementation of retry_with_context tool
    # AC-1: Given QA score 87 (threshold 90) and attempt 1/3, resets targeted tasks, creates retry_context Artifact, increments attempt to 2
    # AC-6: Given attempt 4 and QA score < 90, tool refuses (precondition: attempt > max_retries)
    # AC-7: Given task with retry_count >= task_retry_limit, task is marked failed permanently
    #
    # @example
    #   result = Legion::OrchestrationTools::RetryWithContext.call(
    #     execution: workflow_execution,
    #     score_report: score_report_artifact
    #   )
    #   if result.success?
    #     # Tasks reset, context accumulated, attempt incremented
    #   else
    #     # Precondition failed or error occurred
    #   end
    class RetryWithContext
      MAX_ATTEMPTS = 3

      def self.call(execution:, score_report:)
        new(execution:, score_report:).call
      end

      def initialize(execution:, score_report:)
        @execution = execution
        @score_report = score_report
      end

      def call
        validate_preconditions
        select_tasks_to_retry
        reset_tasks
        increment_attempt
        create_artifacts
        transition_to_retrying_phase
        enqueue_conductor_job
      end

      private

      attr_reader :execution, :score_report

      def validate_preconditions
        # Check attempt <= max_retries — block when attempt has exceeded MAX_ATTEMPTS
        if execution.attempt > MAX_ATTEMPTS
          raise PreconditionError,
                "Attempt #{execution.attempt} > max_retries #{MAX_ATTEMPTS}. Cannot retry further."
        end

        # Check score < threshold (default 90); nil score means not yet scored — allow retry
        score = score_report.metadata&.[]("score")
        if !score.nil? && score.to_i >= 90
          raise PreconditionError,
                "Score #{score} >= threshold 90. No retry needed."
        end
      end

      def select_tasks_to_retry
        # Try to extract file paths from QA feedback
        feedback_content = score_report.content
        file_paths = extract_file_paths(feedback_content)

        if file_paths.any?
          # Select tasks that match the file paths
          @tasks_to_retry = tasks_matching_file_paths(file_paths).to_a
          # If no tasks match file paths, fall back to all non-completed tasks
          if @tasks_to_retry.empty?
            @tasks_to_retry = non_completed_tasks.to_a
            Rails.logger.info("QA feedback references files but no tasks match — retrying all incomplete tasks")
          end
        else
          # Fallback: select all non-completed tasks
          @tasks_to_retry = non_completed_tasks.to_a
          Rails.logger.info("QA feedback doesn't reference specific files — retrying all incomplete tasks")
        end
      end

      def extract_file_paths(text)
        # Extract file paths from text (e.g., "app/models/user.rb", "test/models/user_test.rb")
        # Pattern matches common Ruby file paths
        text.scan(/(?:app|lib|test|spec|features)\/[^\s"']+\.(?:rb|erb|slim|haml)/)
      end

      def tasks_matching_file_paths(file_paths)
        # Find tasks whose prompts or results reference the file paths
        # For now, we'll match against task prompts
        task_ids = file_paths.flat_map do |file_path|
          Task.where("prompt LIKE ? OR result LIKE ?", "%#{file_path}%", "%#{file_path}%")
             .where(workflow_execution: execution)
             .pluck(:id)
        end.uniq

        Task.where(id: task_ids).where(workflow_execution: execution)
      end

      def non_completed_tasks
        Task.where(workflow_execution: execution)
            .where.not(status: "completed")
      end

      def reset_tasks
        @current_attempt = execution.attempt # Capture current attempt before incrementing
        limit = task_retry_limit_for_task(nil)
        @tasks_to_retry.each do |task|
          # Check if this reset would exhaust the retry budget.
          # Permanently fail when retry_count is already at or above the limit —
          # meaning all allowed retries have been consumed.
          if task.retry_count >= limit
            # Mark task as permanently failed
            task.status = "failed"
            task.metadata = (task.metadata || {}).merge("permanently_failed" => true)
            task.save!(validate: false)
          elsif task.resettable?
            # Failed or skipped tasks: delegate to TaskResetService (increments retry_count)
            TaskResetService.call(task: task)
          else
            # Ready/pending/running tasks: increment retry_count to track retry attempts.
            # After incrementing, check again if the limit is now reached.
            new_count = task.retry_count + 1
            if new_count >= limit
              task.retry_count = new_count
              task.status = "failed"
              task.metadata = (task.metadata || {}).merge("permanently_failed" => true)
              task.save!(validate: false)
            else
              task.update!(retry_count: new_count)
            end
          end
        end
      end

      def task_retry_limit_for_task(_task = nil)
        execution.task_retry_limit
      end

      def increment_attempt
        execution.update!(attempt: execution.attempt + 1)
      end

      def create_artifacts
        workflow_run = execution.workflow_run
        current_attempt = @current_attempt

        # Create review_feedback artifact linked to score_report
        review_feedback = Artifact.create!(
          workflow_run: workflow_run,
          workflow_execution: execution,
          artifact_type: :review_feedback,
          name: "Review Feedback (Attempt #{current_attempt})",
          content: score_report.content,
          parent_artifact: score_report,
          project: execution.project,
          created_by: execution.team,
          metadata: { attempt: current_attempt }
        )

        # Create retry_context artifact with accumulated feedback using RetryContextBuilder
        accumulated_context = build_accumulated_context

        retry_context = Artifact.create!(
          workflow_run: workflow_run,
          workflow_execution: execution,
          artifact_type: :retry_context,
          name: "Retry Context (Attempt #{current_attempt})",
          content: accumulated_context,
          project: execution.project,
          created_by: execution.team,
          metadata: { attempt: current_attempt }
        )

        [ retry_context, review_feedback ]
      end

      def build_accumulated_context
        # Use RetryContextBuilder to build accumulated context
        # We need a task to pass to RetryContextBuilder, so we'll use the first task
        task = @tasks_to_retry&.first || Task.where(workflow_execution: execution).first

        next_attempt = @current_attempt + 1

        # Include the current score_report feedback at the top
        # The next attempt number is used to indicate "this is what to fix for attempt N"
        current_feedback = "## Attempt #{next_attempt} Retry Context\n\n" \
                           "### Attempt #{@current_attempt} QA Feedback\n#{score_report.content}"

        # Build prior context from RetryContextBuilder (prior attempts)
        if task
          context_hash = RetryContextBuilder.call(task: task, execution: execution)

          if context_hash.empty?
            current_feedback
          else
            formatted = format_context_hash(context_hash)
            "#{current_feedback}\n\n## Prior Attempts\n#{formatted}"
          end
        else
          current_feedback
        end
      end

      def format_context_hash(context_hash)
        formatted = +""
        context_hash.each do |key, data|
          formatted << "## #{key.to_s.upcase}\n"
          formatted << "### Retry Context\n"
          formatted << data[:retry_context]
          formatted << "\n\n### Review Feedback\n"
          formatted << data[:review_feedback]
          formatted << "\n\n"
        end
        formatted.strip
      end

      def transition_to_retrying_phase
        # Transition to iterating phase for retrying
        execution.update!(phase: :iterating)
      end

      def enqueue_conductor_job
        # Enqueue ConductorJob with trigger: :retry_ready
        # This will trigger the next cycle (dispatch_coding)
        ConductorJob.perform_later(
          workflow_execution_id: execution.id,
          trigger: :retry_ready
        )
      end

      class PreconditionError < StandardError; end
    end
  end
end
