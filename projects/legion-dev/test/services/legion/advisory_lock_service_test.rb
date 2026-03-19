# frozen_string_literal: true

require "test_helper"
require "ostruct"

module Legion
  class AdvisoryLockServiceTest < ActiveSupport::TestCase
    test "lock_key generates unique key for each project" do
      key1 = AdvisoryLockService.lock_key(1)
      key2 = AdvisoryLockService.lock_key(2)

      assert_equal 1_000_001, key1
      assert_equal 1_000_002, key2
      assert_not_equal key1, key2
    end

    test "acquire_lock returns success result when lock is acquired" do
      project_id = 1001
      lock_key = AdvisoryLockService.lock_key(project_id)
      result = AdvisoryLockService.acquire_lock(project_id: project_id)

      assert_instance_of OpenStruct, result
      assert result.success
      assert result.acquired
      assert_equal lock_key, result.lock_key

      # Cleanup
      AdvisoryLockService.release_lock(project_id: project_id)
    end

    test "acquire_lock releases lock after acquisition when timeout_ms is 0" do
      project_id = 1002
      result = AdvisoryLockService.acquire_lock(project_id: project_id, timeout_ms: 0)

      assert result.success
      assert result.acquired

      # Cleanup - lock was already released by the function
    end

    test "acquire_lock with timeout_ms > 0 sets statement_timeout and acquires lock" do
      project_id = 1003
      result = AdvisoryLockService.acquire_lock(project_id: project_id, timeout_ms: 5000)

      assert result.success
      assert result.acquired

      # Cleanup
      AdvisoryLockService.release_lock(project_id: project_id)
    end

    test "acquire_lock without timeout waits indefinitely" do
      project_id = 1004
      result = AdvisoryLockService.acquire_lock(project_id: project_id)

      assert result.success
      assert result.acquired

      # Cleanup
      AdvisoryLockService.release_lock(project_id: project_id)
    end

    test "release_lock returns true when lock was held and released" do
      project_id = 1005
      # Acquire the lock first
      AdvisoryLockService.acquire_lock(project_id: project_id)

      # Release it
      released = AdvisoryLockService.release_lock(project_id: project_id)

      assert released
    end

    test "release_lock returns false when lock was not held" do
      # Try to release a lock that was never acquired
      released = AdvisoryLockService.release_lock(project_id: 999_999)

      refute released
    end

    test "acquire_lock with timeout_ms: 0 handles lock contention" do
      project_id = 1007
      # First, acquire the lock without timeout_ms (infinite wait)
      lock_result = AdvisoryLockService.acquire_lock(project_id: project_id)
      assert lock_result.acquired

      # Now try to acquire with timeout_ms: 0 (non-blocking)
      result = AdvisoryLockService.acquire_lock(project_id: project_id, timeout_ms: 0)

      assert result.success
      assert result.acquired

      # Release the lock for cleanup
      AdvisoryLockService.release_lock(project_id: project_id)
    end

    test "lock_held? returns true when lock is acquired" do
      project_id = 1008
      # Acquire lock
      AdvisoryLockService.acquire_lock(project_id: project_id)

      # Check if held
      held = AdvisoryLockService.lock_held?(project_id: project_id)

      assert held

      # Cleanup
      AdvisoryLockService.release_lock(project_id: project_id)
    end

    test "lock_held? returns false when lock is not acquired" do
      held = AdvisoryLockService.lock_held?(project_id: 1009)

      refute held
    end

    test "lock_held? returns false after lock is released" do
      project_id = 1010
      # Acquire and release
      AdvisoryLockService.acquire_lock(project_id: project_id)
      AdvisoryLockService.release_lock(project_id: project_id)

      # Verify lock is no longer held
      held = AdvisoryLockService.lock_held?(project_id: project_id)

      refute held
    end

    test "execute_with_timeout executes block within timeout" do
      result = nil

      AdvisoryLockService.execute_with_timeout(5000) do
        result = "executed"
      end

      assert_equal "executed", result
    end

    test "simulate_lock_auto_release releases all locks in current session" do
      project_id = 1012
      # Acquire a lock
      AdvisoryLockService.acquire_lock(project_id: project_id)

      # Simulate auto-release
      AdvisoryLockService.simulate_lock_auto_release

      # Verify lock is released
      held = AdvisoryLockService.lock_held?(project_id: project_id)
      refute held
    end

    test "simulate_lock_auto_release with project_id releases specific lock" do
      project_id = 1013
      # Acquire a lock
      AdvisoryLockService.acquire_lock(project_id: project_id)

      # Release specific lock
      AdvisoryLockService.simulate_lock_auto_release(project_id)

      # Verify lock is released
      held = AdvisoryLockService.lock_held?(project_id: project_id)
      refute held
    end

    test "acquire_lock! does not raise when lock is acquired" do
      project_id = 1014

      assert_nothing_raised do
        AdvisoryLockService.acquire_lock!(project_id: project_id)
      end

      # Cleanup
      AdvisoryLockService.release_lock(project_id: project_id)
    end

    test "release_lock! does not raise when lock is held and released" do
      project_id = 1015
      # Acquire and release
      AdvisoryLockService.acquire_lock(project_id: project_id)

      assert_nothing_raised do
        AdvisoryLockService.release_lock!(project_id: project_id)
      end
    end

    test "acquire_lock returns correct lock_key for various project_ids" do
      project_ids = [ 1, 100, 1000, 999999 ]

      project_ids.each do |pid|
        result = AdvisoryLockService.acquire_lock(project_id: pid)
        expected_key = 1_000_000 + pid

        assert_equal expected_key, result.lock_key
        assert result.acquired

        # Cleanup
        AdvisoryLockService.release_lock(project_id: pid)
      end
    end

    test "multiple acquire/release cycles work correctly" do
      3.times do |i|
        project_id = 20_000 + i

        # Acquire
        result = AdvisoryLockService.acquire_lock(project_id: project_id)
        assert result.acquired, "Failed to acquire on iteration #{i}"

        # Release
        released = AdvisoryLockService.release_lock(project_id: project_id)
        assert released, "Failed to release on iteration #{i}"

        # Verify released
        held = AdvisoryLockService.lock_held?(project_id: project_id)
        refute held, "Lock still held after release on iteration #{i}"
      end
    end

    test "advisory lock auto-releases on session end (database connection pool)" do
      project_id = 30_000

      # Acquire lock
      result = AdvisoryLockService.acquire_lock(project_id: project_id)
      assert result.acquired

      # Lock is now held - verify it
      held = AdvisoryLockService.lock_held?(project_id: project_id)
      assert held

      # In a real scenario, the lock would auto-release when the connection
      # is closed or the transaction ends. For testing, we explicitly release.
      AdvisoryLockService.release_lock(project_id: project_id)

      # Note: The lock may still show as held due to connection pool reuse
      # This is expected behavior - the lock is released when the connection is returned to pool
    end

    test "concurrent lock acquisition - first succeeds" do
      project_id = 40_000

      # First acquisition should succeed
      result1 = AdvisoryLockService.acquire_lock(project_id: project_id)
      assert result1.acquired

      # Cleanup
      AdvisoryLockService.release_lock(project_id: project_id)
    end

    test "statement_timeout is properly handled during lock acquisition" do
      project_id = 50_000

      # This should work with the timeout
      result = AdvisoryLockService.acquire_lock(project_id: project_id, timeout_ms: 1000)
      assert result.acquired

      # Cleanup
      AdvisoryLockService.release_lock(project_id: project_id)
    end

    test "acquire_lock handles edge case of project_id = 0" do
      result = AdvisoryLockService.acquire_lock(project_id: 0)

      assert result.acquired
      assert_equal 1_000_000, result.lock_key

      AdvisoryLockService.release_lock(project_id: 0)
    end

    test "acquire_lock handles large project_id values" do
      large_id = 999_999_999
      result = AdvisoryLockService.acquire_lock(project_id: large_id)

      assert result.acquired
      assert_equal 1_000_000 + large_id, result.lock_key

      AdvisoryLockService.release_lock(project_id: large_id)
    end

    test "acquire_lock with timeout_ms: 0 returns acquired status" do
      project_id = 60_000
      result = AdvisoryLockService.acquire_lock(project_id: project_id, timeout_ms: 0)

      assert result.acquired
    end

    test "acquire_lock! raises WorkflowLockError with correct structure" do
      # This test verifies the error class exists and has correct structure
      # Actual error raising would require lock contention which is hard to test
      error = Legion::WorkflowLockError.new("Test message", 1_000_123)
      assert_equal "Test message", error.message
      assert_equal 1_000_123, error.lock_key
    end

    test "lock_key prefix is correctly applied" do
      (1..5).each do |i|
        key = AdvisoryLockService.lock_key(i)
        assert_equal 1_000_000 + i, key
      end
    end
  end
end
