# frozen_string_literal: true

require "test_helper"
require "timeout"

class ArtifactVersioningTest < ActiveSupport::TestCase
  setup do
    @project = create(:project)
    @team_membership = create(:team_membership)
    @workflow_run = create(:workflow_run, project: @project, team_membership: @team_membership)
    @workflow_execution = create(:workflow_execution, project: @project)
    @created_by = create(:agent_team, project: @project)
  end

  test "AC-2: sequential versions within same execution for same artifact type" do
    # Create first artifact
    artifact1 = create(:artifact, project: @project, workflow_run: @workflow_run, workflow_execution: @workflow_execution, artifact_type: :plan, content: "First plan", created_by: @created_by)
    assert_equal 1, artifact1.version_number
    assert_equal "1.0.0", artifact1.version

    # Create second artifact of same type for same execution
    artifact2 = create(:artifact, project: @project, workflow_run: @workflow_run, workflow_execution: @workflow_execution, artifact_type: :plan, content: "Second plan", created_by: @created_by)
    assert_equal 2, artifact2.version_number
    assert_equal "2.0.0", artifact2.version

    # Create third artifact of same type for same execution
    artifact3 = create(:artifact, project: @project, workflow_run: @workflow_run, workflow_execution: @workflow_execution, artifact_type: :plan, content: "Third plan", created_by: @created_by)
    assert_equal 3, artifact3.version_number
    assert_equal "3.0.0", artifact3.version
  end

  test "AC-2: different artifact types have independent versioning within same execution" do
    # Create plan artifacts
    plan1 = create(:artifact, project: @project, workflow_run: @workflow_run, workflow_execution: @workflow_execution, artifact_type: :plan, content: "Plan 1", created_by: @created_by)
    assert_equal 1, plan1.version_number

    plan2 = create(:artifact, project: @project, workflow_run: @workflow_run, workflow_execution: @workflow_execution, artifact_type: :plan, content: "Plan 2", created_by: @created_by)
    assert_equal 2, plan2.version_number

    # Create score_report artifacts (different type, should reset to 1)
    score1 = create(:artifact, project: @project, workflow_run: @workflow_run, workflow_execution: @workflow_execution, artifact_type: :score_report, content: "Score 1", created_by: @created_by)
    assert_equal 1, score1.version_number
    assert_equal "1.0.0", score1.version

    score2 = create(:artifact, project: @project, workflow_run: @workflow_run, workflow_execution: @workflow_execution, artifact_type: :score_report, content: "Score 2", created_by: @created_by)
    assert_equal 2, score2.version_number
    assert_equal "2.0.0", score2.version

    # Create architect_review artifacts (different type, should reset to 1)
    review1 = create(:artifact, project: @project, workflow_run: @workflow_run, workflow_execution: @workflow_execution, artifact_type: :architect_review, content: "Review 1", created_by: @created_by)
    assert_equal 1, review1.version_number
    assert_equal "1.0.0", review1.version

    # Original plan versions unchanged
    assert_equal 2, plan2.reload.version_number
  end

  test "concurrent artifact creation avoids duplicate versions" do
    execution = @workflow_execution
    created_by = @created_by

    # Create multiple artifacts concurrently using threads with locking
    results = []
    mutex = Mutex.new

    Timeout.timeout(10) do
      threads = 5.times.map do |i|
        Thread.new do
          begin
            artifact = Artifact.create_with_version!(
              project: @project,
              workflow_run: @workflow_run,
              workflow_execution: execution,
              artifact_type: :code_output,
              content: "Code output #{i}",
              name: "Code Output #{i}",
              created_by: created_by
            )
            mutex.synchronize { results << artifact.version_number }
          rescue => e
            mutex.synchronize { results << nil }
          end
        end
      end

      threads.each(&:join)
    end

    # All artifacts should have been created (with retries)
    assert_equal 5, results.length
    assert results.all? { |r| r.is_a?(Integer) }
    assert_equal [ 1, 2, 3, 4, 5 ], results.sort

    # Verify in database
    db_artifacts = Artifact.where(workflow_execution: execution, artifact_type: :code_output)
    assert_equal 5, db_artifacts.count
    versions = db_artifacts.pluck(:version_number).sort
    assert_equal [ 1, 2, 3, 4, 5 ], versions
  end

  test "concurrent creation with race condition retry" do
    execution = create(:workflow_execution, project: @project)
    created_by = create(:agent_team, project: @project)

    # Test the create_with_version! method's retry logic
    results = []
    mutex = Mutex.new

    threads = 3.times.map do |i|
      Thread.new do
        begin
          artifact = Artifact.create_with_version!(
            project: @project,
            workflow_run: @workflow_run,
            workflow_execution: execution,
            artifact_type: :review_feedback,
            content: "Review feedback #{i}",
            name: "Review Feedback #{i}",
            created_by: created_by
          )
          mutex.synchronize { results << artifact.version_number }
        rescue => e
          # Expected to catch some errors due to race conditions, but retries should handle most
          mutex.synchronize { results << nil }
        end
      end
    end

    threads.each(&:join)

    # All artifacts should have been created successfully (with retries)
    assert_equal 3, results.length
    assert results.all? { |r| r.is_a?(Integer) }
    assert_equal [ 1, 2, 3 ], results.sort.uniq
  end

  test "AC-5: parent-child linking with parent_artifact association" do
    parent = create(:artifact, project: @project, workflow_run: @workflow_run, workflow_execution: @workflow_execution, artifact_type: :plan, content: "Parent plan", created_by: @created_by)
    child = create(:artifact, project: @project, workflow_run: @workflow_run, workflow_execution: @workflow_execution, artifact_type: :retry_context, content: "Child retry context", parent_artifact: parent, created_by: @created_by)

    assert_equal parent, child.parent_artifact
    assert_nil parent.parent_artifact
    assert_equal parent.id, child.parent_artifact_id
  end

  test "AC-5: parent-child linking with child_artifacts association" do
    parent = create(:artifact, project: @project, workflow_run: @workflow_run, workflow_execution: @workflow_execution, artifact_type: :plan, content: "Parent plan", created_by: @created_by)

    child1 = create(:artifact, project: @project, workflow_run: @workflow_run, workflow_execution: @workflow_execution, artifact_type: :retry_context, content: "Child 1", parent_artifact: parent, created_by: @created_by)
    child2 = create(:artifact, project: @project, workflow_run: @workflow_run, workflow_execution: @workflow_execution, artifact_type: :retry_context, content: "Child 2", parent_artifact: parent, created_by: @created_by)
    child3 = create(:artifact, project: @project, workflow_run: @workflow_run, workflow_execution: @workflow_execution, artifact_type: :review_feedback, content: "Child 3", parent_artifact: parent, created_by: @created_by)

    assert_includes parent.child_artifacts, child1
    assert_includes parent.child_artifacts, child2
    assert_includes parent.child_artifacts, child3
    assert_equal 3, parent.child_artifacts.count
  end

  test "parent-child linking with multiple generations" do
    grandparent = create(:artifact, project: @project, workflow_run: @workflow_run, workflow_execution: @workflow_execution, artifact_type: :plan, content: "Grandparent", created_by: @created_by)
    parent = create(:artifact, project: @project, workflow_run: @workflow_run, workflow_execution: @workflow_execution, artifact_type: :code_output, content: "Parent", parent_artifact: grandparent, created_by: @created_by)
    child = create(:artifact, project: @project, workflow_run: @workflow_run, workflow_execution: @workflow_execution, artifact_type: :retry_context, content: "Child", parent_artifact: parent, created_by: @created_by)

    # Verify chain
    assert_equal grandparent, parent.parent_artifact
    assert_equal parent, child.parent_artifact
    assert_equal parent, grandparent.child_artifacts.first
    assert_equal child, parent.child_artifacts.first
  end

  test "parent-child linking with nullifying parent" do
    parent = create(:artifact, project: @project, workflow_run: @workflow_run, workflow_execution: @workflow_execution, artifact_type: :plan, content: "Parent", created_by: @created_by)
    child = create(:artifact, project: @project, workflow_run: @workflow_run, workflow_execution: @workflow_execution, artifact_type: :retry_context, content: "Child", parent_artifact: parent, created_by: @created_by)

    parent.destroy

    child.reload
    assert_nil child.parent_artifact
    assert_nil child.parent_artifact_id
  end

  test "parent-child with different versions per type" do
    parent = create(:artifact, project: @project, workflow_run: @workflow_run, workflow_execution: @workflow_execution, artifact_type: :plan, content: "Parent plan", created_by: @created_by)
    assert_equal 1, parent.version_number

    child1 = create(:artifact, project: @project, workflow_run: @workflow_run, workflow_execution: @workflow_execution, artifact_type: :plan, content: "Child plan 1", parent_artifact: parent, created_by: @created_by)
    assert_equal 2, child1.version_number # Same type as parent, so version increments

    child2 = create(:artifact, project: @project, workflow_run: @workflow_run, workflow_execution: @workflow_execution, artifact_type: :score_report, content: "Child score report", parent_artifact: parent, created_by: @created_by)
    assert_equal 1, child2.version_number # Different type, resets to 1
  end

  test "create_with_version! method creates artifacts with correct versions" do
    execution = create(:workflow_execution, project: @project)
    created_by = create(:agent_team, project: @project)

    artifact1 = Artifact.create_with_version!(
      project: @project,
      workflow_run: @workflow_run,
      workflow_execution: execution,
      artifact_type: :plan,
      content: "Plan 1",
      name: "Plan 1",
      created_by: created_by
    )
    assert_equal 1, artifact1.version_number

    artifact2 = Artifact.create_with_version!(
      project: @project,
      workflow_run: @workflow_run,
      workflow_execution: execution,
      artifact_type: :plan,
      content: "Plan 2",
      name: "Plan 2",
      created_by: created_by
    )
    assert_equal 2, artifact2.version_number

    artifact3 = Artifact.create_with_version!(
      project: @project,
      workflow_run: @workflow_run,
      workflow_execution: execution,
      artifact_type: :score_report,
      content: "Score 1",
      name: "Score 1",
      created_by: created_by
    )
    assert_equal 1, artifact3.version_number
  end

  test "version independence across different executions" do
    execution1 = @workflow_execution
    execution2 = create(:workflow_execution, project: @project)

    # Create artifacts for execution1
    plan1_e1 = create(:artifact, project: @project, workflow_run: @workflow_run, workflow_execution: execution1, artifact_type: :plan, content: "Plan 1 e1", created_by: @created_by)
    assert_equal 1, plan1_e1.version_number

    plan2_e1 = create(:artifact, project: @project, workflow_run: @workflow_run, workflow_execution: execution1, artifact_type: :plan, content: "Plan 2 e1", created_by: @created_by)
    assert_equal 2, plan2_e1.version_number

    # Create artifacts for execution2 (should start from 1)
    plan1_e2 = create(:artifact, project: @project, workflow_run: @workflow_run, workflow_execution: execution2, artifact_type: :plan, content: "Plan 1 e2", created_by: @created_by)
    assert_equal 1, plan1_e2.version_number

    plan2_e2 = create(:artifact, project: @project, workflow_run: @workflow_run, workflow_execution: execution2, artifact_type: :plan, content: "Plan 2 e2", created_by: @created_by)
    assert_equal 2, plan2_e2.version_number

    # Verify execution1 versions unchanged
    assert_equal 1, plan1_e1.reload.version_number
    assert_equal 2, plan2_e1.reload.version_number
  end
end
