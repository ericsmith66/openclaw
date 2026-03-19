# frozen_string_literal: true

module Legion
  # RetryContextBuilder builds the accumulated context hash for a given task,
  # reading all prior retry_context and review_feedback Artifacts for the execution.
  #
  # Requirements:
  # - FR-7: Build accumulated context hash from retry_context and review_feedback Artifacts
  # - FR-8: Cap at 2000 tokens per attempt (summarization if needed)
  # - NF-2: Total context cap at 6000 tokens across all retry feedback
  class RetryContextBuilder
    MAX_TOKENS_PER_ATTEMPT = 2000
    MAX_TOTAL_TOKENS = 6000

    # Builds the accumulated context hash for a given task
    #
    # @param task [Task] The task to build context for
    # @param execution [WorkflowExecution] The workflow execution
    # @return [Hash] Accumulated context hash with attempt keys
    def self.call(task:, execution:)
      new(task: task, execution: execution).build
    end

    def initialize(task:, execution:)
      @task = task
      @execution = execution
    end

    def build
      context = {}
      attempts = fetch_attempts

      attempts.each do |attempt|
        retry_context = fetch_retry_context(attempt)
        review_feedback = fetch_review_feedback(attempt)

        # Only include attempts that have both retry_context and review_feedback
        next if retry_context.nil? || review_feedback.nil?

        # Cap each attempt's content at MAX_TOKENS_PER_ATTEMPT
        context["attempt_#{attempt}".to_sym] = {
          retry_context: truncate_with_ellipsis(retry_context, MAX_TOKENS_PER_ATTEMPT),
          review_feedback: truncate_with_ellipsis(review_feedback, MAX_TOKENS_PER_ATTEMPT)
        }
      end

      # Apply total context cap
      apply_total_cap(context)

      context
    end

    private

    attr_reader :task, :execution

    # Fetch all unique attempt numbers from retry_context and review_feedback artifacts
    def fetch_attempts
      attempt_sql = Arel.sql("artifacts.metadata->>'attempt'")

      retry_context_attempts = Artifact.retry_contexts
        .where(workflow_execution: execution)
        .where.not(metadata: { attempt: nil })
        .pluck(attempt_sql)
        .map(&:to_i)
        .uniq

      review_feedback_attempts = Artifact.review_feedbacks
        .where(workflow_execution: execution)
        .joins("JOIN artifacts AS score_reports ON artifacts.parent_artifact_id = score_reports.id")
        .where.not(metadata: { attempt: nil })
        .pluck(attempt_sql)
        .map(&:to_i)
        .uniq

      (retry_context_attempts + review_feedback_attempts).uniq.sort
    end

    # Fetch retry_context content for a specific attempt
    def fetch_retry_context(attempt)
      attempt_sql = Arel.sql("artifacts.metadata->>'attempt'")

      artifact = Artifact.retry_contexts
        .where(workflow_execution: execution)
        .where("#{attempt_sql} = ?", attempt.to_s)
        .first

      artifact&.content
    end

    # Fetch review_feedback content for a specific attempt
    def fetch_review_feedback(attempt)
      attempt_sql = Arel.sql("artifacts.metadata->>'attempt'")

      artifact = Artifact.review_feedbacks
        .where(workflow_execution: execution)
        .joins("JOIN artifacts AS score_reports ON artifacts.parent_artifact_id = score_reports.id")
        .where("#{attempt_sql} = ?", attempt.to_s)
        .first

      artifact&.content
    end

    # Truncate string to max_length and add ellipsis if truncated
    def truncate_with_ellipsis(text, max_length)
      return text if text.length <= max_length

      truncated = text.first(max_length - 3)
      "#{truncated}..."
    end

    # Apply total context cap by summarizing oldest attempts
    def apply_total_cap(context)
      total_length = context.values.sum do |attempt_data|
        attempt_data[:retry_context].length + attempt_data[:review_feedback].length
      end

      return context if total_length <= MAX_TOTAL_TOKENS

      # Summarize oldest attempts until under the cap
      context.keys.each do |key|
        attempt_data = context[key]
        next unless attempt_data

        current_total = context.values.sum do |data|
          data[:retry_context].length + data[:review_feedback].length
        end

        break if current_total <= MAX_TOTAL_TOKENS

        # Summarize by keeping only the first part and adding ellipsis
        max_per_field = (MAX_TOTAL_TOKENS / (context.size * 2)) - 3
        attempt_data[:retry_context] = truncate_with_ellipsis(
          attempt_data[:retry_context], [ max_per_field, 100 ].max
        )
        attempt_data[:review_feedback] = truncate_with_ellipsis(
          attempt_data[:review_feedback], [ max_per_field, 100 ].max
        )
      end

      context
    end
  end
end
