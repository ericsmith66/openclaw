# frozen_string_literal: true

require "test_helper"

class UnlockCommandTest < ActiveSupport::TestCase
  setup do
    @project = create(:project)
  end

  teardown do
    # Release all locks held in the current session to avoid interference between tests
    Legion::AdvisoryLockService.simulate_lock_auto_release
  end

  test "releases advisory lock for a project" do
    # Acquire a lock first
    Legion::AdvisoryLockService.acquire_lock(project_id: @project.id)

    # Release the lock
    released = Legion::AdvisoryLockService.release_lock(project_id: @project.id)

    # Verify lock was released
    assert released, "Lock should have been released"
  end

  test "handles no lock held error gracefully" do
    # Attempt to release when no lock is held
    released = Legion::AdvisoryLockService.release_lock(project_id: @project.id)

    # Should return false when no lock was held
    refute released, "Should return false when no lock was held"
  end

  test "validates project path exists" do
    # Create a project and verify it exists
    assert @project.persisted?, "Project should be persisted"

    # Attempt to release lock for non-existent project (using a fake ID)
    fake_project_id = 999999
    released = Legion::AdvisoryLockService.release_lock(project_id: fake_project_id)

    # Should return false for non-existent project (no lock to release)
    refute released, "Should return false when no lock was held for fake project"
  end

  test "release_lock returns correct boolean for multiple calls" do
    # Acquire a lock
    Legion::AdvisoryLockService.acquire_lock(project_id: @project.id)

    # Release the lock - should return true
    released1 = Legion::AdvisoryLockService.release_lock(project_id: @project.id)
    assert released1, "First release should return true"

    # Release again - should return false (lock already released)
    released2 = Legion::AdvisoryLockService.release_lock(project_id: @project.id)
    refute released2, "Second release should return false"
  end

  test "release_lock works with different projects" do
    # Create another project
    project2 = create(:project)

    # Acquire locks for both projects
    Legion::AdvisoryLockService.acquire_lock(project_id: @project.id)
    Legion::AdvisoryLockService.acquire_lock(project_id: project2.id)

    # Release only first project's lock
    released1 = Legion::AdvisoryLockService.release_lock(project_id: @project.id)
    assert released1, "First project lock should be released"

    # Release second project's lock
    released2 = Legion::AdvisoryLockService.release_lock(project_id: project2.id)
    assert released2, "Second project lock should be released"
  end
end
