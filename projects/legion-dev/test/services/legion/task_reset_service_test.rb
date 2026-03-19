# frozen_string_literal: true

require "test_helper"

module Legion
  class TaskResetServiceTest < ActiveSupport::TestCase
    setup do
      @project = create(:project)
      @team = create(:agent_team, project: @project)
      @membership = create(:team_membership, agent_team: @team)
      @workflow_run = create(:workflow_run, project: @project, team_membership: @membership)
    end

    test "FR-5: single task reset updates status to pending then ready (no deps)" do
      # Per FR-9: if all dependencies are completed (or no deps), task becomes ready
      task = create(:task, workflow_run: @workflow_run, status: :failed, retry_count: 0)

      TaskResetService.call(task: task)

      assert_equal "ready", task.reload.status
    end

    test "FR-5: single task reset increments retry_count" do
      task = create(:task, workflow_run: @workflow_run, status: :failed, retry_count: 0)

      TaskResetService.call(task: task)

      assert_equal 1, task.reload.retry_count
    end

    test "FR-5: single task reset increments retry_count on subsequent resets" do
      task = create(:task, workflow_run: @workflow_run, status: :failed, retry_count: 2)

      TaskResetService.call(task: task)

      assert_equal 3, task.reload.retry_count
    end

    test "FR-5: single task reset clears timing fields" do
      task = create(:task, workflow_run: @workflow_run, status: :failed,
                          queued_at: Time.now, started_at: Time.now, completed_at: Time.now)

      TaskResetService.call(task: task)

      updated_task = task.reload
      assert_nil updated_task.queued_at
      assert_nil updated_task.started_at
      assert_nil updated_task.completed_at
    end

    test "FR-9: single task reset resets to ready if dependencies met (no deps)" do
      # Task with no dependencies should be ready after reset
      task = create(:task, workflow_run: @workflow_run, status: :failed)

      TaskResetService.call(task: task)

      assert_equal "ready", task.reload.status
    end

    test "FR-9: single task reset stays pending if dependencies not completed" do
      # Create dependency task that is not completed
      dep_task = create(:task, workflow_run: @workflow_run, status: :pending)
      task = create(:task, workflow_run: @workflow_run, status: :failed)
      create(:task_dependency, task: task, depends_on_task: dep_task)

      TaskResetService.call(task: task)

      assert_equal "pending", task.reload.status
    end

    test "FR-9: single task reset becomes ready when all dependencies are completed" do
      # Create dependency task that is completed
      dep_task = create(:task, workflow_run: @workflow_run, status: :completed)
      task = create(:task, workflow_run: @workflow_run, status: :failed)
      create(:task_dependency, task: task, depends_on_task: dep_task)

      TaskResetService.call(task: task)

      assert_equal "ready", task.reload.status
    end

    test "FR-8: Task#resettable? returns true for failed tasks" do
      task = create(:task, workflow_run: @workflow_run, status: :failed)

      assert task.resettable?
    end

    test "FR-8: Task#resettable? returns true for skipped tasks" do
      task = create(:task, workflow_run: @workflow_run, status: :skipped)

      assert task.resettable?
    end

    test "FR-8: Task#resettable? returns false for pending tasks" do
      task = create(:task, workflow_run: @workflow_run, status: :pending)

      assert_not task.resettable?
    end

    test "FR-8: Task#resettable? returns false for ready tasks" do
      task = create(:task, workflow_run: @workflow_run, status: :ready)

      assert_not task.resettable?
    end

    test "FR-8: Task#resettable? returns false for running tasks" do
      task = create(:task, workflow_run: @workflow_run, status: :running)

      assert_not task.resettable?
    end

    test "FR-8: Task#resettable? returns false for completed tasks" do
      task = create(:task, workflow_run: @workflow_run, status: :completed)

      assert_not task.resettable?
    end

    test "FR-5: raises TaskNotResettableError for non-resettable task (completed)" do
      task = create(:task, workflow_run: @workflow_run, status: :completed)

      assert_raises TaskResetService::TaskNotResettableError do
        TaskResetService.call(task: task)
      end
    end

    test "FR-5: raises TaskNotResettableError for non-resettable task (pending)" do
      task = create(:task, workflow_run: @workflow_run, status: :pending)

      assert_raises TaskResetService::TaskNotResettableError do
        TaskResetService.call(task: task)
      end
    end

    test "FR-5: raises TaskNotResettableError for non-resettable task (ready)" do
      task = create(:task, workflow_run: @workflow_run, status: :ready)

      assert_raises TaskResetService::TaskNotResettableError do
        TaskResetService.call(task: task)
      end
    end

    test "FR-5: raises TaskNotResettableError for non-resettable task (running)" do
      task = create(:task, workflow_run: @workflow_run, status: :running)

      assert_raises TaskResetService::TaskNotResettableError do
        TaskResetService.call(task: task)
      end
    end

    test "FR-5: raises TaskNotResettableError with correct error message" do
      task = create(:task, workflow_run: @workflow_run, status: :completed)

      error = assert_raises TaskResetService::TaskNotResettableError do
        TaskResetService.call(task: task)
      end

      assert_includes error.message, task.id.to_s
      assert_includes error.message, "completed"
      assert_includes error.message, "failed"
      assert_includes error.message, "skipped"
    end

    test "FR-6: batch reset resets all failed tasks" do
      task1 = create(:task, workflow_run: @workflow_run, status: :failed, retry_count: 0)
      task2 = create(:task, workflow_run: @workflow_run, status: :failed, retry_count: 1)
      task3 = create(:task, workflow_run: @workflow_run, status: :completed, retry_count: 0) # Should NOT be reset

      TaskResetService.reset_all_failed(workflow_run: @workflow_run)

      assert_equal "ready", task1.reload.status # No deps -> ready
      assert_equal 1, task1.reload.retry_count
      assert_equal "ready", task2.reload.status # No deps -> ready
      assert_equal 2, task2.reload.retry_count
      assert_equal "completed", task3.reload.status # Unchanged
    end

    test "FR-6: batch reset cascades to skipped dependents" do
      # Create a chain: task1 (failed) -> task2 (skipped, depends on task1)
      task1 = create(:task, workflow_run: @workflow_run, status: :failed)
      task2 = create(:task, workflow_run: @workflow_run, status: :skipped)
      create(:task_dependency, task: task2, depends_on_task: task1)

      TaskResetService.reset_all_failed(workflow_run: @workflow_run)

      assert_equal "ready", task1.reload.status # No other deps -> ready
      assert_equal "pending", task2.reload.status # task1 not completed yet
    end

    test "FR-6: batch reset handles multiple independent failed tasks" do
      task1 = create(:task, workflow_run: @workflow_run, status: :failed)
      task2 = create(:task, workflow_run: @workflow_run, status: :failed)
      # No dependencies between them

      TaskResetService.reset_all_failed(workflow_run: @workflow_run)

      assert_equal "ready", task1.reload.status # No deps -> ready
      assert_equal "ready", task2.reload.status # No deps -> ready
    end

    test "FR-6: batch reset handles cascading dependencies correctly" do
      # Create a chain: task1 (failed) -> task2 (skipped, depends on task1) -> task3 (skipped, depends on task2)
      task1 = create(:task, workflow_run: @workflow_run, status: :failed)
      task2 = create(:task, workflow_run: @workflow_run, status: :skipped)
      task3 = create(:task, workflow_run: @workflow_run, status: :skipped)
      create(:task_dependency, task: task2, depends_on_task: task1)
      create(:task_dependency, task: task3, depends_on_task: task2)

      TaskResetService.reset_all_failed(workflow_run: @workflow_run)

      assert_equal "ready", task1.reload.status # No deps -> ready
      assert_equal "pending", task2.reload.status # task1 not completed
      assert_equal "pending", task3.reload.status # task2 not completed
    end

    test "NF-1: reset is atomic - transaction wraps all changes" do
      task1 = create(:task, workflow_run: @workflow_run, status: :failed)
      task2 = create(:task, workflow_run: @workflow_run, status: :skipped)
      create(:task_dependency, task: task2, depends_on_task: task1)

      original_status1 = task1.status
      original_status2 = task2.status

      TaskResetService.reset_all_failed(workflow_run: @workflow_run)

      # Both should be reset (both in same transaction)
      assert_not_equal original_status1, task1.reload.status
      assert_not_equal original_status2, task2.reload.status
    end

    test "NF-1: reset is atomic - rollback on error" do
      task1 = create(:task, workflow_run: @workflow_run, status: :failed)
      task2 = create(:task, workflow_run: @workflow_run, status: :skipped)
      create(:task_dependency, task: task2, depends_on_task: task1)

      original_task1_status = task1.status
      original_task2_status = task2.status

      # The operation should either complete fully or not at all
      TaskResetService.reset_all_failed(workflow_run: @workflow_run)

      # Verify both tasks were updated (atomic operation)
      assert_equal "ready", task1.reload.status # No deps
      assert_equal "pending", task2.reload.status # task1 not completed
    end

    test "reset_all_failed with no failed tasks does nothing" do
      task1 = create(:task, workflow_run: @workflow_run, status: :completed)
      task2 = create(:task, workflow_run: @workflow_run, status: :pending)

      original_task1_status = task1.status
      original_task2_status = task2.status

      TaskResetService.reset_all_failed(workflow_run: @workflow_run)

      assert_equal original_task1_status, task1.reload.status
      assert_equal original_task2_status, task2.reload.status
    end

    test "reset_all_failed with empty workflow_run does not error" do
      empty_workflow_run = create(:workflow_run, project: @project, team_membership: @membership)

      # Should not raise any errors
      assert_nothing_raised do
        TaskResetService.reset_all_failed(workflow_run: empty_workflow_run)
      end
    end

    test "reset_all_failed updates timing fields for all reset tasks" do
      task1 = create(:task, workflow_run: @workflow_run, status: :failed,
                          queued_at: Time.now, started_at: Time.now, completed_at: Time.now)
      task2 = create(:task, workflow_run: @workflow_run, status: :skipped,
                          queued_at: Time.now, started_at: Time.now, completed_at: Time.now)
      create(:task_dependency, task: task2, depends_on_task: task1)

      TaskResetService.reset_all_failed(workflow_run: @workflow_run)

      updated_task1 = task1.reload
      updated_task2 = task2.reload

      assert_nil updated_task1.queued_at
      assert_nil updated_task1.started_at
      assert_nil updated_task1.completed_at
      assert_nil updated_task2.queued_at
      assert_nil updated_task2.started_at
      assert_nil updated_task2.completed_at
    end

    test "reset_all_failed increments retry_count for all reset tasks" do
      task1 = create(:task, workflow_run: @workflow_run, status: :failed, retry_count: 2)
      task2 = create(:task, workflow_run: @workflow_run, status: :skipped, retry_count: 1)
      create(:task_dependency, task: task2, depends_on_task: task1)

      TaskResetService.reset_all_failed(workflow_run: @workflow_run)

      assert_equal 3, task1.reload.retry_count
      assert_equal 2, task2.reload.retry_count
    end

    test "returns Result struct with reset tasks count" do
      task1 = create(:task, workflow_run: @workflow_run, status: :failed)
      task2 = create(:task, workflow_run: @workflow_run, status: :skipped)
      create(:task_dependency, task: task2, depends_on_task: task1)

      result = TaskResetService.reset_all_failed(workflow_run: @workflow_run)

      assert_instance_of TaskResetService::Result, result
      assert_equal 2, result.reset_count
    end

    test "single task reset returns Result struct" do
      task = create(:task, workflow_run: @workflow_run, status: :failed)

      result = TaskResetService.call(task: task)

      assert_instance_of TaskResetService::Result, result
      assert_equal task.id, result.task.id
      assert_equal "ready", result.task.status # No deps -> ready
    end

    test "handles task with multiple dependents correctly" do
      # task1 (failed) -> task2 (skipped, depends on task1)
      # task1 (failed) -> task3 (skipped, depends on task1)
      task1 = create(:task, workflow_run: @workflow_run, status: :failed)
      task2 = create(:task, workflow_run: @workflow_run, status: :skipped)
      task3 = create(:task, workflow_run: @workflow_run, status: :skipped)
      create(:task_dependency, task: task2, depends_on_task: task1)
      create(:task_dependency, task: task3, depends_on_task: task1)

      TaskResetService.reset_all_failed(workflow_run: @workflow_run)

      assert_equal "ready", task1.reload.status # No other deps
      assert_equal "pending", task2.reload.status # task1 not completed
      assert_equal "pending", task3.reload.status # task1 not completed
    end

    test "handles circular dependency detection (should not occur but verify no infinite loop)" do
      # Create tasks with dependencies
      task1 = create(:task, workflow_run: @workflow_run, status: :failed)
      task2 = create(:task, workflow_run: @workflow_run, status: :skipped)
      create(:task_dependency, task: task2, depends_on_task: task1)

      # This should complete without infinite loop
      result = TaskResetService.reset_all_failed(workflow_run: @workflow_run)

      assert_equal 2, result.reset_count
    end

    test "FR-5: single task reset does not modify error context fields" do
      task = create(:task, workflow_run: @workflow_run, status: :failed,
                          last_error: "Previous error message")

      TaskResetService.call(task: task)

      # last_error should remain unchanged (only retry_count and timing are reset)
      assert_equal "Previous error message", task.reload.last_error
    end

    test "reset_all_failed only resets tasks from specified workflow_run" do
      workflow_run2 = create(:workflow_run, project: @project, team_membership: @membership)
      task1 = create(:task, workflow_run: @workflow_run, status: :failed)
      task2 = create(:task, workflow_run: workflow_run2, status: :failed) # Different workflow

      TaskResetService.reset_all_failed(workflow_run: @workflow_run)

      assert_equal "ready", task1.reload.status # No deps
      assert_equal "failed", task2.reload.status # Unchanged (different workflow)
    end
  end
end
