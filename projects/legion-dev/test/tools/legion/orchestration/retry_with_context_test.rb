# frozen_string_literal: true

require "test_helper"
require Rails.root.join("app/tools/legion/orchestration/retry_with_context")

module Legion
  module OrchestrationTools
    class RetryWithContextTest < ActiveSupport::TestCase
      setup do
        @project = create(:project)
        @team = create(:agent_team, project: @project)
        @membership = create(:team_membership, agent_team: @team)
        @workflow_run = create(:workflow_run, project: @project, team_membership: @membership)
        @execution = create(:workflow_execution, project: @project)
        @workflow_run.update!(workflow_execution: @execution)

        # Stub DispatchService for QA gate evaluation
        @default_dispatch_result = mock("dispatch_result")
        @default_dispatch_result.stubs(:result).returns("")
        Legion::DispatchService.stubs(:call).returns(@default_dispatch_result)

        # Stub lower-level agent infrastructure
        AgentDesk::Rules::RulesLoader.stubs(:load_rules_content).returns("rules content")
        AgentDesk::Prompts::PromptsManager.stubs(:system_prompt).returns("system prompt")
        AgentDesk::Tools::PowerTools.stubs(:create).returns(AgentDesk::Tools::ToolSet.new)
        AgentDesk::Skills::SkillLoader.any_instance.stubs(:activate_skill_tool).returns(stub(full_name: "skills---activate_skill"))
        AgentDesk::Tools::TodoTools.stubs(:create).returns(AgentDesk::Tools::ToolSet.new)
        AgentDesk::Tools::MemoryTools.stubs(:create).returns(AgentDesk::Tools::ToolSet.new)
        AgentDesk::Models::ModelManager.stubs(:new).returns(mock)
        Legion::PostgresBus.stubs(:new).returns(mock)
        AgentDesk::Hooks::HookManager.stubs(:new).returns(mock)
        AgentDesk::Tools::ApprovalManager.stubs(:new).returns(mock)
        AgentDesk::Agent::Runner.stubs(:new).returns(mock)

        default_runner = mock
        default_runner.stubs(:run)
        default_profile = mock
        default_profile.stubs(:id).returns("default")
        default_profile.stubs(:name).returns("default")
        default_profile.stubs(:provider).returns("default")
        default_profile.stubs(:model).returns("default")
        default_profile.stubs(:max_iterations).returns(100)
        Legion::AgentAssemblyService.stubs(:call).returns({
          runner: default_runner,
          system_prompt: "default",
          tool_set: mock,
          profile: default_profile,
          message_bus: mock
        })
      end

      # ============================================================================
      # FR-1: Precondition validation (attempt < max, score < threshold)
      # ============================================================================

      test "FR-1: precondition fails when attempt >= max_retries" do
        # Set execution attempt BEYOND max (> 3 means 4)
        @execution.update!(attempt: 4)

        # Create a score report with score below threshold
        score_report = create(:artifact,
                              workflow_execution: @execution,
                              artifact_type: :score_report,
                              content: "## Score\n85/100\n\n## Feedback\nMissing tests",
                              metadata: { score: 85 })

        # Should raise precondition error (attempt 4 > MAX_ATTEMPTS 3)
        assert_raises do
          RetryWithContext.call(execution: @execution, score_report: score_report)
        end
      end

      test "FR-1: precondition fails when score >= threshold" do
        # Set execution attempt below max
        @execution.update!(attempt: 1)

        # Create a score report with score at or above threshold (90)
        score_report = create(:artifact,
                              workflow_execution: @execution,
                              artifact_type: :score_report,
                              content: "## Score\n92/100\n\n## Feedback\nExcellent",
                              metadata: { score: 92 })

        # Should raise precondition error
        assert_raises do
          RetryWithContext.call(execution: @execution, score_report: score_report)
        end
      end

      test "FR-1: precondition passes when attempt < max and score < threshold" do
        # Set execution attempt below max
        @execution.update!(attempt: 1)

        # Create a score report with score below threshold
        score_report = create(:artifact,
                              workflow_execution: @execution,
                              artifact_type: :score_report,
                              content: "## Score\n85/100\n\n## Feedback\nMissing tests",
                              metadata: { score: 85 })

        # Should not raise
        assert_nothing_raised do
          RetryWithContext.call(execution: @execution, score_report: score_report)
        end
      end

      test "FR-1: precondition uses default threshold of 90" do
        @execution.update!(attempt: 1)

        # Score exactly at threshold (90) should fail precondition
        score_report = create(:artifact,
                              workflow_execution: @execution,
                              artifact_type: :score_report,
                              content: "## Score\n90/100\n\n## Feedback\nAt threshold",
                              metadata: { score: 90 })

        assert_raises do
          RetryWithContext.call(execution: @execution, score_report: score_report)
        end
      end

      test "FR-1: precondition passes when score is just below threshold" do
        @execution.update!(attempt: 1)

        # Score 89 (just below 90) should pass precondition
        score_report = create(:artifact,
                              workflow_execution: @execution,
                              artifact_type: :score_report,
                              content: "## Score\n89/100\n\n## Feedback\nAlmost there",
                              metadata: { score: 89 })

        assert_nothing_raised do
          RetryWithContext.call(execution: @execution, score_report: score_report)
        end
      end

      # ============================================================================
      # FR-1: Task selection via file path matching from QA feedback
      # ============================================================================

      test "FR-1: task selection via file path matching in QA feedback" do
        @execution.update!(attempt: 1)

        # Create tasks with file paths
        task1 = create(:task, workflow_execution: @execution, position: 1,
                             prompt: "Implement User model",
                             status: :failed,
                             last_error: "Test failed")
        task2 = create(:task, workflow_execution: @execution, position: 2,
                             prompt: "Implement Post model",
                             status: :completed,
                             last_error: nil)

        # Create score report with file path references in feedback
        score_report = create(:artifact,
                              workflow_execution: @execution,
                              artifact_type: :score_report,
                              content: "## Score\n85/100\n\n## Feedback\nIssues in app/models/user.rb and test/models/user_test.rb",
                              metadata: { score: 85 })

        # Should select task1 (matches file path)
        result = RetryWithContext.call(execution: @execution, score_report: score_report)

        # Verify task1 was reset (may be pending or ready depending on dependencies)
        assert_includes %w[pending ready], task1.reload.status, "Expected task1 to be reset"
        # Verify task2 was not reset (completed)
        assert_equal "completed", task2.reload.status
      end

      test "FR-1: fallback to all non-completed tasks when no file path matching" do
        @execution.update!(attempt: 1)

        # Create tasks
        task1 = create(:task, workflow_execution: @execution, position: 1,
                             status: :failed)
        task2 = create(:task, workflow_execution: @execution, position: 2,
                             status: :completed)
        task3 = create(:task, workflow_execution: @execution, position: 3,
                             status: :failed)

        # Create score report with no file path references
        score_report = create(:artifact,
                              workflow_execution: @execution,
                              artifact_type: :score_report,
                              content: "## Score\n85/100\n\n## Feedback\nGeneral issues with implementation",
                              metadata: { score: 85 })

        result = RetryWithContext.call(execution: @execution, score_report: score_report)

        # Verify failed tasks were reset (may be pending or ready depending on dependencies)
        assert_includes %w[pending ready], task1.reload.status, "Expected task1 to be reset"
        # Verify completed task was not reset
        assert_equal "completed", task2.reload.status
        assert_includes %w[pending ready], task3.reload.status, "Expected task3 to be reset"
      end

      test "FR-1: fallback to all non-completed tasks when QA feedback is unclear" do
        @execution.update!(attempt: 1)

        task1 = create(:task, workflow_execution: @execution, position: 1,
                             status: :failed)
        task2 = create(:task, workflow_execution: @execution, position: 2,
                             status: :pending)

        # Create score report with unclear feedback
        score_report = create(:artifact,
                              workflow_execution: @execution,
                              artifact_type: :score_report,
                              content: "## Score\n85/100\n\n## Feedback\nSome problems need fixing",
                              metadata: { score: 85 })

        result = RetryWithContext.call(execution: @execution, score_report: score_report)

        # Only failed tasks should be reset (may be pending or ready depending on dependencies)
        assert_includes %w[pending ready], task1.reload.status, "Expected task1 to be reset"
        # Pending task should not be reset (it wasn't failed, so not in tasks_to_retry)
        assert_equal "pending", task2.reload.status
      end

      # ============================================================================
      # FR-1: Artifact creation for retry_context and review_feedback
      # ============================================================================

      test "FR-1: creates retry_context Artifact with accumulated feedback" do
        @execution.update!(attempt: 1)

        task = create(:task, workflow_execution: @execution, position: 1,
                             status: :failed)
        score_report = create(:artifact,
                              workflow_execution: @execution,
                              artifact_type: :score_report,
                              content: "## Score\n85/100\n\n## Feedback\nMissing tests",
                              metadata: { score: 85 })

        result = RetryWithContext.call(execution: @execution, score_report: score_report)

        # Verify retry_context artifact was created
        retry_context = Artifact.retry_contexts.where(workflow_execution: @execution).first
        assert retry_context
        assert retry_context.content.include?("85")
        assert retry_context.content.include?("Missing tests")
        assert_equal 1, retry_context.metadata["attempt"]
      end

      test "FR-1: creates review_feedback Artifact linked to score_report" do
        @execution.update!(attempt: 1)

        task = create(:task, workflow_execution: @execution, position: 1,
                             status: :failed)
        score_report = create(:artifact,
                              workflow_execution: @execution,
                              artifact_type: :score_report,
                              content: "## Score\n85/100\n\n## Feedback\nMissing tests",
                              metadata: { score: 85 })

        result = RetryWithContext.call(execution: @execution, score_report: score_report)

        # Verify review_feedback artifact was created
        review_feedback = Artifact.review_feedbacks.where(workflow_execution: @execution).first
        assert review_feedback
        assert_equal score_report.id, review_feedback.parent_artifact_id
        assert review_feedback.content.include?("85")
      end

      test "FR-1: creates retry_context with attempt number in metadata" do
        @execution.update!(attempt: 2)

        task = create(:task, workflow_execution: @execution, position: 1,
                             status: :failed)
        score_report = create(:artifact,
                              workflow_execution: @execution,
                              artifact_type: :score_report,
                              content: "## Score\n85/100\n\n## Feedback\nMissing tests",
                              metadata: { score: 85 })

        result = RetryWithContext.call(execution: @execution, score_report: score_report)

        retry_context = Artifact.retry_contexts.where(workflow_execution: @execution).first
        assert retry_context
        assert_equal 2, retry_context.metadata["attempt"]
      end

      # ============================================================================
      # FR-1: Attempt increment
      # ============================================================================

      test "FR-1: increments WorkflowExecution.attempt after retry" do
        @execution.update!(attempt: 1)

        task = create(:task, workflow_execution: @execution, position: 1,
                             status: :failed)
        score_report = create(:artifact,
                              workflow_execution: @execution,
                              artifact_type: :score_report,
                              content: "## Score\n85/100\n\n## Feedback\nMissing tests",
                              metadata: { score: 85 })

        result = RetryWithContext.call(execution: @execution, score_report: score_report)

        assert_equal 2, @execution.reload.attempt
      end

      test "FR-1: increments attempt from 0 to 1 on first retry" do
        @execution.update!(attempt: 0)

        task = create(:task, workflow_execution: @execution, position: 1,
                             status: :failed)
        score_report = create(:artifact,
                              workflow_execution: @execution,
                              artifact_type: :score_report,
                              content: "## Score\n85/100\n\n## Feedback\nMissing tests",
                              metadata: { score: 85 })

        result = RetryWithContext.call(execution: @execution, score_report: score_report)

        assert_equal 1, @execution.reload.attempt
      end

      test "FR-1: does not increment attempt when precondition fails" do
        @execution.update!(attempt: 4) # Beyond MAX_ATTEMPTS — triggers precondition error

        task = create(:task, workflow_execution: @execution, position: 1,
                             status: :failed)
        score_report = create(:artifact,
                              workflow_execution: @execution,
                              artifact_type: :score_report,
                              content: "## Score\n85/100\n\n## Feedback\nMissing tests",
                              metadata: { score: 85 })

        assert_raises do
          RetryWithContext.call(execution: @execution, score_report: score_report)
        end

        assert_equal 4, @execution.reload.attempt
      end

      # ============================================================================
      # FR-5: Task retry limit enforcement and permanent failure marking
      # ============================================================================

      test "FR-5: marks task as permanently failed when retry_count >= task_retry_limit" do
        @execution.update!(attempt: 1, task_retry_limit: 3)

        task = create(:task, workflow_execution: @execution, position: 1,
                             status: :failed, retry_count: 3)

        score_report = create(:artifact,
                              workflow_execution: @execution,
                              artifact_type: :score_report,
                              content: "## Score\n85/100\n\n## Feedback\nMissing tests",
                              metadata: { score: 85 })

        result = RetryWithContext.call(execution: @execution, score_report: score_report)

        # Task should be marked as permanently failed
        assert_equal "failed", task.reload.status
        assert task.metadata["permanently_failed"]
      end

      test "FR-5: does not reset task that has exceeded retry limit" do
        @execution.update!(attempt: 1, task_retry_limit: 3)

        task = create(:task, workflow_execution: @execution, position: 1,
                             status: :failed, retry_count: 3)

        score_report = create(:artifact,
                              workflow_execution: @execution,
                              artifact_type: :score_report,
                              content: "## Score\n85/100\n\n## Feedback\nMissing tests",
                              metadata: { score: 85 })

        result = RetryWithContext.call(execution: @execution, score_report: score_report)

        # Task should not be reset to pending
        assert_equal "failed", task.reload.status
        assert_equal 3, task.reload.retry_count
      end

      test "FR-5: resets task that is below retry limit" do
        @execution.update!(attempt: 1, task_retry_limit: 3)

        task = create(:task, workflow_execution: @execution, position: 1,
                             status: :failed, retry_count: 2)

        score_report = create(:artifact,
                              workflow_execution: @execution,
                              artifact_type: :score_report,
                              content: "## Score\n85/100\n\n## Feedback\nMissing tests",
                              metadata: { score: 85 })

        result = RetryWithContext.call(execution: @execution, score_report: score_report)

        # Task should be reset (retry_count 2 < limit 3); may be pending or ready depending on deps
        assert_includes %w[pending ready], task.reload.status, "Expected task to be reset"
        assert_equal 3, task.reload.retry_count
      end

      test "FR-5: handles mixed tasks - some at limit, some below" do
        @execution.update!(attempt: 1, task_retry_limit: 3)

        task1 = create(:task, workflow_execution: @execution, position: 1,
                             status: :failed, retry_count: 3) # At limit
        task2 = create(:task, workflow_execution: @execution, position: 2,
                             status: :failed, retry_count: 1) # Below limit

        score_report = create(:artifact,
                              workflow_execution: @execution,
                              artifact_type: :score_report,
                              content: "## Score\n85/100\n\n## Feedback\nMissing tests",
                              metadata: { score: 85 })

        result = RetryWithContext.call(execution: @execution, score_report: score_report)

        # task1 should be permanently failed
        assert_equal "failed", task1.reload.status
        assert task1.metadata["permanently_failed"]
        # task2 should be reset (may be pending or ready depending on deps)
        assert_includes %w[pending ready], task2.reload.status, "Expected task2 to be reset"
        assert_equal 2, task2.reload.retry_count
      end

      # ============================================================================
      # FR-7: RetryContextBuilder integration
      # ============================================================================

      test "FR-7: accumulated context includes prior retry_context and review_feedback" do
        # Attempt 1
        @execution.update!(attempt: 1)
        task1 = create(:task, workflow_execution: @execution, position: 1,
                             status: :failed)
        score_report1 = create(:artifact,
                               workflow_execution: @execution,
                               artifact_type: :score_report,
                               content: "## Score\n85/100\n\n## Feedback\nFirst attempt issues",
                               metadata: { score: 85 })
        RetryWithContext.call(execution: @execution, score_report: score_report1)

        # Attempt 2
        @execution.update!(attempt: 2)
        task2 = create(:task, workflow_execution: @execution, position: 1,
                             status: :failed)
        score_report2 = create(:artifact,
                               workflow_execution: @execution,
                               artifact_type: :score_report,
                               content: "## Score\n87/100\n\n## Feedback\nSecond attempt issues",
                               metadata: { score: 87 })

        result = RetryWithContext.call(execution: @execution, score_report: score_report2)

        # The most-recent retry_context (attempt 2) should include both attempts' feedback
        retry_context = Artifact.retry_contexts.where(workflow_execution: @execution).last
        assert retry_context, "Expected a retry_context artifact to exist"
        assert retry_context.content.include?("First attempt issues"),
               "Expected accumulated context to include attempt 1 feedback"
        assert retry_context.content.include?("Second attempt issues"),
               "Expected accumulated context to include attempt 2 (current) feedback"
      end

      # ============================================================================
      # NF-3: Deterministic task selection
      # ============================================================================

      test "NF-3: task selection is deterministic given same QA feedback" do
        @execution.update!(attempt: 1)

        task1 = create(:task, workflow_execution: @execution, position: 1,
                             status: :failed)
        task2 = create(:task, workflow_execution: @execution, position: 2,
                             status: :failed)

        score_report = create(:artifact,
                              workflow_execution: @execution,
                              artifact_type: :score_report,
                              content: "## Score\n85/100\n\n## Feedback\nIssues in app/models/user.rb",
                              metadata: { score: 85 })

        # Run twice with same feedback
        result1 = RetryWithContext.call(execution: @execution, score_report: score_report)
        task1_status_1 = task1.reload.status

        # Reset for second run
        task1.update!(status: :failed, retry_count: 0)
        task2.update!(status: :failed, retry_count: 0)

        result2 = RetryWithContext.call(execution: @execution, score_report: score_report)
        task1_status_2 = task1.reload.status

        # Results should be the same
        assert_equal task1_status_1, task1_status_2
      end

      # ============================================================================
      # Error scenarios
      # ============================================================================

      test "handles score_report without metadata gracefully" do
        @execution.update!(attempt: 1)

        task = create(:task, workflow_execution: @execution, position: 1,
                             status: :failed)
        score_report = create(:artifact,
                              workflow_execution: @execution,
                              artifact_type: :score_report,
                              content: "## Score\n85/100\n\n## Feedback\nMissing tests",
                              metadata: {})

        # Should handle gracefully
        assert_nothing_raised do
          RetryWithContext.call(execution: @execution, score_report: score_report)
        end
      end

      test "handles score_report with missing score gracefully" do
        @execution.update!(attempt: 1)

        task = create(:task, workflow_execution: @execution, position: 1,
                             status: :failed)
        score_report = create(:artifact,
                              workflow_execution: @execution,
                              artifact_type: :score_report,
                              content: "## Score\n85/100\n\n## Feedback\nMissing tests",
                              metadata: { other_field: "value" })

        # Should handle gracefully
        assert_nothing_raised do
          RetryWithContext.call(execution: @execution, score_report: score_report)
        end
      end

      test "raises error when score_report not found" do
        @execution.update!(attempt: 1)

        assert_raises do
          RetryWithContext.call(execution: @execution, score_report: nil)
        end
      end

      test "raises error when execution not found" do
        score_report = create(:artifact,
                              artifact_type: :score_report,
                              content: "## Score\n85/100\n\n## Feedback\nMissing tests",
                              metadata: { score: 85 })

        assert_raises do
          RetryWithContext.call(execution: nil, score_report: score_report)
        end
      end
    end
  end
end
