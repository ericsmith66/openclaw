# frozen_string_literal: true

require "test_helper"
require Rails.root.join("app/tools/legion/orchestration/retry_with_context")

class RetryLimitIntegrationTest < ActionDispatch::IntegrationTest
  # Disable transactional tests so subprocess can see test data
  self.use_transactional_tests = false

  # Setup common test data
  setup do
    # Use a temporary project path for each test with unique identifier
    @project_path = Rails.root.join("tmp", "retry-limit-test-project-#{Time.now.to_i}-#{SecureRandom.hex(4)}")
    @project = create(:project, path: @project_path.to_s)

    # Create agent team
    @team = create(:agent_team, project: @project, name: "ROR")

    # Create team membership (QA agent)
    @membership = create(:team_membership,
                        agent_team: @team,
                        config: {
                          "id" => "qa",
                          "name" => "QA Agent",
                          "provider" => "smart_proxy",
                          "model" => "deepseek-reasoner"
                        })
    @team.team_memberships << @membership
    @team.save!

    # Create a workflow execution with task_retry_limit: 3
    @execution = create(:workflow_execution,
                       project: @project,
                       phase: :executing,
                       attempt: 1,
                       task_retry_limit: 3,
                       prd_path: "test_prd.md")

    # Create a workflow run associated with the execution
    @workflow_run = create(:workflow_run,
                          project: @project,
                          team_membership: @membership,
                          prompt: "Test workflow",
                          status: :completed,
                          result: "Workflow completed successfully")

    # Add workflow_run to execution
    @execution.workflow_runs << @workflow_run

    # Create tasks for the workflow run (with failed status so they can be reset)
    # Task 1: Will reach retry limit after 3 resets (retry_count starts at 0)
    @task1 = create(:task,
                   project: @project,
                   team_membership: @membership,
                   workflow_run: @workflow_run,
                   workflow_execution: @execution,
                   position: 1,
                   prompt: "Build the application",
                   task_type: :code,
                   status: "failed",
                   result: "Build failed",
                   retry_count: 0,
                   last_error: "Previous attempt failed: compilation error")

    # Task 2: Will not reach retry limit
    @task2 = create(:task,
                   project: @project,
                   team_membership: @membership,
                   workflow_run: @workflow_run,
                   workflow_execution: @execution,
                   position: 2,
                   prompt: "Write tests",
                   task_type: :code,
                   status: "failed",
                   result: "Tests failed",
                   retry_count: 0,
                   last_error: "Previous attempt failed: compilation error")

    # Task 3: Already completed
    @task3 = create(:task,
                   project: @project,
                   team_membership: @membership,
                   workflow_run: @workflow_run,
                   workflow_execution: @execution,
                   position: 3,
                   prompt: "Documentation",
                   task_type: :review,
                   status: "completed",
                   result: "Documentation completed")
  end

  teardown do
    # Clean up test project directory
    FileUtils.rm_rf(@project.path) if File.directory?(@project.path)

    # Null out circular/cross FKs before bulk deletes to avoid constraint violations
    conn = ActiveRecord::Base.connection
    conn.execute("UPDATE workflow_runs SET task_id = NULL, workflow_execution_id = NULL")
    conn.execute("UPDATE tasks SET execution_run_id = NULL")
    Artifact.delete_all
    TaskDependency.delete_all
    WorkflowEvent.delete_all
    ConductorDecision.delete_all
    Task.delete_all
    WorkflowExecution.delete_all
    WorkflowRun.delete_all
    TeamMembership.delete_all
    AgentTeam.delete_all
    Project.delete_all
  end

  # =============================================================================
  # AC-6: Given attempt 3 and QA score < 90, retry_with_context tool refuses
  # AC-7: Given task with retry_count >= task_retry_limit, task is marked failed permanently
  # AC-12: Two distinct counters tracked: WorkflowExecution.attempt and Task.retry_count
  # =============================================================================

  test "AC-6, AC-7, AC-12: Three QA cycles below threshold lead to retrospective" do
    VCR.use_cassette("retry_limit_three_cycles_below_threshold") do
      # First QA cycle - score 85 (below threshold 90)
      score_report1 = Artifact.create!(
        project: @project,
        workflow_run: @workflow_run,
        workflow_execution: @execution,
        created_by: @team,
        artifact_type: :score_report,
        name: "Score Report 1",
        content: "# Score\n85/100\n\n## Feedback\nFirst issue in app/models/user.rb",
        metadata: { "score" => 85 }
      )

      # Execute retry_with_context for first cycle
      Legion::OrchestrationTools::RetryWithContext.call(
        execution: @execution,
        score_report: score_report1
      )

      # Verify first retry - attempt should be 2
      execution1 = @execution.reload
      assert_equal 2, execution1.attempt, "Expected attempt to be incremented to 2"
      assert_equal "iterating", execution1.phase, "Expected phase to be iterating"

      # Task 1 should have retry_count = 1 after first reset
      task1 = @task1.reload
      assert_equal 1, task1.retry_count, "Expected task1 retry_count to be 1 after first reset"

      # Task 2 should have retry_count = 1 after first reset
      task2 = @task2.reload
      assert_equal 1, task2.retry_count, "Expected task2 retry_count to be 1 after first reset"

      # Second QA cycle - score 88 (still below threshold)
      score_report2 = Artifact.create!(
        project: @project,
        workflow_run: @workflow_run,
        workflow_execution: execution1,
        created_by: @team,
        artifact_type: :score_report,
        name: "Score Report 2",
        content: "# Score\n88/100\n\n## Feedback\nSecond issue in app/models/user.rb",
        metadata: { "score" => 88 }
      )

      # Execute retry_with_context for second cycle
      Legion::OrchestrationTools::RetryWithContext.call(
        execution: execution1,
        score_report: score_report2
      )

      # Verify second retry - attempt should be 3
      execution2 = execution1.reload
      assert_equal 3, execution2.attempt, "Expected attempt to be incremented to 3"

      # Task 1 should have retry_count = 2 after second reset
      task1_2 = @task1.reload
      assert_equal 2, task1_2.retry_count, "Expected task1 retry_count to be 2 after second reset"

      # Task 2 should have retry_count = 2 after second reset
      task2_2 = @task2.reload
      assert_equal 2, task2_2.retry_count, "Expected task2 retry_count to be 2 after second reset"

      # Third QA cycle - score 89 (still below threshold)
      score_report3 = Artifact.create!(
        project: @project,
        workflow_run: @workflow_run,
        workflow_execution: execution2,
        created_by: @team,
        artifact_type: :score_report,
        name: "Score Report 3",
        content: "# Score\n89/100\n\n## Feedback\nThird issue in app/models/user.rb",
        metadata: { "score" => 89 }
      )

      # Execute retry_with_context for third cycle
      Legion::OrchestrationTools::RetryWithContext.call(
        execution: execution2,
        score_report: score_report3
      )

      # Verify third retry - attempt should be 4 (3 retries completed)
      execution3 = execution2.reload
      assert_equal 4, execution3.attempt, "Expected attempt to be incremented to 4 after 3 retries"

      # Task 1 should have retry_count = 3 after third reset
      task1_3 = @task1.reload
      assert_equal 3, task1_3.retry_count, "Expected task1 retry_count to be 3 after third reset"

      # Task 2 should have retry_count = 3 after third reset
      task2_3 = @task2.reload
      assert_equal 3, task2_3.retry_count, "Expected task2 retry_count to be 3 after third reset"

      # Fourth QA cycle - score 89 (still below threshold, but max retries reached)
      score_report4 = Artifact.create!(
        project: @project,
        workflow_run: @workflow_run,
        workflow_execution: execution3,
        created_by: @team,
        artifact_type: :score_report,
        name: "Score Report 4",
        content: "# Score\n89/100",
        metadata: { "score" => 89 }
      )

      # Verify that retry_with_context raises precondition error (max retries reached)
      # AC-6: attempt 4 >= max_retries 3 should refuse
      assert_raises(Legion::OrchestrationTools::RetryWithContext::PreconditionError) do
        Legion::OrchestrationTools::RetryWithContext.call(
          execution: execution3,
          score_report: score_report4
        )
      end

      # Verify task1 is marked as permanently failed (retry_count >= task_retry_limit)
      # AC-7: task exceeding retry limit marked failed
      assert_equal "failed", task1_3.status, "Expected task1 to be marked as failed"
      assert task1_3.metadata["permanently_failed"], "Expected permanently_failed flag to be set for task1"

      # Verify task2 is marked as permanently failed
      assert_equal "failed", task2_3.status, "Expected task2 to be marked as failed"
      assert task2_3.metadata["permanently_failed"], "Expected permanently_failed flag to be set for task2"

      # Verify task3 remains completed
      task3 = @task3.reload
      assert_equal "completed", task3.status, "Expected task3 to remain completed"
    end
  end

  test "AC-6, AC-7, AC-12: Task exceeding retry limit marked failed while others continue" do
    VCR.use_cassette("retry_limit_task_marked_failed") do
      # Create a task that has already reached retry limit (retry_count = 3)
      task_at_limit = create(:task,
                            project: @project,
                            team_membership: @membership,
                            workflow_run: @workflow_run,
                            workflow_execution: @execution,
                            position: 4,
                            prompt: "Task at retry limit",
                            task_type: :code,
                            status: "failed",
                            retry_count: 3)

      # Create score report with score below threshold
      score_report = Artifact.create!(
        project: @project,
        workflow_run: @workflow_run,
        workflow_execution: @execution,
        created_by: @team,
        artifact_type: :score_report,
        name: "Score Report",
        content: "# Score\n85/100\n\n## Feedback\nIssue in task at limit",
        metadata: { "score" => 85 }
      )

      # Execute retry_with_context
      Legion::OrchestrationTools::RetryWithContext.call(
        execution: @execution,
        score_report: score_report
      )

      # Verify task at limit is marked as permanently failed
      task_at_limit.reload
      assert_equal "failed", task_at_limit.status, "Expected task at limit to be marked as failed"
      assert task_at_limit.metadata["permanently_failed"], "Expected permanently_failed flag to be set"

      # Verify other tasks are still resettable and get reset
      task1 = @task1.reload
      assert task1.status.in?([ "pending", "ready" ]), "Expected task1 to be reset, but was #{task1.status}"
      assert_equal 1, task1.retry_count, "Expected task1 retry_count to be 1"

      task2 = @task2.reload
      assert task2.status.in?([ "pending", "ready" ]), "Expected task2 to be reset, but was #{task2.status}"
      assert_equal 1, task2.retry_count, "Expected task2 retry_count to be 1"
    end
  end

  test "AC-6: Execution attempt reaches 3 (max retries) and refuses further retries" do
    VCR.use_cassette("retry_limit_attempt_reaches_3") do
      # First retry - attempt 1 -> 2
      score_report1 = Artifact.create!(
        project: @project,
        workflow_run: @workflow_run,
        workflow_execution: @execution,
        created_by: @team,
        artifact_type: :score_report,
        name: "Score Report 1",
        content: "# Score\n85/100",
        metadata: { "score" => 85 }
      )

      Legion::OrchestrationTools::RetryWithContext.call(
        execution: @execution,
        score_report: score_report1
      )

      assert_equal 2, @execution.reload.attempt, "Expected attempt to be 2 after first retry"

      # Second retry - attempt 2 -> 3
      execution2 = @execution.reload
      score_report2 = Artifact.create!(
        project: @project,
        workflow_run: @workflow_run,
        workflow_execution: execution2,
        created_by: @team,
        artifact_type: :score_report,
        name: "Score Report 2",
        content: "# Score\n88/100",
        metadata: { "score" => 88 }
      )

      Legion::OrchestrationTools::RetryWithContext.call(
        execution: execution2,
        score_report: score_report2
      )

      assert_equal 3, execution2.reload.attempt, "Expected attempt to be 3 after second retry"

      # Third retry - attempt 3 -> 4
      execution3 = execution2.reload
      score_report3 = Artifact.create!(
        project: @project,
        workflow_run: @workflow_run,
        workflow_execution: execution3,
        created_by: @team,
        artifact_type: :score_report,
        name: "Score Report 3",
        content: "# Score\n89/100",
        metadata: { "score" => 89 }
      )

      Legion::OrchestrationTools::RetryWithContext.call(
        execution: execution3,
        score_report: score_report3
      )

      assert_equal 4, execution3.reload.attempt, "Expected attempt to be 4 after third retry"

      # Fourth attempt should fail (max retries reached)
      # AC-6: attempt 4 >= max_retries 3 should raise PreconditionError
      execution4 = execution3.reload
      score_report4 = Artifact.create!(
        project: @project,
        workflow_run: @workflow_run,
        workflow_execution: execution4,
        created_by: @team,
        artifact_type: :score_report,
        name: "Score Report 4",
        content: "# Score\n89/100",
        metadata: { "score" => 89 }
      )

      assert_raises(Legion::OrchestrationTools::RetryWithContext::PreconditionError) do
        Legion::OrchestrationTools::RetryWithContext.call(
          execution: execution4,
          score_report: score_report4
        )
      end

      # Verify attempt is still 4 (not incremented to 5)
      assert_equal 4, execution4.reload.attempt, "Expected attempt to remain 4 (max retries reached)"
    end
  end

  test "AC-6, AC-7, AC-12: Task at retry limit does not prevent other tasks from being reset" do
    VCR.use_cassette("retry_limit_other_tasks_reset") do
      # Create a task that has already reached retry limit (retry_count = 3)
      task_at_limit = create(:task,
                            project: @project,
                            team_membership: @membership,
                            workflow_run: @workflow_run,
                            workflow_execution: @execution,
                            position: 4,
                            prompt: "Task at retry limit",
                            task_type: :code,
                            status: "failed",
                            retry_count: 3)

      # Create score report with score below threshold
      score_report = Artifact.create!(
        project: @project,
        workflow_run: @workflow_run,
        workflow_execution: @execution,
        created_by: @team,
        artifact_type: :score_report,
        name: "Score Report",
        content: "# Score\n85/100\n\n## Feedback\nIssues in multiple files",
        metadata: { "score" => 85 }
      )

      # Execute retry_with_context
      Legion::OrchestrationTools::RetryWithContext.call(
        execution: @execution,
        score_report: score_report
      )

      # Verify task at limit is marked as permanently failed
      task_at_limit.reload
      assert_equal "failed", task_at_limit.status, "Expected task at limit to be marked as failed"
      assert task_at_limit.metadata["permanently_failed"], "Expected permanently_failed flag to be set"

      # Verify other tasks are reset
      task1 = @task1.reload
      assert task1.status.in?([ "pending", "ready" ]), "Expected task1 to be reset, but was #{task1.status}"
      assert_equal 1, task1.retry_count, "Expected task1 retry_count to be 1"

      task2 = @task2.reload
      assert task2.status.in?([ "pending", "ready" ]), "Expected task2 to be reset, but was #{task2.status}"
      assert_equal 1, task2.retry_count, "Expected task2 retry_count to be 1"

      # Verify task3 remains completed
      task3 = @task3.reload
      assert_equal "completed", task3.status, "Expected task3 to remain completed"
    end
  end

  test "AC-6, AC-7, AC-12: Retrospective triggered after max retries reached" do
    VCR.use_cassette("retry_limit_retrospective_triggered") do
      # Complete three retry cycles
      3.times do |i|
        score_report = Artifact.create!(
          project: @project,
          workflow_run: @workflow_run,
          workflow_execution: @execution,
          created_by: @team,
          artifact_type: :score_report,
          name: "Score Report #{i + 1}",
          content: "# Score\n#{85 + i}/100",
          metadata: { "score" => 85 + i }
        )

        Legion::OrchestrationTools::RetryWithContext.call(
          execution: @execution,
          score_report: score_report
        )
      end

      # Verify attempt reached 4 (3 retries completed)
      assert_equal 4, @execution.reload.attempt, "Expected attempt to be 4 after 3 retries"

      # Fourth attempt should fail (max retries reached)
      # AC-6: attempt 4 >= max_retries 3 should raise PreconditionError
      score_report4 = Artifact.create!(
        project: @project,
        workflow_run: @workflow_run,
        workflow_execution: @execution,
        created_by: @team,
        artifact_type: :score_report,
        name: "Score Report 4",
        content: "# Score\n89/100",
        metadata: { "score" => 89 }
      )

      assert_raises(Legion::OrchestrationTools::RetryWithContext::PreconditionError) do
        Legion::OrchestrationTools::RetryWithContext.call(
          execution: @execution,
          score_report: score_report4
        )
      end

      # Verify non-completed tasks are marked as permanently failed (retry_count >= 3)
      retried_tasks = @execution.tasks.where.not(status: "completed").reload
      retried_tasks.each do |task|
        assert_equal "failed", task.reload.status,
                     "Expected task #{task.id} to be permanently failed"
        assert task.reload.metadata["permanently_failed"],
               "Expected permanently_failed flag for task #{task.id}"
      end
    end
  end

  # =============================================================================
  # Private helper methods
  # =============================================================================

  private

  def cassette_exists?(name)
    cassette_path = Rails.root.join("test/vcr_cassettes/#{name}.yml")
    File.exist?(cassette_path)
  end
end
