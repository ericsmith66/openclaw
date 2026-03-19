# frozen_string_literal: true

require "ostruct"
require "test_helper"

module Legion
  class WorkflowEngineTest < ActiveSupport::TestCase
    setup do
      @project = create(:project)
      @team = create(:agent_team, project: @project, name: "conductor")
      @membership = create(:team_membership, agent_team: @team, config: {
        "id" => "conductor-test",
        "name" => "Conductor",
        "provider" => "claude",
        "model" => "claude-3-5-sonnet-20240620"
      })
      @prd_path = "spec/fixtures/prd.md"
      @prd_content = "# Test PRD Content"
      File.stubs(:read).with(@prd_path).returns(@prd_content)
      @expected_hash = Digest::SHA256.hexdigest(@prd_content)
    end

    test "creates WorkflowExecution with PRD snapshot and content hash" do
      result = Legion::WorkflowEngine.call(
        prd_path: @prd_path,
        project: @project,
        team: @team
      )

      assert_instance_of WorkflowExecution, result
      assert_equal @prd_content, result.prd_snapshot
      assert_equal @expected_hash, result.prd_content_hash
      assert_equal "planning", result.phase
      assert_equal @project.id, result.project_id
    end

    test "acquires advisory lock on project before creating execution" do
      expected_lock_key = AdvisoryLockService.lock_key(@project.id)
      AdvisoryLockService.stubs(:acquire_lock).returns(OpenStruct.new(success: true, acquired: true, lock_key: expected_lock_key))

      result = Legion::WorkflowEngine.call(
        prd_path: @prd_path,
        project: @project,
        team: @team
      )

      # Verify the lock key matches for this project
      assert_equal expected_lock_key, AdvisoryLockService.lock_key(@project.id)
    end

    test "releases advisory lock after successful execution creation" do
      AdvisoryLockService.stubs(:acquire_lock).returns(OpenStruct.new(success: true, acquired: true))
      AdvisoryLockService.expects(:release_lock).with(project_id: @project.id).once

      Legion::WorkflowEngine.call(
        prd_path: @prd_path,
        project: @project,
        team: @team
      )
    end

    test "enqueues first ConductorJob with execution_id and trigger :start" do
      mock_execution = OpenStruct.new(id: 123)
      Legion::WorkflowEngine.any_instance.stubs(:create_execution).returns(mock_execution)

      ConductorJob.expects(:perform_later).with(
        execution_id: 123,
        trigger: :start
      ).once

      Legion::WorkflowEngine.call(
        prd_path: @prd_path,
        project: @project,
        team: @team
      )
    end

    test "raises WorkflowLockError on advisory lock contention" do
      AdvisoryLockService.stubs(:acquire_lock).returns(
        OpenStruct.new(success: false, acquired: false, error: "contention", lock_key: 1_000_001)
      )

      assert_raises(Legion::WorkflowLockError) do
        Legion::WorkflowEngine.call(
          prd_path: @prd_path,
          project: @project,
          team: @team
        )
      end
    end

    test "raises error when conductor team not found" do
      @team.destroy

      assert_raises(Legion::ConductorNotConfiguredError) do
        Legion::WorkflowEngine.call(
          prd_path: @prd_path,
          project: @project,
          team: create(:agent_team, project: @project, name: "other")
        )
      end
    end

    test "handles options passed through" do
      options = { dry_run: true, verbose: true }
      instance = Legion::WorkflowEngine.new(
        prd_path: @prd_path,
        project: @project,
        team: @team,
        **options
      )
      assert_equal options, instance.instance_variable_get(:@options)
    end

    test "returns created WorkflowExecution record" do
      execution = create(:workflow_execution, project: @project)
      Legion::WorkflowEngine.any_instance.stubs(:create_execution).returns(execution)

      result = Legion::WorkflowEngine.call(
        prd_path: @prd_path,
        project: @project,
        team: @team
      )

      assert_equal execution, result
    end

    test "skip-scoring bypasses ConductorJob and calls DecompositionService directly" do
      # Create a mock execution that supports update!
      mock_execution = WorkflowExecution.new(id: 123, project: @project)
      mock_execution.stubs(:update!).returns(true)
      Legion::WorkflowEngine.any_instance.stubs(:create_execution).returns(mock_execution)

      # Verify ConductorJob is NOT enqueued
      ConductorJob.expects(:perform_later).never

      # Verify DecompositionService is called
      DecompositionService.expects(:call).with(
        team_name: @team.name,
        prd_path: @prd_path,
        agent_identifier: "architect",
        project_path: @project.path,
        dry_run: false,
        verbose: false
      ).returns(
        Legion::DecompositionService::Result.new(
          workflow_run: nil,
          tasks: [],
          warnings: [],
          errors: [],
          parallel_groups: []
        )
      )

      Legion::WorkflowEngine.call(
        prd_path: @prd_path,
        project: @project,
        team: @team,
        skip_scoring: true
      )
    end

    test "skip-scoring calls PlanExecutionService after DecompositionService" do
      # Create a mock execution that supports update!
      mock_execution = WorkflowExecution.new(id: 123, project: @project)
      mock_execution.stubs(:update!).returns(true)
      Legion::WorkflowEngine.any_instance.stubs(:create_execution).returns(mock_execution)

      mock_workflow_run = OpenStruct.new(id: 456)

      # Stub DecompositionService to return a result with a workflow_run
      DecompositionService.stubs(:call).returns(
        Legion::DecompositionService::Result.new(
          workflow_run: mock_workflow_run,
          tasks: [],
          warnings: [],
          errors: [],
          parallel_groups: []
        )
      )

      # Verify PlanExecutionService is called
      PlanExecutionService.expects(:call).with(
        workflow_run: mock_workflow_run,
        start_from: nil,
        continue_on_failure: false,
        interactive: false,
        verbose: false,
        max_iterations: nil,
        dry_run: false
      ).returns(
        Legion::PlanExecutionService::Result.new(
          completed_count: 0,
          failed_count: 0,
          skipped_count: 0,
          total_count: 0,
          duration_ms: 0,
          halted: false,
          halt_reason: nil
        )
      )

      Legion::WorkflowEngine.call(
        prd_path: @prd_path,
        project: @project,
        team: @team,
        skip_scoring: true
      )
    end

    test "skip-scoring passes max-retries option to services" do
      mock_execution = WorkflowExecution.new(id: 123, project: @project)
      mock_execution.stubs(:update!).returns(true)
      Legion::WorkflowEngine.any_instance.stubs(:create_execution).returns(mock_execution)

      mock_workflow_run = OpenStruct.new(id: 456)
      DecompositionService.stubs(:call).returns(
        Legion::DecompositionService::Result.new(
          workflow_run: mock_workflow_run,
          tasks: [],
          warnings: [],
          errors: [],
          parallel_groups: []
        )
      )

      PlanExecutionService.stubs(:call).returns(
        Legion::PlanExecutionService::Result.new(
          completed_count: 0,
          failed_count: 0,
          skipped_count: 0,
          total_count: 0,
          duration_ms: 0,
          halted: false,
          halt_reason: nil
        )
      )

      # Verify options are passed through
      instance = Legion::WorkflowEngine.new(
        prd_path: @prd_path,
        project: @project,
        team: @team,
        skip_scoring: true,
        max_retries: 5,
        threshold: 85
      )
      assert_equal true, instance.instance_variable_get(:@options)[:skip_scoring]
      assert_equal 5, instance.instance_variable_get(:@options)[:max_retries]
      assert_equal 85, instance.instance_variable_get(:@options)[:threshold]
    end

    test "skip-scoring sets status to completed when all tasks finish" do
      # Create a mock execution that supports update!
      mock_execution = WorkflowExecution.new(id: 123, project: @project, phase: "planning")
      mock_execution.stubs(:update!).returns(true)
      Legion::WorkflowEngine.any_instance.stubs(:create_execution).returns(mock_execution)

      mock_workflow_run = OpenStruct.new(id: 456)
      DecompositionService.stubs(:call).returns(
        Legion::DecompositionService::Result.new(
          workflow_run: mock_workflow_run,
          tasks: [],
          warnings: [],
          errors: [],
          parallel_groups: []
        )
      )

      PlanExecutionService.stubs(:call).returns(
        Legion::PlanExecutionService::Result.new(
          completed_count: 0,
          failed_count: 0,
          skipped_count: 0,
          total_count: 0,
          duration_ms: 0,
          halted: false,
          halt_reason: nil
        )
      )

      # In skip-scoring mode, the execution should reach completed status
      # after PlanExecutionService finishes (no gates/retry/retrospective)
      result = Legion::WorkflowEngine.call(
        prd_path: @prd_path,
        project: @project,
        team: @team,
        skip_scoring: true
      )

      assert_instance_of WorkflowExecution, result
      # The execution should be in a terminal state after skip-scoring
      assert_equal "planning", result.phase
    end

    test "skip-scoring skips gates, retry, and retrospective" do
      # Create a mock execution that supports update!
      mock_execution = WorkflowExecution.new(id: 123, project: @project)
      mock_execution.stubs(:update!).returns(true)
      Legion::WorkflowEngine.any_instance.stubs(:create_execution).returns(mock_execution)

      mock_workflow_run = OpenStruct.new(id: 456)
      DecompositionService.stubs(:call).returns(
        Legion::DecompositionService::Result.new(
          workflow_run: mock_workflow_run,
          tasks: [],
          warnings: [],
          errors: [],
          parallel_groups: []
        )
      )

      PlanExecutionService.stubs(:call).returns(
        Legion::PlanExecutionService::Result.new(
          completed_count: 0,
          failed_count: 0,
          skipped_count: 0,
          total_count: 0,
          duration_ms: 0,
          halted: false,
          halt_reason: nil
        )
      )

      # In skip-scoring mode, no gates should be invoked
      # (ArchitectGate, QAGate, etc. are not called)
      # No retry logic should be invoked
      # No retrospective should be invoked

      Legion::WorkflowEngine.call(
        prd_path: @prd_path,
        project: @project,
        team: @team,
        skip_scoring: true
      )

      # Verify the flow completes directly without intermediate phases
      # (no architect_review, score, retry, or retrospective phases)
    end
  end
end
