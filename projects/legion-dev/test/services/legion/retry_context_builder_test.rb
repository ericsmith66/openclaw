# frozen_string_literal: true

require "test_helper"

module Legion
  class RetryContextBuilderTest < ActiveSupport::TestCase
    setup do
      @project = create(:project)
      @team = create(:agent_team, project: @project)
      @membership = create(:team_membership, agent_team: @team)
      @workflow_run = create(:workflow_run, project: @project, team_membership: @membership)
      @workflow_execution = create(:workflow_execution,
                                    project: @project,
                                    workflow_runs: [ @workflow_run ])
    end

    # ============================================================================
    # FR-7: RetryContextBuilder builds accumulated context hash
    # ============================================================================

    test "FR-7: attempt 1 with no prior feedback returns empty context" do
      # No retry_context or review_feedback artifacts exist
      result = RetryContextBuilder.call(
        task: create(:task, workflow_execution: @workflow_execution),
        execution: @workflow_execution
      )

      assert_instance_of Hash, result
      assert_empty result
    end

    test "FR-7: attempt 2 with one prior feedback includes that feedback" do
      # Create a retry_context artifact for attempt 1
      create(:artifact,
             workflow_execution: @workflow_execution,
             artifact_type: :retry_context,
             content: "Previous attempt 1 context",
             metadata: { attempt: 1 })

      # Create a review_feedback artifact for attempt 1
      score_report = create(:artifact,
                            workflow_execution: @workflow_execution,
                            artifact_type: :score_report,
                            content: "Score report content",
                            metadata: { score: 85 })
      create(:artifact,
             workflow_execution: @workflow_execution,
             artifact_type: :review_feedback,
             content: "Review feedback for attempt 1",
             parent_artifact: score_report,
             metadata: { attempt: 1 })

      result = RetryContextBuilder.call(
        task: create(:task, workflow_execution: @workflow_execution),
        execution: @workflow_execution
      )

      assert_instance_of Hash, result
      assert_equal "Previous attempt 1 context", result[:attempt_1][:retry_context]
      assert_equal "Review feedback for attempt 1", result[:attempt_1][:review_feedback]
      assert_nil result[:attempt_2]
    end

    test "FR-7: attempt 3 with two prior feedbacks includes both feedbacks" do
      # Create retry_context and review_feedback for attempt 1
      create(:artifact,
             workflow_execution: @workflow_execution,
             artifact_type: :retry_context,
             content: "Previous attempt 1 context",
             metadata: { attempt: 1 })
      score_report1 = create(:artifact,
                             workflow_execution: @workflow_execution,
                             artifact_type: :score_report,
                             content: "Score report 1",
                             metadata: { score: 85 })
      create(:artifact,
             workflow_execution: @workflow_execution,
             artifact_type: :review_feedback,
             content: "Review feedback for attempt 1",
             parent_artifact: score_report1,
             metadata: { attempt: 1 })

      # Create retry_context and review_feedback for attempt 2
      create(:artifact,
             workflow_execution: @workflow_execution,
             artifact_type: :retry_context,
             content: "Previous attempt 2 context",
             metadata: { attempt: 2 })
      score_report2 = create(:artifact,
                             workflow_execution: @workflow_execution,
                             artifact_type: :score_report,
                             content: "Score report 2",
                             metadata: { score: 88 })
      create(:artifact,
             workflow_execution: @workflow_execution,
             artifact_type: :review_feedback,
             content: "Review feedback for attempt 2",
             parent_artifact: score_report2,
             metadata: { attempt: 2 })

      result = RetryContextBuilder.call(
        task: create(:task, workflow_execution: @workflow_execution),
        execution: @workflow_execution
      )

      assert_instance_of Hash, result
      assert_equal "Previous attempt 1 context", result[:attempt_1][:retry_context]
      assert_equal "Review feedback for attempt 1", result[:attempt_1][:review_feedback]
      assert_equal "Previous attempt 2 context", result[:attempt_2][:retry_context]
      assert_equal "Review feedback for attempt 2", result[:attempt_2][:review_feedback]
      assert_nil result[:attempt_3]
    end

    # ============================================================================
    # FR-8: 2000 token cap per attempt via summarization
    # ============================================================================

    test "FR-8: attempt context capped at 2000 characters with summarization" do
      # Create a retry_context that exceeds 2000 characters
      long_content = "x" * 2500
      create(:artifact,
             workflow_execution: @workflow_execution,
             artifact_type: :retry_context,
             content: long_content,
             metadata: { attempt: 1 })

      # Create corresponding review_feedback
      score_report = create(:artifact,
                            workflow_execution: @workflow_execution,
                            artifact_type: :score_report,
                            content: "Score report",
                            metadata: { score: 85 })
      create(:artifact,
             workflow_execution: @workflow_execution,
             artifact_type: :review_feedback,
             content: "Review feedback",
             parent_artifact: score_report,
             metadata: { attempt: 1 })

      result = RetryContextBuilder.call(
        task: create(:task, workflow_execution: @workflow_execution),
        execution: @workflow_execution
      )

      assert_instance_of Hash, result
      assert result[:attempt_1][:retry_context].length <= 2000
      # Should be truncated with ellipsis or similar indicator
      assert result[:attempt_1][:retry_context].end_with?("...")
    end

    test "FR-8: review feedback also capped at 2000 characters" do
      # Create a review_feedback that exceeds 2000 characters
      long_feedback = "y" * 2500
      score_report = create(:artifact,
                            workflow_execution: @workflow_execution,
                            artifact_type: :score_report,
                            content: "Score report",
                            metadata: { score: 85 })
      create(:artifact,
             workflow_execution: @workflow_execution,
             artifact_type: :review_feedback,
             content: long_feedback,
             parent_artifact: score_report,
             metadata: { attempt: 1 })

      # Create corresponding retry_context
      create(:artifact,
             workflow_execution: @workflow_execution,
             artifact_type: :retry_context,
             content: "Retry context",
             metadata: { attempt: 1 })

      result = RetryContextBuilder.call(
        task: create(:task, workflow_execution: @workflow_execution),
        execution: @workflow_execution
      )

      assert_instance_of Hash, result
      assert result[:attempt_1][:review_feedback].length <= 2000
      assert result[:attempt_1][:review_feedback].end_with?("...")
    end

    test "FR-8: multiple attempts each capped at 2000 characters" do
      # Create long content for both attempts
      long_content1 = "a" * 2500
      long_content2 = "b" * 2500

      create(:artifact,
             workflow_execution: @workflow_execution,
             artifact_type: :retry_context,
             content: long_content1,
             metadata: { attempt: 1 })
      score_report1 = create(:artifact,
                             workflow_execution: @workflow_execution,
                             artifact_type: :score_report,
                             content: "Score report 1",
                             metadata: { score: 85 })
      create(:artifact,
             workflow_execution: @workflow_execution,
             artifact_type: :review_feedback,
             content: long_content1,
             parent_artifact: score_report1,
             metadata: { attempt: 1 })

      create(:artifact,
             workflow_execution: @workflow_execution,
             artifact_type: :retry_context,
             content: long_content2,
             metadata: { attempt: 2 })
      score_report2 = create(:artifact,
                             workflow_execution: @workflow_execution,
                             artifact_type: :score_report,
                             content: "Score report 2",
                             metadata: { score: 88 })
      create(:artifact,
             workflow_execution: @workflow_execution,
             artifact_type: :review_feedback,
             content: long_content2,
             parent_artifact: score_report2,
             metadata: { attempt: 2 })

      result = RetryContextBuilder.call(
        task: create(:task, workflow_execution: @workflow_execution),
        execution: @workflow_execution
      )

      assert_instance_of Hash, result
      assert result[:attempt_1][:retry_context].length <= 2000
      assert result[:attempt_1][:review_feedback].length <= 2000
      assert result[:attempt_2][:retry_context].length <= 2000
      assert result[:attempt_2][:review_feedback].length <= 2000
    end

    # ============================================================================
    # NF-2: 6000 token total context cap
    # ============================================================================

    test "NF-2: total accumulated context capped at 6000 characters" do
      # Create content that would exceed 6000 total
      # Attempt 1: 2500 chars
      long_content1 = "a" * 2500
      create(:artifact,
             workflow_execution: @workflow_execution,
             artifact_type: :retry_context,
             content: long_content1,
             metadata: { attempt: 1 })
      score_report1 = create(:artifact,
                             workflow_execution: @workflow_execution,
                             artifact_type: :score_report,
                             content: "Score report 1",
                             metadata: { score: 85 })
      create(:artifact,
             workflow_execution: @workflow_execution,
             artifact_type: :review_feedback,
             content: long_content1,
             parent_artifact: score_report1,
             metadata: { attempt: 1 })

      # Attempt 2: 2500 chars
      long_content2 = "b" * 2500
      create(:artifact,
             workflow_execution: @workflow_execution,
             artifact_type: :retry_context,
             content: long_content2,
             metadata: { attempt: 2 })
      score_report2 = create(:artifact,
                             workflow_execution: @workflow_execution,
                             artifact_type: :score_report,
                             content: "Score report 2",
                             metadata: { score: 88 })
      create(:artifact,
             workflow_execution: @workflow_execution,
             artifact_type: :review_feedback,
             content: long_content2,
             parent_artifact: score_report2,
             metadata: { attempt: 2 })

      # Attempt 3: 2500 chars (would make 7500 total without cap)
      long_content3 = "c" * 2500
      create(:artifact,
             workflow_execution: @workflow_execution,
             artifact_type: :retry_context,
             content: long_content3,
             metadata: { attempt: 3 })
      score_report3 = create(:artifact,
                             workflow_execution: @workflow_execution,
                             artifact_type: :score_report,
                             content: "Score report 3",
                             metadata: { score: 90 })
      create(:artifact,
             workflow_execution: @workflow_execution,
             artifact_type: :review_feedback,
             content: long_content3,
             parent_artifact: score_report3,
             metadata: { attempt: 3 })

      result = RetryContextBuilder.call(
        task: create(:task, workflow_execution: @workflow_execution),
        execution: @workflow_execution
      )

      assert_instance_of Hash, result
      # Total should be capped at 6000
      total_length = result[:attempt_1][:retry_context].length +
                     result[:attempt_1][:review_feedback].length +
                     result[:attempt_2][:retry_context].length +
                     result[:attempt_2][:review_feedback].length +
                     result[:attempt_3][:retry_context].length +
                     result[:attempt_3][:review_feedback].length
      assert total_length <= 6000
    end

    test "NF-2: oldest feedback is summarized when total exceeds 6000" do
      # Create content that would exceed 6000 total
      long_content1 = "a" * 2500
      create(:artifact,
             workflow_execution: @workflow_execution,
             artifact_type: :retry_context,
             content: long_content1,
             metadata: { attempt: 1 })
      score_report1 = create(:artifact,
                             workflow_execution: @workflow_execution,
                             artifact_type: :score_report,
                             content: "Score report 1",
                             metadata: { score: 85 })
      create(:artifact,
             workflow_execution: @workflow_execution,
             artifact_type: :review_feedback,
             content: long_content1,
             parent_artifact: score_report1,
             metadata: { attempt: 1 })

      # Attempt 2: 2500 chars
      long_content2 = "b" * 2500
      create(:artifact,
             workflow_execution: @workflow_execution,
             artifact_type: :retry_context,
             content: long_content2,
             metadata: { attempt: 2 })
      score_report2 = create(:artifact,
                             workflow_execution: @workflow_execution,
                             artifact_type: :score_report,
                             content: "Score report 2",
                             metadata: { score: 88 })
      create(:artifact,
             workflow_execution: @workflow_execution,
             artifact_type: :review_feedback,
             content: long_content2,
             parent_artifact: score_report2,
             metadata: { attempt: 2 })

      result = RetryContextBuilder.call(
        task: create(:task, workflow_execution: @workflow_execution),
        execution: @workflow_execution
      )

      assert_instance_of Hash, result
      # Attempt 1 (oldest) should be summarized
      assert result[:attempt_1][:retry_context].end_with?("...")
      assert result[:attempt_1][:review_feedback].end_with?("...")
      # Attempt 2 (newer) should be preserved in full or with less truncation
      assert result[:attempt_2][:retry_context].end_with?("...")
      assert result[:attempt_2][:review_feedback].end_with?("...")
    end

    # ============================================================================
    # FR-7, FR-8, NF-2: Accumulated context hash structure
    # ============================================================================

    test "returns accumulated context hash with correct structure" do
      create(:artifact,
             workflow_execution: @workflow_execution,
             artifact_type: :retry_context,
             content: "Context for attempt 1",
             metadata: { attempt: 1 })
      score_report = create(:artifact,
                            workflow_execution: @workflow_execution,
                            artifact_type: :score_report,
                            content: "Score report",
                            metadata: { score: 85 })
      create(:artifact,
             workflow_execution: @workflow_execution,
             artifact_type: :review_feedback,
             content: "Feedback for attempt 1",
             parent_artifact: score_report,
             metadata: { attempt: 1 })

      result = RetryContextBuilder.call(
        task: create(:task, workflow_execution: @workflow_execution),
        execution: @workflow_execution
      )

      assert_instance_of Hash, result
      assert result.key?(:attempt_1)
      assert result[:attempt_1].is_a?(Hash)
      assert result[:attempt_1].key?(:retry_context)
      assert result[:attempt_1].key?(:review_feedback)
      assert_equal "Context for attempt 1", result[:attempt_1][:retry_context]
      assert_equal "Feedback for attempt 1", result[:attempt_1][:review_feedback]
    end

    test "returns empty hash when no artifacts exist" do
      result = RetryContextBuilder.call(
        task: create(:task, workflow_execution: @workflow_execution),
        execution: @workflow_execution
      )

      assert_instance_of Hash, result
      assert_empty result
    end

    test "only includes attempts that have both retry_context and review_feedback" do
      # Only create retry_context for attempt 1, no review_feedback
      create(:artifact,
             workflow_execution: @workflow_execution,
             artifact_type: :retry_context,
             content: "Context for attempt 1",
             metadata: { attempt: 1 })

      result = RetryContextBuilder.call(
        task: create(:task, workflow_execution: @workflow_execution),
        execution: @workflow_execution
      )

      assert_instance_of Hash, result
      assert_empty result
    end

    test "handles artifacts with missing metadata gracefully" do
      # Create artifact without metadata
      create(:artifact,
             workflow_execution: @workflow_execution,
             artifact_type: :retry_context,
             content: "Context without metadata")

      score_report = create(:artifact,
                            workflow_execution: @workflow_execution,
                            artifact_type: :score_report,
                            content: "Score report")
      create(:artifact,
             workflow_execution: @workflow_execution,
             artifact_type: :review_feedback,
             content: "Feedback without metadata",
             parent_artifact: score_report)

      result = RetryContextBuilder.call(
        task: create(:task, workflow_execution: @workflow_execution),
        execution: @workflow_execution
      )

      # Should handle gracefully - either skip or use defaults
      assert_instance_of Hash, result
    end

    # ============================================================================
    # NF-1: Performance requirements
    # ============================================================================

    test "NF-1: completes in under 500ms for typical case" do
      # Create multiple artifacts
      3.times do |i|
        create(:artifact,
               workflow_execution: @workflow_execution,
               artifact_type: :retry_context,
               content: "Context for attempt #{i + 1}",
               metadata: { attempt: i + 1 })
        score_report = create(:artifact,
                              workflow_execution: @workflow_execution,
                              artifact_type: :score_report,
                              content: "Score report #{i + 1}",
                              metadata: { score: 85 + i })
        create(:artifact,
               workflow_execution: @workflow_execution,
               artifact_type: :review_feedback,
               content: "Feedback for attempt #{i + 1}",
               parent_artifact: score_report,
               metadata: { attempt: i + 1 })
      end

      time_taken = measure_time do
        RetryContextBuilder.call(
          task: create(:task, workflow_execution: @workflow_execution),
          execution: @workflow_execution
        )
      end

      assert time_taken < 0.5, "Expected completion in under 500ms, took #{time_taken}s"
    end

    private

    def measure_time
      start_time = Time.now
      yield
      Time.now - start_time
    end
  end
end
